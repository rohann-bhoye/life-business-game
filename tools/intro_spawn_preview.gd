extends SceneTree

# Screenshot of where the intro drops the player (airport, Airport Road). Temp save only.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("intro_spawn_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	for index in range(8): await process_frame
	var cinematic = load("res://intro_cinematic.gd").new()
	root.add_child(cinematic)
	cinematic._place_player()
	cinematic.queue_free()
	for index in range(40): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("intro_spawn.png"))
	quit()
