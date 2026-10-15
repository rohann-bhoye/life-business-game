extends SceneTree

const Backend = preload("res://business_backend.gd")
var path := ""

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func _click(tablet, name: String) -> void:
	tablet._process(1)
	var control: Control = tablet.screen_menu.get_node(name)
	var uv := control.get_rect().get_center() / Vector2(tablet.screen_viewport.size)
	var point := Vector3((uv.x - 0.5) * tablet.screen_size.x, (0.5 - uv.y) * tablet.screen_size.y, 0.027)
	var pixel: Vector2 = tablet.get_parent().unproject_position(tablet.to_global(point))
	assert(tablet.screen_point(pixel).distance_to(control.get_rect().get_center()) < 0.01)
	var motion := InputEventMouseMotion.new()
	motion.position = pixel
	root.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pixel
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func _run() -> void:
	path = OS.get_environment("TEMP").path_join("employee_actions_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	root.size = Vector2i(1152, 648)
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Customer").set_physics_process(false)
	var ops = current_scene.get_node("ShopOperations")
	ops.set_process(false)
	var worker = current_scene.get_node("StockWorker")
	worker.set_physics_process(false)
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	player.shop_indoors = true
	player.spring_arm.spring_length = 0
	var shop = current_scene.get_node("Shop/ShopArea")
	var business = shop.business
	var ui = current_scene.get_node("Ui")
	assert(not business.set_employee_work("stock", false))
	assert(not business.set_employee_work("bad_role", true))
	assert(business.hire_stock_worker() and business.hire_worker())
	worker.position = Vector3(-4.6, 0.1, -1.8)
	worker.show()
	player.position = Vector3(-4.6, 1.1, -0.2)
	player.camera.look_at(worker.global_position + Vector3(0, 1.5, 0))
	assert(ops.employee_target() == "stock")
	assert(ops.interaction_hint().contains("Sunil"))
	await _key(KEY_E)
	assert(ui.tablet.visible and ui.selected_tab == 2 and ui.employee_role == "stock")
	assert(ui.shop_menu.get_node("WorkerLabel").text.contains("Sunil"))
	assert(ui.shop_menu.get_node("WorkerStatusLabel").text == "Waiting for delivery")
	var money: int = business.money
	await _click(ui.tablet, "WorkSwitch")
	assert(not business.stock_worker_on_shift() and business.cashier_on_shift(), "stock=%s cashier=%s source=%s copy=%s disabled=%s" % [business.stock_worker_on_shift(), business.cashier_on_shift(), ui.shop_menu.get_node("WorkSwitch").button_pressed, ui.tablet.screen_menu.get_node("WorkSwitch").button_pressed, ui.tablet.screen_menu.get_node("WorkSwitch").disabled])
	assert(business.staff.on_shift(business, "stock") and business.money == money)
	assert(ui.shop_menu.get_node("WorkerStatusLabel").text == "Paused by owner")
	await _click(ui.tablet, "WorkSwitch")
	assert(business.stock_worker_on_shift())
	assert(business.order_stock("soap") and business.receive_delivery())
	await process_frame
	await _click(ui.tablet, "CollectDeliveryButton")
	assert(not worker.route.is_empty())
	for frame in range(500):
		worker._physics_process(0.05)
		if business.worker_carried_stock > 0: break
	assert(business.worker_carried_stock == 10 and business.product_stock("soap") == 0)
	await _click(ui.tablet, "WorkSwitch")
	var position: Vector3 = worker.position
	var route: Array = worker.route.duplicate()
	for frame in range(100): worker._physics_process(0.05)
	assert(worker.position == position and worker.route == route and business.worker_carried_stock == 10)
	assert(not business.shelve_box(true))
	await _click(ui.tablet, "WorkSwitch")
	for frame in range(800):
		worker._physics_process(0.05)
		if worker.route.is_empty(): break
	assert(business.product_stock("soap") == 10 and business.worker_carried_stock == 0)
	await _click(ui.tablet, "AutoCollectSwitch")
	assert(business.assistant_auto_collect)
	await _click(ui.tablet, "CashierSelectButton")
	assert(ui.employee_role == "cashier" and not ui.shop_menu.get_node("AutoCollectSwitch").visible)
	await _click(ui.tablet, "WorkSwitch")
	assert(not business.cashier_on_shift() and business.stock_worker_on_shift(), "role=%s cashier=%s stock=%s source=%s copy=%s" % [ui.employee_role, business.cashier_on_shift(), business.stock_worker_on_shift(), ui.shop_menu.get_node("WorkSwitch").button_pressed, ui.tablet.screen_menu.get_node("WorkSwitch").button_pressed])
	var visitor = current_scene.get_node("Customer")
	player.position = Vector3(-4.6, 1.1, -4)
	visitor.state = visitor.State.SCANNING
	visitor.has_product = true
	visitor.product_id = "bottle"
	visitor.basket_count = 1
	visitor.scanned_count = 0
	visitor.agreed_unit_price = 100
	visitor.quoted_price = 100
	visitor.wants_discount = false
	visitor.spending_budget = 200
	visitor.bargain_seconds_left = 60
	visitor.auto_checkout_seconds = business.cashier_scan_seconds()
	ops.enqueue(visitor)
	ops.show_basket(visitor)
	visitor._physics_process(5)
	assert(visitor.scanned_count == 0 and business.items_sold == 0)
	assert(business.set_employee_work("cashier", true))
	visitor._physics_process(3)
	assert(visitor.scanned_count == 1 and visitor.state == visitor.State.PAYING)
	assert(business.set_employee_work("cashier", false))
	visitor._physics_process(3)
	assert(business.items_sold == 0)
	assert(business.set_employee_work("cashier", true))
	visitor._physics_process(1)
	assert(business.items_sold == 1)
	assert(business.set_employee_work("cashier", false))
	assert(business.save_progress())
	var restored = Backend.new()
	restored.load_progress(path)
	assert(not restored.cashier_on_shift() and restored.stock_worker_on_shift() and restored.assistant_auto_collect)
	var legacy: Dictionary = business.snapshot()
	for role in business.staff.ROLES: legacy.staff_relations.records[role].erase("work_enabled")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated = Backend.new()
	migrated.load_progress(path)
	assert(migrated.cashier_on_shift() and migrated.stock_worker_on_shift())
	legacy.staff_relations.records.stock.work_enabled = "off"
	assert(not business._is_valid_snapshot(legacy))
	await _key(KEY_ESCAPE)
	assert(not player._menu_is_open())
	# Looking at the employee must win over the nearby checkout interaction.
	shop.worker.show()
	player.position = Vector3(-2.5, 1.1, 0.5)
	player.camera.look_at(shop.worker.global_position + Vector3(0, 1.5, 0))
	assert(ops.player_at_counter() and ops.employee_target() == "cashier")
	await _key(KEY_E)
	assert(ui.tablet.visible and ui.employee_role == "cashier" and not ui.checkout_menu.visible)
	for role in ["cashier", "stock"]:
		ui.employee_role = role
		for size in [Vector2i(1152, 648), Vector2i(360, 640)]:
			root.size = size
			await process_frame
			await process_frame
			ui.tablet._process(1)
			var controls = ui.tablet.screen_menu.get_children().filter(func(node): return node is Control and node.visible)
			for i in range(controls.size()):
				assert(Rect2(Vector2.ZERO, ui.tablet.screen_menu.size).encloses(controls[i].get_rect()), str(controls[i].name))
				assert(controls[i].get_combined_minimum_size().x <= controls[i].size.x, str(controls[i].name))
				for j in range(i + 1, controls.size()): assert(not controls[i].get_rect().intersects(controls[j].get_rect()), "%s overlaps %s" % [controls[i].name, controls[j].name])
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("employee_tablet_%s_%dx%d.png" % [role, size.x, size.y])) == OK)
	business.save_path = ""
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: aimed employee E priority, tablet role selection, clickable work switches, independent jobs, paused box resume, Sunil soap restocking, opt-in collection, persistent switches, old-save defaults and validation")
	quit()
