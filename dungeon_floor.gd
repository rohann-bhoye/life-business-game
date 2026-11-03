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

var grid: Array = []
var kit := ""
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

static func create(index: int, origin: Vector3) -> Node3D:
	var floor := preload("res://dungeon_floor.gd").new()
	floor.name = "DungeonFloor"
	floor.position = origin
	floor._build(index)
	return floor

func _build(index: int) -> void:
	grid = Layouts.rows(index)
	kit = "res://assets/props/dungeon/floor%d/" % (index + 1)
	var atlas: Texture2D = load(kit + "floor%d_print.png" % (index + 1))
	toon = _toon(atlas, false)
	toon_outlined = _toon(atlas, true)
	glow = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_texture = atlas
	glow.vertex_color_use_as_albedo = true
	var pieces := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + index
	var water := SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	water.set_normal(Vector3.UP)
	var fireflies: Array[Vector3] = []
	for row in range(grid.size()):
		for col in range(grid[row].length()):
			var tag := _tag(col, row)
			if tag == "#": continue
			var at := _centre(col, row)
			_add(pieces, "ceiling", Transform3D(Basis(), at))
			if tag in ["w", "p"]:
				_add(pieces, "stream", Transform3D(Basis(), at))
				for corner in [Vector3(-2, -0.35, -2), Vector3(2, -0.35, -2), Vector3(2, -0.35, 2), Vector3(-2, -0.35, -2), Vector3(2, -0.35, 2), Vector3(-2, -0.35, 2)]: water.add_vertex(at + corner)
				if tag == "p": _add(pieces, "bridge", Transform3D(Basis(), at))
				else: _solid(Vector3(CELL, 1.6, CELL), at + Vector3(0, 0.4, 0))
			else:
				_add(pieces, "floor", Transform3D(Basis(Vector3.UP, (rng.randi() % 4) * PI / 2.0), at))
				if tag == "." and rng.randf() < 0.14:
					_add(pieces, "rubble", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.5, 0.9)), at + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))))
			var torch_placed := false
			for direction in WALL_DIRECTIONS:
				var side: Vector2i = direction[0]
				if _tag(col + side.x, row + side.y) != "#": continue
				var kind := "wall_moss" if rng.randf() < 0.35 else "wall"
				if tag == "T" and not torch_placed:
					kind = "wall_torch"
					torch_placed = true
					_torch(at + Vector3(side.x, 0, side.y) * 1.25 + Vector3(0, 3.2, 0))
				_add(pieces, kind, Transform3D(Basis(Vector3.UP, direction[1]), at))
			match tag:
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
	multimesh.use_colors = name in ["mushroom_cap"]
	multimesh.mesh = _mesh(name)
	multimesh.instance_count = items.size()
	for index in range(items.size()):
		multimesh.set_instance_transform(index, items[index][0])
		if multimesh.use_colors: multimesh.set_instance_color(index, items[index][1])
	var batch := MultiMeshInstance3D.new()
	batch.name = "Kit_" + name
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if name in ["mushroom_cap"]: batch.material_override = glow
	elif name in ["floor", "ceiling", "wall", "wall_moss", "wall_torch", "stream"]: batch.material_override = toon
	else: batch.material_override = toon_outlined
	add_child(batch)

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
				_solid(Vector3(length * CELL, 8.0, CELL), Vector3((start + (length - 1) / 2.0) * CELL, 3.5, row * CELL))
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
	jar.add_child(_piece("jar", Vector3.ZERO, toon_outlined))
	jar.add_child(_piece("jar_glow", Vector3.ZERO, glow))
	add_child(jar)
	loot.append(jar)

func _chest(at: Vector3) -> void:
	chest_spot = at
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

## A rock to break with the lathi: three good hits (see strike).
func _ore(at: Vector3, rng: RandomNumberGenerator) -> void:
	var ore := Node3D.new()
	ore.name = "OreRock"
	ore.position = at
	ore.rotation.y = rng.randf() * TAU
	ore.set_meta("hp", 3)
	ore.add_child(_piece("ore_rock", Vector3.ZERO, toon_outlined))
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
		if jar.visible and Vector2(jar.position.x - at.x, jar.position.z - at.z).length() < REACH: return "E - take the firefly jar"
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
