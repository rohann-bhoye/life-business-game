extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("performance_probe_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	camera.global_position = Vector3(24, 3, 9)
	camera.look_at(Vector3(-7, 2.5, 3))
	current_scene.get_node("Landscape").set_camera(camera)
	if "--cpu" in OS.get_cmdline_user_args():
		for path in ["Ui", "ShopOperations", "Warehouse", "RackFurnishing", "Neighbourhood/EnvironmentDetails", "Ui/NotificationFeed"]:
			var node := current_scene.get_node(path)
			if not node.has_method("_process"): continue
			var begin := Time.get_ticks_usec()
			for index in range(100): node.call("_process", 0.0)
			print("SCRIPT %s: %.3f ms per update" % [path, float(Time.get_ticks_usec() - begin) / 100000.0])
		quit()
		return
	var details = current_scene.get_node("Neighbourhood/EnvironmentDetails")
	var settings = preload("res://game_settings.gd").new()
	var ground: MeshInstance3D = current_scene.get_node("MeshInstance3D")
	var original: Material = ground.material_override
	var cheap := StandardMaterial3D.new()
	cheap.albedo_color = Color(0.26, 0.4, 0.18)
	var modes: Array = ["low_preset"] if "--low" in OS.get_cmdline_user_args() else ["current", "no_new_details", "no_sun_shadows"]
	if "--scaling" in OS.get_cmdline_user_args(): modes = ["native", "scaled_75"]
	for mode in modes:
		if mode == "low_preset":
			settings.graphics = 0
			settings.apply_graphics(current_scene)
		if mode == "native": root.scaling_3d_scale = 1.0
		if mode == "scaled_75": root.scaling_3d_scale = 0.75
		if mode == "no_new_details":
			details.hide()
			ground.material_override = cheap
		if mode == "no_sun_shadows":
			details.show()
			ground.material_override = original
			current_scene.get_node("DirectionalLight3D").shadow_enabled = false
		for warmup in range(40): await process_frame
		var times: Array[float] = []
		var start := Time.get_ticks_usec()
		var previous := start
		for frame in range(120):
			await process_frame
			var now := Time.get_ticks_usec()
			times.append(float(now - previous) / 1000.0)
			previous = now
		times.sort()
		print("PROFILE %s: %.1f FPS, p95 %.1f ms, CPU process %.2f ms, physics %.2f ms, draw calls %d, objects %d" % [mode, 120000000.0 / (previous - start), times[113], Performance.get_monitor(Performance.TIME_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("performance_%s.png" % mode))
	quit()
