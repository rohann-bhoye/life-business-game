extends SceneTree

# A tour of screenshots from many angles: the home (front, sides, back, top, inside), the
# warehouse and the shop. Run with a window:  Godot --path . --script res://tools/city_views.gd
# Pictures go to CITY_VIEWS_OUT (a folder) or user://city_views.
const SHOTS := {
	"h1_front": [Vector3(-47.0, 2.4, -6.0), Vector3(-61.0, 1.6, -6.0)],
	"h2_front_left": [Vector3(-50.5, 3.0, -14.0), Vector3(-60.0, 1.5, -7.0)],
	"h3_front_right": [Vector3(-50.5, 3.0, 2.5), Vector3(-60.0, 1.5, -5.0)],
	"h4_back": [Vector3(-74.0, 4.0, -6.0), Vector3(-62.0, 1.5, -6.0)],
	"h5_top": [Vector3(-62.0, 22.0, -2.0), Vector3(-60.0, 0.0, -6.0)],
	"h6_inside": [Vector3(-63.4, 1.9, -6.0), Vector3(-60.0, 1.0, -6.0)],
	"h7_bays": [Vector3(-49.0, 2.4, 3.5), Vector3(-58.0, 0.8, 0.4)],
	"w1_front": [Vector3(-4.0, 3.0, 8.6), Vector3(-4.0, 1.6, 15.0)],
	"w2_side": [Vector3(-17.0, 3.2, 19.0), Vector3(-4.0, 1.5, 22.0)],
	"w3_inside": [Vector3(-4.0, 1.8, 16.4), Vector3(-4.0, 1.2, 28.0)],
	"w4_back": [Vector3(-4.0, 4.0, 37.0), Vector3(-4.0, 1.5, 29.0)],
	"s1_front": [Vector3(-8.6, 2.3, 8.2), Vector3(-3.2, 1.7, 1.0)],
	"s2_street": [Vector3(6.0, 2.4, 9.0), Vector3(-3.0, 1.8, 2.0)],
}

func _initialize() -> void:
	call_deferred("_run")

func _save(folder: String, name: String) -> void:
	for frame in range(14): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	image.save_jpg(folder.path_join(name + ".jpg"), 0.86)
	print("VIEW ", name)

func _run() -> void:
	var folder := OS.get_environment("CITY_VIEWS_OUT")
	if folder == "": folder = ProjectSettings.globalize_path("user://city_views")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("city_views_%d.json" % Time.get_ticks_usec())
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
	var only := OS.get_environment("CITY_VIEWS_ONLY")
	for name in SHOTS:
		if only != "" and not name.begins_with(only): continue
		camera.global_position = SHOTS[name][0]
		camera.look_at(SHOTS[name][1])
		await _save(folder, name)
	quit()
