extends Panel

# Settings for the lobby and the pause menu: Sound, Controls, Gameplay, Graphics and
# Display.
# Graphics has a preset (Auto, Low, Normal, High) with a line saying what it does,
# and the options it sets underneath; changing any of them makes the preset Custom.
signal closed
const Settings := preload("res://game_settings.gd")
const MenuSkin := preload("res://menu_skin.gd")
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
var detected := 0

func _ready() -> void:
	hide()
	# Dark glass panel (lobby style) so the white labels are readable everywhere.
	add_theme_stylebox_override("panel", preload("res://ui_style.gd").glass_box(0.92))
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
	_section("SOUND")
	volume = _slider("Master volume", 0, 100, 1)
	music = _slider("Music volume", 0, 100, 1)
	_section("CONTROLS")
	sensitivity = _slider("Look sensitivity", 1, 10, 0.5)
	fov = _slider("Camera FOV", 50, 90, 1)
	invert = _check("Invert vertical look")
	_section("GAMEPLAY")
	day_length = _choice("Day length", ["Fast (6 min)", "Normal (9 min)", "Relaxed (12 min)"])
	var day_help := Label.new()
	day_help.text = "How long the shop day (8 AM to 8 PM) lasts in real time."
	day_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	day_help.add_theme_font_size_override("font_size", 13)
	day_help.add_theme_color_override("font_color", Color(0.72, 0.8, 0.86))
	form.add_child(day_help)
	_section("GRAPHICS")
	graphics = _choice("Preset", ["Auto", "Low", "Normal", "High", "Custom"])
	graphics.name = "GraphicsPreset"
	graphics.item_selected.connect(_on_preset)
	preset_help = Label.new()
	preset_help.name = "PresetHelp"
	preset_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preset_help.add_theme_font_size_override("font_size", 13)
	preset_help.add_theme_color_override("font_color", Color(0.72, 0.8, 0.86))
	form.add_child(preset_help)
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
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color("86efac"))
	add_child(status)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	add_child(footer)
	var apply := Button.new()
	apply.text = "Apply"
	apply.icon = MenuSkin.texture("checkmark", 16)
	apply.custom_minimum_size.y = 40
	apply.theme_type_variation = "PrimaryButton"
	apply.pressed.connect(_apply)
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(apply)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size.y = 40
	back.pressed.connect(close_menu)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(back)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98))
	form.add_child(label)
	return label

## A small coloured heading with a thin line, between groups of settings.
func _section(text: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	form.add_child(gap)
	var heading := _label(text, 14)
	heading.add_theme_color_override("font_color", Color("fbbf24"))
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.14)
	line.custom_minimum_size.y = 1
	form.add_child(line)

func _slider(title: String, minimum: float, maximum: float, step: float) -> HSlider:
	var label := _label(title, 16)
	var slider := HSlider.new()
	slider.name = title.replace(" ", "") + "Slider"
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size.y = 20
	slider.value_changed.connect(func(value): label.text = "%s: %s" % [title, str(value)])
	form.add_child(slider)
	return slider

## A row with the setting's name on the left and `control` on the right. Rows use
## the plain label font (the pixel button font has no "%" and shouts in capitals).
func _row(title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	form.add_child(row)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var font := label.get_theme_font("font")
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", 15)
	if control is OptionButton:
		control.get_popup().add_theme_font_override("font", font)
		control.get_popup().add_theme_font_size_override("font_size", 15)
	row.add_child(control)

func _choice(title: String, items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.name = title.replace(" ", "") + "Option"
	for item in items: option.add_item(item)
	option.custom_minimum_size = Vector2(150, 32)
	_row(title, option)
	return option

func _check(title: String) -> CheckButton:
	var check := CheckButton.new()
	check.name = title.replace(" ", "").replace(",", "") + "Check"
	_row(title, check)
	return check

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(440, viewport_size.x - 32)
	var height := minf(viewport_size.y - 32, form.get_combined_minimum_size().y + 128)
	size = Vector2(width, height)
	position = (viewport_size - size) / 2
	scroll.position = Vector2(20, 20)
	scroll.size = Vector2(width - 40, height - 128)
	form.custom_minimum_size.x = width - 56
	status.position = Vector2(20, height - 92)
	status.size = Vector2(width - 40, 24)
	footer.position = Vector2(20, height - 60)
	footer.size = Vector2(width - 40, 40)

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
	status.tooltip_text = status.text
	status.clip_text = true
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
