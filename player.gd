extends CharacterBody3D

const GameSettings := preload("res://game_settings.gd")
var invert_y := false

@export var speed := 5.0
@export var gravity := 20.0
@export var jump_velocity := 6.5
@export var mouse_sensitivity := 0.003
@export var camera_distance := 4.5

var indoors := false
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
	spring_arm.add_excluded_object(get_rid())
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
	for talk in ["Ui/StaffDialog", "Ui/CustomerChat", "Ui/FriendChat"]:
		var dialog := get_tree().current_scene.get_node_or_null(talk)
		if is_instance_valid(dialog) and dialog.visible: return true
	return shop_menu.visible or house_menu.visible or (is_instance_valid(bargain_menu) and bargain_menu.visible) or (is_instance_valid(supplier_menu) and supplier_menu.visible) or (is_instance_valid(checkout_menu) and checkout_menu.visible)

func _process(_delta: float) -> void:
	player_mesh.visible = not (indoors or shop_indoors or warehouse_indoors) and spring_arm.get_hit_length() >= 1.8

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _menu_is_open(): return
	rotate_y(-event.relative.x * mouse_sensitivity)
	camera_pivot.rotate_x(event.relative.y * mouse_sensitivity * (1 if invert_y else -1))
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, deg_to_rad(-55), deg_to_rad(55 if warehouse_indoors else 30))
	get_viewport().set_input_as_handled()

func _unhandled_input(event):
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		open_tablet()
		get_viewport().set_input_as_handled()
		return

	if _menu_is_open():
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not indoors and not shop_indoors and not warehouse_indoors:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_distance = clampf(camera_distance - 0.5, 1.2, 6.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_distance = clampf(camera_distance + 0.5, 1.2, 6.0)

func _physics_process(delta):
	var direction = Vector3.ZERO
	if indoors or shop_indoors or warehouse_indoors:
		spring_arm.spring_length = 0.0
	else:
		spring_arm.spring_length = lerpf(spring_arm.spring_length, camera_distance, minf(delta * 10.0, 1.0))

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

	direction = transform.basis * direction

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if is_on_floor() and not _menu_is_open() and Input.is_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity
	elif not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	move_and_slide()
