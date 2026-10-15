extends RefCounted

const PATHS := {
	"bottle": "res://assets/products/kenney/soda-bottle.glb",
	"snack": "res://assets/products/kenney/bag.glb"
}
static var models: Dictionary = {}
static var bounds: Dictionary = {}

static func _bounds(node: Node3D, transform: Transform3D) -> AABB:
	var combined := AABB()
	var current := transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		combined = current * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := _bounds(child, current)
			if child_bounds.has_volume():
				combined = combined.merge(child_bounds) if combined.has_volume() else child_bounds
	return combined

static func attach(parent: Node3D, product: String, size: Vector3) -> void:
	if not models.has(product):
		models[product] = load(PATHS[product]) as PackedScene
		var sample: Node3D = models[product].instantiate()
		bounds[product] = _bounds(sample, Transform3D.IDENTITY)
		sample.free()
	var box: AABB = bounds[product]
	var factor := minf(size.x / box.size.x, minf(size.y / box.size.y, size.z / box.size.z))
	var visual := Node3D.new()
	visual.name = "ProductAsset"
	visual.scale = Vector3.ONE * factor
	visual.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * factor
	visual.add_child(models[product].instantiate())
	parent.add_child(visual)
	label_product(parent, product, box.size.x * factor * 0.5 + 0.002)

static func label_product(parent: Node3D, product: String, face_x := 0.084) -> void:
	var label := Label3D.new()
	label.name = "PackageLabel"
	label.text = {"bottle": "REUSE", "snack": "MASALA\nCRUNCH", "soap": "SOAP"}[product]
	label.font_size = 32
	label.pixel_size = 0.00055
	label.outline_size = 0
	label.rotation.y = PI / 2
	label.position = Vector3(face_x, 0.21 if product == "bottle" else (0.13 if product == "snack" else 0.06), 0)
	var patch := MeshInstance3D.new()
	patch.name = "PackageSleeve"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.005, 0.11 if product != "soap" else 0.07, 0.1)
	patch.mesh = mesh
	patch.position = label.position - Vector3(0.003, 0, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = {"bottle": Color(0.04, 0.43, 0.44), "snack": Color(0.8, 0.19, 0.19), "soap": Color(0.18, 0.35, 0.67)}[product]
	material.roughness = 0.9
	patch.material_override = material
	parent.add_child(patch)
	parent.add_child(label)
