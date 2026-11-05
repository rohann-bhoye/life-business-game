extends Node3D

# One floor of Gufa Darwaza, built from its grid map (dungeon_layouts.gd) with the
# floor's Blender kit (tools/blender/build_dungeon_kit.py): every kit piece drawn as
# one MultiMesh in the anime look (toon.gdshader, outlines on rocks and props, the
# glowing caps and jars unshaded), torches, fireflies, the stream, and colliders (one
# floor slab, rock runs, the stream, boulders, the chest). Treasure jars and the chest
# are picked up with E (interact); the entry stone and the stairs are reported to
# dungeon_world.gd through the metas entry, exit, facing and stairs.
const Layouts := preload("res://dungeon_layouts.gd")
const CELL := 4.0
const WALL_DIRECTIONS := [[Vector2i(0, -1), 0.0], [Vector2i(1, 0), -PI / 2.0], [Vector2i(0, 1), PI], [Vector2i(-1, 0), PI / 2.0]]
const CAP_TINTS := [Color(1, 1, 1), Color(0.35, 0.85, 1.6), Color(1.6, 0.55, 1.3)]
const REACH := 2.2
## What each floor's kit calls its pieces and how they are drawn: walls (piece, weight),
## the lamp wall, ceiling ("" = open to the sky), water, loot, the rock collider height,
## pieces drawn without outlines (plain) and unshaded (glow).
## Floor 2 is Surya Nagri (tools/blender/build_surya_nagri.py): a canyon city open to a
## hazy sky, lit by its own sun (_surya_air), with the turning Surya Chakra in the plaza.
const STYLES := [
	{"walls": [["wall_moss", 0.35], ["wall", 0.65]], "lamp_wall": "wall_torch", "ceiling": "ceiling", "water": "stream", "court": "floor",
		"loot": ["jar", "jar_glow"], "loot_name": "firefly jar", "rock_height": 8.0,
		"plain": ["floor", "ceiling", "wall", "wall_moss", "wall_torch", "stream"], "glow": ["mushroom_cap"]},
	{"walls": [["cliff", 0.55], ["cliff_vines", 0.25], ["cliff_carved", 0.2]], "lamp_wall": "cliff_lamp", "ceiling": "", "water": "channel", "court": "court",
		"loot": ["gem", "gem_glow"], "loot_name": "Surya gem", "rock_height": 10.0, "realistic": true,
		"plain": ["floor", "court", "garden", "tuft", "cliff", "cliff_vines", "cliff_carved", "cliff_lamp", "facade", "corner", "channel", "palm_leaves", "flag"], "glow": ["lantern_glow"]},
]
## Surya Nagri is realistic (owner, 2026-11-05): every kit piece keeps its colour and gets a
## scanned CC0 texture set over it (real_detail.gdshader): [set, repeats per metre, strength].
## The sets are Poly Haven 1k textures in assets/props/dungeon/floor2/scans/textures.
const REAL := {
	"floor": ["red_sandstone_pavement", 0.42, 1.0], "court": ["red_sandstone_pavement", 0.42, 1.0], "garden": ["mossy_sandstone", 0.5, 0.9],
	"cliff": ["sandstone_cracks", 0.11, 1.0], "cliff_lamp": ["sandstone_cracks", 0.11, 1.0], "corner": ["sandstone_cracks", 0.11, 1.0],
	"cliff_vines": ["mossy_sandstone", 0.14, 1.0], "cliff_carved": ["rabdentse_ruins_wall", 0.22, 1.0], "facade": ["rabdentse_ruins_wall", 0.22, 1.0],
	"pillar": ["large_sandstone_blocks", 0.45, 0.9], "pillar_broken": ["large_sandstone_blocks", 0.45, 0.9], "chakra_stand": ["large_sandstone_blocks", 0.45, 0.9],
	"channel": ["large_sandstone_blocks", 0.45, 0.9], "bridge": ["large_sandstone_blocks", 0.45, 0.9], "lantern": ["large_sandstone_blocks", 0.6, 0.8],
	"stairs": ["large_sandstone_blocks", 0.45, 0.9], "entry_stone": ["sandstone_cracks", 0.6, 0.8], "elephant": ["sandstone_cracks", 0.6, 0.8],
	"rubble": ["sandstone_cracks", 0.6, 1.0], "ore_rock": ["sandstone_cracks", 0.6, 1.0], "gem": ["sandstone_cracks", 1.0, 0.3],
	"chakra": ["sandstone_cracks", 0.8, 0.3], "palm_trunk": ["sandstone_cracks", 1.2, 0.7], "palm_leaves": ["mossy_sandstone", 1.0, 0.35],
	"flag": ["mossy_sandstone", 1.0, 0.2], "tuft": ["mossy_sandstone", 1.0, 0.3],
}
const SCANS := "res://assets/props/dungeon/floor2/scans/"

var grid: Array = []
var kit := ""
var floor_id := 0
var style: Dictionary = STYLES[0]
## Surya Nagri: the turning wheel, lantern lights, light shafts and drifting mist.
var chakra: Node3D
var lanterns: Array[OmniLight3D] = []
var shafts: Array[MeshInstance3D] = []
var mists: Array[MeshInstance3D] = []
var sun: DirectionalLight3D
## Light versions (Low preset): fewer scanned rocks and plants.
var low := true
## Wall edges of a realistic floor ([point on the wall, yaw facing into the cell, side]),
## dressed with scanned cliffs after the grid is built (_dress).
var edges: Array = []
var real_materials := {}
var scan_scenes := {}

## In the scene now: the sun casts the cliffs' shadows on every preset (they are what makes
## the rock read as solid). Low uses one cheap short-range pass, the others two splits.
func _ready() -> void:
	if not is_instance_valid(sun): return
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if low else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 55.0 if low else 90.0
var meshes := {}
var toon: ShaderMaterial
var toon_outlined: ShaderMaterial
var glow: StandardMaterial3D
var loot: Array[Node3D] = []
var chest_lid: Node3D
var chest_open := false
var chest_spot := Vector3.ZERO
var stairs_spot := Vector3.ZERO
var spawns: Array[Vector3] = []
var boss_spot := Vector3.ZERO
var lid_turn := 0.0
var ores: Array[Node3D] = []
var torches: Array[OmniLight3D] = []
## Diary stands (dungeon_books.gd), each with meta "page" (0-3).
var books: Array[Node3D] = []

static func create(index: int, origin: Vector3, light_version := true) -> Node3D:
	var floor := preload("res://dungeon_floor.gd").new()
	floor.name = "DungeonFloor"
	floor.position = origin
	floor.low = light_version
	floor._build(index)
	return floor

func _build(floor_index: int) -> void:
	floor_id = floor_index
	style = STYLES[clampi(floor_id, 0, STYLES.size() - 1)]
	grid = Layouts.rows(floor_id)
	kit = "res://assets/props/dungeon/floor%d/" % (floor_id + 1)
	var atlas: Texture2D = load(kit + "floor%d_print.png" % (floor_id + 1))
	toon = _toon(atlas, false)
	toon_outlined = _toon(atlas, true)
	glow = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_texture = atlas
	glow.vertex_color_use_as_albedo = true
	var pieces := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + floor_id
	var water := SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	water.set_normal(Vector3.UP)
	var fireflies: Array[Vector3] = []
	for row in range(grid.size()):
		for col in range(grid[row].length()):
			var tag := _tag(col, row)
			if tag == "#": continue
			var at := _centre(col, row)
			if style.ceiling != "": _add(pieces, style.ceiling, Transform3D(Basis(), at))
			if tag in ["w", "p"]:
				_add(pieces, style.water, Transform3D(Basis(), at))
				for corner in [Vector3(-2, -0.35, -2), Vector3(2, -0.35, -2), Vector3(2, -0.35, 2), Vector3(-2, -0.35, -2), Vector3(2, -0.35, 2), Vector3(-2, -0.35, 2)]: water.add_vertex(at + corner)
				if tag == "p": _add(pieces, "bridge", Transform3D(Basis(), at))
				else: _solid(Vector3(CELL, 1.6, CELL), at + Vector3(0, 0.4, 0))
			else:
				var ground := "floor"
				if tag in ["B", "b", "C", "X"]: ground = style.court
				elif tag in [",", "W"] and floor_id == 1: ground = "garden"
				_add(pieces, ground, Transform3D(Basis(Vector3.UP, (rng.randi() % 4) * PI / 2.0), at))
				if tag == "." and rng.randf() < (0.08 if floor_id == 1 else 0.14):
					_add(pieces, "rubble", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.5, 0.9)), at + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))))
				# Grass pushing up between the old flagstones.
				if floor_id == 1 and ground == "floor" and not style.has("realistic"):
					for count in range(rng.randi_range(1, 4)):
						_add(pieces, "tuft", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), at + Vector3(rng.randf_range(-1.8, 1.8), 0, rng.randf_range(-1.8, 1.8))))
			var lamp_placed := false
			for direction in WALL_DIRECTIONS:
				var side: Vector2i = direction[0]
				if _tag(col + side.x, row + side.y) != "#": continue
				var kind := _wall_kind(rng)
				if tag == "T" and not lamp_placed:
					kind = style.lamp_wall
					lamp_placed = true
					_torch(at + Vector3(side.x, 0, side.y) * 1.25 + Vector3(0, 3.2, 0))
					if style.has("realistic"): _scan("brass_diya_lantern", at + Vector3(side.x, 0, side.y) * 1.3 + Vector3(0, 1.75, 0), 0.0, 4.0)
				elif tag == "F" and not lamp_placed:
					kind = "facade"
					lamp_placed = true
				_add(pieces, kind, Transform3D(Basis(Vector3.UP, direction[1]), at))
				if style.has("realistic") and kind != "facade": edges.append([at + Vector3(side.x, 0, side.y) * 2.0, direction[1], Vector3(side.x, 0, side.y), Vector2i(col, row), side])
			match tag:
				"P":
					_add(pieces, "pillar", Transform3D(Basis(Vector3.UP, (rng.randi() % 4) * PI / 2.0), at))
					_solid(Vector3(1.3, 7.0, 1.3), at + Vector3(0, 3.5, 0))
					# Every other pillar flies a saffron temple flag.
					if (col + row) % 2 == 0: _add(pieces, "flag", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0.75, 0, 0.75)))
				"q":
					_add(pieces, "pillar_broken", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at))
					_solid(Vector3(1.3, 3.0, 1.3), at + Vector3(0, 1.5, 0))
				"y":
					var palm := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.25)), at + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)))
					_add(pieces, "palm_trunk", palm)
					_add(pieces, "palm_leaves", palm)
					_solid(Vector3(0.6, 3.0, 0.6), palm.origin + Vector3(0, 1.5, 0))
				"l":
					_add(pieces, "lantern", Transform3D(Basis(), at))
					_add(pieces, "lantern_glow", Transform3D(Basis(), at))
					_solid(Vector3(0.7, 2.6, 0.7), at + Vector3(0, 1.3, 0))
					_lantern(at + Vector3(0, 2.9, 0))
				"h":
					_add(pieces, "elephant", Transform3D(Basis(Vector3.UP, PI * 0.5), at))
					_solid(Vector3(3.4, 3.2, 2.0), at + Vector3(0, 1.6, 0))
				"W":
					_chakra(at)
				"m":
					for count in range(rng.randi_range(3, 5)):
						var size := rng.randf_range(0.8, 2.2)
						var spot := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), at + Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.4, 1.4)))
						_add(pieces, "mushroom_stem", spot)
						_add(pieces, "mushroom_cap", spot, CAP_TINTS[count % CAP_TINTS.size()])
					fireflies.append(at)
				"r":
					var size := rng.randf_range(0.9, 1.3)
					_add(pieces, "boulder", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), at))
					_solid(Vector3(2.6, 2.4, 2.4) * size, at + Vector3(0, 1.1 * size, 0))
					for count in range(2):
						_add(pieces, "stalagmite", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.2)), at + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))))
				"L":
					_loot(at + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)))
				"o":
					_ore(at + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)), rng)
				"x":
					_add(pieces, "rubble", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at))
				"C":
					_chest(at)
				"X":
					stairs_spot = at
					_add(pieces, "stairs", Transform3D(Basis(Vector3.UP, PI), at))
				"E":
					_add(pieces, "entry_stone", Transform3D(Basis(), at))
					set_meta("entry", at + Vector3(0, 1.0, 0))
					set_meta("exit", at + Vector3(0, 1.0, 0))
					set_meta("facing", _open_facing(col, row))
					_swirl(at)
				"S":
					spawns.append(at)
				"b":
					boss_spot = at
				"1", "2", "3", "4":
					_book(at, int(tag) - 1)
	_corners(pieces)
	for name in pieces: _batch(name, pieces[name])
	if style.has("realistic"): _dress(rng)
	var stream := MeshInstance3D.new()
	stream.name = "Stream"
	stream.mesh = water.commit()
	var flow := ShaderMaterial.new()
	flow.shader = preload("res://assets/materials/water_flow.gdshader")
	stream.material_override = flow
	add_child(stream)
	for spot in fireflies: _fireflies(spot)
	_solid(Vector3(grid[0].length() * CELL, 0.5, grid.size() * CELL), Vector3((grid[0].length() - 1) * CELL / 2.0, -0.25, (grid.size() - 1) * CELL / 2.0))
	_rock_colliders()
	set_meta("stairs", stairs_spot)
	if floor_id == 1: _surya_air(rng)

## A wall piece for this floor, picked by the style's weights.
func _wall_kind(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	for entry in style.walls:
		roll -= float(entry[1])
		if roll <= 0.0: return entry[0]
	return style.walls[0][0]

## A lantern post's warm light (the first four only: the floor is one big mesh and the
## Compatibility renderer lights an object with 8 lights at most).
func _lantern(at: Vector3) -> void:
	if lanterns.size() >= 4: return
	var light := OmniLight3D.new()
	light.name = "Lantern"
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 1.8
	light.omni_range = 9.0
	light.position = at
	add_child(light)
	lanterns.append(light)

## The Surya Chakra: the golden wheel turns slowly on its plinth in the plaza (its face
## towards the entry hall, +z), centre 5.2 m up.
func _chakra(at: Vector3) -> void:
	add_child(_piece("chakra_stand", at, _solid_material("chakra_stand")))
	chakra = Node3D.new()
	chakra.name = "SuryaChakra"
	chakra.position = at + Vector3(0, 5.2, 0)
	var wheel := _piece("chakra", Vector3.ZERO, _real("chakra") if style.has("realistic") else _gold())
	chakra.add_child(wheel)
	add_child(chakra)
	_solid(Vector3(7.6, 1.3, 4.0), at + Vector3(0, 0.65, 0))
	_solid(Vector3(8.2, 9.0, 1.2), at + Vector3(0, 5.2, 0))
	set_meta("chakra", at)

## Gold that shines: the toon look with a warm rim and a little glow of its own.
func _gold() -> ShaderMaterial:
	var material: ShaderMaterial = toon_outlined.duplicate()
	material.set_shader_parameter("rim_color", Color(1.0, 0.82, 0.45))
	material.set_shader_parameter("rim_strength", 0.6)
	material.set_shader_parameter("glow", Color(0.09, 0.055, 0.01))
	return material

## Surya Nagri's air: its own low sun over the canyon (sharp shadows from the cliffs on
## Medium and up), shafts of light falling through the haze, mist drifting at knee to
## head height, and the path of the first-visit fly-over (dungeon_world.gd).
func _surya_air(rng: RandomNumberGenerator) -> void:
	sun = DirectionalLight3D.new()
	sun.name = "SuryaSun"
	# A low golden sun: long shadows from the cliffs and warm light on the rock (like late
	# afternoon), the shaded side lit only by the sky.
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(32), 0)
	sun.light_color = Color(1.0, 0.8, 0.56)
	sun.light_energy = 1.5
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	var towards_sun: Vector3 = sun.basis.z.normalized()
	var width: float = grid[0].length() * CELL
	var depth: float = grid.size() * CELL
	var cinematic: bool = preload("res://game_settings.gd").cinematic_running()
	# Shafts: tall soft cones leaning with the sun, over the plaza, the hall and the gardens.
	var spots: Array[Vector3] = [Vector3(40, 0, 33), Vector3(78, 0, 30), Vector3(12, 0, 22), Vector3(40, 0, 10), Vector3(66, 0, 8)]
	for spot in ([] if cinematic else spots):
		var shaft := MeshInstance3D.new()
		shaft.name = "LightShaft"
		var cone := CylinderMesh.new()
		cone.top_radius = 1.6
		cone.bottom_radius = 3.2
		cone.height = 30.0
		cone.radial_segments = 12
		cone.cap_top = false
		cone.cap_bottom = false
		shaft.mesh = cone
		shaft.material_override = _beam()
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Along the sunlight: the cone's axis points at the sun, its foot on the ground here.
		shaft.basis = Basis(Quaternion(Vector3.UP, towards_sun))
		shaft.position = spot + towards_sun * 13.0
		add_child(shaft)
		shafts.append(shaft)
	# Mist: big soft cards facing the camera, low over the open ground.
	var cards := 0 if cinematic else (6 if low else 10)
	var tries := 0
	while mists.size() < cards and tries < 400:
		tries += 1
		var col := rng.randi_range(1, grid[0].length() - 2)
		var row := rng.randi_range(1, grid.size() - 2)
		if _tag(col, row) == "#": continue
		var mist := MeshInstance3D.new()
		mist.name = "Mist"
		var card := QuadMesh.new()
		card.size = Vector2(rng.randf_range(9.0, 14.0), rng.randf_range(3.0, 4.5))
		mist.mesh = card
		mist.material_override = _mist_material()
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mist.position = _centre(col, row) + Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(1.2, 2.4), rng.randf_range(-1.5, 1.5))
		mist.set_meta("home", mist.position)
		mist.set_meta("phase", rng.randf() * TAU)
		add_child(mist)
		mists.append(mist)
	# Dust motes turning gold in the sun over the plaza.
	var dust := CPUParticles3D.new()
	dust.name = "SunDust"
	dust.amount = 45
	dust.lifetime = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(14, 4, 12)
	dust.position = Vector3(40, 4.5, 36)
	dust.gravity = Vector3(0, -0.02, 0)
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.2
	dust.spread = 180.0
	var mote := QuadMesh.new()
	mote.size = Vector2(0.05, 0.05)
	var shine := StandardMaterial3D.new()
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	shine.albedo_color = Color(1.0, 0.9, 0.6)
	mote.material = shine
	dust.mesh = mote
	add_child(dust)
	# The fly-over: high above the south cliffs, down over the plaza, a sweep past the
	# wheel's face, and into the player's eyes on the entry stone. [camera, looking at]
	var wheel: Vector3 = get_meta("chakra", Vector3(40, 0, 36)) + Vector3(0, 5.2, 0)
	var entry: Vector3 = get_meta("entry", Vector3(40, 1, 60))
	set_meta("flight", [
		[Vector3(width * 0.5, 36.0, depth + 14.0), wheel + Vector3(0, -3, -6)],
		[Vector3(width * 0.74, 21.0, depth * 0.8), wheel],
		[wheel + Vector3(15.0, 3.0, 9.0), wheel],
		[wheel + Vector3(-12.0, 1.0, 11.0), wheel],
		[entry + Vector3(0, 0.62, 0), wheel + Vector3(0, -1.0, 0)],
	])

## A light shaft: additive warm haze, fading out at both ends (UV v runs down the cone).
func _beam() -> StandardMaterial3D:
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 64
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.albedo_texture = texture
	material.albedo_color = Color(1.0, 0.86, 0.6, 0.085)
	material.disable_fog = true
	return material

## A mist card: a soft round blot of haze that always faces the camera.
func _mist_material() -> StandardMaterial3D:
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = texture
	material.albedo_color = Color(0.95, 0.88, 0.76, 0.14)
	return material

func _tag(col: int, row: int) -> String:
	if row < 0 or row >= grid.size() or col < 0 or col >= grid[row].length(): return "#"
	return grid[row][col]

func _centre(col: int, row: int) -> Vector3:
	return Vector3(col * CELL, 0, row * CELL)

## Which way an arriving player should face: towards the first open side.
func _open_facing(col: int, row: int) -> float:
	for direction in WALL_DIRECTIONS:
		var side: Vector2i = direction[0]
		if _tag(col + side.x, row + side.y) != "#": return atan2(-side.x, -side.y)
	return 0.0

func _add(pieces: Dictionary, name: String, transform: Transform3D, colour := Color.WHITE) -> void:
	if not pieces.has(name): pieces[name] = []
	pieces[name].append([transform, colour])

## A rock pillar on every grid corner where rock and open cells meet (hides seams).
func _corners(pieces: Dictionary) -> void:
	for row in range(grid.size() + 1):
		for col in range(grid[0].length() + 1):
			var open := 0
			for cell in [Vector2i(col - 1, row - 1), Vector2i(col, row - 1), Vector2i(col - 1, row), Vector2i(col, row)]:
				if _tag(cell.x, cell.y) != "#": open += 1
			# Surya Nagri: none along a straight wall (two open cells side by side), only at real
			# corners, or the cliff reads as a row of columns.
			if style.has("realistic") and open == 2 and (_tag(col - 1, row - 1) != "#") != (_tag(col, row) != "#"): continue
			if open > 0 and open < 4: _add(pieces, "corner", Transform3D(Basis(Vector3.UP, (col * 7 + row * 3) % 4 * PI / 2.0), Vector3((col - 0.5) * CELL, 0, (row - 0.5) * CELL)))

func _mesh(name: String) -> Mesh:
	if meshes.has(name): return meshes[name]
	var scene := (load(kit + name + ".glb") as PackedScene).instantiate()
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	meshes[name] = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	scene.free()
	return meshes[name]

func _batch(name: String, items: Array) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = name in style.glow
	multimesh.mesh = _mesh(name)
	multimesh.instance_count = items.size()
	for index in range(items.size()):
		multimesh.set_instance_transform(index, items[index][0])
		if multimesh.use_colors: multimesh.set_instance_color(index, items[index][1])
	var batch := MultiMeshInstance3D.new()
	batch.name = "Kit_" + name
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if name in style.glow: batch.material_override = glow
	elif name in style.plain: batch.material_override = toon
	else: batch.material_override = toon_outlined
	# Fronds and flags are thin: seen from both sides.
	if name in ["palm_leaves", "flag"]: batch.material_override = _two_sided()
	if style.has("realistic") and REAL.has(name): batch.material_override = _real(name)
	add_child(batch)

## A kit piece's material: realistic on Surya Nagri, the outlined toon look elsewhere.
func _solid_material(name: String) -> Material:
	return _real(name) if style.has("realistic") and REAL.has(name) else toon_outlined

## The realistic material for kit piece `name` (REAL), shared by every piece using it.
func _real(name: String) -> ShaderMaterial:
	if real_materials.has(name): return real_materials[name]
	var entry: Array = REAL[name]
	var material := ShaderMaterial.new()
	# Low gets the light version (one projection, no roughness map): the full one cost the
	# MX110 two thirds of its frame rate here.
	if low: material.shader = preload("res://assets/materials/real_detail_low.gdshader")
	elif name in ["palm_leaves", "flag"]: material.shader = preload("res://assets/materials/real_detail_two_sided.gdshader")
	else: material.shader = preload("res://assets/materials/real_detail.gdshader")
	material.set_shader_parameter("atlas", toon.get_shader_parameter("albedo_texture"))
	material.set_shader_parameter("metal_mask", load(kit + "floor%d_metal.png" % (floor_id + 1)))
	var folder := SCANS + "textures/" + str(entry[0])
	var albedo: Texture2D = load(folder + "_diff_1k.jpg")
	material.set_shader_parameter("detail_albedo", albedo)
	material.set_shader_parameter("detail_normal", load(folder + "_nor_gl_1k.jpg"))
	if not low: material.set_shader_parameter("detail_arm", load(folder + "_arm_1k.jpg"))
	material.set_shader_parameter("detail_mean", _mean_colour(albedo))
	material.set_shader_parameter("detail_scale", float(entry[1]))
	material.set_shader_parameter("detail_strength", float(entry[2]))
	real_materials[name] = material
	return material

## A texture's average colour in linear light (the shader divides by it).
static func _mean_colour(texture: Texture2D) -> Vector3:
	var image := texture.get_image()
	if image == null: return Vector3(0.3, 0.3, 0.3)
	if image.is_compressed(): image.decompress()
	image.resize(8, 8, Image.INTERPOLATE_BILINEAR)
	var total := Vector3.ZERO
	for y in range(8):
		for x in range(8):
			var colour := image.get_pixel(x, y).srgb_to_linear()
			total += Vector3(colour.r, colour.g, colour.b)
	return total / 64.0

## A scanned CC0 model (assets/props/dungeon/floor2/scans) placed in the floor.
func _scan(name: String, at: Vector3, yaw: float, size: float) -> Node3D:
	if not scan_scenes.has(name): scan_scenes[name] = load(SCANS + name + ".glb")
	var node: Node3D = (scan_scenes[name] as PackedScene).instantiate()
	node.position = at
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size
	add_child(node)
	return node

## True when the wall on `side` of cell `cell` carries on past both neighbours along it.
func _straight_wall(cell: Vector2i, side: Vector2i) -> bool:
	var along := Vector2i(side.y, side.x)
	for step in [along, -along]:
		var next: Vector2i = cell + step
		if _tag(next.x, next.y) == "#" or _tag(next.x + side.x, next.y + side.y) != "#": return false
	return true

## Real rock in front of the cut cliffs: scanned cliffs and rock faces along the walls (a
## second row higher up breaks the cliff tops), boulders at their feet, and ferns and
## shrubs in the gardens. The Low preset gets about half, no high row and no shrubs.
func _dress(rng: RandomNumberGenerator) -> void:
	for edge in edges:
		var wall: Vector3 = edge[0]
		var side: Vector3 = edge[2]
		var yaw: float = edge[1] + rng.randf_range(-0.4, 0.4) + (PI if rng.randf() < 0.5 else 0.0)
		# Wide scans only on a straight run of wall (the cells either side have the same wall),
		# so no rock sticks out past a corner into ground you can walk on.
		var straight := _straight_wall(edge[3], edge[4])
		if not low and rng.randf() < 0.5:
			if straight and rng.randf() < 0.55: _scan("namaqualand_cliff_01", wall + side * 2.0, edge[1] + rng.randf_range(-0.15, 0.15), rng.randf_range(1.0, 1.25))
			else: _scan("rock_face_01", wall + side * 1.6, edge[1] + rng.randf_range(-0.3, 0.3), rng.randf_range(1.1, 1.5))
		if not low and straight and rng.randf() < 0.3:
			_scan("namaqualand_cliff_01", wall + side * 2.6 + Vector3(0, rng.randf_range(6.0, 11.0), 0), yaw + 1.3, rng.randf_range(1.3, 1.8))
		if rng.randf() < (0.06 if low else 0.22):
			_scan("namaqualand_boulder_04", wall - side * rng.randf_range(0.2, 0.7) + Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.4, 1.4)) * Vector3(absf(side.z), 0, absf(side.x)), rng.randf() * TAU, rng.randf_range(0.5, 0.9))
	for row in range(grid.size()):
		for col in range(grid[row].length()):
			if not _tag(col, row) in [",", "W"]: continue
			var at := _centre(col, row)
			for count in range(1 if low else 2):
				_scan("fern_02", at + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6)), rng.randf() * TAU, rng.randf_range(1.2, 1.7))
			if not low:
				_scan("shrub_04", at + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)), rng.randf() * TAU, rng.randf_range(3.5, 5.0))

var two_sided: ShaderMaterial

func _two_sided() -> ShaderMaterial:
	if two_sided == null:
		two_sided = ShaderMaterial.new()
		two_sided.shader = preload("res://assets/materials/toon_two_sided.gdshader")
		two_sided.set_shader_parameter("albedo_texture", toon.get_shader_parameter("albedo_texture"))
	return two_sided

func _toon(atlas: Texture2D, outlined: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/toon.gdshader")
	material.set_shader_parameter("albedo_texture", atlas)
	if outlined:
		var outline := ShaderMaterial.new()
		outline.shader = preload("res://assets/materials/outline.gdshader")
		outline.set_shader_parameter("width", 0.025)
		material.next_pass = outline
	return material

func _piece(name: String, at: Vector3, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = name.to_pascal_case()
	piece.mesh = _mesh(name)
	piece.material_override = material
	piece.position = at
	return piece

func _solid(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)

## Rock cells next to open ones, as boxes merged along each row.
func _rock_colliders() -> void:
	for row in range(grid.size()):
		var start := -1
		for col in range(grid[row].length() + 1):
			var edge: bool = col < grid[row].length() and _tag(col, row) == "#" and _touches_open(col, row)
			if edge and start < 0: start = col
			if not edge and start >= 0:
				var length := col - start
				var tall: float = style.rock_height
				_solid(Vector3(length * CELL, tall, CELL), Vector3((start + (length - 1) / 2.0) * CELL, tall / 2.0 - 0.5, row * CELL))
				start = -1

func _touches_open(col: int, row: int) -> bool:
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if _tag(col + dx, row + dz) != "#": return true
	return false

func _torch(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "Torch"
	light.light_color = Color(1.0, 0.68, 0.38)
	light.light_energy = 2.7
	light.omni_range = 11.0
	torches.append(light)
	light.position = at
	add_child(light)
	var flame := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.45)
	flame.mesh = quad
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	fire.albedo_color = Color(1.0, 0.66, 0.22)
	flame.material_override = fire
	flame.position = at - Vector3(0, 0.0, 0)
	add_child(flame)

func _fireflies(at: Vector3) -> void:
	var fireflies := CPUParticles3D.new()
	fireflies.amount = 14
	fireflies.lifetime = 6.0
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(3, 1.2, 3)
	fireflies.position = at + Vector3(0, 1.8, 0)
	fireflies.spread = 180.0
	fireflies.gravity = Vector3.ZERO
	fireflies.initial_velocity_min = 0.1
	fireflies.initial_velocity_max = 0.3
	var dot := QuadMesh.new()
	dot.size = Vector2(0.07, 0.07)
	var spark := StandardMaterial3D.new()
	spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark.albedo_color = Color(0.85, 1.0, 0.5)
	dot.material = spark
	fireflies.mesh = dot
	add_child(fireflies)

func _swirl(at: Vector3) -> void:
	var swirl := MeshInstance3D.new()
	swirl.name = "EntrySwirl"
	var disc := QuadMesh.new()
	disc.size = Vector2(2.4, 2.4)
	disc.orientation = PlaneMesh.FACE_Y
	swirl.mesh = disc
	var portal := ShaderMaterial.new()
	portal.shader = preload("res://assets/materials/portal.gdshader")
	swirl.material_override = portal
	swirl.position = at + Vector3(0, 0.36, 0)
	add_child(swirl)
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.8, 1.0)
	light.light_energy = 1.2
	light.omni_range = 7.0
	light.position = at + Vector3(0, 1.2, 0)
	add_child(light)

func _loot(at: Vector3) -> void:
	var jar := Node3D.new()
	jar.name = "Treasure"
	jar.position = at
	jar.add_child(_piece(style.loot[0], Vector3.ZERO, _solid_material(style.loot[0])))
	jar.add_child(_piece(style.loot[1], Vector3.ZERO, glow))
	add_child(jar)
	loot.append(jar)

func _chest(at: Vector3) -> void:
	chest_spot = at
	if style.has("realistic"):
		# The scanned treasure chest; its lid already hinges at the back edge.
		var chest := _scan("treasure_chest", at, 0.0, 1.35)
		chest_lid = chest.find_child("treasure_chest_lid", true, false) as Node3D
		_solid(Vector3(1.3, 0.8, 0.9), at + Vector3(0, 0.4, 0))
		return
	add_child(_piece("chest_base", at, toon_outlined))
	chest_lid = Node3D.new()
	chest_lid.name = "ChestHinge"
	chest_lid.position = at + Vector3(0, 0.6, -0.375)
	chest_lid.add_child(_piece("chest_lid", Vector3.ZERO, toon_outlined))
	add_child(chest_lid)
	_solid(Vector3(1.3, 0.8, 0.9), at + Vector3(0, 0.4, 0))

## A page of Dada-ji's diary: a red book on a stone stand, in a warm glow that dims once
## it has been read (mark_read).
func _book(at: Vector3, page: int) -> void:
	var stand := Node3D.new()
	stand.name = "DiaryPage%d" % (page + 1)
	stand.position = at + Vector3(0.9, 0, 0.9)
	stand.rotation.y = page * 1.3
	stand.set_meta("page", page)
	add_child(stand)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.34, 0.35, 0.4)
	stone.roughness = 0.95
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.3
	pillar.bottom_radius = 0.42
	pillar.height = 0.95
	pillar.radial_segments = 8
	pillar.material = stone
	var base := MeshInstance3D.new()
	base.mesh = pillar
	base.position.y = 0.475
	stand.add_child(base)
	var book := Node3D.new()
	book.name = "Book"
	book.position.y = 1.02
	book.rotation.x = -0.3
	stand.add_child(book)
	for part in [[Vector3(0.62, 0.07, 0.46), Vector3.ZERO, Color(0.55, 0.14, 0.09)], [Vector3(0.56, 0.05, 0.42), Vector3(0.02, 0.045, 0), Color(0.96, 0.9, 0.74)], [Vector3(0.07, 0.075, 0.47), Vector3(-0.2, 0.002, 0), Color(0.95, 0.72, 0.25)]]:
		var paint := StandardMaterial3D.new()
		paint.albedo_color = part[2]
		var box := BoxMesh.new()
		box.size = part[0]
		box.material = paint
		var piece := MeshInstance3D.new()
		piece.mesh = box
		piece.position = part[1]
		book.add_child(piece)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color(1.0, 0.78, 0.42)
	light.light_energy = 1.6
	light.omni_range = 4.0
	light.position.y = 1.7
	stand.add_child(light)
	_solid(Vector3(0.8, 1.0, 0.8), stand.position + Vector3(0, 0.5, 0))
	books.append(stand)

## A page that has been read glows softer, so the unread ones stand out.
func mark_read(page: int) -> void:
	for stand in books:
		if stand.get_meta("page") == page: stand.get_node("Glow").light_energy = 0.5

## The diary page within reach of `at` (local), or -1.
func book_at(at: Vector3) -> int:
	for stand in books:
		if Vector2(stand.position.x - at.x, stand.position.z - at.z).length() < REACH: return stand.get_meta("page")
	return -1

func _process(delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	for index in range(books.size()):
		books[index].get_node("Book").position.y = 1.02 + sin(time * 1.8 + index) * 0.025
	for index in range(torches.size()):
		torches[index].light_energy = 2.7 + sin(time * 11.0 + index * 3.1) * 0.25 + sin(time * 23.0 + index) * 0.18
	for index in range(loot.size()):
		if loot[index].visible: loot[index].get_child(1).scale = Vector3.ONE * (1.0 + sin(time * 3.0 + index) * 0.15)
	if chest_open and lid_turn < 1.6:
		lid_turn = minf(1.6, lid_turn + delta * 3.0)
		chest_lid.rotation.x = -lid_turn
	# Surya Nagri: the wheel turns (one turn in about two minutes), lanterns flicker, the
	# light shafts breathe and the mist drifts.
	if is_instance_valid(chakra): chakra.rotation.z -= delta * chakra_speed
	for index_light in range(lanterns.size()):
		lanterns[index_light].light_energy = 1.8 + sin(time * 7.0 + index_light * 2.3) * 0.15 + sin(time * 17.0 + index_light) * 0.08
	for index_shaft in range(shafts.size()):
		var beam: StandardMaterial3D = shafts[index_shaft].material_override
		beam.albedo_color.a = 0.085 + sin(time * 0.35 + index_shaft * 1.7) * 0.025
	for mist in mists:
		var phase: float = mist.get_meta("phase")
		mist.position = mist.get_meta("home") + Vector3(sin(time * 0.07 + phase) * 2.5, sin(time * 0.11 + phase) * 0.25, cos(time * 0.05 + phase) * 1.5)

## How fast the Surya Chakra turns (radians a second); the wheel puzzle can change it.
var chakra_speed := 0.05

## A rock to break with the lathi: three good hits (see strike).
func _ore(at: Vector3, rng: RandomNumberGenerator) -> void:
	var ore := Node3D.new()
	ore.name = "OreRock"
	ore.position = at
	ore.rotation.y = rng.randf() * TAU
	ore.set_meta("hp", 3)
	ore.add_child(_piece("ore_rock", Vector3.ZERO, _solid_material("ore_rock")))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.7, 1.5, 1.7)
	shape.shape = box
	shape.position.y = 0.75
	body.add_child(shape)
	ore.add_child(body)
	add_child(ore)
	ores.append(ore)

## A lathi swing from `at` (local) towards `facing` (local, flat): the nearest ore rock
## in front takes a hit. -1 nothing there, 0 hit (it shakes and cracks), else the
## treasure it broke into (smoke and chunks fly).
func strike(at: Vector3, facing: Vector3, damage := 1) -> int:
	for ore in ores:
		var to: Vector3 = ore.position - at
		to.y = 0.0
		if to.length() > 2.7 or to.normalized().dot(facing) < 0.35: continue
		var hp: int = ore.get_meta("hp") - damage
		ore.set_meta("hp", hp)
		var Effects := preload("res://dungeon_effects.gd")
		if hp > 0:
			Effects.chunks(self, ore.position + Vector3(0, 0.8, 0), Color(0.3, 0.35, 0.42), 6)
			var shake := create_tween()
			shake.tween_property(ore, "scale", Vector3(1.08, 0.92, 1.08), 0.05)
			shake.tween_property(ore, "scale", Vector3.ONE * (0.9 + hp * 0.03), 0.1)
			return 0
		Effects.chunks(self, ore.position + Vector3(0, 0.8, 0), Color(0.3, 0.35, 0.42), 16)
		Effects.chunks(self, ore.position + Vector3(0, 0.8, 0), Color(0.6, 0.9, 1.0), 8)
		Effects.smoke(self, ore.position + Vector3(0, 0.6, 0), 1.0, 16, Color(0.6, 0.62, 0.66))
		ores.erase(ore)
		ore.queue_free()
		return 1 + int(randf() < 0.3)
	return -1

## What E would do near `at` (local to the floor), for the hint line.
func hint_at(at: Vector3) -> String:
	var page := book_at(at)
	if page >= 0: return "E - read Dada-ji's diary (page %d)" % (page + 1)
	for jar in loot:
		if jar.visible and Vector2(jar.position.x - at.x, jar.position.z - at.z).length() < REACH: return "E - take the %s" % style.loot_name
	if not chest_open and chest_spot != Vector3.ZERO and Vector2(chest_spot.x - at.x, chest_spot.z - at.z).length() < REACH: return "E - open the treasure chest"
	return ""

## E near `at`: how much treasure it gave (0 if nothing was there).
func interact_at(at: Vector3) -> int:
	for jar in loot:
		if jar.visible and Vector2(jar.position.x - at.x, jar.position.z - at.z).length() < REACH:
			jar.visible = false
			return 1
	if not chest_open and chest_spot != Vector3.ZERO and Vector2(chest_spot.x - at.x, chest_spot.z - at.z).length() < REACH:
		chest_open = true
		return 4
	return 0
