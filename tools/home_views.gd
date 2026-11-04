extends SceneTree

# Screenshots of the home and its colony plot: lane view, inside the yard, parking bays
# and the old site. Run with a window:  Godot --path . --script res://tools/home_views.gd
# Pictures go to HOME_VIEWS_OUT (a folder) or user://home_views.

func _initialize() -> void:
	call_deferred("_run")

func _save(folder: String, name: String) -> void:
	for frame in range(14): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	image.save_jpg(folder.path_join(name + ".jpg"), 0.86)
	print("VIEW ", folder.path_join(name + ".jpg"))

func _look(camera: Camera3D, from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at)

func _run() -> void:
	var folder := OS.get_environment("HOME_VIEWS_OUT")
	if folder == "": folder = ProjectSettings.globalize_path("user://home_views")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("home_views_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	var settings = preload("res://game_settings.gd").new()
	settings.graphics = 2
	settings.apply_graphics(world)
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player").hide()
	world.get_node("Ui").visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 62
	for frame in range(20): await process_frame
	_look(camera, Vector3(-44.0, 3.0, -1.0), Vector3(-60.0, 1.2, -6.0))
	await _save(folder, "1_from_lane")
	_look(camera, Vector3(-53.0, 2.0, -10.5), Vector3(-62.0, 1.3, -5.0))
	await _save(folder, "2_gate")
	_look(camera, Vector3(-51.0, 3.0, 8.0), Vector3(-58.0, 0.6, 1.2))
	await _save(folder, "3_parking")
	_look(camera, Vector3(-40.0, 8.0, 14.0), Vector3(-60.0, 0.0, -2.0))
	await _save(folder, "4_overview")
	_look(camera, Vector3(10.0, 3.0, 8.0), Vector3(4.0, 1.0, -4.0))
	await _save(folder, "5_old_site")
	quit()
