extends SceneTree

# Pictures for the Settings > Graphics cards (settings_menu.gd): the same view of the town
# on Low, Medium and High, saved small to assets/ui/settings/graphics_<level>.jpg (temporary
# save; nothing kept). Normal renderer only. Run with a window:
#   Godot --path . --script res://tools/graphics_thumbnails.gd
const LEVELS := ["low", "medium", "high"]
const EYE := Vector3(6.0, 3.3, 13.0)
const LOOK := Vector3(-9.5, 2.9, 3.1)
const SIZE := Vector2i(480, 270)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var folder := "res://assets/ui/settings"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("graphics_thumbs_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	packed.pack(fixture)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	var business = world.get_node("Shop/ShopArea").business
	business.save_path = ""
	# Late afternoon: long shadows show what each level adds.
	business.minutes_of_day = 990.0
	business.clock_changed.emit()
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player").hide()
	world.get_node("Ui").visible = false
	for layer in root.find_children("*", "CanvasLayer", true, false): layer.visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 52
	camera.position = EYE
	camera.look_at(LOOK, Vector3.UP)
	for frame in range(40): await process_frame
	for index in range(LEVELS.size()):
		var settings = preload("res://game_settings.gd").new()
		settings.graphics = index
		settings.apply_graphics(world)
		camera.make_current()
		for frame in range(30): await process_frame
		for layer in root.find_children("*", "CanvasLayer", true, false): layer.visible = false
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		# The hotbar is drawn along the bottom: keep the 16:9 part above it.
		image = image.get_region(Rect2i(image.get_width() * 6 / 100, 0, image.get_width() * 88 / 100, image.get_height() * 88 / 100))
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		var path := ProjectSettings.globalize_path(folder.path_join("graphics_%s.jpg" % LEVELS[index]))
		image.save_jpg(path, 0.88)
		print("SHOT ", path)
	quit()
