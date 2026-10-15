extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(OS.get_environment("TEMP").path_join(file_name)) == OK)

func _run() -> void:
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("ShopOperations").enabled = false
	scene.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("life_business_character_preview_%d.json" % Time.get_ticks_usec())
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player = current_scene.get_node("Player")
	var customer = current_scene.get_node("Customer")
	var worker = current_scene.get_node("Worker")
	player.set_physics_process(false)
	player.set_process(false)
	customer.set_physics_process(false)
	customer._physics_process(3.1)
	assert(customer.visible and customer.state == customer.State.ARRIVING)
	customer._physics_process(100.0)
	assert(customer.state == customer.State.BUYING)
	var money_before: int = shop.money
	var stock_before: int = shop.stock
	customer._physics_process(1.1)
	assert(customer.state == customer.State.LEAVING)
	assert(shop.money == money_before + 100 and shop.stock == stock_before - 1)
	assert(shop.business.hire_worker())
	worker.get_node("RestockTimer").stop()
	player.global_position = Vector3(-1.5, 1.1, 4.5)
	customer.global_position = Vector3(0, 0.1, 4.5)
	worker.global_position = Vector3(1.5, 0.1, 4.5)
	for actor in [player, customer, worker]:
		actor.rotation.y = PI
	player.player_mesh.show()
	assert(player.player_mesh.mesh == null)
	assert(player.get_node("CollisionShape3D").shape is CapsuleShape3D)
	var visuals := [player.player_mesh, customer.get_node("CharacterVisual"), worker.get_node("CharacterVisual")]
	for visual in visuals:
		visual.set_process(false)
		assert(visual.body.mesh is BoxMesh and visual.head.mesh is CylinderMesh)
		assert(visual.head.get_node("Hair") is MeshInstance3D)
		assert(visual.left_arm.get_node("Hand") is MeshInstance3D)
		assert(visual.left_leg.get_node("Shoe") is MeshInstance3D)
		var start: Vector3 = visual.global_position
		visual.previous_position = start
		visual.global_position.x += 0.03
		visual._process(0.02)
		assert(visual.walk_blend > 0 and absf(visual.left_leg.rotation.x) > 0.001)
		assert(is_equal_approx(visual.left_leg.rotation.x, -visual.right_leg.rotation.x))
		visual.global_position = start
		visual.previous_position = start
		for frame in range(60):
			visual._process(0.02)
		assert(is_zero_approx(visual.walk_blend) and is_zero_approx(visual.left_leg.rotation.x))
		visual.rotation.y = 0.0
	assert(customer.get_node("Body") == visuals[1].body and worker.get_node("Head") == visuals[2].head)
	worker.get_node("CharacterVisual").play_work_animation()
	worker.get_node("CharacterVisual")._process(0.25)
	assert(worker.get_node("CharacterVisual").left_arm.rotation.x > 0.5)
	var preview_camera := Camera3D.new()
	preview_camera.name = "PreviewCamera"
	current_scene.add_child(preview_camera)
	preview_camera.position = Vector3(0, 2.7, 10)
	preview_camera.look_at(Vector3(0, 1.0, 4.5))
	preview_camera.current = true
	await process_frame
	await _capture("life_business_characters_front.png")
	for visual in visuals:
		visual.phase = 1.0
		visual.walk_blend = 1.0
		visual.previous_position = visual.global_position - Vector3(0.03, 0, 0)
		visual._process(0.02)
	preview_camera.position = Vector3(4, 3.0, 9.5)
	preview_camera.look_at(Vector3(0, 1.0, 4.5))
	await _capture("life_business_characters_walking.png")
	root.size = Vector2i(640, 480)
	await process_frame
	await _capture("life_business_characters_small.png")
	customer._physics_process(100.0)
	assert(customer.is_queued_for_deletion())
	assert(shop.money == money_before + 100 - 1000 and shop.stock == stock_before - 1)
	print("PASS: low-poly parts, preserved Body/Head and player collider, walk/idle poses, worker gesture, one customer purchase and despawn")
	quit()
