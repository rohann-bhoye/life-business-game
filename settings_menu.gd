extends Panel

# Settings for the lobby and the pause menu: Sound, Controls, Gameplay, Graphics and
# Display.
# Graphics has a preset (Auto, Low, Normal, High) with a line saying what it does,
# and the options it sets underneath; changing any of them makes the preset Custom.
signal closed
const Settings := preload("res://game_settings.gd")
const Bazaar := preload("res://ui_bazaar.gd")
const RENDER_SCALES := [0.5, 0.6, 0.75, 0.85, 1.0]
const FPS_LIMITS := [30, 60, 120, 0]
const PRESET_HELP := [
	"Fastest: no shadows, light grass, 75% 3D resolution, no clouds, walkers or fog.",
	"Balanced: short shadows, medium grass, full resolution, street life on.",
	"Best look: far shadows, full grass, 4x smooth edges.",
	"Your own mix of the options below.",
]
var settings_path := "user://settings.cfg"
var volume: HSlider
var music: HSlider
var sensitivity: HSlider
var fov: HSlider
var graphics: OptionButton
var preset_help: Label
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
var scroll: ScrollContainer
var footer: HBoxContainer
var dim: ColorRect
var detected := 0

func _ready() -> void:
	hide()
	# The pause menu's look (ui_bazaar.gd): a cream card with a saffron top, outlined
	# buttons, green switches and saffron sliders, over a dimmed screen.
	theme = Bazaar.make_theme()
	add_theme_stylebox_override("panel", Bazaar.card())
	dim = Bazaar.dim()
	add_child(dim)
	scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	var title := _label("SETTINGS", 26)
	title.add_theme_font_override("font", preload("res://kenney_theme.gd").heading_font())
	title.name = "Title"
	var hint := _label("Changes take effect when you press Apply.", 13)
	hint.add_theme_color_override("font_color", Bazaar.MUTED)
	_section("SOUND")
	volume = _slider("Master volume", 0, 100, 1, "%")
	music = _slider("Music volume", 0, 100, 1, "%")
	_section("CONTROLS")
	sensitivity = _slider("Look sensitivity", 1, 10, 0.5)
	fov = _slider("Camera FOV", 50, 90, 1, String.chr(176))
	invert = _check("Invert vertical look")
	_section("GAMEPLAY")
	day_length = _choice("Day length", ["Fast (6 min)", "Normal (9 min)", "Relaxed (12 min)"])
	_help("How long the shop day (8 AM to 8 PM) lasts in real time.")
	_section("GRAPHICS")
	graphics = _choice("Preset", ["Auto", "Low", "Normal", "High", "Custom"])
	graphics.name = "GraphicsPreset"
	graphics.item_selected.connect(_on_preset)
	preset_help = _help("")
	preset_help.name = "PresetHelp"
	render_scale = _choice("3D resolution", RENDER_SCALES.map(func(value): return "%d%%" % roundi(value * 100)))
	shadows = _choice("Shadows", ["Off", "Short", "Far"])
	grass = _choice("Grass", ["Off", "Light", "Medium", "Full"])
	antialias = _choice("Smooth edges", ["Off", "2x", "4x"])
	effects = _check("Street life, clouds and fog")
	for option in [render_scale, shadows, grass, antialias]: option.item_selected.connect(func(_index): _make_custom())
	effects.toggled.connect(func(_on): _make_custom())
	_section("DISPLAY")
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
	get_viewport().size_changed.connect(_layout)
	_layout()

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

## A small saffron heading with a thin line, between groups of settings.
func _section(text: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	form.add_child(gap)
	var heading := _label(text, 14)
	heading.add_theme_font_override("font", preload("res://kenney_theme.gd").heading_font())
	heading.add_theme_color_override("font_color", Bazaar.SAFFRON_DEEP)
	var line := ColorRect.new()
	line.color = Bazaar.LINE
	line.custom_minimum_size.y = 2
	form.add_child(line)

## The setting's name with its value on the right, and the slider underneath. The value
## always shows (also at 0, which never fires value_changed).
func _slider(title: String, minimum: float, maximum: float, step: float, unit := "") -> HSlider:
	var row := HBoxContainer.new()
	form.add_child(row)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var amount := Label.new()
	amount.name = "Value"
	amount.add_theme_font_size_override("font_size", 15)
	amount.add_theme_color_override("font_color", Bazaar.SAFFRON_DEEP)
	row.add_child(amount)
	var slider := HSlider.new()
	slider.name = title.replace(" ", "") + "Slider"
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
func _row(title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 36
	form.add_child(row)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	control.add_theme_font_size_override("font_size", 15)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if control is OptionButton: control.get_popup().add_theme_font_size_override("font_size", 15)
	row.add_child(control)

func _choice(title: String, items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.name = title.replace(" ", "") + "Option"
	for item in items: option.add_item(item)
	option.custom_minimum_size = Vector2(170, 36)
	option.focus_mode = Control.FOCUS_NONE
	_row(title, option)
	return option

func _check(title: String) -> CheckButton:
	var check := CheckButton.new()
	check.name = title.replace(" ", "").replace(",", "") + "Check"
	check.focus_mode = Control.FOCUS_NONE
	_row(title, check)
	return check

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(460, viewport_size.x - 32)
	var height := minf(viewport_size.y - 32, form.get_combined_minimum_size().y + 132)
	size = Vector2(width, height)
	position = (viewport_size - size) / 2
	scroll.position = Vector2(24, 24)
	scroll.size = Vector2(width - 40, height - 132)
	form.custom_minimum_size.x = width - 64
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
	graphics.select(settings.graphics + 1)
	graphics.set_item_text(0, "Auto (%s)" % Settings.PRESET_NAMES[detected])
	_show_options(settings.options())
	_update_help()
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
	scroll.scroll_vertical = 0
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

func _on_preset(index: int) -> void:
	if index <= Settings.CUSTOM: _show_options(Settings.PRESETS[detected if index == 0 else index - 1])
	_update_help()

func _make_custom() -> void:
	graphics.select(Settings.CUSTOM + 1)
	_update_help()

func _update_help() -> void:
	var index := graphics.selected
	if index == 0: preset_help.text = "Auto chooses %s for this PC. %s" % [Settings.PRESET_NAMES[detected], PRESET_HELP[detected]]
	else: preset_help.text = PRESET_HELP[index - 1]

func _apply() -> void:
	var settings = Settings.new()
	settings.volume = volume.value / 100
	settings.music_volume = music.value / 100
	settings.sensitivity = sensitivity.value / 1000
	settings.fov = fov.value
	settings.graphics = graphics.selected - 1
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
	if not settings.save_file(settings_path):
		status.text = "Could not save settings."
		status.add_theme_color_override("font_color", Bazaar.RED_DEEP)
		return
	settings.apply_global()
	var player = get_tree().current_scene.get_node_or_null("Player")
	if is_instance_valid(player): settings.apply_player(player)
	close_menu()

func close_menu() -> void:
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
