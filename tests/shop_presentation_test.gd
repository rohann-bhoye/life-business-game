extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _capture(camera: Camera3D, name: String, point: Vector3, target: Vector3) -> void:
	camera.position = point
	camera.look_at(target)
	current_scene.get_node("Landscape").set_camera(camera)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(OS.get_environment("TEMP").path_join("shop_polish_%s.png" % name)) == OK)
	var dark := 0
	var light := 0
	for y in range(0, image.get_height(), 12):
		for x in range(0, image.get_width(), 12):
			var luminance := image.get_pixel(x, y).get_luminance()
			if luminance < 0.2: dark += 1
			if luminance > 0.4: light += 1
	assert(dark > 30 and light > 30, "Shop image is blank, washed out or completely dark")

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("shop_polish_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	for name in ["Player", "Customer", "StockWorker"]: current_scene.get_node(name).set_physics_process(false)
	current_scene.get_node("ShopOperations").set_process(false)
	current_scene.get_node("Neighbourhood/StreetLife").set_physics_process(false)
	var presentation = current_scene.get_node("ShopPresentation")
	var business = current_scene.get_node("Shop/ShopArea").business
	var ops = current_scene.get_node("ShopOperations")
	var shop = current_scene.get_node("Shop")
	assert(shop.get_node("StoreName").text == "APNA MART")
	assert(current_scene.get_node("Road").material_override is ShaderMaterial)
	assert(current_scene.get_node("Road").mesh.custom_aabb == AABB())
	assert(shop.get_node("Floor").material_override != null)
	assert(shop.get_node("BackWall").material_override == preload("res://brick_works.gd").brick_material())
	assert(shop.get_node("RoofTrim").global_position.y == 4)
	assert(presentation.price_labels.size() == 3)
	assert(business.set_product_price("snack", 90))
	assert(presentation.price_labels.snack.text == String.chr(8377) + "90")
	assert(business.order_stock("snack") and business.receive_delivery() and business.pick_up_box() and business.shelve_box())
	assert(business.order_stock("soap") and business.receive_delivery() and business.pick_up_box() and business.shelve_box())
	for id in ["bottle", "snack", "soap"]:
		var sample = ops.make_product(current_scene, "PolishItem" + id, Vector3.ZERO, id)
		assert(sample.has_node("PackageLabel") and sample.has_node("PackageSleeve") and sample.has_node("Cap"))
		assert(sample.get_node("PackageLabel").text.length() > 0)
		sample.queue_free()
	var before: Dictionary = business.snapshot()
	presentation._refresh_prices()
	assert(business.snapshot() == before)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	var player = current_scene.get_node("Player")
	player.position = Vector3(4, 1.1, 6)
	ops.get_node("SlidingDoor").set_process(false)
	ops.get_node("SlidingDoor")._process(2)
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(15, 2, 7), Vector3(15, -1, 7)))
	assert(not hit.is_empty() and is_equal_approx(hit.position.y, 0.1))
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1600, 900)
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.current = true
		await _capture(camera, "front_day", Vector3(-9, 3.5, 9), Vector3(-3, 2, 0.5))
		await _capture(camera, "interior_day", Vector3(-0.5, 2, 1.6), Vector3(-4.5, 1.25, -3.0))
		await _capture(camera, "products", Vector3(-3.3, 1.0, -2.0), Vector3(-5.6, 0.7, -1.8))
		await _capture(camera, "road", Vector3(-3, 4, 10), Vector3(-3, 0, 6))
		var pixel := Vector2i(camera.unproject_position(Vector3(-4, 0.117, 6)))
		var road_image := root.get_texture().get_image()
		var asphalt := Color(0, 0, 0, 0)
		for y in range(-5, 6):
			for x in range(-5, 6): asphalt += road_image.get_pixelv(pixel + Vector2i(x, y)) / 121.0
		assert(absf(asphalt.r - asphalt.g) < 0.08 and asphalt.r < 0.6, "Road rendered green or failed to draw")
		business.advance_clock(780)
		await _capture(camera, "front_night", Vector3(-8, 2.8, 8), Vector3(-3, 1.8, 0))
	# Each upgrade gives the shop a new look (shop_style.gd); the floor rules stay.
	var style = current_scene.get_node("ShopPresentation/ShopStyle")
	var floor_before: Material = shop.get_node("Floor").material_override
	var paint: MeshInstance3D = current_scene.get_node("ShopOperations/ShopDecor/WallPaint")
	var layout: Array = business.racks.records.duplicate(true)
	assert(style.level == 1 and not style.extras.has_node("IceCreamFreezer"))
	assert(business.upgrade_shop())
	assert(style.level == 2 and shop.get_node("StoreName").text == "APNA SUPER MART")
	assert(style.extras.has_node("IceCreamFreezer") and style.extras.has_node("BladeSign") and not style.extras.has_node("OfferScreen"))
	assert(shop.get_node("Floor").material_override != floor_before and paint.material_override.albedo_color == style.PAINT[1])
	assert(business.upgrade_shop())
	await process_frame
	assert(style.level == 3 and shop.get_node("StoreName").text == "APNA MEGA MART")
	assert(style.extras.name == "Level3Look" and style.extras.has_node("OfferScreen") and style.extras.has_node("Bunting") and style.extras.has_node("IceCreamFreezer"))
	assert(style.get_children().size() == 1 and business.racks.records == layout)
	print("PASS: material atlas, readable storefront, live shelf prices, product labels, ceiling fixtures, unchanged ground/economy and desktop shop captures, per-level shop looks")
	quit()
