extends SceneTree

# Drives a car, opens the pause menu and the map, saves screenshots (temp folder).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("menu_overlap_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	for index in range(10): await process_frame
	var cars = current_scene.get_node("CarWorld")
	cars.hud.visible = true
	cars.driving = current_scene.get_node("Player")
	var ui = current_scene.get_node("Ui")
	ui.get_node("PauseMenu").open_menu()
	for index in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("menu_overlap_pause.png"))
	quit()
