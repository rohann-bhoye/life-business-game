extends Node3D

# A twin dustbin on a steel stand outside the shop door, like the green WET and
# blue DRY bins on Indian streets: tapered bins with lids and swing pivots, a small
# signboard on top, and a solid body so people walk round it. Built from simple
# meshes, so it costs a few draw calls and needs no model files.

const GREEN := Color(0.16, 0.56, 0.27)
const BLUE := Color(0.13, 0.36, 0.72)
const STEEL := Color(0.62, 0.66, 0.68)

func _ready() -> void:
	for side in [[-0.27, GREEN, "WET"], [0.27, BLUE, "DRY"]]:
		_bin(Vector3(side[0], 0.12, 0), side[1], side[2])
	# The stand: two side posts, a middle post and the top rail the bins swing on.
	for x in [-0.56, 0.0, 0.56]:
		_part("Post", _box_mesh(Vector3(0.045, 1.0, 0.045)), Vector3(x, 0.5, -0.05), STEEL, 0.6)
		_part("Foot", _box_mesh(Vector3(0.09, 0.02, 0.32)), Vector3(x, 0.01, -0.02), STEEL.darkened(0.3), 0.6)
	_part("Rail", _box_mesh(Vector3(1.16, 0.04, 0.04)), Vector3(0, 0.78, -0.05), STEEL, 0.6)
	var board := _part("Board", _box_mesh(Vector3(1.12, 0.22, 0.03)), Vector3(0, 1.1, -0.05), Color(0.97, 0.96, 0.9), 0.0)
	_part("BoardEdge", _box_mesh(Vector3(1.16, 0.03, 0.035)), Vector3(0, 1.225, -0.05), GREEN, 0.0)
	var text := Label3D.new()
	text.name = "BoardText"
	text.text = "KACHRA YAHAN DAALEIN\nKeep your street clean"
	text.font_size = 34
	text.pixel_size = 0.0022
	text.modulate = Color(0.1, 0.2, 0.16)
	text.outline_size = 0
	text.position = Vector3(0, 0, 0.017)
	board.add_child(text)
	var body := StaticBody3D.new()
	body.name = "DustbinBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.25, 0.55)
	shape.shape = box
	shape.position = Vector3(0, 0.62, 0)
	body.add_child(shape)
	add_child(body)

func _bin(at: Vector3, colour: Color, label: String) -> void:
	var bin := Node3D.new()
	bin.name = label.capitalize() + "Bin"
	bin.position = at
	add_child(bin)
	var shell := CylinderMesh.new()
	shell.top_radius = 0.235
	shell.bottom_radius = 0.19
	shell.height = 0.62
	shell.radial_segments = 20
	_part("Shell", shell, Vector3(0, 0.31, 0), colour, 0.0, bin)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.25
	rim.bottom_radius = 0.25
	rim.height = 0.035
	rim.radial_segments = 20
	_part("Rim", rim, Vector3(0, 0.63, 0), colour.darkened(0.25), 0.0, bin)
	var lid := CylinderMesh.new()
	lid.top_radius = 0.2
	lid.bottom_radius = 0.245
	lid.height = 0.06
	lid.radial_segments = 20
	_part("Lid", lid, Vector3(0, 0.675, 0), colour.darkened(0.12), 0.0, bin)
	_part("Handle", _box_mesh(Vector3(0.12, 0.025, 0.03)), Vector3(0, 0.72, 0), Color(0.15, 0.15, 0.15), 0.0, bin)
	# Swing pivots on the rail posts, and a white band with the bin's word.
	for x in [-0.25, 0.25]:
		_part("Pivot", _box_mesh(Vector3(0.05, 0.05, 0.05)), Vector3(x, 0.66, -0.05), STEEL.darkened(0.2), 0.6, bin)
	var band := CylinderMesh.new()
	band.top_radius = 0.222
	band.bottom_radius = 0.214
	band.height = 0.09
	band.radial_segments = 20
	_part("Band", band, Vector3(0, 0.45, 0), Color(0.95, 0.95, 0.92), 0.0, bin)
	var word := Label3D.new()
	word.name = "Word"
	word.text = label
	word.font_size = 32
	word.pixel_size = 0.0024
	word.modulate = colour.darkened(0.35)
	word.outline_size = 0
	word.position = Vector3(0, 0.45, 0.236)
	bin.add_child(word)

func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _part(node_name: String, mesh: Mesh, at: Vector3, colour: Color, metallic: float, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metallic
	material.roughness = 0.45 if metallic > 0.0 else 0.6
	instance.material_override = material
	parent.add_child(instance)
	return instance
