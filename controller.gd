extends Node

# Controller support (Xbox layout; PlayStation maps the same buttons). Added by player.gd.
# It turns the controller into the inputs the game already reads, so every screen works:
#   In the world  left stick walk, right stick look, A jump, X interact (E), B drop (Q),
#                 Y tablet (Tab), RT or RB swing the lathi (left click), Start pause, Back help (F1)
#   In a menu     the left stick moves the pointer, A clicks, right stick scrolls,
#                 B or Start closes (Escape), the d-pad nudges the pointer
# Nothing happens until a controller is connected.
const DEADZONE := 0.22
const LOOK_SPEED := 2.9
const POINTER_SPEED := 760.0
const SCROLL_SPEED := 9.0

var player: CharacterBody3D
var trigger_down := false
var pointer := Vector2.ZERO
var was_menu := false
## True while the player last used the controller, false after the keyboard or mouse.
## Switches by itself the moment either is touched; `changed` tells the screen (game_ui.gd)
## to swap its key hints.
var using_pad := false
var warped_at := 0
signal changed(pad: bool)
## Our own synthetic key and mouse events carry this device number, so they are not
## mistaken for the keyboard.
const OWN_DEVICE := 77

func _ready() -> void:
	player = get_parent()

func _set_pad(pad: bool) -> void:
	if pad == using_pad: return
	using_pad = pad
	if pad: pointer = get_viewport().get_mouse_position()
	changed.emit(pad)

func connected() -> bool:
	return not Input.get_connected_joypads().is_empty()

func _axis(axis: JoyAxis) -> float:
	var value := Input.get_joy_axis(Input.get_connected_joypads()[0], axis)
	return 0.0 if absf(value) < DEADZONE else value

func _stick(x_axis: JoyAxis, y_axis: JoyAxis) -> Vector2:
	var stick := Vector2(_axis(x_axis), _axis(y_axis))
	return stick.limit_length(1.0)

## The walking direction from the left stick (x right, y back), zero in a menu.
func move_vector() -> Vector2:
	if not using_pad or not connected() or player._menu_is_open(): return Vector2.ZERO
	return _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)

func _process(delta: float) -> void:
	if not connected(): return
	var pad_id: int = Input.get_connected_joypads()[0]
	# Any real stick push or trigger pull wakes the controller.
	if not using_pad and (Vector2(Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad_id, JOY_AXIS_LEFT_Y)).length() > 0.45 or Vector2(Input.get_joy_axis(pad_id, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad_id, JOY_AXIS_RIGHT_Y)).length() > 0.45 or Input.get_joy_axis(pad_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5): _set_pad(true)
	if not using_pad: return
	var menu: bool = player._menu_is_open() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if menu:
		if not was_menu: pointer = get_viewport().get_mouse_position()
		_pointer(delta)
	elif not was_menu:
		var look := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
		if look != Vector2.ZERO: player.look_by(look.x * LOOK_SPEED * delta, look.y * LOOK_SPEED * 0.8 * delta)
	was_menu = menu
	var pulled: bool = Input.get_joy_axis(Input.get_connected_joypads()[0], JOY_AXIS_TRIGGER_RIGHT) > 0.55
	if pulled != trigger_down and not menu:
		trigger_down = pulled
		_click(MOUSE_BUTTON_LEFT, pulled, get_viewport().get_visible_rect().size / 2.0)
	elif menu: trigger_down = false

func _pointer(delta: float) -> void:
	var move := _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	if move != Vector2.ZERO:
		var size := get_viewport().get_visible_rect().size
		pointer = (pointer + move * move.length() * POINTER_SPEED * delta).clamp(Vector2.ZERO, size - Vector2.ONE)
		warped_at = Time.get_ticks_msec()
		get_viewport().warp_mouse(pointer)
		var motion := InputEventMouseMotion.new()
		motion.position = pointer
		motion.global_position = pointer
		motion.relative = move * POINTER_SPEED * delta
		motion.device = OWN_DEVICE
		Input.parse_input_event(motion)
	var scroll := _axis(JOY_AXIS_RIGHT_Y)
	if scroll != 0.0:
		var wheel := InputEventMouseButton.new()
		wheel.position = pointer
		wheel.global_position = pointer
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if scroll > 0.0 else MOUSE_BUTTON_WHEEL_UP
		wheel.factor = absf(scroll) * SCROLL_SPEED * delta * 10.0
		wheel.device = OWN_DEVICE
		wheel.pressed = true
		Input.parse_input_event(wheel)
		wheel.pressed = false
		Input.parse_input_event(wheel)

func _input(event: InputEvent) -> void:
	if event.device == OWN_DEVICE: return
	# Keyboard or mouse: the controller steps aside at once.
	if event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 1.5 and Time.get_ticks_msec() - warped_at > 250):
		_set_pad(false)
		return
	if not event is InputEventJoypadButton: return
	_set_pad(true)
	var menu: bool = player._menu_is_open() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	var down: bool = event.pressed
	match event.button_index:
		JOY_BUTTON_A:
			if menu: _click(MOUSE_BUTTON_LEFT, down, pointer)
			else: _key(KEY_SPACE, down)
		JOY_BUTTON_X:
			if not menu: _key(KEY_E, down)
		JOY_BUTTON_B:
			if menu: _key(KEY_ESCAPE, down)
			else: _key(KEY_Q, down)
		JOY_BUTTON_Y:
			if not menu or player._menu_is_open(): _key(KEY_TAB, down)
		JOY_BUTTON_START:
			_key(KEY_ESCAPE, down)
		JOY_BUTTON_RIGHT_STICK:
			_key(KEY_C, down)
		JOY_BUTTON_LEFT_SHOULDER:
			_key(KEY_SHIFT, down)
		JOY_BUTTON_BACK:
			_key(KEY_F1, down)
		JOY_BUTTON_RIGHT_SHOULDER:
			if not menu: _click(MOUSE_BUTTON_LEFT, down, get_viewport().get_visible_rect().size / 2.0)
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			if menu and down:
				var step := Vector2(0, -40) if event.button_index == JOY_BUTTON_DPAD_UP else Vector2(0, 40) if event.button_index == JOY_BUTTON_DPAD_DOWN else Vector2(-40, 0) if event.button_index == JOY_BUTTON_DPAD_LEFT else Vector2(40, 0)
				pointer = (pointer + step).clamp(Vector2.ZERO, get_viewport().get_visible_rect().size - Vector2.ONE)
				warped_at = Time.get_ticks_msec()
				get_viewport().warp_mouse(pointer)

func _key(code: Key, pressed: bool) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = pressed
	press.device = OWN_DEVICE
	Input.parse_input_event(press)

func _click(button: MouseButton, pressed: bool, at: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = pressed
	click.position = at
	click.global_position = at
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.device = OWN_DEVICE
	Input.parse_input_event(click)
