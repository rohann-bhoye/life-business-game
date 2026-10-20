extends RefCounted

# Industrial red-brick building style for the shop and the warehouse: a brick wall
# material (made in code, world-mapped so it tiles on any wall size), steel roof
# trusses, blue roller shutters, glass windows in a bright frame, roof skylights,
# hedge planters and big hanging bay numbers. Each part is one merged mesh. Parts
# are built facing +z in a holder turned by `yaw`.
const IndianHouse := preload("res://indian_house.gd")
const STEEL := Color(0.32, 0.36, 0.4)
const SHUTTER := Color(0.16, 0.32, 0.62)
const FRAME := Color(0.86, 0.2, 0.56)
const HEDGE := Color(0.16, 0.42, 0.18)
const BRICK_WALL := Color(0.6, 0.27, 0.2)
static var bricks: StandardMaterial3D
static var glass: StandardMaterial3D

## Red bricks in running bond with light mortar, about 0.25 x 0.125 m each.
static func brick_material() -> StandardMaterial3D:
	if bricks != null: return bricks
	var image := Image.create(128, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2037
	var mortar := Color(0.78, 0.74, 0.68)
	for row in range(4):
		var offset := 16 if row % 2 == 1 else 0
		for column in range(5):
			var shade := BRICK_WALL.lightened(rng.randf_range(-0.12, 0.1)) if rng.randf() > 0.15 else BRICK_WALL.darkened(rng.randf_range(0.1, 0.25))
			for y in range(row * 16, row * 16 + 16):
				for x in range(column * 32 - offset, column * 32 + 32 - offset):
					if x < 0 or x >= 128: continue
					var edge := y % 16 < 2 or (x + offset) % 32 < 2
					image.set_pixel(x, y, mortar if edge else shade.darkened(rng.randf_range(0.0, 0.05)))
	image.generate_mipmaps()
	bricks = StandardMaterial3D.new()
	bricks.albedo_texture = ImageTexture.create_from_image(image)
	bricks.uv1_triplanar = true
	bricks.uv1_world_triplanar = true
	bricks.uv1_scale = Vector3(1.0, 2.0, 1.0)
	bricks.roughness = 0.9
	return bricks

static func glass_material() -> StandardMaterial3D:
	if glass != null: return glass
	glass = StandardMaterial3D.new()
	glass.albedo_color = Color(0.45, 0.66, 0.78, 0.55)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	glass.metallic_specular = 0.9
	return glass

static func _holder(parent: Node3D, node_name: String, at: Vector3, yaw: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = at
	holder.rotation.y = yaw
	parent.add_child(holder)
	return holder

static func _mesh(holder: Node3D, st: SurfaceTool, node_name := "Mesh") -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = st.commit()
	mesh.material_override = IndianHouse._material()
	holder.add_child(mesh)
	return mesh

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

## A box turned by `angle` about z (for truss diagonals), into a merged mesh.
static func _turned_box(st: SurfaceTool, center: Vector3, size: Vector3, angle: float, colour: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var transform := Transform3D(Basis(Vector3.BACK, angle), center)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		st.set_color(colour)
		st.set_normal(transform.basis * normals[index])
		st.add_vertex(transform * vertices[index])

## A steel roof truss across the room (along x, from `left` to `right`) hanging under
## the ceiling at `top`: top and bottom chords, posts and zig-zag diagonals.
static func truss(parent: Node3D, node_name: String, left: float, right: float, z: float, top: float, depth := 0.55) -> void:
	var holder := _holder(parent, node_name, Vector3.ZERO, 0.0)
	var st := _begin()
	var width := right - left
	var middle := (left + right) / 2.0
	IndianHouse.box(st, Vector3(middle, top - 0.06, z), Vector3(width, 0.12, 0.14), STEEL)
	IndianHouse.box(st, Vector3(middle, top - depth, z), Vector3(width, 0.1, 0.12), STEEL)
	var bays := maxi(2, roundi(width / 1.2))
	var step := width / bays
	for index in range(bays + 1):
		IndianHouse.box(st, Vector3(left + index * step, top - depth / 2.0, z), Vector3(0.08, depth, 0.1), STEEL)
		if index == bays: continue
		var length := sqrt(step * step + depth * depth)
		var angle := atan2(depth, step) * (1 if index % 2 == 0 else -1)
		_turned_box(st, Vector3(left + (index + 0.5) * step, top - depth / 2.0, z), Vector3(length, 0.06, 0.08), angle, STEEL.lightened(0.08))
	_mesh(holder, st)

## Steel I-beams across a room (along x) under the ceiling at `top`, one per z in
## `rows`, each with a flange top and bottom and a plate where it meets the wall.
static func i_beams(parent: Node3D, node_name: String, left: float, right: float, rows: Array, top: float) -> void:
	var holder := _holder(parent, node_name, Vector3.ZERO, 0.0)
	var st := _begin()
	var width := right - left
	var middle := (left + right) / 2.0
	for z in rows:
		IndianHouse.box(st, Vector3(middle, top - 0.02, z), Vector3(width, 0.04, 0.16), STEEL)
		IndianHouse.box(st, Vector3(middle, top - 0.12, z), Vector3(width, 0.16, 0.04), STEEL)
		IndianHouse.box(st, Vector3(middle, top - 0.22, z), Vector3(width, 0.04, 0.16), STEEL)
		for x in [left + 0.02, right - 0.02]: IndianHouse.box(st, Vector3(x, top - 0.2, z), Vector3(0.04, 0.4, 0.3), STEEL.darkened(0.15))
	_mesh(holder, st)

## A closed blue roller shutter with ribs, a top box and guide rails (front = +z).
static func shutter(parent: Node3D, node_name: String, at: Vector3, yaw: float, width: float, height: float) -> void:
	var holder := _holder(parent, node_name, at, yaw)
	var st := _begin()
	IndianHouse.box(st, Vector3(0, height / 2.0, 0.02), Vector3(width, height, 0.04), SHUTTER)
	for rib in range(int(height / 0.16)):
		IndianHouse.box(st, Vector3(0, 0.1 + rib * 0.16, 0.045), Vector3(width, 0.025, 0.01), SHUTTER.darkened(0.25))
	IndianHouse.box(st, Vector3(0, height + 0.16, 0.12), Vector3(width + 0.3, 0.32, 0.24), STEEL)
	for x in [-1, 1]: IndianHouse.box(st, Vector3(x * (width / 2.0 + 0.06), height / 2.0, 0.05), Vector3(0.1, height, 0.1), STEEL)
	IndianHouse.box(st, Vector3(0, 0.05, 0.06), Vector3(width, 0.1, 0.03), Color(0.95, 0.75, 0.1))
	IndianHouse.box(st, Vector3(width * 0.3, 0.35, 0.07), Vector3(0.25, 0.04, 0.03), Color(0.1, 0.1, 0.1))
	_mesh(holder, st)

## A big glass window (see-through glass pane) in a thick bright frame with a sill
## and mullions (front = +z).
static func framed_window(parent: Node3D, node_name: String, at: Vector3, yaw: float, width: float, height: float, frame := FRAME, panes := 3, backing := Color(0.12, 0.16, 0.2)) -> void:
	var holder := _holder(parent, node_name, at, yaw)
	var st := _begin()
	for y in [0.0, height]: IndianHouse.box(st, Vector3(0, y, 0.06), Vector3(width + 0.24, 0.16, 0.14), frame)
	for x in [-1, 1]: IndianHouse.box(st, Vector3(x * (width / 2.0 + 0.04), height / 2.0, 0.06), Vector3(0.16, height, 0.14), frame)
	for pane in range(1, panes): IndianHouse.box(st, Vector3(-width / 2.0 + pane * width / panes, height / 2.0, 0.05), Vector3(0.06, height, 0.08), frame.darkened(0.2))
	IndianHouse.box(st, Vector3(0, -0.12, 0.14), Vector3(width + 0.4, 0.06, 0.26), Color(0.7, 0.7, 0.68))
	# What shows through the glass: a dark room from outside, daylight from inside
	# (a clear backing leaves the opening see-through).
	if backing.a > 0.0: IndianHouse.box(st, Vector3(0, height / 2.0, 0.0), Vector3(width, height, 0.01), backing)
	_mesh(holder, st, "Frame")
	var pane_mesh := MeshInstance3D.new()
	pane_mesh.name = "Glass"
	var box := BoxMesh.new()
	box.size = Vector3(width, height, 0.02)
	pane_mesh.mesh = box
	pane_mesh.position = Vector3(0, height / 2.0, 0.04)
	pane_mesh.material_override = glass_material()
	pane_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(pane_mesh)

## A glass roof skylight: a raised steel kerb with a glass top.
static func skylight(parent: Node3D, node_name: String, at: Vector3, size: Vector2) -> void:
	var holder := _holder(parent, node_name, at, 0.0)
	var st := _begin()
	for z in [-1, 1]: IndianHouse.box(st, Vector3(0, 0.12, z * size.y / 2.0), Vector3(size.x + 0.12, 0.24, 0.08), STEEL)
	for x in [-1, 1]: IndianHouse.box(st, Vector3(x * size.x / 2.0, 0.12, 0), Vector3(0.08, 0.24, size.y), STEEL)
	for bar in range(1, 3): IndianHouse.box(st, Vector3(-size.x / 2.0 + bar * size.x / 3.0, 0.26, 0), Vector3(0.05, 0.04, size.y), STEEL)
	_mesh(holder, st)
	var top := MeshInstance3D.new()
	top.name = "Glass"
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 0.03, size.y)
	top.mesh = box
	top.position = Vector3(0, 0.25, 0)
	top.material_override = glass_material()
	holder.add_child(top)

## A low brick planter box with a trimmed hedge on top (front = +z).
static func planter(parent: Node3D, node_name: String, at: Vector3, yaw: float, length: float) -> void:
	var holder := _holder(parent, node_name, at, yaw)
	var st := _begin()
	IndianHouse.box(st, Vector3(0, 0.25, 0), Vector3(length, 0.5, 0.6), BRICK_WALL)
	IndianHouse.box(st, Vector3(0, 0.52, 0), Vector3(length + 0.08, 0.06, 0.68), Color(0.7, 0.68, 0.64))
	IndianHouse.box(st, Vector3(0, 0.82, 0), Vector3(length - 0.1, 0.56, 0.5), HEDGE)
	IndianHouse.box(st, Vector3(0, 1.12, 0), Vector3(length - 0.2, 0.08, 0.42), HEDGE.lightened(0.08))
	_mesh(holder, st)

## A closed steel door in a frame with a handle and a kick plate, its bottom
## centre at `at` (front = +z), with an optional sign above it.
static func door(parent: Node3D, node_name: String, at: Vector3, yaw: float, width: float, height: float, colour: Color, sign_text := "") -> Node3D:
	var holder := _holder(parent, node_name, at, yaw)
	var st := _begin()
	IndianHouse.box(st, Vector3(0, height / 2.0, 0.02), Vector3(width, height, 0.04), colour)
	for x in [-1, 1]: IndianHouse.box(st, Vector3(x * (width / 2.0 + 0.04), height / 2.0, 0.04), Vector3(0.08, height + 0.04, 0.08), STEEL.darkened(0.3))
	IndianHouse.box(st, Vector3(0, height + 0.04, 0.04), Vector3(width + 0.16, 0.08, 0.08), STEEL.darkened(0.3))
	IndianHouse.box(st, Vector3(width * 0.36, height * 0.46, 0.07), Vector3(0.04, 0.18, 0.04), Color(0.85, 0.85, 0.82))
	IndianHouse.box(st, Vector3(0, 0.12, 0.045), Vector3(width - 0.06, 0.22, 0.01), colour.darkened(0.2))
	for y in [0.55, 1.35]: IndianHouse.box(st, Vector3(0, y * height / 2.1, 0.045), Vector3(width - 0.2, 0.5, 0.01), colour.lightened(0.06))
	if sign_text != "": IndianHouse.box(st, Vector3(0, height * 0.82, 0.055), Vector3(width - 0.16, 0.16, 0.01), Color(0.12, 0.3, 0.26))
	_mesh(holder, st)
	if sign_text != "":
		var label := Label3D.new()
		label.text = sign_text
		label.font_size = 26
		label.pixel_size = 0.004
		label.outline_size = 0
		label.position = Vector3(0, height * 0.82, 0.062)
		holder.add_child(label)
	return holder

## A small louvred vent window (front = +z), centred on `at`.
static func vent(parent: Node3D, node_name: String, at: Vector3, yaw: float, width: float) -> void:
	var holder := _holder(parent, node_name, at, yaw)
	var st := _begin()
	IndianHouse.box(st, Vector3.ZERO, Vector3(width + 0.12, 0.46, 0.04), STEEL.darkened(0.3))
	IndianHouse.box(st, Vector3(0, 0, 0.02), Vector3(width, 0.34, 0.01), Color(0.1, 0.11, 0.12))
	for index in range(5): IndianHouse.box(st, Vector3(0, -0.14 + index * 0.07, 0.04), Vector3(width, 0.03, 0.03), STEEL.lightened(0.15))
	IndianHouse.box(st, Vector3(0, -0.26, 0.06), Vector3(width + 0.2, 0.05, 0.12), Color(0.7, 0.7, 0.68))
	_mesh(holder, st)

## A round wall clock (front = +z) at 10:10.
static func clock(parent: Node3D, node_name: String, at: Vector3, yaw: float) -> void:
	var holder := _holder(parent, node_name, at, yaw)
	var st := _begin()
	IndianHouse.disc(st, Vector3.ZERO, 0.2, 0.04, Color(0.15, 0.15, 0.16), 24)
	IndianHouse.disc(st, Vector3(0, 0, 0.025), 0.175, 0.01, Color(0.97, 0.96, 0.92), 24)
	for hour in range(12):
		var angle := hour * TAU / 12.0
		IndianHouse.box(st, Vector3(sin(angle) * 0.15, cos(angle) * 0.15, 0.033), Vector3(0.012, 0.03, 0.005), Color(0.15, 0.15, 0.16))
	_turned_box(st, Vector3(-0.04, 0.025, 0.038), Vector3(0.1, 0.014, 0.005), -0.52, Color(0.1, 0.1, 0.1))
	_turned_box(st, Vector3(0.055, 0.03, 0.04), Vector3(0.13, 0.01, 0.005), 0.52, Color(0.1, 0.1, 0.1))
	_mesh(holder, st)

## A painted wall poster board with a slogan (front = +z), centred on `at`.
static func poster(parent: Node3D, node_name: String, at: Vector3, yaw: float, size: Vector2, colour: Color, text: String) -> void:
	var holder := _holder(parent, node_name, at, yaw)
	var st := _begin()
	IndianHouse.box(st, Vector3.ZERO, Vector3(size.x + 0.08, size.y + 0.08, 0.03), Color(0.95, 0.95, 0.92))
	IndianHouse.box(st, Vector3(0, 0, 0.02), Vector3(size.x, size.y, 0.01), colour)
	_mesh(holder, st)
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.004
	label.outline_size = 0
	label.position = Vector3(0, 0, 0.03)
	holder.add_child(label)

## A big hanging bay board (blue with white letters, e.g. "A1") facing +z.
static func bay_number(parent: Node3D, node_name: String, at: Vector3, yaw: float, text: String) -> void:
	var holder := _holder(parent, node_name, at, yaw)
	var st := _begin()
	IndianHouse.box(st, Vector3.ZERO, Vector3(1.0, 0.75, 0.05), SHUTTER)
	IndianHouse.box(st, Vector3(0, -0.34, 0.03), Vector3(1.0, 0.06, 0.02), Color(0.95, 0.55, 0.12))
	for x in [-0.35, 0.35]: IndianHouse.box(st, Vector3(x, 0.55, 0), Vector3(0.02, 0.35, 0.02), STEEL)
	_mesh(holder, st)
	for side in [1, -1]:
		var label := Label3D.new()
		label.text = text
		label.font_size = 120
		label.pixel_size = 0.004
		label.outline_size = 0
		label.position = Vector3(0, 0.02, 0.03 * side)
		label.rotation.y = 0.0 if side == 1 else PI
		holder.add_child(label)
