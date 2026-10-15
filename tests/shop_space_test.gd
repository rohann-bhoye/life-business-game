extends SceneTree

var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fixture() -> PackedScene:
	var scene = load("res://main.tscn.tscn").instantiate()
	var path := OS.get_environment("TEMP").path_join("life_business_space_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	scene.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	return packed

func _stop() -> void:
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("Player").set_physics_process(false)
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("ShopOperations").set_process(false)
	current_scene.get_node("StockWorker").set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	assert(not img.is_empty())
	assert(img.save_png(OS.get_environment("TEMP").path_join("shop_space_%s.png" % label)) == OK)

func _check_room(level: int) -> void:
	var building = current_scene.get_node("Shop")
	var depth := 10.0
	var back_z := 2.5 - depth
	assert(building.get_node("BackWall").position.z == back_z)
	assert(building.get_node("BackWallBody").position.z == back_z)
	assert(is_equal_approx(building.get_node("BackWall").mesh.size.y, 3.8))
	assert(is_equal_approx(building.get_node("RoofTrim").global_position.y, 4.0))
	assert(building.get_node("RoofTrimBody/CollisionShape3D").shape.size == building.get_node("RoofTrim").mesh.size)
	for x in [-3.0, 3.0]:
		var name := ("SideWall%s" % x).validate_node_name()
		assert(building.get_node(name).mesh.size.z == depth)
		assert(building.get_node(name + "Body/CollisionShape3D").shape.size.z == depth)
	assert(is_equal_approx(building.get_node("ShopInterior/CollisionShape3D").shape.size.z, depth - 0.2))
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(-3, 1, -1.8), Vector3(-3, 1, -9.5))
	query.exclude = [current_scene.get_node("Player").get_rid()]
	var hit: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty() and hit.collider.name == "BackWallBody")
	assert(absf(hit.position.z - (back_z + 0.06)) < 0.01)
	var side := PhysicsRayQueryParameters3D.create(Vector3(-3, 1, back_z + 0.8), Vector3(1, 1, back_z + 0.8))
	hit = current_scene.get_world_3d().direct_space_state.intersect_ray(side)
	assert(not hit.is_empty() and str(hit.collider.name).begins_with("SideWall"))

func _run() -> void:
	var packed := _fixture()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	_stop()
	var shop = current_scene.get_node("Shop/ShopArea")
	var ops = current_scene.get_node("ShopOperations")
	var player = current_scene.get_node("Player")
	assert(shop.business.hire_worker() and shop.business.hire_stock_worker())
	var worker = shop.worker
	assert(worker.get_node("EmployeeNameLabel").text.contains("Ramesh"))
	assert(current_scene.get_node("StockWorker/EmployeeNameLabel").text.contains("Sunil"))
	assert(worker.get_node("EmployeeNameLabel").billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	player.global_position = Vector3(-2.5, 1.1, -0.6)
	ops._process(1)
	assert(worker.visible and worker.position.distance_to(player.position - Vector3(0, 1, 0)) > 0.9)
	assert(worker.position.z < 0 and worker.position.x < -3.0)
	player.global_position = Vector3(-1, 1.1, 1.6)
	ops._process(2)
	assert(worker.visible and worker.position.is_equal_approx(ops.cashier_point))
	var visual = worker.get_node("CharacterVisual")
	visual.set_process(false)
	visual.previous_position = visual.global_position
	visual.walk_blend = 0
	visual.play_work_animation()
	visual._process(0.5)
	var hand: Node3D = visual.left_arm.get_node("Hand")
	var forward: Vector3 = -worker.global_basis.z
	assert((hand.global_position - visual.left_arm.global_position).dot(forward) > 0.4)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	camera.position = Vector3(-0.5, 2.2, 1.8)
	camera.look_at(Vector3(-2.5, 1.5, -0.6))
	await _capture("employees")
	for level in range(1, 4):
		if level > 1:
			player.global_position = Vector3(-3, 1.1, -3.3 if level == 2 else -6.0)
			var menu = current_scene.get_node("Ui").supplier_menu
			menu.open_menu()
			menu.tabs.current_tab = 2
			assert(menu.expansion_button.disabled)
			camera.position = Vector3(-1.1, 1.8, -0.7)
			camera.look_at(Vector3(-1.1, 1.35, -1.6))
			await _capture("purchase_%d" % level)
			assert(shop.business.upgrade_shop())
			assert(shop.business.shop_level == level)
			menu.close_menu()
			assert(player.shop_indoors)
		await _check_room(level)
		assert(shop.stock == 10 and ops.rack.global_position == Vector3(-5.6, 0.1, -0.5))
		camera.position = Vector3(7, 11, 11)
		camera.look_at(Vector3(-3, 1, -2))
		await _capture("level_%d" % level)
		assert(shop.business.save_progress())
		var before: Dictionary = shop.business.snapshot()
		change_scene_to_packed(packed)
		await scene_changed
		await process_frame
		_stop()
		shop = current_scene.get_node("Shop/ShopArea")
		ops = current_scene.get_node("ShopOperations")
		player = current_scene.get_node("Player")
		assert(shop.business.snapshot() == before)
		await _check_room(level)
		camera = Camera3D.new()
		current_scene.add_child(camera)
		camera.current = true
	assert(shop.money == 40500 and shop.business.upgrade_expenses == 7500)
	assert(not shop.business.upgrade_shop())
	player.global_position = Vector3(-3, 1.1, -6.0)
	for frame in range(5):
		await physics_frame
		await process_frame
	assert(player.shop_indoors)
	camera.position = Vector3(-2.6, 2.2, 1.6)
	camera.look_at(Vector3(-3, 1.8, -6))
	await _capture("interior")
	var ui = current_scene.get_node("Ui")
	assert(ui.shop_level_label.text.contains("60 m2") and ui.upgrade_button.disabled)
	ui.supplier_menu.open_menu()
	ui.supplier_menu.tabs.current_tab = 2
	assert(ui.supplier_menu.expansion_button.disabled)
	var before: Dictionary = shop.business.snapshot()
	ui.supplier_menu.expansion_button.pressed.emit()
	assert(shop.business.snapshot() == before)
	ui.supplier_menu.close_menu()
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	shop.business.save_path = ""
	print("PASS: forward hand gesture, cashier sidestep, employee tags, full room at every business level, solid walls, interior camera area, unchanged stock/routes, save/reload")
	quit()
