extends CharacterBody3D

const GameSettings := preload("res://game_settings.gd")
var invert_y := false

@export var speed := 5.0
## 1.0 normally; below 1.0 while the backpack is over its weight limit (inventory_ui.gd).
var load_factor := 1.0
@export var gravity := 20.0
@export var jump_velocity := 6.5
@export var mouse_sensitivity := 0.003
## First person everywhere: the camera sits at the eyes (CameraPivot), the player's
## own body stays hidden, and the view bobs a little while walking.
const EYE_HEIGHT := 0.7
const LOOK_LIMIT := 70.0
var bob_phase := 0.0

var indoors := false
var controller: Node
## Fly mode for testing (the F key, or L3 on a controller; no button on screen): no gravity and
## no collisions; W/A/S/D go where you look, Space rises, Shift or Ctrl sinks, Alt is
## faster. Off by default and never saved.
var flying := false
var fly_layers := Vector2i.ZERO
var shop_indoors := false
var warehouse_indoors := false
var bargain_menu: Control
var supplier_menu: Control
var checkout_menu: Control

@onready var camera_pivot = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var player_mesh: MeshInstance3D = $MeshInstance3D
@onready var shop_menu: Control = get_tree().current_scene.get_node("Ui/ShopMenu")
@onready var house_menu: Control = get_tree().current_scene.get_node("Ui/HouseMenu")
@onready var sale_price_input: SpinBox = shop_menu.get_node("SalePriceInput")

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.set_use_accumulated_input(false)
	var settings = GameSettings.new()
	settings.load_file(get_tree().current_scene.get_meta("session_settings_path", "user://settings.cfg"))
	settings.apply_player(self)
	camera.near = 0.05
	# Controller support (controller.gd): walk, look, buttons and a menu pointer.
	controller = preload("res://controller.gd").new()
	controller.name = "Controller"
	add_child(controller)
	controller.changed.connect(func(pad: bool): get_tree().current_scene.get_node("Ui")._on_device_changed(pad))
	spring_arm.add_excluded_object(get_rid())
	spring_arm.spring_length = 0.0
	camera.position = Vector3.ZERO
	player_mesh.hide()
	var interior: Area3D = get_tree().current_scene.get_node("House/InteriorArea")
	interior.body_entered.connect(_on_interior_entered)
	interior.body_exited.connect(_on_interior_exited)

func _on_interior_entered(body: Node3D) -> void:
	if body == self:
		indoors = true
		spring_arm.spring_length = 0.0
		camera.position = Vector3.ZERO
		player_mesh.hide()

func _apply_graphics_settings() -> void:
	var settings := GameSettings.new()
	settings.load_file(get_tree().current_scene.get_meta("session_settings_path", "user://settings.cfg"))
	settings.apply_graphics(get_tree().current_scene)

func _on_interior_exited(body: Node3D) -> void:
	if body == self:
		indoors = false

## The tablet (shop menu) comes out with Tab, wherever the player is.
func open_tablet() -> void:
	if _menu_is_open(): return
	house_menu.hide()
	shop_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _menu_is_open() -> bool:
	var roadmap := get_tree().current_scene.get_node_or_null("Ui/RoadmapMenu")
	if is_instance_valid(roadmap) and roadmap.visible: return true
	var pause := get_tree().current_scene.get_node_or_null("Ui/PauseMenu")
	if is_instance_valid(pause) and pause.is_open(): return true
	var report := get_tree().current_scene.get_node_or_null("Ui/DayReportScreen")
	if is_instance_valid(report) and report.visible: return true
	var inventory := get_tree().current_scene.get_node_or_null("Ui/InventoryBar")
	if is_instance_valid(inventory) and inventory.is_open(): return true
	var journal := get_tree().current_scene.get_node_or_null("Ui/QuestJournal")
	if is_instance_valid(journal) and journal.is_open(): return true
	var world_map := get_tree().current_scene.get_node_or_null("Ui/WorldMap")
	if is_instance_valid(world_map) and world_map.is_open(): return true
	for book in get_tree().get_nodes_in_group("dungeon_panel"):
		if book.visible: return true
	for talk in ["Ui/StaffDialog", "Ui/CustomerChat", "Ui/FriendChat", "Ui/ShopSaleDialog", "Ui/HowToPlay"]:
		var dialog := get_tree().current_scene.get_node_or_null(talk)
		if is_instance_valid(dialog) and dialog.visible: return true
	return shop_menu.visible or house_menu.visible or (is_instance_valid(bargain_menu) and bargain_menu.visible) or (is_instance_valid(supplier_menu) and supplier_menu.visible) or (is_instance_valid(checkout_menu) and checkout_menu.visible)

func _process(_delta: float) -> void:
	player_mesh.visible = false

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _menu_is_open(): return
	rotate_y(-event.relative.x * mouse_sensitivity)
	camera_pivot.rotate_x(event.relative.y * mouse_sensitivity * (1 if invert_y else -1))
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-LOOK_LIMIT), deg_to_rad(LOOK_LIMIT))
	get_viewport().set_input_as_handled()

## Turns the view by the given radians (the controller's right stick; the mouse does the same).
func look_by(yaw: float, pitch: float) -> void:
	rotate_y(-yaw)
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - pitch * (-1 if invert_y else 1), deg_to_rad(-LOOK_LIMIT), deg_to_rad(LOOK_LIMIT))

func toggle_flying() -> void:
	flying = not flying
	if flying:
		fly_layers = Vector2i(collision_layer, collision_mask)
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
	else:
		collision_layer = fly_layers.x
		collision_mask = fly_layers.y
		velocity = Vector3.ZERO

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F and not _menu_is_open():
		toggle_flying()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_STICK:
		toggle_flying()
		return
	if event.is_action_pressed("ui_cancel"):
		if _menu_is_open():
			var dialog := get_tree().current_scene.get_node_or_null("Ui/StaffDialog")
			if is_instance_valid(dialog) and dialog.visible: dialog.close_menu()
			if is_instance_valid(bargain_menu) and bargain_menu.visible:
				bargain_menu.close_menu()
			if is_instance_valid(supplier_menu) and supplier_menu.visible:
				supplier_menu.close_menu()
			if is_instance_valid(checkout_menu) and checkout_menu.visible:
				checkout_menu.close_menu()
			sale_price_input.apply()
			shop_menu.hide()
			house_menu.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			var pause := get_tree().current_scene.get_node_or_null("Ui/PauseMenu")
			if is_instance_valid(pause): pause.open_menu()
			else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return

	# Tab takes out the tablet anywhere (the open tablet puts itself away on Tab).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		var help := get_tree().current_scene.get_node_or_null("Ui/HowToPlay")
		if help != null and not _menu_is_open():
			help.open()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		# Everything the tablet did now lives on the shop PC.
		var ui := get_tree().current_scene.get_node_or_null("Ui")
		if ui != null and not _menu_is_open(): ui.show_feedback("The tablet is now on the shop PC: press E at the desk. Goals are in the Journal (J).")
		get_viewport().set_input_as_handled()
		return

	if _menu_is_open():
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	var direction = Vector3.ZERO
	spring_arm.spring_length = 0.0
	# A small head bob while walking on the ground; back to eye height when still.
	var walking: bool = is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5
	bob_phase = bob_phase + delta * 9.0 if walking else 0.0
	camera_pivot.position.y = move_toward(camera_pivot.position.y, EYE_HEIGHT + (sin(bob_phase) * 0.025 if walking else 0.0), delta * 0.6)

	if not _menu_is_open():
		# Returning from a computer/menu can leave Windows mouse capture released.
		# Beginning keyboard movement immediately restores normal simultaneous look.
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D)):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if Input.is_key_pressed(KEY_W):
			direction.z -= 1
		if Input.is_key_pressed(KEY_S):
			direction.z += 1
		if Input.is_key_pressed(KEY_A):
			direction.x -= 1
		if Input.is_key_pressed(KEY_D):
			direction.x += 1

	direction = direction.normalized()
	# The left stick walks at its own pace (half push, half speed).
	if direction == Vector3.ZERO and is_instance_valid(controller):
		var stick: Vector2 = controller.move_vector()
		direction = Vector3(stick.x, 0, stick.y)

	if flying:
		# Fly where the camera looks.
		var heading: Vector3 = camera.global_transform.basis * direction
		var lift := 0.0
		if not _menu_is_open():
			if Input.is_key_pressed(KEY_SPACE): lift += 1.0
			if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL): lift -= 1.0
		var pace: float = speed * (9.0 if Input.is_key_pressed(KEY_ALT) else 3.5)
		velocity = (heading + Vector3(0, lift, 0)).limit_length(1.0) * pace
		move_and_slide()
		return

	direction = transform.basis * direction

	# Shift sprints (not with a menu open); speed eases in and out instead of snapping.
	var sprint := 1.0
	if Input.is_key_pressed(KEY_SHIFT) and not _menu_is_open(): sprint = 1.5
	var wanted: Vector3 = direction * speed * load_factor * sprint
	var ease_rate: float = (45.0 if direction != Vector3.ZERO else 60.0) * delta
	velocity.x = move_toward(velocity.x, wanted.x, ease_rate)
	velocity.z = move_toward(velocity.z, wanted.z, ease_rate)

	if is_on_floor() and not _menu_is_open() and Input.is_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity
	elif not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	move_and_slide()
