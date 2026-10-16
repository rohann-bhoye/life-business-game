extends SceneTree

# Screenshot of the management PC product dropdown (temporary save).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("dropdown_preview_%d.json" % Time.get_ticks_usec())
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
	for frame in range(60): await process_frame
	var selector: OptionButton = terminal.screen_menu.get_node("ProductSelector")
	selector.show_popup()
	for frame in range(6): await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		terminal.screen_viewport.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("pc_dropdown.png"))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: dropdown preview")
	quit()
