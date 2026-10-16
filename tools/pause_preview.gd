extends SceneTree

# Screenshots of the in-game pause menu and its settings window (temporary save).
func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("%s.png" % name))

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("pause_preview_%d.json" % Time.get_ticks_usec())
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
	var pause = current_scene.get_node("Ui/PauseMenu")
	pause.open_menu()
	for frame in range(4): await process_frame
	await _shot("pause_menu")
	pause._settings()
	for frame in range(4): await process_frame
	await _shot("pause_settings")
	get_root().get_tree().paused = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: pause preview")
	quit()
