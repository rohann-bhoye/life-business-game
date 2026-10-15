extends SceneTree

const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("life_business_employee_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _reload(state) -> void:
	state.save_path = _path()
	assert(state.save_progress())
	var other = Backend.new()
	other.load_progress(state.save_path)
	assert(other.snapshot() == state.snapshot())

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("employee_%s.png" % label)) == OK)

func _layout(menu: Panel) -> void:
	var controls = menu.get_children().filter(func(node): return node is Control and node.visible)
	for index in range(controls.size()):
		assert(Rect2(Vector2.ZERO, menu.size).encloses(controls[index].get_rect()), str(controls[index].name))
		assert(controls[index].get_combined_minimum_size().x <= controls[index].size.x, str(controls[index].name))
		for other in range(index + 1, controls.size()): assert(not controls[index].get_rect().intersects(controls[other].get_rect()))

func _run() -> void:
	var tired = Backend.new()
	assert(tired.hire_worker() and tired.set_staff_shift("cashier", 480, 600))
	tired.staff.records.cashier.happiness = 35
	tired.advance_clock(120)
	assert(tired.staff.reply(tired, "cashier", "overtime"))
	assert(not tired.cashier_on_shift() and tired.staff.records.cashier.unpaid == 0 and tired.staff.records.cashier.message.contains("can't stay"))
	var poor = Backend.new()
	assert(poor.hire_worker() and poor.set_staff_shift("cashier", 480, 600))
	poor.advance_clock(120)
	assert(poor.staff.reply(poor, "cashier", "overtime"))
	poor.advance_clock(60)
	poor.money = 49
	assert(not poor.staff.reply(poor, "cashier", "pay") and poor.money == 49 and poor.staff.records.cashier.unpaid == 50)
	var state = Backend.new()
	assert(state.hire_worker(2) and state.hire_stock_worker())
	assert(state.set_staff_shift("cashier", 480, 600))
	assert(state.set_staff_shift("stock", 480, 600))
	state.advance_clock(120)
	assert(state.staff.pending_role() == "cashier" and not state.cashier_on_shift())
	_reload(state)
	var cash: int = state.money
	assert(state.staff.reply(state, "cashier", "overtime"))
	assert(state.money == cash and state.cashier_on_shift() and state.staff.records.cashier.unpaid == 50)
	assert(not state.staff.reply(state, "cashier", "overtime") and not state.staff.reply(state, "cashier", "pay"))
	assert(state.staff.reply(state, "stock", "home") and not state.staff.reply(state, "stock", "home"))
	state.advance_clock(59)
	assert(state.staff.records.cashier.state == "done")
	state.advance_clock(1)
	assert(state.staff.records.cashier.state == "pay" and not state.cashier_on_shift())
	assert(state.staff.reply(state, "cashier", "pay") and state.money == cash - 50 and state.overtime_expenses == 50)
	assert(not state.staff.reply(state, "cashier", "pay"))
	assert(state.staff.reply(state, "cashier", "kind") and not state.staff.reply(state, "cashier", "kind"))
	_reload(state)
	state.advance_clock(1380)
	assert(state.staff.records.cashier.state == "leave")
	assert(state.staff.reply(state, "cashier", "insist"))
	state.advance_clock(60)
	assert(state.staff.reply(state, "cashier", "refuse"))
	assert(state.staff.records.cashier.unpaid == 50 and state.overtime_expenses == 50)
	state.advance_clock(1380)
	assert(state.staff.reply(state, "cashier", "rude"))
	assert(state.staff.records.cashier.quit_day > 0 and not state.worker_on_duty())
	assert(not state.hire_worker())
	assert(state.staff.reply(state, "cashier", "pay"))
	assert(state.hire_worker(3) and state.cashier_level == 3 and state.staff.records.cashier.happiness == 70)
	_reload(state)
	assert(state.order_stock() and state.receive_delivery())
	state.minutes_of_day = 500
	assert(state.pick_up_box(true))
	state.staff.records.stock.happiness = 30
	assert(state.staff.reply(state, "stock", "rude"))
	assert(state.worker_carried_stock == 0 and state.boxed_stock == 10 and state.stock == 10)
	assert(state.hire_stock_worker())
	_reload(state)
	var corrupt: Dictionary = state.snapshot()
	corrupt.staff_relations.records.cashier.happiness = 101
	assert(not state._is_valid_snapshot(corrupt))
	var old = Backend.new()
	assert(old.hire_worker())
	var legacy: Dictionary = old.snapshot()
	legacy.version = 8
	legacy.erase("staff_relations")
	legacy.erase("overtime_expenses")
	for field in ["inventory", "pending_product", "assistant_auto_collect"]: legacy.erase(field)
	var migration_path := _path()
	var file := FileAccess.open(migration_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated = Backend.new()
	migrated.load_progress(migration_path)
	assert(migrated.money == 49000 and migrated.staff.records.cashier.happiness == 70)
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
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	var ops = current_scene.get_node("ShopOperations")
	ops.set_process(false)
	current_scene.get_node("StockWorker").set_physics_process(false)
	var visitor = current_scene.get_node("Customer")
	visitor.set_physics_process(false)
	visitor.hide()
	var shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	var door = ops.get_node("SlidingDoor")
	door.set_process(false)
	player.position = Vector3(3, 1.1, 6)
	door._process(2)
	assert(door.openness == 0)
	player.position = Vector3(-3, 1.1, 3.7)
	door._process(0.5)
	assert(door.openness == 1)
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(-3.2, 1, 3.2), Vector3(-3.2, 1, 2.0))
	query.exclude = [player.get_rid()]
	assert(current_scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	player.position = Vector3(3, 1.1, 6)
	door._process(0.5)
	assert(door.openness == 1)
	door._process(2)
	await physics_frame
	await physics_frame
	assert(not current_scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	visitor.position = Vector3(-3, 0.1, 3.7)
	visitor.show()
	door._process(0.5)
	assert(door.openness == 1)
	visitor.hide()
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	camera.position = Vector3(-0.5, 2.1, 1.8)
	camera.look_at(Vector3(-2.5, 1.5, -0.6))
	assert(shop.business.hire_worker())
	shop.business.set_staff_shift("cashier", 480, 600)
	shop.business.advance_clock(120)
	var dialog = current_scene.get_node("Ui").staff_dialog
	current_scene.get_node("Ui").notifications.refresh()
	assert(not dialog.visible and not player._menu_is_open())
	current_scene.get_node("Ui").notifications.rows["staff:cashier"].pressed.emit()
	assert(dialog.visible and player._menu_is_open())
	await _capture("shift_request")
	for viewport_size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = viewport_size
		await process_frame
		dialog._layout()
		_layout(dialog)
		await _capture("dialog_%d" % viewport_size.x)
	dialog.choices[1].pressed.emit()
	assert(dialog.visible and shop.business.cashier_on_shift())
	dialog.choices[0].pressed.emit()
	assert(not dialog.visible)
	shop.business.advance_clock(60)
	current_scene.get_node("Ui").notifications.refresh()
	current_scene.get_node("Ui").notifications.rows["staff:cashier"].pressed.emit()
	assert(dialog.visible and dialog.actions[0] == "pay")
	await _capture("overtime_pay")
	dialog.choices[0].pressed.emit()
	assert(shop.business.overtime_expenses == 50)
	dialog.choices[0].pressed.emit()
	root.size = Vector2i(1152, 648)
	await process_frame
	var menu = current_scene.get_node("Ui").supplier_menu
	menu.open_menu()
	menu.tabs.current_tab = 3
	_layout(menu)
	await _capture("happiness")
	menu.close_menu()
	shop.business.minutes_of_day = 480
	shop.business.staff.records.cashier = shop.business.EmployeeRelations.fresh_record()
	visitor.shopping_quantity = 3
	visitor.wants_discount = false
	visitor.spending_budget = 200
	for frame in range(1200):
		if visitor.state == visitor.State.SCANNING: break
		visitor._physics_process(0.05)
	assert(visitor.state == visitor.State.SCANNING)
	player.position = Vector3(-1.0, 1.1, 1.6)
	visitor._physics_process(1.5)
	ops._update_checkout_display()
	assert(ops.checkout_display.text.contains("SCAN 1.5s"))
	camera.position = Vector3(-1.5, 1.9, -0.8)
	camera.look_at(Vector3(-2.5, 1.45, 1.2))
	await _capture("live_scan")
	visitor._physics_process(1.6)
	ops._update_checkout_display()
	assert(visitor.scanned_count == 1 and ops.checkout_display.text.contains("1/3"))
	await _capture("scan_next")
	for frame in range(2): visitor._physics_process(3.1)
	ops._update_checkout_display()
	assert(visitor.state == visitor.State.PAYING and ops.checkout_display.text.contains(visitor.payment_method))
	await _capture("payment")
	visitor._physics_process(1.1)
	assert(shop.stock == 7 and shop.business.items_sold == 3)
	for frame in range(20): ops._employee_presence(shop.worker, "cashier", 1)
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: shift conversations, daily mood, overtime request/payment/debt, quitting/rehiring and wages, returned worker box, v8 migration/save reload, movement lock, responsive dialogue, automatic solid sliding doors and dynamic scan/payment display")
	quit()
