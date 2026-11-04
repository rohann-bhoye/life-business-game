extends SceneTree

# Slides a car-sized box from each home bay out into West Colony's lane, then along the lane
# to the Main Road, and prints every solid that blocks it.
#   Godot --headless --path . --script res://tools/car_exit_probe.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("car_exit_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	packed.pack(fixture)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	for frame in range(30): await process_frame
	var world = current_scene
	var space: PhysicsDirectSpaceState3D = world.get_viewport().world_3d.direct_space_state
	var car_world = world.find_child("CarWorld", true, false)
	var home_cars: Array = car_world.cars.slice(car_world.cars.size() - 2)
	var shape: Shape3D
	for child in home_cars[0].get_children():
		if child is CollisionShape3D: shape = child.shape
	var local_origin := Transform3D.IDENTITY
	for child in home_cars[0].get_children():
		if child is CollisionShape3D: local_origin = child.transform
	print("CAR SHAPE ", shape, " ", shape.size if shape is BoxShape3D else "")
	var blocked := {}
	# Route: from each bay straight out along +x to the lane centre (x -52.8), then south to z 7.
	for car in home_cars:
		var route: Array = []
		var at: Vector3 = car.global_position
		var steps := 24
		for k in range(steps + 1): route.append([Vector3(lerpf(at.x, -52.8, k / float(steps)), at.y, at.z), -PI / 2.0])
		var start_z := at.z
		for k in range(1, 25): route.append([Vector3(-52.8, at.y, lerpf(start_z, 7.0, k / 24.0)), 0.0])
		for step in route:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			var frame := Transform3D(Basis(Vector3.UP, step[1]), step[0]) * local_origin
			query.transform = frame
			query.exclude = [car.get_rid()]
			query.collision_mask = 0xFFFFF
			for hit in space.intersect_shape(query, 8):
				var key: String = "%s (%s) at %s" % [hit.collider.name, hit.collider.get_parent().name, hit.collider.global_position.snapped(Vector3(0.1, 0.1, 0.1))]
				if not blocked.has(key): blocked[key] = "car %s near %s" % [car.name, step[0].snapped(Vector3(0.1, 0.1, 0.1))]
	for key in blocked: print("BLOCKED by ", key, " -> ", blocked[key])
	print("EXIT PROBE done, blockers: ", blocked.size())
	quit()
