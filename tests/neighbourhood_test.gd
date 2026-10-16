extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _walk_forward(seconds: float) -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	await create_timer(seconds).timeout
	var release := InputEventKey.new()
	release.keycode = KEY_W
	Input.parse_input_event(release)
	await physics_frame

func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(OS.get_environment("TEMP").path_join(file_name)) == OK)

func _run() -> void:
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("ShopOperations").enabled = false
	scene.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("life_business_neighbourhood_preview_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	var shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var customer = current_scene.get_node("Customer")
	customer.set_physics_process(false)
	var player = current_scene.get_node("Player")
	var shop_mesh: MeshInstance3D = current_scene.get_node("Shop")
	assert(shop_mesh.mesh.custom_aabb.size == Vector3.ZERO and shop_mesh.mesh.size == Vector3(4, 3, 4))
	assert(current_scene.get_node("Road").mesh.custom_aabb.size == Vector3.ZERO)
	var road = current_scene.get_node("Road")
	assert(road.position.y - road.mesh.size.y / 2 > 0.1)
	assert(current_scene.get_node("Shop/ShopSign").position.z > current_scene.get_node("Shop/SignBoard").position.z + 0.06)
	assert(current_scene.get_node("Ground/CollisionShape3D").shape.size == Vector3(150, 0.2, 120))
	assert(current_scene.get_node("Shop/ShopSign").rotation.is_zero_approx())
	assert(current_scene.get_node("DirectionalLight3D").shadow_enabled == (preload("res://game_settings.gd").new().detected_quality() > 0))
	assert(current_scene.get_node("WorldEnvironment").environment.sky != null)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(-3, 1.0, 3.5), Vector3(-3, 1.0, 0))
	var wall: Dictionary = space.intersect_ray(query)
	assert(not wall.is_empty() and wall["collider"] == current_scene.get_node("Shop/BuildingBody"))
	var route_shape := CapsuleShape3D.new()
	route_shape.radius = 0.3
	route_shape.height = 1.8
	for pair in [["CustomerSpawnPoint", "CustomerPurchasePoint"], ["CustomerPurchasePoint", "CustomerExitPoint"]]:
		var route := PhysicsShapeQueryParameters3D.new()
		route.shape = route_shape
		route.transform = Transform3D(Basis.IDENTITY, current_scene.get_node(pair[0]).global_position + Vector3(0, 0.95, 0))
		route.motion = current_scene.get_node(pair[1]).global_position - current_scene.get_node(pair[0]).global_position
		route.exclude = [player.get_rid()]
		assert(space.intersect_shape(route).is_empty())
		var clearance := space.cast_motion(route)
		assert(is_equal_approx(clearance[0], 1.0), "Blocked customer route: %s" % [pair])
	query = PhysicsRayQueryParameters3D.create(Vector3(15, 2, 7), Vector3(15, -1, 7))
	var ground: Dictionary = space.intersect_ray(query)
	assert(not ground.is_empty() and is_equal_approx(ground["position"].y, 0.1))
	query = PhysicsRayQueryParameters3D.create(Vector3(72, 1, 7), Vector3(76, 1, 7))
	assert(not space.intersect_ray(query).is_empty())
	player.global_position = Vector3(-3, 1.1, 3.6)
	player.rotation.y = 0
	player.velocity = Vector3.ZERO
	await _walk_forward(0.5)
	assert(player.global_position.z >= 2.49 and player.global_position.z < 3.0)
	assert(shop.player_inside)
	var interaction := InputEventKey.new()
	interaction.keycode = KEY_E
	interaction.pressed = true
	shop._unhandled_input(interaction)
	assert(shop.shop_menu.visible)
	shop.close_button.pressed.emit()
	assert(not shop.shop_menu.visible)
	assert(shop.business.hire_worker())
	current_scene.get_node("Worker/RestockTimer").stop()
	customer._physics_process(3.1)
	for frame in range(15):
		customer._physics_process(0.1)
	var overview := Camera3D.new()
	current_scene.add_child(overview)
	overview.position = Vector3(14, 12, 20)
	overview.look_at(Vector3(0, 0.8, -1))
	overview.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _capture("life_business_neighbourhood_overview.png")
	overview.position = Vector3(1.5, 4.5, 10)
	overview.look_at(Vector3(-3, 1.5, 0.5))
	await _capture("life_business_neighbourhood_shop.png")
	root.size = Vector2i(640, 480)
	await process_frame
	await _capture("life_business_neighbourhood_small.png")
	player.global_position = Vector3(0, 1.1, 0)
	player.velocity = Vector3.ZERO
	var before_sale: int = shop.money
	for frame in range(200):
		if customer.is_queued_for_deletion():
			break
		customer._physics_process(0.1)
	assert(customer.is_queued_for_deletion())
	assert(shop.money == before_sale + 100 and shop.stock == 9)
	print("PASS: visible shop/road, readable sign orientation, ground/boundary/shop collision, clear customer routes, E/Close interaction, one purchase/despawn")
	quit()
