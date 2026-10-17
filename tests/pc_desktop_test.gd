extends SceneTree

# Shop PC: full-screen view, APNA OS desktop apps and the APNA Jobs staff page,
# driven by real mouse clicks through the monitor.
var path: String

func _initialize() -> void:
	call_deferred("_run")

func _click(terminal, control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
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
	path = OS.get_environment("TEMP").path_join("pc_desktop_test_%d.json" % Time.get_ticks_usec())
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
	current_scene.get_node("Player").set_physics_process(false)
	var business = current_scene.get_node("Shop/ShopArea").business
	var camera: Camera3D = root.get_camera_3d()
	var terminal = current_scene.get_node("ShopOperations").pc.get_node("ComputerTerminal")
	terminal.open()
	await create_timer(0.5).timeout
	# Full screen: the sharp overlay covers exactly where the monitor is drawn.
	assert(terminal.active and terminal.app == "home" and terminal.overlay.visible)
	assert(not terminal.screen_menu.visible and not terminal.staff.visible)
	var rect: Rect2 = Rect2(terminal.overlay_image.position, terminal.overlay_image.size)
	assert(rect.size.x >= root.size.x - 2 or rect.size.y >= root.size.y - 2, "PC screen must fill the window: %s" % rect)
	assert(rect.get_center().distance_to(terminal.focus_camera.unproject_position(terminal.screen_mesh.global_position)) < 1.0)
	assert(terminal.screen_point(rect.get_center()).distance_to(Vector2(480, 270)) < 1.0)
	assert(terminal.screen_viewport.size == Vector2i(1920, 1080))
	# Staff app: hire Sunil, change his hours and give him a day off.
	await _click(terminal, terminal.desktop.get_node("App_staff"))
	assert(terminal.app == "staff" and terminal.staff.visible)
	var staff = terminal.staff
	var money: int = business.money
	await _click(terminal, staff.cards.stock.hire)
	assert(business.stock_worker_hired and business.money == money - business.HIRING_COST)
	assert(staff.selected == "stock" and staff.cards.stock.hire.text == "Manage")
	assert(staff.cards.stock.badge.text in ["ON DUTY", "OFF SHIFT"])
	await _click(terminal, staff.manage.rows.end.minus)
	await _click(terminal, staff.manage.rows.end.minus)
	assert(staff.end_hour == business.stock_shift_end / 60 - 2)
	await _click(terminal, staff.manage.save)
	assert(business.stock_shift_end == staff.end_hour * 60 and staff.manage.save.disabled)
	await _click(terminal, staff.manage.work)
	assert(not business.staff.records.stock.work_enabled and staff.cards.stock.badge.text == "DAY OFF")
	await _click(terminal, staff.manage.work)
	assert(business.staff.records.stock.work_enabled)
	# Cashier level chips change the hiring price before hiring.
	staff.select_role("cashier")
	await _click(terminal, staff.level_buttons[2])
	assert(staff.level == 3 and staff.cards.cashier.hire.text.ends_with("3,000"))
	await _click(terminal, staff.find_child("BackButton", true, false))
	assert(terminal.app == "home" and not staff.visible)
	# Shop Manager: staff tabs live in the Staff app; its close button goes home.
	await _click(terminal, terminal.desktop.get_node("App_manager"))
	assert(terminal.app == "manager" and terminal.screen_menu.visible)
	var tabs: TabBar = terminal.screen_menu.get_node("ManagementTabs")
	assert(tabs.is_tab_hidden(1) and tabs.is_tab_hidden(3) and not tabs.is_tab_hidden(0))
	await _click(terminal, terminal.screen_menu.get_node("CloseButton"))
	assert(terminal.active and terminal.app == "home" and not terminal.screen_menu.visible)
	await _click(terminal, terminal.desktop.get_node("Task_bank"))
	assert(terminal.bank.visible and terminal.app == "bank")
	await _click(terminal, terminal.desktop.get_node("Task_store"))
	assert(terminal.store.visible and not terminal.bank.visible)
	await _click(terminal, terminal.desktop.get_node("ExitButton"))
	assert(not terminal.active and not terminal.overlay.visible and root.get_camera_3d() == camera)
	# Esc also leaves, and the PC opens on the desktop again.
	terminal.open()
	assert(terminal.app == "home")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	assert(not terminal.active and not terminal.overlay.visible)
	business.save_path = ""
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: full-screen shop PC, APNA OS desktop apps, staff hiring cards, work hours, day off, cashier levels and exit")
	quit()
