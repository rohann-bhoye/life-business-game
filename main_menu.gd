extends Control

const Session := preload("res://game_session.gd")
const LoadingScreen := preload("res://loading_screen.gd")
const Settings := preload("res://game_settings.gd")
const SettingsMenu := preload("res://settings_menu.gd")
const MenuSkin := preload("res://menu_skin.gd")
const Coop := preload("res://coop.gd")
const CoopMenu := preload("res://coop_menu.gd")
@export var save_path := "user://business_save.json"
@export var settings_path := "user://settings.cfg"
var continue_button: Button
var new_button: Button
var save_label: Label
var status_label: Label
var content: VBoxContainer
var settings_menu: Panel
var coop_menu: Panel
var how_to_play: Control
var confirmation: Panel
var footer: Label
var version_label: Label
var lobby_panel: Panel
var news_panel: Panel
var launching := false
const GAME_SCENE := "res://main.tscn.tscn"

const KenneyTheme := preload("res://kenney_theme.gd")
const CREDITS := "Made by Bucketstudy team"
const VERSION := "Development Demo | v0.10"
const WHATS_NEW := ["Co-op: run one shop with up to 3 friends", "Indian town: mandir, pani puri cart, cows", "Thick grass, block paths and a home yard", "Graphics presets, 3D resolution, FPS counter", "Longer days: a relaxed 12-minute shop day", "Street lamps glow at night on every setting"]

## Lobby look: Kenney buttons (green / blue / grey / red) on dark glass panels,
## white labels, dark text on grey buttons.
static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 18
	MenuSkin.apply(result)
	result.set_color("font_color", "Label", Color(0.95, 0.97, 0.98))
	for type in ["CheckButton"]:
		result.set_color("font_color", type, Color(0.95, 0.97, 0.98))
	result.set_stylebox("panel", "Panel", glass_box())
	return result

static func glass_box(alpha := 0.82) -> StyleBoxFlat:
	return preload("res://ui_style.gd").glass_box(alpha)


func _ready() -> void:
	if not ResourceLoader.has_cached(GAME_SCENE): ResourceLoader.load_threaded_request(GAME_SCENE, "", true)
	get_tree().root.content_scale_size = Vector2i.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = make_theme()
	var settings = Settings.new()
	settings.load_file(settings_path)
	settings.apply_global()
	preload("res://background_music.gd").ensure(get_tree())
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
	_build_slots()
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
	var coop := _button(content, "Co-op", _open_coop)
	coop.name = "CoopButton"
	_button(content, "How to Play", func(): how_to_play.open()).name = "HowToPlayButton"
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
	how_to_play = preload("res://how_to_play.gd").new()
	add_child(how_to_play)
	settings_menu = SettingsMenu.new()
	settings_menu.name = "SettingsMenu"
	add_child(settings_menu)
	settings_menu.closed.connect(func(): content.show())
	coop_menu = CoopMenu.new()
	coop_menu.name = "CoopMenu"
	coop_menu.lobby = self
	add_child(coop_menu)
	coop_menu.closed.connect(func(): content.show())
	_build_confirmation()
	content.minimum_size_changed.connect(_layout)
	content.visibility_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_refresh_save()
	# Back from a co-op game: make sure the connection is closed and say why it ended.
	if Coop.active: Coop.leave(get_tree())
	if not Coop.last_message.is_empty():
		status_label.text = Coop.last_message
		Coop.last_message = ""
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
	var title := _label(confirmation, "New game: choose difficulty", 24)
	title.name = "Title"
	title.position = Vector2(20, 20)
	var message := _label(confirmation, "", 15)
	message.name = "Message"
	message.position = Vector2(20, 60)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.clip_text = true
	# Normal keeps the old ConfirmButton name.
	var rupee := String.chr(8377)
	var choices := [["EasyButton", "Aasaan - %s15,000" % rupee, 0, "PrimaryButton"], ["ConfirmButton", "Normal - %s10,000" % rupee, 1, "InfoButton"], ["HardButton", "Mushkil - %s6,000" % rupee, 2, "DangerButton"]]
	for index in range(choices.size()):
		var choice: Array = choices[index]
		var button := _button(confirmation, choice[1], _new_game.bind(choice[2]))
		button.name = choice[0]
		button.theme_type_variation = choice[3]
		button.position = Vector2(20, 132 + index * 52)
	var cancel := _button(confirmation, "Cancel", _cancel_new)
	cancel.position = Vector2(20, 296)

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
	# Small windows: tighter spacing, shorter buttons, no tagline, so everything fits.
	content.add_theme_constant_override("separation", 6 if compact else 10)
	content.get_node("Tagline").visible = not compact
	for child in content.get_children():
		if child is Button: child.custom_minimum_size.y = 36 if compact else 44
	content.size = Vector2(minf(360, viewport_size.x - 48), content.get_combined_minimum_size().y)
	content.position = Vector2(24 if compact else 64, maxf(24, (viewport_size.y - content.get_combined_minimum_size().y) / 2))
	# Glass panel behind the menu column (skipped on very small screens).
	lobby_panel.visible = not compact and content.visible
	lobby_panel.position = content.position - Vector2(28, 24)
	lobby_panel.size = content.size + Vector2(56, 48)
	# News card only when there is room beside the menu.
	news_panel.visible = viewport_size.x >= 900 and viewport_size.y >= 560 and content.visible
	var items: Label = news_panel.get_node("Items")
	var width := minf(380, viewport_size.x - 520)
	items.size = Vector2(width - 40, 0)
	# Grow with the list so longer news never spills out of the card.
	news_panel.size = Vector2(width, minf(viewport_size.y - 96, 72 + items.get_combined_minimum_size().y))
	news_panel.position = Vector2(viewport_size.x - news_panel.size.x - 48, 48)
	items.size = Vector2(width - 40, news_panel.size.y - 64)
	footer.position = Vector2(24 if compact else 64, viewport_size.y - 36)
	footer.size = Vector2(maxf(0, viewport_size.x - 48), 26)
	version_label.size = Vector2(260, 22)
	version_label.position = Vector2(viewport_size.x - 284, viewport_size.y - 32)
	version_label.visible = viewport_size.x >= 700
	confirmation.size = Vector2(minf(460, viewport_size.x - 32), 360)
	confirmation.position = (viewport_size - confirmation.size) / 2
	for child in confirmation.get_children():
		child.size.x = confirmation.size.x - 40
	confirmation.get_node("Message").size.y = 68

# --- Save slots: slot 1 is the original save file, slots 2 and 3 add "_2"/"_3". ---
const SLOTS := 3
var base_save_path := ""
var slot := 1
var slot_buttons: Array[Button] = []

static func slot_path(base: String, number: int) -> String:
	return base if number <= 1 else "%s_%d.%s" % [base.get_basename(), number, base.get_extension()]

func _lobby_config_path() -> String:
	return settings_path.get_base_dir().path_join("lobby.cfg")

func _build_slots() -> void:
	# Coming back from a game passes that slot's path: recover the base and slot.
	base_save_path = save_path
	for number in range(2, SLOTS + 1):
		var suffix := "_%d.%s" % [number, save_path.get_extension()]
		if save_path.ends_with(suffix):
			base_save_path = save_path.trim_suffix(suffix) + "." + save_path.get_extension()
			slot = number
	if slot == 1:
		var config := ConfigFile.new()
		if config.load(_lobby_config_path()) == OK: slot = clampi(int(config.get_value("lobby", "slot", 1)), 1, SLOTS)
	var row := HBoxContainer.new()
	row.name = "SlotRow"
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	for number in range(1, SLOTS + 1):
		var button := Button.new()
		button.name = "Slot%d" % number
		button.text = "SLOT %d" % number
		button.custom_minimum_size.y = 36
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(select_slot.bind(number))
		row.add_child(button)
		slot_buttons.append(button)
	select_slot(slot, false)

func select_slot(number: int, remember := true) -> void:
	if launching: return
	slot = clampi(number, 1, SLOTS)
	save_path = slot_path(base_save_path, slot)
	for index in range(slot_buttons.size()):
		slot_buttons[index].theme_type_variation = "PrimaryButton" if index + 1 == slot else ""
	if remember:
		var config := ConfigFile.new()
		config.load(_lobby_config_path())
		config.set_value("lobby", "slot", slot)
		config.save(_lobby_config_path())
	if is_instance_valid(save_label): _refresh_save()

func _refresh_save() -> void:
	var summary := Session.save_summary(save_path)
	continue_button.disabled = not summary.valid
	# Without a save, New Game is the main (green) action.
	new_button.theme_type_variation = "InfoButton" if summary.valid else "PrimaryButton"
	if summary.valid:
		var state = summary.state
		save_label.text = "Slot %d  |  Day %d  |  %02d:%02d\nMoney %s%s  |  Stock %d" % [slot, state.day, int(state.minutes_of_day) / 60, int(state.minutes_of_day) % 60, String.chr(8377), str(state.money), state.stock]
		continue_button.tooltip_text = state.save_status
	else:
		save_label.text = ("Slot %d is empty\nStart a New Game here" % slot) if not FileAccess.file_exists(save_path) else ("Slot %d: save unavailable\nNew Game will archive it." % slot)
	_layout()

func _continue() -> void:
	if launching: return
	_refresh_save()
	if continue_button.disabled: return
	var state = Session.save_summary(save_path).state
	_start_game("Continue  |  Slot %d  |  Day %d  |  %s%s" % [slot, state.day, String.chr(8377), _money(state.money)], "Welcome back! Day %d, %02d:%02d. Good luck today." % [state.day, int(state.minutes_of_day) / 60, int(state.minutes_of_day) % 60])

func _request_new() -> void:
	if launching: return
	# Always choose a difficulty; an old save in this slot is archived, not deleted.
	var has_save := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak") or FileAccess.file_exists(save_path + ".recovered")
	confirmation.get_node("Message").text = "Aasaan: patient customers, bigger budgets. Mushkil: impatient customers, tight budgets." + ("\nYour current save here is archived, not deleted." if has_save else "\nYou start with one free cold-drink fridge.")
	content.hide()
	confirmation.show()
	_layout()

func _new_game(difficulty := 1) -> void:
	if launching: return
	var error := Session.new_game(save_path, difficulty, not Coop.active)
	if not error.is_empty():
		_cancel_new()
		status_label.text = error
		return
	_start_game("New shop  |  Slot %d  |  Day 1  |  %s%s  |  %s" % [slot, String.chr(8377), _money(Session.Backend.DIFFICULTY_MONEY[difficulty]), Session.Backend.DIFFICULTY_NAMES[difficulty]], "Welcome to your new shop in Dholkarpur Gaon! Follow the First Day guide to get started.", "", not Coop.active)

static func _money(value: int) -> String:
	var digits := str(absi(value))
	var result := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0: result += ","
		result += digits[index]
	return ("-" if value < 0 else "") + result

# The game scene loads on a background thread from the moment the menu opens; the
# loading screen shows that progress, covers the scene change and waits for a key.
func _start_game(summary: String, greeting: String, game_path := "", play_intro := false) -> void:
	launching = true
	status_label.text = "Loading game..."
	var tree := get_tree()
	var path := game_path if not game_path.is_empty() else save_path
	var settings := settings_path
	var loading = LoadingScreen.new()
	tree.root.add_child(loading)
	loading.failed.connect(func():
		launching = false
		if Coop.active: Coop.leave(tree)
		status_label.text = "Could not start the game.")
	loading.begin(func(): return Session.launch_game(tree, path, settings), summary, greeting, play_intro)

func _cancel_new() -> void:
	confirmation.hide()
	content.show()
	# Cancelled hosting a co-op game on an old slot: stop hosting.
	if Coop.active and not launching: Coop.leave(get_tree())

# --- Co-op (coop_menu.gd picks host or join; these launch the game) ---

func _open_coop() -> void:
	if launching: return
	content.hide()
	coop_menu.open_menu()

## Hosting runs this slot's shop: continue it, or start a new one in an empty slot.
func start_coop_host() -> void:
	Coop.menu_save_path = save_path
	content.show()
	_refresh_save()
	if not continue_button.disabled: _continue()
	else: _request_new()

## A friend plays in a temporary save of their own (their slots stay untouched);
## sharing the host's shop comes in the next co-op phase.
func start_coop_client(address: String) -> void:
	Coop.menu_save_path = save_path
	var path := settings_path.get_base_dir().path_join("coop_friend_save.json")
	for suffix in ["", ".bak", ".tmp", ".recovered", ".recovered.bak"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	var error := Session.new_game(path)
	if not error.is_empty():
		Coop.leave(get_tree())
		content.show()
		status_label.text = error
		return
	_start_game("Co-op  |  Joining %s" % address, "You joined your friend's shop! Walk over and say hi.", path)

func _open_settings() -> void:
	content.hide()
	settings_menu.open_menu(settings_path)

func _input(event: InputEvent) -> void:
	if confirmation.visible and event.is_action_pressed("ui_cancel"):
		_cancel_new()
		get_viewport().set_input_as_handled()
