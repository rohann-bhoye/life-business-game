extends Node3D

# Life around the farm field (town_fill.gd builds it): a tube-well pump room with
# a cement water tank, a scarecrow (bijuka) with a clay-pot head, hay stacks,
# stacked gunny sacks, a charpai under the tree and a parked red tractor. The
# static parts are one merged mesh; the water is a separate see-through mesh.
const IndianHouse := preload("res://indian_house.gd")
const Models := preload("res://vehicle_models.gd")
const BRICK := Color(0.66, 0.3, 0.22)
const CEMENT := Color(0.66, 0.65, 0.62)
const WOOD := Color(0.45, 0.28, 0.15)
const HAY := Color(0.86, 0.7, 0.32)
const SACK := Color(0.8, 0.7, 0.5)
var town: Node3D

func build(neighbourhood: Node3D) -> void:
	town = neighbourhood
	name = "FarmDetails"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube_well(st, Vector3(-28.6, 0.1, -13.2))
	_scarecrow(st, Vector3(-30.6, 0.1, -6.5))
	for spot in [Vector3(-30.7, 0.1, -10.6), Vector3(-30.7, 0.1, -2.6)]: _hay(st, spot)
	_sacks(st, Vector3(-15.3, 0.1, -6.4))
	_charpai(st, Vector3(-12.4, 0.1, -6.7))
	var mesh := MeshInstance3D.new()
	mesh.name = "FarmProps"
	mesh.mesh = st.commit()
	mesh.material_override = IndianHouse._material()
	add_child(mesh)
	_water(Vector3(-28.6, 0.1, -13.2))
	var tractor := MeshInstance3D.new()
	tractor.name = "Tractor"
	tractor.mesh = Models.tractor()
	tractor.position = Vector3(-13.8, 0.1, -10.4)
	tractor.rotation.y = PI * 0.92
	add_child(tractor)
	town._collider("TractorBody", self, Vector3(1.7, 1.6, 2.6), Vector3(-13.8, 0.9, -10.4))
	var sign := Label3D.new()
	sign.name = "TractorName"
	sign.text = "KISAN"
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.outline_size = 0
	sign.modulate = Color(1, 0.9, 0.5)
	tractor.add_child(sign)
	sign.position = Vector3(0.34, 0.98, -0.6)
	sign.rotation.y = PI / 2

func _box(st: SurfaceTool, center: Vector3, size: Vector3, colour: Color) -> void:
	IndianHouse.box(st, center, size, colour)

## Brick pump room with a slab roof, a door and the outlet pipe over the tank.
func _tube_well(st: SurfaceTool, at: Vector3) -> void:
	_box(st, at + Vector3(-0.6, 0.55, 0), Vector3(1.0, 1.1, 1.1), BRICK)
	_box(st, at + Vector3(-0.6, 1.14, 0), Vector3(1.2, 0.08, 1.3), CEMENT)
	_box(st, at + Vector3(-0.6, 0.45, 0.56), Vector3(0.5, 0.85, 0.03), Color(0.25, 0.35, 0.45))
	for row in range(4): _box(st, at + Vector3(-0.6, 0.18 + row * 0.26, 0.553), Vector3(1.0, 0.012, 0.01), Color(0.85, 0.82, 0.78))
	# Tank walls around the water, and the pipe pouring into it.
	_box(st, at + Vector3(0.6, 0.06, 0), Vector3(1.2, 0.12, 1.0), CEMENT)
	for z in [-0.47, 0.47]: _box(st, at + Vector3(0.6, 0.3, z), Vector3(1.2, 0.5, 0.06), CEMENT)
	for x in [0.03, 1.17]: _box(st, at + Vector3(x, 0.3, 0), Vector3(0.06, 0.5, 1.0), CEMENT)
	_box(st, at + Vector3(-0.05, 0.85, 0), Vector3(0.5, 0.08, 0.08), Color(0.2, 0.22, 0.24))
	_box(st, at + Vector3(0.22, 0.8, 0), Vector3(0.06, 0.1, 0.1), Color(0.2, 0.22, 0.24))
	town._collider("TubeWellBody", self, Vector3(2.4, 1.2, 1.3), at + Vector3(0, 0.6, 0))

func _water(at: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.55, 0.75, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.05
	for part in [[Vector3(0.6, 0.48, 0), Vector3(1.08, 0.02, 0.88)], [Vector3(0.22, 0.65, 0), Vector3(0.05, 0.32, 0.06)]]:
		var water := MeshInstance3D.new()
		water.name = "Water"
		var box := BoxMesh.new()
		box.size = part[1]
		water.mesh = box
		water.material_override = material
		water.position = at + part[0]
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(water)

## Bijuka: a wooden cross with a kurta, a painted clay pot for a head and a straw hat.
func _scarecrow(st: SurfaceTool, at: Vector3) -> void:
	_box(st, at + Vector3(0, 0.95, 0), Vector3(0.08, 1.9, 0.08), WOOD)
	_box(st, at + Vector3(0, 1.45, 0), Vector3(0.08, 0.08, 1.2), WOOD)
	_box(st, at + Vector3(0, 1.25, 0), Vector3(0.22, 0.6, 0.5), Color(0.95, 0.5, 0.12))
	_box(st, at + Vector3(0, 1.45, 0), Vector3(0.24, 0.12, 1.1), Color(0.95, 0.5, 0.12))
	_box(st, at + Vector3(0, 0.82, 0), Vector3(0.2, 0.3, 0.42), Color(0.95, 0.93, 0.86))
	IndianHouse.cylinder(st, at + Vector3(0, 1.6, 0), 0.17, 0.3, Color(0.72, 0.38, 0.22), 10)
	for z in [-0.06, 0.06]: _box(st, at + Vector3(0.17, 1.78, z), Vector3(0.02, 0.04, 0.04), Color(0.05, 0.05, 0.05))
	_box(st, at + Vector3(0.17, 1.68, 0), Vector3(0.02, 0.02, 0.12), Color(0.85, 0.1, 0.1))
	IndianHouse.cylinder(st, at + Vector3(0, 1.9, 0), 0.32, 0.03, HAY, 12)
	IndianHouse.cylinder(st, at + Vector3(0, 1.93, 0), 0.16, 0.14, HAY, 10)
	town._collider("ScarecrowBody", self, Vector3(0.3, 1.9, 0.3), at + Vector3(0, 0.95, 0))

## A round hay stack: three shrinking tiers and a small top knot.
func _hay(st: SurfaceTool, at: Vector3) -> void:
	for tier in range(3):
		IndianHouse.cylinder(st, at + Vector3(0, tier * 0.42, 0), 0.62 - tier * 0.17, 0.44, HAY.darkened(tier * 0.05), 12)
	IndianHouse.cylinder(st, at + Vector3(0, 1.26, 0), 0.1, 0.2, HAY.darkened(0.2), 8)
	town._collider("HayBody", self, Vector3(1.1, 1.3, 1.1), at + Vector3(0, 0.65, 0))

## Gunny sacks of seed and grain: three below, two on top, one leaning.
func _sacks(st: SurfaceTool, at: Vector3) -> void:
	for index in range(3): _box(st, at + Vector3(0, 0.2, -0.5 + index * 0.5), Vector3(0.36, 0.4, 0.46), SACK.darkened(index * 0.04))
	for index in range(2): _box(st, at + Vector3(0, 0.58, -0.25 + index * 0.5), Vector3(0.34, 0.36, 0.44), SACK.darkened(0.06))
	_box(st, at + Vector3(0.36, 0.25, 0.85), Vector3(0.3, 0.5, 0.4), SACK)
	for index in range(3): _box(st, at + Vector3(0.185, 0.22, -0.5 + index * 0.5), Vector3(0.01, 0.12, 0.2), Color(0.15, 0.4, 0.2))
	town._collider("SacksBody", self, Vector3(0.8, 0.8, 1.9), at + Vector3(0.1, 0.4, 0.15))

## Rope cot (as in home_decor.gd) for the farmer's rest under the tree.
func _charpai(st: SurfaceTool, at: Vector3) -> void:
	for x in [-0.4, 0.4]:
		for z in [-0.9, 0.9]: _box(st, at + Vector3(x, 0.22, z), Vector3(0.07, 0.44, 0.07), WOOD)
	for x in [-0.4, 0.4]: _box(st, at + Vector3(x, 0.42, 0), Vector3(0.06, 0.06, 1.86), WOOD)
	for z in [-0.9, 0.9]: _box(st, at + Vector3(0, 0.42, z), Vector3(0.86, 0.06, 0.06), WOOD)
	_box(st, at + Vector3(0, 0.43, 0), Vector3(0.76, 0.02, 1.76), Color(0.86, 0.77, 0.58))
	for stripe in range(8): _box(st, at + Vector3(0, 0.442, -0.77 + stripe * 0.22), Vector3(0.76, 0.006, 0.05), Color(0.72, 0.6, 0.4))
	town._collider("FarmCharpaiBody", self, Vector3(0.9, 0.46, 1.9), at + Vector3(0, 0.23, 0))
