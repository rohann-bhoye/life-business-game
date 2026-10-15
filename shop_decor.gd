extends Node3D

# Decorative shop interior: high wall shelves of groceries, ceiling fans, wall
# paint band, signs, entrance mat and a sweets display at the counter.
# Everything sits on walls, the ceiling or the counter so the floor stays free
# for rack placement and customer routes. Nothing here affects gameplay.
const Kenney = preload("res://kenney_assets.gd")
const FOOD := "res://assets/products/kenney/%s.glb"
const FURNITURE := "res://assets/furniture/kenney/%s.glb"
const GROCERIES := ["bottle-oil", "carton", "honey", "can", "peanut-butter", "bottle-ketchup", "carton-small", "can-small", "soda-can", "loaf"]
const ROOM_MIN_X := -5.94
const ROOM_MAX_X := -0.06
const BACK_Z := -7.44
const FRONT_Z := 2.44
const SHELF_HEIGHTS := [2.35, 2.85]

var fans: Array[Node3D] = []

func build(counter: Node3D) -> void:
	name = "ShopDecor"
	var board := _material(Color(0.55, 0.36, 0.2))
	var bracket := _material(Color(0.2, 0.22, 0.24))
	var placements := {}
	for id in GROCERIES: placements[id] = [] as Array[Transform3D]
	# Right wall shelves (behind the management desk, above head height).
	_wall_shelf(Vector3(ROOM_MAX_X - 0.16, 0, -4.9), Vector3(0.3, 0.04, 4.6), board, bracket, placements, 0)
	# Back wall shelves.
	_wall_shelf(Vector3(-3.0, 0, BACK_Z + 0.16), Vector3(5.6, 0.04, 0.3), board, bracket, placements, 5)
	for id in placements:
		if not placements[id].is_empty(): Kenney.batch(self, "Shelf_" + id, FOOD % id, placements[id])
	_paint_band()
	for z in [-1.4, -5.2]:
		var fan := Kenney.fit(self, "CeilingFan%d" % fans.size(), FURNITURE % "ceilingFan", Vector3(1.3, 0.5, 1.3), Vector3(-3.0, 3.25, z))
		fans.append(fan)
	Kenney.fit(self, "EntranceMat", FURNITURE % "rugDoormat", Vector3(1.4, 0.02, 0.8), Vector3(-3.0, 0.005, 1.9))
	_sign_panel("OfferBoard", "AAJ KA OFFER\nFresh stock every day!", Vector3(ROOM_MAX_X - 0.02, 1.75, 1.3), -PI / 2, Vector2(1.1, 0.55), Color(0.85, 0.2, 0.18))
	_sign_panel("PaymentBoard", "CASH  |  CARD  |  UPI\nAll payments accepted", Vector3(ROOM_MAX_X - 0.02, 1.75, -0.1), -PI / 2, Vector2(1.1, 0.5), Color(0.1, 0.42, 0.36))
	_sign_panel("WelcomeBoard", "APNA MART\nDaily needs - Fresh - Sasta", Vector3(-3.0, 3.48, BACK_Z + 0.02), 0.0, Vector2(2.6, 0.5), Color(0.12, 0.3, 0.26))
	_counter_sweets(counter)

func _wall_shelf(center: Vector3, size: Vector3, board: Material, bracket: Material, placements: Dictionary, seed: int) -> void:
	var along_z := size.z > size.x
	var length := size.z if along_z else size.x
	var count := int(length / 0.24)
	for level in range(SHELF_HEIGHTS.size()):
		var y: float = SHELF_HEIGHTS[level]
		_box("WallShelf", Vector3(center.x, y, center.z), size, board)
		for end in [-1, 1]:
			var offset := Vector3(0, -0.08, end * (length / 2 - 0.15)) if along_z else Vector3(end * (length / 2 - 0.15), -0.08, 0)
			_box("ShelfBracket", Vector3(center.x, y, center.z) + offset, Vector3(0.04, 0.14, 0.24) if not along_z else Vector3(0.24, 0.14, 0.04), bracket)
		for index in range(count):
			var id: String = GROCERIES[(index / 3 + level * 4 + seed) % GROCERIES.size()]
			var t := -length / 2 + 0.14 + index * (length - 0.28) / maxf(count - 1, 1)
			var spot := Vector3(center.x, y + 0.02, center.z + t) if along_z else Vector3(center.x + t, y + 0.02, center.z)
			var factor := Kenney.height_factor(FOOD % id, 0.22 if id != "loaf" else 0.14)
			var yaw := -PI / 2 if along_z else 0.0
			placements[id].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * factor), spot))

func _paint_band() -> void:
	var paint := _material(Color(0.93, 0.74, 0.38))
	var stripe := _material(Color(0.12, 0.3, 0.26))
	var depth := FRONT_Z - BACK_Z
	var mid_z := (FRONT_Z + BACK_Z) / 2
	for side in [[ROOM_MIN_X + 0.006, mid_z, Vector3(0.012, 1.0, depth)], [ROOM_MAX_X - 0.006, mid_z, Vector3(0.012, 1.0, depth)]]:
		_box("WallPaint", Vector3(side[0], 0.5, side[1]), side[2], paint)
		_box("WallStripe", Vector3(side[0], 1.03, side[1]), Vector3(0.016, 0.06, depth), stripe)
	_box("WallPaint", Vector3(-3.0, 0.5, BACK_Z + 0.006), Vector3(5.88, 1.0, 0.012), paint)
	_box("WallStripe", Vector3(-3.0, 1.03, BACK_Z + 0.008), Vector3(5.88, 0.06, 0.016), stripe)

func _counter_sweets(counter: Node3D) -> void:
	var top := 0.58
	var tray := _box("SweetsTray", Vector3(-1.3, top + 0.01, 0.12), Vector3(0.24, 0.02, 0.4), _material(Color(0.85, 0.82, 0.74)))
	remove_child(tray)
	counter.add_child(tray)
	var bars: Array[Transform3D] = []
	for index in range(3):
		var factor := Kenney.height_factor(FOOD % "chocolate-wrapper", 0.03)
		bars.append(Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3.ONE * factor), Vector3(-1.3, top + 0.02 + index * 0.03, 0.02)))
	Kenney.batch(counter, "CounterChocolates", FOOD % "chocolate-wrapper", bars)
	var pops: Array[Transform3D] = []
	for index in range(4):
		var factor := Kenney.height_factor(FOOD % "lollypop", 0.2)
		pops.append(Transform3D(Basis(Vector3.UP, index * 0.8).scaled(Vector3.ONE * factor), Vector3(-1.34 + (index % 2) * 0.08, top + 0.02, 0.2 + (index / 2) * 0.07)))
	Kenney.batch(counter, "CounterLollypops", FOOD % "lollypop", pops)

func _sign_panel(node_name: String, text: String, position: Vector3, yaw: float, size: Vector2, color: Color) -> void:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = position
	holder.rotation.y = yaw
	add_child(holder)
	var back := MeshInstance3D.new()
	back.name = "Panel"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, 0.03)
	back.mesh = mesh
	back.material_override = _material(color)
	holder.add_child(back)
	var label := Label3D.new()
	label.name = "Text"
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.0022
	label.outline_size = 0
	label.modulate = Color(1, 0.97, 0.88)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.width = size.x / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position.z = 0.02
	holder.add_child(label)

func _box(node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = position
	add_child(node, true)
	return node

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _process(delta: float) -> void:
	for fan in fans: fan.rotate_y(delta * 4.0)
