extends SceneTree

const Backend = preload("res://business_backend.gd")
var path: String

func _initialize() -> void:
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
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	for name in ["Player", "Customer", "StockWorker", "Warehouse/WarehouseReceiver"]: current_scene.get_node(name).set_physics_process(false)
	current_scene.get_node("ShopOperations").set_process(false)
	current_scene.get_node("Warehouse").set_process(false)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(OS.get_environment("TEMP").path_join(name + ".png")) == OK)

func _click(terminal, control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	await _click_point(terminal, point)

func _click_point(terminal, point: Vector2) -> void:
	var local := Vector3((point.x / 960 - 0.5) * 0.78, (0.5 - point.y / 540) * 0.44, 0)
	var pixel: Vector2 = terminal.focus_camera.unproject_position(terminal.screen_mesh.to_global(local))
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pixel
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func _run() -> void:
	path = OS.get_environment("TEMP").path_join("office_test_%d.json" % Time.get_ticks_usec())
	var state = Backend.new()
	state.load_progress(path)
	assert(state.hire_warehouse_worker())
	assert(not state.hire_warehouse_worker())
	assert(state.order_stock("soap", 3) and state.receive_delivery())
	assert(state.set_staff_shift("warehouse", 480, 1200))
	assert(state._is_valid_snapshot(state.snapshot()))
	await _reload()
	var warehouse = current_scene.get_node("Warehouse")
	var business = current_scene.get_node("Shop/ShopArea").business
	var receiver = warehouse.receiver
	assert(business.warehouse_worker_hired and business.warehouse_shift_end == 1200)
	assert(not business.stock_worker_hired)
	assert(not warehouse.walk_route(warehouse.office_idle, warehouse.entry).is_empty())
	for id in range(16): assert(not warehouse.walk_route(warehouse.entry, warehouse.service_point(id)).is_empty())
	for frame in range(1000): receiver._physics_process(0.1)
	assert(business.logistics.stored_units("soap") == 30)
	assert(business.logistics.warehouse_carry.is_empty() and business.boxed_stock == 0 and business.queued_boxes.is_empty())
	assert(business.inventory.soap.stock == 0, "Receiver must store boxes, not silently restock shop")
	assert(business.order_stock("bottle", 2) and business.receive_delivery())
	assert(business.warehouse_pick_up_box())
	assert(business.logistics.free_slot(0) == 4)
	assert(business.set_employee_work("warehouse", false))
	var before: Dictionary = business.snapshot()
	for frame in range(100): receiver._physics_process(0.1)
	assert(business.snapshot() == before)
	assert(not business.warehouse_store_carried())
	assert(business.save_progress())
	await _reload()
	warehouse = current_scene.get_node("Warehouse")
	business = current_scene.get_node("Shop/ShopArea").business
	receiver = warehouse.receiver
	assert(not business.staff.records.warehouse.work_enabled)
	assert(business.logistics.warehouse_carry.amount == 10)
	assert(business.set_employee_work("warehouse", true))
	for frame in range(1000): receiver._physics_process(0.1)
	assert(business.logistics.stored_units("bottle") == 20)
	assert(business._is_valid_snapshot(business.snapshot()))
	var terminal = warehouse.computer.get_node("ComputerTerminal")
	var menu = current_scene.get_node("Ui/SupplierMenu")
	var camera: Camera3D = root.get_camera_3d()
	terminal.open(true)
	await create_timer(0.4).timeout
	assert(terminal.active and menu.visible and menu.modulate.a == 0)
	assert(root.get_camera_3d() == terminal.focus_camera)
	var center: Vector2 = terminal.focus_camera.unproject_position(terminal.screen_mesh.global_position)
	assert(terminal.screen_point(center).distance_to(Vector2(480, 270)) < 1)
	menu.tabs.current_tab = 1
	menu.role_input.select(2)
	menu.role_input.item_selected.emit(2)
	terminal._sync()
	assert(terminal.screen_menu.get_node("WarehouseWorkSwitch").visible)
	terminal.screen_menu.get_node("WarehouseWorkSwitch").button_pressed = false
	assert(not business.staff.records.warehouse.work_enabled)
	terminal.screen_menu.get_node("WarehouseWorkSwitch").button_pressed = true
	assert(business.staff.records.warehouse.work_enabled)
	menu.tabs.current_tab = 0
	terminal._sync()
	await _click(terminal, terminal.screen_menu.get_node("ProductSelector"))
	for code in [KEY_HOME, KEY_DOWN, KEY_ENTER]:
		for pressed in [true, false]:
			var selection := InputEventKey.new()
			selection.keycode = code
			selection.pressed = pressed
			Input.parse_input_event(selection)
			Input.flush_buffered_events()
			await process_frame
	assert(menu.product_input.selected == 1, "Product popup selection=%d open=%s" % [menu.product_input.selected, terminal.screen_menu.get_node("ProductSelector").get_popup().visible])
	await _click(terminal, terminal.screen_menu.get_node("ProductSelector"))
	var popup: PopupMenu = terminal.screen_menu.get_node("ProductSelector").get_popup()
	assert(popup.visible)
	await _click_point(terminal, Vector2(popup.position) + Vector2(popup.size.x * 0.5, popup.size.y - 14))
	assert(menu.product_input.selected == menu.product_input.item_count - 1 and not popup.visible, "Mouse product selection must work inside the monitor")
	menu.product_input.select(0)
	menu.product_input.item_selected.emit(0)
	terminal._sync()
	var money_before: int = business.money
	await _click(terminal, terminal.screen_menu.get_node("OrderButton"))
	assert(business.money == money_before - 500 and business.supply_in_transit == 10)
	menu.tabs.current_tab = 1
	terminal._sync()
	if DisplayServer.get_name() != "headless":
		current_scene.get_node("Player").hide()
		for size in [Vector2i(1152, 648), Vector2i(1920, 1080)]:
			root.size = size
			await _capture("office_desktop_%d" % size.x)
		menu.tabs.current_tab = 0
		terminal._sync()
		await _capture("office_orders")
		menu.tabs.current_tab = 1
		terminal._sync()
		var pixels: Image = terminal.screen_viewport.get_texture().get_image()
		var scale := pixels.get_width() / 960
		assert(pixels.get_pixel(40 * scale, 465 * scale).get_luminance() > 0.5)
		assert(pixels.get_pixel(950 * scale, 520 * scale).get_luminance() < 0.3)
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	assert(not terminal.active and not menu.visible and menu.modulate.a == 1)
	assert(root.get_camera_3d() == camera)
	terminal.open(true)
	event = InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	assert(not terminal.active)
	var shop_terminal = current_scene.get_node("ShopOperations").pc.get_node("ComputerTerminal")
	shop_terminal.open()
	assert(shop_terminal.active and menu.active_terminal == shop_terminal)
	shop_terminal.close()
	assert(root.get_camera_3d() == camera and not menu.visible)
	if DisplayServer.get_name() != "headless":
		var overview := Camera3D.new()
		current_scene.add_child(overview)
		overview.current = true
		current_scene.get_node("Landscape").set_camera(overview)
		overview.global_position = Vector3(-14.2, 2.5, 21.5)
		overview.look_at(Vector3(-14.2, 1.2, 17.2))
		await _capture("office_asset")
	var failure = Backend.new()
	failure.save_path = path.path_join("missing.json")
	before = failure.snapshot()
	assert(not failure.hire_warehouse_worker() and failure.snapshot() == before)
	failure.save_path = ""
	assert(failure.hire_warehouse_worker() and failure.order_stock("soap") and failure.receive_delivery())
	failure.save_path = path.path_join("missing.json")
	before = failure.snapshot()
	assert(not failure.warehouse_pick_up_box() and failure.snapshot() == before)
	failure.save_path = ""
	assert(failure.warehouse_pick_up_box())
	assert(failure.set_employee_work("warehouse", false))
	assert(failure.retrieve_receiver_box() and failure.carried_stock == 10 and failure.logistics.warehouse_carry.is_empty())
	assert(failure._is_valid_snapshot(failure.snapshot()))
	var legacy: Dictionary = Backend.new().snapshot()
	for field in ["warehouse_worker_hired", "warehouse_worker_hired_day", "warehouse_shift_start", "warehouse_shift_end"]: legacy.erase(field)
	legacy.staff_relations.records.erase("warehouse")
	legacy.logistics.erase("warehouse_carry")
	assert(failure._is_valid_snapshot(legacy))
	var shared = Backend.new()
	assert(shared.hire_stock_worker() and shared.hire_warehouse_worker())
	assert(shared.order_stock("soap", 2) and shared.receive_delivery() and shared.assign_stock_collection())
	assert(shared.warehouse_pick_up_box() and shared.boxed_stock == 10 and shared.stock_collection_assigned)
	assert(shared.warehouse_store_carried() and not shared.warehouse_pick_up_box())
	assert(shared.pick_up_box(true) and shared.worker_carried_stock == 10)
	assert(shared.logistics.stored_units("soap") == 10 and shared._is_valid_snapshot(shared.snapshot()))
	var life = Backend.new()
	assert(life.hire_warehouse_worker() and life.set_staff_shift("warehouse", 480, 600))
	life.advance_clock(120)
	assert(life.staff.records.warehouse.state == "leave")
	assert(life.staff.reply(life, "warehouse", "overtime") and life.warehouse_worker_on_shift())
	life.advance_clock(60)
	assert(life.staff.records.warehouse.state == "pay" and not life.warehouse_worker_on_shift())
	assert(life.staff.reply(life, "warehouse", "pay") and life.overtime_expenses == 50)
	assert(life._is_valid_snapshot(life.snapshot()))
	life.advance_clock(1260)
	assert(life.wage_expenses == 200 and life.warehouse_worker_on_shift())
	assert(life._is_valid_snapshot(life.snapshot()))
	life.staff.records.warehouse.happiness = 30
	assert(life.staff.reply(life, "warehouse", "rude") and not life.staff.active(life, "warehouse"))
	assert(life._is_valid_snapshot(life.snapshot()))
	assert(life.hire_warehouse_worker() and life.staff.active(life, "warehouse"))
	assert(life._is_valid_snapshot(life.snapshot()))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: imported office, live monitor desktop/camera restore, independent warehouse receiving, shift/work switch persistence, reserved slots, legacy saves, rollback and recoverable stock")
	quit()
