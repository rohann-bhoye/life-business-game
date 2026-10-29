extends RefCounted

# The planned home colonies of Dholkarpur Gaon (built by town_expansion.gd _houses):
# a West Colony lane (x -52) and an East Colony lane (x 62.5) run north-south and meet the
# Main Road at a crossing. Houses face their lane in tidy rows 10 m apart; each has a
# front garden with a block path from its door to the pavement, and a parking bay in the
# gap beside it (a parked car in every second bay, drivable via car_world.gd).
# Concrete poles with sagging wires follow each lane (a transformer mid-way, a wire
# dropping to every house), street lamps stand on the other pavement, and green signs at
# the lane mouths name the colony.
const IndianHouse := preload("res://indian_house.gd")
const IndianStreet := preload("res://indian_street.gd")
const BlockPath := preload("res://block_path.gd")
const LANE_W := 4.4
const WALK := 1.4
const HOUSE_OFFSET := 8.3
const BAY_LENGTH := 5.2
const BAY_WIDTH := 2.8
const MAIN_ROAD := [4.35, 9.65]
const COLONIES := [
	{"name": "West", "label": "COLONY 1\nWest Lane", "x": -52.0, "far": [-34.0, 44.0],
		"west": [-26.0, -16.0, -6.0, 17.0, 27.0], "east": [-26.0, -16.0, -6.0, 17.0]},
	{"name": "East", "label": "COLONY 2\nEast Lane", "x": 62.5, "far": [-40.0, 44.0],
		"west": [], "east": [-36.0, -26.0, -16.0, -6.0, 17.0, 27.0, 37.0]},
]
const PAVING := Color(0.66, 0.69, 0.67)
const LINE := Color(0.88, 0.88, 0.84)
const BAY_GREY := Color(0.55, 0.56, 0.57)
const CONCRETE := Color(0.72, 0.72, 0.7)
const WIRE := Color(0.06, 0.06, 0.07)

var expansion: Node3D
var town: Node3D
var future: Node3D
## Parking bays with a car: [position, yaw, kind, colour], read by car_world.gd.
var car_spots: Array = []
var details := SurfaceTool.new()
var poles := SurfaceTool.new()
var house_index := 0

func build(owner: Node3D) -> void:
	expansion = owner
	town = owner.town
	future = owner.future
	details.begin(Mesh.PRIMITIVE_TRIANGLES)
	poles.begin(Mesh.PRIMITIVE_TRIANGLES)
	for colony in COLONIES: _colony(colony)
	_commit(details, "ColonyDetails", IndianHouse._material())
	_commit(poles, "ColonyPoles", IndianHouse._material())

func _commit(st: SurfaceTool, node_name: String, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = st.commit()
	mesh.material_override = material
	future.add_child(mesh)

func _colony(colony: Dictionary) -> void:
	var x: float = colony.x
	_lane(colony)
	var pole_zs := [-30.0, -14.0, 0.0, 15.0, 31.0, 44.0] if colony.name == "West" else [-34.0, -18.0, -2.0, 15.0, 31.0, 44.0]
	for index in range(pole_zs.size()): _pole(Vector3(x + 3.35, 0.1, pole_zs[index]), index == 2)
	for index in range(1, pole_zs.size()): _span(Vector3(x + 3.35, 0.1, pole_zs[index - 1]), Vector3(x + 3.35, 0.1, pole_zs[index]))
	for row in [["west", -1], ["east", 1]]:
		for z in colony[row[0]]: _house(colony, x + row[1] * HOUSE_OFFSET, z, -row[1], pole_zs)
	for z in [-22.0, -7.0, 21.0, 37.0]: town._streetlight(Vector3(x - 3.35, 0.1, z), PI / 2.0, false)
	expansion._road_sign("%sColonySignWest" % colony.name, Vector3(x - 4.4, 0.1, 1.2), 0.0, colony.label)
	expansion._road_sign("%sColonySignEast" % colony.name, Vector3(x + 4.4, 0.1, 12.8), PI, colony.label)

## The lane: a road on each side of the Main Road, pavements, edge lines and centre dashes.
func _lane(colony: Dictionary) -> void:
	var x: float = colony.x
	var road_material: Material = expansion._road_material()
	for part in [[colony.far[0], MAIN_ROAD[0]], [MAIN_ROAD[1], colony.far[1]]]:
		var length: float = part[1] - part[0]
		var middle: float = (part[0] + part[1]) / 2.0
		var road: MeshInstance3D = expansion._box("%sLane%d" % [colony.name, roundi(middle)], Vector3(LANE_W, 0.012, length), Vector3(x, 0.112, middle), Color(0.16, 0.18, 0.19), false, future)
		if road_material != null: road.material_override = road_material
		var z0: float = part[0] if part[0] < MAIN_ROAD[0] else part[0] + 1.75
		var z1: float = part[1] if part[1] > MAIN_ROAD[1] else part[1] - 1.75
		for side in [-1, 1]:
			IndianHouse.box(details, Vector3(x + side * (LANE_W / 2.0 + WALK / 2.0), 0.114, (z0 + z1) / 2.0), Vector3(WALK, 0.014, z1 - z0), PAVING)
			IndianHouse.box(details, Vector3(x + side * (LANE_W / 2.0 - 0.2), 0.119, (part[0] + part[1]) / 2.0), Vector3(0.05, 0.008, length), LINE)
		for dash in range(int(length / 4.0)):
			IndianHouse.box(details, Vector3(x, 0.119, part[0] + 2.0 + dash * 4.0), Vector3(0.1, 0.008, 1.8), Color(0.88, 0.86, 0.68))

## A house facing the lane (`toward` is the direction, -1/+1 along x, of the lane from it).
func _house(colony: Dictionary, x: float, z: float, toward: float, pole_zs: Array) -> void:
	var index := house_index
	house_index += 1
	var yaw: float = PI / 2.0 if toward > 0.0 else -PI / 2.0
	IndianHouse.build(future, "TownHouse%d" % index, Vector3(6.4, 0, 5.4), Vector3(x, 0.1, z), yaw, index + 3)
	expansion.town._collider("TownHouseBody%d" % index, future, Vector3(4.8, 4.0, 5.8), Vector3(x, 2.1, z))
	var lane_x: float = colony.x
	var walk_edge: float = lane_x - toward * (LANE_W / 2.0 + WALK)
	# Block path from the door to the pavement.
	BlockPath.lay(future, "TownHousePath%d" % index, Vector2(x + toward * 3.25, z), Vector2(walk_edge, z), 3)
	# Parking bay in the gap on the south side: tarmac with painted lines, open to the lane.
	var bay := Vector3(lane_x - toward * (LANE_W / 2.0 + WALK + BAY_LENGTH / 2.0), 0.0, z + 5.0)
	IndianHouse.box(details, Vector3(bay.x, 0.109, bay.z), Vector3(BAY_LENGTH, 0.012, BAY_WIDTH), BAY_GREY)
	for side in [-1, 1]: IndianHouse.box(details, Vector3(bay.x, 0.118, bay.z + side * BAY_WIDTH / 2.0), Vector3(BAY_LENGTH - 0.2, 0.008, 0.07), LINE)
	IndianHouse.box(details, Vector3(bay.x - toward * (BAY_LENGTH / 2.0 - 0.1), 0.118, bay.z), Vector3(0.07, 0.008, BAY_WIDTH), LINE)
	if index % 2 == 0:
		var kinds := ["hatchback", "sedan", "suv", "pickup"]
		var colours := [Color(0.78, 0.12, 0.14), Color(0.14, 0.28, 0.62), Color(0.9, 0.9, 0.88), Color(0.16, 0.45, 0.28), Color(0.95, 0.75, 0.15), Color(0.35, 0.35, 0.38)]
		car_spots.append([Vector3(bay.x, 0.0, bay.z), -PI / 2.0 * toward, kinds[(index / 2) % kinds.size()], colours[(index / 2) % colours.size()]])
	# The service wire from the nearest pole to the house roof.
	var nearest: float = pole_zs[0]
	for pole_z in pole_zs:
		if absf(pole_z - z) < absf(nearest - z): nearest = pole_z
	IndianStreet._beam(poles, Vector3(lane_x + 3.35, 5.4, nearest), Vector3(x + toward * 1.4, 4.2, z), 0.02, WIRE)

func _pole(base: Vector3, transformer: bool) -> void:
	IndianHouse.box(poles, base + Vector3(0, 1.5, 0), Vector3(0.24, 3.0, 0.24), CONCRETE)
	IndianHouse.box(poles, base + Vector3(0, 4.5, 0), Vector3(0.19, 3.0, 0.19), CONCRETE)
	IndianHouse.box(poles, base + Vector3(0, 6.6, 0), Vector3(0.15, 1.2, 0.15), CONCRETE)
	IndianHouse.box(poles, base + Vector3(0, 6.6, 0), Vector3(1.5, 0.12, 0.12), Color(0.35, 0.36, 0.37))
	for offset in [-0.6, 0.6]: IndianHouse.cylinder(poles, base + Vector3(offset, 6.66, 0), 0.05, 0.14, Color(0.9, 0.88, 0.8), 8)
	IndianHouse.box(poles, base + Vector3(-0.13, 2.3, 0), Vector3(0.02, 0.26, 0.2), Color(0.95, 0.94, 0.9))
	if transformer:
		IndianHouse.cylinder(poles, base + Vector3(0, 4.9, 0.0) + Vector3(0.42, 0, 0), 0.26, 0.7, Color(0.38, 0.4, 0.42), 10)
		IndianHouse.box(poles, base + Vector3(0.21, 5.1, 0), Vector3(0.5, 0.1, 0.1), Color(0.35, 0.36, 0.37))
	expansion.town._collider("ColonyPoleBody", future, Vector3(0.25, 3.0, 0.25), base + Vector3(0, 1.5, 0))

func _span(a: Vector3, b: Vector3) -> void:
	for offset in [-0.6, 0.6]:
		var last := a + Vector3(offset, 6.66, 0)
		for step in range(1, 9):
			var t := step / 8.0
			var point := (a + Vector3(offset, 6.66, 0)).lerp(b + Vector3(offset, 6.66, 0), t) - Vector3(0, 0.45 * 4.0 * t * (1.0 - t), 0)
			IndianStreet._beam(poles, last, point, 0.028, WIRE)
			last = point
