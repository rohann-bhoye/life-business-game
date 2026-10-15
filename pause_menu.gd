extends Panel

const Session := preload("res://game_session.gd")
const SettingsMenu := preload("res://settings_menu.gd")
var settings_menu: Panel
var form: VBoxContainer
var status: Label
@onready var ui = get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 12)
	add_child(form)
	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 24)
	form.add_child(title)
	_button("Resume", close_menu).name = "ResumeButton"
	_button("Settings", _settings).name = "SettingsButton"
	_button("Save & Main Menu", _return_menu).name = "ReturnButton"
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(status)
	settings_menu = SettingsMenu.new()
	settings_menu.name = "PauseSettingsMenu"
	settings_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	settings_menu.theme = theme
	ui.add_child(settings_menu)
	settings_menu.closed.connect(func(): show())
	get_viewport().size_changed.connect(_layout)
	_layout()

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	form.add_child(button)
	return button

func _layout() -> void:
	size = Vector2(minf(360, get_viewport().get_visible_rect().size.x - 32), 300)
	position = (get_viewport().get_visible_rect().size - size) / 2
	form.position = Vector2(20, 20)
	form.size = size - Vector2(40, 40)

func open_menu() -> void:
	status.text = ""
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	hide()
	settings_menu.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func is_open() -> bool:
	return visible or settings_menu.visible

func _settings() -> void:
	hide()
	settings_menu.open_menu(get_tree().current_scene.get_meta("session_settings_path", "user://settings.cfg"))

func _return_menu() -> void:
	ui.shop._capture_marketing_time()
	if not ui.shop.business.save_progress():
		status.text = "Could not save. Your game remains open."
		return
	var tree := get_tree()
	tree.paused = false
	var error := Session.launch_menu(tree, tree.current_scene.get_meta("session_save_path", ui.shop.save_path), tree.current_scene.get_meta("session_settings_path", "user://settings.cfg"))
	if error != OK:
		tree.paused = true
		status.text = "Could not open the main menu."

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
