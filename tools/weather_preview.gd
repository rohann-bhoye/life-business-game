extends SceneTree

# Screenshot of a rainy day on the street with the rival Sharma store (temporary save).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("weather_preview_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	root.size = Vector2i(1152, 648)
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	business.save_path = ""
	var rainy := 3
	while business.weather_for_day(rainy) != "rain": rainy += 1
	business.advance_clock((rainy - 1) * 1440.0 + 180.0)
	current_scene.get_node("DayClock")._process(0.0)
	print("DAY ", business.day, " raining=", business.is_raining(), " rival=", business.rival_open())
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(25, 1.1, 8.0)
	player.rotation.y = PI
	player.camera_pivot.rotation.x = deg_to_rad(-5)
	for frame in range(90): await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("weather_rain.png"))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: weather preview")
	quit()
