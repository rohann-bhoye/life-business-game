extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _capture(terrain, camera: Camera3D, size: Vector2i) -> void:
	root.size = size
	terrain.set_camera(camera)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered: Image = root.get_texture().get_image()
	assert(rendered.save_png(OS.get_environment("TEMP").path_join("terrain_neighbourhood_%dx%d.png" % [size.x, size.y])) == OK)
	terrain.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden: Image = root.get_texture().get_image()
	var changed := 0
	for y in range(0, size.y, 8):
		for x in range(0, size.x, 8):
			if rendered.get_pixel(x, y) != hidden.get_pixel(x, y): changed += 1
	assert(changed > 200, "Terrain mesh did not render in the desktop view")
	terrain.show()
	await process_frame

func _run() -> void:
	assert(ClassDB.class_exists("Terrain3D"), "Installed Terrain3D extension failed to load")
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("terrain_test_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	for name in ["Player", "Customer", "StockWorker"]: current_scene.get_node(name).set_physics_process(false)
	current_scene.get_node("ShopOperations").set_process(false)
	current_scene.get_node("Neighbourhood/StreetLife").set_physics_process(false)
	var terrain = current_scene.get_node("Landscape")
	assert(terrain.get_class() == "Terrain3D" and terrain.version == "1.0.2")
	assert(terrain.data.get_regions_active().size() == 4 and terrain.region_size == 128)
	assert(terrain.collision_mode == 0 and terrain.material.world_background == 0)
	assert(terrain.assets.get_texture_count() == 1)
	assert(terrain.assets.get_texture(0).albedo_texture != null and terrain.assets.get_texture(0).normal_texture != null)
	for position in [Vector3.ZERO, Vector3(-6.8, 0, 3.5), Vector3(4, 0, -4), Vector3(31, 0, 31), Vector3(-31, 0, -31)]:
		assert(is_equal_approx(terrain.data.get_height(position), 0.08), "Terrain raised an existing gameplay area")
	assert(terrain.data.get_height(Vector3(83, 0, -55)) > 20)
	assert(terrain.data.get_height(Vector3(-75, 0, -82)) > 17)
	var business = current_scene.get_node("Shop/ShopArea").business
	var before: Dictionary = business.snapshot()
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(15, 2, 7), Vector3(15, -1, 7)))
	assert(not hit.is_empty() and is_equal_approx(hit.position.y, 0.1))
	assert(hit.collider == current_scene.get_node("Ground"))
	assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(30, 1, 7), Vector3(33, 1, 7))).is_empty())
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	camera.position = Vector3(15, 9, 28)
	camera.look_at(Vector3(10, 4, -42))
	terrain.set_camera(camera)
	if DisplayServer.get_name() != "headless":
		for size in [Vector2i(1152, 648), Vector2i(1920, 1080)]: await _capture(terrain, camera, size)
	assert(business.snapshot() == before, "Scenery must not mutate save/economy")
	var restored = load("res://neighbourhood_landscape.tscn").instantiate()
	current_scene.add_child(restored)
	assert(restored.data.get_regions_active().size() == 4)
	assert(is_equal_approx(restored.data.get_height(Vector3.ZERO), 0.08))
	restored.queue_free()
	print("PASS: Terrain3D 1.0.2 load, four persisted grass regions, flat shop/road/delivery areas, hills, unchanged collision/boundaries/economy and desktop render checks")
	quit()
