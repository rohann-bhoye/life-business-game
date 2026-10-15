extends Node3D

var materials: Dictionary = {}
const WIND_SHADER := preload("res://assets/materials/foliage_wind.gdshader")
var foliage_materials: Array[ShaderMaterial] = []
var foliage_cache := {}

func _ready() -> void:
	get_parent().get_node("MeshInstance3D").material_override = _material(Color(0.26, 0.46, 0.3))
	_build_shop()
	get_parent().get_node("Shop/ShopArea").business.changed.connect(_update_shop_upgrade)
	_update_shop_upgrade()
	_build_streets()
	_build_garden()
	for point in [Vector3(-11, 0.1, -8), Vector3(-18, 0.1, 12), Vector3(11, 0.1, -11), Vector3(12, 0.1, 0), Vector3(15, 0.1, 13), Vector3(-17, 0.1, 0), Vector3(-21, 0.1, -14), Vector3(23, 0.1, -18), Vector3(25, 0.1, 3), Vector3(-24, 0.1, 16)]:
		_tree(point)
	for x in [-18.0, -8.0, 8.0, 18.0]:
		_streetlight(Vector3(x, 0.1, 3.3))
		_streetlight(Vector3(x + 1.0, 0.1, 10.7), PI)
	_build_background()
	_build_street_details()
	var environment := Node3D.new()
	environment.name = "EnvironmentDetails"
	environment.set_script(preload("res://environment_details.gd"))
	add_child(environment)
	call_deferred("_batch_scenery")
	var street_life := Node3D.new()
	street_life.name = "StreetLife"
	street_life.set_script(preload("res://street_life.gd"))
	add_child(street_life)
	for x in [-31.5, 31.5]:
		_collider("BoundaryX%s" % x, self, Vector3(0.3, 5, 64), Vector3(x, 2.5, 0))

func set_quality(quality: int) -> void:
	var show_scenery := quality > 0
	for child in get_children():
		if not child.name.begins_with("Tree"): continue
		child.visible = show_scenery
		for body_name in ["TrunkBody", "CanopyBody"]:
			var body := child.get_node_or_null(body_name) as StaticBody3D
			if body != null: body.collision_layer = 1 if show_scenery else 0
	var street_life := get_node_or_null("StreetLife")
	if street_life != null:
		street_life.visible = show_scenery
		street_life.set_physics_process(show_scenery)
	for z in [-31.5, 31.5]:
		_collider("BoundaryZ%s" % z, self, Vector3(64, 5, 0.3), Vector3(0, 2.5, z))

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
	for node_name in ["RoofTrim", "SignBoard"]:
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
	_box("NorthPavement", self, Vector3(64, 0.014, 1.6), Vector3(0, 0.107, 3.4), paving)
	_box("SouthPavement", self, Vector3(64, 0.014, 1.6), Vector3(0, 0.107, 10.6), paving)
	_box("ShopForecourt", self, Vector3(6.5, 0.016, 1.2), Vector3(-3, 0.108, 2.6), paving)
	_box("HomePath", self, Vector3(2.2, 0.018, 5.2), Vector3(4, 0.109, 0.25), Color(0.72, 0.73, 0.7))
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

func _foliage(color: Color) -> ShaderMaterial:
	if foliage_cache.has(color): return foliage_cache[color]
	var material := ShaderMaterial.new()
	material.shader = WIND_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("wind_strength", 0.07)
	foliage_materials.append(material)
	foliage_cache[color] = material
	return material

func _batch_scenery() -> void:
	var sources: Array = []
	for child in get_children():
		if child.name.begins_with("Tree"):
			for part in child.get_children():
				if part is MeshInstance3D and part.mesh is SphereMesh: sources.append(part)
		elif child is MeshInstance3D:
			for prefix in ["LaneMark", "Crossing", "RoadPatch", "Drain", "Bench", "NeighbourWindow", "SouthShopWindow"]:
				if child.name.begins_with(prefix): sources.append(child); break
	preload("res://scenery_batch.gd").build(self, sources, "StreetBatch")

func _tree(offset: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = "Tree%d" % get_child_count()
	tree.position = offset
	add_child(tree)
	var variation := float(tree.get_index() % 4) * 0.025
	_cone("Trunk", tree, 0.24, 0.15, 2.5, Vector3(0, 1.25, 0), Color(0.31, 0.22, 0.15))
	for branch in range(4):
		var limb := _cone("Branch%d" % branch, tree, 0.09, 0.045, 1.15, Vector3(0, 2.0 + branch * 0.18, 0), Color(0.31, 0.22, 0.15))
		limb.rotation = Vector3(0.0, branch * TAU / 4.0, deg_to_rad(58))
	var leaf_material := _foliage(Color(0.14 + variation, 0.36 + variation, 0.19))
	for index in range(6):
		var leaves := MeshInstance3D.new()
		leaves.name = "Canopy%d" % index
		var crown := SphereMesh.new()
		crown.radius = 0.95 if index < 4 else 0.78
		crown.height = crown.radius * 1.7
		crown.radial_segments = 9
		crown.rings = 5
		crown.material = leaf_material
		leaves.mesh = crown
		var angle := index * TAU / 4.0
		leaves.position = Vector3(cos(angle) * (0.65 if index < 4 else 0.3), 2.75 + (index / 4) * 0.85, sin(angle) * (0.65 if index < 4 else 0.3))
		tree.add_child(leaves)
	_collider("TrunkBody", tree, Vector3(0.35, 2.1, 0.35), Vector3(0, 1.05, 0))
	_collider("CanopyBody", tree, Vector3(1.6, 2.2, 1.6), Vector3(0, 3.0, 0))

func _streetlight(offset: Vector3, facing := 0.0) -> void:
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
