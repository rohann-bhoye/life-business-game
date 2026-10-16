extends SceneTree

const Backend = preload("res://business_backend.gd")
const Catalog = preload("res://product_catalog.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("life_products_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _reload(state) -> void:
	assert(state.save_progress())
	var restored = Backend.new()
	restored.load_progress(state.save_path)
	assert(restored.snapshot() == state.snapshot())

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	assert(not img.is_empty())
	assert(img.save_png(OS.get_environment("TEMP").path_join("products_%s.png" % label)) == OK)

func _run() -> void:
	var state = Backend.new()
	state.save_path = _path()
	_reload(state)
	assert(state.product_stock("bottle") == 10 and state.product_stock("snack") == 0)
	assert(not state.order_stock("invalid"))
	for id in ["bottle", "snack", "soap"]:
		var before: int = state.product_stock(id)
		var money: int = state.money
		assert(state.order_stock(id))
		assert(state.money == money - Catalog.COSTS[id] and state.product_stock(id) == before)
		assert(state.can_order_stock("bottle") and not state.order_stock("bottle", 11))
		_reload(state)
		assert(state.receive_delivery())
		_reload(state)
		assert(state.product_stock(id) == before and state.boxed_stock == 10)
		assert(state.pick_up_box())
		_reload(state)
		assert(state.shelve_box())
		assert(state.product_stock(id) == before + 10)
		assert(state.sell_basket(3, 200, -1, id))
		assert(state.product_stock(id) == before + 7)
		_reload(state)
	assert(state.product_stock("bottle") == 17 and state.stock == 31)
	assert(state.money == 49400 and state.sales_revenue == 900 and state.restocking_expenses == 1500)
	var corrupt: Dictionary = state.snapshot()
	corrupt.inventory.soap.stock += 1
	assert(not state._is_valid_snapshot(corrupt))
	var legacy: Dictionary = Backend.new().snapshot()
	legacy.version = 9
	for field in ["inventory", "pending_product", "assistant_auto_collect"]: legacy.erase(field)
	var legacy_path := _path()
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	var migrated: Dictionary = state._read_valid_save(legacy_path)
	assert(state._is_valid_snapshot(migrated) and migrated.version == 10)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = _path()
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	root.size = Vector2i(1152, 648)
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Player").set_physics_process(false)
	current_scene.get_node("Customer").set_physics_process(false)
	var ops = current_scene.get_node("ShopOperations")
	ops.set_process(false)
	var assistant = current_scene.get_node("StockWorker")
	assistant.set_physics_process(false)
	var shop = current_scene.get_node("Shop/ShopArea")
	var business = shop.business
	var player = current_scene.get_node("Player")
	var menu = current_scene.get_node("Ui").supplier_menu
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	camera.position = Vector3(-0.8, 2.8, 1.8)
	camera.look_at(Vector3(-4.3, 1.1, -3.8))
	assert(business.hire_stock_worker())
	assert(business.order_stock("snack") and business.receive_delivery())
	assistant._physics_process(100)
	assert(business.boxed_stock == 10 and assistant.route.is_empty())
	player.position = ops.drop_point + Vector3(0, 1, 0)
	assert(ops.try_interact() and business.carried_stock == 10)
	# Racks are mixed: the bottle rack's empty rows accept snacks too.
	player.position = ops.rack_point + Vector3(0, 1, 0)
	assert(ops.try_interact() and business.carried_stock == 9)
	assert(current_scene.get_node("Ui").feedback_label.text.begins_with("Shelved 1"))
	assert(not player._menu_is_open())
	player.position = ops.rack_target("snack") + Vector3(0, 1, 0)
	for remaining in range(8, -1, -1):
		assert(ops.try_interact() and business.carried_stock == remaining)
	assert(business.product_stock("snack") == 10)
	menu.product_input.select(1)
	menu.product_input.item_selected.emit(1)
	assert(menu.retail_price.value == 80)
	menu.retail_price.value = 90
	assert(business.product_price("snack") == 90)
	menu.open_menu()
	await _capture("orders")
	menu.close_menu()
	assert(business.order_stock("soap") and business.receive_delivery())
	menu.role_input.select(1)
	menu.role_input.item_selected.emit(1)
	menu.tabs.current_tab = 1
	menu.auto_collect.button_pressed = true
	assert(business.assistant_auto_collect)
	for frame in range(1200):
		assistant._physics_process(0.05)
		if business.product_stock("soap") == 10 and assistant.route.is_empty(): break
	assert(business.product_stock("soap") == 10 and business.boxed_stock == 0)
	_reload(business)
	menu.open_menu()
	await _capture("sunil")
	menu.close_menu()
	player.position = Vector3(1, 1.1, 5)
	ops.update_rack()
	await _capture("racks")
	for id in ["bottle", "snack", "soap"]:
		var visitor = load("res://customer.tscn").instantiate()
		visitor.shop_area_path = "../Shop/ShopArea"
		visitor.purchase_point_path = "../CustomerPurchasePoint"
		visitor.exit_point_path = "../CustomerExitPoint"
		current_scene.add_child(visitor)
		visitor.set_physics_process(false)
		visitor.product_id = id
		visitor.shopping_quantity = 3
		visitor.spending_budget = 200
		visitor.wants_discount = false
		visitor.state = visitor.State.TAKING
		visitor.wait_remaining = 0
		visitor.position = ops.rack_target(id)
		visitor.show()
		for frame in range(1200):
			visitor._physics_process(0.05)
			if visitor.state == visitor.State.SCANNING: break
		assert(visitor.state == visitor.State.SCANNING and visitor.basket_count == 3)
		assert(visitor.quoted_price == business.product_price(id))
		var previous_stock: int = business.product_stock(id)
		var cash: int = business.money
		for index in range(3): assert(visitor.scan_next())
		assert(business.product_stock(id) == previous_stock)
		assert(ops.checkout_display.text.contains("3/3 SCANNED"))
		camera.position = Vector3(-2.4, 2.1, -1.3)
		camera.look_at(Vector3(-2.5, 1.35, 0.5))
		await _capture(id + "_checkout")
		visitor.complete_checkout()
		assert(business.money == cash + business.product_price(id) * 3)
		assert(business.product_stock(id) == previous_stock - 3)
		visitor.complete_checkout()
		assert(business.product_stock(id) == previous_stock - 3)
		visitor.queue_free()
		await process_frame
		_reload(business)
	var placeholders: Array[Node3D] = []
	for index in range(3):
		var point := Node3D.new()
		current_scene.add_child(point)
		placeholders.append(point)
		ops.enqueue(point)
		var spot: Vector3 = ops.queue_position(point)
		assert(spot.x > -5 and spot.x < -1 and spot.z < 2.0)
	for point in placeholders: ops.queue.erase(point); point.queue_free()
	var line: Array[Node3D] = []
	for index in range(3):
		var visitor = load("res://customer.tscn").instantiate()
		visitor.shop_area_path = "../Shop/ShopArea"
		visitor.purchase_point_path = "../CustomerPurchasePoint"
		visitor.exit_point_path = "../CustomerExitPoint"
		current_scene.add_child(visitor)
		visitor.set_physics_process(false)
		visitor.shopping_quantity = 1
		visitor.state = visitor.State.TAKING
		visitor.wait_remaining = 0
		visitor.position = ops.rack_point
		visitor.show()
		line.append(visitor)
		for frame in range(500):
			visitor._physics_process(0.05)
			if visitor.state == visitor.State.SCANNING or visitor.state == visitor.State.QUEUING and visitor.position.is_equal_approx(ops.queue_position(visitor)): break
		assert(visitor.position.is_equal_approx(ops.queue_position(visitor)))
	assert(ops.queue.size() == 3 and line[0].state == line[0].State.SCANNING)
	camera.position = Vector3(-1.2, 2.3, -0.9)
	camera.look_at(Vector3(-3.4, 1.25, 1.2))
	await _capture("indoor_queue")
	for visitor in line:
		visitor.leave_shop()
		visitor.queue_free()
	await process_frame
	var audio = ops.get_node("ShopAudio")
	for effect in ["scan", "payment", "door", "delivery", "stock", "click"]:
		assert(audio.streams[effect] is AudioStream and audio.streams[effect].get_length() > 0.0, effect)
	assert(audio.footsteps.size() == 5)
	for size in [Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		menu.open_menu()
		menu.tabs.current_tab = 0
		for control in [menu.product_input, menu.retail_price, menu.order_button]:
			assert(menu.get_global_rect().encloses(control.get_global_rect()))
		await _capture("menu_%d" % size.x)
		menu.close_menu()
	business.save_path = ""
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: three products, catalog prices, isolated inventory, all delivery/save stages, manual correct-rack stocking, optional Sunil collection, timed checkout, payment guards, indoor queue, sounds and responsive PC")
	quit()
