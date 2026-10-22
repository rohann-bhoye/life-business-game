extends Node3D

var clouds: Array[Node3D] = []
var cloud_material: StandardMaterial3D
var detailed_ground: ShaderMaterial

const GRASS_SHADER := preload("res://assets/materials/grass_blades.gdshader")
const GRASS_CELL := 8.0
const GRASS_DENSITY := 9.0
const MASK_STEP := 0.25
## Grass grows over the whole open town (town_boundary.gd), masked in 0.25 m cells.
const Edge := preload("res://town_boundary.gd")
const MASK_WIDTH := int((Edge.MAX_X - Edge.MIN_X) / MASK_STEP)
const MASK_HEIGHT := int((Edge.MAX_Z - Edge.MIN_Z) / MASK_STEP)
## The lawn ground (and its collider) reaches into the hills all round, so the open
## town is solid everywhere and the lawn meets the hills along their foot.
const GROUND_SIZE := Vector3(150, 0.2, 176)
const GROUND_Z := 2.0
var grass_chunks: Array[MultiMeshInstance3D] = []
var grass_level := 3

func _ready() -> void:
	var grass := Node3D.new()
	grass.name = "WindGrass"
	add_child(grass)
	# Planted once the whole town (farm, warehouse, houses) exists, to keep off it.
	call_deferred("_build_grass")
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
				if mask[int((z - Edge.MIN_Z) / MASK_STEP) * MASK_WIDTH + int((x - Edge.MIN_X) / MASK_STEP)]: continue
				var size := rng.randf_range(0.8, 1.25)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.75, 1.35), size))
				transforms.append(Transform3D(basis, Vector3(x, 0.1, z)))
			if transforms.is_empty(): continue
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_custom_data = true
			multimesh.mesh = clump
			multimesh.instance_count = transforms.size()
			for index in range(transforms.size()):
				multimesh.set_instance_transform(index, transforms[index])
				multimesh.set_instance_custom_data(index, Color(rng.randf(), 0, 0, 0))
			var chunk := MultiMeshInstance3D.new()
			chunk.name = "GrassChunk%d_%d" % [cell_x, cell_z]
			chunk.multimesh = multimesh
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk.visibility_range_end = 38.0
			chunk.visibility_range_end_margin = 4.0
			holder.add_child(chunk)
			grass_chunks.append(chunk)
	_apply_grass_quality()

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
		if box.position.y < 0.6: _mark(mask, box, 0.1)
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		if mesh == ground or not (mesh.mesh is BoxMesh or mesh.mesh is PlaneMesh): continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if box.position.y < 0.35 and box.end.y < 0.45 and box.size.x * box.size.z > 0.2: _mark(mask, box, 0.05)
	# Merged block paths (block_path.gd) mark themselves.
	for path in get_tree().get_nodes_in_group("no_grass"):
		_mark(mask, path.global_transform * path.get_aabb(), 0.05)
	return mask

func _mark(mask: PackedByteArray, box: AABB, margin: float) -> void:
	if box.end.x < Edge.MIN_X or box.position.x > Edge.MAX_X or box.end.z < Edge.MIN_Z or box.position.z > Edge.MAX_Z: return
	var first_x := clampi(int((box.position.x - margin - Edge.MIN_X) / MASK_STEP), 0, MASK_WIDTH - 1)
	var last_x := clampi(int((box.end.x + margin - Edge.MIN_X) / MASK_STEP), 0, MASK_WIDTH - 1)
	var first_z := clampi(int((box.position.z - margin - Edge.MIN_Z) / MASK_STEP), 0, MASK_HEIGHT - 1)
	var last_z := clampi(int((box.end.z + margin - Edge.MIN_Z) / MASK_STEP), 0, MASK_HEIGHT - 1)
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
	for chunk in grass_chunks:
		var count := chunk.multimesh.instance_count
		chunk.multimesh.visible_instance_count = -1 if grass_level >= 3 else count / (2 if grass_level == 2 else 4)
		chunk.visibility_range_end = [24.0, 24.0, 38.0, 45.0][grass_level]

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
