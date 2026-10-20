extends Panel

const Session := preload("res://game_session.gd")
const SettingsMenu := preload("res://settings_menu.gd")
const UiStyle := preload("res://ui_style.gd")
const KenneyTheme := preload("res://kenney_theme.gd")
const Coop := preload("res://coop.gd")
var settings_menu: Panel
var coop_code: Label
var form: VBoxContainer
var status: Label
@onready var ui = get_parent()

func _ready() -> void:
	# Co-op never pauses the game, so the menu must work while it runs.
	process_mode = Node.PROCESS_MODE_ALWAYS if Coop.active else Node.PROCESS_MODE_WHEN_PAUSED
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
	hint.text = "Co-op: the shop keeps running" if Coop.active else "Game time is stopped"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("94a3b8"))
	form.add_child(hint)
	_button("Resume", close_menu, "PrimaryButton").name = "ResumeButton"
	if Coop.hosting:
		coop_code = Label.new()
		coop_code.name = "CoopCode"
		coop_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coop_code.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		coop_code.add_theme_font_size_override("font_size", 15)
		coop_code.add_theme_color_override("font_color", Color("fde68a"))
		form.add_child(coop_code)
		# Codes are read when used: the internet code arrives a few seconds after hosting.
		var copy := _button("Copy co-op code", func():
			var codes := Coop.host_codes()
			if codes.is_empty(): return
			DisplayServer.clipboard_set(codes[0][1])
			status.text = "Code copied. Send it to your friends!"
			_layout())
		copy.name = "CopyCoopCode"
	_button("How to Play", func(): ui.get_node("HowToPlay").open()).name = "HowToPlayButton"
	_button("Settings", _settings).name = "SettingsButton"
	_button("Save & Main Menu", _return_menu, "InfoButton").name = "ReturnButton"
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("fca5a5"))
	form.add_child(status)
	settings_menu = SettingsMenu.new()
	settings_menu.name = "PauseSettingsMenu"
	settings_menu.process_mode = process_mode
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
	if is_instance_valid(coop_code):
		var codes := Coop.host_codes()
		coop_code.text = "Co-op code: %s (%s)" % [codes[0][1], codes[0][0]] if not codes.is_empty() else "Co-op code: no network found"
	show()
	_layout()
	# In co-op the shop keeps running for your friends while your menu is open.
	if not Coop.active: get_tree().paused = true
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
	# Hosting co-op: boxes friends are holding go back to the bay before saving.
	var coop_world := get_tree().current_scene.get_node_or_null("CoopWorld")
	if Coop.hosting and coop_world != null: coop_world.return_friend_boxes()
	if not ui.shop.business.save_progress():
		status.text = "Could not save. Your game remains open."
		_layout()
		return
	var tree := get_tree()
	tree.paused = false
	var menu_path: String = tree.current_scene.get_meta("session_save_path", ui.shop.save_path)
	# Leaving co-op disconnects (friends see "left the shop") and returns to your slot.
	if Coop.active:
		if not Coop.menu_save_path.is_empty(): menu_path = Coop.menu_save_path
		Coop.leave(tree)
	var error := Session.launch_menu(tree, menu_path, tree.current_scene.get_meta("session_settings_path", "user://settings.cfg"))
	if error != OK:
		tree.paused = true
		status.text = "Could not open the main menu."
		_layout()

func _input(event: InputEvent) -> void:
	# The guide on top closes first.
	var help := ui.get_node_or_null("HowToPlay")
	if help != null and help.visible: return
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
