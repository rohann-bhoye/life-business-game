extends SceneTree

# Screenshots of a road end in tester mode (smoke) - run with --tester to see the smoke.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("smoke_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	for index in range(8): await process_frame
	var player = current_scene.get_node("Player")
	player.global_position = Vector3(58.0, 1.6, 7.0)
	player.rotation.y = -PI / 2.0
	for index in range(50): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("smoke_%s.png" % ("tester" if "--tester" in OS.get_cmdline_args() + OS.get_cmdline_user_args() else "admin")))
	quit()
