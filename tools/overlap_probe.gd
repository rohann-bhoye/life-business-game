extends SceneTree

# Reports solid things that sit inside each other around the parked cars and the home:
# every drivable car's body is tested against all other solids; any hit is printed.
#   Godot --headless --path . --script res://tools/overlap_probe.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("overlap_probe_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	packed.pack(fixture)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	for frame in range(30): await process_frame
	var world = current_scene
	var space: PhysicsDirectSpaceState3D = world.get_viewport().world_3d.direct_space_state
	var car_world = world.get_node("ShopOperations").get_node_or_null("CarWorld")
	if car_world == null: car_world = world.find_child("CarWorld", true, false)
	var bad := 0
	for car in car_world.cars:
		for child in car.get_children():
			if not child is CollisionShape3D or child.shape == null: continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = child.shape
			query.transform = child.global_transform
			query.exclude = [car.get_rid()]
			query.collision_mask = 0xFFFFF
			for hit in space.intersect_shape(query, 16):
				var other: Object = hit.collider
				print("OVERLAP car ", car.name, " at ", car.global_position.snapped(Vector3(0.1, 0.1, 0.1)), " with ", other.name, " (", other.get_parent().name, ") at ", other.global_position.snapped(Vector3(0.1, 0.1, 0.1)))
				bad += 1
	print("PROBE done, ", car_world.cars.size(), " cars, ", bad, " overlaps")
	quit()
