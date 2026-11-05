extends SceneTree

# Screenshots of Gufa Darwaza Floor 2, Surya Nagri (dungeon_floor.gd, dungeon_layouts.gd
# FLOOR_2): frames of the first-visit fly-over, the player's view on landing and a few
# fixed views, on the graphics preset in SURYA_GRAPHICS (0 Low ... 3 Ultra, default 0),
# with the frame rate. Pictures go to SURYA_VIEWS_OUT or user://surya_views (temporary
# save, nothing kept). Run with a window:
#   Godot --path . --script res://tools/surya_views.gd
const VIEWS := {
	"plaza": [Vector3(52.0, 3.0, 50.0), Vector3(40.0, 5.0, 36.0)],
	"court": [Vector3(40.0, 2.2, 22.0), Vector3(44.0, 2.0, 8.0)],
	"garden": [Vector3(70.0, 2.0, 50.0), Vector3(80.0, 2.0, 24.0)],
	"high": [Vector3(88.0, 30.0, 70.0), Vector3(40.0, 0.0, 30.0)],
}

func _initialize() -> void:
	call_deferred("_run")

func _shot(folder: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("surya_%s.png" % name))
	print("SHOT ", name)

func _run() -> void:
	var folder := OS.get_environment("SURYA_VIEWS_OUT")
	if folder == "": folder = ProjectSettings.globalize_path("user://surya_views")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("surya_views_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = world.get_node("Shop/ShopArea").business
	business.save_path = ""
	var settings = preload("res://game_settings.gd").new()
	settings.graphics = int(OS.get_environment("SURYA_GRAPHICS")) if OS.get_environment("SURYA_GRAPHICS") != "" else 0
	settings.apply_graphics(world)
	for frame in range(30): await process_frame
	# The player applies the saved settings on its own; apply the chosen preset again after it.
	settings.apply_graphics(world)
	for frame in range(5): await process_frame
	var dungeon = world.find_child("DungeonWorld", true, false)
	assert(dungeon != null)
	business.treasure.deepest = 0
	dungeon._enter(1)
	# The fly-over: frames along the way, then the landing.
	var started := Time.get_ticks_msec()
	for at in [1.2, 3.5, 6.0, 8.5]:
		while (Time.get_ticks_msec() - started) / 1000.0 < at + 0.4: await process_frame
		await _shot(folder, "fly_%d" % int(at * 10))
	while dungeon.flying_over or dungeon.busy: await process_frame
	for frame in range(10): await process_frame
	await _shot(folder, "landing")
	# Frame rate from the entry stone, looking at the wheel.
	var frames := 0
	var clock := Time.get_ticks_msec()
	while Time.get_ticks_msec() - clock < 3000:
		await process_frame
		frames += 1
	print("FPS on preset %d: %.1f" % [settings.graphics, frames / 3.0])
	var camera := Camera3D.new()
	dungeon.floor_root.add_child(camera)
	camera.far = 150.0
	camera.fov = 70.0
	camera.make_current()
	world.get_node("Ui").visible = false
	for name in VIEWS:
		camera.position = VIEWS[name][0]
		camera.look_at(dungeon.floor_root.to_global(VIEWS[name][1]), Vector3.UP)
		for frame in range(8): await process_frame
		await _shot(folder, name)
	print("PASS: surya views in ", folder)
	quit()
