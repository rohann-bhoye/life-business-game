extends Panel

const Session := preload("res://game_session.gd")
const SettingsMenu := preload("res://settings_menu.gd")
const UiStyle := preload("res://ui_style.gd")
const KenneyTheme := preload("res://kenney_theme.gd")
var settings_menu: Panel
var form: VBoxContainer
var status: Label
@onready var ui = get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	# Same dark glass look as the lobby, so white text stays readable.
	add_theme_stylebox_override("panel", UiStyle.glass_box(0.9))
	form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 12)
	add_child(form)
	var title := Label.new()
	title.name = "Title"
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_font_override("font", KenneyTheme.heading_font())
	title.add_theme_color_override("font_color", Color.WHITE)
	form.add_child(title)
	var hint := Label.new()
	hint.text = "Game time is stopped"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("94a3b8"))
	form.add_child(hint)
	_button("Resume", close_menu, "PrimaryButton").name = "ResumeButton"
	_button("Settings", _settings).name = "SettingsButton"
	_button("Save & Main Menu", _return_menu, "InfoButton").name = "ReturnButton"
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("fca5a5"))
	form.add_child(status)
	settings_menu = SettingsMenu.new()
	settings_menu.name = "PauseSettingsMenu"
	settings_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	settings_menu.theme = theme
	ui.add_child(settings_menu)
	settings_menu.closed.connect(func(): show())
	get_viewport().size_changed.connect(_layout)
	_layout()

func _button(text: String, action: Callable, variation := "") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.theme_type_variation = variation
	button.pressed.connect(action)
	form.add_child(button)
	return button

func _layout() -> void:
	var width := minf(360, get_viewport().get_visible_rect().size.x - 32)
	form.position = Vector2(24, 22)
	form.size = Vector2(width - 48, 0)
	# Fit the panel to its contents (no empty space at the bottom).
	size = Vector2(width, form.get_combined_minimum_size().y + 44)
	position = (get_viewport().get_visible_rect().size - size) / 2

func open_menu() -> void:
	status.text = ""
	show()
	_layout()
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
		_layout()
		return
	var tree := get_tree()
	tree.paused = false
	var error := Session.launch_menu(tree, tree.current_scene.get_meta("session_save_path", ui.shop.save_path), tree.current_scene.get_meta("session_settings_path", "user://settings.cfg"))
	if error != OK:
		tree.paused = true
		status.text = "Could not open the main menu."
		_layout()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
