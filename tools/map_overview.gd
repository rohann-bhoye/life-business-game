extends SceneTree

# Top-down and angled overview screenshots of the whole map (temporary save).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("map_overview_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	root.size = Vector2i(1280, 720)
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	business.save_path = ""
	business.advance_clock(2 * 1440.0 + 120.0)
	current_scene.get_node("Player").set_physics_process(false)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	camera.far = 400
	current_scene.get_node("Landscape").set_camera(camera)
	var shots := {"top": [Vector3(0, 95, 6), Vector3(0, 0, 5.9)], "angle": [Vector3(0, 40, 55), Vector3(0, 0, 0)], "west": [Vector3(-55, 25, 30), Vector3(-10, 0, 0)], "road": [Vector3(-20, 2, 7.5), Vector3(-70, 1, 7.5)], "rival": [Vector3(21, 2.2, 6), Vector3(25, 1, 15)]}
	for name in shots:
		if name == "rival": await create_timer(9.0).timeout
		camera.global_position = shots[name][0]
		camera.look_at(shots[name][1], Vector3.FORWARD if name == "top" else Vector3.UP)
		for frame in range(8): await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("map_%s.png" % name))
	print("Sharma sale today: ", business.rival_sale())
	# Town edge: see-through barrier and the 3-2-1 send-home countdown.
	var player: Node3D = current_scene.get_node("Player")
	player.global_position = Vector3(30.0, 1.1, 8.5)
	camera.global_position = Vector3(18, 2.4, 9.5)
	camera.look_at(Vector3(32, 1.4, 7.5), Vector3.UP)
	await create_timer(1.2).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("map_edge.png"))
	await create_timer(2.5).timeout
	print("Sent home: ", player.global_position.distance_to(Vector3(30.0, 1.1, 8.5)) > 20.0)
	# Night: stars, lamps, headlights, fewer people, Sharma closed.
	business.advance_clock(22 * 60.0 - business.minutes_of_day)
	for name in ["road", "rival"]:
		camera.global_position = shots[name][0]
		camera.look_at(shots[name][1], Vector3.UP)
		for frame in range(8): await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("map_night_%s.png" % name))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: map overview")
	quit()
