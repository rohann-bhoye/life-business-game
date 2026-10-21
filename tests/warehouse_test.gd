extends SceneTree

const Backend = preload("res://business_backend.gd")
const Logistics = preload("res://shop_logistics.gd")
var path: String

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	call_deferred("_run")

func _reload() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	for name in ["Player", "Customer", "StockWorker"]: current_scene.get_node(name).set_physics_process(false)
	current_scene.get_node("ShopOperations").set_process(false)
	current_scene.get_node("Warehouse").set_process(false)

func _capture(camera: Camera3D, label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	var bright := 0
	var dark := 0
	for y in range(0, image.get_height(), 16):
		for x in range(0, image.get_width(), 16):
			if image.get_pixel(x, y).get_luminance() > 0.35: bright += 1
			if image.get_pixel(x, y).get_luminance() < 0.2: dark += 1
	assert(bright > 30 and dark > 30)
	assert(image.save_png(OS.get_environment("TEMP").path_join("warehouse_%s_%d.png" % [label, root.size.x])) == OK)

func _run() -> void:
	path = OS.get_environment("TEMP").path_join("warehouse_%d_%d.json" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	var state = Backend.new()
	state.load_progress(path)
	assert(state.order_racks("bottle", 2))
	assert(state.order_racks("soap", 1))
	assert(state.money == 47000 and state.furnishing_expenses == 3000 and state.racks.records.size() == 3)
	assert(not state.order_racks("soap", 3))
	assert(state._is_valid_snapshot(state.snapshot()))
	assert(state.save_progress())
	await _reload()
	var warehouse = current_scene.get_node("Warehouse")
	var business = current_scene.get_node("Shop/ShopArea").business
	var ops = current_scene.get_node("ShopOperations")
	assert(warehouse.racks.size() == 16 and warehouse.truck_state == warehouse.TruckState.ARRIVING)
	assert(warehouse.truck != ops.van and warehouse.truck.visible)
	for id in range(16):
		assert(warehouse.racks[id].position == warehouse.rack_point(id))
		assert(warehouse.racks[id].has_node("Shelf3Body"))
		assert(business.logistics.free_slot(id) == id * 16)
	for index in range(150): warehouse._process(0.1)
	assert(business.logistics.rack_incoming.is_empty() and business.logistics.rack_delivered.size() == 3)
	assert(warehouse.furniture_boxes.size() == 3 and warehouse.furniture_boxes[2].visible)
	assert(business.money == 47000)
	var furnishing = current_scene.get_node("RackFurnishing")
	var player = current_scene.get_node("Player")
	player.global_position = warehouse.furniture_boxes[0].global_position + Vector3(0, -0.4, -0.8)
	player.camera.global_position = player.global_position + Vector3(0, 1.6, 0)
	player.camera.look_at(warehouse.furniture_boxes[0].global_position)
	assert(warehouse.hint().begins_with("Unpack rack"))
	assert(warehouse.try_interact() and furnishing.active)
	furnishing.cancel()
	assert(business.logistics.rack_delivered.size() == 3)
	assert(not business.place_rack("bottle", Vector2(-3, 1.5), 2, -1, true))
	assert(business.place_rack("bottle", Vector2(-2.5, -4), 2, -1, true))
	assert(business.money == 47000 and business.logistics.rack_delivered.size() == 2)
	assert(business.order_stock("soap", 2) and business.receive_delivery() and business.pick_up_box())
	assert(business.shelve_one(2))
	assert(business.carried_stock == 9)
	player = current_scene.get_node("Player")
	player.global_position = warehouse.service_point(0)
	assert(warehouse.try_interact())
	assert(business.carried_stock == 0 and business.logistics.stored_units("soap") == 9)
	assert(business.inventory.soap.stock == 1 and business.boxed_stock == 10)
	assert(warehouse.stored_models[0].visible)
	assert(not business.store_product_box(0))
	assert(business.save_progress())
	await _reload()
	warehouse = current_scene.get_node("Warehouse")
	business = current_scene.get_node("Shop/ShopArea").business
	ops = current_scene.get_node("ShopOperations")
	assert(business.logistics.storage.size() == 1 and warehouse.stored_models[0].visible)
	assert(business.logistics.rack_delivered.size() == 2)
	player = current_scene.get_node("Player")
	player.global_position = warehouse.service_point(0)
	player.camera.global_position = player.global_position + Vector3(0, 1.6, 0)
	player.camera.look_at(warehouse.slot_point(0))
	await physics_frame
	await physics_frame
	await create_timer(0.15).timeout
	assert(player.warehouse_indoors)
	assert(warehouse.storage_box_target() == 0)
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	assert(business.carried_stock == 9 and business.boxed_stock == 0 and business.queued_boxes.size() == 1)
	assert(business.logistics.storage.is_empty() and not warehouse.stored_models[0].visible)
	assert(business.store_product_box(255))
	assert(business.logistics.at_slot(255).amount == 9)
	assert(business.boxed_stock == 10)
	assert(business.pick_up_box())
	assert(business.store_product_box(5))
	var feed = current_scene.get_node("Ui/NotificationFeed")
	feed.refresh()
	assert(feed.entries["stock:soap"].detail.contains("Warehouse"))
	assert(feed.entries.furniture.detail.contains("warehouse"))
	assert(business._is_valid_snapshot(business.snapshot()))
	var invalid: Dictionary = business.snapshot()
	invalid.logistics.storage.append(invalid.logistics.storage[0].duplicate())
	assert(not business._is_valid_snapshot(invalid))
	invalid = business.snapshot()
	invalid.logistics.storage[0].amount = 11
	assert(not business._is_valid_snapshot(invalid))
	invalid = business.snapshot()
	invalid.logistics.rack_incoming.append("unknown")
	assert(not business._is_valid_snapshot(invalid))
	var old: Dictionary = Backend.new().snapshot()
	old.erase("logistics")
	assert(business._is_valid_snapshot(old))
	var full = Logistics.new()
	for slot in range(256): full.storage.append({"slot": slot, "product": "bottle", "amount": 10})
	assert(full.free_slot(0) == -1 and full.free_slot(15) == -1)
	assert(Logistics.valid(full.snapshot(), 5))
	var failed = Backend.new()
	failed.save_path = path.path_join("missing.json")
	var before: Dictionary = failed.snapshot()
	assert(not failed.order_racks("bottle", 2))
	assert(failed.snapshot() == before)
	failed.save_path = ""
	assert(failed.order_stock("bottle") and failed.receive_delivery() and failed.pick_up_box())
	failed.save_path = path.path_join("missing.json")
	before = failed.snapshot()
	assert(not failed.store_product_box(0))
	assert(failed.snapshot() == before)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-3, 1, warehouse.FRONT - 1), Vector3(-3, 1, warehouse.FRONT + 1))).is_empty())
	assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-8, 1, warehouse.FRONT - 1), Vector3(-8, 1, warehouse.FRONT + 1))).is_empty())
	assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-15.5, 1, 21), Vector3(-17, 1, 21))).is_empty())
	assert(warehouse.rack_point(15).z < 31)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 0.8, 0.9)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.exclude = [player.get_rid()]
	for lane in [-11.75, -7.8, -3.0, 1.8, 5.75]:
		for index in range(57):
			query.transform = Transform3D(Basis.IDENTITY, Vector3(lane, 1, 15.1 + index * 0.25))
			assert(space.intersect_shape(query).is_empty(), "Warehouse walking lane blocked")
	for z in [18.5, 22.5, 26.5]:
		for index in range(57):
			query.transform = Transform3D(Basis.IDENTITY, Vector3(-10, 1, z) + Vector3(index * 0.25, 0, 0))
			assert(space.intersect_shape(query).is_empty(), "Warehouse cross aisle blocked")
	assert(warehouse.PRODUCT_BAY.has_point(Vector2(ops.drop_point.x, ops.drop_point.z)))
	assert(warehouse.get_node("ProductBay/BayLabel").basis.z.is_equal_approx(Vector3.UP))
	assert(warehouse.get_node("ProductBay/BayLabel").basis.x.is_equal_approx(Vector3.LEFT))
	for slot in range(20):
		var point: Vector3 = ops.product_delivery_point(slot)
		assert(warehouse.PRODUCT_BAY.encloses(Rect2(Vector2(point.x, point.z) - Vector2.ONE * 0.3, Vector2.ONE * 0.6)))
	for package in warehouse.furniture_boxes:
		if package.visible: assert(warehouse.RACK_BAY.has_point(Vector2(package.position.x, package.position.z)))
	player.global_position = Vector3(-14.2, 0.1, 18)
	player.camera.global_position = player.global_position + Vector3(0, 1.6, 0)
	player.camera.look_at(warehouse.computer.global_position)
	assert(warehouse.computer_target() and warehouse.try_interact())
	var menu = current_scene.get_node("Ui/SupplierMenu")
	assert(menu.visible and menu.get_node("TitleLabel").text == "WAREHOUSE ORDERS")
	assert(menu.company_column.visible and menu.company_list.item_count == 2)
	menu.company_list.item_selected.emit(1)
	assert(menu.tabs.current_tab == 4 and menu.get_node("BuyRackButton").visible)
	menu.company_list.item_selected.emit(0)
	assert(menu.tabs.current_tab == 0 and menu.order_button.visible)
	var close_event := InputEventKey.new()
	close_event.keycode = KEY_E
	close_event.pressed = true
	Input.parse_input_event(close_event)
	Input.flush_buffered_events()
	assert(not menu.visible)
	var packages_before: int = business.logistics.rack_delivered.size()
	assert(business.order_stock("soap") and business.order_racks("bottle", 1))
	assert(ops.delivery_state == ops.DeliveryState.ARRIVING and warehouse.truck_state == warehouse.TruckState.IDLE)
	for frame in range(500):
		ops._process(0.1)
		warehouse._process(0.1)
		assert(not (ops.van.visible and warehouse.truck.visible), "Delivery trucks must queue for the unloading lane")
	assert(business.supply_in_transit == 0 and business.logistics.rack_incoming.is_empty())
	assert(business.logistics.rack_delivered.size() == packages_before + 1)
	assert(ops.delivery_box.visible and ops.delivery_box.position == ops.product_delivery_point(0))
	assert(ops.delivery_box.has_node("Carton") and ops.delivery_box.get_node("SupplierLabel").text == "APNA WHOLESALE")
	assert(warehouse.furniture_boxes[0].get_node("SupplierLabel").text == "RACKWORKS")
	assert(business._is_valid_snapshot(business.snapshot()))
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.current = true
		current_scene.get_node("Landscape").set_camera(camera)
		current_scene.get_node("Player").hide()
		for size in [Vector2i(1152, 648), Vector2i(1920, 1080)]:
			root.size = size
			camera.position = Vector3(-3, 6.5, 3)
			camera.look_at(Vector3(-3, 2.5, 19))
			await _capture(camera, "front")
			camera.position = Vector3(-9.4, 2.4, 9.8)
			camera.look_at(ops.drop_point + Vector3(0.7, 0.4, 0.7))
			await _capture(camera, "products")
			camera.position = Vector3(-3, 2, warehouse.FRONT + 1)
			camera.look_at(Vector3(-3, 2, 25))
			await _capture(camera, "inside")
			camera.position = warehouse.service_point(0) + Vector3(0, 1.6, -0.3)
			camera.look_at(warehouse.rack_point(0) + Vector3(0, 1.6, 0))
			await _capture(camera, "stock")
		menu.open_menu(true)
		menu.tabs.current_tab = 4
		await _capture(camera, "orders")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: bulk rack orders/separate truck/boxed placement, 4x4 warehouse racks, 256 finite box slots, physical storage/retrieval, partial quantities, save/reload, accounting and collisions")
	quit()
