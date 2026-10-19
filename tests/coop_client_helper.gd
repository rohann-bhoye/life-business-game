extends SceneTree

# Second player for coop_test.gd, run as its own Godot process:
#   Godot --headless --path . --script res://tests/coop_client_helper.gd -- <join code> [stay seconds]
# Joins with the host's join code as "Friend" (Aunty) and loads the town. Waits for
# the host's shop (the host set snacks to 180), sets the soap price to 190 (which
# must reach the host's shop), takes the second soap box from the bay while the host
# holds the first, puts it down and picks it up again, walks 4 m east along the
# home path, waits a moment (or <stay> seconds) and quits still carrying the box,
# which disconnects it.
const Coop := preload("res://coop.gd")
const Session := preload("res://game_session.gd")

func _initialize() -> void:
	call_deferred("_run")

func _wait_for(condition: Callable, seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - start > seconds * 1000.0: return false
		await process_frame
	return true

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var target := Coop.read_join(arguments[0] if not arguments.is_empty() else "")
	assert(not target.is_empty(), "Friend got an unreadable join code")
	assert(Coop.join(self, target.address, "Friend", "aunty", target.port) == OK)
	var connected := [false]
	get_multiplayer().connected_to_server.connect(func(): connected[0] = true)
	var reached: bool = await _wait_for(func(): return connected[0], 20.0)
	assert(reached, "Friend could not reach the host")
	var save := OS.get_environment("TEMP").path_join("coop_friend_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = save
	Session.add_coop(fixture)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var business = current_scene.get_node("Shop/ShopArea").business
	assert(business.has_method("_send"), "A friend's game must use the co-op shop (remote_backend.gd)")
	var player: CharacterBody3D = current_scene.get_node("Player")
	player.set_physics_process(false)
	var shared: bool = await _wait_for(func(): return business.product_price("snack") == 180, 30.0)
	assert(shared, "The host's shop never arrived")
	assert(not current_scene.get_node("DayClock").is_processing(), "A friend's clock must follow the host")
	assert(business.set_product_price("soap", 190))
	# The host holds one soap box; this friend takes the other from the bay, puts it
	# down, picks it up again and leaves still carrying it.
	var box_ready: bool = await _wait_for(func(): return business.queued_boxes.size() >= 1 and business.carried_stock == 0, 30.0)
	assert(box_ready, "The friend never saw the second box at the bay")
	assert(business.pick_up_box(false, 0) and business.carried_stock == 10)
	for frame in range(30): await process_frame
	assert(business.put_down_box(Vector3(6.0, 0.1, 6.0)) and business.carried_stock == 0)
	var on_ground: bool = await _wait_for(func(): return business.logistics.ground_boxes.size() == 1, 30.0)
	assert(on_ground, "The friend's box never landed on the ground")
	assert(business.pick_up_ground_box(0) and business.carried_stock == 10)
	for frame in range(30): await process_frame
	# Fill a shelf: one soap from the box onto a soap rack.
	assert(business.shelve_one(-1) and business.carried_stock == 9, "The friend could not shelve a soap")
	for frame in range(30): await process_frame
	# Serve the host's customer at the counter: scan both bottles, take the cash.
	var operations = current_scene.get_node("ShopOperations")
	var at_counter: bool = await _wait_for(func():
		var waiting = operations.checkout_customer()
		return waiting != null and waiting.coop_mirror and waiting.state == waiting.State.SCANNING, 30.0)
	assert(at_counter, "The friend never saw the host's customer at the counter")
	var customer = operations.checkout_customer()
	assert(operations.basket_customer == customer, "The counter did not show the customer's basket")
	for index in range(customer.total_items()): assert(customer.scan_item(index), "The friend could not scan item %d" % index)
	assert(customer.state == customer.State.PAYING)
	customer.complete_checkout()
	assert(customer.state == customer.State.LEAVING)
	for frame in range(30): await process_frame
	# A second customer wants a discount: stand at the counter, scan, accept the
	# offer and take their UPI payment.
	player.global_position = operations.cashier_point + Vector3(0, 1.0, 0)
	var first_customer = customer
	var next_ready: bool = await _wait_for(func():
		var waiting = operations.checkout_customer()
		return waiting != null and waiting != first_customer and waiting.state == waiting.State.SCANNING, 30.0)
	assert(next_ready, "The friend never saw the second customer at the counter")
	var bargainer = operations.checkout_customer()
	for index in range(bargainer.total_items()): assert(bargainer.scan_item(index))
	assert(bargainer.state == bargainer.State.NEGOTIATING, "The customer did not ask for a discount")
	assert(bargainer.resolve_bargain("accept"), "The friend could not accept the offer")
	assert(bargainer.state == bargainer.State.PAYING)
	bargainer.complete_checkout()
	for frame in range(30): await process_frame
	# Night falls in the host's game: get into the shared home's bed and wait for the
	# host; then the morning and the day report (with this friend's work) arrive.
	var night: bool = await _wait_for(func(): return business.minutes_of_day >= 1200.0, 30.0)
	assert(night, "The host's evening never reached the friend")
	player.global_position = current_scene.get_node("House/Bed/SleepArea/CollisionShape3D").global_position
	for frame in range(3): await physics_frame
	var coop = current_scene.get_node("CoopWorld")
	coop.request_sleep()
	var woke: bool = await _wait_for(func(): return business.day == 2 and current_scene.get_node("Ui/DayReportScreen").visible, 60.0)
	assert(woke, "The friend never woke up to the day report")
	assert(current_scene.get_node("Ui/DayReportScreen").team_label.text.contains("Friend: sold"))
	current_scene.get_node("Ui/DayReportScreen").close()
	var start := player.global_position
	var walked := 0.0
	while walked < 2.0:
		await physics_frame
		walked += 1.0 / Engine.physics_ticks_per_second
		player.global_position = start + Vector3(2.0 * walked, 0, 0)
	print("FRIEND WALKED TO ", player.global_position)
	var stay := float(arguments[1]) if arguments.size() > 1 else 1.0
	await create_timer(stay).timeout
	Coop.leave(self)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save + suffix): DirAccess.remove_absolute(save + suffix)
	quit()
