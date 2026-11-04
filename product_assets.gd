extends RefCounted

const PATHS := {
	"bottle": "res://assets/products/custom/bottle.glb",
	"snack": "res://assets/products/custom/snack.glb",
	"oil": "res://assets/products/custom/oil.glb",
	"milk": "res://assets/products/custom/milk.glb",
	"bread": "res://assets/products/custom/bread.glb",
	"chocolate": "res://assets/products/custom/chocolate.glb",
	"honey": "res://assets/products/custom/honey.glb",
	"soap": "res://assets/products/custom/soap.glb"
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
	# Our models print their label toward +Z; shelves, counters and baskets face +X.
	visual.rotation.y = PI / 2
	visual.position = -Vector3(box.get_center().z, box.position.y, -box.get_center().x) * factor
	visual.add_child(models[product].instantiate())
	parent.add_child(visual)
	label_product(parent, product, box.size.x * factor * 0.5 + 0.002)

static func label_product(parent: Node3D, product: String, face_x := 0.084) -> void:
	# Kenney grocery models already look like their product; only the original three get packaging labels.
	return  # custom product models print their own labels
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
	if product == "bottle":
		# Round bottles get a wrap-around label band instead of a flat card.
		var band := CylinderMesh.new()
		band.top_radius = face_x * 0.92
		band.bottom_radius = face_x * 0.96
		band.height = 0.075
		band.radial_segments = 12
		band.rings = 1
		patch.mesh = band
		patch.position = Vector3(0, label.position.y, 0)
		label.position.x = face_x * 0.94 + 0.003
		label.font_size = 26
	else:
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
