extends SceneTree

const Backend = preload("res://business_backend.gd")
const Store = preload("res://rack_store.gd")

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = code
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func _run() -> void:
	var state = Backend.new()
	var path := OS.get_environment("TEMP").path_join("racks_%d_%d.json" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	state.load_progress(path)
	var before: Dictionary = state.snapshot()
	for point in [Vector2(-3, 1.5), Vector2(-5.6, -3.3), Vector2(0, -4)]:
		assert(not state.place_rack("bottle", point, 2))
		assert(state.snapshot() == before)
	assert(state.place_rack("bottle", Vector2(-2.5, -4), 2))
	assert(state.money == 49000 and state.furnishing_expenses == 1000)
	assert(state.racks.records.size() == 4)
	assert(state._is_valid_snapshot(state.snapshot()))
	assert(state.purchase_stock())
	assert(state.racks.find(3).amount == 10 and state.racks.find(0).amount == 10)
	assert(state.sell_basket(2, 100, 100, "bottle", 3))
	assert(state.racks.find(3).amount == 8)
	assert(not state.sell_basket(9, 100, 100, "bottle", 3))
	assert(state.racks.free_space(3, "soap") == 20)
	var money: int = state.money
	assert(state.place_rack("bottle", Vector2(-1, -4), 2, 3))
	assert(state.money == money and state.racks.find(3).amount == 8)
	for record in state.racks.records:
		assert(not state.racks.route(Store.ENTRY, Store.approach(record)).is_empty())
	assert(state.save_progress())
	var loaded = Backend.new()
	loaded.load_progress(path)
	assert(loaded.snapshot() == state.snapshot())
	var invalid: Dictionary = state.snapshot()
	invalid.rack_layout[3].amount += 1
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid.rack_layout[3].x = NAN
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid.rack_layout[3].id = 0
	assert(not state._is_valid_snapshot(invalid))
	var legacy = Backend.new()
	var old: Dictionary = legacy.snapshot()
	old.erase("rack_layout")
	old.erase("furnishing_expenses")
	assert(legacy._is_valid_snapshot(old))
	var failed = Backend.new()
	failed.save_path = path.path_join("missing.json")
	before = failed.snapshot()
	assert(not failed.place_rack("soap", Vector2(-2.5, -4), 2))
	assert(failed.snapshot() == before)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	world.get_node("Customer").set_physics_process(false)
	world.get_node("Player").set_physics_process(false)
	var furnishing = world.get_node("RackFurnishing")
	var ops = world.get_node("ShopOperations")
	var business = world.get_node("Shop/ShopArea").business
	assert(furnishing.models.size() == 4)
	assert(furnishing.models[3].node.position == Vector3(-1, 0.1, -4))
	assert(furnishing.stock_rack("bottle") == 3)
	assert(furnishing.available(3) == 8)
	var menu = world.get_node("Ui/SupplierMenu")
	menu.open_menu()
	menu.tabs.current_tab = 4
	assert(menu.get_node("BuyRackButton").visible and not menu.order_button.visible)
	before = business.snapshot()
	menu.get_node("BuyRackButton").pressed.emit()
	assert(not furnishing.active and menu.visible and business.logistics.rack_incoming.size() == 1)
	assert(business.receive_rack_delivery())
	before = business.snapshot()
	assert(furnishing.begin_buy("bottle"))
	menu.close_menu()
	_key(KEY_R)
	assert(furnishing.turn == 3)
	_key(KEY_ESCAPE)
	assert(not furnishing.active and business.snapshot() == before)
	assert(furnishing.begin_move(3))
	furnishing.set_process(false)
	furnishing.candidate = {"id": 3, "product": "bottle", "x": -3.0, "z": 1.5, "turn": 2, "amount": 8}
	assert(not furnishing.confirm())
	assert(business.snapshot() == before)
	furnishing.candidate.x = -2.5
	furnishing.candidate.z = -4.0
	_key(KEY_E)
	assert(not furnishing.active and business.racks.find(3).x == -2.5)
	assert(furnishing.models[3].node.position == Vector3(-2.5, 0.1, -4))
	assert(business.hire_stock_worker())
	assert(business.order_stock("bottle") and business.receive_delivery())
	assert(ops.stock_worker.assign_delivery())
	assert(not furnishing.begin_move(3))
	ops.stock_worker.global_position = ops.drop_point
	ops.stock_worker.route.clear()
	assert(business.pick_up_box(true))
	ops.stock_worker._return_to_rack()
	assert(ops.stock_worker.target_rack == 3)
	assert(ops.stock_worker.route.back().is_equal_approx(Store.approach(business.racks.find(3))))
	for index in range(500):
		ops.stock_worker._physics_process(0.1)
		if business.worker_carried_stock == 0: break
	assert(business.worker_carried_stock == 0 and business.racks.find(3).amount == 18)
	assert(business._is_valid_snapshot(business.snapshot()))
	assert(business.assign_shelf_slot(3, 2, "bottle"))
	assert(business.order_stock("soap") and business.receive_delivery() and business.pick_up_box())
	world.get_node("Player").global_position = Store.approach(business.racks.find(3))
	# Racks are mixed: rack 3's empty row (assigned to bottles) still takes soap.
	assert(ops.try_interact())
	assert(business.racks.find(3).slots[2].product == "soap" and business.carried_stock == 9)
	world.get_node("Player").global_position = Store.approach(business.racks.find(2))
	assert(ops.try_interact())
	assert(business.racks.find(2).amount == 1 and business.carried_stock == 8)
	assert(business.drop_box())
	var customer = world.get_node("Customer")
	customer.product_id = "bottle"
	customer.rack_id = 3
	customer.basket_count = 3
	customer.has_product = true
	assert(furnishing.available(3) == 15 and furnishing.available(0) == 10)
	customer.has_product = false
	assert(furnishing.available(3) == 18)
	var path_to_rack: Array[Vector3] = ops.customer_entry_route("bottle", 3)
	assert(path_to_rack.back().is_equal_approx(Store.approach(business.racks.find(3))))
	var check_route: Array[Vector3] = business.racks.route(Store.ENTRY, Store.approach(business.racks.find(3)))
	for point in check_route:
		for record in business.racks.records:
			assert(not Store.footprint(record).grow(0.27).has_point(Vector2(point.x, point.z)))
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.current = true
		camera.position = Vector3(-3.7, 2.4, 1.8)
		camera.look_at(Vector3(-2.5, 1, -4))
		world.get_node("Landscape").set_camera(camera)
		world.get_node("Player").hide()
		world.get_node("Ui").show_feedback("Rack restocked.")
		for size in [Vector2i(1152, 648), Vector2i(1920, 1080)]:
			root.size = size
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			assert(not image.is_empty())
			assert(image.get_pixel(image.get_width() / 2, image.get_height() / 2).get_luminance() > 0.02)
			assert(image.save_png(OS.get_environment("TEMP").path_join("racks_%d.png" % size.x)) == OK)
			menu.open_menu()
			menu.tabs.current_tab = 4
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("racks_menu_%d.png" % size.x)) == OK)
			menu.close_menu()
		for index in range(300): ops.stock_worker._physics_process(0.1)
		world.get_node("Player").global_position = Vector3(-3.7, 0.1, -1)
		world.get_node("Player").camera = camera
		camera.look_at(Vector3(-1.25, 0.1, -4))
		assert(furnishing.begin_move(3))
		furnishing._process(0)
		assert(furnishing.preview.visible and furnishing.last_error.is_empty())
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("racks_preview.png")) == OK)
		furnishing.cancel()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: rack purchase/move/cancel, aisle protection, per-rack stock, save/reload, UI and worker destination")
	quit()
