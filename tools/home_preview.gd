extends SceneTree

# Screenshots of the furnished home, inside and outside (temporary save only).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("home_preview_%d.json" % Time.get_ticks_usec())
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
	current_scene.get_node("Shop/ShopArea").business.save_path = ""
	current_scene.get_node("Player").set_physics_process(false)
	var house: Node3D = current_scene.get_node("House")
	assert(house.get_node_or_null("HomeDecor") != null)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	current_scene.get_node("Landscape").set_camera(camera)
	for frame in range(10): await process_frame
	var player = current_scene.get_node("Player")
	print("SPAWN local=%s indoors=%s owned=%s" % [house.to_local(player.global_position), player.indoors, current_scene.get_node("Shop/ShopArea").business.house_owned])
	var shots := {"bedroom": [Vector3(0.4, 1.7, 0.9), Vector3(-2.2, 0.6, -2.8)], "living": [Vector3(-0.3, 1.7, 0.9), Vector3(2.8, 0.6, -2.4)], "kitchen": [Vector3(1.5, 1.7, -2.2), Vector3(-2.8, 0.7, 1.2)], "outside": [Vector3(5.5, 3.2, 9.5), Vector3(0, 1.8, -0.8)], "side": [Vector3(-6.5, 4.0, 5.0), Vector3(0, 2.0, -0.8)]}
	for name in shots:
		camera.global_position = house.to_global(shots[name][0])
		camera.look_at(house.to_global(shots[name][1]))
		for frame in range(3): await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("home_%s.png" % name))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: home preview")
	quit()
