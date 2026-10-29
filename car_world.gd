extends Node3D

# The player's cars: a small parking lot beside the home (four bays: hatchback, sedan,
# SUV and pickup in different paints, each free to drive). E at a car's door gets in (the
# first-person view moves to the right-hand driver seat), W/S gas and brake, A/D steer,
# Space the handbrake, E again gets out beside the car. The left stick and RT/LT do the same
# on a controller (controller.gd). Created by shop_operations.gd (like export_world).
const DrivableCar := preload("res://drivable_car.gd")
const LOT_AT := Vector3(3.0, 0.1, -40.65)
const BAY := 3.1
const REACH := 3.2
const CARS := [["hatchback", Color(0.78, 0.12, 0.14)], ["sedan", Color(0.14, 0.28, 0.62)], ["suv", Color(0.9, 0.9, 0.88)], ["pickup", Color(0.16, 0.45, 0.28)]]

var ops: Node
var player: CharacterBody3D
var cars: Array[CharacterBody3D] = []
var driving: CharacterBody3D
var hud: Label
var saved_layers := Vector2i.ZERO
var last_yaw := 0.0

func _ready() -> void:
	name = "CarWorld"
	player = get_tree().current_scene.get_node("Player")
	_build_lot()
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	hud = Label.new()
	hud.name = "DriveHud"
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hud.position += Vector2(-130, -90)
	hud.visible = false
	layer.add_child(hud)
	get_tree().current_scene.get_node("Shop/ShopArea").business.clock_changed.connect(_update_lamps)

## A tarmac pad with white bay lines, a sign, a low kerb, and the four cars facing +x.
func _build_lot() -> void:
	var lot := Node3D.new()
	lot.name = "ParkingLot"
	lot.position = LOT_AT
	add_child(lot)
	var asphalt := _box(lot, Vector3(7.0, 0.05, BAY * CARS.size() + 0.8), Vector3(0, 0.0, BAY * 1.5 - BAY * 1.5), Color(0.2, 0.21, 0.23))
	asphalt.position.z = BAY * (CARS.size() - 1) / 2.0
	for index in range(CARS.size() + 1):
		_box(lot, Vector3(5.6, 0.052, 0.09), Vector3(-0.1, 0.0, index * BAY - BAY / 2.0), Color(0.93, 0.93, 0.9))
	_box(lot, Vector3(0.18, 0.2, BAY * CARS.size() + 0.8), Vector3(3.5, 0.1, BAY * (CARS.size() - 1) / 2.0), Color(0.75, 0.75, 0.72))
	var post := _box(lot, Vector3(0.1, 2.2, 0.1), Vector3(-3.2, 1.1, -BAY / 2.0 - 0.3), Color(0.25, 0.27, 0.3))
	var board := _box(lot, Vector3(1.3, 0.55, 0.06), Vector3(-3.2, 2.2, -BAY / 2.0 - 0.3), Color(0.1, 0.28, 0.55))
	var label := Label3D.new()
	label.text = "APNA PARKING"
	label.position = Vector3(0, 0, 0.04)
	label.rotation.y = 0.0
	label.font_size = 36
	label.pixel_size = 0.0045
	label.outline_size = 0
	board.add_child(label)
	var label_back := label.duplicate() as Label3D
	label_back.position = Vector3(0, 0, -0.04)
	label_back.rotation.y = PI
	board.add_child(label_back)
	for index in range(CARS.size()):
		var car: CharacterBody3D = DrivableCar.create(CARS[index][0], CARS[index][1])
		car.position = LOT_AT + Vector3(0.1, 0.0, index * BAY)
		car.rotation.y = PI / 2.0
		add_child(car)
		cars.append(car)

func _box(parent: Node3D, size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.95
	box.material = material
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	return mesh

func _update_lamps() -> void:
	var minutes: float = get_tree().current_scene.get_node("Shop/ShopArea").business.minutes_of_day
	var night := minutes < 390.0 or minutes >= 1110.0
	for car in cars: car.set_night(night)

func _near_car() -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_distance := REACH
	for car in cars:
		var distance := player.global_position.distance_to(car.global_position + Vector3(0, 1.0, 0))
		var door := player.global_position.distance_to(car.to_global(Vector3(0.0, 1.0, 0.0)))
		distance = minf(distance, door)
		if distance < best_distance:
			best = car
			best_distance = distance
	return best

func hint() -> String:
	if is_instance_valid(driving): return "E - get out of the car"
	var car := _near_car()
	if car == null: return ""
	return "E - drive the %s  (W/S gas and brake, A/D steer, Space handbrake)" % car.data.name

func try_interact() -> bool:
	if is_instance_valid(driving):
		_get_out()
		return true
	var car := _near_car()
	if car == null: return false
	if is_instance_valid(ops) and (ops.holding_bag or ops.shop.business.carried_stock > 0): return false
	_get_in(car)
	return true

func _get_in(car: CharacterBody3D) -> void:
	driving = car
	car.occupied = true
	saved_layers = Vector2i(player.collision_layer, player.collision_mask)
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.rotation.y = car.rotation.y
	last_yaw = car.rotation.y
	player.global_position = car.seat_position()
	hud.visible = true

func _get_out() -> void:
	var car := driving
	driving = null
	car.occupied = false
	car.speed = 0.0
	hud.visible = false
	player.collision_layer = saved_layers.x
	player.collision_mask = saved_layers.y
	player.global_position = car.to_global(Vector3(-2.0, 0.9, 0.2))
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(driving): return
	var throttle := 0.0
	var steering := 0.0
	if Input.is_key_pressed(KEY_W): throttle += 1.0
	if Input.is_key_pressed(KEY_S): throttle -= 1.0
	if Input.is_key_pressed(KEY_D): steering += 1.0
	if Input.is_key_pressed(KEY_A): steering -= 1.0
	var pad = player.get("controller")
	if is_instance_valid(pad):
		var stick: Vector2 = pad.move_vector() if pad.using_pad else Vector2.ZERO
		if stick != Vector2.ZERO:
			throttle = -stick.y
			steering = stick.x
	driving.drive(throttle, steering, Input.is_key_pressed(KEY_SPACE), delta)
	# The view turns with the car (and you can still look around with the mouse).
	player.rotation.y += driving.rotation.y - last_yaw
	last_yaw = driving.rotation.y
	player.global_position = driving.seat_position()
	hud.text = "%d km/h   %s" % [roundi(absf(driving.speed) * 3.6), driving.data.name]
	if player.global_position.y < -20.0: _get_out()
