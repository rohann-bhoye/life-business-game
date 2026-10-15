extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("warehouse_polish_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	for name in ["Player", "Customer", "StockWorker", "Warehouse/WarehouseReceiver"]: current_scene.get_node(name).set_physics_process(false)
	var warehouse = current_scene.get_node("Warehouse")
	warehouse.set_process(false)
	var operations = current_scene.get_node("ShopOperations")
	operations.set_process(false)
	var business = current_scene.get_node("Shop/ShopArea").business
	var player = current_scene.get_node("Player")
	var door = warehouse.get_node("WarehouseDoor")
	door.set_process(false)
	player.global_position = Vector3(-3.5, 1.1, warehouse.FRONT - 5)
	door._process(2)
	assert(door.openness == 0)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(-3.5, 1.2, warehouse.FRONT - 1), Vector3(-3.5, 1.2, warehouse.FRONT + 1))
	query.exclude = [player.get_rid()]
	assert(not space.intersect_ray(query).is_empty(), "Closed warehouse door must be solid")
	player.global_position.z = warehouse.FRONT - 1.8
	door._process(0.5)
	assert(door.openness == 1)
	await physics_frame
	await physics_frame
	assert(space.intersect_ray(query).is_empty(), "Open warehouse entrance must be clear")
	player.global_position.z = warehouse.FRONT - 5
	door._process(2)
	assert(door.openness == 0)
	assert(business.hire_warehouse_worker())
	warehouse.receiver.global_position = Vector3(-3, 0.1, warehouse.FRONT + 1)
	door._process(0.5)
	assert(door.openness == 1, "Warehouse employee must trigger the door")
	var chair: Node3D = warehouse.get_node("OfficeDeskSetup/OfficeChair")
	var chair_direction: Vector3 = warehouse.computer.global_position - chair.global_position
	chair_direction.y = 0
	assert(chair.global_basis.z.normalized().dot(chair_direction.normalized()) > 0.99)
	var office_door = warehouse.get_node("StorageBuilding/OfficeDoor")
	office_door.set_process(false)
	player.global_position = Vector3(-14.2, 1.1, warehouse.FRONT + 0.6)
	office_door.toggle()
	office_door._process(0.5)
	assert(office_door.openness > 0.99, "Office door must open for the player")
	office_door.toggle()
	office_door._process(2.0)
	assert(is_zero_approx(office_door.openness), "Office door must close only when toggled")
	var monitor: Node3D = warehouse.get_node("OfficeDeskSetup/WarehousePC")
	var chair_to_monitor: Vector3 = monitor.global_position - chair.global_position
	chair_to_monitor.y = 0
	chair_to_monitor = chair_to_monitor.normalized()
	assert(monitor.global_basis.z.normalized().dot(-chair_to_monitor) > 0.99, "PC screen must face the chair")
	assert(monitor.has_node("MonitorBack") and monitor.has_node("MonitorBase"))
	assert(warehouse.get_node("StorageBuilding/OfficeCeilingLight18/OfficeLight").light_energy > 1)
	assert(business.order_stock() and business.receive_delivery() and business.pick_up_box())
	var box = operations.carried_box
	var visual = player.player_mesh
	player.global_position = Vector3(0, 1.1, 10)
	player.indoors = false
	player.shop_indoors = false
	player.warehouse_indoors = false
	visual.show()
	visual.rotation.y = 1.1
	box._process(0.016)
	assert(is_zero_approx(visual.rotation.y))
	# Third person uses the animated Kenney model; its carry pose holds the box
	# at hand height in front of the body and the block grips are hidden.
	assert(visual.kenney.is_visible_in_tree())
	assert(not box.get_node("LeftGrip").visible and not box.get_node("RightGrip").visible)
	var box_offset: Vector3 = visual.global_basis.inverse() * (box.global_position - visual.kenney.global_position)
	assert(box_offset.z < -0.3 and box_offset.y > 0.5 and box_offset.y < 0.95, str(box_offset))
	visual._process(0.016)
	assert(is_equal_approx(visual.anim_tree.get("parameters/carry_blend/blend_amount"), 1.0))
	for arm in [visual.left_arm, visual.right_arm]:
		assert(arm.scale.is_equal_approx(Vector3.ONE), "Shoulder must not stretch")
	visual.previous_position = visual.global_position - Vector3(0.03, 0, 0)
	visual._process(0.03)
	assert(absf(visual.left_leg.rotation.x) > 0.001 and is_equal_approx(visual.left_leg.rotation.x, -visual.right_leg.rotation.x))
	assert(absf(visual.left_leg.get_node("Calf").rotation.x) + absf(visual.right_leg.get_node("Calf").rotation.x) > 0.01)
	player.warehouse_indoors = true
	box._process(0.016)
	assert(box.get_node("LeftCarryForearm").visible)
	assert(player.camera.to_local(box.global_position).distance_to(Vector3(0, -0.35, -1.15)) < 0.05)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30, 15)
	current_scene.get_node("Ui/SupplierMenu").open_menu()
	var yaw: float = player.rotation.y
	player._input(motion)
	assert(is_equal_approx(player.rotation.y, yaw), "Menus must lock look")
	current_scene.get_node("Ui/SupplierMenu").close_menu()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.velocity = Vector3(1, 0, 0)
		root.push_input(motion)
		await process_frame
		assert(not is_equal_approx(player.rotation.y, yaw), "Mouse look must work while moving")
		player.velocity = Vector3.ZERO
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.current = true
		current_scene.get_node("Landscape").set_camera(camera)
		player.hide()
		business.minutes_of_day = 1320
		business.clock_changed.emit()
		camera.global_position = Vector3(-14.2, 2, 21.1)
		camera.look_at(Vector3(-14.2, 1.2, 17.2))
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		assert(image.get_pixel(576, 324).get_luminance() > 0.05)
		assert(image.save_png(OS.get_environment("TEMP").path_join("warehouse_office_lit.png")) == OK)
		camera.global_position = Vector3(-14.2, 1.9, warehouse.FRONT - 3.5)
		camera.look_at(Vector3(-14.2, 1.3, warehouse.FRONT))
		office_door.toggle()
		office_door._process(0.5)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("warehouse_office_door.png")) == OK)
		door._process(2)
		camera.global_position = Vector3(-3, 2.5, 10)
		camera.look_at(Vector3(-3, 2, warehouse.FRONT))
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("warehouse_door_closed.png")) == OK)
		business.minutes_of_day = 720
		business.clock_changed.emit()
		player.show()
		player.warehouse_indoors = false
		player.global_position = Vector3(0, 1.1, 10)
		player.rotation = Vector3.ZERO
		visual.show()
		box._process(0.016)
		camera.global_position = Vector3(1.6, 1.9, 7.5)
		camera.look_at(player.global_position + Vector3(0, 0.15, -0.4))
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("third_person_carry_pose.png")) == OK)
		visual.set_process(false)
		for step in range(12):
			player.global_position.z -= 0.02
			visual._process(0.025)
			box._process(0.025)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("third_person_carry_walk.png")) == OK)
	box.hide()
	visual.reset_carry_pose()
	assert(visual.left_arm.get_node("Hand").visible and visual.left_arm.get_node("Forearm").scale.is_equal_approx(Vector3.ONE))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: warehouse and office doors, reinforced PC, receiver sensor, chair direction, lighting, mouse-look, articulated carrying and FPP hands")
	quit()
