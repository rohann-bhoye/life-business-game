extends SceneTree

# Screenshots of the online street props and the counter scale (tools/blender/street_props.py,
# assets/props/street/README.md): the shop front, a road bench, a planter, a street bin, the
# bus stop, a colony lane bench and the counter from both sides, on Low and High graphics.
# Pictures go to STREET_VIEWS_OUT or user://street_views. Run with a window:
#   Godot --path . --script res://tools/street_props_views.gd
const SHOTS := {
	"front": [Vector3(-2.0, 1.8, 7.0), Vector3(-2.6, 0.9, 2.6)],
	"bench": [Vector3(10.8, 1.5, 7.6), Vector3(13.0, 0.6, 11.0)],
	"planter": [Vector3(6.3, 1.5, 5.8), Vector3(8.5, 0.4, 3.1)],
	"bin": [Vector3(15.4, 1.4, 8.4), Vector3(17.0, 0.4, 10.75)],
	"busstop": [Vector3(-22.0, 1.7, 7.6), Vector3(-24.0, 0.7, 12.0)],
	"lane": [Vector3(-50.0, 1.6, 10.8), Vector3(-47.8, 0.5, 14.0)],
	"counter": [Vector3(-2.2, 1.5, 1.7), Vector3(-2.45, 0.85, 0.3)],
	"cashier": [Vector3(-2.3, 1.45, -0.8), Vector3(-2.45, 0.85, 0.4)],
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var folder := OS.get_environment("STREET_VIEWS_OUT")
	if folder == "": folder = ProjectSettings.globalize_path("user://street_views")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("street_views_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	world.get_node("Shop/ShopArea").business.save_path = ""
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player").hide()
	world.get_node("Ui").visible = false
	var bar = world.get_node_or_null("Ui/InventoryBar")
	if bar != null:
		bar.set_process(false)
		if bar.layer != null: bar.layer.visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 62
	var settings = preload("res://game_settings.gd").new()
	for quality in [0, 2]:
		settings.graphics = quality
		settings.apply_graphics(world)
		for frame in range(10): await process_frame
		for name in SHOTS:
			camera.global_position = SHOTS[name][0]
			camera.look_at(SHOTS[name][1])
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			image.save_jpg(folder.path_join("%s_%s.jpg" % [name, "low" if quality == 0 else "high"]), 0.86)
	print("STREET VIEWS saved to ", folder)
	quit()
