extends SceneTree

# Screenshots of the intro cinematic at a few moments (temp folder).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1152, 648)
	var cinematic = load("res://intro_cinematic.gd").new()
	root.add_child(cinematic)
	for moment in [5.0, 11.0, 18.0, 30.0, 36.0, 43.0, 47.0, 51.0, 53.5, 58.0]:
		cinematic.clock = moment
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("intro_%02d.png" % int(moment)))
	quit()
