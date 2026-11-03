class_name PreviewStage
extends RefCounted
## Builds the little 3D "photo studio" (camera + lights) that every slot
## and the big preview use, and turns an ItemData into a centered, scaled model.


static func build(viewport: SubViewport, distance: float, with_platform: bool) -> Node3D:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.8)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Invisible "studio sky" so metal / shiny items have something to reflect.
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.75, 0.8, 0.9)
	sky_mat.sky_horizon_color = Color(0.55, 0.58, 0.65)
	sky_mat.ground_bottom_color = Color(0.1, 0.11, 0.13)
	sky_mat.ground_horizon_color = Color(0.35, 0.37, 0.42)
	sky.sky_material = sky_mat
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -30, 0)
	key.light_energy = 1.3
	viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 140, 0)
	fill.light_energy = 0.8
	fill.light_color = Color(0.55, 0.7, 1.0)
	viewport.add_child(fill)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 30.0
	cam.position = Vector3(0, distance * 0.22, distance)
	cam.rotation.x = -atan2(distance * 0.22, distance)
	viewport.add_child(cam)
	cam.current = true

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	viewport.add_child(pivot)

	if with_platform:
		var disc := MeshInstance3D.new()
		disc.name = "Platform"
		var cm := CylinderMesh.new()
		cm.top_radius = 0.75
		cm.bottom_radius = 0.8
		cm.height = 0.06
		cm.radial_segments = 64
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("1b2230")
		m.metallic = 0.2
		m.roughness = 0.55
		cm.material = m
		disc.mesh = cm
		disc.position.y = -0.62
		viewport.add_child(disc)

		var glow := OmniLight3D.new()
		glow.name = "RarityLight"
		glow.position = Vector3(0, -0.45, 0.5)
		glow.omni_range = 2.2
		glow.light_energy = 1.4
		viewport.add_child(glow)
	return pivot


static func make_model(item: ItemData) -> Node3D:
	var holder := Node3D.new()
	if item == null:
		return holder
	var model: Node3D = null
	if item.model_scene != null:
		var inst := item.model_scene.instantiate()
		if inst is Node3D:
			model = inst
		else:
			inst.free()
	if model == null and item.mesh != null:
		var mi := MeshInstance3D.new()
		mi.mesh = item.mesh
		if item.mesh.get_surface_count() > 0 and item.mesh.surface_get_material(0) == null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = item.color
			mat.metallic = item.metallic
			mat.roughness = item.roughness
			if item.emission_energy > 0.0:
				mat.emission_enabled = true
				mat.emission = item.color
				mat.emission_energy_multiplier = item.emission_energy
			mi.material_override = mat
		model = mi
	if model == null:
		return holder

	# Center + scale the model so any size of asset fits the slot nicely.
	var fit := Node3D.new()
	holder.add_child(fit)
	fit.add_child(model)
	var acc: Array = []
	_collect_aabb(model, Transform3D.IDENTITY, acc)
	if not acc.is_empty():
		var box: AABB = acc[0]
		var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
		if longest > 0.0001:
			var s := item.preview_scale / longest
			fit.scale = Vector3.ONE * s
			fit.position = -box.get_center() * s
	return holder


static func _collect_aabb(node: Node, parent_xform: Transform3D, acc: Array) -> void:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	if node is VisualInstance3D and not (node is Light3D):
		var box: AABB = xform * (node as VisualInstance3D).get_aabb()
		if acc.is_empty():
			acc.append(box)
		else:
			acc[0] = (acc[0] as AABB).merge(box)
	for child in node.get_children():
		_collect_aabb(child, xform, acc)
