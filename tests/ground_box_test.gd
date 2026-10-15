extends SceneTree

const Backend = preload("res://business_backend.gd")

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = code
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("ground_box_%d.json" % Time.get_ticks_usec())
	var state = Backend.new()
	state.load_progress(path)
	assert(state.order_stock("soap", 2) and state.receive_delivery() and state.pick_up_box())
	assert(state.shelve_one(2) and state.carried_stock == 9)
	var before: Dictionary = state.snapshot()
	assert(not state.put_down_box(Vector3(NAN, 0, 0)) and state.snapshot() == before)
	state.save_path = path.path_join("missing/save.json")
	assert(not state.put_down_box(Vector3(-24, 0.42, 3)) and state.snapshot() == before)
	state.save_path = path
	assert(state.put_down_box(Vector3(-24, 0.42, 3)))
	assert(state.carried_stock == 0 and state.boxed_stock == 10 and state.supply_box_count() == 2)
	assert(state.logistics.ground_boxes[0].amount == 9 and state._is_valid_snapshot(state.snapshot()))
	var loaded = Backend.new()
	loaded.load_progress(path)
	assert(loaded.snapshot() == state.snapshot())
	for corruption in ["position", "amount", "duplicate"]:
		var bad: Dictionary = state.snapshot()
		if corruption == "position": bad.logistics.ground_boxes[0].position[0] = NAN
		elif corruption == "amount": bad.logistics.ground_boxes[0].amount = 11
		else: bad.logistics.ground_boxes.append(bad.logistics.ground_boxes[0].duplicate(true))
		assert(not state._is_valid_snapshot(bad))
	before = state.snapshot()
	state.save_path = path.path_join("missing/save.json")
	assert(not state.pick_up_ground_box(0) and state.snapshot() == before)
	state.save_path = path
	assert(state.pick_up_ground_box(0) and state.carried_stock == 9 and state.logistics.ground_boxes.is_empty())
	assert(not state.pick_up_ground_box(0) and not state.pick_up_ground_box(-1))
	assert(state._is_valid_snapshot(state.snapshot()))
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	await physics_frame
	await physics_frame
	root.size = Vector2i(1152, 648)
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Customer").set_physics_process(false)
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(-24, 0.1, 4)
	player.rotation = Vector3.ZERO
	var ops = current_scene.get_node("ShopOperations")
	var business = current_scene.get_node("Shop/ShopArea").business
	var ui = current_scene.get_node("Ui")
	assert(ui.controls_panel.has_node("KeyQ"))
	ui.shop_menu.show()
	before = business.snapshot()
	_key(KEY_Q)
	assert(business.snapshot() == before)
	ui.shop._on_close_button_pressed()
	player.global_position = Vector3(-5.3, 0.1, 1.5)
	player.rotation.y = PI / 2
	assert(ops.release_held_item() and business.snapshot() == before)
	assert(ui.feedback_label.text.contains("blocked"))
	player.global_position = Vector3(-24, 0.1, 4)
	player.rotation = Vector3.ZERO
	_key(KEY_Q, true)
	assert(business.snapshot() == before)
	_key(KEY_Q)
	assert(business.carried_stock == 0 and business.logistics.ground_boxes.size() == 1)
	assert(ops.ground_boxes[0].visible and not ops.carried_box.visible)
	assert(ops.ground_boxes[0].get_node("BoxLabel").text.contains("9"))
	await physics_frame
	player.camera.global_position = Vector3(-24, 1.5, 4)
	player.camera.look_at(ops.ground_boxes[0].global_position)
	assert(ops.ground_box_target() == 0)
	_key(KEY_E)
	assert(business.carried_stock == 9 and business.logistics.ground_boxes.is_empty())
	assert(not ops.ground_boxes[0].visible and ops.carried_box.visible)
	assert(ops.ground_boxes[0].get_node("GroundBody").collision_layer == 0)
	_key(KEY_Q)
	assert(business.carried_stock == 0)
	assert(business._is_valid_snapshot(business.snapshot()))
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.current = true
		camera.global_position = Vector3(-22, 2, 5)
		camera.look_at(ops.ground_boxes[0].global_position)
		current_scene.get_node("Landscape").set_camera(camera)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("ground_box_preview.png"))
	print("PASS: Q frees hands, E recovers partial box, saved positions, queue/stock conservation, invalid data, rollback, menu/echo guards and ground collision lifecycle")
	quit()
