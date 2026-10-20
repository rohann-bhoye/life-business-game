extends SceneTree

# G moves the checkout counter and the PC desk: placement rules, saving, the queue,
# cashier and customer routes following the counter, and the move-mode buttons
# (mouse place/cancel, wheel rotate, Q packs a bought rack).

const Backend = preload("res://business_backend.gd")
const Store = preload("res://rack_store.gd")

func _initialize() -> void:
	call_deferred("_run")

func _send(event: InputEvent) -> void:
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var release: InputEvent = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	_send(event)

func _mouse(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	_send(event)

func _run() -> void:
	var state = Backend.new()
	var path := OS.get_environment("TEMP").path_join("fixtures_%d_%d.json" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	state.load_progress(path)
	assert(state.racks.fixtures == Store.FIXTURE_HOME)
	# The old fixed reservations are unchanged for a shop that never moved anything.
	assert(Store.fixture_body("counter", Store.FIXTURE_HOME.counter).is_equal_approx(Rect2(-3.95, -0.02, 2.9, 0.84)))
	assert(Store.fixture_rect(Store.FIXTURE_HOME.counter, Store.QUEUE_ZONE).is_equal_approx(Rect2(-4.95, 0.9, 4.4, 1.5)))
	for point in Store.service_points(state.racks.fixtures):
		assert(not state.racks.route(Store.ENTRY, point).is_empty())
	var before: Dictionary = state.snapshot()
	# Into a wall, onto the racks, over the door, facing the wall, onto the desk.
	for bad in [Vector3(-0.5, -3, 0), Vector3(-5.2, -3.3, 0), Vector3(-3, 2, 0), Vector3(-1.0, -4.5, 3), Vector3(-1.2, -1.6, 0)]:
		assert(not state.move_fixture("counter", Vector2(bad.x, bad.y), int(bad.z)), "counter allowed at %s" % bad)
		assert(state.snapshot() == before)
	assert(not state.move_fixture("shelf", Vector2(-2, -4.5), 0))
	assert(not state.move_fixture("counter", Vector2(NAN, -4.5), 0))
	assert(state.move_fixture("counter", Vector2(-2.0, -4.5), 3))
	assert(state.racks.fixtures.counter == {"x": -2.0, "z": -4.5, "turn": 3})
	assert(state._is_valid_snapshot(state.snapshot()))
	# Racks now keep clear of the moved queue and cashier space, and the old front is free.
	assert(not state.racks.placement_error({"id": 3, "product": "bottle", "x": -3.25, "z": -4.5, "turn": 0, "amount": 0}).is_empty())
	assert(state.place_rack("bottle", Vector2(-2.5, 0.75), 1))
	for point in Store.service_points(state.racks.fixtures):
		assert(not state.racks.route(Store.ENTRY, point).is_empty())
	assert(state.move_fixture("desk", Vector2(-3.0, -6.75), 0) == false)
	assert(state.move_fixture("desk", Vector2(-1.1, -0.75), 2))
	assert(state.save_progress())
	var loaded = Backend.new()
	loaded.load_progress(path)
	assert(loaded.racks.fixtures == state.racks.fixtures)
	assert(loaded.snapshot() == state.snapshot())
	var invalid: Dictionary = state.snapshot()
	invalid.shop_fixtures.counter.turn = 5
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid.shop_fixtures.desk.x = NAN
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid.shop_fixtures.erase("desk")
	assert(not state._is_valid_snapshot(invalid))
	# A saved rack inside the moved counter's queue is refused.
	invalid = state.snapshot()
	invalid.rack_layout[3].x = -3.25
	invalid.rack_layout[3].z = -4.5
	invalid.rack_layout[3].turn = 0
	assert(not state._is_valid_snapshot(invalid))
	var legacy: Dictionary = Backend.new().snapshot()
	legacy.erase("shop_fixtures")
	assert(state._is_valid_snapshot(legacy))
	var failed = Backend.new()
	failed.save_path = path.path_join("missing.json")
	before = failed.snapshot()
	assert(not failed.move_fixture("counter", Vector2(-2.0, -4.5), 3))
	assert(failed.snapshot() == before)

	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("fixtures_world_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	world.get_node("Customer").set_physics_process(false)
	var player = world.get_node("Player")
	player.set_physics_process(false)
	var furnishing = world.get_node("RackFurnishing")
	var ops = world.get_node("ShopOperations")
	var business = world.get_node("Shop/ShopArea").business
	var bar = world.get_node("Ui/MoveModeBar")
	assert(not bar.visible)
	# The crosshair picks what G moves.
	player.shop_indoors = true
	player.global_position = Vector3(-2.5, 0.1, 2.0)
	for aim in [[Vector3(-2.5, 1.5, 2.0), Vector3(-2.5, 0.6, 0.4), "counter"], [Vector3(-0.6, 1.6, 0.5), Vector3(-1.1, 0.8, -1.6), "desk"], [Vector3(-4.0, 1.5, 1.8), Vector3(-5.6, 1.0, -0.5), 0]]:
		player.camera.global_position = aim[0]
		player.camera.look_at(aim[1])
		assert(typeof(furnishing.aimed_target()) == typeof(aim[2]) and furnishing.aimed_target() == aim[2], "aimed %s" % [furnishing.aimed_target()])
	player.camera.global_position = Vector3(-2.5, 1.5, 2.0)
	player.camera.look_at(Vector3(-2.5, 0.6, 0.4))
	_key(KEY_G)
	assert(furnishing.active and furnishing.fixture == "counter")
	await process_frame
	assert(bar.visible and bar.title.text == "MOVE CHECKOUT COUNTER")
	_mouse(MOUSE_BUTTON_RIGHT)
	assert(not furnishing.active and furnishing.fixture == "")
	_key(KEY_G)
	assert(furnishing.active)
	_key(KEY_G)
	assert(not furnishing.active)
	# Customers in the queue keep the counter where it is.
	var shopper := Node3D.new()
	ops.queue.append(shopper)
	assert(not furnishing.begin_fixture("counter"))
	ops.queue.clear()
	shopper.free()
	# Move the counter to the back, turned to face the room.
	assert(furnishing.begin_fixture("counter"))
	_mouse(MOUSE_BUTTON_WHEEL_UP)
	assert(furnishing.turn == 1)
	_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	assert(furnishing.turn == 3)
	furnishing._fixture_candidate(Vector3(-1.0, 0.1, -4.5))
	assert(not furnishing.last_error.is_empty())
	_mouse(MOUSE_BUTTON_LEFT)
	assert(furnishing.active and business.racks.fixtures.counter == Store.FIXTURE_HOME.counter)
	furnishing._fixture_candidate(Vector3(-2.0, 0.1, -4.5))
	assert(furnishing.last_error.is_empty(), furnishing.last_error)
	_mouse(MOUSE_BUTTON_LEFT)
	assert(not furnishing.active)
	assert(business.racks.fixtures.counter == {"x": -2.0, "z": -4.5, "turn": 3})
	assert(ops.counter.global_position.is_equal_approx(Vector3(-2.0, 0.3, -4.5)))
	assert(ops.get_node("CheckoutCounterBody").global_position.is_equal_approx(Vector3(-2.0, 0.3, -4.5)))
	assert(ops.cashier_point.is_equal_approx(Vector3(-1.0, 0.1, -4.5)))
	assert(world.get_node("CustomerPurchasePoint").global_position.is_equal_approx(Vector3(-2.8, 0.1, -4.5)))
	assert(ops.queue_position(null).is_equal_approx(Vector3(-2.8, 0.1, -4.5)))
	assert(not business.racks.route(Store.ENTRY, ops.queue_entry()).is_empty())
	var exit_route: Array[Vector3] = ops.customer_exit_route()
	assert(exit_route.size() > 3 and exit_route[-1].is_equal_approx(world.get_node("CustomerExitPoint").global_position))
	player.global_position = Vector3(-1.0, 0.1, -4.5)
	assert(ops.player_at_counter())
	# The PC desk goes along the right wall, and its PC with it.
	var pc_before: Vector3 = ops.pc.global_position
	assert(furnishing.begin_fixture("desk"))
	furnishing._fixture_candidate(Vector3(-1.0, 0.1, 0.0))
	assert(furnishing.last_error.is_empty(), furnishing.last_error)
	_key(KEY_E)
	assert(business.racks.fixtures.desk == {"x": -1.0, "z": 0.0, "turn": 0})
	assert(ops.pc.global_position.is_equal_approx(pc_before + Vector3(0.1, 0, 1.57)))
	assert(ops.get_node("ManagementDeskAsset").global_position.is_equal_approx(Vector3(-1.0, 0.1, -0.03)))
	# Q in move mode packs an empty bought rack; starting racks and fixtures stay.
	assert(business.order_racks("soap") and business.receive_rack_delivery())
	assert(business.place_rack("soap", Vector2(-3.25, -1.0), 0, -1, true))
	assert(business.racks.records.size() == 4)
	await process_frame
	assert(furnishing.begin_move(0))
	_key(KEY_Q)
	assert(furnishing.active and business.racks.records.size() == 4)
	_key(KEY_ESCAPE)
	assert(furnishing.begin_move(3))
	await process_frame
	assert(furnishing.can_pack())
	_key(KEY_Q)
	assert(not furnishing.active and business.racks.records.size() == 3 and "soap" in business.logistics.rack_delivered)
	print("PASS: G picks the aimed rack/counter/desk, move bar, mouse place/cancel/rotate, counter and desk rules and saves, moved queue/cashier/routes, Q packs a bought rack")
	quit()
