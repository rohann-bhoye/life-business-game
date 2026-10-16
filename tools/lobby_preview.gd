extends SceneTree

# Screenshots of the lobby (main menu) at desktop and small sizes, using a temporary save.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := OS.get_environment("TEMP").path_join("lobby_preview_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	var state = load("res://business_backend.gd").new()
	state.save_path = dir.path_join("save.json")
	assert(state.save_progress())
	var menu = load("res://main_menu.tscn").instantiate()
	menu.save_path = state.save_path
	menu.settings_path = dir.path_join("settings.cfg")
	root.add_child(menu)
	for size in [Vector2i(1152, 648), Vector2i(640, 480)]:
		root.size = size
		for frame in range(6): await process_frame
		menu._layout()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("lobby_%dx%d.png" % [size.x, size.y]))
	print("PASS: lobby preview")
	quit()
