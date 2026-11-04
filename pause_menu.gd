extends Panel

const Session := preload("res://game_session.gd")
const SettingsMenu := preload("res://settings_menu.gd")
const UiStyle := preload("res://ui_style.gd")
const KenneyTheme := preload("res://kenney_theme.gd")
const Coop := preload("res://coop.gd")
const Bazaar := preload("res://ui_bazaar.gd")
var settings_menu: Panel
var coop_code: Label
var form: VBoxContainer
var dim: ColorRect
var status: Label
@onready var ui = get_parent()

func _ready() -> void:
	# Co-op never pauses the game, so the menu must work while it runs.
	process_mode = Node.PROCESS_MODE_ALWAYS if Coop.active else Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	# Bright bazaar (ui_bazaar.gd): a cream card with a cartoon outline and a saffron top.
	add_theme_stylebox_override("panel", Bazaar.card())
	# The whole screen dims behind the menu, so the HUD and the name tags step back.
	dim = ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.5)
	dim.show_behind_parent = true
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	add_child(form)
	var title := Label.new()
	title.name = "Title"
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_font_override("font", KenneyTheme.heading_font())
	title.add_theme_color_override("font_color", Bazaar.INK)
	form.add_child(title)
	var hint := Label.new()
	hint.text = "Co-op: the shop keeps running" if Coop.active else "Dholkarpur Gaon  -  game time is stopped"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Bazaar.MUTED)
	form.add_child(hint)
	var rule := ColorRect.new()
	rule.color = Bazaar.LINE
	rule.custom_minimum_size.y = 1
	form.add_child(rule)
	_button("Resume", close_menu, true).name = "ResumeButton"
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
	_button("Unstuck  (stuck or outside the map)", _unstuck).name = "UnstuckButton"
	var leave := _button("Save & Main Menu", _return_menu)
	leave.name = "ReturnButton"
	leave.add_theme_color_override("font_color", Bazaar.PINK)
	var keys := Label.new()
	keys.text = "Esc   Resume"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys.add_theme_font_size_override("font_size", 12)
	keys.add_theme_color_override("font_color", Bazaar.MUTED)
	form.add_child(keys)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("fca5a5"))
	form.add_child(status)
	settings_menu = SettingsMenu.new()
	settings_menu.name = "PauseSettingsMenu"
	settings_menu.process_mode = process_mode
	ui.add_child(settings_menu)
	settings_menu.closed.connect(func(): show())
	get_viewport().size_changed.connect(_layout)
	_layout()

## Closes the menu and moves the player to the nearest free spot, or back into the city when
## outside the map (player_memory.gd; the U key does the same).
func _unstuck() -> void:
	close_menu()
	var memory := ui.get_node_or_null("PlayerMemory")
	if memory != null: memory.unstuck()

func _style(fill: Color, border: Color, width := 1, radius := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style

## A menu row: white with a cartoon outline, warm yellow under the pointer; the first
## (Resume) is saffron (ui_bazaar.gd).
func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	Bazaar.button(button, primary)
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
	dim.position = -position
	dim.size = get_viewport().get_visible_rect().size

func open_menu() -> void:
	status.text = ""
	if is_instance_valid(coop_code):
		var codes := Coop.host_codes()
		coop_code.text = "Co-op code: %s (%s)" % [codes[0][1], codes[0][0]] if not codes.is_empty() else "Co-op code: no network found"
	move_to_front()
	show()
	_layout()
	hide_overlays(ui)
	# In co-op the shop keeps running for your friends while your menu is open.
	if not Coop.active: get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Hides what would draw over a full-screen menu while the game is paused: the hotbar
## (its own layer above the HUD, it covered the settings' buttons) and the quest marker.
## Both show again by themselves once the menu closes and their _process runs.
static func hide_overlays(game_ui: Node) -> void:
	var bar := game_ui.get_node_or_null("InventoryBar")
	if bar != null and bar.layer != null: bar.layer.visible = false
	var quests := game_ui.get_node_or_null("QuestJournal")
	if quests != null and quests.waypoint != null: quests.waypoint.visible = false

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
