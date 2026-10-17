extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("street_assets_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	for name in ["Player", "Customer", "StockWorker"]: current_scene.get_node(name).set_physics_process(false)
	var ops = current_scene.get_node("ShopOperations")
	ops.set_process(false)
	var business = current_scene.get_node("Shop/ShopArea").business
	var before: Dictionary = business.snapshot()
	var street = current_scene.get_node("Neighbourhood/StreetLife")
	street.set_physics_process(false)
	assert(street.walkers.size() == 12)
	var start: Vector3 = street.walkers[0].position
	street._physics_process(1)
	assert(is_equal_approx(street.walkers[0].position.x - start.x, street.WALK_SPEED))
	assert(street.walkers[0].position.z == start.z)
	street.walkers[0].position.x = 28.9
	street.directions[0] = 1
	street._physics_process(1)
	assert(street.walkers[0].position.x == 29 and street.directions[0] == -1)
	for frame in range(100): street._physics_process(1)
	for person in street.walkers:
		assert(absf(person.position.x) <= 29)
		assert(is_equal_approx(person.position.z, 3.9) or is_equal_approx(person.position.z, 10.9))
		assert(person.get_node("CharacterVisual").body.mesh != null)
	assert(business.snapshot() == before, "Ambient pedestrians must not change the shop economy")
	for index in range(6):
		assert(current_scene.has_node("Neighbourhood/SouthBuilding%d" % index))
		assert(current_scene.has_node("Neighbourhood/SouthBuilding%dBody" % index))
	var assets = load("res://product_assets.gd")
	for id in ["bottle", "snack"]:
		var item = ops.make_product(current_scene, "AssetTest" + id, Vector3(2, 1, 0), id)
		assert(item.has_node("ProductAsset") and item.has_node("Cap"))
		var meshes = item.get_node("ProductAsset").find_children("*", "MeshInstance3D", true, false)
		assert(not meshes.is_empty())
		for mesh in meshes:
			var material = mesh.mesh.surface_get_material(0)
			assert(material is StandardMaterial3D and material.albedo_texture != null, "Imported product is missing its colour texture")
		var bounds: AABB = assets._bounds(item.get_node("ProductAsset"), Transform3D.IDENTITY)
		var limit := Vector3(0.18, 0.4, 0.18) if id == "bottle" else Vector3(0.16, 0.26, 0.11)
		assert(bounds.has_volume())
		assert(bounds.size.x <= limit.x + 0.001 and bounds.size.y <= limit.y + 0.001 and bounds.size.z <= limit.z + 0.001)
		assert(absf(bounds.position.y) < 0.001, "Product must rest on the shelf")
		item.queue_free()
	if DisplayServer.get_name() != "headless":
		assert(business.order_stock("snack") and business.receive_delivery() and business.pick_up_box() and business.shelve_box())
		root.size = Vector2i(1152, 648)
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.current = true
		camera.position = Vector3(-14, 9, -1)
		camera.look_at(Vector3(0, 1, 9))
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("street_assets_neighbourhood.png")) == OK)
		camera.position = Vector3(-2, 1.8, -1)
		camera.look_at(Vector3(-4.5, 1.2, -2))
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("street_assets_products.png")) == OK)
	print("PASS: licensed fitted product models, preserved scan caps, twelve walking/reversing passers-by, six solid buildings and no ambient economy changes")
	quit()
