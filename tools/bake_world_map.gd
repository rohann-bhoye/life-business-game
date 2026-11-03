extends SceneTree

# Bakes the picture behind the world map (world_map.gd): the whole land seen straight down
# by an orthographic camera at noon, with draw distances, fog and 3D labels off, saved to
# assets/ui/world_map.png. The game only shows this picture, so opening the map costs no
# 3D rendering. Run again whenever the world changes, then import:
#   Godot --path . --script res://tools/bake_world_map.gd
#   Godot --headless --path . --import
const WorldMap := preload("res://world_map.gd")
const WIDTH := 744
const HEIGHT := 1024

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("map_bake_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	packed.pack(scene)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(WIDTH, HEIGHT)
	for frame in 30: await process_frame
	for node in current_scene.find_children("*", "GeometryInstance3D", true, false):
		var item := node as GeometryInstance3D
		item.visibility_range_begin = 0.0
		item.visibility_range_end = 0.0
		if item is Label3D: item.visible = false
	current_scene.get_node("Player").visible = false
	for node in current_scene.find_children("*", "Node3D", true, false):
		if str(node.name).to_lower().contains("cloud"): node.visible = false
	var bounds: Rect2 = WorldMap.BOUNDS
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = bounds.size.y
	camera.near = 1.0
	camera.far = 1200.0
	camera.position = Vector3(bounds.get_center().x, 500.0, bounds.get_center().y)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	var world_env := current_scene.find_children("*", "WorldEnvironment", true, false)
	if not world_env.is_empty():
		var look: Environment = (world_env[0] as WorldEnvironment).environment.duplicate()
		look.fog_enabled = false
		look.volumetric_fog_enabled = false
		look.background_mode = Environment.BG_COLOR
		look.background_color = Color(0.2, 0.33, 0.38)
		camera.environment = look
	# Its own viewport onto the same world, so no UI is drawn into the picture.
	var shot := SubViewport.new()
	shot.size = Vector2i(WIDTH, HEIGHT)
	shot.world_3d = root.find_world_3d()
	shot.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(shot)
	shot.add_child(camera)
	camera.make_current()
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	var image := shot.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	var path := ProjectSettings.globalize_path("res://assets/ui/world_map.png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	print("saved " if image.save_png(path) == OK else "FAILED ", path)
	quit()
