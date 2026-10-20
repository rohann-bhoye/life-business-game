extends SceneTree

# Renders the pictures on the PC's APNA Builders site (builders_page.gd) from the
# game itself: the shop front at business levels 2 and 3, and the room after each
# expansion. Run with a window (not --headless), then import:
#   godot --path . --script res://tools/pc_builder_pictures.gd
#   godot --headless --path . --import
const OUT := "res://assets/ui/pc/"

func _initialize() -> void:
	call_deferred("_run")

## Only the shop: no customers, walkers, staff or traffic in the pictures.
func _hide_people() -> void:
	for node in current_scene.find_children("*", "", true, false):
		if str(node.name) in ["StreetLife", "Traffic"] and node is Node3D: node.hide()
	for visual in current_scene.find_children("CharacterVisual", "", true, false):
		if visual.get_parent() is Node3D: visual.get_parent().hide()

func _save(name: String) -> void:
	for frame in range(12):
		_hide_people()
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	image.save_jpg(ProjectSettings.globalize_path(OUT + name + ".jpg"), 0.86)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(960, 540)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("builder_pictures_%d.json" % Time.get_ticks_usec())
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
	world.get_node("Ui").visible = false
	var player = world.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(10, 1, 14)
	for node in world.find_children("*", "", true, false):
		if str(node.name) in ["StreetLife", "Traffic", "NightLife"]: node.process_mode = Node.PROCESS_MODE_DISABLED
	var business = world.get_node("Shop/ShopArea").business
	business.money = 100000
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	# The room after each expansion (basic look), from the door towards the back wall.
	camera.fov = 72
	for step in [1, 2]:
		business.expand_shop()
		camera.global_position = Vector3(-1.0, 2.4, 1.6)
		camera.look_at(Vector3(-3.4, 1.1, -9.5))
		await _save("expand_%d" % step)
	# Shop fronts after each makeover.
	camera.fov = 60
	for level in [2, 3]:
		business.upgrade_shop()
		camera.global_position = Vector3(-2.2, 2.0, 8.6)
		camera.look_at(Vector3(-3.0, 2.0, 2.5))
		await _save("look_%d" % level)
	print("Saved APNA Builders pictures to ", OUT)
	quit()
