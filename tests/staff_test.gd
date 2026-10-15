extends SceneTree

const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("life_business_staff_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	assert(not img.is_empty())
	assert(img.save_png(OS.get_environment("TEMP").path_join("staff_%s.png" % label)) == OK)

func _check_layout(menu: Panel) -> void:
	assert(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(menu.get_rect()))
	var controls = menu.get_children().filter(func(node): return node is Control and node.visible)
	for index in range(controls.size()):
		assert(Rect2(Vector2.ZERO, menu.size).encloses(controls[index].get_rect()), str(controls[index].name))
		assert(controls[index].get_combined_minimum_size().x <= controls[index].size.x, str(controls[index].name))
		for other in range(index + 1, controls.size()):
			assert(not controls[index].get_rect().intersects(controls[other].get_rect()), "%s %s overlaps %s %s" % [controls[index].name, controls[index].get_rect(), controls[other].name, controls[other].get_rect()])

func _run() -> void:
	for level in range(1, 4):
		var state = Backend.new()
		assert(not state.hire_worker(0) and not state.hire_worker(4))
		assert(state.hire_worker(level) and not state.hire_worker(level))
		assert(state.money == 50000 - level * 1000 and state.cashier_scan_seconds() == 4.0 - level)
		assert(state.hire_stock_worker())
		assert(state.set_staff_shift("cashier", 540, 1020))
		assert(state.set_staff_shift("stock", 600, 1080))
		var before: Dictionary = state.snapshot()
		for shift in [[300, 480], [480, 1380], [600, 600], [720, 480], [481, 600]]:
			assert(not state.set_staff_shift("cashier", shift[0], shift[1]))
		assert(not state.set_staff_shift("other", 480, 1200) and before == state.snapshot())
		for minute in [539, 540, 599, 600, 1019, 1020, 1079, 1080]:
			state.minutes_of_day = minute
			assert(state.cashier_on_shift() == (minute >= 540 and minute < 1020))
			assert(state.stock_worker_on_shift() == (minute >= 600 and minute < 1080))
		state.minutes_of_day = 600
		state.wages_due = 200
		assert(not state.cashier_on_shift() and not state.stock_worker_on_shift())
		state.wages_due = 0
		state.advance_clock(1440)
		assert(state.wage_expenses == 400)
		state.save_path = _path()
		assert(state.save_progress())
		var loaded = Backend.new()
		loaded.load_progress(state.save_path)
		assert(loaded.snapshot() == state.snapshot())
		for field in Backend.EMPLOYEE_FIELDS:
			var corrupt: Dictionary = state.snapshot()
			corrupt[field] = 1.5
			assert(not state._is_valid_snapshot(corrupt))
	var old = Backend.new()
	assert(old.hire_worker() and old.hire_stock_worker() and old.order_stock() and old.receive_delivery() and old.pick_up_box(true))
	var legacy: Dictionary = old.snapshot()
	legacy["version"] = 7
	for field in ["staff_relations", "overtime_expenses", "inventory", "pending_product", "assistant_auto_collect"]: legacy.erase(field)
	for field in Backend.EMPLOYEE_FIELDS: legacy.erase(field)
	var legacy_path := _path()
	_write(legacy_path, legacy)
	var migrated = Backend.new()
	migrated.load_progress(legacy_path)
	assert(migrated.worker_hired and migrated.stock_worker_hired and migrated.worker_carried_stock == 10)
	assert(migrated.cashier_level == 1 and migrated.cashier_shift_start == 480 and migrated.stock_shift_end == 1200)
	assert(migrated.money == old.money and migrated.save_progress())
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
	var shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	var ops = current_scene.get_node("ShopOperations")
	ops.set_process(false)
	var helper = current_scene.get_node("StockWorker")
	helper.set_physics_process(false)
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(-1.1, 1.1, -0.7)
	player.rotation.y = 0
	player.camera_pivot.rotation.x = deg_to_rad(-12)
	player.spring_arm.spring_length = 0
	var menu = current_scene.get_node("Ui").supplier_menu
	menu.open_menu()
	menu.tabs.current_tab = 1
	menu.level_input.select(2)
	menu.level_input.item_selected.emit(2)
	assert(menu.cashier_button.text.contains("3,000") and menu.contract_label.text.contains("1s"))
	await _capture("hiring")
	menu.cashier_button.pressed.emit()
	assert(shop.business.cashier_level == 3 and shop.money == 47000)
	assert((-shop.worker.global_basis.z).dot(Vector3.BACK) > 0.99)
	menu.start_hour.get_line_edit().text = "9"
	menu.end_hour.get_line_edit().text = "17"
	menu.shift_button.pressed.emit()
	assert(shop.business.cashier_shift_start == 540 and shop.business.cashier_shift_end == 1020)
	assert(menu.cashier_label.text.contains("Off shift"))
	menu.role_input.select(1)
	menu.role_input.item_selected.emit(1)
	menu.stock_worker_button.pressed.emit()
	menu.start_hour.get_line_edit().text = "10"
	menu.end_hour.get_line_edit().text = "18"
	menu.shift_button.pressed.emit()
	assert(shop.business.stock_shift_start == 600)
	for viewport_size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = viewport_size
		await process_frame
		menu._layout()
		for role in range(2):
			menu.role_input.select(role)
			menu.role_input.item_selected.emit(role)
			_check_layout(menu)
		menu.tabs.current_tab = 2
		_check_layout(menu)
		menu.tabs.current_tab = 3
		_check_layout(menu)
		menu.tabs.current_tab = 1
		await _capture("menu_%d" % viewport_size.x)
	root.size = Vector2i(1152, 648)
	await process_frame
	menu.close_menu()
	assert(shop.business.order_stock() and shop.business.receive_delivery())
	assert(not helper.assign_delivery())
	shop.business.advance_clock(120)
	assert(helper.assign_delivery())
	for frame in range(1200):
		if shop.business.worker_carried_stock > 0: break
		helper._physics_process(0.05)
	assert(shop.business.worker_carried_stock == 10 and shop.stock == 10)
	assert(shop.business.set_staff_shift("stock", 480, 600))
	var paused: Vector3 = helper.position
	helper._physics_process(100)
	assert(helper.position == paused and shop.stock == 10 and not shop.business.shelve_box(true))
	assert(shop.business.set_staff_shift("stock", 480, 1200))
	for frame in range(1200):
		if shop.business.worker_carried_stock == 0: break
		helper._physics_process(0.05)
	assert(shop.stock == 20)
	var visitor = current_scene.get_node("Customer")
	visitor.set_physics_process(false)
	visitor.shopping_quantity = 3
	visitor.wants_discount = false
	visitor.spending_budget = 200
	for frame in range(1200):
		if visitor.state == visitor.State.SCANNING: break
		visitor._physics_process(0.05)
	assert(visitor.state == visitor.State.SCANNING)
	var before_money: int = shop.money
	for level in range(1, 4):
		# Each level uses a fresh timer, without changing the financial ledger.
		var duration: float = Backend.CASHIER_SCAN_SECONDS[level - 1]
		var saved_level: int = shop.business.cashier_level
		shop.business.cashier_level = level
		visitor.cashier_active = false
		visitor._physics_process(duration - 0.1)
		assert(visitor.scanned_count == level - 1 and shop.money == before_money and shop.stock == 20)
		visitor._physics_process(0.11)
		assert(visitor.scanned_count == level and shop.money == before_money)
		shop.business.cashier_level = saved_level
	assert(visitor.state == visitor.State.PAYING)
	visitor._physics_process(0.5)
	assert(shop.money == before_money)
	visitor._physics_process(0.51)
	assert(shop.money == before_money + 300 and shop.stock == 17)
	assert(shop.business._is_valid_snapshot(shop.business.snapshot()))
	visitor.queue_free()
	await process_frame
	current_scene.get_node("CustomerSpawner")._on_spawn_timer_timeout()
	visitor = current_scene.get_node("CustomerSpawner").active_customer
	visitor.set_physics_process(false)
	visitor.shopping_quantity = 2
	visitor.wants_discount = false
	visitor.spending_budget = 200
	for frame in range(1200):
		if visitor.state == visitor.State.SCANNING: break
		visitor._physics_process(0.05)
	assert(visitor.state == visitor.State.SCANNING)
	assert(shop.business.set_staff_shift("cashier", 480, 600))
	visitor._physics_process(4)
	assert(visitor.scanned_count == 0)
	assert(shop.business.set_staff_shift("cashier", 480, 1200))
	player.global_position = Vector3(-2.5, 1.1, -0.6)
	visitor._physics_process(4)
	assert(visitor.scanned_count == 0)
	player.global_position = Vector3(-1.0, 1.1, 1.6)
	visitor._physics_process(0.5)
	assert(visitor.scanned_count == 0)
	ops._process(0)
	player.rotation.y = 0.6
	player.camera_pivot.rotation.x = deg_to_rad(-8)
	player.spring_arm.spring_length = 0
	visitor.hide()
	await physics_frame
	await physics_frame
	await _capture("facing")
	visitor.show()
	visitor._physics_process(0.51)
	assert(visitor.scanned_count == 1 and shop.worker.get_node("CharacterVisual").work_remaining > 0)
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: staff facing, three hiring levels and timed scans, payment guards, independent shifts and boundaries, wages, paused physical deliveries, v7 migration, saves, responsive staff forms")
	quit()
