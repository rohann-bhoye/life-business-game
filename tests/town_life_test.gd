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
	assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-72, 1, 7), Vector3(-76, 1, 7))).is_empty(), "West boundary missing")
	assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1, 57), Vector3(0, 1, 61))).is_empty(), "South boundary missing")
	assert(business.snapshot() == before, "Town scenery must not change the economy")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: town expansion (roads, market, houses, chai stall, bus stop, vehicles), Sharma shop keeper and shoppers walking in/out, wider boundaries")
	quit()
