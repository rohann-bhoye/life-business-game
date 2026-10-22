extends Node3D

# Land around the original 64 m town (flat out to x +-74, z -56..60), all open now
# (town_boundary.gd): the main road continues both ways with streetlights and trees,
# the market street (FutureTown, opened at build) has Indian shops, a chai stall,
# more houses and parked autos/scooters, and Airport Road leaves the market street
# west to the cargo terminal (export_world.gd) with a car park. The bus stop sits in
# the old town. Built once by neighbourhood.gd; uses its box/tree/streetlight helpers.
const Models := preload("res://vehicle_models.gd")
const AIRPORT_ROAD_Z := 45.5
const Kenney = preload("res://kenney_assets.gd")
const IndianHouse := preload("res://indian_house.gd")
const MARKET_X := 50.0
const BUS_STOP_X := -24.0
const SHOPS := [
	["CHAI POINT", Color(0.85, 0.45, 0.12)], ["GUPTA MEDICAL", Color(0.1, 0.55, 0.45)],
	["MITHAI HOUSE", Color(0.85, 0.2, 0.35)], ["MOBILE REPAIR", Color(0.2, 0.35, 0.75)],
	["PANI PURI", Color(0.9, 0.7, 0.1)], ["TAILOR", Color(0.5, 0.3, 0.6)],
	["HARDWARE", Color(0.35, 0.4, 0.45)], ["BAKERY", Color(0.75, 0.5, 0.25)],
]
var town: Node3D
# Houses, the market street with its shops, the chai stall and parked vehicles open
# in a later phase: they are built under FutureTown, which is hidden and disabled
# (no collisions) until unlock_future_town(). Roads, lamps and trees stay visible.
var future: Node3D
var people: Array[Node3D] = []

func build(neighbourhood: Node3D) -> void:
	name = "TownExpansion"
	town = neighbourhood
	future = Node3D.new()
	future.name = "FutureTown"
	town.add_child(future)
	_roads()
	_horizon_road()
	_houses()
	_market()
	_chai_stall()
	_bus_stop()
	_vehicles()
	_greenery()
	_airport_road()
	# The market street and its houses are open from the start now.
	unlock_future_town()

func unlock_future_town() -> void:
	future.visible = true
	future.process_mode = Node.PROCESS_MODE_INHERIT

func _box(node_name: String, size: Vector3, position: Vector3, colour: Color, solid := false, parent: Node3D = null) -> MeshInstance3D:
	return town._box(node_name, town if parent == null else parent, size, position, colour, solid)

func _roads() -> void:
	var road_material := _road_material()
	var paving := Color(0.66, 0.69, 0.67)
	for side in [-1, 1]:
		var road := _box("RoadExtension%d" % side, Vector3(43, 0.012, 5.5), Vector3(side * 53.5, 0.111, 7), Color(0.16, 0.18, 0.19))
		if road_material != null: road.material_override = road_material
		_box("NorthPavementExt%d" % side, Vector3(43, 0.014, 1.6), Vector3(side * 53.5, 0.107, 3.4), paving)
		_box("SouthPavementExt%d" % side, Vector3(43, 0.014, 1.6), Vector3(side * 53.5, 0.107, 10.6), paving)
		for z in [4.35, 9.65]: _box("RoadEdgeExt%d_%s" % [side, z], Vector3(43, 0.008, 0.05), Vector3(side * 53.5, 0.124, z), Color(0.83, 0.86, 0.83))
		for step in range(10):
			var x: float = side * (34.0 + step * 4.0)
			_box("LaneMark%s" % x, Vector3(1.8, 0.008, 0.09), Vector3(x, 0.124, 7), Color(0.88, 0.86, 0.68))
	# Market street crossing the main road in the east (future phase).
	for part in [[-21.3, 51.3], [33.8, 48.3]]:
		var road := _box("MarketStreet%s" % part[0], Vector3(5.5, 0.012, part[1]), Vector3(MARKET_X, 0.112, part[0]), Color(0.16, 0.18, 0.19), false, future)
		if road_material != null: road.material_override = road_material
	for side in [-1, 1]:
		_box("MarketPavementN%d" % side, Vector3(1.6, 0.014, 50.0), Vector3(MARKET_X + side * 3.55, 0.107, -22.4), paving, false, future)
		_box("MarketPavementS%d" % side, Vector3(1.6, 0.014, 46.0), Vector3(MARKET_X + side * 3.55, 0.107, 34.4), paving, false, future)
	for stripe in range(7):
		_box("MarketCrossing%d" % stripe, Vector3(2.0, 0.008, 0.28), Vector3(MARKET_X - 5.5, 0.124, 4.8 + stripe * 0.7), Color(0.85, 0.87, 0.83), false, future)
	for x in [-70.0, -58.0, -46.0, 38.0, 62.0, 70.0]:
		town._streetlight(Vector3(x, 0.1, 3.3), 0.0, false)
		town._streetlight(Vector3(x + 1.0, 0.1, 10.7), PI, false)

const Horizon := preload("res://horizon.gd")
const ROAD_Z := 7.0

## Past the future town the road, pavements and markings climb the crest and run
## down the valley (horizon.gd) in 1 m steps; the landscape beside the road is
## lowered to match once it has loaded.
func _horizon_road() -> void:
	var road_material := _road_material()
	var paving := Color(0.66, 0.69, 0.67)
	var line := Color(0.83, 0.86, 0.83)
	for side in [-1, 1]:
		var road := SurfaceTool.new()
		road.begin(Mesh.PRIMITIVE_TRIANGLES)
		var edges := SurfaceTool.new()
		edges.begin(Mesh.PRIMITIVE_TRIANGLES)
		for step in range(50):
			var x0: float = side * (Horizon.START + step)
			var x1: float = side * (Horizon.START + step + 1.0)
			_slope_strip(road, x0, x1, 4.25, 9.75, 0.117, Color.WHITE)
			_slope_strip(edges, x0, x1, 2.6, 4.2, 0.114, paving)
			_slope_strip(edges, x0, x1, 9.8, 11.4, 0.114, paving)
			for z in [4.35, 9.65]: _slope_strip(edges, x0, x1, z - 0.025, z + 0.025, 0.124, line)
			if step % 4 < 2: _slope_strip(edges, x0, x1, 6.955, 7.045, 0.124, Color(0.88, 0.86, 0.68))
		for part in [[road, road_material, "HorizonRoad"], [edges, IndianHouse._material(), "HorizonPavements"]]:
			var mesh := MeshInstance3D.new()
			mesh.name = "%s%d" % [part[2], side]
			mesh.mesh = part[0].commit()
			mesh.material_override = part[1]
			town.add_child(mesh)
	call_deferred("_lower_valley")

## The town road's asphalt (shop_presentation.gd builds it; the main Road node only
## gets it later in that node's _ready, so ask the builder directly).
func _road_material() -> Material:
	var presentation := town.get_parent().get_node_or_null("ShopPresentation")
	if presentation != null and presentation.has_method("surface"): return presentation.surface(Vector2(0, 0.5), 3.0)
	return town.get_parent().get_node("Road").material_override

## A flat strip across the road from z0 to z1 between x0 and x1, following the hill.
func _slope_strip(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float, colour: Color) -> void:
	var y0 := y + Horizon.height(x0)
	var y1 := y + Horizon.height(x1)
	var normal := Vector3(-Horizon.slope((x0 + x1) / 2.0), 1.0, 0.0).normalized()
	IndianHouse._quad(st, Vector3(x0, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y0, z1), normal, colour)

## Lowers the landscape along the road into the valley, blending back to the
## original hills 45 m to each side.
func _lower_valley() -> void:
	var landscape := town.get_parent().get_node_or_null("Landscape")
	if landscape == null or landscape.get_class() != "Terrain3D": return
	var data = landscape.data
	for side in [-1, 1]:
		for step in range(53):
			var x: float = side * (Horizon.START + step)
			for z in range(int(ROAD_Z) - 45, int(ROAD_Z) + 46):
				var weight := 1.0 - smoothstep(6.0, 45.0, absf(z - ROAD_Z))
				var point := Vector3(x, 0, z)
				data.set_height(point, lerpf(data.get_height(point), 0.06 + Horizon.height(x), weight))
	data.update_maps()

## Airport Road: from the market street (x 50) west to the cargo terminal yard
## (x 30), asphalt with edge lines and dashes, a footpath with lamps on the north
## side, green APNA AIRPORT signs on the main road and at the turn, and a small car
## park north of the road with two parked cars.
func _airport_road() -> void:
	var road_material := _road_material()
	var paving := Color(0.66, 0.69, 0.67)
	var white := Color(0.85, 0.87, 0.83)
	var z := AIRPORT_ROAD_Z
	var road := _box("AirportRoad", Vector3(17.3, 0.012, 5.5), Vector3(38.6, 0.112, z), Color(0.16, 0.18, 0.19))
	if road_material != null: road.material_override = road_material
	for edge in [z - 2.6, z + 2.6]: _box("AirportRoadEdge%d" % roundi(edge), Vector3(17.3, 0.008, 0.08), Vector3(38.6, 0.124, edge), white)
	for step in range(5): _box("AirportRoadDash%d" % step, Vector3(1.8, 0.008, 0.1), Vector3(32.2 + step * 3.4, 0.124, z), Color(0.88, 0.86, 0.68))
	_box("AirportRoadPavement", Vector3(15.6, 0.014, 1.4), Vector3(37.8, 0.107, z - 3.45), paving)
	for x in [33.0, 40.0]: town._streetlight(Vector3(x, 0.1, z - 3.5), 0.0, false)
	# Car park north of the road, by the control tower.
	_box("AirportCarPark", Vector3(10.0, 0.014, 6.0), Vector3(36.0, 0.109, z - 7.2), Color(0.58, 0.59, 0.58))
	for bay in range(5): _box("ParkingLine%d" % bay, Vector3(0.1, 0.008, 4.2), Vector3(31.6 + bay * 2.2, 0.122, z - 7.5), white)
	for car in [[Vector3(32.7, 0.1, z - 7.4), Color(0.85, 0.2, 0.18)], [Vector3(37.1, 0.1, z - 7.4), Color(0.2, 0.4, 0.8)]]:
		var model := MeshInstance3D.new()
		model.name = "ParkedCar"
		model.mesh = Models.car(car[1])
		model.position = car[0]
		model.rotation.y = PI / 2
		town.add_child(model)
		town._collider("ParkedCarBody", town, Vector3(1.9, 1.5, 4.0), car[0] + Vector3(0, 0.75, 0))
	_road_sign("AirportSignMain", Vector3(45.2, 0.1, 12.6), -PI / 2, "APNA AIRPORT\nCargo terminal - turn south")
	_road_sign("AirportSignTurn", Vector3(46.0, 0.1, 40.2), PI, "APNA AIRPORT\nturn right")

## A green road sign on two posts with white words (front +z, turned by `yaw`).
func _road_sign(node_name: String, at: Vector3, yaw: float, words: String) -> void:
	var sign := Node3D.new()
	sign.name = node_name
	sign.position = at
	sign.rotation.y = yaw
	town.add_child(sign)
	for x in [-0.9, 0.9]: _box("Post", Vector3(0.08, 2.6, 0.08), Vector3(x, 1.3, 0), Color(0.6, 0.62, 0.64), false, sign)
	_box("Board", Vector3(2.4, 1.0, 0.06), Vector3(0, 2.3, 0), Color(0.05, 0.42, 0.22), false, sign)
	_box("Border", Vector3(2.3, 0.9, 0.01), Vector3(0, 2.3, 0.035), Color(0.92, 0.95, 0.92), false, sign)
	_box("Inner", Vector3(2.2, 0.8, 0.01), Vector3(0, 2.3, 0.04), Color(0.05, 0.42, 0.22), false, sign)
	var label := Label3D.new()
	label.text = words
	label.position = Vector3(0, 2.3, 0.05)
	label.font_size = 44
	label.pixel_size = 0.004
	label.outline_size = 0
	sign.add_child(label)

func _houses() -> void:
	var spots := [
		# [x, z, yaw] — north side faces the road (+z), south side faces it (-z).
		[-40.0, -6.0, 0.0], [-50.0, -6.0, 0.0], [-60.0, -6.0, 0.0], [-70.0, -6.0, 0.0],
		[-40.0, 18.0, PI], [-52.0, 18.0, PI], [-64.0, 18.0, PI],
		[36.0, -6.0, 0.0], [64.0, -6.0, 0.0], [71.0, -16.0, 0.0],
		[38.0, 19.0, PI], [64.0, 19.0, PI], [71.0, 30.0, PI],
		[-46.0, -24.0, 0.0], [-62.0, -24.0, 0.0], [-36.0, 34.0, PI],
	]
	for index in range(spots.size()):
		var spot: Array = spots[index]
		IndianHouse.build(future, "TownHouse%d" % index, Vector3(6.4, 0, 5.4), Vector3(spot[0], 0.1, spot[1]), spot[2], index + 3)
		town._collider("TownHouseBody%d" % index, future, Vector3(5.8, 4.0, 4.8), Vector3(spot[0], 2.1, spot[1]))
		# Short garden path from the pavement to each front door.
		var front: float = spot[1] + (2.9 if spot[2] == 0.0 else -2.9)
		var pavement: float = 2.6 if spot[2] == 0.0 else 11.4
		if absf(front - pavement) < 14.0:
			_box("TownHousePath%d" % index, Vector3(1.4, 0.016, absf(front - pavement)), Vector3(spot[0], 0.108, (front + pavement) / 2.0), Color(0.72, 0.73, 0.7), false, future)

## A small Indian shop: coloured facade, half-open shutter, sign and awning.
func _shop(index: int, position: Vector3, facing: float) -> void:
	var entry: Array = SHOPS[index]
	var shop := Node3D.new()
	shop.name = "MarketShop%d" % index
	shop.position = position
	shop.rotation.y = facing
	future.add_child(shop)
	var wall := Color(0.93, 0.88, 0.78) if index % 2 == 0 else Color(0.88, 0.9, 0.84)
	town._box("Body", shop, Vector3(5.0, 3.4, 5.0), Vector3(0, 1.7, -2.5), wall, true)
	town._box("Roof", shop, Vector3(5.3, 0.18, 5.3), Vector3(0, 3.45, -2.5), Color(0.4, 0.38, 0.36))
	town._box("Opening", shop, Vector3(3.6, 2.2, 0.04), Vector3(0, 1.2, 0.01), Color(0.12, 0.1, 0.09))
	town._box("Shutter", shop, Vector3(3.7, 0.7, 0.08), Vector3(0, 2.6, 0.06), Color(0.55, 0.58, 0.6))
	town._box("Counter", shop, Vector3(3.2, 0.9, 0.5), Vector3(0, 0.55, 0.3), entry[1].darkened(0.2))
	town._box("SignBoard", shop, Vector3(4.6, 0.6, 0.12), Vector3(0, 3.0, 0.12), entry[1])
	for stripe in range(8):
		town._box("Awning%d" % stripe, shop, Vector3(0.6, 0.06, 0.9), Vector3(-2.1 + stripe * 0.6, 2.25, 0.5), entry[1] if stripe % 2 == 0 else Color(0.97, 0.96, 0.92))
	var label := Label3D.new()
	label.name = "Name"
	label.text = entry[0]
	label.position = Vector3(0, 3.0, 0.2)
	label.font_size = 52
	label.pixel_size = 0.006
	label.outline_size = 0
	label.modulate = Color(1, 0.98, 0.92)
	shop.add_child(label)

func _market() -> void:
	# Shops line both sides of the market street, fronts facing the street.
	var z_slots := [-10.0, -18.0, -26.0, -34.0]
	for index in range(4):
		_shop(index, Vector3(MARKET_X - 4.6, 0.1, z_slots[index]), PI / 2)
		_shop(index + 4, Vector3(MARKET_X + 4.6, 0.1, z_slots[index]), -PI / 2)

func _person(node_name: String, model: String, position: Vector3, yaw: float, parent: Node3D = null) -> Node3D:
	var person := Node3D.new()
	person.name = node_name
	person.position = position
	person.rotation.y = yaw
	var visual := Node3D.new()
	visual.name = "CharacterVisual"
	visual.set_script(preload("res://character_visual.gd"))
	visual.model = model
	person.add_child(visual)
	(town if parent == null else parent).add_child(person)
	people.append(person)
	return person

func _chai_stall() -> void:
	var base := Vector3(MARKET_X - 6.5, 0.1, -3.0)
	_box("ChaiCart", Vector3(1.8, 0.9, 0.9), base + Vector3(0, 0.55, 0), Color(0.72, 0.32, 0.12), true, future)
	_box("ChaiCartRoof", Vector3(2.2, 0.08, 1.3), base + Vector3(0, 2.1, 0), Color(0.95, 0.75, 0.2), false, future)
	for x in [-0.95, 0.95]: _box("ChaiPole%s" % x, Vector3(0.06, 1.2, 0.06), base + Vector3(x, 1.5, 0.5), Color(0.3, 0.25, 0.2), false, future)
	_box("Kettle", Vector3(0.3, 0.3, 0.3), base + Vector3(-0.4, 1.15, 0), Color(0.75, 0.75, 0.72), false, future)
	var sign := Label3D.new()
	sign.text = "CHAI 10"
	sign.position = base + Vector3(0, 1.85, 0.66)
	sign.font_size = 40
	sign.pixel_size = 0.005
	future.add_child(sign)
	for stool in [Vector3(-1.2, 0, 1.4), Vector3(0.9, 0, 1.6)]:
		_box("ChaiStool%s" % stool.x, Vector3(0.4, 0.45, 0.4), base + stool + Vector3(0, 0.25, 0), Color(0.45, 0.3, 0.2), false, future)
	_person("ChaiWala", "male-c", base + Vector3(0.2, 0, -0.9), 0.0, future)
	_person("ChaiCustomer1", "female-d", base + Vector3(-1.0, 0, 1.25), PI, future)
	_person("ChaiCustomer2", "male-f", base + Vector3(1.1, 0, 1.3), PI + 0.4, future)

## Bus stop on the south pavement inside the open town (the bus halts here).
func _bus_stop() -> void:
	var base := Vector3(BUS_STOP_X, 0.1, 11.6)
	_box("BusStopRoof", Vector3(3.6, 0.1, 1.4), base + Vector3(0, 2.4, 0.2), Color(0.2, 0.45, 0.65))
	_box("BusStopBack", Vector3(3.6, 1.8, 0.06), base + Vector3(0, 1.4, 0.85), Color(0.6, 0.78, 0.85))
	for x in [-1.7, 1.7]: _box("BusStopPost%s" % x, Vector3(0.08, 2.4, 0.08), base + Vector3(x, 1.2, 0.8), Color(0.25, 0.27, 0.3))
	_box("BusStopBench", Vector3(2.8, 0.1, 0.45), base + Vector3(0, 0.5, 0.5), Color(0.4, 0.42, 0.45), true)
	var sign := Label3D.new()
	sign.text = "BUS STOP\nMarket - Station"
	sign.position = base + Vector3(0, 2.0, 0.8)
	sign.rotation.y = PI
	sign.font_size = 34
	sign.pixel_size = 0.005
	town.add_child(sign)
	_person("BusWaiting", "female-a", base + Vector3(0.6, 0, 0.3), PI)

## Low-poly auto-rickshaw (yellow/green with a black canopy).
func _auto(index: int, position: Vector3, yaw: float) -> void:
	var auto := Node3D.new()
	auto.name = "Auto%d" % index
	auto.position = position
	auto.rotation.y = yaw
	future.add_child(auto)
	town._box("Body", auto, Vector3(1.3, 0.75, 2.4), Vector3(0, 0.65, 0), Color(0.95, 0.78, 0.1), true)
	town._box("Lower", auto, Vector3(1.32, 0.25, 2.42), Vector3(0, 0.38, 0), Color(0.1, 0.5, 0.25))
	town._box("Canopy", auto, Vector3(1.35, 0.12, 1.9), Vector3(0, 1.55, 0.15), Color(0.08, 0.08, 0.09))
	for z in [-0.8, 1.1]: town._box("Pillar%s" % z, auto, Vector3(1.25, 0.6, 0.06), Vector3(0, 1.2, z), Color(0.08, 0.08, 0.09))
	for wheel in [Vector3(0, 0.25, -1.1), Vector3(-0.6, 0.25, 0.8), Vector3(0.6, 0.25, 0.8)]:
		town._box("Wheel%s" % wheel.x, auto, Vector3(0.18, 0.45, 0.45), wheel, Color(0.05, 0.05, 0.05))

func _scooter(index: int, position: Vector3, yaw: float) -> void:
	var scooter := Node3D.new()
	scooter.name = "Scooter%d" % index
	scooter.position = position
	scooter.rotation.y = yaw
	future.add_child(scooter)
	var colour: Color = [Color(0.8, 0.15, 0.15), Color(0.15, 0.35, 0.8), Color(0.9, 0.9, 0.9)][index % 3]
	town._box("Body", scooter, Vector3(0.35, 0.45, 1.3), Vector3(0, 0.5, 0), colour)
	town._box("Seat", scooter, Vector3(0.3, 0.1, 0.6), Vector3(0, 0.78, -0.2), Color(0.1, 0.1, 0.1))
	town._box("Handle", scooter, Vector3(0.6, 0.06, 0.06), Vector3(0, 1.05, 0.55), Color(0.2, 0.2, 0.2))
	for z in [-0.5, 0.5]: town._box("Wheel%s" % z, scooter, Vector3(0.12, 0.36, 0.36), Vector3(0, 0.2, z), Color(0.05, 0.05, 0.05))

func _vehicles() -> void:
	# Moving traffic on the main road is in traffic.gd; only the market keeps a parked auto.
	_auto(0, Vector3(MARKET_X + 1.6, 0.1, -40.0), 0.0)
	for index in range(6):
		_scooter(index, Vector3(MARKET_X + (-2.1 if index % 2 == 0 else 2.1), 0.1, -8.0 - index * 4.5), PI / 2 if index % 2 == 0 else -PI / 2)

func _greenery() -> void:
	for point in [Vector3(-36, 0.1, -2), Vector3(-56, 0.1, -12), Vector3(-72, 0.1, 8), Vector3(-44, 0.1, 26), Vector3(-68, 0.1, 30), Vector3(36, 0.1, -14), Vector3(60, 0.1, -30), Vector3(72, 0.1, 4), Vector3(44, 0.1, 28), Vector3(68, 0.1, 44), Vector3(-30, 0.1, -40), Vector3(10, 0.1, -40), Vector3(38, 0.1, 55), Vector3(-36, 0.1, 46), Vector3(-8, 0.1, 74)]:
		town._tree(point)
