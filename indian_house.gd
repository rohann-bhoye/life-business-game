extends RefCounted

# Indian town house built from simple parts and merged into ONE vertex-coloured
# mesh per house (one draw call): flat-roof storeys in warm colours, an arched
# door, grilled windows with chajja sunshades, a balcony, a parapet with a black
# water tank and stair room, and clothes drying on the roof. The front faces +z.
const WALLS := [Color(0.93, 0.6, 0.64), Color(0.36, 0.72, 0.72), Color(0.93, 0.74, 0.34), Color(0.82, 0.47, 0.33), Color(0.62, 0.82, 0.66), Color(0.72, 0.62, 0.82), Color(0.56, 0.72, 0.9), Color(0.95, 0.88, 0.74)]
const TRIMS := [Color(0.95, 0.94, 0.9), Color(0.56, 0.16, 0.16), Color(0.95, 0.94, 0.9), Color(0.28, 0.33, 0.4)]
const ACCENTS := [Color(0.1, 0.45, 0.4), Color(0.55, 0.16, 0.16), Color(0.18, 0.28, 0.52), Color(0.6, 0.4, 0.15)]
const CLOTHES := [Color(0.98, 0.55, 0.1), Color(0.85, 0.12, 0.2), Color(0.2, 0.4, 0.8), Color(0.97, 0.97, 0.94), Color(0.2, 0.6, 0.3)]
const GREY := Color(0.62, 0.6, 0.56)
const GLASS := Color(0.22, 0.33, 0.4)
const TANK := Color(0.08, 0.08, 0.09)
const FLOOR_H := 3.0
const PLINTH := 0.3
static var material: StandardMaterial3D

## Builds the house under `parent` as a Node3D named `node_name` at `position`
## (ground level) turned by `yaw`. `size` is the footprint (x width, z depth).
## Options: "balcony" (default true), "storeys" (default from seed).
static func build(parent: Node3D, node_name: String, size: Vector3, position: Vector3, yaw: float, seed: int, options := {}) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = position
	holder.rotation.y = yaw
	parent.add_child(holder)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := size.x - 0.2
	var depth := size.z - 0.2
	var storeys: int = options.get("storeys", 3 if seed % 5 == 3 else 2)
	var wall: Color = WALLS[seed % WALLS.size()]
	var trim: Color = TRIMS[(seed / 2) % TRIMS.size()]
	var accent: Color = ACCENTS[(seed + 1) % ACCENTS.size()]
	var front := depth / 2
	var top := PLINTH + storeys * FLOOR_H
	box(st, Vector3(0, PLINTH / 2, 0), Vector3(width + 0.3, PLINTH, depth + 0.3), GREY)
	for storey in range(storeys):
		var base := PLINTH + storey * FLOOR_H
		box(st, Vector3(0, base + FLOOR_H / 2, 0), Vector3(width, FLOOR_H, depth), wall if storey % 2 == 0 else wall.lightened(0.12))
		box(st, Vector3(0, base + FLOOR_H, 0), Vector3(width + 0.16, 0.2, depth + 0.16), trim)
		var window_y := base + 1.55
		for side in [-1, 1]:
			_window(st, Vector3(side * width / 4.0, window_y, front), trim, accent)
		# Small side windows.
		for side in [-1, 1]:
			box(st, Vector3(side * (width / 2 + 0.02), window_y, -depth / 6), Vector3(0.06, 0.9, 0.8), GLASS)
			box(st, Vector3(side * (width / 2 + 0.2), window_y + 0.55, -depth / 6), Vector3(0.4, 0.07, 1.1), trim)
		if storey == 0:
			_door(st, Vector3(0, PLINTH, front), Vector3(1.1, 2.15, 0), trim, accent)
			box(st, Vector3(0, 0.1, front + 0.45), Vector3(1.7, 0.2, 0.6), GREY)
			box(st, Vector3(0.85, PLINTH + 1.6, front + 0.03), Vector3(0.36, 0.14, 0.03), Color(0.97, 0.96, 0.9))
		else:
			_door(st, Vector3(0, base, front), Vector3(1.0, 2.05, 0), trim, accent)
			if options.get("balcony", true): _balcony(st, Vector3(0, base, front), width * 0.55, accent)
	# Flat roof: parapet, water tank on a stand, stair room, clothes line.
	for side in [-1, 1]:
		box(st, Vector3(side * (width / 2 + 0.01), top + 0.45, 0), Vector3(0.16, 0.7, depth + 0.16), trim)
		box(st, Vector3(0, top + 0.45, side * (depth / 2 + 0.01)), Vector3(width + 0.16, 0.7, 0.16), trim)
	var tank_x := (width / 2 - 1.0) * (1 if seed % 2 == 0 else -1)
	box(st, Vector3(tank_x, top + 0.25, -depth / 2 + 1.0), Vector3(1.3, 0.5, 1.3), GREY)
	cylinder(st, Vector3(tank_x, top + 0.5, -depth / 2 + 1.0), 0.6, 1.2, TANK)
	cylinder(st, Vector3(tank_x, top + 1.7, -depth / 2 + 1.0), 0.22, 0.1, TANK)
	box(st, Vector3(-tank_x, top + 1.1, -depth / 2 + 1.1), Vector3(1.8, 2.2, 2.0), wall.darkened(0.08))
	box(st, Vector3(-tank_x, top + 2.25, -depth / 2 + 1.1), Vector3(2.0, 0.12, 2.2), trim)
	box(st, Vector3(-tank_x, top + 0.95, -depth / 2 + 2.12), Vector3(0.8, 1.8, 0.05), accent)
	_clothes_line(st, Vector3(0, top, depth / 2 - 1.2), minf(width - 2.0, 3.6), seed)
	# AC unit on a side wall.
	box(st, Vector3((width / 2 + 0.17) * (-1 if seed % 2 == 0 else 1), PLINTH + FLOOR_H + 1.9, depth / 4), Vector3(0.3, 0.5, 0.8), Color(0.88, 0.89, 0.88))
	var mesh := MeshInstance3D.new()
	mesh.name = "House"
	mesh.mesh = st.commit()
	mesh.material_override = _material()
	holder.add_child(mesh)
	return holder

static func _material() -> StandardMaterial3D:
	if material == null:
		material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.92
	return material

## Grilled window with a frame, a round arch above it and a chajja sunshade.
static func _window(st: SurfaceTool, center: Vector3, trim: Color, accent: Color) -> void:
	disc(st, Vector3(center.x, center.y + 0.6, center.z + 0.012), 0.6, 0.02, trim)
	box(st, Vector3(center.x, center.y, center.z + 0.02), Vector3(1.3, 1.4, 0.04), trim)
	box(st, Vector3(center.x, center.y, center.z + 0.04), Vector3(1.1, 1.2, 0.03), GLASS)
	for bar in range(-2, 3):
		box(st, Vector3(center.x + bar * 0.2, center.y, center.z + 0.07), Vector3(0.035, 1.18, 0.03), accent)
	box(st, Vector3(center.x, center.y + 0.06, center.z + 0.07), Vector3(1.08, 0.035, 0.03), accent)
	box(st, Vector3(center.x, center.y + 1.0, center.z + 0.26), Vector3(1.6, 0.08, 0.52), trim)

## Wooden door with an arched top in the trim colour.
static func _door(st: SurfaceTool, bottom: Vector3, size: Vector3, trim: Color, accent: Color) -> void:
	disc(st, Vector3(bottom.x, bottom.y + size.y, bottom.z + 0.012), size.x / 2 + 0.12, 0.02, trim)
	box(st, Vector3(bottom.x, bottom.y + size.y / 2 + 0.05, bottom.z + 0.02), Vector3(size.x + 0.24, size.y + 0.1, 0.04), trim)
	box(st, Vector3(bottom.x, bottom.y + size.y / 2, bottom.z + 0.045), Vector3(size.x, size.y, 0.05), accent.darkened(0.15))
	box(st, Vector3(bottom.x, bottom.y + size.y / 2, bottom.z + 0.075), Vector3(0.03, size.y - 0.1, 0.02), accent.lightened(0.25))

static func _balcony(st: SurfaceTool, floor: Vector3, length: float, accent: Color) -> void:
	box(st, Vector3(floor.x, floor.y + 0.08, floor.z + 0.55), Vector3(length, 0.16, 1.1), GREY)
	box(st, Vector3(floor.x, floor.y + 1.0, floor.z + 1.07), Vector3(length, 0.06, 0.06), accent)
	for side in [-1, 1]:
		box(st, Vector3(floor.x + side * length / 2, floor.y + 0.58, floor.z + 0.55), Vector3(0.06, 0.84, 1.1), accent)
	var bars := int(length / 0.2)
	for index in range(bars + 1):
		box(st, Vector3(floor.x - length / 2 + index * length / bars, floor.y + 0.58, floor.z + 1.07), Vector3(0.035, 0.84, 0.035), accent)

static func _clothes_line(st: SurfaceTool, center: Vector3, length: float, seed: int) -> void:
	for side in [-1, 1]:
		box(st, Vector3(center.x + side * length / 2, center.y + 0.8, center.z), Vector3(0.05, 1.6, 0.05), GREY)
	box(st, Vector3(center.x, center.y + 1.55, center.z), Vector3(length, 0.02, 0.02), GREY)
	var count := int(length / 0.7)
	for index in range(count):
		var x := center.x - length / 2 + 0.4 + index * (length - 0.8) / maxf(1, count - 1)
		var cloth: Color = CLOTHES[(seed + index) % CLOTHES.size()]
		var tall := 0.55 if (seed + index) % 3 else 0.9
		box(st, Vector3(x, center.y + 1.53 - tall / 2, center.z), Vector3(0.42, tall, 0.02), cloth)

# --- Geometry: boxes, upright cylinders and discs facing +z, vertex-coloured. ---

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	# Godot draws clockwise triangles (seen from the front) as front faces.
	var points := [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(normal) > 0: points = [a, c, b, a, d, c]
	st.set_color(color)
	st.set_normal(normal)
	for point in points: st.add_vertex(point)

static func box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var x := Vector3(size.x / 2, 0, 0)
	var y := Vector3(0, size.y / 2, 0)
	var z := Vector3(0, 0, size.z / 2)
	_quad(st, center + x - y - z, center + x + y - z, center + x + y + z, center + x - y + z, Vector3.RIGHT, color)
	_quad(st, center - x - y - z, center - x - y + z, center - x + y + z, center - x + y - z, Vector3.LEFT, color)
	_quad(st, center - x + y - z, center - x + y + z, center + x + y + z, center + x + y - z, Vector3.UP, color)
	_quad(st, center - x - y - z, center + x - y - z, center + x - y + z, center - x - y + z, Vector3.DOWN, color)
	_quad(st, center - x - y + z, center + x - y + z, center + x + y + z, center - x + y + z, Vector3.BACK, color)
	_quad(st, center - x - y - z, center - x + y - z, center + x + y - z, center + x - y - z, Vector3.FORWARD, color)

## Upright cylinder standing on `bottom`.
static func cylinder(st: SurfaceTool, bottom: Vector3, radius: float, height: float, color: Color, segments := 14) -> void:
	for index in range(segments):
		var a0 := index * TAU / segments
		var a1 := (index + 1) * TAU / segments
		var p0 := bottom + Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := bottom + Vector3(cos(a1), 0, sin(a1)) * radius
		var up := Vector3(0, height, 0)
		var mid := (a0 + a1) / 2
		_quad(st, p0, p1, p1 + up, p0 + up, Vector3(cos(mid), 0, sin(mid)), color)
		var top := bottom + up
		var tri := [top, p1 + up, p0 + up]
		if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(Vector3.UP) > 0: tri = [top, p0 + up, p1 + up]
		st.set_color(color)
		st.set_normal(Vector3.UP)
		for point in tri: st.add_vertex(point)

## Thin round disc facing +z (used for arches: the door or window hides its lower half).
static func disc(st: SurfaceTool, center: Vector3, radius: float, thickness: float, color: Color, segments := 20) -> void:
	for index in range(segments):
		var a0 := index * TAU / segments
		var a1 := (index + 1) * TAU / segments
		var p0 := center + Vector3(cos(a0), sin(a0), 0) * radius
		var p1 := center + Vector3(cos(a1), sin(a1), 0) * radius
		var front := Vector3(0, 0, thickness / 2)
		var tri := [center + front, p0 + front, p1 + front]
		if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(Vector3.BACK) > 0: tri = [center + front, p1 + front, p0 + front]
		st.set_color(color)
		st.set_normal(Vector3.BACK)
		for point in tri: st.add_vertex(point)
		var mid := (a0 + a1) / 2
		_quad(st, p0 - front, p1 - front, p1 + front, p0 + front, Vector3(cos(mid), sin(mid), 0), color)
