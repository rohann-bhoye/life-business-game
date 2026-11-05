extends RefCounted

# A "road closed" barricade where a road leaves the open town: red-and-white striped
# barriers across the road and its pavements, a row of traffic cones on the town side, a
# yellow board on two posts and a blinking amber lamp on each end barrier, with an
# invisible wall just behind so nobody walks or drives on to the unfinished land.
# The barriers, cones and board are one merged mesh. Replaced the old smoke walls.
const IndianHouse := preload("res://indian_house.gd")
const RED := Color(0.8, 0.11, 0.09)
const WHITE := Color(0.95, 0.95, 0.92)
const STEEL := Color(0.24, 0.26, 0.28)
const ORANGE := Color(0.98, 0.43, 0.07)
const YELLOW := Color(0.98, 0.79, 0.13)
const BLACK := Color(0.07, 0.07, 0.08)
const GROUND := 0.11
const BOARD_Z := 0.75

static var lamp_material: StandardMaterial3D

## `point` is the middle of the road where the block stands and `direction` the way out of
## town. Barriers reach `half_width` to each side; `wall_width` 0 builds no wall (another
## wall already seals the road). `tester_only` blocks are left out in admin mode.
static func build(parent: Node3D, point: Vector3, direction: Vector3, label: String, words: String, half_width := 4.6, wall_width := 80.0, tester_only := true) -> Node3D:
	if tester_only and preload("res://admin_mode.gd").enabled(): return null
	var root := Node3D.new()
	root.name = "RoadBlock%s" % label
	root.position = point
	root.rotation.y = atan2(direction.x, direction.z)
	parent.add_child(root)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Barriers about 1.9 m wide, alternately a little forward and back like real ones.
	var count := maxi(2, ceili(half_width / 1.0))
	var span := half_width * 2.0 / count
	for index in range(count):
		_barrier(st, Vector3(-half_width + span * (index + 0.5), 0.0, -0.16 if index % 2 == 0 else 0.16), span - 0.14)
	# A line of cones on the town side.
	var cones := count + 1
	for index in range(cones):
		_cone(st, Vector3(lerpf(-half_width + 0.35, half_width - 0.35, index / float(cones - 1)), 0.0, -1.5))
	_board(st)
	var mesh := MeshInstance3D.new()
	mesh.name = "Barricade"
	mesh.mesh = st.commit()
	mesh.material_override = IndianHouse._material()
	root.add_child(mesh)
	var lines := words.split("\n", false, 1)
	_words(root, "ROAD CLOSED", 80, 1.98)
	if lines.size() > 0: _words(root, lines[0] if lines.size() == 1 else "%s\n%s" % [lines[0], lines[1]], 40 if lines.size() == 1 else 32, 1.6)
	# On top of the outer leg of each end barrier.
	_lamp(root, Vector3(-half_width + 0.17, GROUND + 1.17, -0.16))
	_lamp(root, Vector3(half_width - 0.17, GROUND + 1.17, -0.16 if (count - 1) % 2 == 0 else 0.16))
	if wall_width > 0.0:
		var body := StaticBody3D.new()
		body.name = "RoadBlockWall%s" % label
		body.position = Vector3(0, 7.0, 0.1)
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(wall_width, 16.0, 0.7)
		shape.shape = box
		body.add_child(shape)
		root.add_child(body)
	return root

## A steel barrier stand: two legs on wide feet and two boards striped red and white.
static func _barrier(st: SurfaceTool, at: Vector3, width: float) -> void:
	for side in [-1.0, 1.0]:
		var x: float = at.x + side * (width / 2.0 - 0.1)
		IndianHouse.box(st, Vector3(x, GROUND + 0.56, at.z), Vector3(0.06, 1.1, 0.06), STEEL)
		IndianHouse.box(st, Vector3(x, GROUND + 0.025, at.z), Vector3(0.09, 0.05, 0.62), STEEL)
		IndianHouse.box(st, Vector3(x, GROUND + 0.07, at.z), Vector3(0.2, 0.04, 0.2), BLACK)
	for board in [[0.95, 0.26, 0], [0.56, 0.2, 1]]:
		var parts := maxi(4, roundi(width / 0.32))
		var part := width / parts
		for index in range(parts):
			var colour := RED if (index + board[2]) % 2 == 0 else WHITE
			IndianHouse.box(st, Vector3(at.x - width / 2.0 + part * (index + 0.5), GROUND + board[0], at.z), Vector3(part, board[1], 0.045), colour)

## A traffic cone: black square base, orange body with two white reflective bands.
static func _cone(st: SurfaceTool, at: Vector3) -> void:
	IndianHouse.box(st, Vector3(at.x, GROUND + 0.02, at.z), Vector3(0.4, 0.04, 0.4), BLACK)
	var bottom := Vector3(at.x, GROUND + 0.04, at.z)
	for ring in [[0.16, 0.13, ORANGE], [0.135, 0.09, WHITE], [0.11, 0.12, ORANGE], [0.085, 0.08, WHITE], [0.06, 0.12, ORANGE], [0.032, 0.07, ORANGE]]:
		IndianHouse.cylinder(st, bottom, ring[0], ring[1], ring[2], 12)
		bottom.y += ring[1]

## The yellow board with a black edge on two posts, behind the barriers.
static func _board(st: SurfaceTool) -> void:
	for side in [-1.0, 1.0]:
		IndianHouse.box(st, Vector3(side * 1.25, GROUND + 1.2, BOARD_Z + 0.06), Vector3(0.09, 2.4, 0.09), STEEL)
	IndianHouse.box(st, Vector3(0, GROUND + 1.85, BOARD_Z), Vector3(2.95, 1.25, 0.05), BLACK)
	IndianHouse.box(st, Vector3(0, GROUND + 1.85, BOARD_Z - 0.03), Vector3(2.8, 1.1, 0.02), YELLOW)
	# Red stripe along the bottom of the face.
	IndianHouse.box(st, Vector3(0, GROUND + 1.39, BOARD_Z - 0.045), Vector3(2.8, 0.1, 0.01), RED)

static func _words(root: Node3D, text: String, font_size: int, height: float) -> void:
	var label := Label3D.new()
	label.name = "BoardWords"
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.004
	label.outline_size = 0
	label.modulate = BLACK
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.line_spacing = -4
	label.position = Vector3(0, GROUND + height, BOARD_Z - 0.06)
	# Faces the town (the root's -z).
	label.rotation.y = PI
	root.add_child(label)

## A small amber lamp that blinks once a second.
static func _lamp(root: Node3D, at: Vector3) -> void:
	if lamp_material == null:
		lamp_material = StandardMaterial3D.new()
		lamp_material.albedo_color = Color(1.0, 0.62, 0.1)
		lamp_material.emission_enabled = true
		lamp_material.emission = Color(1.0, 0.55, 0.05)
		lamp_material.emission_energy_multiplier = 2.5
	var lamp := MeshInstance3D.new()
	lamp.name = "AmberLamp"
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.12
	sphere.radial_segments = 10
	sphere.rings = 5
	lamp.mesh = sphere
	lamp.material_override = lamp_material
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.position = at
	root.add_child(lamp)
	var timer := Timer.new()
	timer.wait_time = 0.55
	timer.autostart = true
	timer.timeout.connect(func(): lamp.visible = not lamp.visible)
	lamp.add_child(timer)
