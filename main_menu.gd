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
var version_label: Label
var lobby_panel: Panel
var news_panel: Panel
var launching := false
var waiting_for_game := false
const GAME_SCENE := "res://main.tscn.tscn"

const KenneyTheme := preload("res://kenney_theme.gd")
const CREDITS := "Made by Bucketstudy team"
const VERSION := "Development Demo | v0.6"
const WHATS_NEW := ["Your own family home with a bedroom, kitchen and TV", "APNA Wholesale online store on the shop PC", "Grow tomatoes, carrots, cabbage, corn and apples", "Hire Kiran to run the farm for you", "Customers now buy mixed baskets", "End-of-day report and reputation bonus"]

## Lobby look: Kenney buttons (green / blue / grey / red) on dark glass panels,
## white labels, dark text on grey buttons.
static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 18
	MenuSkin.apply(result)
	result.set_color("font_color", "Label", Color(0.95, 0.97, 0.98))
	result.set_type_variation("InfoButton", "Button")
	result.set_stylebox("normal", "InfoButton", KenneyTheme.button_box("blue"))
	result.set_stylebox("hover", "InfoButton", KenneyTheme.button_box("green"))
	for state in ["font_color", "font_hover_color", "font_focus_color"]: result.set_color(state, "InfoButton", Color.WHITE)
	for type in ["CheckButton"]:
		result.set_color("font_color", type, Color(0.95, 0.97, 0.98))
	result.set_stylebox("panel", "Panel", glass_box())
	return result

static func glass_box(alpha := 0.82) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, alpha)
	style.set_corner_radius_all(16)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.12)
	style.shadow_size = 12
	style.shadow_color = Color(0, 0, 0, 0.35)
	return style

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
	# Dark on the left (behind the menu), clear on the right so the street shows.
	var shade := TextureRect.new()
	shade.name = "LobbyShade"
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.04, 0.08, 0.86))
	gradient.set_color(1, Color(0.02, 0.04, 0.08, 0.05))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0, 0.5)
	shade_texture.fill_to = Vector2(0.75, 0.5)
	shade.texture = shade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lobby_panel = Panel.new()
	lobby_panel.name = "LobbyPanel"
	lobby_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lobby_panel)
	news_panel = _build_news()
	content = VBoxContainer.new()
	content.name = "MainActions"
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	var title := _label(content, "LIFE BUSINESS\nGAME", 48)
	title.name = "GameTitle"
	title.add_theme_font_override("font", KenneyTheme.heading_font())
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	var tagline := _label(content, "Run your shop. Build your life.", 17)
	tagline.name = "Tagline"
	tagline.add_theme_color_override("font_color", Color("4ade80"))
	save_label = _label(content, "", 15)
	save_label.name = "SaveCard"
	save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var card := glass_box(0.55)
	card.set_corner_radius_all(10)
	card.content_margin_left = 12
	card.content_margin_right = 12
	card.content_margin_top = 8
	card.content_margin_bottom = 8
	card.shadow_size = 0
	save_label.add_theme_stylebox_override("normal", card)
	continue_button = _button(content, "Continue", _continue)
	continue_button.name = "ContinueButton"
	continue_button.theme_type_variation = "PrimaryButton"
	new_button = _button(content, "New Game", _request_new)
	new_button.name = "NewGameButton"
	new_button.theme_type_variation = "InfoButton"
	_button(content, "Settings", _open_settings).name = "SettingsButton"
	var quit := _button(content, "Quit", func(): get_tree().quit())
	quit.name = "QuitButton"
	quit.theme_type_variation = "DangerButton"
	status_label = _label(content, "", 14)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer = _label(self, CREDITS, 16)
	footer.name = "Credits"
	footer.add_theme_font_override("font", KenneyTheme.heading_font())
	footer.add_theme_color_override("font_color", Color("fde68a"))
	version_label = _label(self, VERSION, 13)
	version_label.name = "Version"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	settings_menu = SettingsMenu.new()
	settings_menu.name = "SettingsMenu"
	add_child(settings_menu)
	settings_menu.closed.connect(func(): content.show())
	_build_confirmation()
	content.minimum_size_changed.connect(_layout)
	content.visibility_changed.connect(_layout)
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

## "What's new" card on the right, like a game launcher's news feed.
func _build_news() -> Panel:
	var panel := Panel.new()
	panel.name = "WhatsNew"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var heading := _label(panel, "WHAT'S NEW", 20)
	heading.name = "Heading"
	heading.add_theme_font_override("font", KenneyTheme.heading_font())
	heading.add_theme_color_override("font_color", Color("4ade80"))
	heading.position = Vector2(20, 16)
	var list := _label(panel, "", 15)
	list.name = "Items"
	list.text = "\n".join(WHATS_NEW.map(func(item): return "-  " + item))
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.position = Vector2(20, 52)
	return panel

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 640 or viewport_size.y < 560
	var title: Label = content.get_node("GameTitle")
	var font_size := 30 if compact else 44
	if title.get_theme_font_size("font_size") != font_size: title.add_theme_font_size_override("font_size", font_size)
	content.size = Vector2(minf(360, viewport_size.x - 48), content.get_combined_minimum_size().y)
	content.position = Vector2(24 if compact else 64, maxf(24, (viewport_size.y - content.get_combined_minimum_size().y) / 2))
	# Glass panel behind the menu column (skipped on very small screens).
	lobby_panel.visible = not compact and content.visible
	lobby_panel.position = content.position - Vector2(28, 24)
	lobby_panel.size = content.size + Vector2(56, 48)
	# News card only when there is room beside the menu.
	news_panel.visible = viewport_size.x >= 900 and viewport_size.y >= 560 and content.visible
	news_panel.size = Vector2(minf(380, viewport_size.x - 520), 300)
	news_panel.position = Vector2(viewport_size.x - news_panel.size.x - 48, 48)
	news_panel.get_node("Items").size = Vector2(news_panel.size.x - 40, news_panel.size.y - 64)
	footer.position = Vector2(24 if compact else 64, viewport_size.y - 36)
	footer.size = Vector2(maxf(0, viewport_size.x - 48), 26)
	version_label.size = Vector2(260, 22)
	version_label.position = Vector2(viewport_size.x - 284, viewport_size.y - 32)
	version_label.visible = viewport_size.x >= 700
	confirmation.size = Vector2(minf(420, viewport_size.x - 32), 262)
	confirmation.position = (viewport_size - confirmation.size) / 2
	for child in confirmation.get_children():
		child.size.x = confirmation.size.x - 40
	confirmation.get_node("Message").size.y = 68

func _refresh_save() -> void:
	var summary := Session.save_summary(save_path)
	continue_button.disabled = not summary.valid
	# Without a save, New Game is the main (green) action.
	new_button.theme_type_variation = "InfoButton" if summary.valid else "PrimaryButton"
	if summary.valid:
		var state = summary.state
		save_label.text = "Last save: Day %d  |  %02d:%02d\nMoney %s%s  |  Stock %d" % [state.day, int(state.minutes_of_day) / 60, int(state.minutes_of_day) % 60, String.chr(8377), str(state.money), state.stock]
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
