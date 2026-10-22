extends Node3D

# Indian street around the shop: concrete electric poles with sagging wires (a drop
# to the shop, one across the road and one to the mandir), a pani-puri cart with
# its bhaiya and a customer, a white cow resting on the verge, two street dogs and
# a small roadside mandir with a saffron flag. Static parts merge into one
# vertex-coloured mesh (indian_house.gd helpers); the flag, the cow's head and tail
# and the dogs move a little. Built once by neighbourhood.gd, off every route.
const IndianHouse := preload("res://indian_house.gd")
const POLE_Z := 2.45
const POLE_XS := [-28.5, -19.0, -9.5, 1.5, 11.0, 20.5, 30.0]
const ARM_Y := 6.7
const CABLE_Y := 5.2
const CONCRETE := Color(0.7, 0.69, 0.66)
const STEEL := Color(0.78, 0.8, 0.8)
const WIRE := Color(0.06, 0.06, 0.07)
const SAFFRON := Color(1.0, 0.5, 0.08)
const MAROON := Color(0.55, 0.12, 0.1)
const WOOD := Color(0.5, 0.3, 0.16)
const CREAM := Color(0.95, 0.93, 0.87)
const DARK := Color(0.1, 0.08, 0.07)
const GOLD := Color(0.95, 0.72, 0.18)
const CART := Vector3(9.5, 0.1, 1.7)
const MANDIR := Vector3(21.5, 0.1, -1.2)
var town: Node3D
var flag: Node3D
var cow_head: Node3D
var cow_tail: Node3D
var sleeping_dog: Node3D
var sitting_dog_head: Node3D
var time := 0.0

func build(neighbourhood: Node3D) -> void:
	name = "IndianStreet"
	town = neighbourhood
	var st := _begin()
	_poles(st)
	_pani_puri(st, CART)
	_mandir(st, MANDIR)
	_commit(st, self, "StreetMesh")
	_cow(Vector3(15.6, 0.1, 1.5), 0.35)
	sleeping_dog = _sleeping_dog(Vector3(-11.3, 0.1, 2.75), 0.6)
	_sitting_dog(Vector3(-21.1, 0.1, 12.4), PI + 0.5)

func set_quality(quality: int) -> void:
	set_process(quality > 0)

func _process(delta: float) -> void:
	time += delta
	flag.rotation.y = 0.35 + sin(time * 1.7) * 0.3
	flag.rotation.x = sin(time * 3.1) * 0.08
	cow_head.rotation.y = sin(time * 0.35) * 0.3
	cow_head.rotation.z = sin(time * 4.0) * 0.025
	# Tail flicks now and then.
	cow_tail.rotation.x = sin(time * 6.0) * 0.45 * maxf(0.0, sin(time * 0.7))
	sleeping_dog.scale.y = 1.0 + sin(time * 1.6) * 0.04
	sitting_dog_head.rotation.y = sin(time * 0.5) * 0.6

# --- Electric poles and wires ---

func _poles(st: SurfaceTool) -> void:
	for index in POLE_XS.size():
		var base := Vector3(POLE_XS[index], 0.1, POLE_Z)
		# Tapered concrete pole, a steel cross-arm with insulators and a cable bracket.
		IndianHouse.box(st, base + Vector3(0, 1.5, 0), Vector3(0.24, 3.0, 0.24), CONCRETE)
		IndianHouse.box(st, base + Vector3(0, 4.5, 0), Vector3(0.19, 3.0, 0.19), CONCRETE)
		IndianHouse.box(st, base + Vector3(0, 6.6, 0), Vector3(0.15, 1.2, 0.15), CONCRETE)
		IndianHouse.box(st, base + Vector3(0, ARM_Y - 0.1, 0), Vector3(0.12, 0.12, 1.5), Color(0.35, 0.36, 0.37))
		for offset in [-0.6, 0.6]:
			IndianHouse.cylinder(st, base + Vector3(0, ARM_Y - 0.04, offset), 0.05, 0.14, CREAM, 8)
		IndianHouse.cylinder(st, base + Vector3(0, 7.2, 0), 0.05, 0.14, CREAM, 8)
		IndianHouse.box(st, base + Vector3(0, CABLE_Y, 0.13), Vector3(0.06, 0.08, 0.1), Color(0.35, 0.36, 0.37))
		# Red and white danger plate facing the road.
		IndianHouse.box(st, base + Vector3(0, 2.3, 0.125), Vector3(0.2, 0.26, 0.02), Color(0.95, 0.94, 0.9))
		IndianHouse.box(st, base + Vector3(0, 2.36, 0.137), Vector3(0.16, 0.08, 0.01), Color(0.8, 0.1, 0.1))
		town._collider("PoleBody%d" % index, self, Vector3(0.25, 3.0, 0.25), base + Vector3(0, 1.5, 0))
		if index == 0: continue
		var last := Vector3(POLE_XS[index - 1], 0.1, POLE_Z)
		var sag := 0.35 + (index % 3) * 0.08
		for offset in [-0.6, 0.6]:
			_wire(st, last + Vector3(0, ARM_Y + 0.1, offset), base + Vector3(0, ARM_Y + 0.1, offset), sag)
		_wire(st, last + Vector3(0, 7.34, 0), base + Vector3(0, 7.34, 0), sag + 0.1)
		_wire(st, last + Vector3(0, CABLE_Y, 0.16), base + Vector3(0, CABLE_Y, 0.16), 0.75, 0.045)
	# Transformer on one pole, a coil of spare cable on another.
	var transformer := Vector3(POLE_XS[1], 0.1, POLE_Z - 0.4)
	IndianHouse.box(st, transformer + Vector3(0, 4.3, 0), Vector3(0.7, 0.85, 0.5), Color(0.5, 0.53, 0.52))
	for fin in range(-2, 3):
		IndianHouse.box(st, transformer + Vector3(fin * 0.13, 4.25, -0.27), Vector3(0.04, 0.6, 0.06), Color(0.45, 0.48, 0.47))
	for x in [-0.22, 0.0, 0.22]:
		IndianHouse.cylinder(st, transformer + Vector3(x, 4.72, 0), 0.04, 0.18, Color(0.55, 0.32, 0.2), 8)
	IndianHouse.box(st, transformer + Vector3(0, 3.82, 0.15), Vector3(0.9, 0.08, 0.7), Color(0.35, 0.36, 0.37))
	var coil := Vector3(POLE_XS[2] + 0.2, 4.1, POLE_Z + 0.16)
	for loop in range(3):
		var radius := 0.2 + loop * 0.04
		for step in range(12):
			var a0 := step * TAU / 12
			var a1 := (step + 1) * TAU / 12
			_beam(st, coil + Vector3(cos(a0) * radius, sin(a0) * radius * 1.3, loop * 0.03), coil + Vector3(cos(a1) * radius, sin(a1) * radius * 1.3, loop * 0.03), 0.035, WIRE)
	# Service drop to the shop, a wire across the road and one to the mandir.
	_wire(st, Vector3(1.5, CABLE_Y, POLE_Z), Vector3(-0.15, 3.1, 2.3), 0.2, 0.03)
	_wire(st, Vector3(11.0, 7.34, POLE_Z), Vector3(13.0, 6.6, 15.4), 0.55, 0.03)
	_wire(st, Vector3(20.5, CABLE_Y, POLE_Z), MANDIR + Vector3(0.75, 2.2, 0.9), 0.3, 0.03)

func _wire(st: SurfaceTool, a: Vector3, b: Vector3, sag: float, thickness := 0.028) -> void:
	var last := a
	for step in range(1, 11):
		var t := step / 10.0
		var point := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		_beam(st, last, point, thickness, WIRE)
		last = point

# --- Pani-puri cart ---

func _pani_puri(st: SurfaceTool, base: Vector3) -> void:
	# Cycle wheels each side, corner stands, a wooden body with a painted front.
	for side in [-1, 1]:
		_wheel(st, base + Vector3(side * 0.82, 0.42, 0.0), 0.4)
	for corner in [Vector3(-0.7, 0, -0.38), Vector3(0.7, 0, -0.38), Vector3(-0.7, 0, 0.38), Vector3(0.7, 0, 0.38)]:
		_beam(st, base + corner, base + corner + Vector3(0, 0.8, 0), 0.05, Color(0.25, 0.26, 0.27))
	IndianHouse.box(st, base + Vector3(0, 0.95, 0), Vector3(1.5, 0.35, 0.85), WOOD)
	IndianHouse.box(st, base + Vector3(0, 0.95, 0.43), Vector3(1.42, 0.27, 0.02), Color(0.12, 0.38, 0.72))
	IndianHouse.box(st, base + Vector3(0, 0.83, 0.445), Vector3(1.42, 0.04, 0.01), Color(1.0, 0.82, 0.15))
	IndianHouse.box(st, base + Vector3(0, 1.14, 0), Vector3(1.6, 0.04, 0.95), STEEL)
	# Glass case of golden puris at the back (a frame, so the puris show).
	var case := base + Vector3(-0.2, 1.16, -0.18)
	IndianHouse.box(st, case + Vector3(0, 0.01, 0), Vector3(0.95, 0.02, 0.5), Color(0.92, 0.9, 0.82))
	IndianHouse.box(st, case + Vector3(0, 0.56, 0), Vector3(0.99, 0.03, 0.54), STEEL)
	IndianHouse.box(st, case + Vector3(0, 0.28, -0.25), Vector3(0.95, 0.55, 0.02), Color(0.55, 0.68, 0.72))
	for x in [-0.48, 0.48]:
		for z in [-0.25, 0.25]:
			IndianHouse.box(st, case + Vector3(x, 0.28, z), Vector3(0.03, 0.56, 0.03), STEEL)
	for layer in range(3):
		var columns := 7 - layer
		var rows := 4 - layer
		for column in range(columns):
			for row in range(rows):
				var spot := case + Vector3((column - (columns - 1) / 2.0) * 0.12, 0.08 + layer * 0.1, (row - (rows - 1) / 2.0) * 0.11)
				_ball(st, spot, 0.058, Color(0.88, 0.62, 0.25).lerp(Color(0.75, 0.48, 0.18), ((column + row) % 3) / 3.0))
	# Two clay matkas wrapped in wet red cloth, with steel lids; a stack of leaf bowls.
	for z in [-0.2, 0.18]:
		var pot := base + Vector3(0.48, 1.33, z)
		_ball(st, pot, 0.17, Color(0.68, 0.3, 0.15), 6, 10)
		IndianHouse.cylinder(st, pot + Vector3(0, -0.05, 0), 0.173, 0.08, Color(0.78, 0.08, 0.1), 10)
		IndianHouse.cylinder(st, pot + Vector3(0, 0.14, 0), 0.08, 0.06, Color(0.68, 0.3, 0.15), 10)
		IndianHouse.cylinder(st, pot + Vector3(0, 0.2, 0), 0.1, 0.02, STEEL, 10)
	for bowl in range(5):
		IndianHouse.cylinder(st, base + Vector3(-0.15, 1.16 + bowl * 0.02, 0.32), 0.07 - bowl * 0.003, 0.015, Color(0.3, 0.52, 0.2), 10)
	IndianHouse.cylinder(st, base + Vector3(0.12, 1.16, 0.32), 0.09, 0.05, STEEL, 10)
	# Striped tarp on four poles, with a bulb.
	for corner in [Vector3(-0.76, 0, -0.44), Vector3(0.76, 0, -0.44), Vector3(-0.76, 0, 0.44), Vector3(0.76, 0, 0.44)]:
		_beam(st, base + corner + Vector3(0, 1.14, 0), base + corner + Vector3(0, 2.25, 0), 0.035, STEEL)
	for stripe in range(5):
		IndianHouse.box(st, base + Vector3(-0.76 + stripe * 0.38, 2.28, 0), Vector3(0.38, 0.04, 1.3), SAFFRON if stripe % 2 == 0 else Color(0.12, 0.45, 0.28))
		IndianHouse.box(st, base + Vector3(-0.76 + stripe * 0.38, 2.2, 0.66), Vector3(0.38, 0.14, 0.02), Color(0.12, 0.45, 0.28) if stripe % 2 == 0 else SAFFRON)
	_ball(st, base + Vector3(0, 2.12, 0), 0.05, Color(1.0, 0.97, 0.8))
	town._collider("PaniPuriCartBody", self, Vector3(1.9, 1.2, 1.1), base + Vector3(0, 0.6, 0))
	var sign := Label3D.new()
	sign.name = "PaniPuriSign"
	sign.text = "PANI PURI  %s20" % String.chr(8377)
	sign.font_size = 34
	sign.pixel_size = 0.0035
	sign.outline_size = 6
	sign.modulate = Color(1.0, 0.95, 0.75)
	sign.position = base + Vector3(0, 0.95, 0.455)
	add_child(sign)
	_person("PaniPuriWala", "male-b", base + Vector3(0.1, 0, -0.8), 0.0)
	_person("PaniPuriCustomer", "female-c", base + Vector3(-1.25, 0, 0.35), PI / 2 + 0.4)

func _wheel(st: SurfaceTool, center: Vector3, radius: float) -> void:
	for step in range(14):
		var a0 := step * TAU / 14
		var a1 := (step + 1) * TAU / 14
		_beam(st, center + Vector3(0, sin(a0), cos(a0)) * radius, center + Vector3(0, sin(a1), cos(a1)) * radius, 0.05, Color(0.12, 0.12, 0.13))
	for spoke in range(6):
		var angle := spoke * PI / 6
		var reach := Vector3(0, sin(angle), cos(angle)) * radius
		_beam(st, center - reach, center + reach, 0.015, STEEL)

# --- Roadside mandir ---

func _mandir(st: SurfaceTool, base: Vector3) -> void:
	var stone := Color(0.76, 0.73, 0.67)
	IndianHouse.box(st, base + Vector3(0, 0.2, 0), Vector3(2.8, 0.4, 2.8), stone)
	IndianHouse.box(st, base + Vector3(0, 0.1, 1.6), Vector3(1.2, 0.2, 0.4), stone)
	# Sanctum with a maroon base band and a saffron cornice.
	IndianHouse.box(st, base + Vector3(0, 1.25, -0.1), Vector3(1.8, 1.7, 1.8), CREAM)
	IndianHouse.box(st, base + Vector3(0, 0.47, -0.1), Vector3(1.86, 0.14, 1.86), MAROON)
	IndianHouse.box(st, base + Vector3(0, 2.12, -0.1), Vector3(1.94, 0.12, 1.94), SAFFRON)
	# Arched doorway with the deity inside, a garland of marigolds around it.
	var door := base + Vector3(0, 0, 0.8)
	IndianHouse.box(st, door + Vector3(0, 1.1, 0.015), Vector3(0.9, 1.3, 0.03), SAFFRON)
	IndianHouse.disc(st, door + Vector3(0, 1.75, 0.015), 0.45, 0.03, SAFFRON)
	IndianHouse.box(st, door + Vector3(0, 1.05, 0.035), Vector3(0.66, 1.1, 0.02), DARK)
	IndianHouse.disc(st, door + Vector3(0, 1.6, 0.035), 0.33, 0.02, DARK)
	IndianHouse.box(st, door + Vector3(0, 0.78, 0.07), Vector3(0.22, 0.34, 0.06), Color(0.92, 0.32, 0.08))
	_ball(st, door + Vector3(0, 1.02, 0.07), 0.09, Color(0.92, 0.32, 0.08))
	IndianHouse.box(st, door + Vector3(0, 1.11, 0.12), Vector3(0.12, 0.04, 0.02), Color(0.95, 0.85, 0.3))
	for bead in range(15):
		var angle := PI * bead / 14.0
		var colour: Color = SAFFRON if bead % 2 == 0 else Color(1.0, 0.78, 0.1)
		_ball(st, door + Vector3(cos(angle) * 0.5, 1.75 + sin(angle) * 0.5, 0.06), 0.045, colour, 3, 5)
	for side in [-1, 1]:
		for bead in range(5):
			_ball(st, door + Vector3(side * 0.5, 1.68 - bead * 0.13, 0.06), 0.045, SAFFRON if bead % 2 else Color(1.0, 0.78, 0.1), 3, 5)
	# Porch: two pillars, a saffron slab and a brass bell.
	for side in [-0.62, 0.62]:
		IndianHouse.box(st, base + Vector3(side, 1.2, 1.2), Vector3(0.14, 1.6, 0.14), CREAM)
	IndianHouse.box(st, base + Vector3(0, 2.05, 1.05), Vector3(1.5, 0.1, 0.65), SAFFRON)
	_beam(st, base + Vector3(0, 2.0, 1.15), base + Vector3(0, 1.78, 1.15), 0.015, DARK)
	IndianHouse.cylinder(st, base + Vector3(0, 1.64, 1.15), 0.08, 0.14, GOLD, 10)
	# Curved shikhara of shrinking tiers, the amalaka and a gold kalash.
	var top := 2.18
	for tier in range(6):
		var width := lerpf(1.6, 0.36, pow(tier / 5.0, 0.8))
		IndianHouse.box(st, base + Vector3(0, top + 0.16, -0.1), Vector3(width, 0.32, width), CREAM if tier % 2 == 0 else Color(0.97, 0.88, 0.72))
		IndianHouse.box(st, base + Vector3(0, top + 0.31, -0.1), Vector3(width + 0.04, 0.04, width + 0.04), SAFFRON)
		top += 0.32
	IndianHouse.cylinder(st, base + Vector3(0, top, -0.1), 0.24, 0.12, CREAM, 12)
	_ball(st, base + Vector3(0, top + 0.24, -0.1), 0.12, GOLD, 5, 8)
	_beam(st, base + Vector3(0, top + 0.3, -0.1), base + Vector3(0, top + 1.6, -0.1), 0.04, Color(0.4, 0.3, 0.2))
	town._collider("MandirBody", self, Vector3(2.8, 4.0, 2.8), base + Vector3(0, 2.0, 0))
	# Saffron pennant (its own mesh so it can wave) and a lit diya at the door.
	flag = Node3D.new()
	flag.name = "MandirFlag"
	flag.position = base + Vector3(0, top + 1.58, -0.1)
	add_child(flag)
	var cloth := _begin()
	for normal in [Vector3.BACK, Vector3.FORWARD]:
		_tri(cloth, Vector3.ZERO, Vector3(0, -0.42, 0), Vector3(0.8, -0.18, 0), normal, SAFFRON)
	_commit(cloth, flag, "Pennant")
	var diya := MeshInstance3D.new()
	diya.name = "MandirDiya"
	var flame := SphereMesh.new()
	flame.radius = 0.03
	flame.height = 0.08
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.75, 0.3)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.55, 0.12)
	glow.emission_energy_multiplier = 3.0
	flame.material = glow
	diya.mesh = flame
	diya.position = door + Vector3(0.25, 0.5, 0.12)
	add_child(diya)
	_ball(st, door + Vector3(0.25, 0.43, 0.12), 0.05, Color(0.62, 0.3, 0.15), 3, 6)

# --- Animals (rounded blobs, so they read as animals beside the boxy houses) ---

func _cow(base: Vector3, yaw: float) -> void:
	var cow := Node3D.new()
	cow.name = "Cow"
	cow.position = base
	cow.rotation.y = yaw
	add_child(cow)
	var white := Color(0.93, 0.91, 0.86)
	var hoof := Color(0.2, 0.18, 0.17)
	var st := _begin()
	# Lying down: body, belly, the zebu hump and dewlap, a grey patch, folded legs.
	_blob(st, Vector3(0, 0.4, 0), Vector3(0.74, 0.3, 0.35), white, 6, 12)
	_blob(st, Vector3(0, 0.22, 0), Vector3(0.64, 0.2, 0.4), white.darkened(0.03), 5, 12)
	_blob(st, Vector3(0.4, 0.66, 0), Vector3(0.18, 0.15, 0.15), white, 5, 8)
	_blob(st, Vector3(0.66, 0.34, 0), Vector3(0.1, 0.19, 0.07), white.darkened(0.04), 4, 8)
	_blob(st, Vector3(-0.22, 0.47, 0.1), Vector3(0.24, 0.19, 0.27), Color(0.6, 0.58, 0.56), 5, 8)
	for side in [-1, 1]:
		_blob(st, Vector3(0.62, 0.09, side * 0.2), Vector3(0.22, 0.08, 0.08), white.darkened(0.06), 4, 8)
		IndianHouse.box(st, Vector3(0.86, 0.06, side * 0.2), Vector3(0.07, 0.1, 0.11), hoof)
	_blob(st, Vector3(-0.32, 0.13, 0.38), Vector3(0.3, 0.11, 0.09), white.darkened(0.06), 4, 8)
	IndianHouse.box(st, Vector3(0.0, 0.08, 0.42), Vector3(0.07, 0.1, 0.11), hoof)
	_commit(st, cow, "Body")
	cow_head = Node3D.new()
	cow_head.name = "Head"
	cow_head.position = Vector3(0.64, 0.64, 0)
	cow.add_child(cow_head)
	st = _begin()
	_blob(st, Vector3(0.1, 0, 0), Vector3(0.19, 0.16, 0.15), white, 5, 8)
	_blob(st, Vector3(0.36, -0.03, 0), Vector3(0.22, 0.14, 0.14), white, 5, 10)
	_blob(st, Vector3(0.55, -0.09, 0), Vector3(0.08, 0.09, 0.11), Color(0.42, 0.34, 0.34), 4, 8)
	IndianHouse.box(st, Vector3(0.43, 0.105, 0), Vector3(0.06, 0.03, 0.02), Color(0.85, 0.1, 0.1))
	for side in [-1, 1]:
		IndianHouse.box(st, Vector3(0.42, 0.03, side * 0.125), Vector3(0.05, 0.045, 0.02), DARK)
		_blob(st, Vector3(0.24, 0.03, side * 0.19), Vector3(0.05, 0.03, 0.1), white.darkened(0.1), 3, 6)
		# Horns painted saffron, as for a festival.
		_beam(st, Vector3(0.27, 0.1, side * 0.07), Vector3(0.22, 0.33, side * 0.16), 0.045, SAFFRON)
	for bead in range(9):
		var angle := TAU * bead / 9.0
		_ball(st, Vector3(0.06, cos(angle) * 0.16, sin(angle) * 0.155), 0.03, Color(0.85, 0.15, 0.1) if bead % 2 else SAFFRON, 3, 5)
	_commit(st, cow_head, "HeadMesh")
	cow_tail = Node3D.new()
	cow_tail.name = "Tail"
	cow_tail.position = Vector3(-0.72, 0.55, 0)
	cow.add_child(cow_tail)
	st = _begin()
	_beam(st, Vector3.ZERO, Vector3(-0.1, -0.42, 0.22), 0.04, white.darkened(0.05))
	_blob(st, Vector3(-0.1, -0.47, 0.22), Vector3(0.04, 0.07, 0.04), DARK, 3, 5)
	_commit(st, cow_tail, "TailMesh")
	town._collider("CowBody", cow, Vector3(1.7, 0.9, 0.85), Vector3(0.1, 0.45, 0))

func _sleeping_dog(base: Vector3, yaw: float) -> Node3D:
	var dog := Node3D.new()
	dog.name = "SleepingDog"
	dog.position = base
	dog.rotation.y = yaw
	add_child(dog)
	var fur := Color(0.7, 0.52, 0.36)
	var st := _begin()
	# Curled up: body, nose tucked on the front paws, tail around the side.
	_blob(st, Vector3(0, 0.12, 0), Vector3(0.3, 0.11, 0.15), fur, 5, 10)
	_blob(st, Vector3(0.14, 0.04, 0.16), Vector3(0.16, 0.035, 0.04), fur.lightened(0.25), 3, 6)
	_blob(st, Vector3(0.28, 0.09, 0.1), Vector3(0.1, 0.075, 0.085), fur, 4, 8)
	_blob(st, Vector3(0.39, 0.07, 0.12), Vector3(0.065, 0.04, 0.045), fur.darkened(0.25), 3, 6)
	_blob(st, Vector3(0.45, 0.075, 0.125), Vector3(0.015, 0.015, 0.02), DARK, 2, 4)
	for z in [0.05, 0.15]:
		_beam(st, Vector3(0.25, 0.14, z), Vector3(0.23, 0.2, z), 0.045, fur.darkened(0.15))
	_beam(st, Vector3(-0.28, 0.09, 0.03), Vector3(-0.17, 0.06, 0.17), 0.05, fur)
	_beam(st, Vector3(-0.17, 0.06, 0.17), Vector3(0.03, 0.05, 0.19), 0.045, fur.lightened(0.3))
	_commit(st, dog, "DogMesh")
	return dog

func _sitting_dog(base: Vector3, yaw: float) -> void:
	var dog := Node3D.new()
	dog.name = "SittingDog"
	dog.position = base
	dog.rotation.y = yaw
	add_child(dog)
	var fur := Color(0.38, 0.27, 0.19)
	var st := _begin()
	_blob(st, Vector3(-0.1, 0.16, 0), Vector3(0.16, 0.15, 0.15), fur, 5, 10)
	_blob(st, Vector3(0.05, 0.36, 0), Vector3(0.12, 0.2, 0.11), fur, 5, 10)
	_blob(st, Vector3(0.13, 0.38, 0), Vector3(0.05, 0.13, 0.07), Color(0.92, 0.88, 0.8), 4, 6)
	for side in [-1, 1]:
		_beam(st, Vector3(0.12, 0.3, side * 0.06), Vector3(0.15, 0.01, side * 0.06), 0.05, fur)
		_blob(st, Vector3(0.17, 0.02, side * 0.06), Vector3(0.045, 0.025, 0.03), Color(0.92, 0.88, 0.8), 2, 6)
		_blob(st, Vector3(-0.04, 0.06, side * 0.13), Vector3(0.16, 0.06, 0.05), fur.darkened(0.08), 3, 8)
	_beam(st, Vector3(-0.24, 0.16, 0), Vector3(-0.34, 0.32, 0), 0.05, fur)
	_beam(st, Vector3(-0.34, 0.32, 0), Vector3(-0.26, 0.44, 0), 0.05, fur.lightened(0.3))
	_commit(st, dog, "DogMesh")
	sitting_dog_head = Node3D.new()
	sitting_dog_head.name = "Head"
	sitting_dog_head.position = Vector3(0.1, 0.6, 0)
	dog.add_child(sitting_dog_head)
	st = _begin()
	_blob(st, Vector3(0.04, 0.02, 0), Vector3(0.1, 0.09, 0.085), fur, 5, 8)
	_blob(st, Vector3(0.15, -0.01, 0), Vector3(0.07, 0.045, 0.045), fur.darkened(0.3), 4, 6)
	_blob(st, Vector3(0.215, 0.0, 0), Vector3(0.015, 0.015, 0.02), DARK, 2, 4)
	for side in [-1, 1]:
		_beam(st, Vector3(0.0, 0.07, side * 0.05), Vector3(-0.01, 0.17, side * 0.06), 0.045, fur.darkened(0.15))
		_blob(st, Vector3(0.11, 0.04, side * 0.055), Vector3(0.012, 0.012, 0.012), DARK, 2, 4)
	_commit(st, sitting_dog_head, "HeadMesh")

# --- Helpers ---

func _person(node_name: String, model: String, position: Vector3, yaw: float) -> void:
	var person := Node3D.new()
	person.name = node_name
	person.position = position
	person.rotation.y = yaw
	var visual := Node3D.new()
	visual.name = "CharacterVisual"
	visual.set_script(preload("res://character_visual.gd"))
	visual.model = model
	person.add_child(visual)
	add_child(person)

func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func _commit(st: SurfaceTool, parent: Node3D, node_name: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = st.commit()
	mesh.material_override = IndianHouse._material()
	parent.add_child(mesh)

## Square rod from a to b (wires, spokes, horns, legs, poles).
static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var direction := (b - a).normalized()
	var side := direction.cross(Vector3.UP)
	if side.length() < 0.01: side = direction.cross(Vector3.RIGHT)
	side = side.normalized() * thickness / 2
	var up := side.cross(direction).normalized() * thickness / 2
	for face in [[side, up], [-side, up], [up, side], [-up, side]]:
		var normal: Vector3 = face[0]
		var edge: Vector3 = face[1]
		IndianHouse._quad(st, a + normal - edge, b + normal - edge, b + normal + edge, a + normal + edge, normal.normalized(), color)

## One triangle facing `normal` (winding fixed to Godot's clockwise front faces).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	var points := [a, b, c]
	if (b - a).cross(c - a).dot(normal) > 0: points = [a, c, b]
	st.set_color(color)
	st.set_normal(normal)
	for point in points: st.add_vertex(point)

## Low-poly smooth ball (puris, matkas, garland beads, the kalash).
static func _ball(st: SurfaceTool, center: Vector3, radius: float, color: Color, rings := 4, segments := 6) -> void:
	_blob(st, center, Vector3.ONE * radius, color, rings, segments)

## Low-poly smooth ellipsoid with the given radii (animal bodies, heads, snouts).
static func _blob(st: SurfaceTool, center: Vector3, radii: Vector3, color: Color, rings := 4, segments := 6) -> void:
	st.set_color(color)
	for ring in range(rings):
		var lat0 := -PI / 2 + PI * ring / rings
		var lat1 := -PI / 2 + PI * (ring + 1) / rings
		for segment in range(segments):
			var lon0 := TAU * segment / segments
			var lon1 := TAU * (segment + 1) / segments
			var corners := []
			for point in [[lat0, lon0], [lat0, lon1], [lat1, lon1], [lat1, lon0]]:
				corners.append(Vector3(cos(point[0]) * cos(point[1]), sin(point[0]), cos(point[0]) * sin(point[1])))
			for tri in [[corners[0], corners[1], corners[2]], [corners[0], corners[2], corners[3]]]:
				var outward: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
				if (tri[1] - tri[0]).cross(tri[2] - tri[0]).length_squared() < 0.000001: continue
				if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(outward) > 0: tri = [tri[0], tri[2], tri[1]]
				for direction in tri:
					st.set_normal((direction / radii).normalized())
					st.add_vertex(center + direction * radii)
