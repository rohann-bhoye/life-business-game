extends SceneTree

# Screenshots of the PC wholesale store page and the operations window (temporary save).
func _initialize() -> void:
	call_deferred("_run")

func _shot(terminal, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	terminal.screen_viewport.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("pcmgr_%s.png" % name))

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("store_preview_%d.json" % Time.get_ticks_usec())
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
	var terminal = current_scene.get_node("ShopOperations").pc.get_node("ComputerTerminal")
	terminal.open(true)
	for frame in range(40): await process_frame
	await _shot(terminal, "operations")
	terminal.screen_menu.get_node("ManagementTabs").current_tab = 3
	
	
	for frame in range(6): await process_frame
	await _shot(terminal, "marketing")
	
	for frame in range(4): await process_frame
	await _shot(terminal, "marketing2")
	
	for frame in range(6): await process_frame
	
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: bank preview")
	quit()
