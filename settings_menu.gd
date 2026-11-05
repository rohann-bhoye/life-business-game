extends Panel

# Settings for the lobby and the pause menu, in tabs: Sound, Controls, Gameplay, Graphics
# and Display.
# Graphics shows three picture cards, Low, Medium and High (pictures by
# tools/graphics_thumbnails.gd), with what each one does; "Pick automatically" chooses
# the card that suits this PC. Under High, "Cinematic lighting" is the Highest look
# (game_settings.gd cinematic, the Forward+ renderer): only on strong graphics cards, and
# switching it restarts the game after saving the shop. "Advanced" opens the single
# options; changing one of them makes it a Custom mix.
# The choice itself lives in the hidden `graphics` option (Auto, Low, Medium, High,
# Highest, Custom), so Apply and the saved settings work as before.
signal closed
const Settings := preload("res://game_settings.gd")
const Bazaar := preload("res://ui_bazaar.gd")
## Rows of the hidden quality option that are not a plain preset.
const HIGHEST_ITEM := 4
const CUSTOM_ITEM := 5
const RENDER_SCALES := [0.5, 0.6, 0.75, 0.85, 1.0]
const FPS_LIMITS := [30, 60, 120, 0]
const TABS := ["SOUND", "CONTROLS", "GAMEPLAY", "GRAPHICS", "DISPLAY"]
const LEVELS := [
	{"name": "LOW", "picture": "res://assets/ui/settings/graphics_low.jpg", "line": "Fastest. For laptops and older PCs."},
	{"name": "MEDIUM", "picture": "res://assets/ui/settings/graphics_medium.jpg", "line": "Balanced look and speed."},
	{"name": "HIGH", "picture": "res://assets/ui/settings/graphics_high.jpg", "line": "Best look. Needs a good graphics card."},
]
const PRESET_HELP := [
	"Low: no shadows, light grass, 75% 3D resolution, no clouds, walkers or fog.",
	"Medium: short shadows, medium grass, full resolution, street life on.",
	"High: far shadows, full grass, 4x smooth edges.",
	"High with Cinematic lighting: real sunlight that bounces, fog with light shafts, soft shadows and reflections. The game restarts to switch (your shop is saved first).",
	"Custom: your own mix of the Advanced options.",
]
var settings_path := "user://settings.cfg"
var volume: HSlider
var music: HSlider
var sensitivity: HSlider
var fov: HSlider
## The quality choice (hidden): Auto, Low, Medium, High, Highest, Custom.
var graphics: OptionButton
var preset_help: Label
var auto_pick: CheckButton
var cinematic: CheckButton
var cinematic_help: Label
var cards: Array[PanelContainer] = []
var card_grid: GridContainer
var advanced: VBoxContainer
var advanced_button: Button
var render_scale: OptionButton
var shadows: OptionButton
var grass: OptionButton
var antialias: OptionButton
var effects: CheckButton
var fullscreen: CheckButton
var vsync: CheckButton
var fps_limit: OptionButton
var show_fps: CheckButton
var invert: CheckButton
var day_length: OptionButton
var status: Label
var form: VBoxContainer
var pages := {}
var tab_buttons := {}
var tab_bar: HFlowContainer
var title: Label
var scroll: ScrollContainer
var footer: HBoxContainer
var dim: ColorRect
var detected := 0
var current_tab := "SOUND"

func _ready() -> void:
	hide()
	# The pause menu's look (ui_bazaar.gd): a cream card with a saffron top, outlined
	# buttons, green switches and saffron sliders, over a dimmed screen.
	theme = Bazaar.make_theme()
	add_theme_stylebox_override("panel", Bazaar.card())
	dim = Bazaar.dim()
	add_child(dim)
	title = Label.new()
	title.name = "Title"
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_font_override("font", preload("res://kenney_theme.gd").heading_font())
	add_child(title)
	tab_bar = HFlowContainer.new()
	tab_bar.name = "Tabs"
	tab_bar.add_theme_constant_override("h_separation", 6)
	tab_bar.add_theme_constant_override("v_separation", 6)
	add_child(tab_bar)
	var group := ButtonGroup.new()
	for name in TABS:
		var tab := Button.new()
		tab.name = name.capitalize() + "Tab"
		tab.text = name.capitalize()
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(96, 36)
		tab.add_theme_font_size_override("font_size", 15)
		tab.pressed.connect(_show_tab.bind(name))
		tab_bar.add_child(tab)
		tab_buttons[name] = tab
	scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	for name in TABS:
		var page := VBoxContainer.new()
		page.name = name.capitalize() + "Page"
		page.add_theme_constant_override("separation", 8)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(page)
		pages[name] = page
	form = pages.SOUND
	volume = _slider("Master volume", 0, 100, 1, "%")
	music = _slider("Music volume", 0, 100, 1, "%")
	form = pages.CONTROLS
	sensitivity = _slider("Look sensitivity", 1, 10, 0.5)
	fov = _slider("Camera FOV", 50, 90, 1, String.chr(176))
	invert = _check("Invert vertical look")
	form = pages.GAMEPLAY
	day_length = _choice("Day length", ["Fast (6 min)", "Normal (9 min)", "Relaxed (12 min)"])
	_help("How long the shop day (8 AM to 8 PM) lasts in real time.")
	form = pages.GRAPHICS
	_build_graphics()
	form = pages.DISPLAY
	fullscreen = _check("Fullscreen")
	vsync = _check("VSync (no tearing)")
	fps_limit = _choice("FPS limit", ["30", "60", "120", "Unlimited"])
	show_fps = _check("Show FPS")
	status = Label.new()
	status.name = "Status"
	status.add_theme_font_size_override("font_size", 13)
	add_child(status)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	add_child(footer)
	var apply := Button.new()
	apply.name = "ApplyButton"
	apply.text = "Apply"
	apply.custom_minimum_size.y = 44
	apply.add_theme_font_size_override("font_size", 17)
	apply.theme_type_variation = "PrimaryButton"
	apply.focus_mode = Control.FOCUS_NONE
	apply.pressed.connect(_apply)
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(apply)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.custom_minimum_size.y = 44
	back.add_theme_font_size_override("font_size", 17)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close_menu)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(back)
	_show_tab(current_tab)
	get_viewport().size_changed.connect(_layout)
	_layout()

## The Graphics tab: auto switch, the three picture cards, what the choice does, the
## Cinematic switch and the Advanced options.
func _build_graphics() -> void:
	graphics = OptionButton.new()
	graphics.name = "GraphicsPreset"
	for item in ["Auto", "Low", "Medium", "High", "Highest", "Custom"]: graphics.add_item(item)
	graphics.visible = false
	graphics.item_selected.connect(_on_preset)
	add_child(graphics)
	auto_pick = _check("Pick automatically for this PC")
	auto_pick.toggled.connect(_on_auto)
	card_grid = GridContainer.new()
	card_grid.name = "QualityCards"
	card_grid.columns = 3
	card_grid.add_theme_constant_override("h_separation", 10)
	card_grid.add_theme_constant_override("v_separation", 10)
	form.add_child(card_grid)
	for index in range(LEVELS.size()): cards.append(_card(index))
	preset_help = _help("")
	preset_help.name = "PresetHelp"
	cinematic = _check("Cinematic lighting (High only)")
	cinematic.toggled.connect(_on_cinematic)
	cinematic_help = _help("")
	advanced_button = Button.new()
	advanced_button.name = "AdvancedButton"
	advanced_button.text = "Advanced options  +"
	advanced_button.focus_mode = Control.FOCUS_NONE
	advanced_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	advanced_button.add_theme_font_size_override("font_size", 15)
	advanced_button.pressed.connect(func(): _show_advanced(not advanced.visible))
	form.add_child(advanced_button)
	advanced = VBoxContainer.new()
	advanced.name = "Advanced"
	advanced.add_theme_constant_override("separation", 8)
	advanced.visible = false
	form.add_child(advanced)
	var page := form
	form = advanced
	render_scale = _choice("3D resolution", RENDER_SCALES.map(func(value): return "%d%%" % roundi(value * 100)))
	shadows = _choice("Shadows", ["Off", "Short", "Far"])
	grass = _choice("Grass", ["Off", "Light", "Medium", "Full"])
	antialias = _choice("Smooth edges", ["Off", "2x", "4x"])
	effects = _check("Street life, clouds and fog")
	form = page
	for option in [render_scale, shadows, grass, antialias]: option.item_selected.connect(func(_index): _make_custom())
	effects.toggled.connect(func(_on): _make_custom())

## One quality card: the town picture at that level, its name and a line; click to pick.
func _card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = LEVELS[index].name.capitalize() + "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _pick_level(index))
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.texture = load(LEVELS[index].picture)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.custom_minimum_size = Vector2(0, 108)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(picture)
	var name_row := HBoxContainer.new()
	name_row.name = "NameRow"
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_row)
	var heading := Label.new()
	heading.name = "Name"
	heading.text = LEVELS[index].name
	heading.add_theme_font_override("font", preload("res://kenney_theme.gd").heading_font())
	heading.add_theme_font_size_override("font_size", 18)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(heading)
	var badge := Label.new()
	badge.name = "Badge"
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Bazaar.GREEN_DEEP)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(badge)
	var line := Label.new()
	line.name = "Line"
	line.text = LEVELS[index].line
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 13)
	line.add_theme_color_override("font_color", Bazaar.MUTED)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)
	card_grid.add_child(card)
	return card

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	form.add_child(label)
	return label

## A muted line of help under a setting.
func _help(text: String) -> Label:
	var help := _label(text, 13)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Bazaar.MUTED)
	return help

## The setting's name with its value on the right, and the slider underneath. The value
## always shows (also at 0, which never fires value_changed).
func _slider(title_text: String, minimum: float, maximum: float, step: float, unit := "") -> HSlider:
	var row := HBoxContainer.new()
	form.add_child(row)
	var label := Label.new()
	label.text = title_text
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var amount := Label.new()
	amount.name = "Value"
	amount.add_theme_font_size_override("font_size", 15)
	amount.add_theme_color_override("font_color", Bazaar.SAFFRON_DEEP)
	row.add_child(amount)
	var slider := HSlider.new()
	slider.name = title_text.replace(" ", "") + "Slider"
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size.y = 26
	slider.focus_mode = Control.FOCUS_NONE
	var show := func(value: float): amount.text = ("%d%s" % [roundi(value), unit]) if step >= 1.0 else "%.1f%s" % [value, unit]
	slider.value_changed.connect(show)
	show.call(slider.value)
	form.add_child(slider)
	return slider

## A row with the setting's name on the left and `control` on the right.
func _row(title_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 36
	form.add_child(row)
	var label := Label.new()
	label.text = title_text
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	control.add_theme_font_size_override("font_size", 15)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if control is OptionButton: control.get_popup().add_theme_font_size_override("font_size", 15)
	row.add_child(control)

func _choice(title_text: String, items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.name = title_text.replace(" ", "") + "Option"
	for item in items: option.add_item(item)
	option.custom_minimum_size = Vector2(170, 36)
	option.focus_mode = Control.FOCUS_NONE
	_row(title_text, option)
	return option

func _check(title_text: String) -> CheckButton:
	var check := CheckButton.new()
	check.name = title_text.replace(" ", "").replace(",", "").replace("(", "").replace(")", "") + "Check"
	check.focus_mode = Control.FOCUS_NONE
	_row(title_text, check)
	return check

func _show_tab(name: String) -> void:
	current_tab = name
	for key in pages: pages[key].visible = key == name
	for key in tab_buttons: tab_buttons[key].set_pressed_no_signal(key == name)
	scroll.scroll_vertical = 0
	_layout()

func _show_advanced(open: bool) -> void:
	advanced.visible = open
	advanced_button.text = "Advanced options  " + ("-" if open else "+")
	_layout()

func _layout() -> void:
	if not is_instance_valid(footer): return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(820, viewport_size.x - 32)
	var narrow := width < 600
	card_grid.columns = 1 if narrow else 3
	for card in cards: card.get_node("Column/Picture").custom_minimum_size.y = 84 if narrow else 108
	var inner := width - 64
	for key in pages: pages[key].custom_minimum_size.x = inner
	# The tab row wraps on narrow screens; its height from the buttons (the flow container
	# does not know it before it has been laid out once).
	var rows := 1
	var run := 0.0
	for key in TABS:
		var wide: float = tab_buttons[key].get_combined_minimum_size().x + 6.0
		if run > 0.0 and run + wide > width - 48: 
			rows += 1
			run = 0.0
		run += wide
	var tabs_height := rows * 36.0 + (rows - 1) * 6.0
	var top := 24 + 40 + tabs_height + 12
	var content: float = pages[current_tab].get_combined_minimum_size().y
	var height := minf(viewport_size.y - 32, top + content + 120)
	height = maxf(height, minf(viewport_size.y - 32, 420))
	size = Vector2(width, height)
	position = (viewport_size - size) / 2
	title.position = Vector2(24, 20)
	tab_bar.position = Vector2(24, 64)
	tab_bar.size = Vector2(width - 48, tabs_height)
	scroll.position = Vector2(24, top)
	scroll.size = Vector2(width - 40, maxf(60, height - top - 120))
	status.position = Vector2(24, height - 98)
	status.size = Vector2(width - 48, 22)
	footer.position = Vector2(24, height - 66)
	footer.size = Vector2(width - 48, 44)
	Bazaar.cover(dim, self)

func open_menu(path: String) -> void:
	settings_path = path
	var settings = Settings.new()
	settings.load_file(path)
	detected = settings.detected_quality()
	volume.value = settings.volume * 100
	music.value = settings.music_volume * 100
	sensitivity.value = settings.sensitivity * 1000
	fov.value = settings.fov
	graphics.select(_item_for(settings))
	auto_pick.text = ""
	auto_pick.get_parent().get_child(0).text = "Pick automatically for this PC (%s)" % LEVELS[detected].name.capitalize()
	# Cinematic only on cards that can carry it (it froze an MX110 laptop).
	var strong: bool = Settings.can_run_cinematic()
	cinematic.disabled = not strong
	cinematic_help.text = "Real sunlight that bounces, fog with light shafts, soft shadows and reflections. The game restarts to switch (your shop is saved first)." if strong else "Needs a GTX 1660 / RTX graphics card or better; not available on this PC."
	_show_options(settings.options())
	_refresh_graphics()
	fullscreen.set_pressed_no_signal(settings.fullscreen)
	vsync.set_pressed_no_signal(settings.vsync)
	fps_limit.select(maxi(0, FPS_LIMITS.find(settings.max_fps)))
	show_fps.set_pressed_no_signal(settings.show_fps)
	invert.set_pressed_no_signal(settings.invert_y)
	day_length.select(settings.day_length)
	status.text = "Graphics card: %s" % RenderingServer.get_video_adapter_name()
	status.add_theme_color_override("font_color", Bazaar.MUTED)
	status.tooltip_text = status.text
	status.clip_text = true
	_show_tab(current_tab)
	# Drawn above everything else in its layer (the HUD, name tags, the lobby).
	move_to_front()
	show()
	_layout()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Fills the option rows with a preset's (or the custom) values without signals.
func _show_options(chosen: Dictionary) -> void:
	var nearest := 0
	for index in range(RENDER_SCALES.size()):
		if absf(RENDER_SCALES[index] - chosen.render_scale) < absf(RENDER_SCALES[nearest] - chosen.render_scale): nearest = index
	render_scale.select(nearest)
	shadows.select(chosen.shadows)
	grass.select(chosen.grass)
	antialias.select(chosen.antialias)
	effects.set_pressed_no_signal(chosen.effects)

## The quality level (0 Low, 1 Medium, 2 High) the current choice shows, or -1 for Custom.
func _level() -> int:
	match graphics.selected:
		0: return detected
		HIGHEST_ITEM: return 2
		CUSTOM_ITEM: return -1
	return graphics.selected - 1

func _pick_level(index: int) -> void:
	graphics.select(HIGHEST_ITEM if index == 2 and cinematic.button_pressed else index + 1)
	_on_preset(graphics.selected)

func _on_auto(on: bool) -> void:
	if on: graphics.select(0)
	else: graphics.select(_level() + 1 if _level() >= 0 else detected + 1)
	_on_preset(graphics.selected)

func _on_cinematic(on: bool) -> void:
	if on: graphics.select(HIGHEST_ITEM)
	elif graphics.selected == HIGHEST_ITEM: graphics.select(3)
	_on_preset(graphics.selected)

func _on_preset(index: int) -> void:
	if index != CUSTOM_ITEM: _show_options(Settings.PRESETS[detected if index == 0 else mini(index - 1, 2)])
	_refresh_graphics()

func _make_custom() -> void:
	graphics.select(CUSTOM_ITEM)
	_refresh_graphics()

## Cards, switches and the help line follow the choice in `graphics`.
func _refresh_graphics() -> void:
	var level := _level()
	auto_pick.set_pressed_no_signal(graphics.selected == 0)
	cinematic.set_pressed_no_signal(graphics.selected == HIGHEST_ITEM)
	for index in range(cards.size()):
		var chosen := index == level
		var style := Bazaar.box(Bazaar.HOVER if chosen else Bazaar.CARD, 4 if chosen else 2, 10, Bazaar.SAFFRON if chosen else Bazaar.LINE)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		cards[index].add_theme_stylebox_override("panel", style)
		var badge: Label = cards[index].get_node("Column/NameRow/Badge")
		badge.text = "BEST FOR THIS PC" if index == detected else ""
	match graphics.selected:
		0: preset_help.text = "Auto picks %s for this PC. %s" % [LEVELS[detected].name.capitalize(), PRESET_HELP[detected]]
		HIGHEST_ITEM: preset_help.text = PRESET_HELP[3]
		CUSTOM_ITEM: preset_help.text = PRESET_HELP[4]
		_: preset_help.text = PRESET_HELP[graphics.selected - 1]
	if graphics.selected == CUSTOM_ITEM and not advanced.visible: _show_advanced(true)

func _apply() -> void:
	var settings = Settings.new()
	# Keep anything the menu does not show (this file may hold more than the rows).
	settings.load_file(settings_path)
	var was_cinematic: bool = settings.cinematic
	settings.volume = volume.value / 100
	settings.music_volume = music.value / 100
	settings.sensitivity = sensitivity.value / 1000
	settings.fov = fov.value
	settings.graphics = [-1, 0, 1, 2, 2, Settings.CUSTOM][graphics.selected]
	settings.render_scale = RENDER_SCALES[render_scale.selected]
	settings.shadows = shadows.selected
	settings.grass = grass.selected
	settings.antialias = antialias.selected
	settings.effects = effects.button_pressed
	settings.fullscreen = fullscreen.button_pressed
	settings.vsync = vsync.button_pressed
	settings.max_fps = FPS_LIMITS[fps_limit.selected]
	settings.show_fps = show_fps.button_pressed
	settings.invert_y = invert.button_pressed
	settings.day_length = day_length.selected
	settings.cinematic = graphics.selected == HIGHEST_ITEM
	# Restart only when the choice changed (a card that cannot run Forward+ falls back to
	# Standard by itself; it must not restart on every Apply).
	var restart: bool = settings.cinematic != was_cinematic
	if not settings.save_file(settings_path):
		status.text = "Could not save settings."
		status.add_theme_color_override("font_color", Bazaar.RED_DEEP)
		return
	if restart:
		_restart(settings)
		return
	settings.apply_global()
	var player = get_tree().current_scene.get_node_or_null("Player")
	if is_instance_valid(player): settings.apply_player(player)
	close_menu()

## The other look needs the other renderer: write it, save the shop, and start again.
func _restart(settings) -> void:
	if not settings.write_renderer():
		status.text = "Could not switch %s Cinematic lighting (the renderer file was not written)." % ("on" if settings.cinematic else "off")
		status.add_theme_color_override("font_color", Bazaar.RED_DEEP)
		return
	var shop = get_tree().current_scene.get_node_or_null("Shop/ShopArea")
	if shop != null and "business" in shop and shop.business != null: shop.business.save_progress()
	if settings.cinematic: Settings.start_highest_trial()
	else: Settings.finish_highest_trial()
	status.text = "Restarting with Cinematic lighting %s..." % ("on" if settings.cinematic else "off")
	OS.set_restart_on_exit(true)
	get_tree().quit()

## The hidden option's row for these settings: Highest when Cinematic lighting is on.
func _item_for(settings) -> int:
	if settings.cinematic: return HIGHEST_ITEM
	return CUSTOM_ITEM if settings.graphics == Settings.CUSTOM else settings.graphics + 1

func close_menu() -> void:
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
