extends SceneTree

const Backend = preload("res://business_backend.gd")
var save_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _load_scene() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = save_path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	for name in ["Player", "Customer", "StockWorker"]:
		current_scene.get_node(name).set_physics_process(false)
	current_scene.get_node("ShopOperations").set_process(false)

func _finish_route(worker) -> void:
	for frame in range(1200):
		worker._physics_process(0.05)
		if worker.route.is_empty(): return
	assert(false, "Sunil did not complete his route")

func _run() -> void:
	for minute in [480.0, 720.0, 1199.0]:
		var blocked = Backend.new()
		assert(blocked.buy_house())
		blocked.advance_clock(minute - 480.0)
		var before: Dictionary = blocked.snapshot()
		assert(not blocked.sleep_time_allowed() and not blocked.sleep_until_morning())
		assert(blocked.snapshot() == before)
	for minute in [1200.0, 1439.0]:
		var evening = Backend.new()
		assert(evening.buy_house())
		evening.advance_clock(minute - 480.0)
		var cash: int = evening.money
		assert(evening.sleep_until_morning())
		assert(evening.day == 2 and evening.minutes_of_day == 480 and evening.money == cash - 100)
		assert(not evening.sleep_until_morning())
	for minute in [0.0, 479.0]:
		var dawn = Backend.new()
		assert(dawn.buy_house())
		dawn.advance_clock(960.0 + minute)
		var cash: int = dawn.money
		assert(dawn.day == 2 and dawn.operating_expenses == 100)
		assert(dawn.sleep_until_morning())
		assert(dawn.day == 2 and dawn.minutes_of_day == 480 and dawn.money == cash)

	save_path = OS.get_environment("TEMP").path_join("sleep_staff_day_%d.json" % Time.get_ticks_usec())
	await _load_scene()
	var business = current_scene.get_node("Shop/ShopArea").business
	assert(business.buy_house() and business.hire_worker(2) and business.hire_stock_worker())
	assert(business.set_staff_shift("cashier", 480, 1080) and business.set_staff_shift("stock", 480, 1080))
	assert(business.order_stock("soap", 2) and business.receive_delivery())
	var worker = current_scene.get_node("StockWorker")
	assert(worker.assign_delivery())
	for frame in range(600):
		worker._physics_process(0.05)
		if business.worker_carried_stock > 0: break
	assert(business.worker_carried_stock == 10 and business.pending_product == "soap")
	assert(business.set_employee_work("stock", false))
	var location: Vector3 = worker.position
	worker._physics_process(30)
	assert(worker.position == location and business.worker_carried_stock == 10)
	assert(business.save_progress())
	await _load_scene()
	business = current_scene.get_node("Shop/ShopArea").business
	worker = current_scene.get_node("StockWorker")
	assert(business.worker_carried_stock == 10 and not business.stock_worker_on_shift())
	assert(not worker.route.is_empty())
	assert(business.set_employee_work("stock", true))
	_finish_route(worker)
	assert(business.product_stock("soap") == 10 and business.boxed_stock == 10)
	assert(worker.assign_delivery())
	_finish_route(worker)
	assert(business.product_stock("soap") == 20 and business.worker_carried_stock == 0)

	# Exercise actual timed checkout during the shift, rather than direct backend sales.
	var player = current_scene.get_node("Player")
	player.position = current_scene.get_node("House").to_global(Vector3(0, 1.0, 0))
	var visitor = current_scene.get_node("Customer")
	visitor.state = visitor.State.SCANNING
	visitor.has_product = true
	visitor.product_id = "bottle"
	visitor.basket_count = 2
	visitor.scanned_count = 0
	visitor.agreed_unit_price = 100
	visitor.quoted_price = 100
	visitor.wants_discount = false
	visitor.spending_budget = 400
	visitor.bargain_seconds_left = 60
	visitor.auto_checkout_seconds = business.cashier_scan_seconds()
	var ops = current_scene.get_node("ShopOperations")
	ops.enqueue(visitor)
	ops.show_basket(visitor)
	visitor._physics_process(1)
	assert(visitor.scanned_count == 0)
	visitor._physics_process(1)
	assert(visitor.scanned_count == 1)
	visitor._physics_process(2)
	assert(visitor.state == visitor.State.PAYING and business.items_sold == 0)
	visitor._physics_process(1)
	assert(business.items_sold == 2 and business.sales_revenue == 200)

	business.advance_clock(600)
	assert(not business.cashier_on_shift() and not business.stock_worker_on_shift())
	assert(business.staff.records.cashier.state == "leave" and business.staff.records.stock.state == "leave")
	assert(business.staff.reply(business, "stock", "home"))
	assert(business.staff.reply(business, "cashier", "overtime"))
	assert(business.cashier_on_shift() and not business.stock_worker_on_shift())
	business.advance_clock(59)
	assert(business.cashier_on_shift())
	business.advance_clock(1)
	assert(not business.cashier_on_shift() and business.staff.records.cashier.state == "pay")
	var before_pay: int = business.money
	assert(business.staff.reply(business, "cashier", "pay"))
	assert(business.money == before_pay - 50 and not business.staff.reply(business, "cashier", "pay"))
	business.advance_clock(60)
	assert(business.minutes_of_day == 1200)
	var cash: int = business.money
	assert(business.sleep_until_morning())
	assert(business.day == 2 and business.money == cash - 500 and business.unpaid_bills() == 0)
	assert(business.cashier_on_shift() and business.stock_worker_on_shift())
	assert(business.staff.records.cashier.unpaid == 0 and business.product_stock("soap") == 20)
	var restored = Backend.new()
	restored.load_progress(save_path)
	assert(restored.snapshot() == business.snapshot())

	# Early E is consumed with HUD feedback; it never opens a menu or changes time.
	player.indoors = true
	player.global_position = current_scene.get_node("House").to_global(Vector3(-1, 1.0, -0.7))
	await physics_frame
	await physics_frame
	await physics_frame
	var bed = current_scene.get_node("House/Bed/SleepArea")
	var ui = current_scene.get_node("Ui")
	bed._process(0)
	assert(bed.overlaps_body(player) and bed.sleep_sign.text == "Sleep after 20:00", "overlap=%s sign=%s position=%s" % [bed.overlaps_body(player), bed.sleep_sign.text, player.global_position])
	var before: Dictionary = business.snapshot()
	assert(bed.try_sleep())
	assert(business.snapshot() == before and ui.feedback_label.text.contains("after 20:00"))
	assert(not player._menu_is_open() and not bed.try_sleep())
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1152, 648)
		player.camera.look_at(current_scene.get_node("House/Bed").global_position)
		await process_frame
		await RenderingServer.frame_post_draw
		var preview := OS.get_environment("TEMP").path_join("sleep_daytime_feedback.png")
		assert(root.get_texture().get_image().save_png(preview) == OK)
		print("PREVIEW: " + preview)
	business.advance_clock(720)
	bed.next_sleep_msec = 0
	bed._process(0)
	assert(bed.sleep_sign.text == "Sleep until morning")
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	bed._unhandled_input(event)
	assert(business.day == 3 and business.minutes_of_day == 480)
	assert(ui.feedback_label.text == "Day 3. Rested until morning.")
	assert(not bed.try_sleep())
	print("PASS: daytime sleep guard/HUD, night/dawn boundaries, single billing, Sunil mid-box save/pause/resume, timed cashier checkout, full-day shifts/overtime/pay and next-morning duties")
	quit()
