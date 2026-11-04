extends SceneTree

# Screenshots of every lobby menu in the bazaar look: the lobby, Settings, Co-op, the
# New Game difficulty choice and How to Play (temporary save; pictures in TEMP as
# menus_<name>.png). Run with a window:  Godot --path . --script res://tools/menus_preview.gd
func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("menus_%s.png" % name))
	print("SHOT ", name)

func _run() -> void:
	var dir := OS.get_environment("TEMP").path_join("menus_preview_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	var state = load("res://business_backend.gd").new()
	state.save_path = dir.path_join("save.json")
	assert(state.save_progress())
	var menu = load("res://main_menu.tscn").instantiate()
	menu.save_path = state.save_path
	menu.settings_path = dir.path_join("settings.cfg")
	root.add_child(menu)
	root.size = Vector2i(1152, 648)
	for frame in range(6): await process_frame
	menu._layout()
	await _shot("lobby")
	menu._open_settings()
	await _shot("settings")
	menu.settings_menu.close_menu()
	menu._open_coop()
	await _shot("coop")
	menu.coop_menu.close_menu()
	menu._request_new()
	await _shot("new_game")
	menu._cancel_new()
	menu.how_to_play.open()
	await _shot("how_to_play")
	menu.how_to_play.close()
	root.size = Vector2i(640, 480)
	for frame in range(4): await process_frame
	menu._layout()
	await _shot("lobby_small")
	# The loading screen over the same picture (never launches: the call does nothing).
	root.size = Vector2i(1152, 648)
	var loading = load("res://loading_screen.gd").new()
	root.add_child(loading)
	loading.begin(func(): return OK, "New shop  |  Slot 2  |  Day 1  |  " + String.chr(8377) + "20,000  |  Aasaan", "")
	for frame in range(20): await process_frame
	await _shot("loading")
	print("PASS: menus preview")
	quit()
