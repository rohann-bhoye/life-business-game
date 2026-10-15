extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("busy_shop_probe_%d.json" % Time.get_ticks_usec())
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
	for sku in ["soap", "snack"]:
		assert(business.order_stock(sku) and business.receive_delivery() and business.pick_up_box())
		assert(business.shelve_box(false))
	assert(business.hire_worker() and business.hire_stock_worker() and business.hire_warehouse_worker())
	assert(business.order_stock("bottle", 8) and business.receive_delivery())
	business.save_path = path
	assert(business.save_progress())
	var saves: Array[float] = []
	for index in range(10):
		var start := Time.get_ticks_usec()
		assert(business.save_progress())
		saves.append(float(Time.get_ticks_usec() - start) / 1000.0)
	saves.sort()
	print("SAVE median %.2f ms, max %.2f ms" % [saves[5], saves[9]])
	if "--save-only" in OS.get_cmdline_user_args():
		quit()
		return
	var spawner = current_scene.get_node("CustomerSpawner")
	spawner._on_spawn_timer_timeout()
	spawner._on_spawn_timer_timeout()
	assert(spawner.customers.size() == 3)
	var process_nodes: Array = []
	for name in ["Ui", "ShopOperations", "Warehouse", "Ui/NotificationFeed"]:
		var node := current_scene.get_node(name)
		node.set_process(false)
		process_nodes.append(node)
	var samples := {}
	for node in process_nodes: samples[node.name] = []
	var player := current_scene.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(-1.2, 1.1, -1.0)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	camera.global_position = Vector3(-0.5, 2, 1.8)
	camera.look_at(Vector3(-4, 1.2, -1))
	current_scene.get_node("Landscape").set_camera(camera)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var frames: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in range(240):
		await process_frame
		var now := Time.get_ticks_usec()
		var delta := float(now - previous) / 1000000.0
		previous = now
		if frame > 39: frames.append(delta * 1000.0)
		for node in process_nodes:
			var start := Time.get_ticks_usec()
			node.call("_process", delta)
			samples[node.name].append(float(Time.get_ticks_usec() - start) / 1000.0)
	frames.sort()
	print("BUSY frame median %.2f ms, p95 %.2f ms, physics %.2f ms, draws %d" % [frames[frames.size()/2], frames[int(frames.size()*0.95)], Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	for name in samples:
		var values: Array = samples[name]
		values.sort()
		print("BUSY SCRIPT %s median %.3f ms, max %.3f ms" % [name, values[values.size()/2], values.back()])
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("busy_shop_profile.png"))
	print("PASS: busy shop profile, temporary save only")
	quit()
