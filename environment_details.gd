extends Node3D

const WIND_SHADER := preload("res://assets/materials/foliage_wind.gdshader")
var clouds: Array[Node3D] = []
var cloud_material: StandardMaterial3D
var detailed_ground: Material
var low_ground: StandardMaterial3D

func _ready() -> void:
	_build_grass()
	_build_clouds()
	_build_ground()
	_build_water()
	var business = get_tree().current_scene.get_node("Shop/ShopArea").business
	business.clock_changed.connect(_update_clouds)
	_update_clouds()

func _process(delta: float) -> void:
	for cloud in clouds:
		cloud.position.x += delta * 0.34
		if cloud.position.x > 48.0: cloud.position.x = -48.0

func _build_grass() -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-0.065, 0, 0), Vector3(0.065, 0, 0), Vector3(0.03, 0.55, 0), Vector3(0, 0, -0.065), Vector3(0, 0, 0.065), Vector3(0, 0.45, 0.03)]:
		builder.add_vertex(point)
	builder.generate_normals()
	var blade := builder.commit()
	var material := ShaderMaterial.new()
	material.shader = WIND_SHADER
	material.set_shader_parameter("base_color", Color(0.2, 0.46, 0.2))
	material.set_shader_parameter("wind_strength", 0.1)
	blade.surface_set_material(0, material)
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()	
	rng.seed = 481516
	for strip_z in [1.65, 12.35, -11.5, 18.0]:
		for index in range(90):
			var x := rng.randf_range(-30.0, 30.0)
			if absf(x + 3.0) < 5.0 and strip_z < 3.0: continue
			var z: float = strip_z + rng.randf_range(-1.0, 1.0)
			if z > 11.2 and x > -16.6 and x < 6.5: continue
			if absf(x - 4.0) < 2.0 and z < 3.0: continue
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.75, 1.25))
			transforms.append(Transform3D(basis, Vector3(x, 0.13, z)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = transforms.size()
	multimesh.mesh = blade
	for index in range(transforms.size()): multimesh.set_instance_transform(index, transforms[index])
	var grass := MultiMeshInstance3D.new()
	grass.name = "WindGrass"
	grass.multimesh = multimesh
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)

func _build_clouds() -> void:
	cloud_material = StandardMaterial3D.new()
	cloud_material.albedo_color = Color(0.92, 0.95, 0.97)
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(8):
		var cloud := Node3D.new()
		cloud.name = "Cloud%d" % index
		cloud.position = Vector3(-42 + index * 12, 18 + (index % 3) * 2.2, -36 - (index % 2) * 12)
		cloud.scale = Vector3(1.8 + (index % 3) * 0.4, 0.65, 1.0)
		add_child(cloud)
		clouds.append(cloud)
		for puff in range(4):
			var mesh := MeshInstance3D.new()
			mesh.name = "Puff%d" % puff
			var sphere := SphereMesh.new()
			sphere.radius = 1.5
			sphere.height = 2.2
			sphere.radial_segments = 12
			sphere.rings = 6
			sphere.material = cloud_material
			mesh.mesh = sphere
			mesh.position = Vector3((puff - 1.5) * 1.5, absf(puff - 1.5) * -0.25, sin(puff * 2.0) * 0.5)
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.add_child(mesh)

func _update_clouds() -> void:
	var business = get_tree().current_scene.get_node("Shop/ShopArea").business
	var elevation: float = sin((business.minutes_of_day / 60.0 - 6.0) / 24.0 * TAU)
	var daylight := smoothstep(-0.15, 0.35, elevation)
	cloud_material.albedo_color = Color(0.1, 0.14, 0.22).lerp(Color(0.92, 0.95, 0.97), daylight)

func _build_ground() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/grass_ground.gdshader")
	detailed_ground = material
	get_tree().current_scene.get_node("MeshInstance3D").material_override = material
	low_ground = StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.seed = 481516
	noise.frequency = 0.08
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.19, 0.29, 0.11), Color(0.32, 0.45, 0.2)])
	texture.color_ramp = ramp
	low_ground.albedo_texture = texture
	low_ground.uv1_scale = Vector3(24, 24, 1)
	low_ground.roughness = 0.98

func set_quality(quality: int) -> void:
	var grass := get_node("WindGrass") as MultiMeshInstance3D
	grass.visible = quality > 0
	grass.multimesh.visible_instance_count = -1
	grass.visibility_range_end = 55.0
	get_tree().current_scene.get_node("MeshInstance3D").material_override = low_ground if quality == 0 else detailed_ground
	for cloud in clouds:
		cloud.visible = quality > 0
	get_node("GardenWater").visible = quality > 0
	set_process(quality > 0)

func _build_water() -> void:
	var builder = get_parent()
	var pond := Node3D.new()
	pond.name = "GardenWater"
	pond.position = Vector3(19, 0.15, -9)
	add_child(pond)
	for z in [-1.65, 1.65]: builder._box("WaterEdgeZ%s" % z, pond, Vector3(5.4, 0.3, 0.22), Vector3(0, 0.12, z), Color(0.5, 0.54, 0.53), true)
	for x in [-2.6, 2.6]: builder._box("WaterEdgeX%s" % x, pond, Vector3(0.22, 0.3, 3.1), Vector3(x, 0.12, 0), Color(0.5, 0.54, 0.53), true)
	var water := MeshInstance3D.new()
	water.name = "FlowingWater"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(5, 3)
	mesh.subdivide_width = 24
	mesh.subdivide_depth = 16
	water.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/water_flow.gdshader")
	water.material_override = material
	water.position.y = 0.12
	pond.add_child(water)
