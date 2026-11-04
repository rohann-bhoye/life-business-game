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
		"west": [-26.0, -16.0, 17.0, 27.0], "east": [-26.0, -16.0, -6.0, 17.0]},
	{"name": "East", "label": "COLONY 2\nEast Lane", "x": 62.5, "far": [-40.0, 44.0],
		"west": [], "east": [-36.0, -26.0, -16.0, -6.0, 17.0, 27.0, 37.0]},
]
## Centres and names of the turning circles (road ends); the grass keeps off them.
const TURN_RADIUS := 8.6
const TURNS := [[Vector3(-52.0, 0.0, 49.5), "WestSouth"], [Vector3(-52.0, 0.0, -40.0), "WestNorth"], [Vector3(62.5, 0.0, 50.0), "EastSouth"], [Vector3(62.5, 0.0, -46.0), "EastNorth"], [Vector3(50.0, 0.0, -237.0), "NorthRoad"]]
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
	_road_blocks()
	_streets()
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
	for z in [-22.0, -11.0, 21.0, 37.0]: town._streetlight(Vector3(x - 3.35, 0.1, z), PI / 2.0, false)
	# West Colony's sign stands on the east verge: the west verge beside the Main Road holds the home bays.
	expansion._road_sign("%sColonySignWest" % colony.name, Vector3(x + (4.4 if colony.name == "West" else -4.4), 0.1, 1.2), 0.0, colony.label)
	expansion._road_sign("%sColonySignEast" % colony.name, Vector3(x + 4.4, 0.1, 12.8), PI, colony.label)

## The lane: a road on each side of the Main Road, pavements, edge lines and centre dashes.
func _lane(colony: Dictionary) -> void:
	var x: float = colony.x
	var road_material: Material = expansion._road_material()
	for part in [[colony.far[0], MAIN_ROAD[0]], [MAIN_ROAD[1], colony.far[1]]]:
		var length: float = part[1] - part[0]
		var middle: float = (part[0] + part[1]) / 2.0
		var road: MeshInstance3D = expansion._box("%sLane%d" % [colony.name, roundi(middle)], Vector3(LANE_W, 0.012, length), Vector3(x, 0.111, middle), Color(0.16, 0.18, 0.19), false, future)
		if road_material != null: road.material_override = road_material
		var z0: float = part[0] if part[0] < MAIN_ROAD[0] else part[0] + 1.75
		var z1: float = part[1] if part[1] > MAIN_ROAD[1] else part[1] - 1.75
		for side in [-1, 1]:
			IndianHouse.box(details, Vector3(x + side * (LANE_W / 2.0 + WALK / 2.0), StreetKit.PAVE_Y, (z0 + z1) / 2.0), Vector3(WALK, StreetKit.PAVE_THICK, z1 - z0), PAVING)
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
		var kinds := ["normal1", "volterra", "suv", "normal2", "taxi", "volterra", "sports2", "cop", "sports", "volterra"]
		var colours := [Color(0.78, 0.12, 0.14), Color(0.55, 0.2, 0.7), Color(0.9, 0.9, 0.88), Color(0.16, 0.45, 0.28), Color(0.95, 0.55, 0.1), Color(0.12, 0.12, 0.14), Color(0.14, 0.28, 0.62)]
		var pick: String = kinds[(index / 2) % kinds.size()]
		car_spots.append([Vector3(bay.x, 0.0, bay.z), -PI / 2.0 * toward, pick, Color(0, 0, 0, 0) if pick in ["taxi", "cop"] else colours[(index / 2) % colours.size()]])
	# The service wire from the nearest pole to the house roof.
	var nearest: float = pole_zs[0]
	for pole_z in pole_zs:
		if absf(pole_z - z) < absf(nearest - z): nearest = pole_z
	IndianStreet._beam(poles, Vector3(lane_x + 3.35, 5.4, nearest), Vector3(x + toward * 1.4, 4.2, z), 0.02, WIRE)

## A concrete pole with a cross-arm along `perp` (the direction across the street line),
## two insulators, a danger plate and (once per street) a transformer.
func _pole(base: Vector3, transformer: bool, perp := Vector3(1, 0, 0)) -> void:
	IndianHouse.box(poles, base + Vector3(0, 1.5, 0), Vector3(0.24, 3.0, 0.24), CONCRETE)
	IndianHouse.box(poles, base + Vector3(0, 4.5, 0), Vector3(0.19, 3.0, 0.19), CONCRETE)
	IndianHouse.box(poles, base + Vector3(0, 6.6, 0), Vector3(0.15, 1.2, 0.15), CONCRETE)
	IndianHouse.box(poles, base + Vector3(0, 6.6, 0), Vector3(0.12, 0.12, 0.12) + perp.abs() * 1.4, Color(0.35, 0.36, 0.37))
	for offset in [-0.6, 0.6]: IndianHouse.cylinder(poles, base + perp * offset + Vector3(0, 6.66, 0), 0.05, 0.14, Color(0.9, 0.88, 0.8), 8)
	IndianHouse.box(poles, base + Vector3(0, 2.3, 0) + perp.rotated(Vector3.UP, PI / 2.0) * 0.13, Vector3(0.2, 0.26, 0.2) * perp.rotated(Vector3.UP, PI / 2.0).abs() + Vector3(0.02, 0.26, 0.02), Color(0.95, 0.94, 0.9))
	if transformer:
		IndianHouse.cylinder(poles, base + Vector3(0, 4.9, 0) + perp * 0.42, 0.26, 0.7, Color(0.38, 0.4, 0.42), 10)
		IndianHouse.box(poles, base + perp * 0.21 + Vector3(0, 5.1, 0), Vector3(0.1, 0.1, 0.1) + perp.abs() * 0.4, Color(0.35, 0.36, 0.37))
	expansion.town._collider("StreetPoleBody", future, Vector3(0.25, 3.0, 0.25), base + Vector3(0, 1.5, 0))

func _span(a: Vector3, b: Vector3, perp := Vector3(1, 0, 0)) -> void:
	for offset in [-0.6, 0.6]:
		var last: Vector3 = a + perp * offset + Vector3(0, 6.66, 0)
		for step in range(1, 9):
			var t := step / 8.0
			var point: Vector3 = (a + perp * offset + Vector3(0, 6.66, 0)).lerp(b + perp * offset + Vector3(0, 6.66, 0), t) - Vector3(0, 0.45 * 4.0 * t * (1.0 - t), 0)
			IndianStreet._beam(poles, last, point, 0.028, WIRE)
			last = point

## A line of poles joined by wires, from `a` to `b` every `step` metres (one transformer).
func _pole_line(a: Vector3, b: Vector3, step: float) -> void:
	var count := maxi(1, roundi(a.distance_to(b) / step))
	var direction := (b - a).normalized()
	var perp: Vector3 = direction.rotated(Vector3.UP, PI / 2.0)
	perp = Vector3(absf(perp.x), 0.0, absf(perp.z))
	var last: Vector3 = a
	for index in range(count + 1):
		var point: Vector3 = a.lerp(b, float(index) / count)
		_pole(point, index == count / 2, perp)
		if index > 0: _span(last, point, perp)
		last = point

## Poles and wires along every other street, and turning circles where roads end.
func _streets() -> void:
	# Main Road: the north pavement line the shop's own poles (z 2.45) already use.
	# Split round West Colony: no pole in front of the home bays or in the lane mouth.
	_pole_line(Vector3(-73.0, 0.1, 2.45), Vector3(-62.5, 0.1, 2.45), 10.5)
	_pole_line(Vector3(-47.5, 0.1, 2.45), Vector3(-37.0, 0.1, 2.45), 10.5)
	_pole_line(Vector3(39.5, 0.1, 2.45), Vector3(47.0, 0.1, 2.45), 7.5)
	_pole_line(Vector3(57.5, 0.1, 2.45), Vector3(73.0, 0.1, 2.45), 7.7)
	# Market Street, west kerb, both halves; North Road and its far end; Airport Road;
	# the Back Street behind the shop.
	_pole_line(Vector3(46.2, 0.1, -46.0), Vector3(46.2, 0.1, -2.0), 11.0)
	_pole_line(Vector3(46.2, 0.1, 14.0), Vector3(46.2, 0.1, 58.0), 11.0)
	_pole_line(Vector3(53.8, 0.1, -62.0), Vector3(53.8, 0.1, -120.0), 14.5)
	_pole_line(Vector3(53.8, 0.1, -174.0), Vector3(53.8, 0.1, -228.0), 13.5)
	_pole_line(Vector3(30.0, 0.1, 48.4), Vector3(46.0, 0.1, 48.4), 8.0)
	_pole_line(Vector3(-17.0, 0.1, -23.9), Vector3(29.0, 0.1, -23.9), 11.5)
	# Turning circles (a loop of road round a small green island) at the ends of the lanes
	# and of the North Road, so a car can come about.
	for end in TURNS:
		_turnaround(end[0], end[1])

func _turnaround(centre: Vector3, label: String) -> void:
	var road_material: Material = expansion._road_material()
	var paving := StandardMaterial3D.new()
	paving.albedo_color = PAVING
	# The road comes in from the town side; the North Road is wider than the lanes.
	_kerb_ring(centre, -signf(centre.z), 2.75 if label == "NorthRoad" else LANE_W / 2.0)
	var road := MeshInstance3D.new()
	road.name = "Turn%sRoad" % label
	var disc := CylinderMesh.new()
	disc.top_radius = 7.0
	disc.bottom_radius = 7.0
	disc.height = 0.012
	disc.radial_segments = 40
	disc.material = road_material if road_material is StandardMaterial3D else paving
	road.mesh = disc
	road.material_override = road_material
	road.position = centre + Vector3(0, 0.111, 0)
	future.add_child(road)
	var island := MeshInstance3D.new()
	island.name = "Turn%sIsland" % label
	var grass := CylinderMesh.new()
	grass.top_radius = 2.6
	grass.bottom_radius = 2.6
	grass.height = 0.05
	grass.radial_segments = 24
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.3, 0.5, 0.22)
	grass.material = green
	island.mesh = grass
	island.position = centre + Vector3(0, 0.13, 0)
	future.add_child(island)
	expansion.town._tree(centre + Vector3(0, 0.1, 0))

## The pavement round a turning circle: a flat ring from radius 7 to 8.4 with its kerb
## faces (it used to be a full disc that hid the asphalt), open where the road comes in
## (`toward` is the road's side along z, `opening` its half width) so the asphalt runs on.
func _kerb_ring(centre: Vector3, toward: float, opening: float) -> void:
	var inner := 7.0
	var outer := 8.4
	var low := Vector3(0, 0.1, 0)
	var high := Vector3(0, StreetKit.PAVE_TOP, 0)
	var segments := 72
	var open := []
	for index in range(segments):
		var middle := (index + 0.5) * TAU / segments
		open.append(sin(middle) * toward > 0.0 and absf(cos(middle)) * inner < opening)
	for index in range(segments):
		if open[index]: continue
		var a0 := index * TAU / segments
		var a1 := (index + 1) * TAU / segments
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var middle := Vector3(cos((a0 + a1) / 2.0), 0, sin((a0 + a1) / 2.0))
		IndianHouse._quad(details, centre + d0 * inner + high, centre + d1 * inner + high, centre + d1 * outer + high, centre + d0 * outer + high, Vector3.UP, PAVING)
		IndianHouse._quad(details, centre + d0 * inner + low, centre + d1 * inner + low, centre + d1 * inner + high, centre + d0 * inner + high, -middle, PAVING)
		IndianHouse._quad(details, centre + d0 * outer + low, centre + d1 * outer + low, centre + d1 * outer + high, centre + d0 * outer + high, middle, PAVING)
		# Closed ends beside the road's mouth.
		for end in [[a1, open[(index + 1) % segments], 1.0], [a0, open[(index - 1 + segments) % segments], -1.0]]:
			if not end[1]: continue
			var angle: float = end[0]
			var d := Vector3(cos(angle), 0, sin(angle))
			var side: Vector3 = Vector3(-sin(angle), 0, cos(angle)) * float(end[2])
			IndianHouse._quad(details, centre + d * inner + low, centre + d * outer + low, centre + d * outer + high, centre + d * inner + high, side, PAVING)

## "Road closed" barricades just outside the two welcome gates on the Main Road, where it
## leads out to unfinished land (road_block.gd; admin mode skips them). The North Road is
## already closed at the edge of town (neighbourhood.gd _close_north).
func _road_blocks() -> void:
	var block := preload("res://road_block.gd")
	block.build(future, Vector3(70.0, 0.0, 7.0), Vector3(1, 0, 0), "East", "Aage kaam chalu hai")
	block.build(future, Vector3(-70.0, 0.0, 7.0), Vector3(-1, 0, 0), "West", "Aage kaam chalu hai")
