extends SceneTree

# Lists everything standing on the plot east of Apna Mart (LOT, world x/z), so a shop wing
# can be built there without swallowing benches, poles or paths. Ground, grass and the shop
# itself are skipped. Run: Godot --headless --path . --script res://tools/lot_probe.gd
const LOT := Rect2(0.15, -12.6, 12.4, 14.9)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("lot_probe_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	for frame in range(20): await process_frame
	var world := current_scene
	var shop: Node = world.get_node("Shop")
	var found := 0
	for node in world.find_children("*", "Node3D", true, false):
		if shop.is_ancestor_of(node) or node == shop: continue
		var box := AABB()
		if node is VisualInstance3D:
			if node is MultiMeshInstance3D or not node.is_visible_in_tree(): continue
			box = node.global_transform * node.get_aabb()
		elif node is CollisionShape3D and node.shape is BoxShape3D:
			box = AABB(node.global_position - node.shape.size / 2.0, node.shape.size)
		else: continue
		if box.size.x > 40.0 or box.size.z > 40.0: continue
		var flat := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		if not flat.intersects(LOT): continue
		if box.end.y < 0.16: continue
		found += 1
		print("ON LOT  %-60s  x %.1f..%.1f  z %.1f..%.1f  top %.1f" % [str(world.get_path_to(node)), box.position.x, box.end.x, box.position.z, box.end.z, box.end.y])
	print("DONE %d things on the lot" % found)
	quit()
