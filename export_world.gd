extends Node3D

# APNA EXPORT in the town (orders: export_store.gd, PC page: export_page.gd):
# - the packing room built onto the shop's left side (door from the shop at the
#   front-left, street door with an APNA EXPORT fascia): the prepare-order table with
#   flat cartons, the outgoing shelf for sealed parcels, a world map and an orders board;
# - the airport south of the warehouse (the town edge moved back): runway, cargo
#   terminal and control tower (tools/blender/build_export_props.py), the export
#   platform with its flight board and a walkway from the road;
# - the APNA AIR CARGO plane: at each flight time with parcels on the platform it flies
#   in along its shown path, lands, loads the parcels (the buyers pay) and flies away.
# Hands: E at the table takes a carton for the first accepted order; E at a rack puts
# one listed item in (reserved there through `bag_lines`, as for counter orders); E at
# the table seals the parcel into the player's hands; E at the platform puts it down.
const Bricks := preload("res://brick_works.gd")
const BlockPath := preload("res://block_path.gd")
const ExportStore := preload("res://export_store.gd")
const Catalog := preload("res://product_catalog.gd")
# Packing room (world): inside x -9.6..-6.06, z -3.9..2.44.
const ROOM_CENTRE := Vector3(-7.83, 0.1, -0.73)
const TABLE_POINT := Vector3(-9.1, 0.1, -1.0)
const SHELF_POINT := Vector3(-9.25, 0.1, 1.4)
## The packing station inside the cargo terminal (works like the shop's table).
const TERMINAL_TABLE := Vector3(11.5, 0.1, 38.0)
const SHELF_SLOTS := [Vector3(-9.25, 0.49, 1.05), Vector3(-9.25, 0.49, 1.75), Vector3(-9.25, 1.04, 1.05), Vector3(-9.25, 1.04, 1.75)]
# Airport (south of the warehouse).
const RUNWAY_Z := 58.0
const PAD := Vector3(7.2, 0.1, 47.4)
const PAD_SLOTS := [Vector3(6.6, 0.32, 47.0), Vector3(7.8, 0.32, 47.0), Vector3(6.6, 0.32, 47.8), Vector3(7.8, 0.32, 47.8)]
const STOP_X := -2.0
# Flight: seconds for each leg (approach, landing roll, loading, take-off roll, climb).
const LEGS := [14.0, 5.0, 5.0, 4.0, 9.0]

var business
var ops: Node3D
var builder: Node3D
var ui: Node
var player: Node3D
## Picking: the order whose carton is in the player's hands (-1 none) and the items in
## it, {product, rack, count}; rack_furnishing.gd reserves them on their racks.
var carton_order := -1
var bag_lines: Array = []
## The sealed parcel (order id) in the player's hands, or -1.
var carrying_parcel := -1
var held_carton: Node3D
var held_parcel: Node3D
var shelf_parcels: Array[Node3D] = []
var pad_parcels: Array[Node3D] = []
var orders_board: Label3D
var flight_board: Label3D
var plane: Node3D
var propellers: Array[Node3D] = []
var path_dots: MultiMeshInstance3D
var flight_time := -1.0
var flight_shipped := false
var last_minutes := -1.0
var board_due := 0

func _ready() -> void:
	name = "ExportWorld"
	var world := get_parent()
	business = world.get_node("Shop/ShopArea").business
	ops = world.get_node("ShopOperations")
	builder = world.get_node("Neighbourhood")
	ui = world.get_node("Ui")
	player = world.get_node("Player")
	_build_packing_room()
	_build_airport()
	_build_plane()
	# Held low on the right, so the view stays clear.
	held_carton = _prop(player, "HeldCarton", "carton_open", Vector3(0.34, 0.02, -0.72))
	held_carton.scale = Vector3.ONE * 0.45
	held_carton.rotation.y = -0.35
	held_carton.hide()
	held_parcel = _prop(player, "HeldParcel", "parcel", Vector3(0.34, 0.02, -0.72))
	held_parcel.scale = Vector3.ONE * 0.45
	held_parcel.rotation.y = -0.35
	held_parcel.hide()
	for slot in SHELF_SLOTS:
		var parcel := _prop(self, "ShelfParcel", "parcel", slot)
		parcel.rotation.y = PI / 2
		parcel.hide()
		shelf_parcels.append(parcel)
	for slot in PAD_SLOTS:
		var parcel := _prop(self, "PadParcel", "parcel", slot)
		parcel.rotation.y = PI / 2
		parcel.hide()
		pad_parcels.append(parcel)
	business.changed.connect(_refresh_parcels)
	_refresh_parcels()

## One of our Blender props (assets/props/export/<name>.glb).
func _prop(parent: Node3D, node_name: String, model: String, at := Vector3.ZERO) -> Node3D:
	var prop: Node3D = (load("res://assets/props/export/%s.glb" % model) as PackedScene).instantiate()
	prop.name = node_name
	prop.position = at
	parent.add_child(prop)
	return prop

func _text(parent: Node3D, node_name: String, value: String, at: Vector3, font_size: int, colour := Color.WHITE, yaw := 0.0) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = value
	label.position = at
	label.rotation.y = yaw
	label.font_size = font_size
	label.pixel_size = 0.004
	label.outline_size = 0
	label.modulate = colour
	parent.add_child(label)
	return label

# ---------------------------------------------------------------- packing room
func _build_packing_room() -> void:
	var room := Node3D.new()
	room.name = "PackingRoom"
	add_child(room)
	var wall := Color(0.78, 0.83, 0.8)
	var walls: Array[MeshInstance3D] = [
		builder._box("PackLeftWall", room, Vector3(0.12, 3.8, 6.58), Vector3(-9.66, 2.0, -0.73), wall, true),
		builder._box("PackBackWall", room, Vector3(3.66, 3.8, 0.12), Vector3(-7.89, 2.0, -3.96), wall, true),
		builder._box("PackFrontLeft", room, Vector3(1.12, 3.8, 0.12), Vector3(-9.16, 2.0, 2.5), wall, true),
		builder._box("PackFrontRight", room, Vector3(1.34, 3.8, 0.12), Vector3(-6.73, 2.0, 2.5), wall, true),
		builder._box("PackDoorLintel", room, Vector3(1.2, 1.5, 0.12), Vector3(-8.0, 3.15, 2.5), wall, true),
	]
	for part in walls: part.material_override = Bricks.brick_material()
	var floor: MeshInstance3D = builder._box("PackFloor", room, Vector3(3.54, 0.012, 6.34), Vector3(-7.83, 0.106, -0.73), Color(0.72, 0.74, 0.76))
	var presentation := get_parent().get_node_or_null("ShopPresentation")
	if presentation != null: floor.material_override = presentation.surface(Vector2(0.5, 0), 2.0)
	builder._box("PackRoof", room, Vector3(3.9, 0.18, 6.84), Vector3(-7.83, 4.0, -0.73), Color(0.24, 0.26, 0.29), true)
	var pink := Color(0.86, 0.2, 0.56)
	builder._box("PackParapetFront", room, Vector3(3.9, 0.3, 0.16), Vector3(-7.83, 4.05, 2.66), pink)
	builder._box("PackParapetBack", room, Vector3(3.9, 0.3, 0.16), Vector3(-7.83, 4.05, -4.07), pink)
	builder._box("PackParapetLeft", room, Vector3(0.16, 0.3, 6.84), Vector3(-9.7, 4.05, -0.73), pink)
	# Mustard paint band and dark stripe inside, as in the shop.
	var paint := Color(0.93, 0.74, 0.38)
	builder._box("PackPaintLeft", room, Vector3(0.012, 1.0, 6.3), Vector3(-9.594, 0.6, -0.73), paint)
	builder._box("PackPaintBack", room, Vector3(3.5, 1.0, 0.012), Vector3(-7.83, 0.6, -3.894), paint)
	builder._box("PackStripeLeft", room, Vector3(0.016, 0.06, 6.3), Vector3(-9.592, 1.13, -0.73), Color(0.12, 0.3, 0.26))
	builder._box("PackStripeBack", room, Vector3(3.5, 0.06, 0.016), Vector3(-7.83, 1.13, -3.892), Color(0.12, 0.3, 0.26))
	# Street door: pink frame, a dark fascia with the APNA EXPORT name.
	for x in [-8.63, -7.37]: builder._box("PackDoorPost%s" % x, room, Vector3(0.12, 2.36, 0.14), Vector3(x, 1.28, 2.6), Bricks.FRAME)
	builder._box("PackDoorTop", room, Vector3(1.38, 0.12, 0.14), Vector3(-8.0, 2.46, 2.6), Bricks.FRAME)
	builder._box("PackFascia", room, Vector3(3.5, 0.62, 0.08), Vector3(-7.85, 3.2, 2.62), Color(0.06, 0.12, 0.15))
	builder._box("PackFasciaAccent", room, Vector3(3.5, 0.035, 0.04), Vector3(-7.85, 2.88, 2.67), Color(0.95, 0.55, 0.12))
	_text(room, "PackSign", "APNA EXPORT", Vector3(-7.85, 3.28, 2.67), 64, Color(0.98, 0.62, 0.15))
	_text(room, "PackSignSmall", "PACKING  &  INTERNATIONAL ORDERS", Vector3(-7.85, 3.04, 2.67), 22)
	# Light.
	var lamp_fixture: MeshInstance3D = builder._box("PackTubeLight", room, Vector3(0.24, 0.07, 1.7), Vector3(-7.83, 3.82, -0.9), Color(0.94, 0.98, 1))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.94, 0.98, 1)
	glow.emission_enabled = true
	glow.emission = Color(0.9, 0.96, 1)
	glow.emission_energy_multiplier = 0.6
	lamp_fixture.material_override = glow
	var lamp := OmniLight3D.new()
	lamp.name = "PackLight"
	lamp.position = Vector3(-7.83, 3.3, -0.73)
	lamp.light_energy = 0.9
	lamp.omni_range = 6.5
	lamp.shadow_enabled = false
	room.add_child(lamp)
	# Prepare-order table against the left wall, its front toward the room (+x).
	var table := _prop(room, "PackingTable", "packing_table", TABLE_POINT)
	table.rotation.y = PI / 2
	builder._collider("PackingTableBody", room, Vector3(0.8, 0.95, 1.8), TABLE_POINT + Vector3(0, 0.47, 0))
	_text(room, "TableSign", "PREPARE ORDERS", TABLE_POINT + Vector3(-0.42, 1.55, 0), 30, Color(0.98, 0.62, 0.15), PI / 2)
	# Outgoing shelf for sealed parcels by the street door.
	var steel := Color(0.3, 0.33, 0.37)
	for z in [0.72, 2.08]:
		for x in [-9.53, -8.97]: builder._box("ShelfPost", room, Vector3(0.04, 1.1, 0.04), Vector3(x, 0.65, z), steel)
	for y in [0.46, 1.01]: builder._box("ShelfBoard%s" % y, room, Vector3(0.6, 0.03, 1.4), Vector3(-9.25, y, 1.4), Color(0.76, 0.78, 0.8))
	builder._collider("OutgoingShelfBody", room, Vector3(0.62, 1.1, 1.42), Vector3(-9.25, 0.65, 1.4))
	_text(room, "ShelfSign", "OUTGOING", Vector3(-8.94, 1.32, 1.4), 26, Color(0.55, 1.0, 0.65), PI / 2)
	# Sliding glass street door, as at the shop.
	var door := Node3D.new()
	door.name = "PackingRoomDoor"
	door.set_script(preload("res://sliding_door.gd"))
	door.doorway_position = Vector3(-8.0, 0.1, 2.5)
	door.doorway_width = 1.2
	door.doorway_height = 2.3
	room.add_child(door)
	# Pink trim round the doorway from the shop (both sides of the wall), and a floor
	# strip through the wall.
	builder._box("DoorThreshold", room, Vector3(0.24, 0.014, 1.2), Vector3(-6.0, 0.108, 1.35), Color(0.72, 0.74, 0.76))
	for x in [-5.92, -6.08]:
		for z in [0.69, 2.01]: builder._box("ShopDoorPost", room, Vector3(0.04, 2.36, 0.12), Vector3(x, 1.28, z), Bricks.FRAME)
		builder._box("ShopDoorTop", room, Vector3(0.04, 0.12, 1.44), Vector3(x, 2.36, 1.35), Bricks.FRAME)
	# Packing supplies against the shop wall, and stock boxes stacked in the corner.
	var supplies := _prop(room, "SupplyShelf", "supply_shelf", Vector3(-6.32, 0.1, -3.2))
	supplies.rotation.y = -PI / 2
	builder._collider("SupplyShelfBody", room, Vector3(0.46, 1.8, 1.02), Vector3(-6.32, 1.0, -3.2))
	for stack in [[Vector3(-9.2, 0.1, -3.4), 0.1], [Vector3(-9.2, 0.5, -3.4), -0.15], [Vector3(-8.55, 0.1, -3.45), 0.4]]:
		_prop(room, "StockParcel", "parcel", stack[0]).rotation.y = stack[1]
	builder._collider("StockParcelsBody", room, Vector3(1.3, 0.9, 0.6), Vector3(-8.9, 0.55, -3.45))
	# World map on the back wall, orders board on the shop's wall.
	_prop(room, "WorldPoster", "world_poster", Vector3(-7.85, 1.95, -3.88))
	builder._box("OrdersBoard", room, Vector3(0.03, 0.9, 1.3), Vector3(-6.08, 1.8, -1.7), Color(0.1, 0.16, 0.24))
	orders_board = _text(room, "OrdersBoardText", "", Vector3(-6.1, 1.8, -1.7), 34, Color.WHITE, -PI / 2)
	orders_board.pixel_size = 0.0026
	orders_board.width = 460
	orders_board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# ---------------------------------------------------------------- airport
func _build_airport() -> void:
	var airport := Node3D.new()
	airport.name = "Airport"
	add_child(airport)
	var asphalt := Color(0.18, 0.19, 0.2)
	var concrete := Color(0.62, 0.62, 0.6)
	var white := Color(0.92, 0.93, 0.9)
	builder._box("Runway", airport, Vector3(60, 0.02, 14), Vector3(0, 0.112, RUNWAY_Z), asphalt)
	for z in [RUNWAY_Z - 6.7, RUNWAY_Z + 6.7]: builder._box("RunwayEdge%d" % roundi(z), airport, Vector3(60, 0.012, 0.25), Vector3(0, 0.124, z), white)
	for step in range(9): builder._box("RunwayDash%d" % step, airport, Vector3(3.2, 0.012, 0.35), Vector3(-24 + step * 6, 0.124, RUNWAY_Z), white)
	for side in [-1, 1]:
		for bar in range(8): builder._box("Threshold%d_%d" % [side, bar], airport, Vector3(3.0, 0.012, 0.6), Vector3(side * 27.6, 0.124, RUNWAY_Z - 5.25 + bar * 1.5), white)
		_text(airport, "RunwayNumber%d" % side, "27" if side > 0 else "09", Vector3(side * 23.4, 0.13, RUNWAY_Z), 160, white, PI / 2 * -side).rotation.x = -PI / 2
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(1, 0.86, 0.4)
	lit.emission_enabled = true
	lit.emission = Color(1, 0.8, 0.35)
	lit.emission_energy_multiplier = 1.4
	for x in range(-28, 30, 7):
		for z in [RUNWAY_Z - 7.3, RUNWAY_Z + 7.3]: builder._box("RunwayLight", airport, Vector3(0.18, 0.2, 0.18), Vector3(x, 0.2, z), Color.WHITE).material_override = lit
	builder._box("Apron", airport, Vector3(24, 0.018, 4.6), Vector3(16, 0.11, 48.8), concrete)
	builder._box("TerminalYard", airport, Vector3(28, 0.016, 15.0), Vector3(16, 0.108, 39.0), concrete)
	var terminal := _prop(airport, "ExportTerminal", "export_terminal", Vector3(16, 0.1, 41.5))
	terminal.name = "ExportTerminal"
	# Its walls (tools/blender/build_export_props.py): a walk-in door in the west wall
	# (z 42.8..45.2) by the walkway and the open runway door (x 10.5..17.5).
	for wall in [[Vector3(16.2, 6.0, 0.2), Vector3(16, 3.1, 36.5)], [Vector3(0.2, 6.0, 10.2), Vector3(24, 3.1, 41.5)],
			[Vector3(0.2, 6.0, 6.4), Vector3(8, 3.1, 39.6)], [Vector3(0.2, 6.0, 1.4), Vector3(8, 3.1, 45.9)], [Vector3(0.2, 3.0, 2.4), Vector3(8, 4.6, 44.0)],
			[Vector3(2.6, 6.0, 0.2), Vector3(9.2, 3.1, 46.5)], [Vector3(6.6, 6.0, 0.2), Vector3(20.8, 3.1, 46.5)], [Vector3(7.0, 1.0, 0.2), Vector3(14, 5.6, 46.5)]]:
		builder._collider("TerminalWall", airport, wall[0], wall[1])
	_terminal_inside(airport)
	builder._collider("TerminalOfficeBody", airport, Vector3(8.2, 3.3, 3.2), Vector3(19, 1.75, 35.0))
	for x in [19.6, 23.6]: builder._collider("CanopyPost%d" % roundi(x), airport, Vector3(0.2, 3.6, 0.2), Vector3(x, 1.9, 48.75))
	_prop(airport, "ControlTower", "control_tower", Vector3(28.2, 0.1, 40.0))
	builder._collider("TowerBody", airport, Vector3(3.1, 7.2, 3.1), Vector3(28.2, 3.7, 40.0))
	# Windsock by the runway end.
	builder._box("WindsockPole", airport, Vector3(0.1, 4.2, 0.1), Vector3(-27.0, 2.2, 49.0), Color(0.85, 0.86, 0.86))
	var sock: MeshInstance3D = builder._box("Windsock", airport, Vector3(1.4, 0.4, 0.4), Vector3(-26.3, 4.0, 49.0), Color(0.95, 0.45, 0.12))
	sock.rotation.z = -0.18
	# Walkway from the road down the warehouse's east side to the platform.
	BlockPath.lay(airport, "AirportWalk", Vector2(7.2, 11.4), Vector2(7.2, 46.0), 3)
	# The export platform: a low concrete dock with yellow edges, a sign and the board.
	builder._box("ExportPad", airport, Vector3(2.8, 0.2, 2.2), PAD + Vector3(0, 0.1, 0), concrete.darkened(0.08))
	for edge in [[Vector3(2.8, 0.03, 0.12), Vector3(0, 0.215, -1.06)], [Vector3(2.8, 0.03, 0.12), Vector3(0, 0.215, 1.06)], [Vector3(0.12, 0.03, 2.2), Vector3(-1.36, 0.215, 0)], [Vector3(0.12, 0.03, 2.2), Vector3(1.36, 0.215, 0)]]:
		builder._box("PadEdge", airport, edge[0], PAD + edge[1], Color(0.98, 0.78, 0.12))
	builder._box("BoardPost", airport, Vector3(0.12, 2.2, 0.12), PAD + Vector3(-1.9, 1.1, -0.6), Color(0.3, 0.33, 0.37))
	builder._box("BoardPanel", airport, Vector3(1.6, 1.0, 0.06), PAD + Vector3(-1.9, 2.0, -0.6), Color(0.1, 0.16, 0.3))
	flight_board = _text(airport, "FlightBoard", "", PAD + Vector3(-1.9, 2.0, -0.64), 26, Color.WHITE, PI)
	flight_board.pixel_size = 0.0028
	_text(airport, "PadSign", "EXPORT PLATFORM", PAD + Vector3(0, 0.6, -1.15), 40, Color(0.98, 0.78, 0.12), PI).rotation.x = 0.0
	# Dotted flight path in the sky (shown before and during a flight).
	var dot := SphereMesh.new()
	dot.radius = 0.22
	dot.height = 0.44
	dot.radial_segments = 6
	dot.rings = 3
	var dot_material := StandardMaterial3D.new()
	dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_material.albedo_color = Color(1.0, 0.62, 0.12)
	dot.material = dot_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = dot
	var points: Array[Vector3] = []
	for k in range(40): points.append(_flight_point(LEGS[0] * k / 40.0))
	for k in range(30): points.append(_flight_point(LEGS[0] + LEGS[1] + LEGS[2] + (LEGS[3] + LEGS[4]) * k / 30.0))
	multimesh.instance_count = points.size()
	for index in range(points.size()): multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, points[index] + Vector3(0, 1.6, 0)))
	path_dots = MultiMeshInstance3D.new()
	path_dots.name = "FlightPath"
	path_dots.multimesh = multimesh
	path_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	path_dots.hide()
	airport.add_child(path_dots)

## Inside the cargo terminal: pallet racks along the walls full of stored parcels (one
## MultiMesh), the packing station with its supplies, lights and the name.
func _terminal_inside(airport: Node3D) -> void:
	var rack_model: Node3D = (load("res://assets/props/warehouse/storage_rack.glb") as PackedScene).instantiate()
	var parcel_model: Node3D = (load("res://assets/props/export/parcel.glb") as PackedScene).instantiate()
	var rack_spots: Array[Transform3D] = []
	for z in [38.2, 41.0, 43.8]: rack_spots.append(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(23.3, 0.1, z)))
	for x in [17.0, 19.8]: rack_spots.append(Transform3D(Basis(Vector3.UP, PI), Vector3(x, 0.1, 37.25)))
	var parcels: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for spot in rack_spots:
		_body(airport, "TerminalRackBody", Vector3(2.7, 4.2, 1.1), spot.translated_local(Vector3(0, 2.1, 0)))
		for level in range(4):
			for slot in range(3):
				if rng.randf() < 0.25: continue
				var lift := 0.0 if level == 0 else 0.1 + level * 0.95 + 0.085
				parcels.append(spot * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), Vector3(-0.85 + slot * 0.85, lift, rng.randf_range(-0.08, 0.08))))
	airport.add_child(_batch("TerminalRacks", rack_model, rack_spots))
	airport.add_child(_batch("StoredParcels", parcel_model, parcels))
	rack_model.free()
	parcel_model.free()
	_prop(airport, "PackingStation", "packing_table", TERMINAL_TABLE)
	builder._collider("PackingStationBody", airport, Vector3(1.8, 0.95, 0.8), TERMINAL_TABLE + Vector3(0, 0.47, 0))
	_text(airport, "StationSign", "PACKING STATION", TERMINAL_TABLE + Vector3(0, 2.2, -1.3), 40, Color(0.98, 0.62, 0.15))
	var supplies := _prop(airport, "StationSupplies", "supply_shelf", Vector3(13.6, 0.1, 37.0))
	builder._collider("StationSuppliesBody", airport, Vector3(1.02, 1.8, 0.46), Vector3(13.6, 1.0, 37.0))
	_text(airport, "TerminalName", "APNA EXPORT  -  CARGO", Vector3(16, 4.7, 36.62), 90, Color.WHITE)
	_text(airport, "OutboundSign", "OUTBOUND", Vector3(14, 0.14, 44.6), 120, Color(0.98, 0.78, 0.12)).rotation.x = -PI / 2
	for x in [12.0, 20.0]:
		var lamp := OmniLight3D.new()
		lamp.name = "TerminalLight"
		lamp.position = Vector3(x, 4.6, 41.5)
		lamp.light_energy = 1.2
		lamp.omni_range = 10.0
		lamp.shadow_enabled = false
		airport.add_child(lamp)

## Many copies of a one-mesh Blender prop as a single MultiMesh.
func _batch(node_name: String, model: Node3D, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var source: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source.mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()): multimesh.set_instance_transform(index, transforms[index])
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multimesh
	return batch

## A box collider at any transform (the turned racks).
func _body(parent: Node3D, node_name: String, size: Vector3, at: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.transform = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func _at_table() -> bool:
	return _near(TABLE_POINT, 1.5) or _near(TERMINAL_TABLE, 1.5)

func _build_plane() -> void:
	plane = _prop(self, "CargoPlane", "cargo_plane")
	plane.rotation.y = PI
	for side in [-1, 1]:
		var prop := _prop(plane, "Propeller%d" % side, "propeller", Vector3(2.05, 3.4, side * 3.6))
		propellers.append(prop)
	plane.hide()

## Where the plane is `t` seconds into a flight (facing -x, landing from the east).
func _flight_point(t: float) -> Vector3:
	var approach: float = LEGS[0]
	var roll: float = approach + LEGS[1]
	var load_end: float = roll + LEGS[2]
	var takeoff: float = load_end + LEGS[3]
	if t < approach:
		var u := t / approach
		return Vector3(lerpf(80.0, 22.0, u), 0.1 + 28.0 * pow(1.0 - u, 1.7), RUNWAY_Z)
	if t < roll:
		var u := (t - approach) / LEGS[1]
		return Vector3(lerpf(22.0, STOP_X, 1.0 - pow(1.0 - u, 2.0)), 0.1, RUNWAY_Z)
	if t < load_end: return Vector3(STOP_X, 0.1, RUNWAY_Z)
	if t < takeoff:
		var u := (t - load_end) / LEGS[3]
		return Vector3(lerpf(STOP_X, -24.0, u * u), 0.1, RUNWAY_Z)
	var u := clampf((t - takeoff) / LEGS[4], 0.0, 1.0)
	return Vector3(lerpf(-24.0, -95.0, u), 0.1 + 34.0 * pow(u, 1.4), RUNWAY_Z)

# ---------------------------------------------------------------- state
func _order(id: int) -> Dictionary:
	return business.exports.find(id)

func holding() -> bool:
	return carton_order >= 0 or carrying_parcel >= 0

func picking_order() -> Dictionary:
	return _order(carton_order) if carton_order >= 0 else {}

func in_carton(product: String) -> int:
	var total := 0
	for line in bag_lines:
		if line.product == product: total += int(line.count)
	return total

func _still_needed(order: Dictionary) -> Array:
	var missing: Array = []
	for line in order.lines:
		var need := int(line.count) - in_carton(line.product)
		if need > 0: missing.append("%d %s" % [need, Catalog.NAMES[line.product]])
	return missing

func next_flight() -> String:
	var minutes := int(business.minutes_of_day)
	for slot in ExportStore.FLIGHTS:
		if slot > minutes: return "%02d:%02d" % [slot / 60, slot % 60]
	return "tomorrow %02d:00" % (ExportStore.FLIGHTS[0] / 60)

func _near(point: Vector3, distance: float) -> bool:
	var offset: Vector3 = player.global_position - point
	offset.y = 0
	return offset.length() <= distance

func _refresh_parcels() -> void:
	var exports = business.exports
	var shelf: Array = exports.in_state("packed").filter(func(order): return int(order.id) != carrying_parcel)
	for index in range(shelf_parcels.size()): shelf_parcels[index].visible = index < shelf.size()
	if flight_time < 0.0 or flight_time < LEGS[0] + LEGS[1] + 1.0:
		var waiting: Array = exports.in_state("on_pad")
		for index in range(pad_parcels.size()):
			pad_parcels[index].visible = index < waiting.size()
			pad_parcels[index].position = PAD_SLOTS[index]
	var lines: Array[String] = ["EXPORT ORDERS"]
	for order in exports.active():
		lines.append("%s  -  %d items  -  %s" % [order.city, ExportStore.units(order), {"accepted": "to pack", "packed": "packed", "on_pad": "at the airport"}[order.state]])
	if lines.size() == 1: lines.append("No orders. Accept one on the\nshop PC: APNA Export.")
	if is_instance_valid(orders_board): orders_board.text = "\n".join(lines)

# ---------------------------------------------------------------- hands (E / Q)
## E for export work; true when it handled the key (shop_operations.gd asks first).
func try_interact() -> bool:
	if carton_order >= 0: return _with_carton()
	if carrying_parcel >= 0: return _with_parcel()
	var free_hands: bool = business.carried_stock == 0 and not ops.holding_bag
	if _at_table():
		if not free_hands:
			ui.show_feedback("Your hands are full. Put that down first.", true)
			return true
		var accepted: Array = business.exports.in_state("accepted")
		if accepted.is_empty():
			ui.show_feedback("No export order to pack. Accept one on the shop PC: APNA Export.", true)
			return true
		carton_order = int(accepted[0].id)
		bag_lines.clear()
		held_carton.show()
		ops.play_sound("stock")
		ui.show_feedback("Carton for %s. Put the listed items in at the racks (E), then seal it here." % accepted[0].city)
		return true
	if _near(SHELF_POINT, 1.3) and free_hands:
		var shelf: Array = business.exports.in_state("packed")
		if not shelf.is_empty():
			_carry(int(shelf[0].id))
			return true
	return false

func _with_carton() -> bool:
	var order := picking_order()
	if order.is_empty():
		_put_away_carton()
		return true
	if _at_table():
		var missing := _still_needed(order)
		if not missing.is_empty():
			ui.show_feedback("Still missing: %s." % ", ".join(missing), true)
			return true
		if business.export_pack(carton_order, bag_lines.duplicate(true)):
			var id := carton_order
			bag_lines.clear()
			carton_order = -1
			held_carton.hide()
			ops.update_rack()
			ops.play_sound("stock")
			_carry(id)
			ui.show_feedback("Parcel for %s sealed! Take it to the export platform at the airport (behind the warehouse)." % order.city)
		else: ui.show_feedback("Could not seal the parcel. Check save status.", true)
		return true
	var record: Dictionary = ops.furnishing.near_any_rack() if is_instance_valid(ops.furnishing) else {}
	if record.is_empty():
		ui.show_feedback("Fill the carton at the racks, then seal it at the packing table.", true)
		return true
	var rack := int(record.id)
	for line in order.lines:
		if in_carton(line.product) < int(line.count) and ops.furnishing.available(rack, line.product) > 0:
			var entry: Dictionary = {}
			for item in bag_lines:
				if item.product == line.product and int(item.rack) == rack: entry = item
			if entry.is_empty():
				entry = {"product": line.product, "rack": rack, "count": 0}
				bag_lines.append(entry)
			entry.count += 1
			ops.update_rack()
			ops.play_sound("stock")
			ui.show_feedback("In the carton: %s %d/%d" % [Catalog.NAMES[line.product], in_carton(line.product), line.count])
			return true
	ui.show_feedback("Nothing for %s on this rack." % order.city if not _still_needed(order).is_empty() else "All in! Seal the carton at the packing table.", not _still_needed(order).is_empty())
	return true

func _carry(id: int) -> void:
	carrying_parcel = id
	held_parcel.show()
	_refresh_parcels()

func _with_parcel() -> bool:
	var order := _order(carrying_parcel)
	if order.is_empty() or order.state != "packed":
		carrying_parcel = -1
		held_parcel.hide()
		_refresh_parcels()
		return true
	if _near(PAD, 2.3):
		if flight_time >= 0.0:
			ui.show_feedback("The plane is loading. Wait for the next flight.", true)
			return true
		if business.export_to_pad(carrying_parcel):
			carrying_parcel = -1
			held_parcel.hide()
			ops.play_sound("stock")
			_refresh_parcels()
			ui.show_feedback("Parcel for %s is on the platform. Next cargo flight: %s." % [order.city, next_flight()])
		return true
	if _near(SHELF_POINT, 1.3):
		carrying_parcel = -1
		held_parcel.hide()
		_refresh_parcels()
		ui.show_feedback("Parcel back on the outgoing shelf.")
		return true
	ui.show_feedback("Take the parcel to the export platform at the airport (walk down past the warehouse).", true)
	return true

## Q: the last item goes back on its rack, an empty carton is put away, a parcel goes
## back on the outgoing shelf when you are by it.
func release() -> bool:
	if carton_order >= 0:
		if not bag_lines.is_empty() and is_instance_valid(ops.furnishing) and not ops.furnishing.near_any_rack().is_empty():
			var line: Dictionary = bag_lines[-1]
			line.count -= 1
			if int(line.count) <= 0: bag_lines.pop_back()
			ops.update_rack()
			ui.show_feedback("Took 1 %s out of the carton." % Catalog.NAMES[line.product])
		else:
			_put_away_carton()
			ui.show_feedback("Carton put away. Its items stay on the racks.")
		return true
	if carrying_parcel >= 0:
		if _near(SHELF_POINT, 1.3):
			carrying_parcel = -1
			held_parcel.hide()
			_refresh_parcels()
			ui.show_feedback("Parcel back on the outgoing shelf.")
		else: ui.show_feedback("Put the parcel on the export platform (E) or back on the outgoing shelf.", true)
		return true
	return false

func _put_away_carton() -> void:
	bag_lines.clear()
	carton_order = -1
	held_carton.hide()
	ops.update_rack()

func hint() -> String:
	if carton_order >= 0:
		var order := picking_order()
		if order.is_empty(): return ""
		if _at_table(): return "Seal the parcel for %s" % order.city if _still_needed(order).is_empty() else "Still missing: %s" % ", ".join(_still_needed(order))
		var record: Dictionary = ops.furnishing.near_any_rack() if is_instance_valid(ops.furnishing) else {}
		if record.is_empty(): return ""
		for line in order.lines:
			if in_carton(line.product) < int(line.count) and ops.furnishing.available(int(record.id), line.product) > 0:
				return "Put 1 %s in the carton (%d/%d)   |   Q: take 1 out" % [Catalog.NAMES[line.product], in_carton(line.product), line.count]
		return "Nothing for %s here" % order.city
	if carrying_parcel >= 0:
		if _near(PAD, 2.3): return "Put the parcel on the export platform"
		if _near(SHELF_POINT, 1.3): return "Put the parcel back on the shelf"
		return ""
	if _at_table(): return "Take a carton for an export order"
	if _near(SHELF_POINT, 1.3) and not business.exports.in_state("packed").is_empty(): return "Pick up the parcel"
	return ""

# ---------------------------------------------------------------- flights
func _process(delta: float) -> void:
	for prop in propellers: prop.rotate_x(delta * 30.0)
	var minutes: float = business.minutes_of_day
	if flight_time < 0.0:
		if last_minutes >= 0.0 and minutes > last_minutes and minutes - last_minutes < 30.0 and not business.exports.in_state("on_pad").is_empty():
			for slot in ExportStore.FLIGHTS:
				if last_minutes < slot and minutes >= slot: _start_flight()
		var soon := false
		if not business.exports.in_state("on_pad").is_empty():
			for slot in ExportStore.FLIGHTS:
				if slot > minutes and slot - minutes <= 60.0: soon = true
		path_dots.visible = soon
	else: _fly(delta)
	last_minutes = minutes
	if Time.get_ticks_msec() >= board_due:
		board_due = Time.get_ticks_msec() + 1000
		var waiting: int = business.exports.in_state("on_pad").size()
		flight_board.text = "APNA AIR CARGO\n%s\n%d parcel%s on the platform" % ["PLANE ON THE WAY" if flight_time >= 0.0 else "Next flight " + next_flight(), waiting, "" if waiting == 1 else "s"]

func _start_flight() -> void:
	flight_time = 0.0
	flight_shipped = false
	plane.show()
	path_dots.show()
	ui.show_feedback("APNA AIR CARGO is coming for your parcels! Watch the sky over the airport.")

func _fly(delta: float) -> void:
	flight_time += delta
	plane.position = _flight_point(flight_time)
	var loading_at: float = LEGS[0] + LEGS[1]
	if flight_time >= loading_at and flight_time < loading_at + LEGS[2]:
		# Parcels float from the platform into the plane's cargo door.
		var door: Vector3 = plane.position + Vector3(5.4, 1.4, 0)
		var u := clampf((flight_time - loading_at) / 2.0, 0.0, 1.0)
		var waiting: Array = business.exports.in_state("on_pad")
		for index in range(pad_parcels.size()):
			if index < waiting.size(): pad_parcels[index].position = PAD_SLOTS[index].lerp(door, u) + Vector3(0, sin(u * PI) * 3.0, 0)
		if u >= 1.0 and not flight_shipped:
			flight_shipped = true
			for parcel in pad_parcels: parcel.hide()
			var shipped: Array = business.export_ship()
			if not shipped.is_empty():
				var total := 0
				var cities: Array[String] = []
				for order in shipped:
					total += int(order.value)
					cities.append(order.city)
				ops.play_sound("payment")
				ui.show_feedback("Parcels flying to %s! Buyers paid %s%d." % [", ".join(cities), String.chr(8377), total])
	var total_time := 0.0
	for leg in LEGS: total_time += leg
	if flight_time >= total_time:
		flight_time = -1.0
		plane.hide()
		path_dots.hide()
		_refresh_parcels()
