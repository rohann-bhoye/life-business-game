extends SceneTree

const Backend := preload("res://business_backend.gd")
var save_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join(file_name)) == OK)

func _prepare_customer(personality := 0, budget := 100):
	var customer = current_scene.get_node("Customer")
	customer.state = customer.State.BUYING
	customer.wait_remaining = 0.0
	customer.wants_discount = true
	customer.personality = personality
	customer.customer_name = ["Ravi - Bargain hunter", "Meena - Regular", "Aman - In a hurry"][personality]
	customer.spending_budget = budget
	customer.deal_sold = false
	customer.deal_result = ""
	customer.global_position = current_scene.get_node("CustomerPurchasePoint").global_position
	customer.show()
	customer._physics_process(0.1)
	return customer

func _open_offer() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	current_scene.get_node("Shop/ShopArea")._unhandled_input(event)
	assert(current_scene.get_node("Ui/BargainMenu").visible)

func _run() -> void:
	var state = Backend.new()
	assert(state.sell_one_stock(100, 80))
	assert(state.money == 50080 and state.stock == 9 and state.sales_revenue == 80)
	assert(state.items_sold == 1 and state.selling_price == 100)
	assert(state._is_valid_snapshot(state.snapshot()))
	var before_invalid: Dictionary = state.snapshot()
	for price in [-2, 0, 40, 55, 110, 210]:
		assert(not state.sell_one_stock(200, price))
	assert(state.snapshot() == before_invalid)
	assert(not state.sell_one_stock(-1, 80))
	assert(not state.sell_one_stock(70, 80))
	assert(state.missed_sales == 1 and state.stock == 9)

	save_path = OS.get_environment("TEMP").path_join("life_business_bargaining_%d.json" % Time.get_ticks_usec())
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("ShopOperations").enabled = false
	scene.get_node("Shop/ShopArea").save_path = save_path
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	var shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Customer").set_physics_process(false)
	var player = current_scene.get_node("Player")
	player.global_position = Vector3(-3, 1.1, 2.9)
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	shop.player_inside = true
	var ui = current_scene.get_node("Ui")
	var menu = ui.bargain_menu
	var customer = _prepare_customer()
	assert(customer.state == customer.State.NEGOTIATING and customer.offer_price == 80)
	ui._process(0.0)
	assert(ui.interaction_label.text == "Customer wants a discount")
	_open_offer()
	assert(player._menu_is_open() and not shop.shop_menu.visible and not shop.house_menu.visible)
	var old_yaw: float = player.rotation.y
	var old_pitch: float = player.camera_pivot.rotation.x
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80, 30)
	player._unhandled_input(motion)
	assert(player.rotation.y == old_yaw and player.camera_pivot.rotation.x == old_pitch)
	var press := InputEventKey.new()
	press.keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	var before_move: Vector3 = player.global_position
	await physics_frame
	await physics_frame
	press.pressed = false
	Input.parse_input_event(press)
	assert(is_equal_approx(player.global_position.z, before_move.z))
	for viewport_size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = viewport_size
		await process_frame
		menu._layout()
		assert(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(menu.get_rect()))
		var controls = menu.get_children().filter(func(node): return node is Control and node.visible)
		for index in range(controls.size()):
			assert(Rect2(Vector2.ZERO, menu.size).encloses(controls[index].get_rect()))
			assert(controls[index].get_combined_minimum_size().x <= controls[index].size.x)
			for other in range(index + 1, controls.size()):
				assert(not controls[index].get_rect().intersects(controls[other].get_rect()))
		await _capture("life_business_bargain_%dx%d.png" % [viewport_size.x, viewport_size.y])
	var before_close: Dictionary = shop.business.snapshot()
	menu.get_node("CloseButton").pressed.emit()
	assert(not menu.visible and customer.state == customer.State.NEGOTIATING)
	assert(shop.business.snapshot() == before_close)
	_open_offer()
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	player._unhandled_input(escape)
	assert(not menu.visible and not player._menu_is_open())
	_open_offer()
	menu.accept_button.pressed.emit()
	assert(not menu.visible and customer.state == customer.State.LEAVING)
	assert(shop.money == 50080 and shop.stock == 9 and shop.sales_revenue == 80)
	assert(shop.selling_price == 100 and ui.hud_money.text == shop.money_label.text)
	assert(shop.stock_label.text == "Stock: 9" and shop.revenue_label.text.ends_with("80"))
	assert(ui.feedback_label.text == "Sold for %s80." % String.chr(8377))
	var after_sale: Dictionary = shop.business.snapshot()
	menu.accept_button.pressed.emit()
	assert(not customer.resolve_bargain("accept") and shop.business.snapshot() == after_sale)
	customer = _prepare_customer()
	for invalid_counter in [70, 80, 85, 105, 110]:
		assert(not customer.resolve_bargain("counter", invalid_counter))
	assert(not customer.resolve_bargain("unknown"))
	assert(customer.state == customer.State.NEGOTIATING and shop.business.snapshot() == after_sale)
	_open_offer()
	menu.counter_input.value = 90
	menu.counter_button.pressed.emit()
	assert(shop.money == 50170 and shop.stock == 8 and shop.sales_revenue == 170)
	customer = _prepare_customer()
	_open_offer()
	var missed_before: int = shop.missed_sales
	menu.keep_button.pressed.emit()
	assert(shop.money == 50170 and shop.stock == 8 and shop.missed_sales == missed_before + 1)
	assert(shop.last_visit == "Offer refused" and not menu.visible)
	customer = _prepare_customer(1)
	_open_offer()
	menu.keep_button.pressed.emit()
	assert(shop.money == 50270 and shop.stock == 7 and shop.sales_revenue == 270)
	customer = _prepare_customer(0, 70)
	assert(customer.offer_price == 70 and customer.acceptable_price == 70)
	_open_offer()
	menu.counter_input.value = 80
	menu.counter_button.pressed.emit()
	assert(shop.money == 50270 and shop.stock == 7 and shop.last_visit == "Offer refused")
	customer = _prepare_customer()
	_open_offer()
	missed_before = shop.missed_sales
	customer._physics_process(20.1)
	menu._process(0.0)
	assert(not menu.visible and shop.missed_sales == missed_before + 1 and shop.last_visit == "Customer left")
	customer = _prepare_customer()
	_open_offer()
	shop.business.advance_clock(720.0)
	var closing_state: Dictionary = shop.business.snapshot()
	menu.accept_button.pressed.emit()
	assert(not menu.visible and shop.business.snapshot() == closing_state and customer.state == customer.State.LEAVING)
	shop.business.advance_clock(720.0)
	player.global_position = Vector3(0, 1.1, 0)
	customer = _prepare_customer()
	assert(customer.state == customer.State.LEAVING and not menu.visible)
	player.global_position = Vector3(-3, 1.1, 2.9)
	shop.player_inside = true
	assert(shop.business.set_selling_price(50))
	shop.sale_price_input.set_value_no_signal(50)
	customer = _prepare_customer()
	assert(customer.state == customer.State.LEAVING)
	assert(shop.business.set_selling_price(100))
	shop.sale_price_input.set_value_no_signal(100)
	customer = _prepare_customer()
	_open_offer()
	while shop.stock > 0:
		assert(shop.sell_one_stock(200))
	var empty_money: int = shop.money
	menu.accept_button.pressed.emit()
	assert(shop.money == empty_money and shop.stock == 0 and shop.last_visit == "Out of stock")
	assert(shop.business._is_valid_snapshot(shop.business.snapshot()))
	shop.business.save_path = save_path
	assert(shop.business.save_progress())
	var saved: Dictionary = shop.business.snapshot()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	assert(shop.money == saved["money"] and shop.stock == saved["stock"])
	assert(shop.sales_revenue == saved["sales_revenue"] and shop.missed_sales == saved["missed_sales"])
	assert(not current_scene.get_node("Ui/BargainMenu").visible)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	print("PASS: discounted accounting, accept/counter/keep, budgets/refusals, one-sale guard, timeout/closing/out-of-stock, away/floor-price autosales, E/Close/Escape, movement lock, responsive UI and save reload")
	quit()
