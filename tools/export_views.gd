extends SceneTree

# Screenshots of the export (packing) room: street front, inside from the doorway,
# inside from the street door, and a top view. Run with a window:
#   Godot --path . --script res://tools/export_views.gd
# Pictures go to EXPORT_VIEWS_OUT (a folder) or user://export_views.

func _initialize() -> void:
	call_deferred("_run")

func _save(folder: String, name: String) -> void:
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	image.save_jpg(folder.path_join(name + ".jpg"), 0.86)
	print("VIEW ", folder.path_join(name + ".jpg"))

func _look(camera: Camera3D, from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at)

func _run() -> void:
	var folder := OS.get_environment("EXPORT_VIEWS_OUT")
	if folder == "": folder = ProjectSettings.globalize_path("user://export_views")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("export_views_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	var settings = preload("res://game_settings.gd").new()
	var graphics := OS.get_environment("EXPORT_VIEWS_GRAPHICS")
	settings.graphics = int(graphics) if graphics != "" else 2
	settings.apply_graphics(world)
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player").hide()
	world.get_node("Ui").visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 62
	_look(camera, Vector3(-10.5, 2.0, 7.5), Vector3(-8.0, 1.5, 2.6))
	await _save(folder, "1_street")
	_look(camera, Vector3(-6.6, 1.8, 1.4), Vector3(-9.0, 1.0, -2.6))
	await _save(folder, "2_in_from_shop")
	_look(camera, Vector3(-8.0, 1.8, 2.2), Vector3(-8.0, 0.9, -3.8))
	await _save(folder, "3_in_from_street")
	_look(camera, Vector3(-9.4, 2.2, -3.6), Vector3(-6.4, 0.8, 0.8))
	await _save(folder, "4_back_corner")
	quit()
