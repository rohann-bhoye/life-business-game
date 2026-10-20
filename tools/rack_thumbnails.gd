extends SceneTree

# Renders 256x256 transparent pictures of a full shelf rack and a produce table for
# the PC store's Furniture cards (pc_store.gd): assets/ui/products/rack_shelf.png and
# rack_produce.png. Run graphically, then import:
#   Godot --path . --script res://tools/rack_thumbnails.gd
#   Godot --headless --path . --import
const Bounds := preload("res://product_assets.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("rack_thumbs_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("Shop/ShopArea").business.save_path = ""
	var ops = current_scene.get_node("ShopOperations")
	var builder = current_scene.get_node("Neighbourhood")
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
	for entry in [["rack_shelf", "shelf"], ["rack_produce", "produce"], ["rack_fridge", "fridge"]]:
		var model: Dictionary
		match entry[1]:
			"shelf": model = ops.build_stock_rack(builder, "ThumbRack", "snack", Vector3.ZERO)
			"produce": model = ops.build_produce_table(builder, "ThumbTable", Vector3.ZERO)
			_: model = ops.build_fridge(builder, "ThumbFridge", Vector3.ZERO)
		var node: Node3D = model.node
		node.get_node("StockSign").hide()
		var holder := Node3D.new()
		studio.add_child(holder)
		node.reparent(holder, false)
		node.position = Vector3.ZERO
		node.rotation.y = 0.55
		var box: AABB = Bounds._bounds(node, Transform3D.IDENTITY)
		var center := box.get_center()
		var radius := box.size.length() * 0.5
		var distance := radius / tan(deg_to_rad(camera.fov * 0.5)) * 1.05
		camera.position = center + Vector3(distance, radius * 0.45, 0)
		camera.look_at(center, Vector3.UP)
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://assets/ui/products/%s.png" % entry[0]))
		print("THUMB ", entry[0], " ", box.size)
		holder.free()
	quit()
