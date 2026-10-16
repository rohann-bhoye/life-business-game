extends SceneTree

# Renders a 256x256 transparent thumbnail of every catalog product (the same
# models used on the shelves) into assets/ui/products/<id>.png for the PC store.
# Run graphically: Godot --path . --script res://tools/product_thumbnails.gd
const Catalog := preload("res://product_catalog.gd")
const Bounds := preload("res://product_assets.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("thumbs_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("Shop/ShopArea").business.save_path = ""
	var ops = current_scene.get_node("ShopOperations")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var studio := Node3D.new()
	viewport.add_child(studio)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	studio.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 35, 0)
	key.light_energy = 1.1
	studio.add_child(key)
	var camera := Camera3D.new()
	camera.fov = 30
	studio.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/products"))
	for id in Catalog.IDS:
		var holder := Node3D.new()
		studio.add_child(holder)
		var item: Node3D = ops.make_product(holder, "Thumb", Vector3.ZERO, id)
		item.rotation.y = -PI / 2 + 0.45
		var box: AABB = Bounds._bounds(item, Transform3D.IDENTITY)
		var center := box.get_center()
		var radius := box.size.length() * 0.5
		var distance := radius / tan(deg_to_rad(camera.fov * 0.5)) * 1.12
		camera.position = center + Vector3(0, radius * 0.35, distance)
		camera.look_at(center, Vector3.UP)
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("res://assets/ui/products/%s.png" % id))
		print("THUMB ", id, " ", box.size)
		holder.free()
	print("PASS: product thumbnails")
	quit()
