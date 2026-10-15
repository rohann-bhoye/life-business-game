extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	assert(not img.is_empty())
	assert(img.save_png(OS.get_environment("TEMP").path_join("queue_patience_%s.png" % label)) == OK)

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("queue_patience_%d.json" % Time.get_ticks_usec())
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("ShopOperations").set_process(false)
	var shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	var ops = current_scene.get_node("ShopOperations")
	var ui = current_scene.get_node("Ui")
	var first = current_scene.get_node("Customer")
	first.set_physics_process(false)
	first.personality = 1
	first.customer_name = "Meena - Regular"
	first.state = first.State.SCANNING
	first.has_product = true
	first.basket_count = 3
	first.bargain_seconds_left = 60
	ops.enqueue(first)
	ops.show_basket(first)
	var second = load("res://customer.tscn").instantiate()
	second.shop_area_path = first.shop_area_path
	second.purchase_point_path = first.purchase_point_path
	second.exit_point_path = first.exit_point_path
	current_scene.add_child(second)
	second.set_physics_process(false)
	second.personality = 2
	second.customer_name = "Aman - In a hurry"
	second.state = second.State.QUEUING
	second.has_product = true
	second.basket_count = 3
	second.visible = true
	ops.enqueue(second)
	second.global_position = ops.queue_position(second)
	assert(ops.available_stock() == 4)
	assert(second.queue_patience_limit() == 60 and first.queue_patience_limit() == 120)
	second._physics_process(44)
	assert(not second.queue_is_impatient() and second.patience_label.visible)
	second._physics_process(1)
	ui.notifications.refresh()
	var key := "queue:" + str(second.get_instance_id())
	assert(second.queue_is_impatient() and ui.notifications.entries.has(key))
	assert(ui.notifications.rows[key].text.contains("15s"))
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	player.shop_indoors = true
	player.global_position = Vector3(-2.5, 1.1, -1.5)
	player.spring_arm.spring_length = 0
	var preview := Camera3D.new()
	current_scene.add_child(preview)
	preview.global_position = second.global_position + Vector3(0, 1.6, -3.2)
	preview.look_at(second.global_position + Vector3(0, 1.6, 0))
	preview.make_current()
	for size in [Vector2i(1152, 648), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		ui.notifications.refresh()
		assert(ui.notifications.size.x <= size.x - 32)
		await _capture("%dx%d" % [size.x, size.y])
	assert(ops.checkout_customer() == first and second in ops.queue)
	second._physics_process(15)
	assert(second.state == second.State.LEAVING and second not in ops.queue)
	assert(not second.has_product and not second.patience_label.visible and ops.available_stock() == 7)
	assert(shop.money == 50000 and shop.stock == 10 and shop.business.items_sold == 0)
	assert(shop.business.missed_sales == 1 and shop.business.customer_reviews.review_count == 1)
	assert(shop.business.customer_reviews.last_score == 10)
	assert(ui.feedback_label.text == "Aman left: queue too slow.")
	second._physics_process(0)
	second.leave_shop()
	assert(shop.business.missed_sales == 1 and shop.business.customer_reviews.review_count == 1)
	ui.notifications.refresh()
	assert(not ui.notifications.entries.has(key) and ops.checkout_customer() == first)
	first.state = first.State.QUEUING
	first.queue_wait_seconds = 119
	first.global_position = ops.queue_position(first)
	first._physics_process(0.1)
	assert(first.state == first.State.BUYING)
	first._physics_process(0.1)
	assert(not first.patience_label.visible and first.queue_wait_seconds < 120)
	first.state = first.State.QUEUING
	first.queue_wait_seconds = 120
	shop.business.minutes_of_day = 1200
	first._physics_process(1)
	assert(first.state == first.State.LEAVING and ops.available_stock() == 10)
	assert(shop.business.customer_reviews.review_count == 1 and shop.business.missed_sales == 1)
	assert(shop.business._is_valid_snapshot(shop.business.snapshot()))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: personality patience, live countdown, impatient notice, timeout stock return, next-customer order, single review/missed sale, checkout transition and neutral closing")
	quit()
