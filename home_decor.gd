extends Node3D

# Builds the player's home: a 6.4 x 5.5 m house with a gable roof, window frames,
# a bedroom corner, living area, kitchen and dining table (Kenney Furniture Kit).
# The original house.tscn nodes the game relies on are kept and re-fitted:
# HouseArea (door menu), InteriorArea (first-person indoors), Bed + SleepArea,
# FrontDoor and HouseSign. Old block walls/roof are hidden and their colliders off.
const Kenney = preload("res://kenney_assets.gd")
const FURNITURE := "res://assets/furniture/kenney/%s.glb"
## "kk:" pieces are KayKit Furniture Bits models (CC0).
const KAYKIT := "res://assets/furniture/kaykit/%s.gltf"
const HALF_WIDTH := 3.2
const FRONT := 1.9
const BACK := -3.6
const WALL_HEIGHT := 3.0
const THICK := 0.2
const DOOR_HALF := 0.7
const DOOR_TOP := 2.3
## Where the player wakes up / spawns, in house-local space (beside the bed).
const SPAWN := Vector3(-1.0, 1.1, -0.7)

# [model, fit size, position, yaw, collider?]
const PIECES := [
	["bedDouble", Vector3(1.45, 1.0, 2.0), Vector3(-1.95, 0.0, -2.55), 0.0, false],
	["sideTable", Vector3(0.42, 0.5, 0.4), Vector3(-2.85, 0.0, -3.2), 0.0, true],
	["lampRoundTable", Vector3(0.25, 0.42, 0.25), Vector3(-2.85, 0.5, -3.2), 0.0, false],
	["bookcaseClosedDoors", Vector3(1.0, 1.9, 0.5), Vector3(-2.85, 0.0, -0.95), PI / 2, true],
	["kk:rug_rectangle_stripes_A", Vector3(1.9, 0.02, 1.5), Vector3(1.9, 0.004, -1.7), 0.0, false],
	["cabinetTelevision", Vector3(1.2, 0.55, 0.45), Vector3(2.85, 0.0, -1.7), -PI / 2, true],
	["televisionModern", Vector3(1.0, 0.65, 0.25), Vector3(2.9, 0.55, -1.7), -PI / 2, false],
	["tableCoffee", Vector3(0.8, 0.4, 0.5), Vector3(1.85, 0.0, -1.7), PI / 2, true],
	["kk:couch_pillows", Vector3(1.6, 0.85, 0.8), Vector3(0.75, 0.0, -1.7), PI / 2, true],
	["kk:armchair_pillows", Vector3(0.8, 0.85, 0.8), Vector3(0.85, 0.0, -3.05), PI / 2, true],
	["kk:lamp_standing", Vector3(0.35, 1.6, 0.35), Vector3(0.15, 0.0, -3.25), 0.0, false],
	["kk:pictureframe_large_A", Vector3(0.8, 0.6, 0.08), Vector3(0.75, 1.45, -3.44), 0.0, false],
	["bookcaseOpen", Vector3(1.2, 1.6, 0.4), Vector3(1.8, 0.0, -3.35), 0.0, true],
	["kk:cactus_medium_A", Vector3(0.45, 1.0, 0.45), Vector3(2.85, 0.0, -3.25), 0.0, false],
	["kitchenFridge", Vector3(0.6, 1.7, 0.6), Vector3(-2.85, 0.0, 1.45), PI / 2, true],
	["kitchenStove", Vector3(0.6, 0.9, 0.6), Vector3(-2.85, 0.0, 0.82), PI / 2, true],
	["kitchenSink", Vector3(0.6, 0.9, 0.6), Vector3(-2.85, 0.0, 0.2), PI / 2, true],
	["table", Vector3(1.0, 0.75, 0.8), Vector3(1.9, 0.0, 0.85), 0.0, true],
	["chair", Vector3(0.45, 0.9, 0.45), Vector3(1.9, 0.0, 0.2), 0.0, false],
	["chair", Vector3(0.45, 0.9, 0.45), Vector3(1.9, 0.0, 1.5), PI, false],
	["plantSmall1", Vector3(0.4, 0.55, 0.4), Vector3(-1.1, 0.0, 2.35), 0.0, false],
	["plantSmall1", Vector3(0.4, 0.55, 0.4), Vector3(1.1, 0.0, 2.35), 0.0, false],
]

var walls: StaticBody3D

func _ready() -> void:
	name = "HomeDecor"
	var house := get_parent()
	_retire_old_house(house)
	walls = StaticBody3D.new()
	walls.name = "HomeWalls"
	add_child(walls)
	_build_shell()
	_build_roof()
	_build_windows()
	_refit_gameplay_nodes(house)
	for index in range(PIECES.size()):
		var piece: Array = PIECES[index]
		var model: String = piece[0]
		var path := KAYKIT % model.trim_prefix("kk:") if model.begins_with("kk:") else FURNITURE % model
		var holder := Kenney.fit(self, "%s%d" % [model.trim_prefix("kk:"), index], path, piece[1], piece[2], piece[3])
		if piece[4]: _collider(holder.name + "Body", piece[1], piece[2], piece[3])
	Kenney.fit(self, "PorchLamp", FURNITURE % "lampWall", Vector3(0.25, 0.35, 0.2), Vector3(1.05, 2.05, FRONT + 0.12))
	_build_yard()

const IndianHouse := preload("res://indian_house.gd")
const IndianStreet := preload("res://indian_street.gd")
const YARD_Z := 6.3
const GATE_HALF := 1.1
const MARIGOLD := [Color(1.0, 0.5, 0.04), Color(1.0, 0.76, 0.08)]

## Indian front yard: a compound wall with gate pillars, globe lamps, an open iron
## gate and a nameplate; a tulsi chaura, a parked scooter, a charpai, a marigold
## toran over the door, rangoli on the path and a DTH dish on the wall. Static
## parts merge into one vertex-coloured mesh; walls, pillars and big items are solid.
func _build_yard() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cream := Color(0.95, 0.9, 0.78)
	var maroon := Color(0.55, 0.16, 0.12)
	# [start x, end x, z] runs along the front, then [x, start z, end z] down the sides.
	for run in [[-3.3, -GATE_HALF - 0.3], [GATE_HALF + 0.3, 4.0]]:
		_yard_wall(st, Vector3((run[0] + run[1]) / 2, 0, YARD_Z), Vector3(absf(run[1] - run[0]), 1.0, 0.16), cream, maroon)
	_yard_wall(st, Vector3(-3.3, 0, (YARD_Z + FRONT) / 2), Vector3(0.16, 1.0, YARD_Z - FRONT), cream, maroon)
	_yard_wall(st, Vector3(4.0, 0, (YARD_Z + 3.8) / 2), Vector3(0.16, 1.0, YARD_Z - 3.8), cream, maroon)
	for side in [-1, 1]:
		var pillar := Vector3(side * (GATE_HALF + 0.15), 0, YARD_Z)
		IndianHouse.box(st, pillar + Vector3(0, 0.72, 0), Vector3(0.32, 1.44, 0.32), cream)
		IndianHouse.box(st, pillar + Vector3(0, 1.47, 0), Vector3(0.4, 0.07, 0.4), maroon)
		IndianStreet._ball(st, pillar + Vector3(0, 1.64, 0), 0.13, Color(0.98, 0.96, 0.88), 5, 8)
		_collider("GatePillar%d" % side, Vector3(0.32, 1.44, 0.32), pillar, 0.0)
		_gate_leaf(side)
	IndianHouse.box(st, Vector3(GATE_HALF + 0.15, 1.05, YARD_Z + 0.17), Vector3(0.26, 0.15, 0.02), Color(0.78, 0.62, 0.25))
	_tulsi(st, Vector3(-1.75, 0, 5.6))
	_scooter(st, Vector3(2.75, 0, 5.0))
	_charpai(st, Vector3(-2.6, 0, 5.0))
	# Toran over the door: marigold strings and mango leaves on a cord.
	for index in range(15):
		var x := -0.75 + index * 0.107
		var drop := 0.06 * sin(PI * index / 14.0)
		for bead in range(3 if index % 2 == 0 else 1):
			IndianStreet._ball(st, Vector3(x, DOOR_TOP + 0.24 - drop - bead * 0.07, FRONT + 0.06), 0.035, MARIGOLD[(index + bead) % 2], 3, 5)
		if index % 2 == 1:
			IndianStreet._blob(st, Vector3(x, DOOR_TOP + 0.13 - drop, FRONT + 0.05), Vector3(0.025, 0.08, 0.01), Color(0.16, 0.48, 0.14), 3, 4)
	# Rangoli on the path in front of the porch.
	var rangoli := Vector3(0, 0.03, 3.8)
	for ring in [[0.5, Color(0.85, 0.12, 0.3)], [0.38, Color(1.0, 0.75, 0.1)], [0.26, Color(0.1, 0.55, 0.45)], [0.12, Color(0.98, 0.98, 0.95)]]:
		IndianStreet._blob(st, rangoli + Vector3(0, 0.001 * (0.5 - ring[0]) * 20, 0), Vector3(ring[0], 0.004, ring[0]), ring[1], 2, 20)
	for petal in range(8):
		var angle := TAU * petal / 8.0
		IndianStreet._blob(st, rangoli + Vector3(cos(angle) * 0.62, 0.0, sin(angle) * 0.62), Vector3(0.09, 0.004, 0.09), Color(0.98, 0.45, 0.08), 2, 8)
	var mesh := MeshInstance3D.new()
	mesh.name = "Yard"
	mesh.mesh = st.commit()
	mesh.material_override = IndianHouse._material()
	add_child(mesh)
	var plate := Label3D.new()
	plate.name = "Nameplate"
	plate.text = "APNA GHAR"
	plate.font_size = 22
	plate.pixel_size = 0.004
	plate.modulate = Color(0.25, 0.12, 0.05)
	plate.outline_size = 0
	plate.position = Vector3(GATE_HALF + 0.15, 1.05, YARD_Z + 0.185)
	add_child(plate)
	_dth_dish()

func _yard_wall(st: SurfaceTool, base: Vector3, size: Vector3, colour: Color, cap: Color) -> void:
	IndianHouse.box(st, base + Vector3(0, size.y / 2, 0), size, colour)
	IndianHouse.box(st, base + Vector3(0, size.y + 0.03, 0), size + Vector3(0.06, -size.y + 0.06, 0.06), cap)
	IndianHouse.box(st, base + Vector3(0, 0.08, 0), size + Vector3(0.02, -size.y + 0.16, 0.02), Color(0.6, 0.58, 0.54))
	_collider("YardWall%d" % get_child_count(), size, base, 0.0)

## One leaf of the iron gate, hinged on its pillar and standing open into the yard.
func _gate_leaf(side: int) -> void:
	var leaf := Node3D.new()
	leaf.name = "GateLeaf%d" % side
	leaf.position = Vector3(side * GATE_HALF, 0, YARD_Z)
	leaf.rotation.y = side * deg_to_rad(-72.0)
	add_child(leaf)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var iron := Color(0.1, 0.28, 0.2)
	var width := GATE_HALF - 0.04
	for rail in [0.12, 0.6, 1.08]:
		IndianHouse.box(st, Vector3(-side * width / 2, rail, 0), Vector3(width, 0.05, 0.04), iron)
	for bar in range(11):
		var x := -side * (0.04 + bar * (width - 0.08) / 10.0)
		IndianHouse.box(st, Vector3(x, 0.62, 0), Vector3(0.025, 1.1, 0.025), iron)
		IndianStreet._ball(st, Vector3(x, 1.2, 0), 0.025, Color(0.85, 0.68, 0.2), 2, 4)
	var mesh := MeshInstance3D.new()
	mesh.name = "Bars"
	mesh.mesh = st.commit()
	mesh.material_override = IndianHouse._material()
	leaf.add_child(mesh)

func _tulsi(st: SurfaceTool, base: Vector3) -> void:
	IndianHouse.box(st, base + Vector3(0, 0.32, 0), Vector3(0.5, 0.64, 0.5), Color(0.92, 0.45, 0.18))
	IndianHouse.box(st, base + Vector3(0, 0.66, 0), Vector3(0.56, 0.06, 0.56), Color(0.98, 0.95, 0.88))
	IndianHouse.box(st, base + Vector3(0, 0.36, 0.252), Vector3(0.16, 0.16, 0.01), Color(0.98, 0.95, 0.88))
	for leaf in range(9):
		var angle := TAU * leaf / 9.0
		var lift := 0.08 * (leaf % 3)
		IndianStreet._blob(st, base + Vector3(cos(angle) * 0.1, 0.82 + lift, sin(angle) * 0.1), Vector3(0.09, 0.07, 0.09), Color(0.16, 0.45, 0.15).lightened(0.05 * (leaf % 3)), 3, 6)
	_collider("TulsiChauraBody", Vector3(0.5, 0.7, 0.5), base, 0.0)

## A parked scooter (Activa style) facing the gate.
func _scooter(st: SurfaceTool, base: Vector3) -> void:
	var paint := Color(0.62, 0.1, 0.12)
	var black := Color(0.08, 0.08, 0.09)
	for z in [-0.6, 0.62]:
		IndianStreet._blob(st, base + Vector3(0, 0.24, z), Vector3(0.06, 0.24, 0.24), black, 5, 12)
		IndianStreet._blob(st, base + Vector3(0, 0.24, z), Vector3(0.065, 0.1, 0.1), Color(0.75, 0.76, 0.76), 3, 8)
	IndianStreet._blob(st, base + Vector3(0, 0.55, -0.42), Vector3(0.24, 0.24, 0.42), paint, 6, 12)
	IndianHouse.box(st, base + Vector3(0, 0.3, 0.08), Vector3(0.3, 0.08, 0.6), Color(0.18, 0.18, 0.19))
	IndianStreet._beam(st, base + Vector3(0, 0.3, 0.5), base + Vector3(0, 0.95, 0.6), 0.3, paint)
	IndianStreet._blob(st, base + Vector3(0, 0.8, -0.38), Vector3(0.17, 0.06, 0.34), black, 4, 10)
	IndianStreet._beam(st, base + Vector3(0, 0.95, 0.6), base + Vector3(0, 1.05, 0.55), 0.08, black)
	IndianStreet._beam(st, base + Vector3(-0.32, 1.05, 0.55), base + Vector3(0.32, 1.05, 0.55), 0.035, Color(0.6, 0.62, 0.63))
	IndianStreet._blob(st, base + Vector3(0, 1.02, 0.66), Vector3(0.09, 0.07, 0.04), Color(0.98, 0.97, 0.85), 3, 8)
	_collider("ScooterBody", Vector3(0.5, 1.0, 1.6), base, 0.0)

## A charpai (rope cot) resting against the side wall.
func _charpai(st: SurfaceTool, base: Vector3) -> void:
	var wood := Color(0.45, 0.28, 0.15)
	for x in [-0.4, 0.4]:
		for z in [-0.9, 0.9]:
			IndianHouse.box(st, base + Vector3(x, 0.22, z), Vector3(0.07, 0.44, 0.07), wood)
	for x in [-0.4, 0.4]:
		IndianHouse.box(st, base + Vector3(x, 0.42, 0), Vector3(0.06, 0.06, 1.86), wood)
	for z in [-0.9, 0.9]:
		IndianHouse.box(st, base + Vector3(0, 0.42, z), Vector3(0.86, 0.06, 0.06), wood)
	IndianHouse.box(st, base + Vector3(0, 0.43, 0), Vector3(0.76, 0.02, 1.76), Color(0.86, 0.77, 0.58))
	for stripe in range(8):
		IndianHouse.box(st, base + Vector3(0, 0.442, -0.77 + stripe * 0.22), Vector3(0.76, 0.006, 0.05), Color(0.72, 0.6, 0.4))
	_collider("CharpaiBody", Vector3(0.9, 0.46, 1.9), base, 0.0)

## A DTH dish on a bracket high on the front wall.
func _dth_dish() -> void:
	var dish := MeshInstance3D.new()
	dish.name = "DthDish"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	IndianHouse.disc(st, Vector3.ZERO, 0.28, 0.03, Color(0.92, 0.92, 0.9), 16)
	IndianStreet._beam(st, Vector3(0, -0.2, 0.0), Vector3(0, 0.0, 0.35), 0.025, Color(0.5, 0.5, 0.5))
	IndianStreet._blob(st, Vector3(0, 0.0, 0.36), Vector3(0.04, 0.04, 0.05), Color(0.3, 0.3, 0.32), 3, 6)
	IndianStreet._beam(st, Vector3(0, -0.28, -0.25), Vector3(0, -0.05, -0.02), 0.04, Color(0.4, 0.4, 0.42))
	dish.mesh = st.commit()
	dish.material_override = IndianHouse._material()
	dish.position = Vector3(2.55, 2.55, FRONT + 0.3)
	dish.rotation = Vector3(-0.5, 0.4, 0)
	add_child(dish)

func _retire_old_house(house: Node) -> void:
	for node_path in ["Walls", "Roof", "LeftWindow", "RightWindow", "RoofBody"]:
		var node := house.get_node_or_null(node_path)
		if node == null: continue
		if node is MeshInstance3D: node.hide()
		for child in node.get_children():
			if child is MeshInstance3D: child.hide()
			if child is CollisionShape3D: child.disabled = true
	for part in ["Bed/MeshInstance3D", "Bed/Pillow"]:
		var node := house.get_node_or_null(part) as Node3D
		if node != null: node.hide()

func _refit_gameplay_nodes(house: Node) -> void:
	var bed := house.get_node_or_null("Bed") as Node3D
	if bed != null:
		bed.position = Vector3(-1.95, 0.3, -2.55)
		var shape := bed.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape != null:
			shape.shape = BoxShape3D.new()
			shape.shape.size = Vector3(1.4, 0.5, 1.95)
		# The sleep zone covers the whole bedroom corner, including the spawn point.
		var sleep := bed.get_node_or_null("SleepArea") as Area3D
		if sleep != null:
			sleep.position = Vector3(0.15, 0.9, 0.6)
			var zone := sleep.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if zone != null:
				zone.shape = BoxShape3D.new()
				zone.shape.size = Vector3(2.4, 2.5, 3.1)
	var interior := house.get_node_or_null("InteriorArea/CollisionShape3D") as CollisionShape3D
	if interior != null:
		interior.get_parent().position = Vector3(0, 1.5, (FRONT + BACK) / 2)
		interior.shape = BoxShape3D.new()
		interior.shape.size = Vector3(HALF_WIDTH * 2 - 0.4, 2.8, FRONT - BACK - 0.4)
	var sign := house.get_node_or_null("HouseSign") as Node3D
	if sign != null: sign.position = Vector3(0, 2.65, FRONT + 0.13)
	var light := house.get_node_or_null("InteriorLight") as OmniLight3D
	if light != null:
		light.position = Vector3(0, 2.7, (FRONT + BACK) / 2)
		light.omni_range = 6.0

func _build_shell() -> void:
	var wall := _material(Color(0.97, 0.84, 0.56))
	var trim := _material(Color(0.45, 0.28, 0.18))
	var floor := _material(Color(0.6, 0.44, 0.3))
	var mid_z := (FRONT + BACK) / 2
	var depth := FRONT - BACK
	# Top sits 1.5 cm above the ground plane so the grass never shows through.
	_solid("Floor", Vector3(HALF_WIDTH * 2, 0.1, depth), Vector3(0, -0.035, mid_z), floor)
	_solid("BackWall", Vector3(HALF_WIDTH * 2, WALL_HEIGHT, THICK), Vector3(0, WALL_HEIGHT / 2, BACK + THICK / 2), wall)
	for side in [-1, 1]:
		_solid("SideWall%d" % side, Vector3(THICK, WALL_HEIGHT, depth), Vector3(side * (HALF_WIDTH - THICK / 2), WALL_HEIGHT / 2, mid_z), wall)
		var front_width := HALF_WIDTH - DOOR_HALF
		_solid("FrontWall%d" % side, Vector3(front_width, WALL_HEIGHT, THICK), Vector3(side * (DOOR_HALF + front_width / 2), WALL_HEIGHT / 2, FRONT - THICK / 2), wall)
		_mesh("DoorPost%d" % side, Vector3(0.12, DOOR_TOP, 0.26), Vector3(side * (DOOR_HALF + 0.03), DOOR_TOP / 2, FRONT - THICK / 2), trim)
	_solid("DoorHeader", Vector3(DOOR_HALF * 2, WALL_HEIGHT - DOOR_TOP, THICK), Vector3(0, (WALL_HEIGHT + DOOR_TOP) / 2, FRONT - THICK / 2), wall)
	_mesh("DoorLintel", Vector3(DOOR_HALF * 2 + 0.24, 0.12, 0.26), Vector3(0, DOOR_TOP + 0.06, FRONT - THICK / 2), trim)
	# Bedroom partition with an open passage toward the front of the house.
	_solid("BedroomWall", Vector3(THICK * 0.6, WALL_HEIGHT, 2.1), Vector3(-0.55, WALL_HEIGHT / 2, BACK + 1.05), wall)
	_mesh("Ceiling", Vector3(HALF_WIDTH * 2, 0.05, depth), Vector3(0, WALL_HEIGHT + 0.02, mid_z), _material(Color(0.97, 0.95, 0.9)))
	_mesh("Porch", Vector3(2.4, 0.12, 1.0), Vector3(0, 0.06, FRONT + 0.5), _material(Color(0.66, 0.64, 0.6)))

func _build_roof() -> void:
	var tiles := _material(Color(0.66, 0.27, 0.2))
	var gable := _material(Color(0.95, 0.81, 0.53))
	var mid_z := (FRONT + BACK) / 2
	var half_depth := (FRONT - BACK) / 2 + 0.35
	var angle := deg_to_rad(30.0)
	var rise := half_depth * tan(angle)
	for side in [-1, 1]:
		var slab := _mesh("RoofSlab%d" % side, Vector3(HALF_WIDTH * 2 + 0.6, 0.14, half_depth / cos(angle) + 0.1), Vector3(0, WALL_HEIGHT + rise / 2 + 0.05, mid_z + side * half_depth / 2), tiles)
		slab.rotation.x = side * angle
		var prism := PrismMesh.new()
		prism.size = Vector3(FRONT - BACK, rise, 0.18)
		var end := MeshInstance3D.new()
		end.name = "Gable%d" % side
		end.mesh = prism
		end.material_override = gable
		end.position = Vector3(side * (HALF_WIDTH - 0.1), WALL_HEIGHT + rise / 2, mid_z)
		end.rotation.y = PI / 2
		add_child(end)
	_mesh("RoofRidge", Vector3(HALF_WIDTH * 2 + 0.7, 0.12, 0.18), Vector3(0, WALL_HEIGHT + rise + 0.08, mid_z), _material(Color(0.5, 0.2, 0.15)))
	# Keeps the third-person camera from clipping into the attic.
	var roof_shape := CollisionShape3D.new()
	roof_shape.shape = BoxShape3D.new()
	roof_shape.shape.size = Vector3(HALF_WIDTH * 2, 0.2, FRONT - BACK)
	roof_shape.position = Vector3(0, WALL_HEIGHT + 0.12, mid_z)
	walls.add_child(roof_shape)

func _build_windows() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.78, 0.86, 0.55)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	var frame := _material(Color(0.97, 0.97, 0.94))
	var spots := [
		[Vector3(-1.95, 1.55, FRONT), 0.0], [Vector3(1.95, 1.55, FRONT), 0.0],
		[Vector3(-HALF_WIDTH, 1.55, -2.2), PI / 2], [Vector3(HALF_WIDTH, 1.55, -0.2), PI / 2],
		[Vector3(-1.9, 1.7, BACK), 0.0], [Vector3(1.6, 1.7, BACK), 0.0],
	]
	for index in range(spots.size()):
		var holder := Node3D.new()
		holder.name = "Window%d" % index
		holder.position = spots[index][0]
		holder.rotation.y = spots[index][1]
		add_child(holder)
		for face in [-1, 1]:
			var pane := _mesh("Glass%d" % face, Vector3(1.1, 0.95, 0.02), Vector3(0, 0, face * (THICK / 2 + 0.012)), glass, holder)
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for edge in [[Vector3(1.25, 0.08, 0.05), Vector3(0, 0.51, 0)], [Vector3(1.25, 0.08, 0.05), Vector3(0, -0.51, 0)], [Vector3(0.08, 1.1, 0.05), Vector3(0.6, 0, 0)], [Vector3(0.08, 1.1, 0.05), Vector3(-0.6, 0, 0)], [Vector3(0.05, 0.95, 0.04), Vector3.ZERO]]:
				_mesh("Frame", edge[0], edge[1] + Vector3(0, 0, face * (THICK / 2 + 0.03)), frame, holder)
		_mesh("Sill", Vector3(1.35, 0.06, 0.32), Vector3(0, -0.56, 0), frame, holder)

func _solid(node_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	_mesh(node_name, size, position, material)
	var shape := CollisionShape3D.new()
	shape.name = node_name + "Shape"
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	shape.position = position
	walls.add_child(shape)

func _mesh(node_name: String, size: Vector3, position: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = position
	(parent if parent != null else self).add_child(node, true)
	return node

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _collider(node_name: String, size: Vector3, position: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position + Vector3(0, size.y / 2, 0)
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	add_child(body)
