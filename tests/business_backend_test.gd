extends SceneTree

const Backend := preload("res://business_backend.gd")

var temporary_paths: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	call_deferred("_run_checks")

func _new_save_path(label: String) -> String:
	var path := OS.get_environment("TEMP").path_join("life_business_%s_%d.json" % [label, Time.get_ticks_usec()])
	temporary_paths.append(path)
	return path

func _check_invariants(state) -> void:
	assert(state._is_valid_snapshot(state.snapshot()))
	assert(state.money == 50000 + state.sales_revenue - state.total_spending())
	assert(state.stock >= 0 and state.money >= 0)

func _buy_storage_box(state) -> void:
	assert(state.order_stock() and state.receive_delivery() and state.pick_up_box())
	var slot := -1
	for rack in range(16):
		slot = state.logistics.free_slot(rack)
		if slot >= 0: break
	assert(state.store_product_box(slot))

func _write_fixture(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(contents)
	file.close()

func _walk_forward(seconds: float) -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	await create_timer(seconds).timeout
	var release := InputEventKey.new()
	release.keycode = KEY_W
	Input.parse_input_event(release)
	await physics_frame

func _run_checks() -> void:
	var supports_mouse_capture := DisplayServer.get_name() != "headless"
	var state = Backend.new()
	assert(state.money == 50000 and state.stock == 10)
	var clock_state = Backend.new()
	assert(clock_state.day == 1 and clock_state.minutes_of_day == 480.0)
	assert(not clock_state.sleep_until_morning())
	clock_state.advance_clock(-1.0)
	clock_state.advance_clock(NAN)
	assert(clock_state.minutes_of_day == 480.0)
	clock_state.advance_clock(960.0)
	assert(clock_state.day == 2 and clock_state.minutes_of_day == 0.0)
	clock_state.advance_clock(1445.0)
	assert(clock_state.day == 3 and clock_state.minutes_of_day == 5.0)
	clock_state.advance_clock(1e30)
	assert(clock_state.day == 3 and clock_state.minutes_of_day == 5.0)
	assert(clock_state.money == 49800 and clock_state.operating_expenses == 200)
	_check_invariants(clock_state)
	var debtor = Backend.new()
	assert(debtor.hire_worker())
	for purchase in range(98):
		_buy_storage_box(debtor)
	assert(debtor.money == 0 and debtor.worker_on_duty())
	debtor.advance_clock(960.0)
	assert(debtor.operating_due == 100 and debtor.wages_due == 200)
	assert(debtor.last_billed_day == 2 and not debtor.worker_on_duty())
	assert(not debtor.pay_bills())
	var debt_path := _new_save_path("unpaid_bills")
	debtor.load_progress(debt_path)
	assert(debtor.save_progress())
	var debtor_loaded = Backend.new()
	debtor_loaded.load_progress(debt_path)
	assert(debtor_loaded.snapshot() == debtor.snapshot())
	debtor_loaded.advance_clock(1.0)
	assert(debtor_loaded.unpaid_bills() == 300)
	debtor_loaded.advance_clock(Backend.SHOP_OPEN_MINUTE - debtor_loaded.minutes_of_day)
	assert(debtor_loaded.sell_one_stock(100) and debtor_loaded.pay_bills())
	assert(debtor_loaded.operating_due == 0 and debtor_loaded.wages_due == 200)
	assert(not debtor_loaded.worker_on_duty())
	assert(debtor_loaded.sell_one_stock(100) and debtor_loaded.sell_one_stock(100))
	assert(debtor_loaded.pay_bills() and debtor_loaded.worker_on_duty())
	assert(debtor_loaded.unpaid_bills() == 0 and debtor_loaded.money == 0)
	assert(not debtor_loaded.pay_bills())
	debtor_loaded.advance_clock(2880.0)
	assert(debtor_loaded.day == 4 and debtor_loaded.operating_due == 200 and debtor_loaded.wages_due == 400)
	_check_invariants(debtor_loaded)
	var invalid_billing: Dictionary = debtor_loaded.snapshot()
	invalid_billing["last_billed_day"] -= 1
	assert(not debtor_loaded._is_valid_snapshot(invalid_billing))
	assert(not state.set_selling_price(49))
	assert(not state.set_selling_price(201))
	assert(not state.set_selling_price(155))
	assert(not state.sell_one_stock(-1))
	assert(state.missed_sales == 0)
	assert(state.set_selling_price(150))
	assert(not state.sell_one_stock(100))
	assert(state.money == 50000 and state.stock == 10 and state.missed_sales == 1)
	assert(state.sell_one_stock(150))
	assert(state.money == 50150 and state.sales_revenue == 150 and state.stock == 9)
	assert(state.hire_worker())
	assert(not state.hire_worker())
	assert(state.start_marketing())
	assert(not state.start_marketing())
	assert(state.purchase_stock())
	assert(state.total_expenses() == 1700 and state.net_profit() == -1550)
	_check_invariants(state)
	for sale in range(19):
		assert(state.sell_one_stock(200))
	assert(not state.sell_one_stock(200))
	assert(state.stock == 0 and state.missed_sales == 2)
	_check_invariants(state)
	var poor = Backend.new()
	for purchase in range(100):
		_buy_storage_box(poor)
	assert(poor.money == 0)
	assert(not poor.buy_house())
	assert(not poor.purchase_stock() and not poor.hire_worker() and not poor.start_marketing())
	assert(poor.sell_one_stock(100))
	assert(not poor.purchase_stock())
	assert(poor.sell_one_stock(100) and poor.start_marketing())
	_check_invariants(poor)
	for field in Backend.INTEGER_FIELDS:
		var invalid: Dictionary = state.snapshot()
		invalid[field] = -1
		assert(not state._is_valid_snapshot(invalid))
	var invalid: Dictionary = state.snapshot()
	invalid["stock"] += 1
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid["money"] += 1
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid["worker_hired"] = false
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid["marketing_seconds_left"] = 61.0
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid["version"] = true
	assert(not state._is_valid_snapshot(invalid))
	var property_owner = Backend.new()
	assert(property_owner.buy_house())
	assert(property_owner.house_owned and property_owner.money == 35000)
	assert(property_owner.property_expenses == 15000 and property_owner.net_profit() == 0)
	assert(not property_owner.buy_house())
	assert(not property_owner.sleep_until_morning())
	property_owner.advance_clock(720)
	assert(property_owner.sleep_until_morning())
	assert(property_owner.day == 2 and property_owner.minutes_of_day == 480.0)
	assert(property_owner.money == 34900 and property_owner.stock == 10)
	assert(property_owner.operating_expenses == 100 and property_owner.net_profit() == -100)
	for bad_time in [-1.0, 1440.0, NAN]:
		var invalid_time: Dictionary = property_owner.snapshot()
		invalid_time["minutes_of_day"] = bad_time
		assert(not property_owner._is_valid_snapshot(invalid_time))
	for bad_day in [0, 1.5, true, 1000000001]:
		var invalid_day: Dictionary = property_owner.snapshot()
		invalid_day["day"] = bad_day
		assert(not property_owner._is_valid_snapshot(invalid_day))
	_check_invariants(property_owner)
	var migration_path := _new_save_path("migration")
	var legacy: Dictionary = state.snapshot()
	legacy["version"] = 1
	for field in ["staff_relations", "overtime_expenses", "inventory", "pending_product", "assistant_auto_collect"]: legacy.erase(field)
	for field in Backend.EMPLOYEE_FIELDS: legacy.erase(field)
	for field in Backend.STAFF_FIELDS + ["stock_worker_hired"]: legacy.erase(field)
	for field in Backend.SUPPLY_FIELDS: legacy.erase(field)
	legacy.erase("shop_level")
	legacy.erase("upgrade_expenses")
	legacy.erase("house_owned")
	legacy.erase("property_expenses")
	legacy.erase("day")
	legacy.erase("minutes_of_day")
	for field in Backend.DAILY_FIELDS:
		legacy.erase(field)
	_write_fixture(migration_path, JSON.stringify(legacy))
	var migrated = Backend.new()
	migrated.load_progress(migration_path)
	assert(migrated.money == state.money and migrated.stock == state.stock and migrated.worker_hired)
	assert(not migrated.house_owned and migrated.property_expenses == 0)
	assert(migrated.save_progress())
	assert(JSON.parse_string(FileAccess.get_file_as_string(migration_path))["version"] == 10)
	assert(migrated.day == 1 and migrated.minutes_of_day == 480.0)
	var legacy_owner = Backend.new()
	assert(legacy_owner.buy_house())
	var version_two: Dictionary = legacy_owner.snapshot()
	version_two["version"] = 2
	for field in ["staff_relations", "overtime_expenses", "inventory", "pending_product", "assistant_auto_collect"]: version_two.erase(field)
	for field in Backend.EMPLOYEE_FIELDS: version_two.erase(field)
	for field in Backend.STAFF_FIELDS + ["stock_worker_hired"]: version_two.erase(field)
	for field in Backend.SUPPLY_FIELDS: version_two.erase(field)
	version_two.erase("shop_level")
	version_two.erase("upgrade_expenses")
	version_two.erase("day")
	version_two.erase("minutes_of_day")
	for field in Backend.DAILY_FIELDS:
		version_two.erase(field)
	var version_two_path := _new_save_path("migration_v2")
	_write_fixture(version_two_path, JSON.stringify(version_two))
	var migrated_owner = Backend.new()
	migrated_owner.load_progress(version_two_path)
	assert(migrated_owner.house_owned and migrated_owner.money == 35000)
	assert(migrated_owner.day == 1 and migrated_owner.minutes_of_day == 480.0)
	assert(migrated_owner.save_progress())
	var version_three: Dictionary = state.snapshot()
	version_three["version"] = 3
	for field in ["staff_relations", "overtime_expenses", "inventory", "pending_product", "assistant_auto_collect"]: version_three.erase(field)
	for field in Backend.EMPLOYEE_FIELDS: version_three.erase(field)
	for field in Backend.STAFF_FIELDS + ["stock_worker_hired"]: version_three.erase(field)
	for field in Backend.SUPPLY_FIELDS: version_three.erase(field)
	version_three.erase("shop_level")
	version_three.erase("upgrade_expenses")
	version_three["day"] = 7
	for field in Backend.DAILY_FIELDS:
		version_three.erase(field)
	var version_three_path := _new_save_path("migration_v3")
	_write_fixture(version_three_path, JSON.stringify(version_three))
	var migrated_three = Backend.new()
	migrated_three.load_progress(version_three_path)
	assert(migrated_three.day == 7 and migrated_three.money == state.money)
	assert(migrated_three.last_billed_day == 7 and migrated_three.worker_hired_day == 7)
	migrated_three.advance_clock(960.0)
	assert(migrated_three.money == state.money - 300 and migrated_three.last_billed_day == 8)
	_check_invariants(migrated_three)
	var final_day = Backend.new()
	assert(final_day.buy_house())
	final_day.day = Backend.MAX_SAVED_VALUE
	final_day.minutes_of_day = 1439.0
	assert(not final_day.sleep_until_morning())
	final_day.advance_clock(1.0)
	assert(final_day.day == Backend.MAX_SAVED_VALUE and final_day.minutes_of_day == 1439.0)
	_check_invariants(migrated)
	var path := _new_save_path("persistence")
	state.load_progress(path)
	state.marketing_seconds_left = 38.5
	assert(state.save_progress())
	assert(state.save_progress())
	var saved: Dictionary = state.snapshot()
	_write_fixture(path, "{external corruption")
	assert(state.save_progress(), "Cached state must repair an externally changed save")
	assert(FileAccess.get_file_as_string(path) == JSON.stringify(saved))
	var loaded = Backend.new()
	loaded.load_progress(path)
	assert(loaded.snapshot() == saved)
	_write_fixture(path, "{broken json")
	var recovered = Backend.new()
	recovered.load_progress(path)
	assert(recovered.snapshot() == saved and recovered.save_status == "Save: Backup recovered")
	_write_fixture(path + ".bak", "{}")
	var reset = Backend.new()
	reset.load_progress(path)
	assert(reset.money == 50000 and reset.save_path == path + ".recovered")
	assert(reset.purchase_stock())
	assert(FileAccess.get_file_as_string(path) == "{broken json")
	var recovered_new_game = Backend.new()
	recovered_new_game.load_progress(path)
	assert(recovered_new_game.money == 49500 and recovered_new_game.stock == 20)
	var unwritable = Backend.new()
	unwritable.load_progress(_new_save_path("missing_directory").path_join("save.json"))
	var unwritable_before: Dictionary = unwritable.snapshot()
	assert(not unwritable.purchase_stock() and unwritable.save_status == "Save: Failed")
	assert(unwritable.snapshot() == unwritable_before)
	var scene_path := _new_save_path("scene")
	var configured = load("res://main.tscn.tscn").instantiate()
	configured.get_node("ShopOperations").enabled = false
	configured.get_node("Shop/ShopArea").save_path = scene_path
	var packed := PackedScene.new()
	assert(packed.pack(configured) == OK)
	configured.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	current_scene.get_node("Ui")._layout()
	var shop = current_scene.get_node("Shop/ShopArea")
	var day_clock = current_scene.get_node("DayClock")
	day_clock.set_process(false)
	var initial_minutes: float = shop.business.minutes_of_day
	day_clock._process(0.5)
	assert(is_equal_approx(shop.business.minutes_of_day, initial_minutes + 0.5 * day_clock.minutes_per_second))
	assert(current_scene.get_node("Ui/ClockLabel").text.begins_with("Day 1 | 08:"))
	var sleep_area = current_scene.get_node("House/Bed/SleepArea")
	assert(sleep_area.sleep_sign.fixed_size)
	assert(is_equal_approx(sleep_area.sleep_sign.pixel_size, 0.002))
	assert(sleep_area.sleep_sign.outline_size == 2)
	assert(not sleep_area.try_sleep())
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	assert(shop.business.set_selling_price(150))
	assert(shop.sell_one_stock(150))
	shop.hire_worker_button.pressed.emit()
	shop.marketing_button.pressed.emit()
	assert(shop.worker.hired and shop.worker.visible and shop.marketing_active)
	var house = current_scene.get_node("House/HouseArea")
	var house_player = current_scene.get_node("Player")
	var original_player_transform: Transform3D = house_player.global_transform
	await physics_frame
	await physics_frame
	var door_query := PhysicsRayQueryParameters3D.create(current_scene.get_node("House").to_global(Vector3(0, 0.9, 3)), current_scene.get_node("House").to_global(Vector3(0, 0.9, 1)))
	door_query.exclude = [house_player.get_rid()]
	var locked_hit: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(door_query)
	assert(not locked_hit.is_empty() and locked_hit["collider"] == house.front_door)
	var interaction := InputEventKey.new()
	interaction.keycode = KEY_E
	interaction.pressed = true
	house._unhandled_input(interaction)
	assert(not house.house_menu.visible)
	house_player.global_position = current_scene.get_node("House").to_global(Vector3(0, 1.0, 3))
	house_player.rotation.y = current_scene.get_node("House").global_rotation.y
	house_player.velocity = Vector3.ZERO
	await _walk_forward(0.3)
	assert(current_scene.get_node("House").to_local(house_player.global_position).z > 2.0 and house.player_inside)
	house._unhandled_input(interaction)
	assert(house.house_menu.visible and not shop.shop_menu.visible)
	var money_before_house: int = shop.money
	var profit_before_house: int = shop.business.net_profit()
	house.buy_house_button.pressed.emit()
	assert(shop.money == money_before_house - 15000 and shop.business.house_owned)
	assert(not house.house_menu.visible)
	if supports_mouse_capture:
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	assert(shop.business.net_profit() == profit_before_house)
	assert(house.buy_house_button.disabled and not house.front_door.visible)
	house.buy_house_button.pressed.emit()
	assert(shop.money == money_before_house - 15000)
	await physics_frame
	await physics_frame
	assert(house.front_door.get_node("CollisionShape3D").disabled)
	assert(current_scene.get_world_3d().direct_space_state.intersect_ray(door_query).is_empty())
	await _walk_forward(0.65)
	assert(current_scene.get_node("House").to_local(house_player.global_position).z < 1.2)
	assert(house_player.indoors and is_zero_approx(house_player.spring_arm.spring_length))
	await process_frame
	await process_frame
	assert(not house_player.player_mesh.visible)
	assert(not house_player.player_mesh.get_node("Body").is_visible_in_tree())
	assert(not house_player.player_mesh.get_node("Head").is_visible_in_tree())
	house_player.global_position = current_scene.get_node("House").to_global(Vector3(0, 1.0, -1.1))
	house_player.rotation.y = PI + current_scene.get_node("House").global_rotation.y
	house_player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await process_frame
	var camera: Camera3D = house_player.get_node("CameraPivot/SpringArm3D/Camera3D")
	assert(camera.global_position.distance_to(house_player.camera_pivot.global_position) < 0.01)
	assert(is_equal_approx(camera.global_position.y, house_player.global_position.y + 0.7))
	var camera_ray := PhysicsRayQueryParameters3D.create(house_player.camera_pivot.global_position, camera.global_position)
	camera_ray.exclude = [house_player.get_rid()]
	assert(current_scene.get_world_3d().direct_space_state.intersect_ray(camera_ray).is_empty())
	house_player.global_position = current_scene.get_node("House").to_global(Vector3(-1, 1.0, -0.7))
	house_player.rotation.y = current_scene.get_node("House").global_rotation.y
	house_player.camera_pivot.rotation.x = deg_to_rad(-55)
	await physics_frame
	await physics_frame
	await physics_frame
	shop.shop_menu.show()
	sleep_area._process(0.0)
	assert(not sleep_area.sleep_sign.visible)
	assert(not sleep_area.try_sleep())
	shop.shop_menu.hide()
	sleep_area._process(0.0)
	assert(sleep_area.sleep_sign.visible)
	shop.business.advance_clock(1200.0 - shop.business.minutes_of_day)
	var money_before_sleep: int = shop.money
	var stock_before_sleep: int = shop.stock
	var day_before_sleep: int = shop.business.day
	sleep_area._unhandled_input(interaction)
	assert(shop.business.day == day_before_sleep + 1 and shop.business.minutes_of_day == 480.0)
	assert(paused and current_scene.get_node("Ui").day_report_screen.visible)
	current_scene.get_node("Ui").day_report_screen.close()
	assert(not sleep_area.try_sleep())
	assert(shop.money == money_before_sleep - 300 and shop.stock == stock_before_sleep)
	assert(shop.business.operating_expenses == 100 and shop.business.wage_expenses == 200)
	assert(shop.business.unpaid_bills() == 0 and shop.pay_bills_button.disabled)
	assert(current_scene.get_node("Ui/ClockLabel").text.begins_with("Day %d | 08:00 | " % shop.business.day))
	assert(shop.business.save_status == "Save: Saved")
	assert(camera.global_position.y < 3.1)
	assert(camera.global_position.distance_to(house_player.camera_pivot.global_position) < 0.01)
	house_player.global_position = current_scene.get_node("House").to_global(Vector3(0, 1.0, -5.0))
	house_player.rotation.y = current_scene.get_node("House").global_rotation.y
	house_player.camera_pivot.rotation.x = deg_to_rad(-12)
	await create_timer(0.3).timeout
	await physics_frame
	assert(not house_player.indoors)
	sleep_area._process(0.0)
	assert(not sleep_area.sleep_sign.visible)
	# First person outdoors too.
	assert(camera.global_position.distance_to(house_player.camera_pivot.global_position) < 0.05)
	house_player.camera_pivot.rotation.x = deg_to_rad(-12)
	house_player.global_transform = original_player_transform
	house_player.velocity = Vector3.ZERO
	house.close_house_button.pressed.emit()
	assert(not house.house_menu.visible)
	await create_timer(0.2).timeout
	await process_frame
	assert(not house_player.indoors and not house_player.player_mesh.visible)
	assert(camera.global_position.distance_to(house_player.camera_pivot.global_position) < 0.05)
	shop.marketing_timer.start(35.0)
	await process_frame
	shop._on_autosave_timer_timeout()
	var before_restart: Dictionary = shop.business.snapshot()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	current_scene.get_node("Ui")._layout()
	shop = current_scene.get_node("Shop/ShopArea")
	current_scene.get_node("DayClock").set_process(false)
	assert(shop.business.day == before_restart["day"])
	assert(absf(shop.business.minutes_of_day - before_restart["minutes_of_day"]) < 1.0)
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	assert(shop.money == before_restart["money"] and shop.stock == before_restart["stock"])
	assert(shop.selling_price == 150 and shop.sale_price_input.value == 150)
	assert(shop.worker.hired and shop.worker.visible)
	house = current_scene.get_node("House/HouseArea")
	assert(shop.business.house_owned and shop.business.property_expenses == 15000)
	assert(not house.front_door.visible and house.buy_house_button.disabled)
	assert(house.ownership_label.text == "Ownership: Yours")
	assert(shop.home_ownership_label.text == "Home: Owned")
	assert(not shop.worker.get_node("RestockTimer").is_stopped())
	assert(shop.marketing_active and shop.marketing_timer.time_left > 30.0 and shop.marketing_timer.time_left <= 35.0)
	assert(current_scene.get_node("CustomerSpawner/SpawnTimer").wait_time == 8.5)
	assert(shop.hire_worker_button.disabled and shop.marketing_button.disabled)
	assert(shop.save_status_label.text == "Save: Loaded")
	assert(not shop.business.hire_worker() and not shop.business.start_marketing())
	assert(shop.business.set_selling_price(100))
	for sale in range(7):
		assert(shop.sell_one_stock(100))
	assert(shop.stock == 2)
	shop.worker.get_node("RestockTimer").timeout.emit()
	assert(shop.stock == 12 and shop.restocking_expenses == 500)
	_check_invariants(shop.business)
	shop.shop_menu.show()
	shop.close_button.pressed.emit()
	assert(not shop.shop_menu.visible)
	shop.player_inside = true
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	shop._unhandled_input(event)
	assert(shop.shop_menu.visible)
	var player = current_scene.get_node("Player")
	var old_position: Vector3 = player.global_position
	var old_yaw: float = player.rotation.y
	var old_pitch: float = player.camera_pivot.rotation.x
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80, 30)
	player._unhandled_input(motion)
	assert(player.rotation.y == old_yaw and player.camera_pivot.rotation.x == old_pitch)
	var movement_event := InputEventKey.new()
	movement_event.keycode = KEY_W
	movement_event.pressed = true
	Input.parse_input_event(movement_event)
	await physics_frame
	await physics_frame
	var release_event := InputEventKey.new()
	release_event.keycode = KEY_W
	Input.parse_input_event(release_event)
	assert(player.global_position.distance_to(old_position) < 0.001)
	shop.close_button.pressed.emit()
	if supports_mouse_capture:
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	await _walk_forward(0.1)
	assert(player.global_position.distance_to(old_position) > 0.02)
	# The headless display cannot capture the OS cursor.
	if supports_mouse_capture:
		player._unhandled_input(motion)
		assert(player.rotation.y != old_yaw and player.camera_pivot.rotation.x != old_pitch)
	player.rotation.y = old_yaw
	player.camera_pivot.rotation.x = old_pitch
	await process_frame
	var game_ui = current_scene.get_node("Ui")
	for tab_index in range(4):
		game_ui.select_tab(tab_index)
		for menu in [shop.shop_menu, house.house_menu]:
			var controls = menu.get_children().filter(func(node): return node is Control and node.visible)
			for index in range(controls.size()):
				var control = controls[index]
				assert(Rect2(Vector2.ZERO, menu.size).encloses(control.get_rect()), "%s: rect %s in %s" % [control.name, control.get_rect(), menu.size])
				assert(control.get_combined_minimum_size().x <= control.size.x)
				for other_index in range(index + 1, controls.size()):
					assert(not control.get_rect().intersects(controls[other_index].get_rect()), "%s %s overlaps %s %s" % [control.name, control.get_rect(), controls[other_index].name, controls[other_index].get_rect()])
	game_ui.select_tab(0)
	assert(game_ui.hud_money.text == shop.money_label.text)
	Engine.time_scale = 120.0
	await shop.marketing_timer.timeout
	Engine.time_scale = 1.0
	assert(not shop.marketing_active)
	assert(current_scene.get_node("CustomerSpawner/SpawnTimer").wait_time == 10.0)
	_check_invariants(shop.business)
	# Detach persistence before deleting this run's isolated fixtures.
	shop.business.save_path = ""
	while shop.money >= 500:
		_buy_storage_box(shop.business)
	shop.business.advance_clock(2880.0)
	assert(shop.business.wages_due > 0)
	assert(shop.worker.get_node("RestockTimer").is_stopped())
	assert(shop.worker_status_label.text == "Status: Unpaid wages")
	while shop.stock > 2:
		assert(shop.sell_one_stock(200))
	var off_duty_money: int = shop.money
	shop.worker._on_restock_timer_timeout()
	assert(shop.stock == 2 and shop.money == off_duty_money)
	assert(not shop.pay_bills_button.disabled)
	var arrears: int = shop.business.unpaid_bills()
	shop.pay_bills_button.pressed.emit()
	assert(shop.money == off_duty_money - arrears)
	assert(shop.business.unpaid_bills() == 0 and shop.pay_bills_button.disabled)
	assert(not shop.worker.get_node("RestockTimer").is_stopped())
	shop.worker._on_restock_timer_timeout()
	assert(shop.stock == 12 and shop.money == off_duty_money - arrears - 500)
	assert(shop.worker.get_node("CharacterVisual").work_remaining > 0.0)
	_check_invariants(shop.business)
	for fixture_path in temporary_paths:
		for suffix in ["", ".bak", ".tmp", ".recovered", ".recovered.bak", ".recovered.tmp"]:
			if FileAccess.file_exists(fixture_path + suffix):
				DirAccess.remove_absolute(fixture_path + suffix)
	print("PASS: daily charges, arrears/repayment, billing restart protection, v1/v2/v3 migration, clock/sleep, TPP/FPP, home entry, movement/menu locks, save recovery, worker/marketing and accounting")
	quit()
