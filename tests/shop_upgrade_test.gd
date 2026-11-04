extends SceneTree

const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path(label: String) -> String:
	var path := OS.get_environment("TEMP").path_join("life_business_upgrade_%s_%d.json" % [label, Time.get_ticks_usec()])
	paths.append(path)
	return path

func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data))
	file.close()

func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join(file_name)) == OK)

func _stop_simulation() -> void:
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _run() -> void:
	var state = Backend.new()
	assert(state.shop_level == 1 and state.next_upgrade_cost() == 2500)
	# Each level brings more shoppers a day; marketing adds 18% on top.
	var level_one: float = state.customers_per_day()
	assert(is_equal_approx(state.customers_per_day(true), level_one * 1.18))
	assert(state.upgrade_shop())
	assert(state.shop_level == 2 and state.money == 47500 and state.stock == 10)
	assert(state.upgrade_expenses == 2500 and state.total_expenses() == 2500 and state.net_profit() == -2500)
	var level_two: float = state.customers_per_day()
	assert(level_two > level_one and is_equal_approx(state.customers_per_day(true), level_two * 1.18))
	assert(state.upgrade_shop())
	assert(state.shop_level == 3 and state.money == 42500 and state.upgrade_expenses == 7500)
	assert(state.customers_per_day() > level_two)
	var max_state: Dictionary = state.snapshot()
	assert(state.next_upgrade_cost() == 0 and not state.can_upgrade_shop())
	assert(not state.upgrade_shop() and state.snapshot() == max_state)
	assert(state._is_valid_snapshot(max_state))
	for pair in [["shop_level", 0], ["shop_level", 4], ["shop_level", 1.5], ["shop_level", true], ["upgrade_expenses", 5000], ["money", 50000]]:
		var invalid: Dictionary = max_state.duplicate()
		invalid[pair[0]] = pair[1]
		assert(not state._is_valid_snapshot(invalid))
	var poor = Backend.new()
	for purchase in range(98):
		assert(poor.order_stock() and poor.receive_delivery() and poor.pick_up_box())
		assert(poor.store_product_box(purchase))
	var poor_before: Dictionary = poor.snapshot()
	assert(not poor.can_upgrade_shop() and not poor.upgrade_shop())
	assert(poor.snapshot() == poor_before)
	var legacy = Backend.new()
	assert(legacy.hire_worker() and legacy.buy_house() and legacy.purchase_stock())
	legacy.advance_clock(1440.0)
	var legacy_data: Dictionary = legacy.snapshot()
	legacy_data["version"] = 4
	for field in ["staff_relations", "overtime_expenses", "inventory", "pending_product", "assistant_auto_collect"]: legacy_data.erase(field)
	for field in Backend.EMPLOYEE_FIELDS: legacy_data.erase(field)
	for field in Backend.STAFF_FIELDS + ["stock_worker_hired"]: legacy_data.erase(field)
	for field in Backend.SUPPLY_FIELDS: legacy_data.erase(field)
	legacy_data.erase("shop_level")
	legacy_data.erase("upgrade_expenses")
	var legacy_path := _path("legacy")
	_write(legacy_path, legacy_data)
	var migrated = Backend.new()
	migrated.load_progress(legacy_path)
	assert(migrated.shop_level == 1 and migrated.upgrade_expenses == 0)
	assert(migrated.money == legacy.money and migrated.stock == legacy.stock and migrated.day == legacy.day)
	assert(migrated.worker_hired and migrated.house_owned and migrated.operating_expenses == legacy.operating_expenses)
	assert(migrated.upgrade_shop() and migrated.save_progress())
	assert(JSON.parse_string(FileAccess.get_file_as_string(legacy_path))["version"] == 10)
	var loaded = Backend.new()
	loaded.load_progress(legacy_path)
	assert(loaded.snapshot() == migrated.snapshot())
	assert(loaded.upgrade_shop() and loaded.save_progress())
	loaded = Backend.new()
	loaded.load_progress(legacy_path)
	assert(loaded.shop_level == 3 and loaded._is_valid_snapshot(loaded.snapshot()))

	var scene_path := _path("scene")
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("ShopOperations").enabled = false
	scene.get_node("Shop/ShopArea").save_path = scene_path
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	_stop_simulation()
	var shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	var ui = current_scene.get_node("Ui")
	var spawner = current_scene.get_node("CustomerSpawner")
	var timer: Timer = spawner.get_node("SpawnTimer")
	var customer = current_scene.get_node("Customer")
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.position = Vector3(1.5, 4.5, 10)
	camera.look_at(Vector3(-3, 1.5, 0.5))
	camera.current = true
	await _capture("life_business_upgrade_level1.png")
	shop.shop_menu.show()
	ui.select_tab(1)
	ui.upgrade_button.pressed.emit()
	assert(shop.money == 47500 and shop.stock == 10 and shop.business.shop_level == 2)
	assert(ui.hud_money.text == shop.money_label.text and shop.business.net_profit() == -2500)
	assert(shop.expenses_label.text.ends_with("2,500") and ui.shop_level_label.text.begins_with("Level 2"))
	assert(timer.one_shot and timer.wait_time == 8.0)
	assert(current_scene.get_node("Shop/ShopSign").text == "SHOP II")
	for viewport_size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = viewport_size
		await process_frame
		ui._layout()
		var controls = shop.shop_menu.get_children().filter(func(node): return node is Control and node.visible)
		for index in range(controls.size()):
			assert(Rect2(Vector2.ZERO, shop.shop_menu.size).encloses(controls[index].get_rect()))
			assert(controls[index].get_combined_minimum_size().x <= controls[index].size.x)
			for other in range(index + 1, controls.size()):
				assert(not controls[index].get_rect().intersects(controls[other].get_rect()))
		await _capture("life_business_upgrade_ui_%dx%d.png" % [viewport_size.x, viewport_size.y])
	spawner._on_spawn_timer_timeout()
	assert(spawner.active_customer == customer)
	assert(current_scene.get_children().filter(func(node): return node.name == "Customer").size() == 1)
	customer.state = customer.State.LEAVING
	customer._physics_process(100.0)
	await process_frame
	assert(not is_instance_valid(spawner.active_customer) and not timer.is_stopped())
	assert(timer.time_left > 7.8 and timer.time_left <= 8.0)
	var wait_before: float = timer.time_left
	assert(shop.business.set_selling_price(110))
	assert(timer.time_left <= wait_before)
	ui.upgrade_button.pressed.emit()
	assert(shop.business.shop_level == 3 and shop.money == 42500 and timer.wait_time == 6.0)
	assert(timer.time_left > 5.8 and timer.time_left <= 6.0)
	assert(ui.upgrade_button.disabled and ui.upgrade_button.text == "Maximum level")
	ui.upgrade_button.pressed.emit()
	assert(shop.money == 42500 and ui.feedback_label.text == "Maximum shop level reached.")
	assert(shop.business.start_marketing())
	assert(is_equal_approx(timer.wait_time, 5.1))
	shop.business.finish_marketing()
	assert(timer.wait_time == 6.0)
	spawner._on_spawn_timer_timeout()
	customer = spawner.active_customer
	assert(is_instance_valid(customer) and timer.is_stopped())
	customer.set_physics_process(false)
	customer._physics_process(0.1)
	customer._physics_process(100.0)
	customer.spending_budget = 200
	var stock_before: int = shop.stock
	customer._physics_process(1.1)
	assert(shop.stock == stock_before - 1 and shop.business.sales_revenue == 110)
	customer._physics_process(100.0)
	await process_frame
	assert(timer.time_left > 5.8 and timer.time_left <= 6.0)
	root.size = Vector2i(1152, 648)
	shop.shop_menu.hide()
	await _capture("life_business_upgrade_level3.png")
	shop.business.advance_clock(720.0)
	timer.stop()
	spawner._on_spawn_timer_timeout()
	assert(not is_instance_valid(spawner.active_customer))
	shop.business.save_path = scene_path
	assert(shop.business.save_progress())
	var saved_money: int = shop.money
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	_stop_simulation()
	shop = current_scene.get_node("Shop/ShopArea")
	ui = current_scene.get_node("Ui")
	spawner = current_scene.get_node("CustomerSpawner")
	shop.business.save_path = ""
	assert(shop.business.shop_level == 3 and shop.money == saved_money)
	assert(shop.business.upgrade_expenses == 7500 and ui.upgrade_button.disabled)
	# The next shopper comes within the usual spread of the average gap (customer_spawner.gd).
	if not spawner.get_node("SpawnTimer").is_stopped():
		assert(spawner.get_node("SpawnTimer").time_left <= maxf(spawner.CLOSED_CHECK, spawner.average_gap_seconds() * spawner.GAP_SPREAD.y) + 0.1)
	assert(current_scene.get_node("Shop/ShopSign").text == "SHOP III")
	assert(not shop.business.shop_is_open())
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	print("PASS: two upgrades, cost/accounting guards, maximum level, v4 migration and restart, customer cooldowns/marketing, one NPC at a time, closed-hours guard, responsive UI and shop visuals")
	quit()
