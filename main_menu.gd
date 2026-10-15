extends Control

const Session := preload("res://game_session.gd")
const Settings := preload("res://game_settings.gd")
const SettingsMenu := preload("res://settings_menu.gd")
const MenuSkin := preload("res://menu_skin.gd")
@export var save_path := "user://business_save.json"
@export var settings_path := "user://settings.cfg"
var continue_button: Button
var new_button: Button
var save_label: Label
var status_label: Label
var content: VBoxContainer
var settings_menu: Panel
var confirmation: Panel
var footer: Label
var launching := false
var waiting_for_game := false
const GAME_SCENE := "res://main.tscn.tscn"

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 18
	MenuSkin.apply(result)
	for type in ["Label", "Button", "OptionButton", "CheckButton"]:
		result.set_color("font_color", type, Color(0.95, 0.97, 0.98))
		result.set_color("font_disabled_color", type, Color(0.48, 0.54, 0.55))
	return result

func _ready() -> void:
	if not ResourceLoader.has_cached(GAME_SCENE): ResourceLoader.load_threaded_request(GAME_SCENE, "", true)
	get_tree().root.content_scale_size = Vector2i.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = make_theme()
	var settings = Settings.new()
	settings.load_file(settings_path)
	settings.apply_global()
	var background := TextureRect.new()
	background.name = "ShopBackground"
	background.texture = load("res://assets/ui/main_menu_shop_v2.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.3)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = VBoxContainer.new()
	content.name = "MainActions"
	content.add_theme_constant_override("separation", 12)
	add_child(content)
	var title := _label(content, "Life Business\nGame", 48)
	title.name = "GameTitle"
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	save_label = _label(content, "", 16)
	save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	continue_button = _button(content, "Continue", _continue)
	continue_button.name = "ContinueButton"
	continue_button.add_theme_stylebox_override("normal", MenuSkin.surface("active", Color(0.85, 0.72, 0.86)))
	new_button = _button(content, "New Game", _request_new)
	new_button.name = "NewGameButton"
	_button(content, "Settings", _open_settings).name = "SettingsButton"
	_button(content, "Quit", func(): get_tree().quit()).name = "QuitButton"
	status_label = _label(content, "", 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer = _label(self, "Development Demo", 14)
	settings_menu = SettingsMenu.new()
	settings_menu.name = "SettingsMenu"
	add_child(settings_menu)
	settings_menu.closed.connect(func(): content.show())
	_build_confirmation()
	content.minimum_size_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_refresh_save()
	_layout()

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_confirmation() -> void:
	confirmation = Panel.new()
	confirmation.name = "NewGameConfirmation"
	add_child(confirmation)
	confirmation.hide()
	var title := _label(confirmation, "Start a new game?", 24)
	title.position = Vector2(20, 20)
	var message := _label(confirmation, "Start with %s50,000.\nYour current save will be archived,\nnot deleted." % String.chr(8377), 16)
	message.name = "Message"
	message.position = Vector2(20, 64)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.clip_text = true
	var start := _button(confirmation, "Start new game", _new_game)
	start.name = "ConfirmButton"
	start.position = Vector2(20, 146)
	var cancel := _button(confirmation, "Cancel", _cancel_new)
	cancel.position = Vector2(20, 202)

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 640 or viewport_size.y < 560
	var title: Label = content.get_node("GameTitle")
	var font_size := 32 if compact else 48
	if title.get_theme_font_size("font_size") != font_size: title.add_theme_font_size_override("font_size", font_size)
	content.size = Vector2(minf(360, viewport_size.x - 48), content.get_combined_minimum_size().y)
	content.position = Vector2(24 if compact else 64, maxf(24, (viewport_size.y - content.get_combined_minimum_size().y) / 2))
	footer.position = Vector2(24 if compact else 64, viewport_size.y - 30)
	confirmation.size = Vector2(minf(420, viewport_size.x - 32), 262)
	confirmation.position = (viewport_size - confirmation.size) / 2
	for child in confirmation.get_children():
		child.size.x = confirmation.size.x - 40
	confirmation.get_node("Message").size.y = 68

func _refresh_save() -> void:
	var summary := Session.save_summary(save_path)
	continue_button.disabled = not summary.valid
	if summary.valid: new_button.remove_theme_stylebox_override("normal")
	else: new_button.add_theme_stylebox_override("normal", MenuSkin.surface("active", Color(0.85, 0.72, 0.86)))
	if summary.valid:
		var state = summary.state
		save_label.text = "Last save: Day %d | %02d:%02d\n%s%s | Stock: %d" % [state.day, int(state.minutes_of_day) / 60, int(state.minutes_of_day) % 60, String.chr(8377), str(state.money), state.stock]
		continue_button.tooltip_text = state.save_status
	else:
		save_label.text = "No saved game" if not FileAccess.file_exists(save_path) else "Save unavailable; New Game will archive it."
	_layout()

func _continue() -> void:
	if launching: return
	_refresh_save()
	if continue_button.disabled: return
	_start_game()

func _request_new() -> void:
	if launching: return
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak") or FileAccess.file_exists(save_path + ".recovered"):
		content.hide()
		confirmation.show()
		_layout()
	else: _new_game()

func _new_game() -> void:
	if launching: return
	var error := Session.new_game(save_path)
	if not error.is_empty():
		_cancel_new()
		status_label.text = error
		return
	_start_game()

func _start_game() -> void:
	launching = true
	waiting_for_game = true
	status_label.text = "Loading game..."

# The game scene loads on a background thread from the moment the menu opens,
# so Continue/New Game show progress instead of freezing the window.
func _process(_delta: float) -> void:
	if not waiting_for_game: return
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		status_label.text = "Loading game... %d%%" % int(100.0 * float(progress[0]))
		return
	waiting_for_game = false
	if status == ResourceLoader.THREAD_LOAD_LOADED: ResourceLoader.load_threaded_get(GAME_SCENE)
	var error := Session.launch_game(get_tree(), save_path, settings_path)
	if error != OK:
		launching = false
		status_label.text = "Could not start the game."

func _cancel_new() -> void:
	confirmation.hide()
	content.show()

func _open_settings() -> void:
	content.hide()
	settings_menu.open_menu(settings_path)

func _input(event: InputEvent) -> void:
	if confirmation.visible and event.is_action_pressed("ui_cancel"):
		_cancel_new()
		get_viewport().set_input_as_handled()
