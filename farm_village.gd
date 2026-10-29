extends RefCounted

# Kisan Gram, the farming village across the Dholkar river, built round the North Road on the
# levelled pad of land_shape.gd (VILLAGE). The playable farm (farm_world.gd and its details) stands
# in the east fields (FARM_OFFSET). Mud-brick huts with tiled roofs and verandas line both sides
# of the road; a village square with a well, a banyan platform and a small shrine sits in the
# middle; irrigation water comes down a canal from the river to the crop fields in the west; a
# cattle shed with cows, haystacks, a water tower, fences and a green entrance sign finish it.
# Everything static is merged into a few meshes; huts, the well, the shed and the tower are solid.
const LandShape := preload("res://land_shape.gd")
const IndianHouse := preload("res://indian_house.gd")
const IndianStreet := preload("res://indian_street.gd")
const ROAD_X := 50.0
const GROUND := 0.1
const MUD := Color(0.8, 0.66, 0.46)
const MUD_DARK := Color(0.64, 0.5, 0.34)
const TILE := Color(0.66, 0.32, 0.2)
const TILE_DARK := Color(0.5, 0.24, 0.15)
const WOOD := Color(0.42, 0.28, 0.16)
const STONE := Color(0.62, 0.6, 0.55)
const HAY := Color(0.86, 0.7, 0.28)
const HUTS_WEST := [-173.0, -183.0, -203.0, -213.0]
const HUTS_EAST := [-173.0, -183.0, -193.0, -203.0, -213.0]

var expansion: Node3D
var town: Node3D
var future: Node3D
var st := SurfaceTool.new()

func build(owner: Node3D) -> void:
	expansion = owner
	town = owner.town
	future = owner.future
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(HUTS_WEST.size()): _hut(Vector3(ROAD_X - 8.3, GROUND, HUTS_WEST[index]), PI / 2.0, index)
	for index in range(HUTS_EAST.size()): _hut(Vector3(ROAD_X + 8.3, GROUND, HUTS_EAST[index]), -PI / 2.0, index + 4)
	_square(Vector3(ROAD_X - 8.3, GROUND, -193.0))
	_fields()
	_canal()
	_cattle_shed(Vector3(ROAD_X + 16.5, GROUND, -181.0))
	_water_tower(Vector3(ROAD_X - 14.0, GROUND, -176.0))
	for stack in [Vector3(ROAD_X + 12.0, GROUND, -168.0), Vector3(ROAD_X + 14.5, GROUND, -167.0), Vector3(ROAD_X - 12.5, GROUND, -207.0)]: _haystack(stack)
	_dirt_track(Vector3(ROAD_X + 3.0, 0.0, -197.5), Vector3(70.0, 0.0, -197.5), 1.8)
	_dirt_track(Vector3(ROAD_X - 3.0, 0.0, -193.0), Vector3(ROAD_X - 5.8, 0.0, -193.0), 1.8)
	var mesh := MeshInstance3D.new()
	mesh.name = "KisanGram"
	mesh.mesh = st.commit()
	mesh.material_override = IndianHouse._material()
	future.add_child(mesh)
	expansion._road_sign("VillageSign", Vector3(ROAD_X + 4.6, 0.1, -168.5), PI, "KISAN GRAM\nFarming village")
	for tree in [Vector3(ROAD_X - 12.0, 0.1, -185.0), Vector3(ROAD_X - 14.5, 0.1, -199.0), Vector3(ROAD_X + 22.0, 0.1, -172.0), Vector3(ROAD_X - 20.0, 0.1, -212.0)]: town._tree(tree)

# --- Geometry helpers (yaw is a multiple of 90 degrees so boxes stay axis-aligned) ---

func _p(origin: Vector3, yaw: float, local: Vector3) -> Vector3:
	return origin + local.rotated(Vector3.UP, yaw)

func _box(origin: Vector3, yaw: float, local_centre: Vector3, size: Vector3, colour: Color) -> void:
	var turned := absf(sin(yaw)) > 0.5
	IndianHouse.box(st, _p(origin, yaw, local_centre), Vector3(size.z, size.y, size.x) if turned else size, colour)

func _solid(node_name: String, origin: Vector3, yaw: float, local_centre: Vector3, size: Vector3) -> void:
	var turned := absf(sin(yaw)) > 0.5
	var centre := _p(origin, yaw, local_centre)
	town._collider(node_name, future, Vector3(size.z, size.y, size.x) if turned else size, centre)

# --- A village hut: mud walls on a stone plinth, a tiled gable roof, a veranda on wooden posts ---

func _hut(origin: Vector3, yaw: float, index: int) -> void:
	var wall := MUD.lerp(Color(0.9, 0.82, 0.62), (index % 3) * 0.2)
	_box(origin, yaw, Vector3(0, 0.125, 0), Vector3(4.9, 0.25, 4.2), STONE)
	_box(origin, yaw, Vector3(0, 1.45, -0.1), Vector3(4.6, 2.4, 3.7), wall)
	# Door and two small windows on the front (+z), a lime-wash band near the base.
	_box(origin, yaw, Vector3(0.9, 1.15, 1.76), Vector3(0.95, 1.8, 0.06), WOOD)
	_box(origin, yaw, Vector3(-1.4, 1.7, 1.76), Vector3(0.6, 0.55, 0.06), Color(0.25, 0.2, 0.15))
	_box(origin, yaw, Vector3(-1.4, 1.7, 1.79), Vector3(0.7, 0.07, 0.07), WOOD)
	_box(origin, yaw, Vector3(0, 0.55, 1.77), Vector3(4.6, 0.5, 0.04), MUD_DARK)
	# Veranda: a low roof on two posts along the front.
	for x in [-2.0, 2.0]: _box(origin, yaw, Vector3(x, 1.3, 2.4), Vector3(0.14, 2.3, 0.14), WOOD)
	_box(origin, yaw, Vector3(0, 2.5, 2.2), Vector3(4.9, 0.1, 1.6), WOOD)
	_box(origin, yaw, Vector3(0, 2.62, 2.2), Vector3(5.1, 0.07, 1.8), TILE_DARK)
	# Gable roof over the house (ridge along its width).
	var a := _p(origin, yaw, Vector3(-2.7, 2.6, 2.2))
	var b := _p(origin, yaw, Vector3(2.7, 2.6, 2.2))
	var c := _p(origin, yaw, Vector3(2.7, 3.85, 0.0))
	var d := _p(origin, yaw, Vector3(-2.7, 3.85, 0.0))
	var up_front := Vector3(0, 1.0, 1.0).rotated(Vector3.UP, yaw).normalized()
	IndianHouse._quad(st, a, b, c, d, up_front, TILE)
	var e := _p(origin, yaw, Vector3(-2.7, 2.6, -2.2))
	var f := _p(origin, yaw, Vector3(2.7, 2.6, -2.2))
	IndianHouse._quad(st, f, e, d, c, Vector3(0, 1.0, -1.0).rotated(Vector3.UP, yaw).normalized(), TILE)
	for end in [-2.5, 2.5]:
		IndianStreet._tri(st, _p(origin, yaw, Vector3(end, 2.6, 2.0)), _p(origin, yaw, Vector3(end, 2.6, -2.0)), _p(origin, yaw, Vector3(end, 3.8, 0.0)), Vector3(end, 0, 0).rotated(Vector3.UP, yaw).normalized(), wall)
		IndianStreet._tri(st, _p(origin, yaw, Vector3(end, 2.6, -2.0)), _p(origin, yaw, Vector3(end, 2.6, 2.0)), _p(origin, yaw, Vector3(end, 3.8, 0.0)), -Vector3(end, 0, 0).rotated(Vector3.UP, yaw).normalized(), wall)
	_box(origin, yaw, Vector3(0, 3.9, 0.0), Vector3(5.5, 0.12, 0.2), TILE_DARK)
	# A chulha chimney on the back, a charpai and a clay pot on the veranda.
	_box(origin, yaw, Vector3(1.2, 3.5, -1.2), Vector3(0.35, 1.0, 0.35), MUD_DARK)
	_box(origin, yaw, Vector3(-1.1, 0.35, 3.0), Vector3(1.3, 0.05, 0.7), WOOD)
	for x in [-1.7, -0.5]: for z in [2.7, 3.3]: _box(origin, yaw, Vector3(x, 0.15, z), Vector3(0.06, 0.3, 0.06), WOOD)
	IndianStreet._ball(st, _p(origin, yaw, Vector3(1.9, 0.5, 2.8)), 0.25, Color(0.7, 0.34, 0.2), 4, 8)
	_solid("VillageHutBody%d" % index, origin, yaw, Vector3(0, 1.8, -0.1), Vector3(4.7, 3.6, 3.8))

# --- The village square: a well, a banyan platform and a small shrine ---

func _square(centre: Vector3) -> void:
	# Well: a stone ring with dark water, two posts and a little roof with a rope pulley.
	var well := centre + Vector3(0, 0, 4.2)
	IndianHouse.cylinder(st, well, 1.0, 0.85, STONE, 14)
	IndianHouse.cylinder(st, well + Vector3(0, 0.84, 0), 0.72, 0.02, Color(0.07, 0.16, 0.22), 14)
	for side in [-1, 1]: IndianHouse.box(st, well + Vector3(side * 0.95, 1.3, 0), Vector3(0.12, 2.0, 0.12), WOOD)
	IndianHouse.box(st, well + Vector3(0, 2.35, 0), Vector3(2.3, 0.12, 0.9), WOOD)
	IndianHouse.box(st, well + Vector3(0, 1.5, 0), Vector3(0.04, 1.6, 0.04), Color(0.55, 0.45, 0.3))
	town._collider("VillageWellBody", future, Vector3(2.0, 1.0, 2.0), well + Vector3(0, 0.5, 0))
	# Banyan platform: a round stone chabutra with a big shade tree.
	var platform := centre + Vector3(0, 0, -1.5)
	IndianHouse.cylinder(st, platform, 2.4, 0.4, STONE, 16)
	IndianHouse.cylinder(st, platform + Vector3(0, 0.4, 0), 2.2, 0.06, Color(0.72, 0.7, 0.66), 16)
	town._tree(platform + Vector3(0, 0.0, 0.0))
	# Shrine: a small saffron mandir with a stepped spire and a flag.
	var shrine := centre + Vector3(-1.5, 0, -6.4)
	IndianHouse.box(st, shrine + Vector3(0, 0.2, 0), Vector3(2.6, 0.4, 2.6), STONE)
	IndianHouse.box(st, shrine + Vector3(0, 1.3, 0), Vector3(1.8, 1.8, 1.8), Color(0.98, 0.62, 0.2))
	IndianHouse.box(st, shrine + Vector3(0, 1.1, 0.91), Vector3(0.7, 1.1, 0.04), Color(0.15, 0.1, 0.08))
	for level in range(4):
		IndianHouse.box(st, shrine + Vector3(0, 2.4 + level * 0.32, 0), Vector3(1.6 - level * 0.34, 0.3, 1.6 - level * 0.34), Color(1.0, 0.7 - level * 0.05, 0.28))
	IndianHouse.box(st, shrine + Vector3(0, 4.0, 0), Vector3(0.05, 0.9, 0.05), WOOD)
	IndianHouse.box(st, shrine + Vector3(0.25, 4.3, 0), Vector3(0.5, 0.3, 0.02), Color(0.9, 0.2, 0.1))
	town._collider("VillageShrineBody", future, Vector3(2.4, 2.4, 2.4), shrine + Vector3(0, 1.2, 0))

# --- Fields in the west, an irrigation canal and a dirt track east to the farm ---

func _fields() -> void:
	var crops := [[Color(0.62, 0.7, 0.22), 0.5, "wheat"], [Color(0.95, 0.8, 0.12), 0.35, "mustard"], [Color(0.28, 0.52, 0.2), 0.9, "sugarcane"]]
	var plots := [Rect2(24.0, -203.0, 15.0, 12.0), Rect2(24.0, -188.0, 15.0, 12.0), Rect2(24.0, -218.0, 15.0, 11.0)]
	for index in range(plots.size()):
		var plot: Rect2 = plots[index]
		var crop: Array = crops[index]
		IndianHouse.box(st, Vector3(plot.get_center().x, GROUND + 0.01, plot.get_center().y), Vector3(plot.size.x, 0.04, plot.size.y), Color(0.38, 0.26, 0.15))
		var row := plot.position.x + 1.0
		while row < plot.end.x - 0.6:
			IndianHouse.box(st, Vector3(row, GROUND + 0.02 + crop[1] / 2.0, plot.get_center().y), Vector3(0.45, crop[1], plot.size.y - 1.2), crop[0])
			row += 1.2
		# A low wooden fence round the plot.
		for side in [plot.position.y, plot.end.y]: IndianHouse.box(st, Vector3(plot.get_center().x, GROUND + 0.45, side), Vector3(plot.size.x, 0.08, 0.08), WOOD)
		for x in range(int(plot.position.x), int(plot.end.x) + 1, 3):
			for z in [plot.position.y, plot.end.y]: IndianHouse.box(st, Vector3(x, GROUND + 0.35, z), Vector3(0.1, 0.7, 0.1), WOOD)
		IndianHouse.box(st, Vector3(plot.position.x + 7.5, GROUND + 0.8, plot.get_center().y - 2.0), Vector3(0.06, 1.6, 0.06), WOOD)
		IndianHouse.box(st, Vector3(plot.position.x + 7.5, GROUND + 1.2, plot.get_center().y - 2.0), Vector3(1.0, 0.07, 0.07), WOOD)
		IndianHouse.box(st, Vector3(plot.position.x + 7.5, GROUND + 1.5, plot.get_center().y - 2.0), Vector3(0.4, 0.4, 0.14), Color(0.8, 0.2, 0.15))

## Irrigation: a narrow water channel from the river's north bank down the west side of the
## fields (water_flow.gdshader), with stone banks.
func _canal() -> void:
	var x := 42.0
	var from_z := LandShape.river_z(x) - 11.5
	var to_z := -224.0
	var length := absf(to_z - from_z)
	var middle := (from_z + to_z) / 2.0
	for side in [-1, 1]: IndianHouse.box(st, Vector3(x + side * 0.85, GROUND + 0.08, middle), Vector3(0.3, 0.2, length), STONE)
	var water := MeshInstance3D.new()
	water.name = "VillageCanal"
	var strip := PlaneMesh.new()
	strip.size = Vector2(1.4, length)
	water.mesh = strip
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/water_flow.gdshader")
	water.material_override = material
	water.position = Vector3(x, GROUND + 0.1, middle)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	future.add_child(water)

func _dirt_track(a: Vector3, b: Vector3, width: float) -> void:
	var centre := (a + b) / 2.0
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	IndianHouse.box(st, Vector3(centre.x, GROUND + 0.005, centre.z), Vector3(absf(b.x - a.x), 0.012, width) if along_x else Vector3(width, 0.012, absf(b.z - a.z)), Color(0.58, 0.46, 0.32))

# --- Cattle shed, haystacks and the water tower ---

func _cattle_shed(at: Vector3) -> void:
	for x in [-3.0, 3.0]:
		for z in [-1.8, 1.8]: IndianHouse.box(st, at + Vector3(x, 1.2, z), Vector3(0.18, 2.4, 0.18), WOOD)
	var a := at + Vector3(-3.6, 2.9, -2.4)
	var b := at + Vector3(3.6, 2.9, -2.4)
	var c := at + Vector3(3.6, 2.3, 2.4)
	var d := at + Vector3(-3.6, 2.3, 2.4)
	IndianHouse._quad(st, a, b, c, d, Vector3(0, 1, 0.2).normalized(), TILE)
	IndianHouse._quad(st, d, c, b, a, Vector3(0, -1, 0), TILE_DARK)
	IndianHouse.box(st, at + Vector3(0, 0.3, -2.0), Vector3(5.6, 0.5, 0.6), WOOD)
	IndianHouse.box(st, at + Vector3(-2.2, 0.35, 0.4), Vector3(1.6, 0.7, 1.4), HAY)
	for index in range(3): _cow(at + Vector3(-1.6 + index * 1.7, 0.0, 1.0), index)
	town._collider("CattleShedBody", future, Vector3(7.0, 2.0, 5.0), at + Vector3(0, 1.0, 0))

func _cow(at: Vector3, index: int) -> void:
	var coat: Color = [Color(0.95, 0.94, 0.9), Color(0.55, 0.36, 0.22), Color(0.2, 0.2, 0.2)][index % 3]
	IndianHouse.box(st, at + Vector3(0, 0.75, 0), Vector3(0.7, 0.65, 1.3), coat)
	IndianHouse.box(st, at + Vector3(0, 0.95, 0.85), Vector3(0.4, 0.4, 0.5), coat)
	IndianHouse.box(st, at + Vector3(0, 0.82, 1.12), Vector3(0.3, 0.22, 0.14), Color(0.95, 0.7, 0.65))
	for x in [-0.22, 0.22]:
		IndianHouse.box(st, at + Vector3(x, 1.22, 0.78), Vector3(0.05, 0.14, 0.05), Color(0.9, 0.88, 0.78))
		for z in [-0.45, 0.45]: IndianHouse.box(st, at + Vector3(x, 0.22, z), Vector3(0.14, 0.45, 0.14), coat.darkened(0.15))

func _haystack(at: Vector3) -> void:
	IndianHouse.cylinder(st, at, 1.1, 1.0, HAY, 10)
	IndianHouse.cylinder(st, at + Vector3(0, 1.0, 0), 0.8, 0.6, HAY.darkened(0.08), 10)
	IndianStreet._ball(st, at + Vector3(0, 1.55, 0), 0.5, HAY.darkened(0.05), 3, 8)

func _water_tower(at: Vector3) -> void:
	for x in [-0.9, 0.9]:
		for z in [-0.9, 0.9]: IndianHouse.box(st, at + Vector3(x, 2.4, z), Vector3(0.2, 4.8, 0.2), Color(0.62, 0.64, 0.66))
	for level in [1.2, 3.0]:
		IndianHouse.box(st, at + Vector3(0, level, 0), Vector3(2.0, 0.1, 0.1), Color(0.55, 0.57, 0.6))
		IndianHouse.box(st, at + Vector3(0, level, 0), Vector3(0.1, 0.1, 2.0), Color(0.55, 0.57, 0.6))
	IndianHouse.cylinder(st, at + Vector3(0, 4.8, 0), 1.5, 1.7, Color(0.28, 0.5, 0.72), 14)
	IndianHouse.cylinder(st, at + Vector3(0, 6.5, 0), 1.2, 0.3, Color(0.22, 0.4, 0.6), 14)
	town._collider("WaterTowerBody", future, Vector3(2.2, 4.8, 2.2), at + Vector3(0, 2.4, 0))
