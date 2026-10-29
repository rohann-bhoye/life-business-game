extends RefCounted

# A stand-in dungeon room for the first milestone (the real floors come from the
# Blender kit and dungeon_layouts.gd next): a 16 m rock hall in the anime look
# (toon.gdshader, outlines on the boulders), glowing mushrooms, fireflies, two
# torches and the entry stone with its swirl, where E takes the player back up.
# Metas: entry (spawn), exit (the stone), facing (spawn yaw), local to the room.
const ROCK := Color(0.23, 0.29, 0.35)
const MOSS := Color(0.31, 0.62, 0.43)

static func build(origin: Vector3) -> Node3D:
	var room := Node3D.new()
	room.name = "DungeonFloor"
	room.position = origin
	var rock := _toon(ROCK)
	var dark := _toon(ROCK.darkened(0.35))
	_slab(room, Vector3(18, 0.4, 18), Vector3(0, -0.2, 0), _toon(Color(0.27, 0.32, 0.36)))
	_slab(room, Vector3(18, 0.4, 18), Vector3(0, 6.2, 0), dark)
	for wall in [[Vector3(18, 6, 1), Vector3(0, 3, -9)], [Vector3(18, 6, 1), Vector3(0, 3, 9)], [Vector3(1, 6, 18), Vector3(-9, 3, 0)], [Vector3(1, 6, 18), Vector3(9, 3, 0)]]:
		_slab(room, wall[0], wall[1], rock)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var mossy := _toon(MOSS)
	for index in range(12):
		var boulder := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radial_segments = 8
		sphere.rings = 5
		boulder.mesh = sphere
		var spot := Vector3(rng.randf_range(-7.5, 7.5), 0.3, rng.randf_range(-7.5, 3.0))
		if index < 8: spot = Vector3(signf(spot.x) * rng.randf_range(6.5, 8.0), 0.3, spot.z)
		boulder.position = spot
		boulder.scale = Vector3(rng.randf_range(1.0, 2.2), rng.randf_range(0.8, 1.6), rng.randf_range(1.0, 2.0))
		boulder.material_override = mossy if index % 3 == 0 else rock
		room.add_child(boulder)
	for index in range(9):
		var colour: Color = [Color(0.78, 1.0, 0.42), Color(0.25, 0.76, 0.79), Color(1.0, 0.5, 0.82)][index % 3]
		var spot := Vector3(rng.randf_range(-7.0, 7.0), 0, rng.randf_range(-7.5, 2.0))
		var size := rng.randf_range(0.6, 1.4)
		var stem := MeshInstance3D.new()
		var stalk := CylinderMesh.new()
		stalk.top_radius = 0.07 * size
		stalk.bottom_radius = 0.1 * size
		stalk.height = 0.6 * size
		stalk.radial_segments = 6
		stem.mesh = stalk
		stem.position = spot + Vector3(0, 0.3 * size, 0)
		stem.material_override = _toon(Color(0.9, 0.88, 0.8))
		room.add_child(stem)
		var cap := MeshInstance3D.new()
		var dome := SphereMesh.new()
		dome.radius = 0.32 * size
		dome.height = 0.32 * size
		dome.is_hemisphere = true
		dome.radial_segments = 8
		dome.rings = 3
		cap.mesh = dome
		cap.position = spot + Vector3(0, 0.6 * size, 0)
		cap.material_override = _glow(colour)
		room.add_child(cap)
	for side in [-1, 1]:
		var torch := OmniLight3D.new()
		torch.light_color = Color(1.0, 0.7, 0.4)
		torch.light_energy = 2.4
		torch.omni_range = 14.0
		torch.position = Vector3(side * 8.0, 3.2, -2.0)
		room.add_child(torch)
		var flame := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.3, 0.45)
		flame.mesh = quad
		var fire := _glow(Color(1.0, 0.66, 0.22))
		fire.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		flame.material_override = fire
		flame.position = torch.position
		room.add_child(flame)
	var fireflies := CPUParticles3D.new()
	fireflies.amount = 40
	fireflies.lifetime = 6.0
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(8, 2, 8)
	fireflies.position = Vector3(0, 2.4, 0)
	fireflies.direction = Vector3(0, 1, 0)
	fireflies.spread = 180.0
	fireflies.gravity = Vector3.ZERO
	fireflies.initial_velocity_min = 0.1
	fireflies.initial_velocity_max = 0.35
	var dot := QuadMesh.new()
	dot.size = Vector2(0.07, 0.07)
	var spark := _glow(Color(0.85, 1.0, 0.5))
	spark.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dot.material = spark
	fireflies.mesh = dot
	room.add_child(fireflies)
	# The entry stone with its small swirl: arrive here, press E here to go back up.
	var stone := MeshInstance3D.new()
	var base := CylinderMesh.new()
	base.top_radius = 1.2
	base.bottom_radius = 1.4
	base.height = 0.3
	stone.mesh = base
	stone.position = Vector3(0, 0.15, 7.0)
	stone.material_override = _toon(Color(0.55, 0.53, 0.5))
	room.add_child(stone)
	var swirl := MeshInstance3D.new()
	var disc := QuadMesh.new()
	disc.size = Vector2(1.8, 1.8)
	swirl.mesh = disc
	var portal := ShaderMaterial.new()
	portal.shader = preload("res://assets/materials/portal.gdshader")
	swirl.material_override = portal
	swirl.position = Vector3(0, 1.3, 8.3)
	room.add_child(swirl)
	room.set_meta("entry", Vector3(0, 1.0, 5.0))
	room.set_meta("exit", Vector3(0, 1.0, 7.0))
	room.set_meta("facing", 0.0)
	return room

static func _slab(room: Node3D, size: Vector3, offset: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = offset
	mesh.material_override = material
	room.add_child(mesh)
	var body := StaticBody3D.new()
	body.position = offset
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = size
	shape.shape = solid
	body.add_child(shape)
	room.add_child(body)

static func _toon(colour: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/toon.gdshader")
	material.set_shader_parameter("albedo", colour)
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://assets/materials/outline.gdshader")
	outline.set_shader_parameter("width", 0.03)
	material.next_pass = outline
	return material

static func _glow(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material
