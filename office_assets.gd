extends RefCounted

const Bounds = preload("res://product_assets.gd")

static func attach(parent: Node3D, name: String, asset: String, size: Vector3, position: Vector3) -> Node3D:
	var scene: PackedScene = load("res://assets/office/kenney/%s.glb" % asset)
	var model: Node3D = scene.instantiate()
	var bounds: AABB = Bounds._bounds(model, Transform3D.IDENTITY)
	var factor := minf(size.x / bounds.size.x, minf(size.y / bounds.size.y, size.z / bounds.size.z))
	var root := Node3D.new()
	root.name = name
	root.position = position
	root.scale = Vector3.ONE * factor
	model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	root.add_child(model)
	parent.add_child(root)
	return root
