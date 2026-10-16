extends Node3D

# Builds the player's home: a 6.4 x 5.5 m house with a gable roof, window frames,
# a bedroom corner, living area, kitchen and dining table (Kenney Furniture Kit).
# The original house.tscn nodes the game relies on are kept and re-fitted:
# HouseArea (door menu), InteriorArea (first-person indoors), Bed + SleepArea,
# FrontDoor and HouseSign. Old block walls/roof are hidden and their colliders off.
const Kenney = preload("res://kenney_assets.gd")
const FURNITURE := "res://assets/furniture/kenney/%s.glb"
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
	["rugRectangle", Vector3(1.9, 0.02, 1.5), Vector3(1.9, 0.004, -1.7), 0.0, false],
	["cabinetTelevision", Vector3(1.2, 0.55, 0.45), Vector3(2.85, 0.0, -1.7), -PI / 2, true],
	["televisionModern", Vector3(1.0, 0.65, 0.25), Vector3(2.9, 0.55, -1.7), -PI / 2, false],
	["tableCoffee", Vector3(0.8, 0.4, 0.5), Vector3(1.85, 0.0, -1.7), PI / 2, true],
	["loungeSofa", Vector3(1.6, 0.85, 0.8), Vector3(0.75, 0.0, -1.7), PI / 2, true],
	["bookcaseOpen", Vector3(1.2, 1.6, 0.4), Vector3(1.8, 0.0, -3.35), 0.0, true],
	["pottedPlant", Vector3(0.45, 1.0, 0.45), Vector3(2.85, 0.0, -3.25), 0.0, false],
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
		var holder := Kenney.fit(self, "%s%d" % [piece[0], index], FURNITURE % piece[0], piece[1], piece[2], piece[3])
		if piece[4]: _collider(holder.name + "Body", piece[1], piece[2], piece[3])
	Kenney.fit(self, "PorchLamp", FURNITURE % "lampWall", Vector3(0.25, 0.35, 0.2), Vector3(1.05, 2.05, FRONT + 0.12))

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
	var wall := _material(Color(0.93, 0.87, 0.74))
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
	var gable := _material(Color(0.9, 0.82, 0.68))
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
