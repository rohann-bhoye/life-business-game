extends SceneTree

# Screenshots of the shop interior and warehouse (temporary save only).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("shop_int_%d.json" % Time.get_ticks_usec())
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
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	for frame in range(10): await process_frame
	var shop := Node3D.new()
	var shots := {"bench": [Vector3(-3.5, 1.6, 6.5), Vector3(-5.0, 0.4, 3.0)], "wh1": [Vector3(-6.0, 1.7, 24.5), Vector3(-6.0, 1.0, 14.0)], "wh2": [Vector3(-6.0, 1.7, 12.0), Vector3(-6.0, 1.0, 22.0)], "wh_out": [Vector3(-6.0, 2.5, 30.0), Vector3(-6.0, 1.5, 18.0)], "corner": [Vector3(-4.6, 1.5, -1.8), Vector3(-5.3, 0.4, 2.0)], "in_door": [Vector3(0, 0.5, 2.2), Vector3(0, -0.3, -1.5)], "in_left": [Vector3(2.6, 0.7, 2.0), Vector3(-2.0, -0.4, -1.0)], "in_right": [Vector3(-2.6, 0.7, 2.0), Vector3(2.0, -0.4, -1.0)], "out": [Vector3(3, 0.6, 9), Vector3(0, 0.2, 0)]}
	for name in shots:
		camera.global_position = shots[name][0]
		camera.look_at(shots[name][1])
		for frame in range(3): await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("shopint_%s.png" % name))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS")
	quit()
