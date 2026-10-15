extends SceneTree

const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("life_business_physical_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _reload(state) -> void:
	var path := _path()
	state.load_progress(path)
	assert(state.save_progress())
	var loaded = Backend.new()
	loaded.load_progress(path)
	assert(loaded.snapshot() == state.snapshot())
	assert(loaded._is_valid_snapshot(loaded.snapshot()))

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	assert(img.get_pixel(img.get_width() / 2, img.get_height() / 2) != img.get_pixel(0, 0))
	assert(img.save_png(OS.get_environment("TEMP").path_join("physical_shop_%s.png" % label)) == OK)

func _walk(key: Key, seconds: float) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(seconds).timeout
	event = InputEventKey.new()
	event.keycode = key
	Input.parse_input_event(event)
	await physics_frame

func _advance(customer, target: int) -> void:
	for index in range(1200):
		if customer.state == target: return
		customer._physics_process(0.05)
	assert(false, "Customer did not reach state %d: %d" % [target, customer.state])

func _check_walkway(points: Array[Vector3], player: CharacterBody3D) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 1.98
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	var excluded: Array[RID] = [player.get_rid()]
	# Moving entrance panels have their own open/closed regression coverage.
	for panel in current_scene.get_node("ShopOperations/SlidingDoor").panels:
		excluded.append(panel.get_rid())
	query.exclude = excluded
	for index in range(points.size() - 1):
		var count := ceili(points[index].distance_to(points[index + 1]) / 0.1)
		for step in range(count + 1):
			var point := points[index].lerp(points[index + 1], float(step) / count)
			query.transform = Transform3D(Basis.IDENTITY, point + Vector3(0, 1.02, 0))
			var hits: Array = current_scene.get_world_3d().direct_space_state.intersect_shape(query)
			assert(hits.is_empty(), "Blocked walkway at %s: %s" % [point, hits])

func _run() -> void:
	var state = Backend.new()
	assert(state.order_stock())
	assert(state.money == 49500 and state.stock == 10 and state.supply_in_transit == 10)
	assert(state.can_order_stock() and not state.order_stock("bottle", 0) and not state.pick_up_box() and not state.shelve_box())
	_reload(state)
	assert(state.receive_delivery() and not state.receive_delivery())
	_reload(state)
	assert(state.pick_up_box() and not state.pick_up_box())
	_reload(state)
	assert(state.drop_box() and not state.drop_box())
	assert(state.pick_up_box() and state.shelve_box())
	assert(state.stock == 20 and state.money == 49500 and not state.shelve_box())
	_reload(state)
	assert(state.order_stock() and state.receive_delivery() and state.pick_up_box() and state.shelve_box())
	assert(state.stock == 30 and state.money == 49000)
	var invalid: Dictionary = state.snapshot()
	invalid["boxed_stock"] = 10
	invalid["carried_stock"] = 10
	assert(not state._is_valid_snapshot(invalid))
	var legacy: Dictionary = state.snapshot()
	legacy["version"] = 5
	for field in ["staff_relations", "overtime_expenses", "inventory", "pending_product", "assistant_auto_collect"]: legacy.erase(field)
	for field in Backend.EMPLOYEE_FIELDS: legacy.erase(field)
	for field in Backend.STAFF_FIELDS + ["stock_worker_hired"]: legacy.erase(field)
	for field in Backend.SUPPLY_FIELDS: legacy.erase(field)
	var legacy_path := _path()
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated = Backend.new()
	migrated.load_progress(legacy_path)
	assert(migrated.stock == 30 and migrated.money == 49000 and migrated.supply_in_transit == 0)

	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = _path()
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	var shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	var operations = current_scene.get_node("ShopOperations")
	operations.set_process(false)
	var player = current_scene.get_node("Player")
	assert(player.global_position.x >= 0.6)
	var spawner = current_scene.get_node("CustomerSpawner")
	spawner.get_node("SpawnTimer").stop()
	var customer = current_scene.get_node("Customer")
	customer.set_physics_process(false)
	assert(current_scene.get_node("Shop").mesh == null)
	assert(operations.available_stock() == 10 and operations.rack_bottles[9].visible and not operations.rack_bottles[10].visible)
	player.global_position = Vector3(-1.1, 1.1, -0.7)
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await physics_frame
	await process_frame
	assert(player.shop_indoors and player._menu_is_open() == false)
	assert(is_zero_approx(player.spring_arm.spring_length))
	_check_walkway([Vector3(-3, 0.1, 3.8), Vector3(-3, 0.1, 1.65), Vector3(-4.6, 0.1, 1.65), Vector3(-4.6, 0.1, -0.6), operations.cashier_point, Vector3(-1.1, 0.1, -0.7)], player)
	assert(operations.try_interact())
	var menu = current_scene.get_node("Ui/SupplierMenu")
	assert(menu.visible and player._menu_is_open())
	var pc_position: Vector3 = player.global_position
	await _walk(KEY_W, 0.1)
	assert(is_equal_approx(player.global_position.z, pc_position.z))
	for size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		menu._layout()
		var controls = menu.get_children().filter(func(node): return node is Control and node.visible)
		for index in range(controls.size()):
			assert(Rect2(Vector2.ZERO, menu.size).encloses(controls[index].get_rect()))
			assert(controls[index].get_combined_minimum_size().x <= controls[index].size.x)
			for other in range(index + 1, controls.size()):
				assert(not controls[index].get_rect().intersects(controls[other].get_rect()))
		if size == Vector2i(360, 640): await _capture("supplier_mobile")
	root.size = Vector2i(1152, 648)
	await process_frame
	menu.order_button.pressed.emit()
	assert(shop.money == 49500 and shop.stock == 10 and not menu.order_button.disabled)
	await _capture("supplier")
	menu.close_menu()
	assert(not player._menu_is_open())
	player.global_position = Vector3(-3, 1.1, 3.8)
	player.rotation.y = 0
	player.velocity = Vector3.ZERO
	await _walk(KEY_W, 0.6)
	assert(player.global_position.z < 2.4 and player.shop_indoors)
	await _walk(KEY_S, 0.8)
	await physics_frame
	await physics_frame
	assert(not player.shop_indoors and player.global_position.z > 3.4)
	operations._process(5.0)
	assert(operations.delivery_state == operations.DeliveryState.UNLOADING)
	var delivery_camera := Camera3D.new()
	current_scene.add_child(delivery_camera)
	delivery_camera.global_position = Vector3(-12, 3.8, 12)
	delivery_camera.look_at(operations.van.global_position + Vector3(0, 1, 0))
	delivery_camera.make_current()
	await _capture("van")
	delivery_camera.queue_free()
	player.camera.make_current()
	operations._process(2.0)
	assert(shop.business.boxed_stock == 10 and operations.delivery_box.visible)
	player.global_position = operations.drop_point + Vector3(0, 1, 1.3)
	player.rotation.y = 0
	player.camera_pivot.rotation.x = deg_to_rad(-12)
	await physics_frame
	await physics_frame
	await _capture("delivery")
	assert(operations.try_interact())
	assert(shop.business.carried_stock == 10 and operations.carried_box.visible and not operations.delivery_box.visible)
	player.global_position = Vector3(-3, 1.1, 1.65)
	player.rotation.y = PI / 2
	player.camera_pivot.rotation.x = deg_to_rad(-12)
	await physics_frame
	await physics_frame
	await physics_frame
	await _capture("carrying")
	operations._process(10.0)
	assert(not operations.van.visible)
	player.global_position = Vector3(-4.6, 1.1, -0.5)
	for remaining in range(9, -1, -1):
		assert(operations.try_interact() and shop.business.carried_stock == remaining)
	assert(shop.stock == 20 and shop.business.carried_stock == 0)
	customer.wants_discount = false
	customer.spending_budget = 200
	customer.shopping_quantity = 1
	_advance(customer, customer.State.SCANNING)
	assert(customer.has_product and operations.checkout_items[0].visible and operations.available_stock() == 19 and shop.stock == 20)
	spawner._on_spawn_timer_timeout()
	spawner._on_spawn_timer_timeout()
	spawner._on_spawn_timer_timeout()
	assert(spawner.customers.size() == 3)
	for visitor in spawner.customers:
		visitor.set_physics_process(false)
		visitor.shopping_quantity = 1
		if visitor != customer: _advance(visitor, visitor.State.QUEUING)
	assert(operations.queue.size() == 3 and operations.available_stock() == 17)
	for visitor in operations.queue:
		visitor.global_position = operations.queue_position(visitor)
	player.global_position = Vector3(-2.5, 1.1, -0.6)
	player.rotation.y = PI
	player.camera_pivot.rotation.x = deg_to_rad(-12)
	await physics_frame
	await physics_frame
	await _capture("queue")
	player.camera.look_at(operations.checkout_items[0].global_position + Vector3(0, 0.15, 0))
	assert(operations.try_interact())
	var checkout = current_scene.get_node("Ui/CheckoutMenu")
	assert(checkout.visible)
	checkout.payment_buttons[customer.payment_method].pressed.emit()
	assert(shop.stock == 19 and shop.money == 49600 and operations.queue.size() == 2)
	customer.complete_checkout()
	assert(shop.money == 49600)
	var next = operations.checkout_customer()
	next.spending_budget = 200
	next.wants_discount = true
	next.personality = 0
	_advance(next, next.State.SCANNING)
	assert(next.scan_next())
	assert(next.resolve_bargain("accept"))
	next.complete_checkout()
	assert(shop.stock == 18 and shop.money == 49680 and operations.queue.size() == 1)
	var last = operations.checkout_customer()
	last.wants_discount = false
	last.spending_budget = 200
	_advance(last, last.State.SCANNING)
	last._physics_process(61.0)
	assert(last.state == last.State.LEAVING and not last.has_product)
	assert(shop.stock == 18 and operations.available_stock() == 18 and operations.queue.is_empty())
	assert(shop.business._is_valid_snapshot(shop.business.snapshot()))
	assert(shop.business.hire_worker())
	player.global_position = Vector3(4, 1.1, 1)
	spawner.customers.clear()
	spawner._on_spawn_timer_timeout()
	var automatic = spawner.active_customer
	automatic.set_physics_process(false)
	automatic.spending_budget = 200
	automatic.shopping_quantity = 1
	_advance(automatic, automatic.State.LEAVING)
	assert(automatic.deal_sold and shop.stock == 17)
	while shop.stock > 2: assert(shop.business.sell_one_stock(200))
	shop.worker._on_restock_timer_timeout()
	assert(shop.business.supply_in_transit == 0 and shop.stock == 2)
	assert(shop.business.order_stock())
	operations._process(5)
	operations._process(2)
	shop.worker._on_restock_timer_timeout()
	assert(shop.stock == 2 and shop.business.boxed_stock == 10)
	assert(shop.business.pick_up_box() and shop.business.shelve_box())
	assert(shop.business._is_valid_snapshot(shop.business.snapshot()))
	spawner.customers.clear()
	spawner._on_spawn_timer_timeout()
	var closing = spawner.active_customer
	closing.set_physics_process(false)
	closing.wants_discount = false
	player.global_position = Vector3(-2.5, 1.1, -0.6)
	_advance(closing, closing.State.SCANNING)
	var stock_before_close: int = shop.stock
	shop.business.advance_clock(720)
	closing._physics_process(0.05)
	assert(closing.state == closing.State.LEAVING and not closing.has_product)
	assert(shop.stock == stock_before_close and operations.queue.is_empty())
	assert(operations.available_stock() == shop.stock)
	shop.business.minutes_of_day = 480.0
	shop.business.clock_changed.emit()
	player.global_position = Vector3(-3.8, 1.1, -1.8)
	player.rotation.y = PI
	player.camera_pivot.rotation.x = deg_to_rad(-12)
	await physics_frame
	await physics_frame
	await _capture("room")
	# Rebuild the real scene at every saved delivery stage, without touching user progress.
	for stage in range(3):
		var saved = Backend.new()
		assert(saved.order_stock())
		if stage >= 1: assert(saved.receive_delivery())
		if stage == 2: assert(saved.pick_up_box())
		var saved_path := _path()
		saved.load_progress(saved_path)
		assert(saved.save_progress())
		var restart = load("res://main.tscn.tscn").instantiate()
		restart.get_node("Shop/ShopArea").save_path = saved_path
		var restart_packed := PackedScene.new()
		assert(restart_packed.pack(restart) == OK)
		restart.free()
		change_scene_to_packed(restart_packed)
		await scene_changed
		await process_frame
		current_scene.get_node("DayClock").set_process(false)
		current_scene.get_node("Customer").set_physics_process(false)
		current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
		var restored = current_scene.get_node("ShopOperations")
		restored.set_process(false)
		var restored_business = current_scene.get_node("Shop/ShopArea").business
		assert(restored_business.money == 49500 and restored_business.stock == 10)
		assert(restored.van.visible == (stage == 0))
		assert(restored.delivery_box.visible == (stage == 1))
		assert(restored.carried_box.visible == (stage == 2))
		restored_business.save_path = ""
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: physical shop, PC ordering, duplicate guards, delivery van/box, carrying/shelving, queue, checkout/bargaining, returned products, worker fulfillment, save stages and v5 migration")
	quit()
