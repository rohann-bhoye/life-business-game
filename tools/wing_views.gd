extends SceneTree

# Screenshots of the side wings (business_backend.gd shop_wing, shop_operations.gd
# _build_wing): the shop with both back expansions and no wing, the Side Wing and the
# Super Hall, from the street, at an angle and inside (temporary save). Pictures go to
# WING_VIEWS_OUT or user://wing_views; WING_PICTURES=1 also writes assets/ui/pc/wing_1.jpg and
# wing_2.jpg for the Builders site. Run with a window:
#   Godot --path . --script res://tools/wing_views.gd
const SHOTS := {
	"street": [Vector3(3.0, 2.4, 11.6), Vector3(2.0, 1.6, 0.0)],
	"angle": [Vector3(16.0, 7.0, 12.0), Vector3(1.0, 1.0, -4.0)],
	"inside": [Vector3(-5.0, 1.8, 1.5), Vector3(5.0, 1.2, -6.0)],
	"coolers": [Vector3(4.6, 1.9, 0.8), Vector3(5.0, 0.9, -10.0)],
	"trolleys": [Vector3(2.6, 1.8, -3.0), Vector3(1.8, 0.6, 2.0)],
	"top": [Vector3(2.0, 30.0, 8.0), Vector3(2.0, 0.0, -4.0)],
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var folder := OS.get_environment("WING_VIEWS_OUT")
	if folder == "": folder = ProjectSettings.globalize_path("user://wing_views")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("wing_views_%d.json" % Time.get_ticks_usec())
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
	settings.graphics = 2
	settings.apply_graphics(world)
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player").hide()
	world.get_node("Ui").visible = false
	# The hotbar has a layer of its own.
	var bar = world.get_node_or_null("Ui/InventoryBar")
	if bar != null:
		bar.set_process(false)
		if bar.layer != null: bar.layer.visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 62
	business.shop_expansion = 2
	business.racks.expansion = 2
	for wing in [0, 1, 2]:
		business.shop_wing = wing
		business.racks.wing = wing
		business.changed.emit()
		for frame in range(20): await process_frame
		for name in SHOTS:
			camera.global_position = SHOTS[name][0]
			camera.look_at(SHOTS[name][1])
			for frame in range(10): await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			image.save_jpg(folder.path_join("wing%d_%s.jpg" % [wing, name]), 0.86)
			# WING_PICTURES=1 also writes the Builders cards (builders_page.gd).
			if OS.get_environment("WING_PICTURES") == "1" and wing > 0 and name == "angle":
				image.save_jpg(ProjectSettings.globalize_path("res://assets/ui/pc/wing_%d.jpg" % wing), 0.86)
		print("WING %d floor %s racks %d" % [wing, str(business.racks.floor_rect(2, wing)), business.rack_limit()])
	quit()
