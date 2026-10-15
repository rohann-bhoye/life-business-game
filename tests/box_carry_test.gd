extends SceneTree

const Catalog = preload("res://product_catalog.gd")
const Backend = preload("res://business_backend.gd")
var save_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _press_e() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_E
	root.push_input(event)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	assert(not img.is_empty())
	assert(img.get_pixel(img.get_width() / 2, img.get_height() * 3 / 4) != img.get_pixel(0, 0))
	assert(img.save_png(OS.get_environment("TEMP").path_join("carry_%s.png" % label)) == OK)

func _run() -> void:
	save_path = OS.get_environment("TEMP").path_join("life_carry_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = save_path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	root.size = Vector2i(1152, 648)
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Customer").set_physics_process(false)
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	var ops = current_scene.get_node("ShopOperations")
	ops.set_process(false)
	var business = current_scene.get_node("Shop/ShopArea").business
	var ui = current_scene.get_node("Ui")
	var box = player.get_node("CarriedBox")
	for product in ["bottle", "snack", "soap"]:
		assert(business.order_stock(product) and business.receive_delivery())
		player.position = ops.drop_point + Vector3(0, 1, 0)
		player.shop_indoors = false
		await _press_e()
		assert(business.carried_stock == 10 and box.visible)
		assert(box.get_node("LeftGrip").position.x < -0.4)
		assert(box.get_node("RightGrip").position.x > 0.4)
		# Racks are mixed: every other rack with an empty row also accepts this product.
		for wrong in ["bottle", "snack", "soap"]:
			if wrong == product: continue
			var other: Dictionary = business.racks.find(["bottle", "snack", "soap"].find(wrong))
			assert(business.racks.supports(other, product))
		player.position = Vector3(-3.5, 1.1, -3.3)
		player.rotation = Vector3.ZERO
		player.shop_indoors = true
		player.spring_arm.spring_length = 0
		player.camera.position = Vector3.ZERO
		player.camera_pivot.rotation.x = -0.15
		await physics_frame
		await process_frame
		player.shop_indoors = true
		box._process(0.016)
		assert(box.get_node("LeftCarryForearm").visible)
		assert(player.camera.to_local(box.global_position).distance_to(Vector3(0, -0.35, -1.15)) < 0.04)
		await _capture(product + "_first_person")
		if product == "bottle":
			for pitch in [-0.8, 0.4]:
				player.camera_pivot.rotation.x = pitch
				box._process(0.016)
				assert(player.camera.to_local(box.global_position).distance_to(Vector3(0, -0.35, -1.15)) < 0.04)
			player.camera_pivot.rotation.x = -0.15
			root.size = Vector2i(640, 480)
			await _capture("compact")
			root.size = Vector2i(1152, 648)
		box.set_process(false)
		var resting: Vector3 = box.position
		for step in range(15):
			player.position.z -= 0.02
			box._process(0.016)
		assert(box.walk_blend > 0.9 and not box.position.is_equal_approx(resting))
		for step in range(30): box._process(0.016)
		assert(is_zero_approx(box.walk_blend))
		box.set_process(true)
		player.position = Vector3(-6.8, 1.1, 4.7)
		player.shop_indoors = false
		player.spring_arm.spring_length = 4.5
		player.spring_arm.rotation.y = 0.75
		await physics_frame
		await process_frame
		player.shop_indoors = false
		box._process(0.016)
		assert(not box.get_node("LeftCarryForearm").visible)
		var visual = player.get_node("MeshInstance3D")
		assert(not visual.left_arm.get_node("Hand").visible)
		await _capture(product + "_third_person")
		player.spring_arm.rotation.y = 0
		if product == "bottle":
			var origin: Vector3 = player.position
			var key := InputEventKey.new()
			key.keycode = KEY_D
			key.pressed = true
			Input.parse_input_event(key)
			player.set_physics_process(true)
			for frame in range(18):
				await physics_frame
				box._process(1.0 / 60.0)
			assert(player.position.distance_to(origin) > 0.1, "Walking input did not move player: %s" % player.position)
			assert(box.walk_blend > 0.1, "Walking sway did not engage: %s" % box.walk_blend)
			key = InputEventKey.new()
			key.keycode = KEY_D
			Input.parse_input_event(key)
			player.set_physics_process(false)
			player.velocity = Vector3.ZERO
		player.position = ops.rack_target(product) + Vector3(0, 1, 0)
		player.shop_indoors = true
		player.rotation.y = PI / 2
		player.spring_arm.spring_length = 0
		player.camera_pivot.rotation.x = -0.15
		var stock: int = business.product_stock(product)
		await _press_e()
		assert(business.product_stock(product) == stock + 1 and business.carried_stock == 9 and box.visible)
		assert(box.place_animation_remaining > 0.0)
		box._process(0.08)
		assert(box.get_node("RightGrip").position.x > 0.45)
		var shelf_items: Array = ops.rack_bottles if product == "bottle" else ops.product_items[product]
		var placed_item: Node3D = shelf_items[mini(stock, shelf_items.size() - 1)]
		assert(placed_item.visible and placed_item.scale.x < 1.0)
		assert(box.get_node("BoxLabel").text.begins_with("9 "))
		assert(ui.feedback_label.text.contains("9 left in box"))
		if product == "bottle": await _capture("placing_item")
		assert(business.save_progress())
		var restored = Backend.new()
		restored.load_progress(save_path)
		assert(restored.carried_stock == 9 and restored.product_stock(product) == stock + 1)
		await create_timer(0.4).timeout
		assert(placed_item.scale.is_equal_approx(Vector3.ONE))
		if product == "bottle":
			player.shop_indoors = true
			player.camera_pivot.rotation.x = -0.15
			box._process(0.016)
			await _capture("partial_box_9")
			player.position = ops.drop_point + Vector3(0, 1, 0)
			player.shop_indoors = false
			await _press_e()
			assert(business.boxed_stock == 9 and business.carried_stock == 0 and not box.visible)
			await _press_e()
			assert(business.boxed_stock == 0 and business.carried_stock == 9 and box.visible)
		player.position = ops.rack_target(product) + Vector3(0, 1, 0)
		for remaining in range(8, -1, -1):
			await _press_e()
			assert(business.carried_stock == remaining)
			if remaining > 0: assert(box.get_node("BoxLabel").text.begins_with("%d " % remaining))
		assert(business.product_stock(product) == stock + 10 and box.visible and box.hide_after_place)
		assert(ui.feedback_label.text.begins_with("Box empty."))
		await create_timer(0.4).timeout
		assert(not box.visible)
		assert(visual.left_arm.get_node("Hand").visible and visual.left_arm.scale.is_equal_approx(Vector3.ONE))
	assert(business.order_stock("snack") and business.receive_delivery())
	player.position = ops.drop_point + Vector3(0, 1, 0)
	await _press_e()
	await _press_e()
	assert(business.boxed_stock == 10 and business.carried_stock == 0 and not box.visible)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(save_path + suffix)
	print("PASS: two-hand carry, sway, hand reach/shelf landing, one-item shelving, partial save/return, wrong-rack guards and final empty box.")
	quit()
