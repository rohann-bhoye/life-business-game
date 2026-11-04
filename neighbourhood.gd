extends Node3D

var materials: Dictionary = {}
## Where every town tree stands (_tree), planted as one MultiMesh (_plant_trees).
var tree_spots: Array[Vector3] = []

func _ready() -> void:
	get_parent().get_node("MeshInstance3D").material_override = _material(Color(0.26, 0.46, 0.3))
	_build_shop()
	get_parent().get_node("Shop/ShopArea").business.changed.connect(_update_shop_upgrade)
	_update_shop_upgrade()
	_build_streets()
	# The old garden east of the shop made way for the side wings' plot (shop_operations.gd).
	for point in [Vector3(-11, 0.1, -8), Vector3(-18, 0.1, 12), Vector3(11, 0.1, -11), Vector3(27, 0.1, -3), Vector3(17.8, 0.1, 13.4), Vector3(-17, 0.1, 0), Vector3(-21, 0.1, -14), Vector3(25.5, 0.1, -9.5), Vector3(25, 0.1, 3)]:
		_tree(point)
	# Not at -8: that is the packing room door (export_world.gd).
	for x in [-18.0, -12.6, 8.0, 18.0]:
		_streetlight(Vector3(x, 0.1, 3.3))
		_streetlight(Vector3(x + 1.0, 0.1, 10.7), PI)
	_build_background()
	_build_street_details()
	var indian_street := Node3D.new()
	indian_street.set_script(preload("res://indian_street.gd"))
	add_child(indian_street)
	indian_street.build(self)
	var environment := Node3D.new()
	environment.name = "EnvironmentDetails"
	environment.set_script(preload("res://environment_details.gd"))
	add_child(environment)
	call_deferred("_batch_scenery")
	var street_life := Node3D.new()
	street_life.name = "StreetLife"
	street_life.set_script(preload("res://street_life.gd"))
	var world_audio := Node.new()
	world_audio.set_script(preload("res://world_audio.gd"))
	get_parent().add_child.call_deferred(world_audio)
	add_child(street_life)
	# The whole land is open (town_boundary.gd); invisible walls only at its end.
	var middle := Vector2((Edge.LAND_MIN_X + Edge.LAND_MAX_X) / 2.0, (Edge.LAND_MIN_Z + Edge.LAND_MAX_Z) / 2.0)
	for x in [Edge.LAND_MIN_X, Edge.LAND_MAX_X]:
		_collider("LandEndX%s" % x, self, Vector3(0.3, 60, Edge.LAND_MAX_Z - Edge.LAND_MIN_Z), Vector3(x, 20, middle.y))
	for z in [Edge.LAND_MIN_Z, Edge.LAND_MAX_Z]:
		_collider("LandEndZ%s" % z, self, Vector3(Edge.LAND_MAX_X - Edge.LAND_MIN_X, 60, 0.3), Vector3(middle.x, 20, z))
	_close_north()

## For now only the city is open: the North Road, the bridge, the village and the farm
## beyond are sealed by an invisible wall, with a road barrier and sign at the road.
func _close_north() -> void:
	var wall_z := -57.0
	_collider("NorthClosedWall", self, Vector3(Edge.LAND_MAX_X - Edge.LAND_MIN_X, 60, 0.4), Vector3(0, 20, wall_z))
	# The same barricade as at the welcome gates (road_block.gd); the wall above seals it.
	preload("res://road_block.gd").build(self, Vector3(50.0, 0.0, wall_z + 1.6), Vector3(0, 0, -1), "North", "Bridge and village\nopen in the next update", 5.0, 0.0, false)

func set_quality(quality: int) -> void:
	var show_scenery := quality > 0
	# Trees stay on every setting: their leaves are merged into StreetBatch, so hiding
	# the trunks left tree tops floating in the air.
	var street_life := get_node_or_null("StreetLife")
	if street_life != null:
		street_life.visible = show_scenery
		street_life.set_physics_process(show_scenery)
	var traffic := get_node_or_null("Traffic")
	if traffic != null: traffic.set_quality(quality)
	var indian_street := get_node_or_null("IndianStreet")
	if indian_street != null: indian_street.set_quality(quality)

func _material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.92
		materials[color] = material
	return materials[color]

func _update_shop_upgrade() -> void:
	var shop: MeshInstance3D = get_parent().get_node("Shop")
	var level: int = shop.get_node("ShopArea").business.shop_level
	var colors := [Color(0.12, 0.3, 0.26), Color(0.17, 0.36, 0.52), Color(0.58, 0.43, 0.12)]
	# The full shop (shop_presentation.gd) keeps its own dark ceiling.
	var operations = get_parent().get_node_or_null("ShopOperations")
	for node_name in ["SignBoard"] if operations != null and operations.enabled else ["RoofTrim", "SignBoard"]:
		shop.get_node(node_name).material_override = _material(colors[level - 1])
	shop.get_node("ShopSign").text = ["SHOP", "SHOP II", "SHOP III"][level - 1]

func _box(node_name: String, parent: Node3D, size: Vector3, offset: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.position = offset
	parent.add_child(instance)
	if solid:
		_collider(node_name + "Body", parent, size, offset)
	return instance

func _collider(node_name: String, parent: Node3D, size: Vector3, offset: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = offset
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func _build_shop() -> void:
	var operations = get_parent().get_node_or_null("ShopOperations")
	if operations != null and operations.enabled:
		operations.build_room(self)
		return
	var shop: MeshInstance3D = get_parent().get_node("Shop")
	var trim := Color(0.12, 0.3, 0.26)
	var glass := Color(0.32, 0.61, 0.67)
	_collider("BuildingBody", shop, Vector3(4, 3, 4), Vector3.ZERO)
	_box("RoofTrim", shop, Vector3(4.35, 0.25, 4.3), Vector3(0, 1.5, 0), trim, true)
	_box("SignBoard", shop, Vector3(3.9, 0.62, 0.12), Vector3(0, 1.62, 2.21), trim)
	for x in [-1.25, 1.25]:
		_box("WindowFrame%s" % x, shop, Vector3(1.04, 1.65, 0.12), Vector3(x, -0.05, 2.015), trim)
		_box("WindowGlass%s" % x, shop, Vector3(0.9, 1.49, 0.06), Vector3(x, -0.05, 2.095), glass)
		_box("WindowMullion%s" % x, shop, Vector3(0.045, 1.49, 0.04), Vector3(x, -0.05, 2.135), trim)
	var door: MeshInstance3D = shop.get_node("ShopDoor")
	door.material_override = _material(trim)
	_box("DoorGlass", door, Vector3(0.76, 1.55, 0.035), Vector3(0, 0.12, 0.12), glass)
	_box("DoorHandle", door, Vector3(0.04, 0.25, 0.08), Vector3(0.32, -0.1, 0.15), Color(0.8, 0.83, 0.83))
	for stripe in range(10):
		var color := Color(0.86, 0.29, 0.29) if stripe % 2 == 0 else Color(0.93, 0.94, 0.9)
		_box("Awning%d" % stripe, shop, Vector3(0.44, 0.12, 1.1), Vector3(-1.98 + stripe * 0.44, 1.12, 2.45), color)
	_box("LeftPlanter", self, Vector3(0.7, 0.45, 0.7), Vector3(-5.8, 0.325, 2.35), Color(0.5, 0.52, 0.51), true)
	_box("PlanterLeaves", self, Vector3(0.6, 0.3, 0.6), Vector3(-5.8, 0.65, 2.35), Color(0.18, 0.43, 0.23))

func _build_streets() -> void:
	var paving := Color(0.66, 0.69, 0.67)
	_box("NorthPavement", self, StreetKit.pavement_size(64, 1.6), StreetKit.pavement_at(0, 3.4), paving)
	_box("SouthPavement", self, StreetKit.pavement_size(64, 1.6), StreetKit.pavement_at(0, 10.6), paving)
	_box("ShopForecourt", self, StreetKit.pavement_size(6.5, 1.2), StreetKit.pavement_at(-3, 2.6), paving)
	# The old driveway to the home; the home now stands in West Colony, so it is hidden.
	_box("HomePath", self, StreetKit.pavement_size(2.2, 5.2), StreetKit.pavement_at(4, 0.25), Color(0.72, 0.73, 0.7)).hide()
	for x in range(-30, 31, 4):
		_box("LaneMark%d" % x, self, Vector3(1.8, 0.008, 0.09), Vector3(x, 0.124, 7), Color(0.88, 0.86, 0.68))
	for z in [4.35, 9.65]:
		_box("RoadEdge%s" % z, self, Vector3(64, 0.008, 0.05), Vector3(0, 0.124, z), Color(0.83, 0.86, 0.83))
	for stripe in range(7):
		_box("Crossing%d" % stripe, self, Vector3(2.0, 0.008, 0.28), Vector3(4, 0.124, 4.8 + stripe * 0.7), Color(0.85, 0.87, 0.83))
	for x in [-13.0, 13.0]:
		_box("BenchSeat%s" % x, self, Vector3(1.8, 0.12, 0.45), Vector3(x, 0.65, 11.2), Color(0.39, 0.43, 0.46), true)
		_box("BenchBack%s" % x, self, Vector3(1.8, 0.45, 0.08), Vector3(x, 0.9, 11.42), Color(0.39, 0.43, 0.46), true)
		for leg in [-0.65, 0.65]:
			_box("BenchLeg%s_%s" % [x, leg], self, Vector3(0.1, 0.5, 0.35), Vector3(x + leg, 0.35, 11.2), Color(0.15, 0.18, 0.19))
	# Asphalt repairs and utility covers stop the road reading as one repeated strip.
	for entry in [[-19.0, 6.0, 3.8, 1.1], [-6.0, 7.8, 2.7, 0.8], [11.5, 6.2, 4.2, 1.0], [24.0, 8.1, 2.2, 0.7]]:
		_box("RoadPatch%s" % entry[0], self, Vector3(entry[2], 0.009, entry[3]), Vector3(entry[0], 0.128, entry[1]), Color(0.105, 0.115, 0.12))
	for x in [-22.0, 0.0, 21.0]:
		var cover := MeshInstance3D.new()
		cover.name = "Manhole%s" % x
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.42
		cylinder.bottom_radius = 0.42
		cylinder.height = 0.015
		cylinder.radial_segments = 16
		cylinder.material = _material(Color(0.19, 0.21, 0.21))
		cover.mesh = cylinder
		cover.position = Vector3(x, 0.135, 7.75 if int(x) % 2 else 6.2)
		add_child(cover)

func _build_street_details() -> void:
	for entry in [[-23.0, 3.1], [-8.5, 10.9], [8.5, 3.1], [23.0, 10.9]]:
		var x: float = entry[0]
		var z: float = entry[1]
		_box("Planter%d" % get_child_count(), self, Vector3(0.75, 0.42, 0.75), Vector3(x, 0.32, z), Color(0.42, 0.38, 0.32))
		for side in [-0.2, 0.2]: _cone("Shrub%d" % get_child_count(), self, 0.28, 0.08, 0.75, Vector3(x + side, 0.82, z), Color(0.18, 0.43, 0.22))
	for entry in [[-17.0, 3.25], [17.0, 10.75]]:
		_box("StreetBin%d" % get_child_count(), self, Vector3(0.48, 0.8, 0.48), Vector3(entry[0], 0.5, entry[1]), Color(0.12, 0.3, 0.29))
	for x in [-27.0, -2.0, 27.0]:
		_box("Drain%d" % get_child_count(), self, Vector3(1.1, 0.025, 0.32), Vector3(x, 0.135, 4.18), Color(0.12, 0.15, 0.16))
		for slot in range(5): _box("DrainSlot%d" % get_child_count(), self, Vector3(0.08, 0.01, 0.38), Vector3(x - 0.4 + slot * 0.2, 0.151, 4.18), Color(0.3, 0.33, 0.33))

func _build_garden() -> void:
	_fence(Vector3(4, 0.1, -8.2), 7.0, false)
	_fence(Vector3(8, 0.1, -4.2), 8.0, true)
	_fence(Vector3(0.6, 0.1, -5.2), 5.0, true)
	for x in [1.7, 6.3]:
		_box("FlowerBed%s" % x, self, Vector3(1.0, 0.15, 1.4), Vector3(x, 0.175, -0.8), Color(0.23, 0.31, 0.23))
		for index in range(5):
			var color := Color(0.91, 0.56, 0.3) if index % 2 == 0 else Color(0.71, 0.27, 0.49)
			_box("Flower%s_%d" % [x, index], self, Vector3(0.18, 0.16, 0.18), Vector3(x - 0.3 + (index % 3) * 0.3, 0.4, -1.25 + (index / 3) * 0.55), color)

func _fence(offset: Vector3, length: float, along_z: bool) -> void:
	var fence := Node3D.new()
	fence.name = "GardenFence%d" % get_child_count()
	fence.position = offset
	if along_z:
		fence.rotation.y = PI / 2
	add_child(fence)
	var color := Color(0.72, 0.76, 0.73)
	for height in [0.4, 0.85]:
		_box("Rail%s" % height, fence, Vector3(length, 0.12, 0.1), Vector3(0, height, 0), color, true)
	for index in range(ceili(length) + 1):
		_box("Post%d" % index, fence, Vector3(0.13, 1.0, 0.13), Vector3(-length / 2 + index * length / ceili(length), 0.5, 0), color)

func _cone(node_name: String, parent: Node3D, bottom: float, top: float, height: float, offset: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 7
	mesh.rings = 1
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.position = offset
	parent.add_child(instance)
	return instance

## All town trees as one MultiMesh of the Blender neem tree, each turned and sized
## a little differently.
func _plant_trees() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = preload("res://tree_models.gd").mesh("neem_tree")
	multimesh.instance_count = tree_spots.size()
	for index in range(tree_spots.size()):
		var size := 0.95 + float(index % 5) * 0.05
		multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.UP, index * 2.4).scaled(Vector3.ONE * size), tree_spots[index]))
	var trees := MultiMeshInstance3D.new()
	trees.name = "TownTrees"
	trees.multimesh = multimesh
	add_child(trees)

func _batch_scenery() -> void:
	_plant_trees()
	var sources: Array = []
	for child in get_children():
		if child is MeshInstance3D:
			# Building windows are hidden behind the Kenney houses (_dress_buildings), so skip them.
			if not child.visible: continue
			for prefix in ["LaneMark", "Crossing", "RoadPatch", "Drain", "Bench"]:
				if child.name.begins_with(prefix): sources.append(child); break
	preload("res://scenery_batch.gd").build(self, sources, "StreetBatch")

## A town shade tree: its trunk and crown colliders here; the Blender neem tree
## itself is drawn with all the others as one MultiMesh (_plant_trees).
func _tree(offset: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = "Tree%d" % get_child_count()
	tree.position = offset
	add_child(tree)
	tree_spots.append(offset)
	_collider("TrunkBody", tree, Vector3(0.35, 2.1, 0.35), Vector3(0, 1.05, 0))
	_collider("CanopyBody", tree, Vector3(1.6, 2.2, 1.6), Vector3(0, 3.0, 0))

## real_light false (town expansion) keeps the glowing lens and adds a soft light pool
## on the ground instead of a SpotLight3D, so low-end GPUs keep few real lights.
func _streetlight(offset: Vector3, facing := 0.0, real_light := true) -> void:
	var lamp := Node3D.new()
	lamp.name = "Streetlight%d" % get_child_count()
	lamp.position = offset
	lamp.rotation.y = facing
	add_child(lamp)
	var metal := Color(0.15, 0.19, 0.21)
	_box("Pole", lamp, Vector3(0.12, 3.2, 0.12), Vector3(0, 1.6, 0), metal, true)
	_box("Arm", lamp, Vector3(0.12, 0.1, 0.75), Vector3(0, 3.15, 0.32), metal)
	_box("Housing", lamp, Vector3(0.35, 0.12, 0.65), Vector3(0, 3.1, 0.65), metal)
	var lens := _box("Lens", lamp, Vector3(0.27, 0.025, 0.5), Vector3(0, 3.03, 0.65), Color(0.97, 0.92, 0.72))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.97, 0.92, 0.72)
	glow.emission_enabled = true
	glow.emission = Color(0.4, 0.35, 0.2)
	lens.material_override = glow
	# A glowing pool on the ground: the only light under the lamps out of town, and
	# the cheap stand-in for the real spot light on Low Fast (day_night.gd).
	var pool := MeshInstance3D.new()
	pool.name = "Pool"
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	pool.mesh = plane
	pool.position = Vector3(0, 0.03, 0.65)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.material_override = _light_pool_material()
	pool.visible = false
	lamp.add_child(pool)
	if not real_light: return
	var light := SpotLight3D.new()
	light.name = "Light"
	light.position = Vector3(0, 3.0, 0.65)
	light.rotation_degrees.x = -90
	light.light_color = Color(1, 0.86, 0.63)
	light.light_energy = 1.5
	light.spot_range = 8.0
	light.spot_angle = 55.0
	light.shadow_enabled = false
	light.visible = false
	lamp.add_child(light)

var light_pool_material: StandardMaterial3D

func _light_pool_material() -> StandardMaterial3D:
	if light_pool_material != null: return light_pool_material
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.85, 0.55, 0.8))
	gradient.set_color(1, Color(1, 0.85, 0.55, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	light_pool_material = StandardMaterial3D.new()
	light_pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light_pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light_pool_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	light_pool_material.albedo_texture = texture
	return light_pool_material

func _build_background() -> void:
	var colors := [Color(0.62, 0.68, 0.7), Color(0.71, 0.56, 0.5), Color(0.74, 0.77, 0.68), Color(0.5, 0.64, 0.63)]
	for index in range(4):
		var x := -15.0 + index * 9.0
		var height := 3.2 + (index % 2) * 1.0
		_box("NeighbourBuilding%d" % index, self, Vector3(6, height, 5), Vector3(x, 0.1 + height / 2, -18), colors[index], true)
		_box("NeighbourRoof%d" % index, self, Vector3(6.3, 0.2, 5.3), Vector3(x, 0.2 + height, -18), Color(0.24, 0.3, 0.31))
		for window in range(3):
			_box("NeighbourWindow%d_%d" % [index, window], self, Vector3(0.85, 1.1, 0.06), Vector3(x - 1.8 + window * 1.8, 1.8, -15.47), Color(0.34, 0.55, 0.61))
	for index in range(6):
		var x := -25.0 + index * 10.0
		var depth := 18.0
		if index == 1:
			x = -24.0
			depth = 26.0
		if index in [2, 3]:
			x = 15.0 if index == 2 else 25.0
			depth = 26.0
		var height := 3.6 + (index % 3) * 0.8
		_box("SouthBuilding%d" % index, self, Vector3(7, height, 5), Vector3(x, 0.1 + height / 2, depth), colors[index % colors.size()], true)
		_box("SouthRoof%d" % index, self, Vector3(7.3, 0.22, 5.3), Vector3(x, height + 0.2, depth), Color(0.24, 0.3, 0.31))
		_box("SouthDoor%d" % index, self, Vector3(1, 2.2, 0.08), Vector3(x, 1.2, depth - 2.54), Color(0.15, 0.28, 0.31))
		for side in [-1, 1]:
			_box("SouthShopWindow%d_%d" % [index, side], self, Vector3(2, 1.6, 0.06), Vector3(x + side * 2.1, 1.7, depth - 2.54), Color(0.36, 0.65, 0.72))
	_dress_buildings()
	_build_lanes()
	# New houses, lanes and the west park in the empty north of town (town_fill.gd).
	var fill := Node3D.new()
	fill.set_script(preload("res://town_fill.gd"))
	add_child(fill)
	fill.build(self)
	_build_rival_store()
	var expansion := Node3D.new()
	expansion.set_script(preload("res://town_expansion.gd"))
	add_child(expansion)
	expansion.build(self)
	# Town life (Sharma shop, moving traffic, night) built after the scenery it uses.
	for script in [preload("res://rival_shop.gd"), preload("res://traffic.gd"), preload("res://night_life.gd")]:
		var life := Node3D.new()
		life.set_script(script)
		add_child(life)
		life.build(self, get_parent().get_node("Shop/ShopArea").business)

# Cement-block paths to every house door. North: a back lane behind the shop and
# home with a short step to each door, joining the street left of the shop and past
# the home. South: a path round the bus stop to the corner house, and corridors
# between the front houses to lanes along the back row.
const BlockPath := preload("res://block_path.gd")
const Edge := preload("res://town_boundary.gd")
const LANES := [
	["BackLane", Vector2(-16.0, -13.6), Vector2(14.0, -13.6), 3],
	# West of the packing room (export_world.gd) built onto the shop.
	["BackLaneWest", Vector2(-10.6, -12.97), Vector2(-10.6, 2.6), 3],
	["BackLaneEast", Vector2(13.4, -12.97), Vector2(13.4, 2.6), 3],
	["BusStopPath", Vector2(-26.6, 11.4), Vector2(-26.6, 13.47), 3],
	["CornerHousePath", Vector2(-27.23, 14.1), Vector2(-24.1, 14.1), 3],
	["WestCorridor", Vector2(-19.6, 11.4), Vector2(-19.6, 21.47), 3],
	["WestBackLane", Vector2(-24.9, 22.1), Vector2(-18.97, 22.1), 3],
	["EastCorridor", Vector2(20.0, 11.4), Vector2(20.0, 21.47), 3],
	["EastBackLane", Vector2(14.1, 22.1), Vector2(25.9, 22.1), 3],
	["SouthHousePath", Vector2(15.0, 11.4), Vector2(15.0, 14.75), 3],
]
func _build_lanes() -> void:
	for lane in LANES:
		BlockPath.lay(self, lane[0], lane[1], lane[2], lane[3])
	for x in [-15.0, -6.0, 3.0, 12.0]:
		BlockPath.lay(self, "DoorStep%d" % int(x), Vector2(x, -14.75), Vector2(x, -14.23), 3)

# Show Indian town houses (indian_house.gd) in place of the block buildings. The
# original box colliders stay; only their visible meshes are hidden.
const IndianHouse := preload("res://indian_house.gd")
func _dress_buildings() -> void:
	var spots: Array = []
	for index in range(4):
		spots.append(["NeighbourHouse%d" % index, 0.0, Vector3(6.2, 6.0, 5.2), ["NeighbourBuilding%d", "NeighbourRoof%d", "NeighbourWindow%d_0", "NeighbourWindow%d_1", "NeighbourWindow%d_2"], index])
	for index in range(6):
		spots.append(["SouthHouse%d" % index, PI, Vector3(7.2, 6.0, 5.2), ["SouthBuilding%d", "SouthRoof%d", "SouthDoor%d", "SouthShopWindow%d_-1", "SouthShopWindow%d_1"], index])
	for number in range(spots.size()):
		var spot: Array = spots[number]
		var building := get_node_or_null(spot[3][0] % spot[4]) as Node3D
		if building == null: continue
		for pattern in spot[3]:
			var part := get_node_or_null(String(pattern % spot[4]).validate_node_name()) as Node3D
			if part != null: part.visible = false
		# Sharma's store front (x 25) hangs on its house, so that one has no balcony.
		IndianHouse.build(self, spot[0], spot[2], Vector3(building.position.x, 0.1, building.position.z), spot[1], number, {"balcony": absf(building.position.x - 25.0) > 1.0})

# Sharma General Store, the rival shop: a shop front on the south-side house at
# x 25, shown from the day it opens (business.rival_open()).
func _build_rival_store() -> void:
	var business = get_parent().get_node("Shop/ShopArea").business
	var store := Node3D.new()
	store.name = "RivalStore"
	store.position = Vector3(25, 0.1, 15.25)
	add_child(store)
	_box("RivalSignBoard", store, Vector3(4.2, 0.7, 0.14), Vector3(0, 3.0, 0), Color(0.55, 0.12, 0.1))
	for index in range(9):
		_box("RivalAwning%d" % index, store, Vector3(0.48, 0.08, 0.9), Vector3(-2.0 + index * 0.5, 2.45, -0.4), Color(0.95, 0.75, 0.2) if index % 2 == 0 else Color(0.97, 0.96, 0.9))
	_box("RivalOpenBoard", store, Vector3(1.0, 0.45, 0.06), Vector3(1.6, 1.4, -0.08), Color(0.12, 0.35, 0.18))
	for entry in [["SHARMA GENERAL STORE", Vector3(0, 3.0, -0.09), 48, Color(1, 0.93, 0.8)], ["OPEN 8-8", Vector3(1.6, 1.4, -0.12), 30, Color(0.85, 1, 0.85)]]:
		var label := Label3D.new()
		label.text = entry[0]
		label.position = entry[1]
		label.rotation.y = PI
		label.font_size = entry[2]
		label.pixel_size = 0.006
		label.modulate = entry[3]
		label.outline_size = 0
		store.add_child(label)
	var update := func(): store.visible = business.rival_open()
	business.clock_changed.connect(update)
	business.changed.connect(update)
	update.call()
