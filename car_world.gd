extends Node3D

# The player's cars: a small parking lot beside the home (four bays: hatchback, sedan,
# SUV and pickup in different paints, each free to drive). E at a car's door gets in (the
# first-person view moves to the right-hand driver seat), W/S gas and brake, A/D steer,
# Space the handbrake, E again gets out beside the car. The left stick and RT/LT do the same
# on a controller (controller.gd). Created by shop_operations.gd (like export_world).
const DrivableCar := preload("res://drivable_car.gd")
const LOT_AT := Vector3(13.4, 0.1, -0.1)
const BAY := 2.7
const REACH := 3.2
const CARS := [["volterra", Color(0.72, 0.05, 0.07)], ["volterra", Color(0.08, 0.2, 0.68)]]

var ops: Node
var player: CharacterBody3D
var cars: Array[CharacterBody3D] = []
var driving: CharacterBody3D
var hud: PanelContainer
var gear_label: Label
var speed_label: Label
var name_label: Label
var saved_layers := Vector2i.ZERO
var last_yaw := 0.0
## Third person (the default) follows the car from behind and above; C (or a click of the right
## stick) switches to the view from the driver seat.
var third_person := true
var chase_cam: Camera3D

func _ready() -> void:
	name = "CarWorld"
	player = get_tree().current_scene.get_node("Player")
	_build_lot()
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	_build_hud(layer)
	chase_cam = Camera3D.new()
	chase_cam.name = "ChaseCamera"
	chase_cam.far = 800.0
	chase_cam.near = 0.1
	add_child(chase_cam)
	get_tree().current_scene.get_node("Shop/ShopArea").business.clock_changed.connect(_update_lamps)

## The driving panel above the hotbar: gear, speed, car name, and the keys that work now.
func _build_hud(layer: CanvasLayer) -> void:
	hud = PanelContainer.new()
	hud.name = "DriveHud"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.05, 0.07, 0.78)
	style.border_color = Color(1, 1, 1, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	hud.add_theme_stylebox_override("panel", style)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.anchor_left = 0.5
	hud.anchor_right = 0.5
	hud.anchor_top = 1.0
	hud.anchor_bottom = 1.0
	hud.offset_top = -100
	hud.offset_bottom = -100
	hud.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.visible = false
	layer.add_child(hud)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	hud.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	gear_label = _hud_label(row, 34, Color(0.45, 0.9, 0.55))
	gear_label.custom_minimum_size.x = 34
	gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label = _hud_label(row, 34, Color(1, 0.97, 0.85))
	speed_label.custom_minimum_size.x = 150
	name_label = _hud_label(row, 16, Color(0.7, 0.78, 0.88))
	var keys := _hud_label(column, 13, Color(0.62, 0.7, 0.8))
	keys.text = "W / S  gas and brake      A / D  steer      Space  handbrake      C  change view      E  get out"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _hud_label(parent: Node, size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

## Your two bays by the home: a paved driveway from the Main Road's pavement north
## between white lines, a sign post, and the cars parked nose to the road.
func _build_lot() -> void:
	var lot := Node3D.new()
	lot.name = "HomeParking"
	lot.position = LOT_AT
	add_child(lot)
	var length := 7.7
	for index in range(CARS.size()):
		var x: float = index * BAY
		_box(lot, Vector3(BAY - 0.04, 0.012, length), Vector3(x, 0.027, 0.45 - 0.0), Color(0.5, 0.51, 0.53))
		for side in [-1, 1]: _box(lot, Vector3(0.07, 0.006, length - 0.5), Vector3(x + side * (BAY / 2.0 - 0.04), 0.035, 0.0), Color(0.93, 0.93, 0.9))
		_box(lot, Vector3(BAY - 0.3, 0.006, 0.07), Vector3(x, 0.035, -length / 2.0 + 0.55), Color(0.93, 0.93, 0.9))
	var post := _box(lot, Vector3(0.1, 2.0, 0.1), Vector3(BAY * CARS.size() - BAY / 2.0 + 0.3, 1.0, -2.0), Color(0.25, 0.27, 0.3))
	var board := _box(lot, Vector3(1.3, 0.5, 0.06), Vector3(BAY * CARS.size() - BAY / 2.0 + 0.3, 2.0, -2.0), Color(0.1, 0.28, 0.55))
	var label := Label3D.new()
	label.text = "APNA GHAR\nPARKING"
	label.position = Vector3(0, 0, 0.04)
	label.font_size = 30
	label.pixel_size = 0.0045
	label.outline_size = 0
	board.add_child(label)
	var label_back := label.duplicate() as Label3D
	label_back.position = Vector3(0, 0, -0.04)
	label_back.rotation.y = PI
	board.add_child(label_back)
	# Cars parked in the colony bays (town_plan.gd) are drivable too.
	var plan = get_tree().current_scene.get_node("Neighbourhood/TownExpansion").plan
	if plan != null:
		for spot in plan.car_spots:
			var parked: CharacterBody3D = DrivableCar.create(spot[2], spot[3])
			parked.position = spot[0]
			parked.rotation.y = spot[1]
			add_child(parked)
			cars.append(parked)
	for index in range(CARS.size()):
		var car: CharacterBody3D = DrivableCar.create(CARS[index][0], CARS[index][1])
		car.position = LOT_AT + Vector3(index * BAY, 0.0, -0.6)
		car.rotation.y = PI
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
	# While driving, the panel above the hotbar already lists every key.
	if is_instance_valid(driving): return ""
	var car := _near_car()
	if car == null: return ""
	return "E - drive the %s" % car.data.name

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
	_apply_view(true)

## Third person or the driver seat: whichever camera is current.
func _apply_view(snap: bool) -> void:
	if third_person and is_instance_valid(driving):
		if snap: _chase(1.0)
		chase_cam.current = true
	else:
		player.camera.current = true

func _chase(weight: float) -> void:
	var car := driving
	var behind: Vector3 = car.global_transform.basis.z
	behind.y = 0.0
	behind = behind.normalized()
	var wanted: Vector3 = car.global_position + behind * (6.4 + absf(car.speed) * 0.05) + Vector3(0, 2.5, 0)
	chase_cam.global_position = chase_cam.global_position.lerp(wanted, weight)
	chase_cam.look_at(car.global_position + Vector3(0, 0.9, 0) - behind * 1.5)
	chase_cam.fov = 68.0 + clampf(absf(car.speed) * 0.7, 0.0, 14.0)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(driving) and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		third_person = not third_person
		_apply_view(true)
		get_viewport().set_input_as_handled()

func _get_out() -> void:
	var car := driving
	driving = null
	car.occupied = false
	car.speed = 0.0
	hud.visible = false
	player.camera.current = true
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
	if third_person: _chase(minf(1.0, delta * 7.0))
	var gear := "N" if absf(driving.speed) < 0.4 else ("D" if driving.speed > 0.0 else "R")
	gear_label.text = gear
	gear_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.35) if gear == "R" else (Color(0.8, 0.85, 0.9) if gear == "N" else Color(0.45, 0.9, 0.55)))
	speed_label.text = "%d km/h" % roundi(absf(driving.speed) * 3.6)
	name_label.text = driving.data.name
	if player.global_position.y < -20.0: _get_out()
