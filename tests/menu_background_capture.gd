extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var scene = load("res://main.tscn.tscn").instantiate()
	var path := OS.get_environment("TEMP").path_join("menu_background_%d.json" % Time.get_ticks_usec())
	scene.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1600, 900)
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Shop/ShopArea").business.save_path = ""
	current_scene.get_node("Ui").visible = false
	for node_name in ["Player", "Customer", "Worker", "StockWorker"]:
		current_scene.get_node(node_name).hide()
		current_scene.get_node(node_name).set_physics_process(false)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.global_position = Vector3(-13.5, 5.5, 14)
	camera.look_at(Vector3(-2.5, 1.5, 0))
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://assets/ui/main_menu_shop_v2.png" if "--polished" in OS.get_cmdline_user_args() else "res://assets/ui/main_menu_shop.png"
	assert(root.get_texture().get_image().save_png(output) == OK)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: actual shop main-menu background captured without owner saves")
	quit()
