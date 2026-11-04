extends RefCounted

# Occlusion culling for the town. The Compatibility renderer draws everything inside the
# view cone, even behind walls (the shop's back wall hides about a hundred town objects that
# were still drawn). Every solid wall and building body already has a box collider, so each
# tall one also gets a box occluder of the same size and place. Built once the town exists
# (environment_details.gd) and again after a shop expansion (shop_operations.gd).
const MIN_HEIGHT := 2.2
const MIN_LENGTH := 2.0
const MAX_SIZE := 70.0
const SHRINK := 0.97
const SKIP_NAMES := ["Glass", "Window", "Door", "Fence", "Gate", "Pole", "Tree", "Trunk", "Canopy", "Sign", "Board", "Rack", "Upright", "Shelf", "Fridge", "Shutter", "Counter", "Desk", "Table", "Cabinet"]
const SKIP_UNDER := ["Player", "Customer", "Worker", "StockWorker", "CarWorld", "Traffic", "StreetLife", "MarketLife", "Ui"]

static func rebuild(world: Node) -> int:
	for old in world.find_children("AutoOccluder", "OccluderInstance3D", true, false): old.queue_free()
	var added := 0
	for body in world.find_children("*", "StaticBody3D", true, false):
		if not (body as Node3D).is_inside_tree() or _skipped(body, world): continue
		for child in body.get_children():
			if not child is CollisionShape3D or child.disabled or not child.shape is BoxShape3D: continue
			var size: Vector3 = child.shape.size
			if size.y < MIN_HEIGHT or maxf(size.x, size.z) < MIN_LENGTH or maxf(size.x, maxf(size.y, size.z)) > MAX_SIZE: continue
			var occluder := OccluderInstance3D.new()
			occluder.name = "AutoOccluder"
			var box := BoxOccluder3D.new()
			box.size = size * SHRINK
			occluder.occluder = box
			occluder.transform = child.transform
			body.add_child(occluder)
			added += 1
	return added

static func _skipped(body: Node, world: Node) -> bool:
	for word in SKIP_NAMES:
		if String(body.name).contains(word): return true
	var node := body.get_parent()
	while node != null and node != world:
		if node.name in SKIP_UNDER: return true
		node = node.get_parent()
	return false
