extends SceneTree

const Backend := preload("res://business_backend.gd")

func _initialize() -> void:
	call_deferred("_run")

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
	assert(state.shop_is_open() and state.sell_one_stock(100))
	state.advance_clock(719.0)
	assert(state.minutes_of_day == 1199.0 and state.shop_is_open())
	assert(state.sell_one_stock(100))
	state.advance_clock(1.0)
	assert(not state.shop_is_open())
	var closed_state: Dictionary = state.snapshot()
	for attempt in range(3):
		assert(not state.sell_one_stock(200))
	assert(state.snapshot() == closed_state)
	state.advance_clock(239.0)
	assert(not state.shop_is_open())
	state.advance_clock(480.0)
	assert(state.day == 2 and state.minutes_of_day == 479.0 and not state.shop_is_open())
	assert(state.operating_expenses == 100)
	state.advance_clock(1.0)
	assert(state.shop_is_open() and state.sell_one_stock(100))
	assert(state._is_valid_snapshot(state.snapshot()))

	var save_path := OS.get_environment("TEMP").path_join("life_business_hours_%d.json" % Time.get_ticks_usec())
	var configured = load("res://main.tscn.tscn").instantiate()
	configured.get_node("ShopOperations").enabled = false
	configured.get_node("Shop/ShopArea").save_path = save_path
	var packed := PackedScene.new()
	assert(packed.pack(configured) == OK)
	configured.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	_stop_simulation()
	var shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	var ui = current_scene.get_node("Ui")
	var spawner = current_scene.get_node("CustomerSpawner")
	var customer = current_scene.get_node("Customer")
	assert(ui.shop_status.text == "Shop: Open")
	assert(ui.shop_menu.get_node("ShopHoursLabel").text == "Hours: 08:00 - 20:00")
	shop.business.advance_clock(720.0)
	assert(ui.shop_status.text == "Shop: Closed")
	var wait_before: float = customer.wait_remaining
	customer._physics_process(100.0)
	assert(not customer.visible and customer.state == customer.State.WAITING)
	assert(customer.wait_remaining == wait_before)
	customer.state = customer.State.ARRIVING
	customer.show()
	var before_departure: Dictionary = shop.business.snapshot()
	customer._physics_process(100.0)
	assert(customer.state == customer.State.LEAVING and customer.is_queued_for_deletion())
	assert(shop.business.snapshot() == before_departure)
	await process_frame
	spawner._on_spawn_timer_timeout()
	assert(not is_instance_valid(spawner.active_customer))
	assert(shop.business.start_marketing())
	spawner.get_node("SpawnTimer").stop()
	spawner._on_spawn_timer_timeout()
	assert(not is_instance_valid(spawner.active_customer))
	assert(shop.purchase_stock())
	var interaction := InputEventKey.new()
	interaction.keycode = KEY_E
	interaction.pressed = true
	shop.player_inside = true
	shop._unhandled_input(interaction)
	assert(shop.shop_menu.visible)
	ui.select_tab(1)
	for viewport_size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = viewport_size
		await process_frame
		ui._layout()
		assert(ui.shop_status.visible and ui.shop_status.text == "Shop: Closed")
		assert(Rect2(Vector2.ZERO, shop.shop_menu.size).encloses(ui.shop_status.get_rect()))
		assert(ui.shop_status.get_combined_minimum_size().x <= ui.shop_status.size.x)
		await _capture("life_business_hours_closed_%dx%d.png" % [viewport_size.x, viewport_size.y])
	shop.close_button.pressed.emit()
	assert(not shop.shop_menu.visible)
	ui._process(0.0)
	assert(ui.interaction_label.text == "My shop (closed)")
	shop._capture_marketing_time()
	shop.business.save_path = save_path
	assert(shop.business.save_progress())
	var saved_money: int = shop.money
	var saved_stock: int = shop.stock
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	_stop_simulation()
	shop = current_scene.get_node("Shop/ShopArea")
	ui = current_scene.get_node("Ui")
	spawner = current_scene.get_node("CustomerSpawner")
	customer = current_scene.get_node("Customer")
	shop.business.save_path = ""
	assert(not shop.business.shop_is_open() and ui.shop_status.text == "Shop: Closed")
	assert(shop.money == saved_money and shop.stock == saved_stock)
	customer._physics_process(100.0)
	assert(not customer.visible)
	shop.business.advance_clock(720.0)
	assert(shop.business.shop_is_open() and ui.shop_status.text == "Shop: Open")
	assert(shop.money == saved_money - 100)
	customer._physics_process(3.1)
	assert(customer.visible and customer.state == customer.State.ARRIVING)
	customer._physics_process(100.0)
	assert(customer.state == customer.State.BUYING)
	customer._physics_process(1.1)
	assert(shop.stock == saved_stock - 1 and shop.money == saved_money)
	customer._physics_process(100.0)
	await process_frame
	spawner._on_spawn_timer_timeout()
	customer = spawner.active_customer
	assert(is_instance_valid(customer))
	customer.set_physics_process(false)
	customer._physics_process(0.1)
	customer._physics_process(100.0)
	assert(customer.state == customer.State.BUYING)
	shop.business.advance_clock(720.0)
	var before_closing_sale: Dictionary = shop.business.snapshot()
	customer._physics_process(100.0)
	assert(customer.is_queued_for_deletion())
	assert(shop.business.snapshot() == before_closing_sale)
	assert(not shop.sell_one_stock(200))
	assert(shop.business._is_valid_snapshot(shop.business.snapshot()))
	assert(shop.business.buy_house() and shop.business.sleep_until_morning())
	assert(shop.business.shop_is_open() and ui.shop_status.text == "Shop: Open")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	print("PASS: 08:00/20:00 boundaries, blocked night sales/spawns, late arrivals, after-hours management, responsive status UI, night save/load, morning customers and sleep reopening")
	quit()
