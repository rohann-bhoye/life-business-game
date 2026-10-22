extends Node3D

# Decorative shop interior: high wall shelves of groceries, ceiling fans, wall
# paint band, signs, entrance mat and a sweets display at the counter.
# Everything sits on walls, the ceiling or the counter so the floor stays free
# for rack placement and customer routes. Nothing here affects gameplay.
const Kenney = preload("res://kenney_assets.gd")
const FOOD := "res://assets/products/kenney/%s.glb"
const FURNITURE := "res://assets/furniture/kenney/%s.glb"
## The wall shelves show the shop's own catalogue (product_catalog.gd), grouped in
## blocks of four like a real kirana: the same models as on the racks.
const WALL_PRODUCTS := ["bottle", "snack", "oil", "milk", "honey", "bread", "soap", "chocolate"]
const WALL_HEIGHTS := {"bottle": 0.27, "snack": 0.23, "oil": 0.27, "milk": 0.21, "honey": 0.15, "bread": 0.12, "soap": 0.1, "chocolate": 0.05}
## Flat packs are stacked.
const WALL_STACKS := {"soap": 2, "chocolate": 3}
const ProductAssets = preload("res://product_assets.gd")
const HouseParts = preload("res://indian_house.gd")
const ROOM_MIN_X := -5.94
const ROOM_MAX_X := -0.06
const BACK_Z := -7.44
## The doorway into the packing room in the left wall (world z), see
## shop_operations.gd SIDE_DOOR: the paint band and stripe stop either side of it.
const SIDE_DOOR := Vector2(0.75, 1.95)
const FRONT_Z := 2.44
const SHELF_HEIGHTS := [2.35, 2.85]
# Indian shop touches: marigold torans, rangoli, tulsi planter and a small mandir.
const MARIGOLD := [Color(1.0, 0.5, 0.04), Color(1.0, 0.76, 0.08)]
const LEAF := Color(0.16, 0.48, 0.14)
# The front doorway is 2 m wide (x -4..-2) and 2.4 m high; the wall's outer face is z 2.56.
const DOOR_X := -3.0
const DOOR_TOP := 2.44

var fans: Array[Node3D] = []
## Shelves, paint and the welcome board on the back wall: they move back together
## when the shop is expanded (set_back).
var back_wall: Node3D
var diya_light: OmniLight3D
var flicker := 0.0

func build(counter: Node3D) -> void:
	name = "ShopDecor"
	var board := _material(Color(0.55, 0.36, 0.2))
	var bracket := _material(Color(0.2, 0.22, 0.24))
	var placements := {}
	for id in WALL_PRODUCTS: placements[id] = [] as Array[Transform3D]
	# Right wall shelves (behind the management desk, above head height).
	_wall_shelf(Vector3(ROOM_MAX_X - 0.16, 0, -4.9), Vector3(0.3, 0.04, 4.6), board, bracket, placements, 0)
	# Back wall shelves, with their own product batches so they can move with the wall.
	back_wall = Node3D.new()
	back_wall.name = "BackWallDecor"
	add_child(back_wall)
	var back_placements := {}
	for id in WALL_PRODUCTS: back_placements[id] = [] as Array[Transform3D]
	_wall_shelf(Vector3(-3.0, 0, BACK_Z + 0.16), Vector3(5.6, 0.04, 0.3), board, bracket, back_placements, 5)
	for id in placements:
		if not placements[id].is_empty(): _wall_batch(self, "Shelf_" + id, id, placements[id])
		if not back_placements[id].is_empty(): _wall_batch(back_wall, "BackShelf_" + id, id, back_placements[id])
	_paint_band()
	# Between the two ceiling lights (z -1.3 and -5.2), hanging from the 3.9 m ceiling.
	for z in [-3.25, 0.45]: fans.append(_ceiling_fan(Vector3(-3.0, 3.9, z)))
	Kenney.fit(self, "EntranceMat", FURNITURE % "rugDoormat", Vector3(1.4, 0.02, 0.8), Vector3(-3.0, 0.005, 1.9))
	_sign_panel("OfferBoard", "AAJ KA OFFER\nFresh stock every day!", Vector3(ROOM_MAX_X - 0.02, 1.75, 1.3), -PI / 2, Vector2(1.1, 0.55), Color(0.85, 0.2, 0.18))
	_sign_panel("PaymentBoard", "CASH  |  CARD  |  UPI\nAll payments accepted", Vector3(ROOM_MAX_X - 0.02, 1.75, -0.1), -PI / 2, Vector2(1.1, 0.5), Color(0.1, 0.42, 0.36))
	_sign_panel("WelcomeBoard", "APNA MART\nDaily needs - Fresh - Sasta", Vector3(-3.0, 3.48, BACK_Z + 0.02), 0.0, Vector2(2.6, 0.5), Color(0.12, 0.3, 0.26))
	_counter_sweets(counter)
	_counter_details(counter)
	_indian_touches()
	# Everything built against the back wall joins back_wall.
	for child in get_children():
		if child is Node3D and child != back_wall and child.position.z < BACK_Z + 0.3:
			child.reparent(back_wall)

## Moves the back-wall decor to a wall at `back_z` and stretches the side paint bands.
func set_back(back_z: float) -> void:
	back_wall.position.z = back_z - BACK_Z
	for child in get_children():
		if child is MeshInstance3D and (child.name.begins_with("WallPaint") or child.name.begins_with("WallStripe")):
			if child.name.ends_with("LeftFront"): continue
			var front: float = SIDE_DOOR.x if child.name.ends_with("Left") else FRONT_Z
			child.mesh.size.z = front - back_z
			child.position.z = (front + back_z) / 2

func _indian_touches() -> void:
	for z in [FRONT_Z - 0.05, 2.62]: _toran("Toran", Vector3(DOOR_X, DOOR_TOP, z), 1.9)
	_rangoli(Vector3(DOOR_X, 0.126, 3.2))
	_tulsi(Vector3(-4.45, 0.1, 2.95))
	_mandir(Vector3(ROOM_MAX_X - 0.02, 1.55, -1.3))

## Instanced spheres; each item is [Transform3D, Color].
func _spheres(node_name: String, radius: float, items: Array, parent: Node = self) -> MultiMeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.8
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = items.size()
	for index in range(items.size()):
		multimesh.set_instance_transform(index, items[index][0])
		multimesh.set_instance_color(index, items[index][1])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node, true)
	return node

## Marigold strings hanging from a cord, with mango leaves between them.
func _toran(node_name: String, center: Vector3, width: float) -> void:
	var flowers: Array = []
	var leaves: Array = []
	var strands := int(width / 0.1)
	for index in range(strands + 1):
		var x := -width / 2 + index * width / strands
		flowers.append([Transform3D(Basis(), center + Vector3(x, 0, 0)), MARIGOLD[index % 2]])
		if index % 2 == 0:
			for drop in range(1, 4 + int(index % 4 == 0)):
				flowers.append([Transform3D(Basis(), center + Vector3(x, -drop * 0.062, 0)), MARIGOLD[(index / 2 + drop) % 2]])
		else:
			var tilt := Basis(Vector3.FORWARD, 0.25 * (1 if index % 4 == 1 else -1))
			leaves.append([Transform3D(tilt.scaled(Vector3(0.45, 1.6, 0.12)), center + Vector3(x, -0.085, 0)), LEAF])
	_spheres(node_name + "Flowers", 0.034, flowers)
	_spheres(node_name + "Leaves", 0.05, leaves)

## A round rangoli on the pavement: coloured rings, petals and white dots.
func _rangoli(center: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "Rangoli"
	holder.position = center
	add_child(holder)
	var rings := [[0.52, Color(0.86, 0.12, 0.45)], [0.44, Color(1.0, 0.8, 0.12)], [0.35, Color(0.1, 0.62, 0.35)], [0.26, Color(1.0, 0.45, 0.05)], [0.16, Color(0.98, 0.96, 0.9)], [0.08, Color(0.85, 0.1, 0.12)]]
	for index in range(rings.size()):
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = rings[index][0]
		mesh.bottom_radius = rings[index][0]
		mesh.height = 0.004
		mesh.radial_segments = 32
		disc.mesh = mesh
		disc.material_override = _material(rings[index][1])
		disc.position.y = index * 0.0015
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(disc)
	var petals: Array = []
	for index in range(8):
		var angle := index * TAU / 8
		var basis := Basis(Vector3.UP, -angle).scaled(Vector3(1.0, 0.05, 0.45))
		petals.append([Transform3D(basis, Vector3(cos(angle), 0.012, sin(angle)) * Vector3(0.4, 1, 0.4) + Vector3(0, 0.012, 0)), Color(0.55, 0.2, 0.75) if index % 2 else Color(0.98, 0.3, 0.2)])
	_spheres("Petals", 0.09, petals, holder)
	var dots: Array = []
	for index in range(20):
		var angle := index * TAU / 20
		dots.append([Transform3D(Basis().scaled(Vector3(1, 0.3, 1)), Vector3(cos(angle) * 0.57, 0.004, sin(angle) * 0.57)), Color(0.98, 0.97, 0.92)])
	_spheres("Dots", 0.022, dots, holder)

## A tulsi planter: terracotta box with a saffron band and a leafy plant.
func _tulsi(base: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "TulsiPlanter"
	holder.position = base
	add_child(holder)
	var pot := _box("Pot", Vector3.ZERO, Vector3(0.38, 0.46, 0.38), _material(Color(0.72, 0.33, 0.2)))
	pot.reparent(holder, false)
	pot.position = Vector3(0, 0.23, 0)
	var band := _box("Band", Vector3.ZERO, Vector3(0.39, 0.06, 0.39), _material(Color(0.98, 0.55, 0.1)))
	band.reparent(holder, false)
	band.position = Vector3(0, 0.38, 0)
	var leaves: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for index in range(18):
		var spot := Vector3(rng.randf_range(-0.13, 0.13), 0.52 + rng.randf_range(0.0, 0.3), rng.randf_range(-0.13, 0.13))
		leaves.append([Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), spot), LEAF.lerp(Color(0.25, 0.6, 0.2), rng.randf())])
	for index in range(6):
		leaves.append([Transform3D(Basis().scaled(Vector3(0.5, 1.4, 0.5)), Vector3(rng.randf_range(-0.1, 0.1), 0.86 + rng.randf_range(0.0, 0.06), rng.randf_range(-0.1, 0.1))), Color(0.45, 0.22, 0.5)])
	_spheres("Leaves", 0.065, leaves, holder)

## A small wall mandir by the counter: shelf, red cloth, framed picture with a
## marigold garland, two diyas with a warm flickering light and SHUBH LABH below.
func _mandir(wall_point: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "Mandir"
	holder.position = wall_point
	holder.rotation.y = -PI / 2
	add_child(holder)
	var parts := [
		["Shelf", Vector3(0, 0, 0.13), Vector3(0.7, 0.04, 0.26), Color(0.5, 0.3, 0.16)],
		["Cloth", Vector3(0, 0.022, 0.13), Vector3(0.64, 0.006, 0.25), Color(0.78, 0.08, 0.1)],
		["ClothFront", Vector3(0, -0.01, 0.262), Vector3(0.64, 0.07, 0.006), Color(0.78, 0.08, 0.1)],
		["Frame", Vector3(0, 0.25, 0.03), Vector3(0.38, 0.44, 0.03), Color(0.86, 0.64, 0.18)],
		["Picture", Vector3(0, 0.25, 0.048), Vector3(0.3, 0.36, 0.006), Color(1.0, 0.56, 0.12)],
		["Halo", Vector3(0, 0.3, 0.053), Vector3(0.16, 0.16, 0.004), Color(1.0, 0.86, 0.36)],
		["LabhBoard", Vector3(0, -0.17, 0.02), Vector3(0.62, 0.16, 0.02), Color(0.99, 0.84, 0.22)],
	]
	for part in parts:
		var node := _box(part[0], Vector3.ZERO, part[2], _material(part[3]))
		node.reparent(holder, false)
		node.position = part[1]
	for side in [-1, 1]:
		var bracket := _box("Bracket", Vector3.ZERO, Vector3(0.03, 0.12, 0.22), _material(Color(0.2, 0.22, 0.24)))
		bracket.reparent(holder, false)
		bracket.position = Vector3(side * 0.28, -0.08, 0.11)
	var garland: Array = []
	for index in range(15):
		var t := index / 14.0
		garland.append([Transform3D(Basis(), Vector3(lerpf(-0.19, 0.19, t), 0.47 - 0.14 * sin(PI * t), 0.07)), MARIGOLD[index % 2]])
	_spheres("Garland", 0.024, garland, holder)
	var flame_material := StandardMaterial3D.new()
	flame_material.albedo_color = Color(1.0, 0.72, 0.2)
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.6, 0.15)
	flame_material.emission_energy_multiplier = 3.0
	for side in [-1, 1]:
		var bowl := MeshInstance3D.new()
		var clay := CylinderMesh.new()
		clay.top_radius = 0.045
		clay.bottom_radius = 0.028
		clay.height = 0.028
		bowl.mesh = clay
		bowl.material_override = _material(Color(0.6, 0.3, 0.16))
		bowl.position = Vector3(side * 0.22, 0.04, 0.17)
		holder.add_child(bowl)
		var flame := MeshInstance3D.new()
		var tip := SphereMesh.new()
		tip.radius = 0.012
		tip.height = 0.052
		flame.mesh = tip
		flame.material_override = flame_material
		flame.position = Vector3(side * 0.22, 0.078, 0.17)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(flame)
	diya_light = OmniLight3D.new()
	diya_light.name = "DiyaLight"
	diya_light.light_color = Color(1.0, 0.62, 0.28)
	diya_light.light_energy = 0.7
	diya_light.omni_range = 1.1
	diya_light.position = Vector3(0, 0.14, 0.22)
	holder.add_child(diya_light)
	var words := Label3D.new()
	words.name = "ShubhLabh"
	words.text = "SHUBH   LABH"
	words.font_size = 44
	words.pixel_size = 0.0021
	words.outline_size = 0
	words.modulate = Color(0.72, 0.06, 0.08)
	words.position = Vector3(0, -0.17, 0.034)
	holder.add_child(words)

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
			var id: String = WALL_PRODUCTS[(index / 4 + level * 3 + seed) % WALL_PRODUCTS.size()]
			var t := -length / 2 + 0.14 + index * (length - 0.28) / maxf(count - 1, 1)
			var spot := Vector3(center.x, y + 0.02, center.z + t) if along_z else Vector3(center.x + t, y + 0.02, center.z)
			# Rack products show their label on +x: turn it to face the room.
			var yaw := PI if along_z else -PI / 2
			var factor: float = WALL_HEIGHTS[id] / maxf(0.01, _baked(id).get_aabb().size.y)
			for layer in range(WALL_STACKS.get(id, 1)):
				placements[id].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * factor), spot + Vector3(0, layer * WALL_HEIGHTS[id], 0)))

var baked := {}
## Each product's wall batches (right wall, back wall): show_stock shows as many items
## as the shop owns.
var wall_batches := {}

## The product exactly as on the racks (shop_operations.gd make_product: model,
## label band, cap), merged into one mesh so a whole shelf is one batch.
func _baked(id: String) -> ArrayMesh:
	if baked.has(id): return baked[id]
	var holder := Node3D.new()
	add_child(holder)
	var item: Node3D = get_parent().make_product(holder, "Bake", Vector3.ZERO, id)
	var mesh := ArrayMesh.new()
	for node in item.find_children("*", "MeshInstance3D", true, false):
		if not node.is_visible_in_tree() or node.mesh == null: continue
		var to_item: Transform3D = item.global_transform.affine_inverse() * node.global_transform
		for surface in range(node.mesh.get_surface_count()):
			var tool := SurfaceTool.new()
			tool.append_from(node.mesh, surface, to_item)
			tool.set_material(node.material_override if node.material_override != null else node.get_active_material(surface))
			tool.commit(mesh)
	holder.free()
	baked[id] = mesh
	return mesh

func _wall_batch(parent: Node3D, node_name: String, id: String, transforms: Array[Transform3D]) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _baked(id)
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()): multimesh.set_instance_transform(index, transforms[index])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	parent.add_child(node, true)
	if not wall_batches.has(id): wall_batches[id] = []
	wall_batches[id].append(node)

## The wall shelves show the shop's real stock: `counts` is product -> units owned
## (on the racks and in the warehouse); the wall fills up to its space and empties
## as things sell.
func show_stock(counts: Dictionary) -> void:
	for id in wall_batches:
		var remaining := int(counts.get(id, 0))
		for node in wall_batches[id]:
			var room: int = node.multimesh.instance_count
			node.multimesh.visible_instance_count = clampi(remaining, 0, room)
			remaining -= room

## The cashier's side of the counter: khata notebook and pen, calculator, a digital
## weighing scale and a phone, merged into one mesh that moves with the counter.
func _counter_details(counter: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top := 0.58
	HouseParts.box(st, Vector3(-0.6, top + 0.016, -0.27), Vector3(0.2, 0.03, 0.27), Color(0.62, 0.1, 0.12))
	HouseParts.box(st, Vector3(-0.6, top + 0.016, -0.27), Vector3(0.19, 0.022, 0.275), Color(0.96, 0.95, 0.9))
	HouseParts.box(st, Vector3(-0.46, top + 0.006, -0.25), Vector3(0.012, 0.012, 0.15), Color(0.1, 0.2, 0.6))
	HouseParts.box(st, Vector3(-0.28, top + 0.012, -0.29), Vector3(0.11, 0.022, 0.16), Color(0.15, 0.16, 0.18))
	HouseParts.box(st, Vector3(-0.28, top + 0.025, -0.325), Vector3(0.08, 0.006, 0.04), Color(0.55, 0.65, 0.5))
	for row in range(3):
		for column in range(3):
			HouseParts.box(st, Vector3(-0.31 + column * 0.03, top + 0.025, -0.285 + row * 0.03), Vector3(0.02, 0.006, 0.02), Color(0.75, 0.77, 0.8))
	HouseParts.box(st, Vector3(0.05, top + 0.02, -0.26), Vector3(0.27, 0.04, 0.25), Color(0.85, 0.86, 0.88))
	HouseParts.box(st, Vector3(0.05, top + 0.045, -0.24), Vector3(0.22, 0.01, 0.18), Color(0.7, 0.72, 0.75))
	HouseParts.box(st, Vector3(0.05, top + 0.035, -0.375), Vector3(0.14, 0.03, 0.02), Color(0.08, 0.08, 0.09))
	HouseParts.box(st, Vector3(0.05, top + 0.035, -0.387), Vector3(0.1, 0.018, 0.005), Color(0.3, 0.85, 0.45))
	HouseParts.box(st, Vector3(0.3, top + 0.006, -0.3), Vector3(0.08, 0.012, 0.16), Color(0.06, 0.06, 0.07))
	HouseParts.box(st, Vector3(0.3, top + 0.013, -0.3), Vector3(0.068, 0.002, 0.14), Color(0.2, 0.35, 0.55))
	var details := MeshInstance3D.new()
	details.name = "CounterDetails"
	details.mesh = st.commit()
	details.material_override = HouseParts._material()
	counter.add_child(details)

func _paint_band() -> void:
	var paint := _material(Color(0.93, 0.74, 0.38))
	var stripe := _material(Color(0.12, 0.3, 0.26))
	var depth := FRONT_Z - BACK_Z
	var mid_z := (FRONT_Z + BACK_Z) / 2
	_box("WallPaint", Vector3(ROOM_MAX_X - 0.006, 0.5, mid_z), Vector3(0.012, 1.0, depth), paint)
	_box("WallStripe", Vector3(ROOM_MAX_X - 0.006, 1.03, mid_z), Vector3(0.016, 0.06, depth), stripe)
	# Left wall: behind the packing room doorway (follows the back wall) and in front of it.
	var x := ROOM_MIN_X + 0.006
	_box("WallPaintLeft", Vector3(x, 0.5, (SIDE_DOOR.x + BACK_Z) / 2), Vector3(0.012, 1.0, SIDE_DOOR.x - BACK_Z), paint)
	_box("WallStripeLeft", Vector3(x, 1.03, (SIDE_DOOR.x + BACK_Z) / 2), Vector3(0.016, 0.06, SIDE_DOOR.x - BACK_Z), stripe)
	_box("WallPaintLeftFront", Vector3(x, 0.5, (SIDE_DOOR.y + FRONT_Z) / 2), Vector3(0.012, 1.0, FRONT_Z - SIDE_DOOR.y), paint)
	_box("WallStripeLeftFront", Vector3(x, 1.03, (SIDE_DOOR.y + FRONT_Z) / 2), Vector3(0.016, 0.06, FRONT_Z - SIDE_DOOR.y), stripe)
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

## An Indian ceiling fan: canopy and down-rod fixed to the ceiling at `top`; the
## rotor (motor and three long blades) is returned and spins around the rod.
func _ceiling_fan(top: Vector3) -> Node3D:
	var fan := Node3D.new()
	fan.name = "CeilingFan%d" % fans.size()
	fan.position = top
	add_child(fan)
	var white := _material(Color(0.94, 0.93, 0.89))
	var metal := _material(Color(0.55, 0.56, 0.57))
	_fan_part(fan, _cylinder(0.09, 0.06, 0.06), Vector3(0, -0.03, 0), white)
	_fan_part(fan, _cylinder(0.018, 0.018, 0.42), Vector3(0, -0.27, 0), metal)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position.y = -0.53
	fan.add_child(rotor)
	_fan_part(rotor, _cylinder(0.11, 0.15, 0.11), Vector3.ZERO, white)
	_fan_part(rotor, _cylinder(0.05, 0.07, 0.05), Vector3(0, -0.08, 0), white)
	for blade in range(3):
		var arm := Node3D.new()
		arm.rotation.y = blade * TAU / 3.0
		rotor.add_child(arm)
		var bracket := BoxMesh.new()
		bracket.size = Vector3(0.14, 0.02, 0.04)
		_fan_part(arm, bracket, Vector3(0.19, -0.01, 0), metal)
		var wing := BoxMesh.new()
		wing.size = Vector3(0.6, 0.012, 0.12)
		var part := _fan_part(arm, wing, Vector3(0.52, -0.015, 0), white)
		part.rotation.x = 0.12
	return rotor

func _cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return mesh

func _fan_part(parent: Node3D, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

var fan_speed := 0.0

func _process(delta: float) -> void:
	# Fans speed up smoothly to a steady low setting (about 70 turns a minute).
	fan_speed = move_toward(fan_speed, 7.5, delta * 2.5)
	for fan in fans: fan.rotate_y(fan_speed * delta)
	if is_instance_valid(diya_light):
		flicker += delta
		diya_light.light_energy = 0.62 + 0.08 * sin(flicker * 13.0) + 0.05 * sin(flicker * 7.3)
