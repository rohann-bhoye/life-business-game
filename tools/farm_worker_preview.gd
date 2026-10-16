extends SceneTree

# Screenshots of Kiran working the farm and the tablet Farm tab (temporary save).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("farm_worker_preview_%d.json" % Time.get_ticks_usec())
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
	assert(business.hire_farm_worker() and business.set_farm_crop("cabbage") and business.buy_seeds(3))
	var worker = current_scene.get_node("Farm/FarmWorker")
	for step in range(500): worker._physics_process(0.05)
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	current_scene.get_node("Landscape").set_camera(camera)
	camera.global_position = worker.global_position + Vector3(2.5, 1.8, 2.5)
	camera.look_at(worker.global_position + Vector3(0, 0.8, 0))
	for frame in range(6): await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("farm_worker.png"))
	camera.queue_free()
	player.shop_indoors = true
	player.global_position = Vector3(-2.5, 1.1, -4)
	player.rotation.y = PI
	player.spring_arm.spring_length = 0
	var ui = current_scene.get_node("Ui")
	ui.shop_menu.show()
	ui.select_tab(5)
	for frame in range(6): await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("farm_tab.png"))
	business.save_path = ""
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: farm worker preview")
	quit()
