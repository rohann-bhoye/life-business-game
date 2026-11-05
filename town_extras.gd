extends RefCounted

# Life for the empty land of Dholkarpur Gaon (built by town_expansion.gd after the town plan):
#   Apna Vidyalaya, the village school in the north-west, with its classrooms, a flagpole with
#   the tricolour, a compound wall with a gate, an assembly ground, swings, a slide and a see-saw;
#   Gram Maidan, a cricket ground in the north-east, with a mown oval, a pitch, stumps, a boundary
#   rope, a pavilion with a scoreboard and benches;
#   benches and dustbins at the colony lane mouths.
# Static parts merge into one mesh; the school, the pavilion and the playground frames are solid.
const IndianHouse := preload("res://indian_house.gd")
const IndianStreet := preload("res://indian_street.gd")
const GROUND := 0.1
const SCHOOL_AT := Vector3(-24.0, 0.0, -44.0)
const MAIDAN_AT := Vector3(26.0, 0.0, -40.0)
const CREAM := Color(0.96, 0.92, 0.78)
const SAFFRON := Color(1.0, 0.6, 0.15)
const GREEN := Color(0.12, 0.55, 0.28)
const WHITE := Color(0.96, 0.96, 0.94)
const WOOD := Color(0.42, 0.28, 0.16)
const STEEL := Color(0.45, 0.48, 0.52)

var expansion: Node3D
var town: Node3D
var future: Node3D
var st := SurfaceTool.new()

func build(owner: Node3D) -> void:
	expansion = owner
	town = owner.town
	future = owner.future
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_school(SCHOOL_AT)
	_maidan(MAIDAN_AT)
	for x in [-52.0, 62.5]: _street_furniture(x)
	var mesh := MeshInstance3D.new()
	mesh.name = "TownExtras"
	mesh.mesh = st.commit()
	mesh.material_override = IndianHouse._material()
	future.add_child(mesh)

func _box(centre: Vector3, size: Vector3, colour: Color) -> void:
	IndianHouse.box(st, centre, size, colour)

func _label(node_name: String, text: String, at: Vector3, size: int, colour: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.01
	label.outline_size = 0
	label.modulate = colour
	future.add_child(label)

# --- Apna Vidyalaya: the school ---

func _school(at: Vector3) -> void:
	# The classroom block (26 x 5.4, 4.2 high) facing south, saffron and green bands, a flat roof.
	var block := at + Vector3(0, 0, 0)
	_box(block + Vector3(0, 2.1 + GROUND, 0), Vector3(26.0, 4.2, 5.4), CREAM)
	_box(block + Vector3(0, 4.05 + GROUND, 2.71), Vector3(26.1, 0.3, 0.1), SAFFRON)
	_box(block + Vector3(0, 0.15 + GROUND, 2.71), Vector3(26.1, 0.3, 0.1), GREEN)
	_box(block + Vector3(0, 4.35 + GROUND, 0), Vector3(26.6, 0.3, 5.9), Color(0.7, 0.68, 0.64))
	_box(block + Vector3(0, 4.7 + GROUND, 2.8), Vector3(26.6, 0.5, 0.15), CREAM)
	# Eight classroom windows with shutters and two doors on the front.
	for index in range(8):
		var x := -11.0 + index * 3.14
		if index == 3 or index == 4: continue
		_box(block + Vector3(x, 2.3 + GROUND, 2.72), Vector3(1.6, 1.3, 0.05), Color(0.16, 0.24, 0.4))
		_box(block + Vector3(x, 2.3 + GROUND, 2.76), Vector3(1.8, 0.1, 0.06), WOOD)
		_box(block + Vector3(x, 1.65 + GROUND, 2.76), Vector3(1.8, 0.1, 0.06), WOOD)
	for x in [-1.1, 1.1]: _box(block + Vector3(x, 1.2 + GROUND, 2.74), Vector3(1.5, 2.4, 0.08), WOOD)
	_box(block + Vector3(0, 3.5 + GROUND, 2.74), Vector3(4.2, 0.9, 0.08), GREEN)
	_label("SchoolSign", "APNA VIDYALAYA", block + Vector3(0, 3.5 + GROUND, 2.82), 52, WHITE)
	town._collider("SchoolBody", future, Vector3(26.4, 4.4, 5.6), block + Vector3(0, 2.2 + GROUND, 0))
	# Flagpole with the tricolour in front of the entrance.
	var pole := at + Vector3(-6.5, GROUND, 6.4)
	_box(pole + Vector3(0, 3.0, 0), Vector3(0.12, 6.0, 0.12), STEEL)
	_box(pole + Vector3(0.55, 5.6, 0), Vector3(1.0, 0.22, 0.04), SAFFRON)
	_box(pole + Vector3(0.55, 5.38, 0), Vector3(1.0, 0.22, 0.04), WHITE)
	_box(pole + Vector3(0.55, 5.16, 0), Vector3(1.0, 0.22, 0.04), GREEN)
	_box(pole + Vector3(0, 0.12, 0), Vector3(1.2, 0.24, 1.2), Color(0.7, 0.68, 0.64))
	# The assembly ground (paved) and a low compound wall round the whole school with a gate.
	_box(at + Vector3(0, GROUND + 0.01, 10.0), Vector3(22.0, 0.025, 8.5), Color(0.66, 0.67, 0.65))
	var wall_z := [at.z - 4.0, at.z + 18.0]
	for z in wall_z:
		for x_range in [[-16.5, -2.0], [2.0, 16.5]] if z > at.z else [[-16.5, 16.5]]:
			var length: float = x_range[1] - x_range[0]
			_box(Vector3(at.x + (x_range[0] + x_range[1]) / 2.0, GROUND + 0.55, z), Vector3(length, 1.1, 0.25), CREAM)
			_box(Vector3(at.x + (x_range[0] + x_range[1]) / 2.0, GROUND + 1.15, z), Vector3(length, 0.1, 0.35), SAFFRON)
	for x in [-16.5, 16.5]:
		_box(Vector3(at.x + x, GROUND + 0.55, at.z + 7.0), Vector3(0.25, 1.1, 22.0), CREAM)
		_box(Vector3(at.x + x, GROUND + 1.15, at.z + 7.0), Vector3(0.35, 0.1, 22.0), SAFFRON)
	for side in [-2.0, 2.0]:
		_box(Vector3(at.x + side, GROUND + 1.0, at.z + 18.0), Vector3(0.45, 2.0, 0.45), CREAM)
		_box(Vector3(at.x + side, GROUND + 2.1, at.z + 18.0), Vector3(0.6, 0.2, 0.6), SAFFRON)
	town._collider("SchoolWallN", future, Vector3(33.0, 1.1, 0.3), Vector3(at.x, GROUND + 0.55, at.z - 4.0))
	town._collider("SchoolWallW", future, Vector3(0.3, 1.1, 22.0), Vector3(at.x - 16.5, GROUND + 0.55, at.z + 7.0))
	town._collider("SchoolWallE", future, Vector3(0.3, 1.1, 22.0), Vector3(at.x + 16.5, GROUND + 0.55, at.z + 7.0))
	town._collider("SchoolWallSW", future, Vector3(14.5, 1.1, 0.3), Vector3(at.x - 9.25, GROUND + 0.55, at.z + 18.0))
	town._collider("SchoolWallSE", future, Vector3(14.5, 1.1, 0.3), Vector3(at.x + 9.25, GROUND + 0.55, at.z + 18.0))
	_label("SchoolGate", "VIDYA DAAN", at + Vector3(0, GROUND + 2.5, 18.4), 30, Color(0.3, 0.15, 0.05))
	# Playground in the west corner: swings, a slide and a see-saw (the frames are solid).
	var play := at + Vector3(-11.0, GROUND, 11.0)
	for x in [-1.8, 1.8]: _box(play + Vector3(x, 1.4, 0), Vector3(0.12, 2.8, 0.12), STEEL)
	_box(play + Vector3(0, 2.8, 0), Vector3(4.0, 0.1, 0.1), STEEL)
	for x in [-0.8, 0.8]:
		_box(play + Vector3(x, 1.6, 0), Vector3(0.03, 2.4, 0.03), Color(0.3, 0.3, 0.3))
		_box(play + Vector3(x, 0.45, 0), Vector3(0.6, 0.06, 0.3), Color(0.85, 0.2, 0.15))
	town._collider("SwingFrame", future, Vector3(4.0, 2.8, 0.3), play + Vector3(0, 1.4, 0))
	var slide := at + Vector3(-5.0, GROUND, 11.0)
	for z in [-0.4, 0.4]: _box(slide + Vector3(-0.6, 0.9, z), Vector3(0.08, 1.8, 0.08), Color(0.2, 0.4, 0.8))
	_box(slide + Vector3(-0.6, 1.8, 0), Vector3(0.9, 0.08, 1.0), Color(0.9, 0.7, 0.1))
	IndianHouse._quad(st, slide + Vector3(-0.1, 1.8, -0.4), slide + Vector3(-0.1, 1.8, 0.4), slide + Vector3(2.2, 0.15, 0.4), slide + Vector3(2.2, 0.15, -0.4), Vector3(0.6, 0.8, 0).normalized(), Color(0.95, 0.3, 0.2))
	IndianHouse._quad(st, slide + Vector3(2.2, 0.15, -0.4), slide + Vector3(2.2, 0.15, 0.4), slide + Vector3(-0.1, 1.8, 0.4), slide + Vector3(-0.1, 1.8, -0.4), Vector3(0, -1, 0), Color(0.7, 0.2, 0.15))
	town._collider("SlideBody", future, Vector3(3.0, 1.9, 1.0), slide + Vector3(0.8, 0.95, 0))
	var saw := at + Vector3(-8.0, GROUND, 14.5)
	_box(saw + Vector3(0, 0.3, 0), Vector3(0.2, 0.6, 0.5), STEEL)
	_box(saw + Vector3(0, 0.62, 0), Vector3(3.4, 0.1, 0.35), Color(0.2, 0.55, 0.3))
	# Shade trees round the grounds.
	for tree in [Vector3(at.x - 15.0, 0.1, at.z + 15.0), Vector3(at.x + 15.0, 0.1, at.z + 15.0), Vector3(at.x + 14.0, 0.1, at.z + 4.0), Vector3(at.x - 14.0, 0.1, at.z + 3.0)]: town._tree(tree)

# --- Gram Maidan: the cricket ground ---

func _maidan(at: Vector3) -> void:
	# Mown oval (a flat ellipse made of two stacked discs), the cut pitch and the creases.
	var oval := MeshInstance3D.new()
	oval.name = "MaidanOval"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.012
	disc.radial_segments = 48
	var mown := StandardMaterial3D.new()
	mown.albedo_color = Color(0.46, 0.66, 0.28)
	mown.roughness = 1.0
	disc.material = mown
	oval.mesh = disc
	oval.scale = Vector3(14.5, 1.0, 7.5)
	oval.position = at + Vector3(0, GROUND + 0.004, 0)
	oval.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	future.add_child(oval)
	_box(at + Vector3(0, GROUND + 0.012, 0), Vector3(20.1, 0.012, 2.8), Color(0.74, 0.62, 0.38))
	for end in [-1.0, 1.0]:
		_box(at + Vector3(end * 8.8, GROUND + 0.02, 0), Vector3(0.06, 0.01, 2.6), WHITE)
		for z in [-0.12, 0.0, 0.12]: _box(at + Vector3(end * 10.1, GROUND + 0.38, z), Vector3(0.05, 0.76, 0.05), Color(0.9, 0.82, 0.55))
		_box(at + Vector3(end * 10.1, GROUND + 0.78, 0), Vector3(0.04, 0.04, 0.34), Color(0.9, 0.82, 0.55))
	# Boundary rope: white posts round the ellipse.
	for index in range(40):
		var angle := TAU * index / 40.0
		var point := at + Vector3(cos(angle) * 14.5, GROUND + 0.28, sin(angle) * 7.5)
		_box(point, Vector3(0.1, 0.55, 0.1), WHITE)
	# Pavilion on the south side: a long covered stand with a red roof and a scoreboard.
	var pav := at + Vector3(0, GROUND, 9.2)
	_box(pav + Vector3(0, 0.3, 0), Vector3(9.0, 0.6, 3.6), Color(0.72, 0.7, 0.66))
	for x in [-4.2, -1.4, 1.4, 4.2]: _box(pav + Vector3(x, 1.8, 1.4), Vector3(0.16, 2.4, 0.16), WOOD)
	_box(pav + Vector3(0, 3.1, 0.3), Vector3(9.6, 0.15, 4.2), Color(0.72, 0.18, 0.14))
	_box(pav + Vector3(0, 1.55, -1.6), Vector3(9.0, 2.0, 0.2), CREAM)
	for index in range(4): _box(pav + Vector3(-3.6 + index * 2.4, 0.85, -0.4), Vector3(2.0, 0.1, 0.6), WOOD)
	for index in range(4): _box(pav + Vector3(-3.6 + index * 2.4, 1.2, -1.0), Vector3(2.0, 0.5, 0.1), WOOD)
	_box(pav + Vector3(0, 4.2, -1.4), Vector3(4.0, 1.3, 0.2), Color(0.1, 0.25, 0.14))
	_box(pav + Vector3(0, 3.55, -1.4), Vector3(0.2, 0.7, 0.2), STEEL)
	_label("Scoreboard", "DHOLKARPUR  112/3\nVISITORS  108 all out", pav + Vector3(0, 4.2, -1.28), 24, Color(1.0, 0.95, 0.6))
	town._collider("PavilionBody", future, Vector3(9.2, 3.2, 3.8), pav + Vector3(0, 1.6, 0))
	_label("MaidanSign", "GRAM MAIDAN", at + Vector3(-17.5, GROUND + 2.6, 10.5), 40, Color(0.12, 0.3, 0.18))
	_box(at + Vector3(-17.5, GROUND + 1.3, 10.6), Vector3(0.12, 2.6, 0.12), WOOD)
	_box(at + Vector3(-17.5, GROUND + 2.6, 10.5), Vector3(3.4, 0.8, 0.08), WHITE)
	for tree in [Vector3(at.x - 17.0, 0.1, at.z - 6.0), Vector3(at.x + 17.0, 0.1, at.z - 5.0), Vector3(at.x + 12.0, 0.1, at.z + 11.0)]: town._tree(tree)

# --- Benches and dustbins at the lane mouths ---

func _street_furniture(lane_x: float) -> void:
	for spot in [[-4.2, -3.0, 1.0], [4.2, 13.8, -1.0], [-4.2, 13.8, 1.0], [4.2, -3.0, -1.0]]:
		# West Colony's north-west corner is the home plot and its bays, so that corner has no bench or bin.
		if lane_x < 0.0 and spot[0] < 0.0 and spot[1] < 0.0: continue
		var base := Vector3(lane_x + spot[0], GROUND, spot[1])
		var face: float = spot[2]
		# A park bench facing the lane, and a green wheelie bin beside it (assets/props/street).
		var tag := "%d_%d" % [roundi(base.x), roundi(base.z)]
		town.street_prop("LaneBench" + tag, future, "bench", base, face * PI / 2.0, Vector3(1.6, 0.92, 0.62))
		town.street_prop("LaneBin" + tag, future, "wheelie_bin", base + Vector3(0, 0, 1.6), face * PI / 2.0, Vector3(0.59, 1.07, 0.77))
