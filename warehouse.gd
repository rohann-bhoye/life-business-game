extends Node3D

const Logistics = preload("res://shop_logistics.gd")
const Catalog = preload("res://product_catalog.gd")
const Office = preload("res://office_assets.gd")
const Bricks = preload("res://brick_works.gd")
var office_idle := Vector3(-12.4, 0.1, 19)
var entry := Vector3(-3, 0.1, 15.1)
var receiver: Node3D
var navigation: AStarGrid2D
const FRONT := 14.5
const BACK := 30.5
const PRODUCT_BAY := Rect2(-11.3, 11.5, 3.8, 2.85)
const RACK_BAY := Rect2(-0.8, 11.5, 4.6, 2.85)
var racks: Array[Node3D] = []
var rack_labels: Array[Label3D] = []
var stored_models: Dictionary = {}
var furniture_boxes: Array[Node3D] = []
var truck: Node3D
enum TruckState { IDLE, ARRIVING, UNLOADING, LEAVING }
var truck_state := TruckState.IDLE
var unload_seconds := 0.0
var built := false
var computer: Node3D
var office_door: Node3D
@onready var world = get_parent()
@onready var business = world.get_node("Shop/ShopArea").business
@onready var operations = world.get_node("ShopOperations")
@onready var builder = world.get_node("Neighbourhood")
@onready var player = world.get_node("Player")
@onready var ui = world.get_node("Ui")

static func rack_point(id: int) -> Vector3:
	return Vector3([-9.8, -5.8, -0.2, 3.8][id % 4], 0.1, 16.5 + (id / 4) * 4)

static func service_point(id: int) -> Vector3:
	return rack_point(id) + Vector3(0, 0, -1.4)

static func slot_point(slot: int) -> Vector3:
	var index := slot % Logistics.SLOTS_PER_RACK
	return rack_point(slot / Logistics.SLOTS_PER_RACK) + Vector3(-0.975 + (index % 4) * 0.65, 0.55 + (index / 4) * 0.95, 0)

func _ready() -> void:
	if not operations.enabled: return
	built = true
	_build_room()
	_build_racks()
	_batch_racks()
	_build_computer()
	_build_loading_bays()
	_build_navigation()
	_build_receiver()
	_build_truck()
	business.changed.connect(_refresh)
	_refresh()

func _build_room() -> void:
	var shell := Node3D.new()
	shell.name = "StorageBuilding"
	add_child(shell)
	# Red-brick walls, a dark steel roof and fascia (brick_works.gd style).
	var wall := Color(0.68, 0.73, 0.76)
	var dark := Color(0.13, 0.14, 0.16)
	var walls: Array[MeshInstance3D] = []
	for x in [-16.5, 6.4]: walls.append(builder._box("SideWall%s" % x, shell, Vector3(0.18, 5.2, 16), Vector3(x, 2.7, 22.5), wall, true))
	walls.append(builder._box("BackWall", shell, Vector3(22.9, 5.2, 0.18), Vector3(-5.05, 2.7, BACK), wall, true))
	# Front wall: small office exit behind the management monitor, main warehouse entrance at x -3.
	walls.append(builder._box("OfficeFrontWallLeft", shell, Vector3(1.675, 5.2, 0.18), Vector3(-15.6625, 2.7, FRONT), wall, true))
	walls.append(builder._box("OfficeFrontWallRight", shell, Vector3(8.575, 5.2, 0.18), Vector3(-9.2875, 2.7, FRONT), wall, true))
	walls.append(builder._box("OfficeDoorHeader", shell, Vector3(1.25, 2.85, 0.18), Vector3(-14.2, 3.875, FRONT), wall, true))
	walls.append(builder._box("FrontWall2.7", shell, Vector3(7.4, 5.2, 0.18), Vector3(2.7, 2.7, FRONT), wall, true))
	for part in walls: part.material_override = Bricks.brick_material()
	builder._box("DoorLintel", shell, Vector3(4, 1.5, 0.18), Vector3(-3, 4.55, FRONT), dark, true)
	builder._box("Roof", shell, Vector3(23.3, 0.2, 16.4), Vector3(-5.05, 5.4, 22.5), Color(0.24, 0.26, 0.28), true)
	var floor = builder._box("Floor", shell, Vector3(22.7, 0.012, 15.8), Vector3(-5.05, 0.106, 22.5), Color(0.6, 0.65, 0.66))
	floor.material_override = world.get_node("ShopPresentation").surface(Vector2(0.5, 0.5), 2)
	builder._box("Forecourt", shell, Vector3(22.9, 0.016, 3.1), Vector3(-5.05, 0.108, 12.95), Color(0.67, 0.7, 0.72))
	builder._box("Fascia", shell, Vector3(22.7, 0.7, 0.1), Vector3(-5.05, 4.6, FRONT - 0.13), dark)
	var sign: Label3D = operations._sign(shell, "StorageSign", "APNA STORAGE", Vector3(-3, 4.6, FRONT - 0.21))
	sign.rotation.y = PI
	sign.font_size = 90
	sign.pixel_size = 0.006
	sign.outline_size = 1
	for side in [-1, 1]:
		builder._box("DoorFrame%d" % side, shell, Vector3(0.1, 3.7, 0.2), Vector3(-3 + side * 2, 1.95, FRONT - 0.05), Color(0.93, 0.66, 0.15))
	var door := Node3D.new()
	door.name = "WarehouseDoor"
	door.set_script(preload("res://sliding_door.gd"))
	door.doorway_position = Vector3(-3, 0.1, FRONT - 0.02)
	door.doorway_width = 4.0
	door.doorway_height = 3.6
	add_child(door)
	for x in [-14.85, -13.55]: builder._box("OfficeDoorFrame%s" % x, shell, Vector3(0.1, 2.35, 0.2), Vector3(x, 1.275, FRONT - 0.05), Color(0.18, 0.31, 0.38))
	builder._box("OfficeDoorFrameTop", shell, Vector3(1.4, 0.1, 0.2), Vector3(-14.2, 2.43, FRONT - 0.05), Color(0.18, 0.31, 0.38))
	office_door = Node3D.new()
	office_door.name = "OfficeDoor"
	office_door.position = Vector3(-14.825, 0.1, FRONT - 0.12)
	office_door.set_script(preload("res://office_door.gd"))
	shell.add_child(office_door)
	var footpath = builder._box("OfficeFootpath", shell, StreetKit.pavement_size(1.8, 4.2), StreetKit.pavement_at(-14.2, FRONT - 2.1), Color(0.66, 0.69, 0.68))
	footpath.material_override = world.get_node("ShopPresentation").surface(Vector2(0.5, 0.5), 2)
	for z in [16, 22, 28]:
		var fixture = builder._box("CeilingFixture%d" % z, shell, Vector3(7, 0.08, 0.35), Vector3(-3, 5.18, z), Color(0.87, 0.93, 0.97))
		var light := OmniLight3D.new()
		light.position = Vector3(0, -0.5, 0)
		light.light_energy = 1.1
		light.omni_range = 11
		light.shadow_enabled = false
		fixture.add_child(light)
	for z in [18, 26]:
		var fixture = builder._box("OfficeCeilingLight%d" % z, shell, Vector3(2.4, 0.08, 0.4), Vector3(-14, 5.05, z), Color(0.95, 0.98, 1))
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.95, 0.98, 1)
		material.emission_enabled = true
		material.emission = Color(0.9, 0.96, 1)
		material.emission_energy_multiplier = 1.2
		fixture.material_override = material
		var light := OmniLight3D.new()
		light.name = "OfficeLight"
		light.position.y = -0.65
		light.light_color = Color(0.96, 0.98, 1)
		light.light_energy = 2.2
		light.omni_range = 9
		light.shadow_enabled = false
		fixture.add_child(light)
	var entrance_light := OmniLight3D.new()
	entrance_light.name = "WarehouseEntranceLight"
	entrance_light.position = Vector3(-3, 3.5, FRONT - 0.7)
	entrance_light.light_energy = 1.2
	entrance_light.omni_range = 5
	shell.add_child(entrance_light)
	var area := Area3D.new()
	area.name = "WarehouseInterior"
	area.position = Vector3(-5.05, 2.7, 22.5)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(22.7, 5.2, 15.8)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(func(body):
		if body == player: player.warehouse_indoors = true)
	area.body_exited.connect(func(body):
		if body == player: player.warehouse_indoors = false)
	_brick_details(shell)

## The building itself is our Blender model (tools/blender/build_warehouse.py), laid
## exactly on this layout: brick facade and plinth (world-mapped brick), ribbed steel
## walls, the pitched roof with skylights, the APNA STORAGE parapet, the entrance
## canopy, office door and window, loading bays with bumpers and bollards, lamps,
## columns and roof trusses. The boxes above stay as invisible colliders; the doors,
## lights, floor, forecourt and labels stay as they are. Hedge planters out front.
func _brick_details(shell: Node3D) -> void:
	for name in ["SideWall-16.5", "SideWall6.4", "BackWall", "OfficeFrontWallLeft", "OfficeFrontWallRight", "OfficeDoorHeader", "FrontWall2.7", "DoorLintel", "Roof", "Fascia", "DoorFrame-1", "DoorFrame1", "OfficeDoorFrame-14.85", "OfficeDoorFrame-13.55", "OfficeDoorFrameTop", "StorageSign"]:
		var part := shell.get_node_or_null(name.validate_node_name()) as Node3D
		if part != null: part.hide()
	for piece in ["warehouse_brick", "warehouse_cladding", "warehouse_shell"]:
		var model: Node3D = (load("res://assets/props/warehouse/%s.glb" % piece) as PackedScene).instantiate()
		model.name = piece.to_pascal_case()
		model.position = Vector3(0, 0.1, 0)
		shell.add_child(model)
		var material: Material = Bricks.brick_material() if piece == "warehouse_brick" else (Bricks.cladding_material() if piece == "warehouse_cladding" else null)
		if material != null:
			for mesh in model.find_children("*", "MeshInstance3D", true, false): mesh.material_override = material
	for spot in [Vector2(-12.35, 1.5), Vector2(-6.25, 2.0), Vector2(5.65, 1.2)]:
		Bricks.planter(shell, "Planter%d" % roundi(spot.x), Vector3(spot.x, 0.1, FRONT - 0.45), 0.0, spot.y)
		builder._collider("Planter%dBody" % roundi(spot.x), shell, Vector3(spot.y, 1.16, 0.6), Vector3(spot.x, 0.68, FRONT - 0.45))

func _build_racks() -> void:
	for id in range(Logistics.STORAGE_RACKS):
		var rack := Node3D.new()
		rack.name = "StorageRack%d" % id
		rack.position = rack_point(id)
		add_child(rack)
		racks.append(rack)
		# Colliders here; the rack you see is the Blender pallet rack, all 16 drawn as one
		# MultiMesh (_rack_models).
		for x in [-1.3, 1.3]: builder._collider("Upright%sBody" % x, rack, Vector3(0.1, 4.2, 1.1), Vector3(x, 2.1, 0))
		for level in range(4): builder._collider("Shelf%dBody" % level, rack, Vector3(2.6, 0.08, 1.1), Vector3(0, 0.1 + level * 0.95, 0))
		var label: Label3D = operations._sign(rack, "SlotLabel", "", Vector3(0, 4.3, -0.6))
		label.rotation.y = PI
		label.pixel_size = 0.0035
		rack_labels.append(label)
		Bricks.bay_number(self, "BayBoard%d" % id, rack.position + Vector3(0, 4.85, 0), PI, "%s%d" % [String.chr(65 + id / 4), id % 4 + 1])

func _build_computer() -> void:
	var setup := Node3D.new()
	setup.name = "OfficeDeskSetup"
	setup.position = Vector3(-15.15, 0, 18.3)
	setup.rotation.y = PI * 0.5
	add_child(setup)
	Office.attach(setup, "WarehouseDeskAsset", "desk", Vector3(2.3, 0.98, 1.3), Vector3(0, 0.1, 0))
	builder._collider("WarehouseDeskBody", setup, Vector3(1.85, 0.95, 1), Vector3(0, 0.575, 0))
	computer = Node3D.new()
	computer.name = "WarehousePC"
	computer.position = Vector3(0, 1.08, -0.1)
	setup.add_child(computer)
	# Casing is fitted around ComputerTerminal's 0.78 x 0.44 live screen.
	var casing := Color(0.06, 0.09, 0.11)
	builder._box("MonitorBack", computer, Vector3(0.9, 0.54, 0.08), Vector3(0, 0.43, 0.075), casing)
	builder._box("MonitorTop", computer, Vector3(0.9, 0.05, 0.08), Vector3(0, 0.695, 0.13), casing)
	builder._box("MonitorBottom", computer, Vector3(0.9, 0.05, 0.08), Vector3(0, 0.165, 0.13), casing)
	builder._box("MonitorLeft", computer, Vector3(0.06, 0.48, 0.08), Vector3(-0.42, 0.43, 0.13), casing)
	builder._box("MonitorRight", computer, Vector3(0.06, 0.48, 0.08), Vector3(0.42, 0.43, 0.13), casing)
	builder._box("MonitorNeck", computer, Vector3(0.1, 0.2, 0.1), Vector3(0, 0.05, 0.06), casing)
	builder._box("MonitorBase", computer, Vector3(0.52, 0.055, 0.3), Vector3(0, -0.045, 0.08), casing)
	Office.attach(setup, "KeyboardAsset", "computerKeyboard", Vector3(0.65, 0.07, 0.3), Vector3(0, 1.08, 0.35))
	Office.attach(setup, "MouseAsset", "computerMouse", Vector3(0.12, 0.06, 0.2), Vector3(0.55, 1.08, 0.35))
	var chair := Office.attach(setup, "OfficeChair", "chairDesk", Vector3(0.9, 1.1, 0.9), Vector3(0, 0.1, 1.2))
	chair.rotation.y = PI
	var sign: Label3D = operations._sign(computer, "OrderSign", "ORDERS", Vector3(0, 0.36, 0))
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var terminal := Node3D.new()
	terminal.name = "ComputerTerminal"
	terminal.set_script(preload("res://computer_terminal.gd"))
	computer.add_child(terminal)

func _batch_racks() -> void:
	var model: Node3D = (load("res://assets/props/warehouse/storage_rack.glb") as PackedScene).instantiate()
	var source: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = source.mesh
	multimesh.instance_count = racks.size()
	for index in range(racks.size()): multimesh.set_instance_transform(index, racks[index].transform)
	var batch := MultiMeshInstance3D.new()
	batch.name = "RackBatch"
	batch.multimesh = multimesh
	add_child(batch)
	model.free()

func _build_navigation() -> void:
	navigation = AStarGrid2D.new()
	navigation.region = Rect2i(-64, 59, 89, 63)
	navigation.cell_size = Vector2.ONE * 0.25
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in range(59, 122):
		for x in range(-64, 25):
			var point := Vector2(x, y) * 0.25
			var blocked := not Rect2(-16.4, 14.6, 22.7, 15.8).grow(-0.35).has_point(point)
			if Rect2(-15.7, 17.2, 1.1, 2.2).grow(0.35).has_point(point): blocked = true
			for rack in racks:
				if Rect2(Vector2(rack.position.x - 1.35, rack.position.z - 0.55), Vector2(2.7, 1.1)).grow(0.3).has_point(point): blocked = true
			navigation.set_point_solid(Vector2i(x, y), blocked)

func walk_route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var start := Vector2i(roundi(from.x * 4), roundi(from.z * 4))
	var end := Vector2i(roundi(to.x * 4), roundi(to.z * 4))
	if not navigation.is_in_boundsv(start) or not navigation.is_in_boundsv(end) or navigation.is_point_solid(start) or navigation.is_point_solid(end): return result
	for point in navigation.get_point_path(start, end): result.append(Vector3(point.x, 0.1, point.y))
	if not result.is_empty(): result.append(to)
	return result

func _build_receiver() -> void:
	receiver = Node3D.new()
	receiver.name = "WarehouseReceiver"
	receiver.add_to_group("door_actors")
	receiver.position = office_idle
	receiver.set_script(preload("res://warehouse_receiver.gd"))
	var visual := Node3D.new()
	visual.name = "CharacterVisual"
	visual.set_script(preload("res://character_visual.gd"))
	visual.shirt_color = Color(0.15, 0.45, 0.66)
	visual.model = "warehouse"
	receiver.add_child(visual)
	add_child(receiver)
	var label: Label3D = operations._sign(receiver, "EmployeeName", "Anil - Warehouse", Vector3(0, 1.85, 0))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.005

func _build_loading_bays() -> void:
	for entry in [{"name": "ProductBay", "area": PRODUCT_BAY, "label": "PRODUCT DELIVERIES"}, {"name": "RackBay", "area": RACK_BAY, "label": "RACK DELIVERIES"}]:
		var bay := Node3D.new()
		bay.name = entry.name
		add_child(bay)
		var area: Rect2 = entry.area
		var centre := area.get_center()
		var yellow := Color(1, 0.76, 0.12)
		for z in [area.position.y, area.end.y]: builder._box("EdgeZ%s" % z, bay, Vector3(area.size.x, 0.012, 0.08), Vector3(centre.x, 0.129, z), yellow)
		for x in [area.position.x, area.end.x]: builder._box("EdgeX%s" % x, bay, Vector3(0.08, 0.012, area.size.y), Vector3(x, 0.129, centre.y), yellow)
		var label: Label3D = operations._sign(bay, "BayLabel", entry.label, Vector3(centre.x, 0.15, area.position.y - 0.22))
		label.rotation.x = -PI / 2
		label.rotation.y = PI
		label.font_size = 34
		label.pixel_size = 0.003
		label.modulate = yellow
	for x in [-4.5, -1.5]: builder._box("WalkwayEdge%s" % x, self, Vector3(0.06, 0.01, 15.7), Vector3(x, 0.125, 22.2), Color(0.9, 0.93, 0.85))

func _build_truck() -> void:
	truck = Node3D.new()
	truck.name = "FurnitureTruck"
	add_child(truck)
	builder._box("Cargo", truck, Vector3(4.5, 2.4, 1.9), Vector3(-0.4, 1.65, 0), Color(0.18, 0.35, 0.57))
	builder._box("Cab", truck, Vector3(1.6, 1.7, 1.8), Vector3(2.45, 1.25, 0), Color(0.94, 0.64, 0.13))
	builder._box("Windshield", truck, Vector3(0.04, 0.6, 1.5), Vector3(3.27, 1.6, 0), Color(0.28, 0.65, 0.75))
	var sign: Label3D = operations._sign(truck, "FurnitureSign", "RACK DELIVERY", Vector3(-0.4, 1.8, -0.97))
	sign.rotation.y = PI
	sign.pixel_size = 0.006
	for x in [-1.8, 1.1, 2.6]:
		for z in [-1.0, 1.0]:
			builder._box("Wheel%s_%s" % [x, z], truck, Vector3(0.65, 0.65, 0.2), Vector3(x, 0.43, z), Color(0.09, 0.1, 0.12))
	truck.hide()

func _refresh() -> void:
	if not built: return
	for model in stored_models.values(): model.hide()
	for box in business.logistics.storage:
		if not stored_models.has(box.slot):
			var crate: Node3D = operations._crate(self, "StoredBox%d" % box.slot)
			crate.position = slot_point(box.slot)
			crate.scale = Vector3.ONE * 0.8
			crate.rotation.y = PI
			stored_models[box.slot] = crate
		var model: Node3D = stored_models[box.slot]
		model.show()
		model.get_node("BoxLabel").text = "%d %s" % [box.amount, Catalog.NAMES[box.product].to_upper()]
	for id in range(racks.size()):
		var count := 0
		for box in business.logistics.storage:
			if int(box.slot) / 16 == id: count += 1
		rack_labels[id].text = "%s%d | %d / 16" % [String.chr(65 + id / 4), id % 4 + 1, count]
	while furniture_boxes.size() < business.logistics.rack_delivered.size():
		var package: Node3D = operations._crate(self, "RackPackage%d" % furniture_boxes.size())
		package.scale = Vector3(1.2, 0.85, 0.75)
		package.rotation.y = PI
		furniture_boxes.append(package)
	for index in range(furniture_boxes.size()):
		var package := furniture_boxes[index]
		package.visible = index < business.logistics.rack_delivered.size()
		package.position = Vector3(0.1 + (index % 3) * 1.3, 0.5, 12.1 + (index / 3) * 1.3)
		if package.visible:
			var product: String = business.logistics.rack_delivered[index]
			package.get_node("BoxLabel").text = "PRODUCE TABLE\n12 BASKETS" if product == "tomato" else "SHELF\n" + Catalog.NAMES[product].to_upper()
	if truck_state == TruckState.IDLE and operations.delivery_state == operations.DeliveryState.IDLE and not business.logistics.rack_incoming.is_empty():
		truck.position = Vector3(-29, 0.1, 8.6)
		truck.show()
		truck_state = TruckState.ARRIVING

func _process(delta: float) -> void:
	if not built: return
	match truck_state:
		TruckState.IDLE:
			if operations.delivery_state == operations.DeliveryState.IDLE and not business.logistics.rack_incoming.is_empty(): _refresh()
		TruckState.ARRIVING:
			truck.position.x = move_toward(truck.position.x, 1.4, delta * 5)
			if is_equal_approx(truck.position.x, 1.4):
				truck_state = TruckState.UNLOADING
				unload_seconds = 2
		TruckState.UNLOADING:
			unload_seconds -= delta
			if unload_seconds <= 0 and business.receive_rack_delivery():
				truck_state = TruckState.LEAVING
				ui.show_feedback("Rack delivery arrived. Packages are outside the warehouse.")
				operations.play_sound("delivery")
		TruckState.LEAVING:
			truck.position.x = move_toward(truck.position.x, 29, delta * 6)
			if is_equal_approx(truck.position.x, 29):
				truck.hide()
				truck_state = TruckState.IDLE
				_refresh()
				operations._sync_state()

func _near(point: Vector3, distance := 1.9) -> bool:
	var offset: Vector3 = player.global_position - point
	return Vector2(offset.x, offset.z).length() <= distance

func storage_rack_target() -> int:
	var selected := -1
	var distance := 1.8
	for id in range(racks.size()):
		var point := service_point(id)
		var offset: Vector3 = player.global_position - point
		if Vector2(offset.x, offset.z).length() < distance:
			selected = id
			distance = Vector2(offset.x, offset.z).length()
	return selected

func _aimed(models: Array) -> int:
	var selected := -1
	var alignment := 0.88
	for index in range(models.size()):
		var model: Node3D = models[index]
		if not model.visible or not _near(model.global_position, 2.2): continue
		var dot: float = (-player.camera.global_basis.z).dot(player.camera.global_position.direction_to(model.global_position))
		if dot > alignment:
			var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, model.global_position)
			query.exclude = [player.get_rid()]
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
			alignment = dot
			selected = index
	return selected

func storage_box_target() -> int:
	var keys: Array = stored_models.keys()
	var index := _aimed(stored_models.values())
	return int(keys[index]) if index >= 0 else -1

func hint() -> String:
	if not built: return ""
	if office_door_target(): return "Close office door" if office_door.opening else "Open office door"
	if business.carried_stock > 0 and storage_rack_target() >= 0: return "Store product box"
	var slot := storage_box_target()
	if business.carried_stock == 0 and slot >= 0: return "Pick up stored box"
	var index := _aimed(furniture_boxes)
	if business.carried_stock == 0 and index >= 0: return "Unpack produce table" if business.logistics.rack_delivered[index] == "tomato" else ("Unpack cold-drink fridge" if business.logistics.rack_delivered[index] == "bottle" else "Unpack rack: " + Catalog.NAMES[business.logistics.rack_delivered[index]])
	if business.carried_stock == 0 and computer_target(): return "Warehouse ordering PC"
	if receiver.parked_box.visible and _aimed([receiver.parked_box]) >= 0: return "Pick up receiver's box"
	if receiver.visible and _near(receiver.global_position, 2): return "Talk to Anil - Warehouse"
	return ""

func try_interact() -> bool:
	if not built or player._menu_is_open() or world.get_node("RackFurnishing").active: return false
	if office_door_target():
		office_door.toggle()
		return true
	var rack := storage_rack_target()
	if business.carried_stock > 0 and rack >= 0:
		var slot: int = business.logistics.free_slot(rack)
		var success: bool = business.store_product_box(slot)
		ui.show_feedback("Box stored." if success else "Storage rack full or save failed.", not success)
		if success: operations.play_sound("stock")
		return true
	if business.carried_stock > 0: return false
	if receiver.parked_box.visible and _aimed([receiver.parked_box]) >= 0:
		var success: bool = business.retrieve_receiver_box()
		ui.show_feedback("Picked up receiver's box." if success else "Clear the delivery area first.", not success)
		return true
	var slot := storage_box_target()
	if slot >= 0:
		var success: bool = business.retrieve_product_box(slot)
		ui.show_feedback("Picked up stored box." if success else "Finish the carried box or clear the delivery area first.", not success)
		return true
	var index := _aimed(furniture_boxes)
	if index >= 0:
		if not world.get_node("RackFurnishing").begin_buy(business.logistics.rack_delivered[index]): ui.show_feedback("Cannot unpack this rack right now.", true)
		return true
	if computer_target():
		computer.get_node("ComputerTerminal").open(true)
		return true
	if is_instance_valid(receiver) and receiver.visible and _near(receiver.global_position, 2) and (-player.camera.global_basis.z).dot(player.camera.global_position.direction_to(receiver.global_position + Vector3(0, 1.4, 0))) > 0.9:
		ui.staff_dialog.open_for("warehouse")
		return true
	return false

func computer_target() -> bool:
	if not is_instance_valid(computer) or not _near(computer.global_position, 1.25): return false
	return (-player.camera.global_basis.z).dot(player.camera.global_position.direction_to(computer.global_position)) > 0.88

func office_door_target() -> bool:
	if not is_instance_valid(office_door) or not _near(office_door.global_position + Vector3(0.62, 1.1, 0), 2.1): return false
	return (-player.camera.global_basis.z).dot(player.camera.global_position.direction_to(office_door.global_position + Vector3(0.62, 1.1, 0))) > 0.82

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if try_interact(): get_viewport().set_input_as_handled()
