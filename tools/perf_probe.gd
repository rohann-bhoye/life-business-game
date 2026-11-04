extends SceneTree

# Frame cost at several spots in the town, on Low (0) and High (2) graphics: average and
# worst frame time (ms), draw calls, and primitives drawn. Needs a window, vsync is turned off.
#   Godot --path . --script res://tools/perf_probe.gd [-- 0|1|2]
const SPOTS := {
	"shop_inside": [Vector3(-3.0, 1.75, 2.25), Vector3(-3.0, 1.55, -7.0)],
	"main_road": [Vector3(-6.0, 2.0, 7.0), Vector3(14.0, 2.0, 7.0)],
	"home_lane": [Vector3(-47.0, 2.4, -6.0), Vector3(-61.0, 1.6, -6.0)],
	"market": [Vector3(46.0, 2.4, 6.0), Vector3(50.0, 2.0, -30.0)],
	"warehouse_in": [Vector3(-4.0, 1.8, 16.4), Vector3(-4.0, 1.2, 28.0)],
	"overview": [Vector3(-20.0, 30.0, 40.0), Vector3(0.0, 0.0, -10.0)],
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var levels: Array = [int(OS.get_cmdline_user_args()[0])] if OS.get_cmdline_user_args().size() > 0 else [0, 2]
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("perf_probe_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	packed.pack(fixture)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player").hide()
	world.get_node("Ui").visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 75
	for frame in range(30): await process_frame
	var vp_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var scale_override := OS.get_environment("PERF_SCALE")
	var no_grade := OS.get_environment("PERF_NO_GRADE") != ""
	for level in levels:
		var settings = preload("res://game_settings.gd").new()
		settings.graphics = level
		settings.apply_graphics(world)
		if scale_override != "": root.scaling_3d_scale = float(scale_override)
		for hide_name in OS.get_environment("PERF_HIDE").split(",", false):
			var hidden := world.get_node_or_null(hide_name)
			if hidden == null: hidden = world.find_child(hide_name, true, false)
			if hidden != null: hidden.visible = false
		if OS.get_environment("PERF_NO_BRICKNORMAL") != "":
			preload("res://brick_works.gd").brick_material().normal_enabled = false
		if OS.get_environment("PERF_NO_TRIPLANAR") != "":
			preload("res://brick_works.gd").brick_material().uv1_triplanar = false
		if OS.get_environment("PERF_NO_OMNI") != "":
			for light in world.find_children("*", "OmniLight3D", true, false): light.visible = false
			for light in world.find_children("*", "SpotLight3D", true, false): light.visible = false
		if OS.get_environment("PERF_NO_SUN") != "":
			world.get_node("DirectionalLight3D").visible = false
			for light in world.find_children("*", "DirectionalLight3D", true, false): light.visible = false
		if OS.get_environment("PERF_NO_SKY") != "":
			var sky_env: Environment = world.get_node("WorldEnvironment").environment
			sky_env.background_mode = Environment.BG_COLOR
			sky_env.fog_enabled = false
		if no_grade:
			var env: Environment = world.get_node("WorldEnvironment").environment
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.glow_enabled = false
			env.adjustment_enabled = false
		for frame in range(20): await process_frame
		for name in SPOTS:
			camera.global_position = SPOTS[name][0]
			camera.look_at(SPOTS[name][1])
			for frame in range(15): await process_frame
			var times: Array = []
			var last := Time.get_ticks_usec()
			for frame in range(90):
				await process_frame
				var now := Time.get_ticks_usec()
				times.append((now - last) / 1000.0)
				last = now
			var total := 0.0
			var worst := 0.0
			for t in times:
				total += t
				worst = maxf(worst, t)
			var vp := root.get_viewport()
			print("PERF level=%d %-13s avg %5.1f ms (%3.0f fps)  worst %5.1f ms  cpu %4.1f gpu %4.1f  draws %4d  prims %7d" % [level, name, total / times.size(), 1000.0 * times.size() / total, worst, RenderingServer.viewport_get_measured_render_time_cpu(vp_rid), RenderingServer.viewport_get_measured_render_time_gpu(vp_rid),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	quit()
