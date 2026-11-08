extends SceneTree

# Screenshots of Sagar Point, the ghat road and the sea round the island. Run with a window:
#   Godot --path . --script res://tools/sagar_views.gd
# SAGAR_GRAPHICS picks the graphics level (default 0, Low, as on the owner's PC).
# Pictures go to SAGAR_VIEWS_OUT (a folder) or user://sagar_views. SAGAR_FPS=1 also prints
# the frame rate at each view (vsync off, 3 s); SAGAR_NO_OCEAN=1 hides the sea to compare.
const SHOTS := {
	"s1_top_sea": [Vector3(-6.0, 19.7, 107.5), Vector3(-6.0, 9.0, 190.0)],
	"s2_top_lighthouse": [Vector3(-8.0, 19.8, 101.0), Vector3(62.0, 6.0, 118.0)],
	"s3_top_town": [Vector3(-6.0, 19.8, 108.0), Vector3(-6.0, 2.0, 20.0)],
	"s4_ghat_road": [Vector3(-50.0, 2.2, 52.0), Vector3(-36.0, 5.0, 78.0)],
	"s5_aerial": [Vector3(60.0, 75.0, 20.0), Vector3(-6.0, 5.0, 115.0)],
	"s6_top_west": [Vector3(-12.0, 19.7, 104.0), Vector3(-110.0, 4.0, 140.0)],
	"s7_beach": [Vector3(-58.0, 1.9, 103.0), Vector3(-72.0, -1.5, 119.0)],
	"s8_beach_wide": [Vector3(-36.0, 9.0, 92.0), Vector3(-72.0, -2.0, 116.0)],
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
	var folder := OS.get_environment("SAGAR_VIEWS_OUT")
	if folder == "": folder = ProjectSettings.globalize_path("user://sagar_views")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("sagar_views_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	var settings = preload("res://game_settings.gd").new()
	settings.graphics = int(OS.get_environment("SAGAR_GRAPHICS")) if OS.get_environment("SAGAR_GRAPHICS") != "" else 0
	settings.apply_graphics(world)
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player").hide()
	world.get_node("Ui").visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 62
	if OS.get_environment("SAGAR_NO_OCEAN") == "1": world.find_child("Ocean", true, false).visible = false
	if OS.get_environment("SAGAR_FPS") == "1":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	for frame in range(20): await process_frame
	var only := OS.get_environment("SAGAR_VIEWS_ONLY")
	for name in SHOTS:
		if only != "" and not name.begins_with(only): continue
		camera.global_position = SHOTS[name][0]
		camera.look_at(SHOTS[name][1])
		await _save(folder, name)
		if OS.get_environment("SAGAR_FPS") == "1": await _fps(name)
	quit()

func _fps(name: String) -> void:
	for frame in range(30): await process_frame
	var start := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - start < 3000000:
		await process_frame
		frames += 1
	print("FPS %s %.1f" % [name, frames / ((Time.get_ticks_usec() - start) / 1000000.0)])
