extends SceneTree

# Renders the six shop reference views from the real game scene: front, interior,
# top (roof hidden), left side, back and a top-down floor plan. Run with a window:
#   Godot --path . --script res://tools/shop_views.gd
# Pictures go to SHOP_VIEWS_OUT (a folder) or user://shop_views; SHOP_VIEWS_GRAPHICS
# picks the graphics level (0 Low .. 2 High, default 2).

func _initialize() -> void:
	call_deferred("_run")

func _save(folder: String, name: String) -> void:
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	image.save_jpg(folder.path_join(name + ".jpg"), 0.86)
	print("VIEW ", folder.path_join(name + ".jpg"))

func _look(camera: Camera3D, from: Vector3, at: Vector3) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.global_position = from
	camera.look_at(at)

## Hides the roof slab, the pink roof edge, the ceiling beams, lights and fans, so
## the top views show the room (only for these pictures, nothing is deleted).
func _open_roof(world: Node) -> void:
	var shop: Node3D = world.get_node("Shop")
	for part in ["RoofTrim", "ParapetFront", "ParapetBack", "ParapetLeft", "ParapetRight", "CeilingBeams"]:
		if shop.has_node(part): shop.get_node(part).hide()
	for fixture in shop.find_children("CeilingFixture*", "", false, false): fixture.hide()
	var ops: Node = world.get_node("ShopOperations")
	for node in ops.find_children("CeilingFan*", "", true, false): node.hide()
	for node in ops.find_children("ExpansionLight*", "", false, false): node.hide()

## A full shop for the pictures (temporary save only): a produce stand and a milk
## fridge join the three racks, and every row is filled with its rack's product.
func _stock_shop(business) -> void:
	business.money = 50000
	print("produce stand placed: ", business.place_rack("tomato", Vector2(-3.4, -4.6), 0))
	print("milk fridge placed: ", business.place_rack("milk", Vector2(-0.45, -5.4), 2))
	for record in business.racks.records:
		for slot in record.slots:
			slot.product = record.product
			slot.count = 10
	business.changed.emit()

func _run() -> void:
	var folder := OS.get_environment("SHOP_VIEWS_OUT")
	if folder == "": folder = ProjectSettings.globalize_path("user://shop_views")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("shop_views_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	var settings = preload("res://game_settings.gd").new()
	var graphics := OS.get_environment("SHOP_VIEWS_GRAPHICS")
	settings.graphics = int(graphics) if graphics != "" else 2
	settings.apply_graphics(world)
	_stock_shop(world.get_node("Shop/ShopArea").business)
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player").hide()
	world.get_node("Ui").visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 62
	_look(camera, Vector3(-8.6, 2.3, 8.2), Vector3(-3.2, 1.7, 1.0))
	await _save(folder, "1_front")
	_look(camera, Vector3(-3.0, 1.75, 2.25), Vector3(-3.0, 1.55, -7.0))
	await _save(folder, "2_interior")
	_look(camera, Vector3(-10.2, 2.4, -0.4), Vector3(-6.0, 1.6, -2.6))
	await _save(folder, "4_left_side")
	_look(camera, Vector3(-7.4, 2.4, -14.8), Vector3(-3.0, 1.6, -7.5))
	await _save(folder, "5_back")
	_open_roof(world)
	_look(camera, Vector3(-9.6, 10.5, 6.8), Vector3(-3.0, 0.4, -2.6))
	await _save(folder, "3_top")
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.5
	camera.global_position = Vector3(-3.0, 20.0, -2.5)
	camera.rotation = Vector3(-PI / 2, 0, 0)
	await _save(folder, "6_floor_plan")
	quit()
