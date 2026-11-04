extends SceneTree

# Lists solid objects that sit inside each other across the whole town: every static box
# collider's world bounds are compared with every other one (siblings of the same
# building/prop are skipped, slabs and ground are ignored). Biggest overlaps first.
#   Godot --headless --path . --script res://tools/city_overlap_probe.gd
const MIN_DEPTH := 0.25

func _initialize() -> void:
	call_deferred("_run")

func _owner_name(node: Node) -> String:
	var parent := node.get_parent()
	return "%s/%s" % [parent.name if parent != null else "", node.name]

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("city_probe_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	packed.pack(fixture)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	for frame in range(30): await process_frame
	var boxes: Array = []
	for body in current_scene.find_children("*", "StaticBody3D", true, false):
		for child in body.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D and not child.disabled:
				var shape: BoxShape3D = child.shape
				var box: AABB = child.global_transform * AABB(-shape.size / 2.0, shape.size)
				if box.size.y < 0.4 or box.size.x > 40.0 or box.size.z > 40.0: continue
				boxes.append({"box": box, "name": _owner_name(body), "body": body})
	var found: Array = []
	for i in range(boxes.size()):
		for j in range(i + 1, boxes.size()):
			var a: Dictionary = boxes[i]
			var b: Dictionary = boxes[j]
			if a.body.get_parent() == b.body.get_parent(): continue
			var cut: AABB = a.box.intersection(b.box)
			if cut.size.x >= MIN_DEPTH and cut.size.y >= MIN_DEPTH and cut.size.z >= MIN_DEPTH:
				found.append([cut.get_volume(), a.name + " @" + str(a.body.get_parent().global_position.snapped(Vector3(0.1, 0.1, 0.1))), b.name + " @" + str(b.body.get_parent().global_position.snapped(Vector3(0.1, 0.1, 0.1))), cut.get_center().snapped(Vector3(0.1, 0.1, 0.1))])
	found.sort_custom(func(x, y): return x[0] > y[0])
	print("BOXES ", boxes.size(), " OVERLAPS ", found.size())
	for k in range(mini(found.size(), 60)):
		print("OVL %.2f m3  %s  <>  %s  at %s" % found[k])
	quit()
