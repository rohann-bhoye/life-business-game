extends RefCounted

const Bounds := preload("res://product_assets.gd")
const ROOT := "res://assets/produce/custom/"
static var scenes := {}
static var boxes := {}

static func attach(parent: Node3D, product: String, size: Vector3, node_name := "ProduceAsset") -> Node3D:
	if not scenes.has(product):
		scenes[product] = load(ROOT + product + ".glb") as PackedScene
		var sample: Node3D = scenes[product].instantiate()
		boxes[product] = Bounds._bounds(sample, Transform3D.IDENTITY)
		sample.free()
	var box: AABB = boxes[product]
	var scale_factor := minf(size.x / box.size.x, minf(size.y / box.size.y, size.z / box.size.z))
	var root := Node3D.new()
	root.name = node_name
	var visual: Node3D = scenes[product].instantiate()
	visual.scale = Vector3.ONE * scale_factor
	visual.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * scale_factor
	root.add_child(visual)
	parent.add_child(root)
	return root
