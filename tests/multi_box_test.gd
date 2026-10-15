extends SceneTree

const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("multi_boxes_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _reload(state) -> void:
	assert(state.save_progress())
	var loaded = Backend.new()
	loaded.load_progress(state.save_path)
	assert(loaded.snapshot() == state.snapshot())

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("multi_boxes_%s.png" % label)) == OK)

func _run() -> void:
	var state = Backend.new()
	state.save_path = _path()
	assert(state.order_stock("bottle", 2) and state.order_stock("snack", 3) and state.order_stock("soap", 1))
	assert(state.money == 47200 and state.stock == 10 and state.supply_in_transit == 60)
	assert(not state.order_stock("soap", 0) and not state.order_stock("soap", 11) and not state.order_stock("bad", 1))
	_reload(state)
	assert(state.receive_delivery() and not state.receive_delivery())
	assert(state.boxed_stock == 10 and state.queued_boxes.size() == 5)
	assert(state.pick_up_box())
	assert(state.order_stock("soap", 2) and state.pending_product == "bottle")
	assert(state.receive_delivery() and state.pending_product == "bottle" and state.carried_stock == 10)
	assert(state.queued_boxes.size() == 7 and state.money == 46000)
	assert(state.shelve_one() and state.carried_stock == 9)
	_reload(state)
	assert(state.drop_box())
	var soap_index := -1
	for index in range(state.queued_boxes.size()):
		if state.queued_boxes[index].product == "soap": soap_index = index; break
	assert(state.pick_up_box(false, soap_index) and state.pending_product == "soap")
	assert(state.queued_boxes[0].amount == 9 and state.queued_boxes[0].product == "bottle")
	assert(state.shelve_box() and state.pending_product == "bottle" and state.boxed_stock == 9)
	assert(state.hire_stock_worker())
	while state.boxed_stock > 0:
		assert(state.pick_up_box(true) and state.shelve_box(true))
		_reload(state)
	assert(state.stock == 90 and state.product_stock("bottle") == 30 and state.product_stock("snack") == 30 and state.product_stock("soap") == 30)
	assert(state.supply_box_count() == 0 and state.money == 45000)
	var capped = Backend.new()
	assert(capped.order_stock("soap", 10) and capped.order_stock("snack", 10))
	assert(not capped.can_order_stock("bottle") and not capped.order_stock("bottle"))
	assert(capped._is_valid_snapshot(capped.snapshot()))
	var invalid: Dictionary = capped.snapshot()
	invalid.incoming_boxes[0].amount = 11
	assert(not capped._is_valid_snapshot(invalid))
	invalid = capped.snapshot()
	invalid.incoming_boxes[0].product = "bottle"
	assert(not capped._is_valid_snapshot(invalid))
	var legacy = Backend.new()
	assert(legacy.order_stock("snack"))
	var data: Dictionary = legacy.snapshot()
	data.erase("incoming_boxes")
	data.erase("queued_boxes")
	var legacy_path := _path()
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var migrated = Backend.new()
	migrated.load_progress(legacy_path)
	assert(migrated.incoming_boxes.size() == 1 and migrated.incoming_boxes[0].product == "snack")
	assert(migrated.receive_delivery() and migrated.pick_up_box() and migrated.shelve_box())
	assert(migrated.product_stock("snack") == 10 and migrated._is_valid_snapshot(migrated.snapshot()))
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = _path()
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("StockWorker").set_physics_process(false)
	var shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	var ops = current_scene.get_node("ShopOperations")
	ops.set_process(false)
	var ui = current_scene.get_node("Ui")
	var menu = ui.supplier_menu
	menu.open_menu()
	menu.product_input.select(2)
	menu.product_input.item_selected.emit(2)
	menu.box_quantity.value = 3
	assert(menu.order_button.text.contains("1,800"))
	for size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		menu._layout()
		var controls = menu.get_children().filter(func(node): return node is Control and node.visible)
		for index in range(controls.size()):
			assert(Rect2(Vector2.ZERO, menu.size).encloses(controls[index].get_rect()), str(controls[index].name))
			assert(controls[index].get_combined_minimum_size().x <= controls[index].size.x, str(controls[index].name))
			for other in range(index + 1, controls.size()): assert(not controls[index].get_rect().intersects(controls[other].get_rect()))
		await _capture("order_%dx%d" % [size.x, size.y])
	menu.order_button.pressed.emit()
	assert(shop.money == 48200 and shop.business.incoming_boxes.size() == 3)
	menu.close_menu()
	ops._process(5)
	ops._process(2)
	assert(ops.delivery_box.visible and ops.extra_delivery_boxes.filter(func(box): return box.visible).size() == 2)
	assert(ops.extra_delivery_boxes[0].get_node("BoxLabel").text.contains("SOAP"))
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	var target: Node3D = ops.extra_delivery_boxes[1]
	player.global_position = target.global_position + Vector3(0, 0.7, 0.8)
	player.camera.look_at(target.global_position)
	assert(ops.delivery_box_target() == 1)
	assert(ops.try_interact() and shop.business.carried_stock == 10 and shop.business.pending_product == "soap")
	assert(shop.business.order_stock("bottle", 2) and shop.business.receive_delivery())
	assert(shop.business.pending_product == "soap" and shop.business.queued_boxes.size() == 4)
	assert(shop.business._is_valid_snapshot(shop.business.snapshot()))
	assert(shop.business.shelve_box())
	var preview := Camera3D.new()
	current_scene.add_child(preview)
	preview.global_position = Vector3(-10.5, 3, 7)
	preview.look_at(Vector3(-8.2, 0.5, 3))
	preview.make_current()
	root.size = Vector2i(1152, 648)
	await _capture("delivery")
	assert(shop.business.hire_stock_worker())
	shop.business.set_assistant_auto_collect(true)
	var worker = current_scene.get_node("StockWorker")
	for frame in range(6000):
		if shop.business.supply_box_count() == 0: break
		worker._physics_process(0.05)
	assert(shop.business.supply_box_count() == 0 and shop.stock == 60)
	assert(shop.business.product_stock("soap") == 30 and shop.business.product_stock("bottle") == 30)
	assert(shop.business._is_valid_snapshot(shop.business.snapshot()))
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: mixed multi-box orders, costs/capacity, labelled crates/selection, active product protection, partial return, worker batches, legacy migration, restart and responsive quantity UI")
	quit()
