extends Panel

# A talk box at the bottom of the screen, like a store sim's dialogue: a round
# portrait with the speaker's initial, their name and a tag line, what they say
# (typed out), and up to four numbered replies (click, or press 1-4; Esc leaves).
# staff_dialog.gd and customer_chat.gd fill it in.

const Bazaar := preload("res://ui_bazaar.gd")
const MAX_CHOICES := 4
## People further than this are not turned to (a talk opened from the PC or a notice).
const FACE_REACH := 8.0
var choices: Array[Button] = []
var portrait: Panel
var initial: Label
var mood: ProgressBar
var typing := 0.0
## The person you talk to: while the box is open the view turns smoothly to their face.
var speaker_node: Node3D
var face_height := 1.5
## Their recorded lines play here (speak()); a new line or leaving stops the last one.
var voice: AudioStreamPlayer
@onready var ui = get_parent()
@onready var business = get_tree().current_scene.get_node("Shop/ShopArea").business

func _ready() -> void:
	hide()
	# The pause menu's look (ui_bazaar.gd): a cream card with a saffron top, outlined reply
	# buttons in the plain font, dark ink text.
	theme = Bazaar.make_theme()
	var frame := Bazaar.card()
	frame.shadow_size = 14
	add_theme_stylebox_override("panel", frame)
	portrait = Panel.new()
	portrait.name = "Portrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	initial = Label.new()
	initial.name = "Initial"
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.add_theme_font_size_override("font_size", 34)
	initial.add_theme_color_override("font_color", Color.WHITE)
	initial.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	initial.add_theme_constant_override("shadow_offset_y", 2)
	portrait.add_child(initial)
	var speaker: Label = ui._label("SpeakerLabel", self)
	speaker.add_theme_font_size_override("font_size", 20)
	speaker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var tag: Label = ui._label("HappinessLabel", self)
	tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Bazaar.MUTED)
	var message: Label = ui._label("MessageLabel", self)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 16)
	# Dark ink on cream: no HUD shadow.
	for label in [speaker, tag, message]:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	speaker.add_theme_color_override("font_color", Bazaar.INK)
	message.add_theme_color_override("font_color", Bazaar.INK)
	mood = ProgressBar.new()
	mood.name = "HappinessBar"
	mood.show_percentage = false
	mood.hide()
	add_child(mood)
	for index in range(MAX_CHOICES):
		var button := Button.new()
		button.name = "Reply%d" % index
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		add_child(button)
		button.pressed.connect(func(): _reply(index))
		choices.append(button)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "Leave  Esc"
	add_child(close)
	close.pressed.connect(close_menu)
	voice = AudioStreamPlayer.new()
	voice.name = "Voice"
	add_child(voice)
	get_viewport().size_changed.connect(_layout)
	_layout()

## Turns the view to `person`'s face while this talk is open (call it before present()).
## Their face is found from their model's top, as characters differ in height.
func look_at_person(person: Node3D) -> void:
	speaker_node = person
	face_height = _face_height(person) if is_instance_valid(person) else 1.5

static func _face_height(person: Node3D) -> float:
	var top := -INF
	for part in person.find_children("*", "GeometryInstance3D", true, false):
		if part is Label3D or part is Sprite3D or not part.is_visible_in_tree(): continue
		top = maxf(top, (part.global_transform * part.get_aabb()).end.y)
	if top == -INF: return 1.5
	# The middle of a big cartoon head sits about a quarter of a metre under its top.
	return clampf(top - person.global_position.y - 0.25, 0.8, 2.2)

## Plays a recorded line (null: silence); it replaces the line before.
func speak(stream: AudioStream) -> void:
	voice.stop()
	if stream == null: return
	voice.stream = stream
	voice.play()

## Turns the player (yaw) and the camera (pitch) a little each frame towards `face`.
func _turn_to(face: Vector3, delta: float) -> void:
	var player = ui.player
	if not is_instance_valid(player): return
	var way: Vector3 = face - player.camera.global_position
	var flat := Vector2(way.x, way.z).length()
	if flat < 0.3 or flat > FACE_REACH: return
	var weight := 1.0 - exp(-delta * 5.0)
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-way.x, -way.z), weight)
	var limit := deg_to_rad(player.LOOK_LIMIT)
	player.camera_pivot.rotation.x = lerpf(player.camera_pivot.rotation.x, clampf(atan2(way.y, flat), -limit, limit), weight)

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var width := minf(760, view.x - 32)
	var narrow := width < 560
	var shown := choices.filter(func(button): return button.visible).size()
	var rows := shown if narrow else ceili(shown / 2.0)
	var height := 166 + maxi(1, rows) * 40
	ui._place(self, (view.x - width) / 2.0, maxf(56, view.y - height - 18), width, height)
	ui._place(portrait, 16, 16, 72, 72)
	ui._place(initial, 0, 0, 72, 72)
	var close: Button = get_node("CloseButton")
	var close_width := maxf(96, close.get_combined_minimum_size().x)
	ui._place(get_node("SpeakerLabel"), 104, 16, width - 134 - close_width, 28)
	ui._place(get_node("HappinessLabel"), 104, 46, width - 120, 20)
	ui._place(mood, 104, 70, minf(220, width - 120), 10)
	ui._place(close, width - 16 - close_width, 14, close_width, 30)
	ui._place(get_node("MessageLabel"), 16, 100, width - 32, 56)
	var column := 0
	var row := 0
	for button in choices:
		if not button.visible: continue
		var button_width := width - 32 if narrow else (width - 40) / 2.0
		ui._place(button, 16 + column * (button_width + 8), 160 + row * 40, button_width, 34)
		if narrow or column == 1:
			column = 0
			row += 1
		else: column = 1

## Shows a speaker and their line with numbered replies (disabled ones greyed).
func present(speaker: String, tag: String, colour: Color, line: String, replies: Array, disabled: Array = []) -> void:
	for menu in [ui.shop_menu, ui.house_menu, ui.supplier_menu, ui.checkout_menu, ui.bargain_menu]:
		menu.hide()
	for other in ui.get_children():
		if other != self and other.get_script() != null and other.has_method("present") and other.visible: other.close_menu()
	get_node("SpeakerLabel").text = speaker
	get_node("HappinessLabel").text = tag
	var face := StyleBoxFlat.new()
	face.bg_color = colour
	face.set_corner_radius_all(36)
	face.border_color = Color(1, 1, 1, 0.85)
	face.set_border_width_all(3)
	portrait.add_theme_stylebox_override("panel", face)
	initial.text = speaker.left(1).to_upper()
	say(line, replies, disabled)
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## The next line in the same talk.
func say(line: String, replies: Array, disabled: Array = []) -> void:
	var message: Label = get_node("MessageLabel")
	message.text = "\"%s\"" % line
	message.visible_ratio = 0.0
	typing = 0.0
	for index in range(MAX_CHOICES):
		var button := choices[index]
		button.visible = index < replies.size()
		if not button.visible: continue
		button.text = "%d   %s" % [index + 1, replies[index]]
		button.disabled = index < disabled.size() and disabled[index]
	_layout()

func _process(delta: float) -> void:
	if not visible: return
	if is_instance_valid(speaker_node) and speaker_node.is_inside_tree():
		# Aimed a little under the face, so the face sits above the talk box, not behind it.
		_turn_to(speaker_node.global_position + Vector3(0, face_height - 0.3, 0), delta)
	var message: Label = get_node("MessageLabel")
	if message.visible_ratio < 1.0:
		typing += delta
		message.visible_ratio = minf(1.0, typing * 55.0 / maxf(1, message.text.length()))

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		close_menu()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
		var index: int = event.keycode - KEY_1
		var message: Label = get_node("MessageLabel")
		message.visible_ratio = 1.0
		if index < choices.size() and choices[index].visible and not choices[index].disabled: _reply(index)
	else: return
	get_viewport().set_input_as_handled()

func _reply(_index: int) -> void:
	pass

func close_menu() -> void:
	hide()
	speaker_node = null
	voice.stop()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
