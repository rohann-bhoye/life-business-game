extends Panel

signal closed
const Settings := preload("res://game_settings.gd")
const MenuSkin := preload("res://menu_skin.gd")
var settings_path := "user://settings.cfg"
var volume: HSlider
var sensitivity: HSlider
var fov: HSlider
var graphics: OptionButton
var fullscreen: CheckButton
var invert: CheckButton
var status: Label
var form: VBoxContainer
var scroll: ScrollContainer
var footer: HBoxContainer

func _ready() -> void:
	hide()
	# Dark glass panel (lobby style) so the white labels are readable everywhere.
	add_theme_stylebox_override("panel", preload("res://ui_style.gd").glass_box(0.92))
	scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	var title := _label("SETTINGS", 26)
	title.add_theme_font_override("font", preload("res://kenney_theme.gd").heading_font())
	title.name = "Title"
	volume = _slider("Volume", 0, 100, 1)
	sensitivity = _slider("Look sensitivity", 1, 10, 0.5)
	fov = _slider("Camera FOV", 50, 90, 1)
	_label("Graphics", 16)
	graphics = OptionButton.new()
	graphics.name = "GraphicsPreset"
	for preset in ["Auto (device)", "Low (Fast)", "Balanced", "High"]: graphics.add_item(preset)
	graphics.custom_minimum_size.y = 32
	form.add_child(graphics)
	fullscreen = CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98))
	form.add_child(fullscreen)
	invert = CheckButton.new()
	invert.text = "Invert vertical look"
	invert.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98))
	form.add_child(invert)
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

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(400, viewport_size.x - 32)
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
	volume.value = settings.volume * 100
	sensitivity.value = settings.sensitivity * 1000
	fov.value = settings.fov
	graphics.select(settings.graphics + 1)
	fullscreen.set_pressed_no_signal(settings.fullscreen)
	invert.set_pressed_no_signal(settings.invert_y)
	status.text = "%s | Auto: %s" % [RenderingServer.get_video_adapter_name(), ["Low", "Balanced", "High"][settings.detected_quality()]]
	status.tooltip_text = status.text
	status.clip_text = true
	show()
	_layout()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _apply() -> void:
	var settings = Settings.new()
	settings.volume = volume.value / 100
	settings.sensitivity = sensitivity.value / 1000
	settings.fov = fov.value
	settings.graphics = graphics.selected - 1
	settings.fullscreen = fullscreen.button_pressed
	settings.invert_y = invert.button_pressed
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
