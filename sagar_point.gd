extends Node3D

# The sea round the island and Sagar Point, the sea-view peak on the south coast hills
# (land_shape.gd shapes the coast, the peak and the ghat road's cut; town_expansion.gd
# adds this node to the town):
# - the sea: one mesh from the coast out to 4 km (dense near the land, coarser far out,
#   open over the land inside LandShape.OCEAN_HOLE), each vertex carrying the sea-bed
#   depth for the anime ocean shader (assets/materials/ocean.gdshader); the sky colours,
#   sun and daylight are copied into it twice a second;
# - invisible sea walls a few metres out in the shallows round the whole island;
# - the ghat road from the West Colony lane's south circle up to the peak: asphalt, white
#   edge lines, a dashed middle and the white-and-black kerb stones of Indian hill roads;
# - the top: a parapet ring (open where the road comes in, under a SAGAR POINT arch), a
#   sandstone chhatri, benches facing the sea and the town, coin binoculars, lamps and the
#   national flag;
# - Sagar Beach below it to the west (LandShape.BEACH): coconut palms, umbrellas with mats,
#   starfish and crabs that scuttle sideways and run from the player; rocks along the
#   waterline all round the island and sea stacks off the peak
#   (tools/blender/build_beach_props.py);
# - a red and white lighthouse on the south-east headland (beam turning at night) and
#   fishing boats sailing past far out.
# The chhatri and lighthouse are tools/blender/build_sagar_props.py models.
const LandShape := preload("res://land_shape.gd")
const IndianHouse := preload("res://indian_house.gd")
const Neighbourhood := preload("res://neighbourhood.gd")
const OCEAN_SHADER := preload("res://assets/materials/ocean.gdshader")

## Fishing boats: [z of its lane, speed along x (m/s), start x, hull colour].
const BOATS := [[168.0, 2.2, -150.0, Color(0.1, 0.32, 0.62)], [245.0, -1.6, 260.0, Color(0.72, 0.16, 0.12)], [370.0, 1.3, 500.0, Color(0.1, 0.5, 0.45)], [-340.0, -1.8, 0.0, Color(0.85, 0.55, 0.1)]]
const BOAT_SPAN := 900.0

var expansion
var ocean_material: ShaderMaterial
var sun: DirectionalLight3D
var sky_material: Material
var beam: Node3D
var boats: Array[Node3D] = []
var since_sky := 1.0
var land_data
var player: Node3D
var crabs: Array[Node3D] = []
var crab_goals: Array[Vector3] = []
var crab_rest := PackedFloat32Array()
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	name = "SagarPoint"
	var world: Node = expansion.town.get_parent() if expansion != null else get_parent()
	var landscape := world.get_node_or_null("Landscape")
	var data = landscape.data if landscape != null and landscape.get_class() == "Terrain3D" else null
	sun = world.get_node_or_null("DirectionalLight3D")
	var environment := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment != null and environment.environment != null and environment.environment.sky != null:
		sky_material = environment.environment.sky.sky_material
	add_child(_ocean(data))
	add_child(_sea_walls())
	_ghat_road()
	_summit()
	_lighthouse(data)
	_boats()
	land_data = data
	player = world.get_node_or_null("Player") as Node3D
	_rocks(data)
	_beach(data)
	_refresh_sky()

func _process(delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	for index in range(boats.size()):
		var lane: Array = BOATS[index]
		var boat := boats[index]
		boat.position.x = wrapf(lane[2] + lane[1] * time, -BOAT_SPAN, BOAT_SPAN)
		boat.position.y = LandShape.SEA_Y + sin(time * 1.3 + index) * 0.16
		boat.rotation.z = sin(time * 1.05 + index * 2.0) * 0.06
		boat.rotation.x = sin(time * 0.8 + index) * 0.03
	if beam != null and beam.visible: beam.rotation.y += delta * 0.7
	_move_crabs(delta)
	since_sky += delta
	if since_sky >= 0.5: _refresh_sky()

func _refresh_sky() -> void:
	since_sky = 0.0
	if ocean_material == null: return
	if sky_material is ProceduralSkyMaterial:
		ocean_material.set_shader_parameter("sky_top", sky_material.sky_top_color)
		ocean_material.set_shader_parameter("sky_horizon", sky_material.sky_horizon_color)
	var daylight := 1.0
	if sun != null:
		daylight = clampf(sun.light_energy / 0.9, 0.0, 1.0) if sun.is_visible_in_tree() else 0.0
		ocean_material.set_shader_parameter("sun_dir", sun.global_transform.basis.z)
		ocean_material.set_shader_parameter("sun_color", sun.light_color)
	ocean_material.set_shader_parameter("daylight", daylight)
	if beam != null: beam.visible = daylight < 0.35

# ---------- the sea

## Grid lines along one axis: every 2 m in the coastal bands (lo..mid_lo, mid_hi..hi),
## every 4 m between them, then wider and wider out to 4 km.
static func _lines(lo: float, mid_lo: float, mid_hi: float, hi: float) -> PackedFloat32Array:
	var inner: Array[float] = []
	var v := lo
	while v < mid_lo - 0.01:
		inner.append(v)
		v += 2.0
	v = mid_lo
	while v < mid_hi - 0.01:
		inner.append(v)
		v += 4.0
	v = mid_hi
	while v <= hi + 0.01:
		inner.append(v)
		v += 2.0
	var outer: Array[float] = []
	var step := 2.5
	var reach := 0.0
	while reach < 4000.0:
		step *= 1.25
		reach += step
		outer.append(reach)
	var lines := PackedFloat32Array()
	for k in range(outer.size() - 1, -1, -1): lines.append(lo - outer[k])
	for value in inner: lines.append(value)
	for value in outer: lines.append(hi + value)
	return lines

## Metres of water over the sea bed at (x, z): from the baked land, sloping deeper past
## its edge.
static func _depth(data, x: float, z: float) -> float:
	var outside := maxf(maxf(-128.0 - x, x - 127.0), maxf(float(LandShape.NORTH_EDGE) - z, z - 127.0))
	var edge_depth := LandShape.SEA_Y - LandShape.SEA_BED
	if outside > 0.0 or data == null: return edge_depth + maxf(outside, 0.0) * 0.5
	var height: float = data.get_height(Vector3(x, 0, z))
	if is_nan(height): return edge_depth
	return LandShape.SEA_Y - height

func _ocean(data) -> MeshInstance3D:
	var xs := _lines(-140.0, -100.0, 100.0, 140.0)
	# Finer far out to the south, the way Sagar Point looks.
	var zs := _lines(-270.0, -228.0, 100.0, 200.0)
	var hole := LandShape.OCEAN_HOLE
	var vertices := PackedVector3Array()
	var depths := PackedVector2Array()
	var normals := PackedVector3Array()
	for row in range(zs.size()):
		var z := zs[row]
		var row_step := zs[mini(row + 1, zs.size() - 1)] - zs[maxi(row - 1, 0)]
		for column in range(xs.size()):
			var x := xs[column]
			vertices.append(Vector3(x, 0.0, z))
			normals.append(Vector3.UP)
			var inside := x > hole.position.x + 0.01 and x < hole.end.x - 0.01 and z > hole.position.y + 0.01 and z < hole.end.y - 0.01
			# UV2: sea-bed depth, and the grid spacing here (the shader calms coarse parts).
			var spacing := maxf(row_step, xs[mini(column + 1, xs.size() - 1)] - xs[maxi(column - 1, 0)]) / 2.0
			depths.append(Vector2(0.0 if inside else _depth(data, x, z), spacing))
	var indices := PackedInt32Array()
	var columns := xs.size()
	for row in range(zs.size() - 1):
		for column in range(columns - 1):
			if xs[column] >= hole.position.x - 0.01 and xs[column + 1] <= hole.end.x + 0.01 and zs[row] >= hole.position.y - 0.01 and zs[row + 1] <= hole.end.y + 0.01: continue
			var a := row * columns + column
			indices.append_array([a, a + 1, a + columns + 1, a, a + columns + 1, a + columns])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV2] = depths
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ocean_material = ShaderMaterial.new()
	ocean_material.shader = OCEAN_SHADER
	ocean_material.set_shader_parameter("ripples", _noise_texture(true, 0.018, 41))
	ocean_material.set_shader_parameter("foam_noise", _noise_texture(false, 0.03, 43))
	var sea := MeshInstance3D.new()
	sea.name = "Ocean"
	sea.mesh = mesh
	sea.material_override = ocean_material
	sea.position.y = LandShape.SEA_Y
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.extra_cull_margin = 4.0
	return sea

static func _noise_texture(normal_map: bool, frequency: float, seed_value: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.as_normal_map = normal_map
	texture.bump_strength = 5.0
	texture.noise = noise
	return texture

## Walls in the shallows (9 m in from the land's edge, where the water is at most knee
## deep), so nobody walks out into the sea.
func _sea_walls() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "SeaWalls"
	var west := -119.0
	var east := 118.0
	var north := float(LandShape.NORTH_EDGE) + 9.0
	var south := 118.0
	for wall in [[Vector3(west, 20, (north + south) / 2.0), Vector3(0.4, 70, south - north)], [Vector3(east, 20, (north + south) / 2.0), Vector3(0.4, 70, south - north)], [Vector3(0, 20, north), Vector3(east - west, 70, 0.4)], [Vector3(0, 20, south), Vector3(east - west, 70, 0.4)]]:
		var piece := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = wall[1]
		piece.shape = shape
		piece.position = wall[0]
		body.add_child(piece)
	return body

# ---------- the ghat road

static func _side(points: PackedVector3Array, index: int) -> Vector3:
	var ahead := points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]
	return Vector3(-ahead.z, 0.0, ahead.x).normalized()

## A strip along `points` from `from` to `to` metres off the middle line (negative is the
## other side), `lift` above the road.
static func _strip(st: SurfaceTool, points: PackedVector3Array, i: int, from: float, to: float, lift: float, colour: Color) -> void:
	var a := points[i] + Vector3(0, lift, 0)
	var b := points[i + 1] + Vector3(0, lift, 0)
	var side_a := _side(points, i)
	var side_b := _side(points, i + 1)
	var normal := (b - a).cross(side_a).normalized()
	if normal.y < 0.0: normal = -normal
	IndianHouse._quad(st, a + side_a * from, a + side_a * to, b + side_b * to, b + side_b * from, normal, colour)

func _ghat_road() -> void:
	var road := LandShape.view_road()
	var points := PackedVector3Array([Vector3(road[0].x, road[0].y, 56.4)])
	points.append_array(road)
	var half := LandShape.VIEW_ROAD_HALF
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var marks := SurfaceTool.new()
	marks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color(0.9, 0.91, 0.88)
	var travelled := 0.0
	var next_stone := 6.0
	var stone := 0
	for i in range(points.size() - 1):
		_strip(surface, points, i, -half, half, 0.0, Color.WHITE)
		_strip(marks, points, i, half - 0.32, half - 0.2, 0.012, white)
		_strip(marks, points, i, -half + 0.2, -half + 0.32, 0.012, white)
		if fmod(travelled, 4.0) < 2.0: _strip(marks, points, i, -0.06, 0.06, 0.012, Color(0.92, 0.86, 0.55))
		travelled += points[i].distance_to(points[i + 1])
		# White and black kerb stones every 3.2 m on both sides (none on the peak's top).
		if travelled >= next_stone:
			next_stone += 3.2
			stone += 1
			var side := _side(points, i)
			for sign in [-1.0, 1.0]:
				var at: Vector3 = points[i] + side * sign * (half + 0.35)
				if Vector2(at.x, at.z).distance_to(LandShape.PEAK) < LandShape.PLATEAU_R + 0.5: continue
				IndianHouse.box(marks, at + Vector3(0, 0.2, 0), Vector3(0.34, 0.5, 0.34), Color(0.93, 0.93, 0.9) if stone % 2 == 0 else Color(0.08, 0.08, 0.09))
	var asphalt := MeshInstance3D.new()
	asphalt.name = "GhatRoad"
	asphalt.mesh = surface.commit()
	var road_material: Material = expansion._road_material() if expansion != null else null
	asphalt.material_override = road_material if road_material != null else IndianHouse._material()
	add_child(asphalt)
	var lines := MeshInstance3D.new()
	lines.name = "GhatRoadMarkings"
	lines.mesh = marks.commit()
	lines.material_override = IndianHouse._material()
	add_child(lines)
	if expansion != null:
		expansion._road_sign("SagarPointSign", Vector3(-56.6, 0.1, 59.0), PI, "SAGAR POINT\nSea view - up the ghat")

# ---------- the top

## A box turned `yaw` about the vertical.
static func _obox(st: SurfaceTool, center: Vector3, size: Vector3, yaw: float, colour: Color) -> void:
	var x := Vector3(cos(yaw), 0, -sin(yaw)) * size.x / 2.0
	var y := Vector3(0, size.y / 2.0, 0)
	var z := Vector3(sin(yaw), 0, cos(yaw)) * size.z / 2.0
	var c := center
	IndianHouse._quad(st, c + x - y - z, c + x + y - z, c + x + y + z, c + x - y + z, x.normalized(), colour)
	IndianHouse._quad(st, c - x - y - z, c - x - y + z, c - x + y + z, c - x + y - z, -x.normalized(), colour)
	IndianHouse._quad(st, c - x + y - z, c - x + y + z, c + x + y + z, c + x + y - z, Vector3.UP, colour)
	IndianHouse._quad(st, c - x - y + z, c + x - y + z, c + x + y + z, c - x + y + z, z.normalized(), colour)
	IndianHouse._quad(st, c - x - y - z, c - x + y - z, c + x + y - z, c + x - y - z, -z.normalized(), colour)

func _solid(body: StaticBody3D, center: Vector3, size: Vector3, yaw: float) -> void:
	var piece := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	piece.shape = shape
	piece.position = center
	piece.rotation.y = yaw
	body.add_child(piece)

func _summit() -> void:
	var top := Vector3(LandShape.PEAK.x, LandShape.PEAK_H, LandShape.PEAK.y)
	var road := LandShape.view_road()
	var entry_point := road[road.size() - 1]
	var entry := atan2(entry_point.z - top.z, entry_point.x - top.x)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := StaticBody3D.new()
	walls.name = "SummitWalls"
	add_child(walls)
	# The parapet ring: whitewashed with a sandstone cap, open toward the road.
	var radius := LandShape.PLATEAU_R - 0.6
	var pieces := 40
	for k in range(pieces):
		var angle := (k + 0.5) * TAU / pieces
		if absf(angle_difference(angle, entry)) < 0.44: continue
		var at := top + Vector3(cos(angle), 0, sin(angle)) * radius
		var yaw := -angle
		var length := 2.0 * radius * sin(PI / pieces) + 0.06
		_obox(st, at + Vector3(0, 0.36, 0), Vector3(0.34, 0.76, length), yaw, Color(0.94, 0.92, 0.86))
		_obox(st, at + Vector3(0, 0.79, 0), Vector3(0.46, 0.1, length + 0.02), yaw, Color(0.8, 0.6, 0.38))
		_solid(walls, at + Vector3(0, 0.6, 0), Vector3(0.4, 1.2, length), yaw)
	# The arch over the way in.
	var out := Vector3(cos(entry), 0, sin(entry))
	var across := Vector3(-out.z, 0, out.x)
	var arch_yaw := atan2(out.x, out.z)
	for sign in [-1.0, 1.0]:
		var foot: Vector3 = top + out * radius + across * sign * 3.9
		_obox(st, foot + Vector3(0, 2.0, 0), Vector3(0.6, 4.0, 0.6), arch_yaw, Color(0.82, 0.6, 0.36))
		_obox(st, foot + Vector3(0, 4.1, 0), Vector3(0.8, 0.2, 0.8), arch_yaw, Color(0.9, 0.74, 0.5))
		_solid(walls, foot + Vector3(0, 2.0, 0), Vector3(0.6, 4.0, 0.6), arch_yaw)
	var board_at := top + out * radius + Vector3(0, 4.0, 0)
	_obox(st, board_at, Vector3(8.4, 0.9, 0.22), arch_yaw, Color(0.72, 0.16, 0.1))
	for facing in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = "SAGAR POINT" if facing > 0.0 else "SAGAR POINT  -  21 m above the sea"
		label.font_size = 96 if facing > 0.0 else 56
		label.pixel_size = 0.006
		label.modulate = Color(1.0, 0.93, 0.62)
		label.outline_size = 10
		label.double_sided = false
		label.position = board_at + out * 0.13 * facing
		label.rotation.y = arch_yaw if facing > 0.0 else arch_yaw + PI
		add_child(label)
	# Coin binoculars on the sea side and lamp posts round the ring.
	for angle in [PI / 2.0 - 0.9, PI / 2.0 + 0.9, PI / 2.0 + 2.2]:
		var at: Vector3 = top + Vector3(cos(angle), 0, sin(angle)) * (radius - 0.9)
		var yaw: float = atan2(cos(angle), sin(angle))
		_obox(st, at + Vector3(0, 0.55, 0), Vector3(0.12, 1.1, 0.12), yaw, Color(0.2, 0.22, 0.25))
		_obox(st, at + Vector3(0, 1.22, 0), Vector3(0.38, 0.3, 0.5), yaw, Color(0.1, 0.36, 0.7))
		for eye in [-0.09, 0.09]:
			_obox(st, at + Vector3(0, 1.26, 0) + Vector3(cos(yaw), 0, -sin(yaw)) * eye - Vector3(sin(yaw), 0, cos(yaw)) * 0.3, Vector3(0.08, 0.08, 0.12), yaw, Color(0.08, 0.08, 0.1))
	for k in range(4):
		var angle := entry + PI / 4.0 + k * PI / 2.0
		var at := top + Vector3(cos(angle), 0, sin(angle)) * (radius - 0.5)
		_obox(st, at + Vector3(0, 1.6, 0), Vector3(0.12, 3.2, 0.12), 0.0, Color(0.16, 0.17, 0.19))
		_obox(st, at + Vector3(0, 3.35, 0), Vector3(0.36, 0.42, 0.36), 0.0, Color(0.16, 0.17, 0.19))
	var lamp_glass := SurfaceTool.new()
	lamp_glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(4):
		var angle := entry + PI / 4.0 + k * PI / 2.0
		var at := top + Vector3(cos(angle), 0, sin(angle)) * (radius - 0.5)
		IndianHouse.box(lamp_glass, at + Vector3(0, 3.33, 0), Vector3(0.3, 0.32, 0.3), Color(1.0, 0.86, 0.55))
	# The flag on the town side.
	var flag_at := top + Vector3(cos(-PI / 2.0 + 0.8), 0, sin(-PI / 2.0 + 0.8)) * 5.6
	_obox(st, flag_at + Vector3(0, 3.2, 0), Vector3(0.09, 6.4, 0.09), 0.0, Color(0.85, 0.85, 0.82))
	for stripe in range(3):
		_obox(st, flag_at + Vector3(0.82, 6.05 - stripe * 0.32, 0), Vector3(1.5, 0.32, 0.03), 0.0, [Color(1.0, 0.6, 0.2), Color(0.97, 0.97, 0.95), Color(0.07, 0.53, 0.03)][stripe])
	_obox(st, flag_at + Vector3(0.82, 5.73, 0), Vector3(0.2, 0.2, 0.05), 0.0, Color(0.0, 0.0, 0.5))
	var stonework := MeshInstance3D.new()
	stonework.name = "SummitStonework"
	stonework.mesh = st.commit()
	stonework.material_override = IndianHouse._material()
	add_child(stonework)
	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.82, 0.5)
	glow.emission_energy_multiplier = 1.6
	var lamps := MeshInstance3D.new()
	lamps.name = "SummitLamps"
	lamps.mesh = lamp_glass.commit()
	lamps.material_override = glow
	add_child(lamps)
	# The chhatri in the middle, its plinth just above the paving; posts are solid.
	var chhatri := (load("res://assets/props/sagar/chhatri.glb") as PackedScene).instantiate() as Node3D
	chhatri.name = "Chhatri"
	chhatri.position = top + Vector3(0, -0.24, 0)
	chhatri.rotation.y = arch_yaw
	add_child(chhatri)
	for corner in [Vector3(1.55, 0, 1.55), Vector3(-1.55, 0, 1.55), Vector3(1.55, 0, -1.55), Vector3(-1.55, 0, -1.55)]:
		_solid(walls, top + corner.rotated(Vector3.UP, arch_yaw) + Vector3(0, 1.5, 0), Vector3(0.34, 3.0, 0.34), arch_yaw)
	# Benches: three facing the open sea, two facing the town.
	var bench := 0
	for angle in [PI / 2.0 - 0.45, PI / 2.0, PI / 2.0 + 0.45, -PI / 2.0 - 0.35, -PI / 2.0 + 0.35]:
		var at: Vector3 = top + Vector3(cos(angle), 0, sin(angle)) * (radius - 1.6)
		Neighbourhood.street_prop("SagarBench%d" % bench, self, "bench", at, atan2(cos(angle), sin(angle)), Vector3(1.5, 0.9, 0.55))
		bench += 1

# ---------- the lighthouse and boats

func _lighthouse(data) -> void:
	var ground := 2.0
	if data != null:
		var height: float = data.get_height(Vector3(LandShape.LIGHTHOUSE.x, 0, LandShape.LIGHTHOUSE.y))
		if not is_nan(height): ground = height
	var tower := (load("res://assets/props/sagar/lighthouse.glb") as PackedScene).instantiate() as Node3D
	tower.name = "Lighthouse"
	tower.position = Vector3(LandShape.LIGHTHOUSE.x, ground - 0.5, LandShape.LIGHTHOUSE.y)
	add_child(tower)
	var body := StaticBody3D.new()
	body.name = "LighthouseBody"
	add_child(body)
	_solid(body, tower.position + Vector3(0, 4.0, 0), Vector3(3.6, 8.0, 3.6), 0.0)
	# Two beams sweeping round at night.
	beam = Node3D.new()
	beam.name = "LighthouseBeam"
	beam.position = tower.position + Vector3(0, 14.4, 0)
	add_child(beam)
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	light.cull_mode = BaseMaterial3D.CULL_DISABLED
	light.albedo_color = Color(1.0, 0.9, 0.6, 0.16)
	for sign in [-1.0, 1.0]:
		var cone := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.25
		mesh.bottom_radius = 3.2
		mesh.height = 46.0
		mesh.radial_segments = 12
		mesh.cap_top = false
		mesh.cap_bottom = false
		cone.mesh = mesh
		cone.material_override = light
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation.z = -PI / 2.0 * sign
		cone.position = Vector3(23.4 * sign, 0, 0)
		beam.add_child(cone)
	beam.visible = false

func _boats() -> void:
	for lane in BOATS:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		IndianHouse.box(st, Vector3(0, 0.05, 0), Vector3(1.0, 0.5, 4.0), Color(0.1, 0.1, 0.12))
		IndianHouse.box(st, Vector3(0, 0.45, 0), Vector3(1.5, 0.35, 4.4), lane[3])
		IndianHouse.box(st, Vector3(0, 0.55, 1.9), Vector3(0.9, 0.3, 1.0), lane[3])
		IndianHouse.box(st, Vector3(0, 0.62, 0), Vector3(1.4, 0.06, 4.2), Color(0.95, 0.9, 0.78))
		IndianHouse.box(st, Vector3(0, 0.95, -1.2), Vector3(1.0, 0.6, 1.1), Color(0.95, 0.93, 0.88))
		IndianHouse.box(st, Vector3(0, 3.1, 0.4), Vector3(0.1, 5.0, 0.1), Color(0.45, 0.32, 0.2))
		var sail := Color(0.97, 0.94, 0.86)
		for normal in [Vector3.RIGHT, Vector3.LEFT]:
			IndianHouse._quad(st, Vector3(0, 1.0, 0.45), Vector3(0, 5.4, 0.45), Vector3(0, 1.1, 2.6), Vector3(0, 1.0, 0.45), normal, sail)
			IndianHouse._quad(st, Vector3(0, 1.2, 0.35), Vector3(0, 4.8, 0.35), Vector3(0, 1.2, -1.9), Vector3(0, 1.2, 0.35), normal, sail)
		var boat := MeshInstance3D.new()
		boat.name = "FishingBoat%d" % boats.size()
		boat.mesh = st.commit()
		boat.material_override = IndianHouse._material()
		boat.position = Vector3(lane[2], LandShape.SEA_Y, lane[0])
		boat.rotation.y = PI / 2.0 if lane[1] > 0.0 else -PI / 2.0
		boat.rotation_order = EULER_ORDER_YXZ
		boat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(boat)
		boats.append(boat)

# ---------- Sagar Beach and the rocky shore

const BEACH_PROP := "res://assets/props/beach/%s.glb"
const ROCKS := ["rock_a", "rock_b", "rock_c"]
## Sea stacks off the peak: x, z, size.
const STACKS := [[18.0, 140.0, 3.0], [33.0, 151.0, 2.2], [-30.0, 160.0, 2.6], [-66.0, 146.0, 1.8]]
## Where the crabs roam: the wet and dry sand of Sagar Beach.
const CRAB_AREA := Rect2(-84.0, 103.0, 38.0, 14.0)

static func _prop_mesh(model: String) -> Mesh:
	var scene := (load(BEACH_PROP % model) as PackedScene).instantiate()
	var found: Mesh = null
	for child in scene.find_children("*", "MeshInstance3D", true, false):
		found = (child as MeshInstance3D).mesh
		break
	scene.free()
	return found

func _prop(model: String, at: Vector3, yaw: float, size: float) -> Node3D:
	var prop := (load(BEACH_PROP % model) as PackedScene).instantiate() as Node3D
	prop.position = at
	prop.rotation.y = yaw
	prop.scale = Vector3.ONE * size
	add_child(prop)
	return prop

static func _ground(data, x: float, z: float, fallback := 0.0) -> float:
	if data == null: return fallback
	var height: float = data.get_height(Vector3(x, 0, z))
	return fallback if is_nan(height) else height

## Rocks along the waterline all round the island (a few heaped at both ends of the
## beach, as tide pools), drawn as one MultiMesh per rock shape, and the sea stacks.
func _rocks(data) -> void:
	rng.seed = 808
	var placed := {}
	for model in ROCKS: placed[model] = []
	var sea := LandShape.SEA_Y
	for attempt in range(6000):
		var x := rng.randf_range(-126.0, 125.0)
		var z := rng.randf_range(float(LandShape.NORTH_EDGE) + 2.0, 125.0)
		var edge := minf(minf(x + 128.0, 127.0 - x), minf(z - LandShape.NORTH_EDGE, 127.0 - z))
		if edge > 13.0: continue
		if z > 95.0 and x > LandShape.BEACH.position.x + 5.0 and x < LandShape.BEACH.end.x - 5.0: continue
		var height := _ground(data, x, z, sea - 5.0)
		if height < sea - 1.8 or height > sea + 1.2: continue
		var size := rng.randf_range(0.5, 2.0) * (1.8 if rng.randf() < 0.12 else 1.0)
		placed[ROCKS[rng.randi() % 3]].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(x, height - 0.12 * size, z)))
	for end in [LandShape.BEACH.position.x + 3.0, LandShape.BEACH.end.x - 3.0]:
		for k in range(9):
			var x: float = end + rng.randf_range(-4.0, 4.0)
			var z := rng.randf_range(106.0, 119.0)
			var size := rng.randf_range(0.4, 1.5)
			placed[ROCKS[k % 3]].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(x, _ground(data, x, z, sea) - 0.15 * size, z)))
	for model in ROCKS:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _prop_mesh(model)
		multimesh.instance_count = placed[model].size()
		for index in range(placed[model].size()): multimesh.set_instance_transform(index, placed[model][index])
		var rocks := MultiMeshInstance3D.new()
		rocks.name = "ShoreRocks_" + model
		rocks.multimesh = multimesh
		add_child(rocks)
	for stack in STACKS:
		_prop("sea_stack", Vector3(stack[0], sea - 4.0, stack[1]), rng.randf() * TAU, stack[2]).name = "SeaStack"

## Sagar Beach: coconut palms along the back of the sand, beach umbrellas with mats,
## starfish on the wet sand and crabs that scuttle about (and run from the player).
func _beach(data) -> void:
	rng.seed = 909
	var beach := LandShape.BEACH
	var x := beach.position.x + 3.0
	while x < beach.end.x - 2.0:
		var z := rng.randf_range(97.0, 102.5)
		_prop("palm", Vector3(x, _ground(data, x, z, 1.0) - 0.1, z), rng.randf_range(-0.5, 0.5), rng.randf_range(0.85, 1.15)).name = "Palm"
		x += rng.randf_range(4.5, 6.5)
	var colours := [Color(0.86, 0.16, 0.14), Color(0.98, 0.76, 0.12), Color(0.12, 0.45, 0.82)]
	for k in range(3):
		var at := Vector3(-76.0 + k * 11.5, 0.0, 107.0 + (k % 2) * 2.0)
		at.y = _ground(data, at.x, at.z, 0.5)
		var umbrella := Node3D.new()
		umbrella.name = "BeachUmbrella%d" % k
		umbrella.position = at
		umbrella.rotation.y = rng.randf() * TAU
		add_child(umbrella)
		var paint := StandardMaterial3D.new()
		paint.albedo_color = colours[k]
		paint.roughness = 0.8
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.03
		pole_mesh.bottom_radius = 0.03
		pole_mesh.height = 2.5
		pole.mesh = pole_mesh
		pole.position.y = 1.1
		umbrella.add_child(pole)
		var canopy := MeshInstance3D.new()
		var canopy_mesh := CylinderMesh.new()
		canopy_mesh.top_radius = 0.04
		canopy_mesh.bottom_radius = 1.5
		canopy_mesh.height = 0.5
		canopy_mesh.radial_segments = 10
		canopy_mesh.cap_bottom = false
		canopy.mesh = canopy_mesh
		canopy.material_override = paint
		canopy.position.y = 2.25
		umbrella.add_child(canopy)
		var mat_mesh := MeshInstance3D.new()
		var towel := BoxMesh.new()
		towel.size = Vector3(0.9, 0.02, 1.8)
		mat_mesh.mesh = towel
		mat_mesh.material_override = paint
		mat_mesh.position = Vector3(0.9, 0.05, 0.3)
		umbrella.add_child(mat_mesh)
	for k in range(10):
		var at := Vector3(rng.randf_range(-84.0, -46.0), 0.0, rng.randf_range(112.0, 117.0))
		at.y = _ground(data, at.x, at.z, LandShape.SEA_Y)
		if at.y < LandShape.SEA_Y + 0.05 or at.y > LandShape.SEA_Y + 1.2: continue
		_prop("starfish", at + Vector3(0, 0.01, 0), rng.randf() * TAU, rng.randf_range(0.9, 1.4)).name = "Starfish"
	for k in range(9):
		var at := _crab_goal(Vector3(rng.randf_range(CRAB_AREA.position.x, CRAB_AREA.end.x), 0, rng.randf_range(CRAB_AREA.position.y, CRAB_AREA.end.y)), 0.5)
		var crab := _prop("crab", at, rng.randf() * TAU, rng.randf_range(1.0, 1.5))
		crab.name = "Crab%d" % k
		crabs.append(crab)
		crab_goals.append(at)
		crab_rest.append(rng.randf_range(0.0, 3.0))

## A spot on the sand above the water within `reach` of `from` (or `from` itself).
func _crab_goal(from: Vector3, reach := 3.0) -> Vector3:
	for attempt in range(8):
		var x := clampf(from.x + rng.randf_range(-reach, reach), CRAB_AREA.position.x, CRAB_AREA.end.x)
		var z := clampf(from.z + rng.randf_range(-reach, reach), CRAB_AREA.position.y, CRAB_AREA.end.y)
		var height := _ground(land_data, x, z, 0.5)
		if height > LandShape.SEA_Y + 0.12: return Vector3(x, height, z)
	return from

func _move_crabs(delta: float) -> void:
	if crabs.is_empty(): return
	var near_player := player != null and player.is_inside_tree()
	if near_player and player.global_position.distance_to(Vector3(CRAB_AREA.get_center().x, 0, CRAB_AREA.get_center().y)) > 90.0: return
	for index in range(crabs.size()):
		var crab := crabs[index]
		var running := false
		if near_player:
			var away := crab.position - player.global_position
			away.y = 0.0
			if away.length() < 3.5:
				running = true
				crab_rest[index] = 0.0
				crab_goals[index] = _crab_goal(crab.position + away.normalized() * 3.5, 0.6)
		if crab_rest[index] > 0.0:
			crab_rest[index] -= delta
			continue
		var to_goal := crab_goals[index] - crab.position
		to_goal.y = 0.0
		if to_goal.length() < 0.08:
			crab_rest[index] = rng.randf_range(0.6, 3.5)
			crab_goals[index] = _crab_goal(crab.position)
			continue
		var step := to_goal.normalized() * minf((2.6 if running else 0.7) * delta, to_goal.length())
		crab.position += step
		crab.position.y = _ground(land_data, crab.position.x, crab.position.z, crab.position.y) + 0.01
		# Crabs walk sideways: the body faces across the way it goes, with a little scuttle.
		crab.rotation.y = lerp_angle(crab.rotation.y, atan2(step.x, step.z) + PI / 2.0, minf(delta * 8.0, 1.0))
		crab.rotation.z = sin(Time.get_ticks_msec() * 0.03 + index) * 0.08
