extends RefCounted

# Detailed low-poly Indian street vehicles, each merged into ONE vertex-coloured
# mesh (one draw call): auto-rickshaw, Activa-style scooter, hatchback car and a
# cycle-rickshaw. The front faces -z (like traffic.gd vehicles), ground at y 0.
const IndianHouse := preload("res://indian_house.gd")
const TYRE := Color(0.06, 0.06, 0.07)
const HUB := Color(0.7, 0.72, 0.74)
const BLACK := Color(0.09, 0.09, 0.1)
const GLASS := Color(0.22, 0.32, 0.4)
const CHROME := Color(0.78, 0.8, 0.82)
const PLATE := Color(0.96, 0.96, 0.9)
const PLATE_YELLOW := Color(0.98, 0.84, 0.2)

static func _box(st: SurfaceTool, center: Vector3, size: Vector3, colour: Color) -> void:
	IndianHouse.box(st, center, size, colour)

## A wheel turning about the x axis: tyre, side walls and a hub.
static func _wheel(st: SurfaceTool, center: Vector3, radius: float, width: float, segments := 12) -> void:
	for index in range(segments):
		var a0 := TAU * index / segments
		var a1 := TAU * (index + 1) / segments
		var p0 := Vector3(0, sin(a0), cos(a0)) * radius
		var p1 := Vector3(0, sin(a1), cos(a1)) * radius
		var half := Vector3(width / 2, 0, 0)
		# Tread.
		IndianHouse._quad(st, center + p0 - half, center + p1 - half, center + p1 + half, center + p0 + half, (p0 + p1).normalized(), TYRE)
		# Side walls with a lighter hub ring.
		for side in [-1, 1]:
			var face: Vector3 = center + half * side
			var inner: float = 0.45
			IndianHouse._quad(st, face, face + p0 * inner, face + p1 * inner, face + p1 * inner, Vector3(side, 0, 0), HUB)
			IndianHouse._quad(st, face + p0 * inner, face + p0, face + p1, face + p1 * inner, Vector3(side, 0, 0), TYRE)

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

static func _finish(st: SurfaceTool) -> ArrayMesh:
	var mesh := st.commit()
	mesh.surface_set_material(0, IndianHouse._material())
	return mesh

## Bajaj-style auto: yellow top, green lower body, black canvas hood, three wheels.
static func auto_rickshaw(top := Color(0.98, 0.8, 0.12), lower := Color(0.1, 0.5, 0.26)) -> ArrayMesh:
	var st := _begin()
	_box(st, Vector3(0, 0.42, 0.05), Vector3(1.28, 0.24, 2.3), lower)
	_box(st, Vector3(0, 0.82, 0.48), Vector3(1.3, 0.56, 1.35), lower)
	_box(st, Vector3(0, 1.12, 0.48), Vector3(1.32, 0.06, 1.37), top)
	# Rounded nose: three stepped boxes narrowing to the front.
	_box(st, Vector3(0, 0.78, -0.55), Vector3(1.0, 0.7, 0.5), top)
	_box(st, Vector3(0, 0.76, -0.88), Vector3(0.78, 0.62, 0.26), top)
	_box(st, Vector3(0, 0.74, -1.06), Vector3(0.52, 0.5, 0.14), top)
	_box(st, Vector3(0, 0.5, -1.0), Vector3(0.6, 0.12, 0.32), BLACK)
	# Windscreen with a black frame, wiper and handlebar.
	_box(st, Vector3(0, 1.38, -0.8), Vector3(0.86, 0.5, 0.04), GLASS)
	_box(st, Vector3(0, 1.64, -0.8), Vector3(0.9, 0.05, 0.06), BLACK)
	_box(st, Vector3(0.12, 1.2, -0.83), Vector3(0.28, 0.02, 0.02), BLACK)
	_box(st, Vector3(0, 1.1, -0.62), Vector3(0.7, 0.04, 0.04), CHROME)
	# Black canvas hood on four rods, with a rear panel and a yellow rim.
	_box(st, Vector3(0, 1.78, 0.12), Vector3(1.36, 0.08, 2.0), BLACK)
	_box(st, Vector3(0, 1.74, 0.12), Vector3(1.38, 0.03, 2.02), top)
	for x in [-0.64, 0.64]:
		for z in [-0.78, 1.08]: _box(st, Vector3(x, 1.42, z), Vector3(0.04, 0.7, 0.04), BLACK)
	_box(st, Vector3(0, 1.42, 1.1), Vector3(1.34, 0.62, 0.04), BLACK)
	_box(st, Vector3(0, 1.3, 1.12), Vector3(0.7, 0.22, 0.02), GLASS)
	# Passenger bench and driver seat.
	_box(st, Vector3(0, 0.98, 0.62), Vector3(1.12, 0.12, 0.5), Color(0.25, 0.12, 0.1))
	_box(st, Vector3(0, 1.22, 0.85), Vector3(1.12, 0.36, 0.08), Color(0.25, 0.12, 0.1))
	_box(st, Vector3(0, 1.0, -0.3), Vector3(0.42, 0.1, 0.36), Color(0.25, 0.12, 0.1))
	# Plates, tail lamps and the wheels (one in front, two at the back).
	_box(st, Vector3(0, 0.62, -1.14), Vector3(0.28, 0.1, 0.02), PLATE_YELLOW)
	_box(st, Vector3(0, 0.62, 1.14), Vector3(0.34, 0.12, 0.02), PLATE_YELLOW)
	for x in [-0.5, 0.5]: _box(st, Vector3(x, 0.72, 1.16), Vector3(0.12, 0.1, 0.03), Color(0.85, 0.1, 0.1))
	_wheel(st, Vector3(0, 0.24, -0.98), 0.24, 0.14)
	for x in [-0.62, 0.62]: _wheel(st, Vector3(x, 0.24, 0.72), 0.24, 0.16)
	return _finish(st)

## Activa-style scooter: front apron, floorboard, body panels, seat, mirrors.
static func scooter(colour := Color(0.8, 0.15, 0.15)) -> ArrayMesh:
	var st := _begin()
	_box(st, Vector3(0, 0.78, -0.52), Vector3(0.42, 0.78, 0.16), colour)
	_box(st, Vector3(0, 0.72, -0.6), Vector3(0.3, 0.5, 0.08), colour.darkened(0.15))
	_box(st, Vector3(0, 0.4, -0.12), Vector3(0.36, 0.06, 0.62), Color(0.2, 0.2, 0.22))
	_box(st, Vector3(0, 0.66, 0.36), Vector3(0.4, 0.44, 0.78), colour)
	_box(st, Vector3(0, 0.95, 0.32), Vector3(0.3, 0.1, 0.62), BLACK)
	_box(st, Vector3(0, 0.6, 0.78), Vector3(0.36, 0.14, 0.06), Color(0.85, 0.1, 0.1))
	_box(st, Vector3(0, 0.46, 0.8), Vector3(0.2, 0.1, 0.02), PLATE)
	# Steering column, handlebar with grips and mirrors, head lamp.
	_box(st, Vector3(0, 1.0, -0.56), Vector3(0.08, 0.36, 0.08), colour.darkened(0.2))
	_box(st, Vector3(0, 1.17, -0.56), Vector3(0.62, 0.05, 0.05), CHROME)
	for x in [-0.31, 0.31]:
		_box(st, Vector3(x, 1.17, -0.56), Vector3(0.1, 0.06, 0.06), BLACK)
		_box(st, Vector3(x * 0.8, 1.32, -0.56), Vector3(0.02, 0.25, 0.02), BLACK)
		_box(st, Vector3(x * 0.8, 1.45, -0.56), Vector3(0.1, 0.06, 0.02), CHROME)
	_box(st, Vector3(0, 1.1, -0.64), Vector3(0.22, 0.12, 0.06), CHROME)
	_box(st, Vector3(0, 0.36, -0.62), Vector3(0.16, 0.3, 0.12), Color(0.2, 0.2, 0.22))
	_wheel(st, Vector3(0, 0.2, -0.62), 0.2, 0.1)
	_wheel(st, Vector3(0, 0.2, 0.55), 0.2, 0.11)
	return _finish(st)

## Small hatchback: body, cabin with glass all round, bumpers, lamps, plates.
static func car(colour := Color(0.85, 0.85, 0.88)) -> ArrayMesh:
	var st := _begin()
	_box(st, Vector3(0, 0.56, 0), Vector3(1.64, 0.52, 3.5), colour)
	_box(st, Vector3(0, 0.86, -1.25), Vector3(1.6, 0.1, 0.9), colour)
	_box(st, Vector3(0, 1.12, 0.25), Vector3(1.46, 0.5, 2.0), colour)
	_box(st, Vector3(0, 1.4, 0.25), Vector3(1.4, 0.06, 1.9), colour.darkened(0.05))
	# Glass: side windows, windscreen and rear window.
	_box(st, Vector3(0, 1.13, 0.25), Vector3(1.48, 0.34, 1.7), GLASS)
	_box(st, Vector3(0, 1.12, -0.76), Vector3(1.32, 0.4, 0.05), GLASS)
	_box(st, Vector3(0, 1.12, 1.26), Vector3(1.3, 0.36, 0.05), GLASS)
	for z in [-0.12, 0.62]: _box(st, Vector3(0, 1.13, z), Vector3(1.5, 0.36, 0.06), colour)
	# Bumpers, grille, lamps, plates, mirrors and door handles.
	for z in [-1.78, 1.78]: _box(st, Vector3(0, 0.38, z), Vector3(1.68, 0.18, 0.1), BLACK)
	_box(st, Vector3(0, 0.62, -1.76), Vector3(0.7, 0.14, 0.04), BLACK)
	for x in [-0.6, 0.6]:
		_box(st, Vector3(x, 0.66, -1.76), Vector3(0.3, 0.12, 0.04), Color(0.95, 0.95, 0.85))
		_box(st, Vector3(x, 0.66, 1.76), Vector3(0.26, 0.14, 0.04), Color(0.85, 0.1, 0.1))
		_box(st, Vector3(x * 1.42, 1.0, -0.62), Vector3(0.12, 0.08, 0.06), colour.darkened(0.2))
		_box(st, Vector3(x * 1.37, 0.78, 0.2), Vector3(0.02, 0.03, 0.14), CHROME)
	_box(st, Vector3(0, 0.4, -1.84), Vector3(0.44, 0.12, 0.02), PLATE)
	_box(st, Vector3(0, 0.62, 1.84), Vector3(0.44, 0.12, 0.02), PLATE)
	for x in [-0.78, 0.78]:
		for z in [-1.12, 1.12]: _wheel(st, Vector3(x, 0.3, z), 0.3, 0.2)
	return _finish(st)

## Red farm tractor: bonnet with grille, big rear wheels under mudguards, seat,
## steering wheel, exhaust stack and a hitch.
static func tractor(colour := Color(0.78, 0.12, 0.1)) -> ArrayMesh:
	var st := _begin()
	var engine := Color(0.3, 0.32, 0.34)
	_box(st, Vector3(0, 0.95, -0.6), Vector3(0.66, 0.5, 1.3), colour)
	_box(st, Vector3(0, 0.72, -0.6), Vector3(0.5, 0.3, 1.2), engine)
	_box(st, Vector3(0, 0.95, -1.26), Vector3(0.6, 0.44, 0.04), BLACK)
	for y in [0.82, 0.92, 1.02, 1.12]: _box(st, Vector3(0, y, -1.285), Vector3(0.54, 0.03, 0.02), CHROME)
	for x in [-0.22, 0.22]: _box(st, Vector3(x, 1.1, -1.27), Vector3(0.12, 0.08, 0.03), Color(0.95, 0.95, 0.85))
	_box(st, Vector3(0.24, 1.45, -0.85), Vector3(0.07, 0.6, 0.07), BLACK)
	_box(st, Vector3(0, 0.6, 0.35), Vector3(0.7, 0.3, 0.9), engine)
	for x in [-0.66, 0.66]:
		_box(st, Vector3(x, 1.12, 0.45), Vector3(0.4, 0.06, 0.9), colour)
		_box(st, Vector3(x, 0.9, 0.9), Vector3(0.4, 0.45, 0.06), colour)
	_box(st, Vector3(0, 1.12, 0.5), Vector3(0.42, 0.1, 0.36), BLACK)
	_box(st, Vector3(0, 1.36, 0.68), Vector3(0.42, 0.4, 0.06), BLACK)
	_box(st, Vector3(0, 1.22, -0.05), Vector3(0.05, 0.42, 0.05), BLACK)
	_box(st, Vector3(0, 1.42, -0.1), Vector3(0.36, 0.03, 0.3), BLACK)
	_box(st, Vector3(0, 0.55, 1.0), Vector3(0.2, 0.12, 0.3), Color(0.15, 0.15, 0.16))
	_wheel(st, Vector3(-0.68, 0.56, 0.45), 0.56, 0.32, 14)
	_wheel(st, Vector3(0.68, 0.56, 0.45), 0.56, 0.32, 14)
	for x in [-0.46, 0.46]: _wheel(st, Vector3(x, 0.3, -0.98), 0.3, 0.16)
	return _finish(st)

## Parked cycle-rickshaw: bicycle front, passenger seat and a folding hood.
static func cycle_rickshaw() -> ArrayMesh:
	var st := _begin()
	var frame := Color(0.15, 0.35, 0.6)
	_box(st, Vector3(0, 0.62, -0.55), Vector3(0.05, 0.05, 1.1), frame)
	_box(st, Vector3(0, 0.8, -1.02), Vector3(0.05, 0.4, 0.05), frame)
	_box(st, Vector3(0, 1.02, -1.02), Vector3(0.5, 0.04, 0.04), CHROME)
	_box(st, Vector3(0, 0.95, -0.42), Vector3(0.2, 0.06, 0.26), BLACK)
	_box(st, Vector3(0, 0.78, -0.42), Vector3(0.04, 0.32, 0.04), frame)
	_box(st, Vector3(0, 0.62, 0.35), Vector3(1.0, 0.08, 0.7), frame)
	_box(st, Vector3(0, 0.82, 0.38), Vector3(0.92, 0.14, 0.5), Color(0.75, 0.12, 0.15))
	_box(st, Vector3(0, 1.08, 0.62), Vector3(0.92, 0.4, 0.1), Color(0.75, 0.12, 0.15))
	# Folded hood over the seat (two hoops and a canvas back).
	for z in [0.4, 0.62]: _box(st, Vector3(0, 1.62, z), Vector3(0.96, 0.04, 0.04), BLACK)
	_box(st, Vector3(0, 1.45, 0.66), Vector3(0.96, 0.36, 0.04), Color(0.1, 0.35, 0.2))
	_box(st, Vector3(0, 1.64, 0.52), Vector3(0.96, 0.03, 0.3), Color(0.1, 0.35, 0.2))
	for x in [-0.47, 0.47]: _box(st, Vector3(x, 1.24, 0.6), Vector3(0.03, 0.8, 0.03), BLACK)
	_wheel(st, Vector3(0, 0.33, -1.02), 0.33, 0.05, 14)
	for x in [-0.52, 0.52]: _wheel(st, Vector3(x, 0.33, 0.4), 0.33, 0.06, 14)
	return _finish(st)
