extends SceneTree

# Screenshots of every road junction (from above and at eye height) and the three road
# ends, to check pavements never cross a road mouth. Run with a window:
#   Godot --path . --script res://tools/junction_views.gd
# Pictures go to JUNCTION_VIEWS_OUT (a folder) or user://junction_views. TESTER=1 builds
# the tester version (no admin mode), as players see it.
const SHOTS := {
	"j1_west_lane_top": [Vector3(-52.0, 16.0, 13.0), Vector3(-52.0, 0.0, 6.0)],
	"j2_west_lane_eye": [Vector3(-46.0, 1.7, 9.0), Vector3(-53.0, 0.6, 0.0)],
	"j3_market_top": [Vector3(50.0, 16.0, 13.0), Vector3(50.0, 0.0, 6.0)],
	"j4_market_eye": [Vector3(56.0, 1.7, 9.0), Vector3(49.0, 0.6, 0.0)],
	"j5_east_lane_top": [Vector3(62.5, 16.0, 13.0), Vector3(62.5, 0.0, 6.0)],
	"j6_east_lane_eye": [Vector3(57.0, 1.7, 9.0), Vector3(63.0, 0.6, 0.0)],
	"j7_airport_top": [Vector3(47.0, 16.0, 52.0), Vector3(47.0, 0.0, 45.0)],
	"j8_airport_eye": [Vector3(41.0, 1.7, 47.0), Vector3(50.0, 0.6, 40.0)],
	"t1_turn_west_north": [Vector3(-52.0, 18.0, -28.0), Vector3(-52.0, 0.0, -40.0)],
	"t2_turn_east_south": [Vector3(62.5, 3.0, 38.0), Vector3(62.5, 0.5, 50.0)],
	"e1_gate_east": [Vector3(58.0, 2.0, 7.0), Vector3(75.0, 1.5, 7.0)],
	"e2_gate_west": [Vector3(-58.0, 2.0, 7.0), Vector3(-75.0, 1.5, 7.0)],
	"e3_north_end": [Vector3(50.0, 3.0, -228.0), Vector3(50.0, 1.5, -250.0)],
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
	var folder := OS.get_environment("JUNCTION_VIEWS_OUT")
	if folder == "": folder = ProjectSettings.globalize_path("user://junction_views")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("junction_views_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	var settings = preload("res://game_settings.gd").new()
	settings.graphics = int(OS.get_environment("JUNCTION_GRAPHICS")) if OS.get_environment("JUNCTION_GRAPHICS") != "" else 2
	settings.apply_graphics(world)
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player").hide()
	world.get_node("Ui").visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 62
	for frame in range(20): await process_frame
	var only := OS.get_environment("JUNCTION_VIEWS_ONLY")
	for name in SHOTS:
		if only != "" and not name.begins_with(only): continue
		camera.global_position = SHOTS[name][0]
		camera.look_at(SHOTS[name][1])
		await _save(folder, name)
	quit()
