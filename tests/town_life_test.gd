extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("town_life_test_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	business.save_path = ""
	var town: Node3D = current_scene.get_node("Neighbourhood")
	for node_name in ["TownExpansion", "RivalShopLife", "RoadExtension-1", "RoadExtension1", "ChaiWala", "BusWaiting", "Auto0", "Scooter5"]:
		assert(town.find_child(node_name, true, false) != null, "Missing town node %s" % node_name)
	for index in range(8): assert(town.find_child("MarketShop%d" % index, true, false) != null)
	for index in range(16): assert(town.find_child("TownHouseBody%d" % index, true, false) != null)
	# The next phase (shops, houses, chai stall) is built but hidden and without collisions.
	var future: Node3D = town.get_node("FutureTown")
	assert(not future.visible and future.process_mode == Node.PROCESS_MODE_DISABLED and future.is_ancestor_of(town.find_child("MarketShop0", true, false)))
	await physics_frame
	var probe: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	assert(probe.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-40, 5, -6), Vector3(-40, 0.5, -6))).is_empty(), "Hidden houses must not block anything")
	var life = town.get_node("RivalShopLife")
	assert(not life.keeper.visible, "Sharma's shop is closed before day %d" % business.RIVAL_OPEN_DAY)
	business.advance_clock(2 * 1440.0 + 120.0)
	assert(business.rival_open() and life.keeper.visible and life.is_physics_processing())
	var before: Dictionary = business.snapshot()
	life.set_physics_process(false)
	var shopper: Node3D = life.shoppers[0]
	var seen_phases := {}
	for step in range(400):
		life._physics_process(0.1)
		seen_phases[life.states[0].phase] = true
		if life.states[0].phase == 4: break
	assert(seen_phases.has(1) and seen_phases.has(3) and life.states[0].phase == 4, "Rival shopper must walk in and come back out")
	assert(shopper.global_position.distance_to(life.PATH_START) < 0.1)
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	await physics_frame
	assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-30, 1, 7), Vector3(-33, 1, 7))).is_empty(), "West boundary missing")
	assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1, 30), Vector3(0, 1, 33))).is_empty(), "South boundary missing")
	assert(business.snapshot() == before, "Town scenery must not change the economy")

	# Traffic: vehicles drive, stop for people in their lane, the bus halts at the stop.
	var traffic = town.get_node("Traffic")
	traffic.set_physics_process(false)
	var player: Node3D = current_scene.get_node("Player")
	player.set_physics_process(false)
	assert(traffic.vehicles.size() == 8 and traffic.bus != null)
	# Clear the lanes so only the tested vehicle and the bus are near.
	for index in range(1, traffic.vehicles.size()):
		if traffic.vehicles[index] != traffic.bus: traffic.vehicles[index].position.x = 70.0 * traffic.states[index].direction
	traffic.vehicles[0].position.x = -20.0
	var auto: Node3D = traffic.vehicles[0]
	var start_x: float = auto.position.x
	traffic._physics_process(0.5)
	assert(auto.position.x > start_x, "Eastbound traffic moves east")
	player.global_position = Vector3(auto.position.x + 5.0, 1.1, traffic.EAST_LANE)
	for step in range(40): traffic._physics_process(0.1)
	assert(auto.position.x + 1.25 < player.global_position.x and traffic.states[0].speed < 0.01, "Vehicles stop for people in the road")
	player.global_position = Vector3(0, 1.1, -30)
	var bus_state: Dictionary = traffic.states[traffic.vehicles.find(traffic.bus)]
	traffic.bus.position.x = traffic.BUS_STOP_X + 3.0
	bus_state.served = false
	bus_state.speed = bus_state.cruise
	for step in range(20): traffic._physics_process(0.1)
	assert(is_equal_approx(traffic.bus.position.x, traffic.BUS_STOP_X) and bus_state.stop > 0.0, "Bus halts at the bus stop")

	# Town edge: see-through barrier, 3-2-1 countdown, stepping back cancels, then home.
	var boundary = town.get_node("TownBoundary")
	boundary.set_physics_process(false)
	player.global_position = Vector3(30.0, 1.1, 20)
	boundary._physics_process(1.0)
	assert(boundary.walls[1].visible and boundary.material.albedo_color.a > 0.4)
	assert(boundary.notice.visible and boundary.notice.text.contains("Returning home in 2"), boundary.notice.text)
	player.global_position = Vector3(20, 1.1, 20)
	boundary._physics_process(0.1)
	assert(not boundary.notice.visible and boundary.remaining < 0.0, "Stepping back cancels the countdown")
	player.global_position = Vector3(30.0, 1.1, 20)
	for step in range(4): boundary._physics_process(1.0)
	assert(player.indoors and player.global_position.distance_to(Vector3(30.0, 1.1, 20)) > 20.0, "Sent home after 3-2-1")

	# Night: shutters down, porch lamps on, chai till 23:00, fewer people and cars, stars.
	business.advance_clock(22 * 60.0 - business.minutes_of_day)
	var night_life = town.get_node("NightLife")
	assert(night_life.shutters.size() == 8 and night_life.shutters.all(func(shutter): return shutter.visible))
	assert(night_life.porch_lamps.size() == 16 and night_life.porch_lamps[0].get_node("Pool").visible and night_life.lamp_material.emission_enabled)
	assert(night_life.chai_people.size() == 3 and night_life.chai_people[0].visible, "Chai stall stays open till 23:00")
	assert(traffic.vehicles.filter(func(vehicle): return vehicle.visible).size() == 4, "Half the traffic rests at night")
	assert(town.get_node("StreetLife").walkers.filter(func(walker): return walker.visible).size() == 4)
	assert(current_scene.get_node("DayNight").stars.visible and not life.keeper.visible)
	business.advance_clock(12 * 60.0)
	assert(not night_life.shutters[0].visible and not current_scene.get_node("DayNight").stars.visible and life.keeper.visible)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: town expansion, Sharma shop keeper and shoppers walking in/out, old-map edge with the next phase hidden, traffic that stops for people and a bus stop, see-through edge with 3-2-1 send-home, night shutters/lamps/stars")
	quit()
