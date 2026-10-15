extends RefCounted

static func build(parent: Node3D, sources: Array, name: String) -> void:
	var groups := {}
	for source in sources:
		if not source is MeshInstance3D or source.mesh == null: continue
		var material: Material = source.material_override
		if material == null: material = source.mesh.surface_get_material(0)
		if material == null: continue
		var unit: Mesh
		var size: Vector3
		var kind := ""
		if source.mesh is BoxMesh:
			kind = "box"
			unit = BoxMesh.new()
			unit.size = Vector3.ONE
			size = source.mesh.size
		elif source.mesh is SphereMesh:
			kind = "sphere"
			unit = SphereMesh.new()
			unit.radius = 1.0
			unit.height = 2.0
			unit.radial_segments = source.mesh.radial_segments
			unit.rings = source.mesh.rings
			size = Vector3(source.mesh.radius, source.mesh.height / 2.0, source.mesh.radius)
		else: continue
		var key := "%s:%d:%d" % [kind, material.get_instance_id(), source.cast_shadow]
		if not groups.has(key): groups[key] = {"mesh": unit, "material": material, "shadow": source.cast_shadow, "transforms": []}
		var transform: Transform3D = parent.global_transform.affine_inverse() * source.global_transform
		transform.basis = transform.basis * Basis.from_scale(size)
		groups[key].transforms.append(transform)
		# Retain named nodes and colliders for existing interactions and tests.
		source.layers = 0
	for key in groups:
		var group: Dictionary = groups[key]
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = group.mesh
		mesh.instance_count = group.transforms.size()
		for index in range(mesh.instance_count): mesh.set_instance_transform(index, group.transforms[index])
		var instance := MultiMeshInstance3D.new()
		instance.name = "%s%d" % [name, parent.get_child_count()]
		instance.multimesh = mesh
		instance.material_override = group.material
		instance.cast_shadow = group.shadow
		parent.add_child(instance)
