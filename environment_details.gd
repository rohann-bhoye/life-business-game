extends Node3D

var clouds: Array[Node3D] = []
var cloud_material: StandardMaterial3D
## Clouds drift east over the whole sky and wrap round past x +-CLOUD_REACH.
const CLOUD_REACH := 160.0
var cloud_speeds: Array[float] = []
var detailed_ground: ShaderMaterial

const GRASS_SHADER := preload("res://assets/materials/grass_blades.gdshader")
const GRASS_CELL := 8.0
const GRASS_DENSITY := 9.0
const MASK_STEP := 0.25
## Grass grows over the whole open town (town_boundary.gd), masked in 0.25 m cells.
const Edge := preload("res://town_boundary.gd")
## The mask covers the whole land (hills and North Road too), so the wild grass keeps off roads there.
const MASK_MIN_X := Edge.LAND_MIN_X
const MASK_MIN_Z := Edge.LAND_MIN_Z
const MASK_WIDTH := int((Edge.LAND_MAX_X - Edge.LAND_MIN_X) / MASK_STEP)
const MASK_HEIGHT := int((Edge.LAND_MAX_Z - Edge.LAND_MIN_Z) / MASK_STEP)
## The lawn ground (and its collider) reaches into the hills all round, so the open
## town is solid everywhere and the lawn meets the hills along their foot.
const GROUND_SIZE := Vector3(150, 0.2, 176)
const GROUND_Z := 2.0
var grass_chunks: Array[MultiMeshInstance3D] = []
var grass_level := 3
## Wild grass on the hills, mountains and meadows round the player (outside the town
## and the North Road lane, which have their own): 8 m squares up to WILD_REACH
## squares away, standing on the Landscape, built as the player walks and dropped
## behind them; none on the river banks, bare rock, snow or cliffs.
const WILD_REACH := 2
const WILD_DENSITY := 0.6
var wild_chunks := {}
var wild_cell := Vector2i(1 << 20, 1 << 20)
var wild_clump: ArrayMesh
## 1 where grass must not grow (roads, paving, objects), over the whole land; see _grass_mask.
var grass_mask := PackedByteArray()
var wild_land: Node
var wild_player: Node3D

func _ready() -> void:
	var grass := Node3D.new()
	grass.name = "WindGrass"
	add_child(grass)
	# Planted once the whole town (farm, warehouse, houses) exists, to keep off it.
	call_deferred("_build_grass")
	# Draw distances once everything (the grass too) is built: draw_distance.gd.
	call_deferred("_limit_draw_distance")
	_build_clouds()
	_build_ground()
	_build_water()
	var business = get_tree().current_scene.get_node("Shop/ShopArea").business
	business.clock_changed.connect(_update_clouds)
	_update_clouds()

func _limit_draw_distance() -> void:
	for frame in range(2): await get_tree().process_frame
	if is_inside_tree(): preload("res://draw_distance.gd").apply(get_tree().current_scene)

func _process(delta: float) -> void:
	for index in range(clouds.size()):
		var cloud := clouds[index]
		cloud.position.x += delta * cloud_speeds[index]
		if cloud.position.x > CLOUD_REACH: cloud.position.x = -CLOUD_REACH

## Dense lawn on every open patch of the town: clumps of thin curved blades, kept off
## anything solid or flat on the ground (roads, paths, floors, soil, buildings, found
## from the scene), in 8 m chunks that only draw near the camera.
func _build_grass() -> void:
	# The farm joins the scene deferred too; one frame later everything is in place.
	await get_tree().process_frame
	if not is_inside_tree(): return
	var mask := _grass_mask()
	var clump := _grass_clump()
	var rng := RandomNumberGenerator.new()
	rng.seed = 481516
	var holder := get_node("WindGrass")
	for cell_x in range(floori(Edge.MIN_X / GRASS_CELL), ceili(Edge.MAX_X / GRASS_CELL)):
		for cell_z in range(floori(Edge.MIN_Z / GRASS_CELL), ceili(Edge.MAX_Z / GRASS_CELL)):
			var transforms: Array[Transform3D] = []
			for index in range(int(GRASS_CELL * GRASS_CELL * GRASS_DENSITY)):
				var x := (cell_x + rng.randf()) * GRASS_CELL
				var z := (cell_z + rng.randf()) * GRASS_CELL
				if x < Edge.MIN_X + 0.3 or x > Edge.MAX_X - 0.3 or z < Edge.MIN_Z + 0.3 or z > Edge.MAX_Z - 0.3: continue
				if _masked(mask, x, z): continue
				if _on_turning_circle(x, z): continue
				var size := rng.randf_range(0.8, 1.25)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.75, 1.35), size))
				transforms.append(Transform3D(basis, Vector3(x, 0.1, z)))
			_grass_chunk("GrassChunk%d_%d" % [cell_x, cell_z], transforms, clump, rng, holder)
	_road_grass(clump, rng, holder)
	_apply_grass_quality()
	grass_mask = mask
	wild_clump = clump
	wild_player = get_tree().current_scene.get_node_or_null("Player")
	var land = get_tree().current_scene.get_node_or_null("Landscape")
	if land != null and land.get_class() == "Terrain3D": wild_land = land

func _physics_process(_delta: float) -> void:
	if wild_clump == null or wild_land == null or not is_instance_valid(wild_player): return
	var cell := Vector2i(floori(wild_player.global_position.x / GRASS_CELL), floori(wild_player.global_position.z / GRASS_CELL))
	if cell == wild_cell: return
	wild_cell = cell
	for key in wild_chunks.keys():
		if maxi(absi(key.x - cell.x), absi(key.y - cell.y)) <= WILD_REACH + 1: continue
		var old = wild_chunks[key]
		if old != null:
			grass_chunks.erase(old)
			old.queue_free()
		wild_chunks.erase(key)
	for dx in range(-WILD_REACH, WILD_REACH + 1):
		for dz in range(-WILD_REACH, WILD_REACH + 1):
			var key := cell + Vector2i(dx, dz)
			if not wild_chunks.has(key): wild_chunks[key] = _wild_chunk(key)

## Is this ground one of the paved turning circles at the road ends (town_plan.gd)?
func _on_turning_circle(x: float, z: float) -> bool:
	for turn in preload("res://town_plan.gd").TURNS:
		if Vector2(x - turn[0].x, z - turn[0].z).length() < preload("res://town_plan.gd").TURN_RADIUS: return true
	return false

func _wild_chunk(key: Vector2i) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var data = wild_land.data
	var transforms: Array[Transform3D] = []
	for index in range(int(GRASS_CELL * GRASS_CELL * GRASS_DENSITY * WILD_DENSITY)):
		var x := (key.x + rng.randf()) * GRASS_CELL
		var z := (key.y + rng.randf()) * GRASS_CELL
		var size := rng.randf_range(0.8, 1.25)
		var turn := rng.randf() * TAU
		if x > Edge.MIN_X and x < Edge.MAX_X and z > Edge.MIN_Z and z < Edge.MAX_Z: continue
		if x > Edge.ROAD_MIN_X and x < Edge.ROAD_MAX_X and z > Edge.ROAD_END_Z and z < Edge.MIN_Z: continue
		if _masked(grass_mask, x, z): continue
		if _on_turning_circle(x, z): continue
		var y: float = data.get_height(Vector3(x, 0, z))
		if is_nan(y) or y < -1.8 or y > 30.0: continue
		var steepness: float = absf(data.get_height(Vector3(x + 1.0, 0, z)) - y) + absf(data.get_height(Vector3(x, 0, z + 1.0)) - y)
		if steepness > 1.6: continue
		transforms.append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3(size, size * rng.randf_range(0.75, 1.35), size)), Vector3(x, y, z)))
	if transforms.is_empty(): return null
	var before := grass_chunks.size()
	_grass_chunk("WildGrass%d_%d" % [key.x, key.y], transforms, wild_clump, rng, get_node("WindGrass"))
	var chunk := grass_chunks[before]
	_grass_quality(chunk)
	return chunk

## Grass along the North Road lane through the hills (town_boundary.gd), standing on
## the Landscape: not on the road itself, the river banks or under the bridge.
func _road_grass(clump: ArrayMesh, rng: RandomNumberGenerator, holder: Node) -> void:
	var land = get_tree().current_scene.get_node_or_null("Landscape")
	if land == null or land.get_class() != "Terrain3D": return
	var road_x: float = preload("res://land_shape.gd").NORTH_ROAD_X
	for cell_x in range(floori(Edge.ROAD_MIN_X / GRASS_CELL), ceili(Edge.ROAD_MAX_X / GRASS_CELL)):
		for cell_z in range(floori(Edge.ROAD_END_Z / GRASS_CELL), ceili(Edge.MIN_Z / GRASS_CELL)):
			var transforms: Array[Transform3D] = []
			for index in range(int(GRASS_CELL * GRASS_CELL * GRASS_DENSITY)):
				var x := (cell_x + rng.randf()) * GRASS_CELL
				var z := (cell_z + rng.randf()) * GRASS_CELL
				if x < Edge.ROAD_MIN_X or x > Edge.ROAD_MAX_X or z < Edge.ROAD_END_Z or z > Edge.MIN_Z or absf(x - road_x) < 3.6: continue
				var y: float = land.data.get_height(Vector3(x, 0, z))
				if is_nan(y) or y < -0.6: continue
				var size := rng.randf_range(0.8, 1.25)
				transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.75, 1.35), size)), Vector3(x, y, z)))
			_grass_chunk("RoadGrass%d_%d" % [cell_x, cell_z], transforms, clump, rng, holder)

func _grass_chunk(chunk_name: String, transforms: Array[Transform3D], clump: ArrayMesh, rng: RandomNumberGenerator, holder: Node) -> void:
	if transforms.is_empty(): return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = clump
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_custom_data(index, Color(rng.randf(), 0, 0, 0))
	var chunk := MultiMeshInstance3D.new()
	chunk.name = chunk_name
	chunk.multimesh = multimesh
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.visibility_range_end = 38.0
	chunk.visibility_range_end_margin = 4.0
	holder.add_child(chunk)
	grass_chunks.append(chunk)

## One clump: six thin blades of different heights, each a tapered two-part blade
## leaning outwards. UV.y runs from root (0) to tip (1) for colour and wind.
func _grass_clump() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for blade in range(6):
		var angle := rng.randf() * TAU
		var outward := Vector3(cos(angle), 0, sin(angle))
		var root := outward * rng.randf_range(0.0, 0.07)
		var height := rng.randf_range(0.13, 0.3)
		var facing := rng.randf() * TAU
		var side := Vector3(cos(facing), 0, sin(facing)) * rng.randf_range(0.011, 0.017)
		var lean := outward * rng.randf_range(0.02, 0.1)
		var middle := root + Vector3(0, height * 0.55, 0) + lean * 0.3
		var tip := root + Vector3(0, height, 0) + lean
		for point in [[root - side, 0.0], [root + side, 0.0], [middle + side * 0.6, 0.55], [root - side, 0.0], [middle + side * 0.6, 0.55], [middle - side * 0.6, 0.55], [middle - side * 0.6, 0.55], [middle + side * 0.6, 0.55], [tip, 1.0]]:
			st.set_uv(Vector2(0, point[1]))
			st.add_vertex(point[0])
	var mesh := st.commit()
	var material := ShaderMaterial.new()
	material.shader = GRASS_SHADER
	mesh.surface_set_material(0, material)
	return mesh

## 0.25 m cells over the open town: 1 where grass must not grow.
func _grass_mask() -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(MASK_WIDTH * MASK_HEIGHT)
	var world := get_tree().current_scene
	var ground := world.get_node("MeshInstance3D")
	# Visibility is ignored on purpose: Low Fast hides the pond, but grass must stay
	# out of it when the player switches to a higher setting later.
	for shape in world.find_children("*", "CollisionShape3D", true, false):
		if not shape.shape is BoxShape3D or shape.disabled: continue
		var body := shape.get_parent()
		if body.name == "Ground" or body is CharacterBody3D: continue
		var box: AABB = shape.global_transform * AABB(-shape.shape.size / 2.0, shape.shape.size)
		# (Very long boxes are land shapes, not objects: they would blank out whole hills.)
		if box.position.y < 0.6 and box.size.x < 80.0 and box.size.z < 80.0: _mark(mask, box, 0.1)
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		if mesh == ground or mesh.mesh == null: continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if mesh.mesh is BoxMesh or mesh.mesh is PlaneMesh:
			if box.position.y < 0.35 and box.end.y < 0.45 and box.size.x * box.size.z > 0.2 and box.size.x < 80.0 and box.size.z < 80.0: _mark(mask, box, 0.05)
		elif mesh.mesh is ArrayMesh and box.position.y < 0.35 and box.end.y < 0.45 and box.size.x * box.size.z > 0.2:
			# Flat merged meshes (the colony's pads, driveways, kerbs...): every triangle counts,
			# not the huge box round the whole mesh.
			_mark_triangles(mask, mesh)
	# Merged block paths (block_path.gd) mark themselves.
	for path in get_tree().get_nodes_in_group("no_grass"):
		_mark(mask, path.global_transform * path.get_aabb(), 0.05)
	return mask

## True when grass must not grow at this spot.
func _masked(mask: PackedByteArray, x: float, z: float) -> bool:
	if mask.is_empty(): return false
	var cx := int((x - MASK_MIN_X) / MASK_STEP)
	var cz := int((z - MASK_MIN_Z) / MASK_STEP)
	if cx < 0 or cz < 0 or cx >= MASK_WIDTH or cz >= MASK_HEIGHT: return false
	return mask[cz * MASK_WIDTH + cx] == 1

## Marks the cells under every triangle of a flat mesh (plus 0.1 m round the edges).
func _mark_triangles(mask: PackedByteArray, node: MeshInstance3D) -> void:
	var xform := node.global_transform
	var array_mesh := node.mesh as ArrayMesh
	for surface in range(array_mesh.get_surface_count()):
		var arrays := array_mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for at in range(0, count - 2, 3):
			var corners: Array[Vector2] = []
			for corner in range(3):
				var vertex := vertices[indices[at + corner] if not indices.is_empty() else at + corner]
				var world := xform * vertex
				corners.append(Vector2(world.x, world.z))
			_mark_triangle(mask, corners[0], corners[1], corners[2], 0.1)

func _mark_triangle(mask: PackedByteArray, a: Vector2, b: Vector2, c: Vector2, margin: float) -> void:
	var low := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y))) - Vector2(margin, margin)
	var high := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y))) + Vector2(margin, margin)
	if high.x < MASK_MIN_X or low.x > Edge.LAND_MAX_X or high.y < MASK_MIN_Z or low.y > Edge.LAND_MAX_Z: return
	var first_x := clampi(int((low.x - MASK_MIN_X) / MASK_STEP), 0, MASK_WIDTH - 1)
	var last_x := clampi(int((high.x - MASK_MIN_X) / MASK_STEP), 0, MASK_WIDTH - 1)
	var first_z := clampi(int((low.y - MASK_MIN_Z) / MASK_STEP), 0, MASK_HEIGHT - 1)
	var last_z := clampi(int((high.y - MASK_MIN_Z) / MASK_STEP), 0, MASK_HEIGHT - 1)
	for z in range(first_z, last_z + 1):
		for x in range(first_x, last_x + 1):
			var p := Vector2(MASK_MIN_X + (x + 0.5) * MASK_STEP, MASK_MIN_Z + (z + 0.5) * MASK_STEP)
			var d1 := _edge_distance(p, a, b)
			var d2 := _edge_distance(p, b, c)
			var d3 := _edge_distance(p, c, a)
			var outside_negative := d1 < -margin or d2 < -margin or d3 < -margin
			var outside_positive := d1 > margin or d2 > margin or d3 > margin
			if not (outside_negative and outside_positive): mask[z * MASK_WIDTH + x] = 1

## Signed distance from point p to the line a-b (0 for a degenerate edge).
func _edge_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var edge := b - a
	var length := edge.length()
	return 0.0 if length < 0.0001 else edge.cross(p - a) / length

func _mark(mask: PackedByteArray, box: AABB, margin: float) -> void:
	if box.end.x < MASK_MIN_X or box.position.x > Edge.LAND_MAX_X or box.end.z < MASK_MIN_Z or box.position.z > Edge.LAND_MAX_Z: return
	var first_x := clampi(int((box.position.x - margin - MASK_MIN_X) / MASK_STEP), 0, MASK_WIDTH - 1)
	var last_x := clampi(int((box.end.x + margin - MASK_MIN_X) / MASK_STEP), 0, MASK_WIDTH - 1)
	var first_z := clampi(int((box.position.z - margin - MASK_MIN_Z) / MASK_STEP), 0, MASK_HEIGHT - 1)
	var last_z := clampi(int((box.end.z + margin - MASK_MIN_Z) / MASK_STEP), 0, MASK_HEIGHT - 1)
	for z in range(first_z, last_z + 1):
		for x in range(first_x, last_x + 1):
			mask[z * MASK_WIDTH + x] = 1

## Settings > Grass: 0 off, 1 light (a quarter of the blades, close by), 2 medium
## (half), 3 full (every blade, drawn further out).
func set_grass(level: int) -> void:
	grass_level = level
	_apply_grass_quality()

func _apply_grass_quality() -> void:
	get_node("WindGrass").visible = grass_level > 0
	for chunk in grass_chunks: _grass_quality(chunk)

func _grass_quality(chunk: MultiMeshInstance3D) -> void:
	var count := chunk.multimesh.instance_count
	chunk.multimesh.visible_instance_count = -1 if grass_level >= 3 else count / (2 if grass_level == 2 else 4)
	chunk.visibility_range_end = [24.0, 24.0, 38.0, 45.0][grass_level]

## About 36 clouds spread over the whole sky (x and z +-150, 28-48 m up), kept apart
## from each other: small, medium and big ones, each one merged mesh (one of five
## puff shapes) with white tops and soft grey-blue undersides.
func _build_clouds() -> void:
	cloud_material = StandardMaterial3D.new()
	cloud_material.albedo_color = Color(0.92, 0.95, 0.97)
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_material.vertex_color_use_as_albedo = true
	var shapes: Array[ArrayMesh] = []
	for shape in range(5): shapes.append(_cloud_mesh(shape))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var spots: Array[Vector2] = []
	for attempt in range(400):
		var spot := Vector2(rng.randf_range(-150.0, 150.0), rng.randf_range(-150.0, 150.0))
		if spots.any(func(other: Vector2) -> bool: return other.distance_to(spot) < 34.0): continue
		spots.append(spot)
		if spots.size() >= 36: break
	for index in range(spots.size()):
		var size: float = [rng.randf_range(0.7, 1.0), rng.randf_range(1.3, 1.8), rng.randf_range(2.1, 2.8)][index % 3]
		var cloud := MeshInstance3D.new()
		cloud.name = "Cloud%d" % index
		cloud.mesh = shapes[index % shapes.size()]
		cloud.material_override = cloud_material
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.position = Vector3(spots[index].x, rng.randf_range(28.0, 48.0), spots[index].y)
		cloud.rotation.y = rng.randf_range(-0.4, 0.4)
		cloud.scale = Vector3(size, size * rng.randf_range(0.55, 0.75), size)
		add_child(cloud)
		clouds.append(cloud)
		cloud_speeds.append(rng.randf_range(0.3, 0.55))

## One cloud: 7-10 low-poly puffs along an ellipse, bigger in the middle, with flat
## bottoms; vertex colours go from a grey-blue underside to a white top.
static func _cloud_mesh(shape: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + shape
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 10
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var puffs := rng.randi_range(7, 10)
	for puff in range(puffs):
		var along := (puff / float(puffs - 1)) * 2.0 - 1.0
		var radius := lerpf(2.6, 1.3, absf(along)) * rng.randf_range(0.8, 1.15)
		var centre := Vector3(along * 5.0, rng.randf_range(0.0, 1.0) * (1.0 - absf(along)) * 1.4, rng.randf_range(-1.6, 1.6))
		for index in indices:
			var point := vertices[index] * radius * 2.0
			point.y = maxf(point.y, -radius * 0.35)
			var normal := normals[index]
			var height := (centre.y + point.y) / 3.5
			st.set_color(Color(0.74, 0.79, 0.87).lerp(Color.WHITE, smoothstep(-0.4, 0.7, normal.y * 0.6 + height)))
			st.set_normal(normal)
			st.add_vertex(centre + point)
	return st.commit()

func _update_clouds() -> void:
	var business = get_tree().current_scene.get_node("Shop/ShopArea").business
	var elevation: float = sin((business.minutes_of_day / 60.0 - 6.0) / 24.0 * TAU)
	var daylight := smoothstep(-0.15, 0.35, elevation)
	cloud_material.albedo_color = Color(0.1, 0.14, 0.22).lerp(Color(0.92, 0.95, 0.97), daylight)

func _build_ground() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/grass_ground.gdshader")
	detailed_ground = material
	var scene := get_tree().current_scene
	var ground_mesh: MeshInstance3D = scene.get_node("MeshInstance3D")
	ground_mesh.material_override = material
	if ground_mesh.mesh is BoxMesh: ground_mesh.mesh.size = GROUND_SIZE
	ground_mesh.position.z = GROUND_Z
	var body := scene.get_node_or_null("Ground") as Node3D
	if body != null:
		body.position.z = GROUND_Z
		var shape := body.get_node("CollisionShape3D") as CollisionShape3D
		if shape.shape is BoxShape3D: shape.shape.size = GROUND_SIZE

## Effects tier from the graphics preset (0 Low, 1 Normal, 2 High); the grass has
## its own setting (set_grass).
func set_quality(quality: int) -> void:
	# Low Fast keeps the lawn shader but skips its fine grain and bump.
	detailed_ground.set_shader_parameter("fine_detail", quality > 0)
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
