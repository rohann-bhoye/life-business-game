extends SceneTree

const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("life_business_checkout_%d.json" % Time.get_ticks_usec())
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
	assert(img.save_png(OS.get_environment("TEMP").path_join("checkout_%s.png" % label)) == OK)

func _press_e() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_E
	root.push_input(event)

func _stop() -> void:
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("ShopOperations").set_process(false)
	current_scene.get_node("StockWorker").set_physics_process(false)
	current_scene.get_node("Shop/ShopArea").business.save_path = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _advance(customer, target: int) -> void:
	for index in range(1600):
		if customer.state == target: return
		customer._physics_process(0.05)
	assert(false, "Customer state %d did not reach %d" % [customer.state, target])

func _check_layout(menu: Panel) -> void:
	var controls = menu.get_children().filter(func(node): return node is Control and node.visible)
	for index in range(controls.size()):
		assert(Rect2(Vector2.ZERO, menu.size).encloses(controls[index].get_rect()), str(controls[index].name))
		assert(controls[index].get_combined_minimum_size().x <= controls[index].size.x, str(controls[index].name))
		for other in range(index + 1, controls.size()):
			assert(not controls[index].get_rect().intersects(controls[other].get_rect()), "%s overlaps %s" % [controls[index].name, controls[other].name])

func _run() -> void:
	var state = Backend.new()
	assert(state.hire_worker() and state.staff_count() == 1)
	state.advance_clock(1440)
	assert(state.hire_stock_worker() and not state.hire_stock_worker())
	state.advance_clock(1440)
	assert(state.staff_count() == 2 and state.money == 47200 and state.wage_expenses == 600)
	assert(state._is_valid_snapshot(state.snapshot()))
	var version_six = Backend.new()
	assert(version_six.hire_worker() and version_six.order_stock())
	var legacy: Dictionary = version_six.snapshot()
	legacy["version"] = 6
	for field in ["staff_relations", "overtime_expenses", "inventory", "pending_product", "assistant_auto_collect"]: legacy.erase(field)
	for field in Backend.EMPLOYEE_FIELDS: legacy.erase(field)
	for field in Backend.STAFF_FIELDS + ["stock_worker_hired", "worker_carried_stock"]: legacy.erase(field)
	var legacy_path := _path()
	_write(legacy_path, legacy)
	var migrated = Backend.new()
	migrated.load_progress(legacy_path)
	assert(migrated.worker_hired and not migrated.stock_worker_hired and migrated.money == 48500 and migrated.supply_in_transit == 10)
	assert(migrated.save_progress() and migrated.snapshot()["version"] == 10)
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = _path()
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	_stop()
	var shop = current_scene.get_node("Shop/ShopArea")
	var ops = current_scene.get_node("ShopOperations")
	var player = current_scene.get_node("Player")
	var ui = current_scene.get_node("Ui")
	var spawner = current_scene.get_node("CustomerSpawner")
	var visitor = current_scene.get_node("Customer")
	visitor.set_physics_process(false)
	assert(ops.pc != ops.checkout_pc and ops.pc.get_parent().name == "ComputerDesk" and ops.checkout_pc.get_parent().name == "CheckoutCounter")
	player.global_position = Vector3(-2.5, 1.1, -0.6)
	player.rotation.y = PI
	player.camera_pivot.rotation.x = deg_to_rad(-22)
	await physics_frame
	await physics_frame
	await physics_frame
	for index in range(3):
		visitor.shopping_quantity = 3 - index
		visitor.payment_method = ["Cash", "Card", "UPI"][index]
		visitor.spending_budget = 200
		visitor.wants_discount = index == 0
		visitor.personality = 0
		assert(shop.business.set_selling_price(100 + index * 10))
		_advance(visitor, visitor.State.SCANNING)
		var before_money: int = shop.money
		var before_stock: int = shop.stock
		assert(ops.checkout_items.filter(func(item): return item.visible).size() == visitor.basket_count)
		assert(ops.available_stock() == before_stock - visitor.basket_count)
		visitor.complete_checkout()
		assert(shop.money == before_money and shop.stock == before_stock)
		if index == 0: await _capture("table")
		player.camera.look_at(ops.checkout_items[0].global_position + Vector3(0, 4, 0))
		assert(ops.try_interact() and visitor.scanned_count == 0 and not ui.checkout_menu.visible)
		assert(ui.feedback_label.text.begins_with("Aim at an unscanned"))
		for scanned in range(visitor.basket_count):
			player.camera.look_at(ops.checkout_items[scanned].global_position + Vector3(0, 0.15, 0))
			await _press_e()
			assert(visitor.scanned_count == scanned + 1)
			assert(shop.money == before_money and shop.stock == before_stock)
			assert(scanned in visitor.scanned_items)
			if index == 0 and scanned == 0:
				await create_timer(0.22).timeout
				ops._process(0.01)
				assert(ops.scanner_light.light_energy > 0.0)
		if index == 0:
			assert(ui.bargain_menu.visible and visitor.state == visitor.State.NEGOTIATING)
			ui.bargain_menu.accept_button.pressed.emit()
			assert(visitor.agreed_unit_price == 80 and ui.checkout_menu.visible)
			assert(visitor.payment_total() == 240 and visitor.cash_tendered == 300 and visitor.change_due() == 60)
		assert(visitor.state == visitor.State.PAYING and ops.payment_prop.visible)
		ops._process(0)
		assert(ops.checkout_display.text.contains(str(visitor.payment_total())))
		await _capture(visitor.payment_method.to_lower())
		for viewport_size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
			root.size = viewport_size
			await process_frame
			ui.checkout_menu._layout()
			_check_layout(ui.checkout_menu)
			if viewport_size == Vector2i(360, 640): await _capture("mobile")
		root.size = Vector2i(1152, 648)
		await process_frame
		var total: int = visitor.payment_total()
		var reviews_before: int = shop.business.customer_reviews.review_count
		var wrong_method: String = ["Card", "UPI", "Cash"][index]
		ui.checkout_menu.payment_buttons[wrong_method].pressed.emit()
		assert(visitor.state == visitor.State.PAYING and ui.checkout_menu.visible)
		assert(ui.checkout_menu.payment_label.text.contains("Wrong method"))
		assert(shop.money == before_money and shop.stock == before_stock)
		assert(shop.business.customer_reviews.review_count == reviews_before)
		ui.checkout_menu.payment_buttons[visitor.payment_method].pressed.emit()
		assert(shop.money == before_money + total and shop.stock == before_stock - visitor.basket_count)
		assert(ui.hud_money.text == shop.money_label.text)
		assert(ui.feedback_label.text.begins_with("Receipt:"))
		assert(shop.business.customer_reviews.review_count == reviews_before + 1)
		assert(visitor.service_wait_seconds > 0)
		var expected_score := clampi(80 - floori(minf(visitor.service_wait_seconds, 120.0) / 2.0) + (10 if visitor.agreed_unit_price < visitor.quoted_price else 0), 20, 100)
		assert(shop.business.customer_reviews.last_score == expected_score)
		assert(ui.shop_menu.get_node("ReputationLabel").text.contains("Last satisfaction:"))
		ui.checkout_menu.payment_buttons[visitor.payment_method].pressed.emit()
		visitor.complete_checkout()
		visitor.leave_shop()
		assert(shop.business.customer_reviews.review_count == reviews_before + 1)
		assert(shop.money == before_money + total and not ops.payment_prop.visible)
		assert(ops.checkout_items.filter(func(item): return item.visible).is_empty())
		visitor.queue_free()
		await process_frame
		spawner._on_spawn_timer_timeout()
		visitor = spawner.active_customer
		visitor.set_physics_process(false)
	assert(shop.stock == 4 and shop.money == 50580 and shop.business.items_sold == 6)
	visitor.shopping_quantity = 3
	visitor.wants_discount = false
	_advance(visitor, visitor.State.SCANNING)
	assert(visitor.scan_next())
	spawner._on_spawn_timer_timeout()
	var small_basket = spawner.active_customer
	small_basket.set_physics_process(false)
	small_basket.shopping_quantity = 3
	_advance(small_basket, small_basket.State.QUEUING)
	assert(small_basket.basket_count == 1 and ops.available_stock() == 0)
	spawner._on_spawn_timer_timeout()
	var empty_rack = spawner.active_customer
	empty_rack.set_physics_process(false)
	var reviews_before_failure: int = shop.business.customer_reviews.review_count
	_advance(empty_rack, empty_rack.State.LEAVING)
	assert(not empty_rack.has_product and shop.stock == 4)
	assert(shop.business.customer_reviews.last_score == 25 and shop.business.customer_reviews.review_count == reviews_before_failure + 1)
	small_basket.leave_shop()
	assert(shop.business.customer_reviews.review_count == reviews_before_failure + 1)
	small_basket.queue_free()
	empty_rack.queue_free()
	visitor._physics_process(61)
	assert(shop.business.customer_reviews.last_score == 10 and shop.business.customer_reviews.review_count == reviews_before_failure + 2)
	assert(shop.stock == 4 and shop.money == 50580 and ops.available_stock() == 4)
	assert(ops.checkout_items.filter(func(item): return item.visible).is_empty())
	visitor.queue_free()
	await process_frame
	player.global_position = Vector3(-1.1, 1.1, -0.7)
	player.rotation.y = 0
	player.camera_pivot.rotation.x = deg_to_rad(-12)
	assert(ops.try_interact() and ui.supplier_menu.visible and not ui.checkout_menu.visible)
	ui.supplier_menu.tabs.current_tab = 1
	ui.supplier_menu.cashier_button.pressed.emit()
	ui.supplier_menu.stock_worker_button.pressed.emit()
	assert(shop.business.staff_count() == 2 and shop.money == 48580)
	ui.supplier_menu.stock_worker_button.pressed.emit()
	assert(shop.money == 48580)
	for viewport_size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = viewport_size
		await process_frame
		ui.supplier_menu._layout()
		_check_layout(ui.supplier_menu)
	root.size = Vector2i(1152, 648)
	await process_frame
	await _capture("staff")
	assert(shop.business.order_stock())
	ops._process(5)
	ops._process(2)
	assert(shop.business.boxed_stock == 10 and shop.stock == 4 and ops.delivery_box.visible)
	shop.worker._on_restock_timer_timeout()
	var helper = current_scene.get_node("StockWorker")
	helper._physics_process(100)
	assert(shop.business.boxed_stock == 10 and shop.stock == 4 and helper.route.is_empty())
	ui.supplier_menu._refresh()
	assert(not ui.supplier_menu.assign_button.disabled)
	ui.supplier_menu.assign_button.pressed.emit()
	assert(not helper.assign_delivery())
	for frame in range(2400):
		if shop.business.worker_carried_stock == 10: break
		helper._physics_process(0.05)
	assert(shop.business.worker_carried_stock == 10 and shop.stock == 4 and not ops.delivery_box.visible)
	assert(helper.carrying_box.visible and not ops.carried_box.visible)
	var carrying_path := _path()
	_write(carrying_path, shop.business.snapshot())
	for frame in range(2400):
		if shop.business.worker_carried_stock == 0: break
		helper._physics_process(0.05)
	assert(shop.stock == 14 and shop.business.worker_carried_stock == 0)
	assert(shop.business._is_valid_snapshot(shop.business.snapshot()))
	var restart = load("res://main.tscn.tscn").instantiate()
	restart.get_node("Shop/ShopArea").save_path = carrying_path
	var restart_packed := PackedScene.new()
	assert(restart_packed.pack(restart) == OK)
	restart.free()
	change_scene_to_packed(restart_packed)
	await scene_changed
	await process_frame
	_stop()
	current_scene.get_node("Customer").set_physics_process(false)
	shop = current_scene.get_node("Shop/ShopArea")
	helper = current_scene.get_node("StockWorker")
	assert(shop.business.worker_carried_stock == 10 and helper.carrying_box.visible and shop.stock == 4)
	for frame in range(2400):
		if shop.business.worker_carried_stock == 0: break
		helper._physics_process(0.05)
	assert(shop.stock == 14 and shop.business._is_valid_snapshot(shop.business.snapshot()))
	shop.business.advance_clock(1440)
	assert(shop.business.wage_expenses == 400 and shop.business.operating_expenses == 100)
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: aimed E scanning, scanner motion/light, matching cash/card/UPI choice, wrong-method and duplicate-payment guards, receipts, employee checkout, responsive UI, physical assistant and save migration")
	quit()
