extends Node3D

var active := false
var screen_viewport: SubViewport
var screen_mesh: MeshInstance3D
var screen_menu: Panel
var pairs: Array = []
var syncing := false
var source
var focus_camera: Camera3D
var previous_camera: Camera3D
var transition: Tween
var saved_input: Array = []
var clock: Label
var desktop_theme: Theme
const UiStyle := preload("res://ui_style.gd")
@onready var world = get_tree().current_scene
@onready var player = world.get_node("Player")
@onready var ui = world.get_node("Ui")

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = Color(0.78, 0.82, 0.85)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style

func _ready() -> void:
	call_deferred("_configure")

func _configure() -> void:
	source = ui.supplier_menu
	screen_viewport = SubViewport.new()
	screen_viewport.name = "DesktopViewport"
	screen_viewport.size = Vector2i(960, 540)
	screen_viewport.disable_3d = true
	screen_viewport.gui_embed_subwindows = true
	screen_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(screen_viewport)
	var desktop := ColorRect.new()
	desktop.name = "Desktop"
	desktop.color = UiStyle.PAGE
	desktop.size = Vector2(960, 540)
	screen_viewport.add_child(desktop)
	var topbar := ColorRect.new()
	topbar.name = "TopBar"
	topbar.color = UiStyle.NAVY
	topbar.size = Vector2(960, 64)
	desktop.add_child(topbar)
	var title := Label.new()
	title.text = "APNA OPERATIONS"
	title.position = Vector2(28, 17)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.98, 0.96))
	desktop.add_child(title)
	var status := Label.new()
	status.text = "SYSTEM ONLINE"
	status.position = Vector2(760, 22)
	status.size = Vector2(170, 24)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color(0.5, 0.94, 0.72))
	desktop.add_child(status)
	var welcome := Label.new()
	welcome.text = "Business desk\nOpen Orders or Warehouse staff to manage today."
	welcome.position = Vector2(34, 100)
	welcome.size = Vector2(620, 84)
	welcome.add_theme_font_size_override("font_size", 20)
	welcome.add_theme_color_override("font_color", UiStyle.TEXT)
	desktop.add_child(welcome)
	var cards := [["Orders", "Buy stock and set prices"], ["Team", "Shifts and staff work"], ["Storage", "Delivery and warehouse status"]]
	for index in range(cards.size()):
		var entry = cards[index]
		var card := Panel.new()
		card.add_theme_stylebox_override("panel", UiStyle.card())

		card.position = Vector2(34 + index * 294, 215)
		card.size = Vector2(270, 92)
		desktop.add_child(card)
		var card_title := Label.new()
		card_title.text = entry[0]
		card_title.position = Vector2(14, 12)
		card_title.add_theme_font_size_override("font_size", 18)
		card_title.add_theme_color_override("font_color", UiStyle.BRAND)
		card.add_child(card_title)
		var card_text := Label.new()
		card_text.text = entry[1]
		card_text.position = Vector2(14, 48)
		card_text.add_theme_font_size_override("font_size", 13)
		card_text.add_theme_color_override("font_color", UiStyle.MUTED)
		card.add_child(card_text)
	var taskbar := ColorRect.new()
	taskbar.color = UiStyle.NAVY
	taskbar.position = Vector2(0, 500)
	taskbar.size = Vector2(960, 40)
	desktop.add_child(taskbar)
	for index in range(3):
		var button := Button.new()
		button.text = ["APNA", "Orders", "Warehouse staff"][index]
		button.position = Vector2(12 + index * 180, 504)
		button.size = Vector2(168, 32)
		UiStyle.style_button(button, index == 0)
		desktop.add_child(button)
		button.pressed.connect(func():
			source.tabs.current_tab = 1 if index == 2 else 0
			if index == 2: source.role_input.select(2); source.role_input.item_selected.emit(2))
	clock = Label.new()
	clock.position = Vector2(720, 508)
	clock.size = Vector2(224, 24)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.add_theme_color_override("font_color", Color("e2e8f0"))
	desktop.add_child(clock)
	desktop_theme = Theme.new()
	desktop_theme.default_font_size = 18
	UiStyle.apply(desktop_theme, true)
	screen_menu = source.duplicate(0) as Panel
	screen_menu.name = "OperationsWindow"
	screen_menu.modulate = Color.WHITE
	screen_menu.theme = desktop_theme
	screen_viewport.add_child(screen_menu)
	_bind(source, screen_menu)
	screen_menu.hide()
	screen_mesh = MeshInstance3D.new()
	screen_mesh.name = "LiveScreen"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.78, 0.44)
	screen_mesh.mesh = quad
	screen_mesh.position = Vector3(0, 0.43, 0.125)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = screen_viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	screen_mesh.material_override = material
	screen_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen_mesh)
	var bezel := MeshInstance3D.new()
	bezel.name = "ScreenBezel"
	var bezel_mesh := QuadMesh.new()
	bezel_mesh.size = Vector2(0.84, 0.50)
	bezel.mesh = bezel_mesh
	bezel.position = Vector3(0, 0.43, 0.121)
	var bezel_material := StandardMaterial3D.new()
	bezel_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bezel_material.albedo_color = Color(0.025, 0.035, 0.04)
	bezel.material_override = bezel_material
	bezel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bezel)
	var power_light := MeshInstance3D.new()
	power_light.name = "PowerLight"
	var light_mesh := SphereMesh.new()
	light_mesh.radius = 0.013
	light_mesh.height = 0.026
	power_light.mesh = light_mesh
	power_light.position = Vector3(0.34, 0.165, 0.128)
	var light_material := StandardMaterial3D.new()
	light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light_material.albedo_color = Color(0.25, 0.95, 0.62)
	power_light.material_override = light_material
	power_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(power_light)
	focus_camera = Camera3D.new()
	focus_camera.name = "FocusCamera"
	focus_camera.fov = 45
	focus_camera.near = 0.02
	add_child(focus_camera)
	source.visibility_changed.connect(func():
		if active and not source.visible: close())
	_sync()

func _bind(original: Control, copy: Control) -> void:
	pairs.append([original, copy])
	if copy is OptionButton:
		copy.item_selected.connect(func(index): original.select(index); original.item_selected.emit(index))
	elif copy is ItemList:
		copy.item_selected.connect(func(index): original.select(index); original.item_selected.emit(index))
	elif copy is Button:
		copy.pressed.connect(func(): original.pressed.emit())
		if copy.toggle_mode: copy.toggled.connect(func(value):
			if not syncing: original.button_pressed = value)
	elif copy is SpinBox:
		copy.value_changed.connect(func(value):
			if not syncing: original.value = value)
	elif copy is TabBar:
		copy.tab_changed.connect(func(index):
			if not syncing: original.current_tab = index)
	for child in original.get_children():
		if child is Control:
			var other := copy.get_node_or_null(NodePath(str(child.name))) as Control
			if other != null: _bind(child, other)

func _sync() -> void:
	syncing = true
	clock.text = "Day %d  %02d:%02d" % [ui.shop.business.day, int(ui.shop.business.minutes_of_day) / 60, int(ui.shop.business.minutes_of_day) % 60]
	for pair in pairs:
		var original: Control = pair[0]
		var copy: Control = pair[1]
		copy.visible = original.visible if original != source else active
		copy.position = original.position
		copy.size = original.size
		if original is Label: copy.text = original.text
		elif original is OptionButton:
			if copy.item_count != original.item_count:
				copy.clear()
				for index in range(original.item_count): copy.add_item(original.get_item_text(index), original.get_item_id(index))
			for index in range(original.item_count):
				copy.set_item_text(index, original.get_item_text(index))
				copy.set_item_disabled(index, original.is_item_disabled(index))
			copy.select(original.selected)
		elif original is ItemList:
			var selected: PackedInt32Array = original.get_selected_items()
			if not selected.is_empty(): copy.select(selected[0])
		elif original is Button:
			copy.text = original.text
			copy.disabled = original.disabled
			if original.toggle_mode: copy.set_pressed_no_signal(original.button_pressed)
		elif original is SpinBox:
			if not copy.get_line_edit().has_focus(): copy.set_value_no_signal(original.value)
		elif original is TabBar: copy.current_tab = original.current_tab
		elif original is ProgressBar: copy.value = original.value
		if original.get_parent() == source and is_equal_approx(original.position.x + original.size.x, source.size.x - 16): copy.size.x += 912 - source.size.x
		if copy is Button and not copy is OptionButton:
			# Restyle only when the primary/secondary role changes (button text can change).
			var primary := UiStyle.is_primary(copy)
			if not copy.has_meta("ui_primary") or copy.get_meta("ui_primary") != primary:
				copy.set_meta("ui_primary", primary)
				UiStyle.style_button(copy, primary)
		if copy is Label or copy is Button or copy is TabBar:
			copy.add_theme_constant_override("outline_size", 0)
		if copy is Label:
			copy.add_theme_color_override("font_color", UiStyle.TEXT)
		if copy is Label:
			copy.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
			copy.add_theme_constant_override("shadow_offset_x", 0)
			copy.add_theme_constant_override("shadow_offset_y", 0)
			copy.add_theme_font_size_override("font_size", 18)
	screen_menu.position = Vector2(24, 12)
	screen_menu.size = Vector2(912, 468)
	screen_menu.add_theme_stylebox_override("panel", desktop_theme.get_stylebox("panel", "Panel"))
	var close_button: Button = screen_menu.get_node("CloseButton")
	close_button.position = Vector2(864, 10)
	close_button.text = ""
	close_button.custom_minimum_size = Vector2.ZERO
	close_button.icon = load("res://assets/ui/kenney/close.png")
	close_button.size = Vector2(40, 28)
	close_button.tooltip_text = "Close computer"
	screen_menu.get_node("ShiftLabel").size.x = 108
	screen_menu.get_node("ShiftStartHour").position.x = 130
	var hour_width := (912.0 - 178) / 2
	screen_menu.get_node("ShiftStartHour").size.x = hour_width
	screen_menu.get_node("ShiftEndHour").position.x = 162 + hour_width
	screen_menu.get_node("ShiftEndHour").size.x = hour_width
	screen_menu.get_node("ShiftToLabel").position.x = 134 + hour_width
	syncing = false

func open(warehouse_context := false) -> void:
	if active or player._menu_is_open(): return
	previous_camera = get_viewport().get_camera_3d()
	source.modulate = Color(1, 1, 1, 0)
	source.open_menu(warehouse_context)
	active = true
	source.active_terminal = self
	saved_input.clear()
	for pair in pairs:
		saved_input.append([pair[0], pair[0].mouse_filter, pair[0].focus_mode])
		pair[0].mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair[0].focus_mode = Control.FOCUS_NONE
	focus_camera.global_transform = previous_camera.global_transform
	focus_camera.current = true
	var landscape = world.get_node_or_null("Landscape")
	if landscape != null: landscape.set_camera(focus_camera)
	var target := screen_mesh.global_transform
	target.origin += target.basis.z * 0.7
	transition = create_tween()
	transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transition.tween_property(focus_camera, "global_transform", target, 0.3)
	screen_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sync()

func close() -> void:
	if not active: return
	active = false
	if is_instance_valid(transition): transition.kill()
	for entry in saved_input:
		if is_instance_valid(entry[0]): entry[0].mouse_filter = entry[1]; entry[0].focus_mode = entry[2]
	for pair in pairs:
		if pair[1] is OptionButton: pair[1].get_popup().hide()
	source.active_terminal = null
	source.modulate = Color.WHITE
	source.close_menu()
	if is_instance_valid(previous_camera):
		previous_camera.current = true
		var landscape = world.get_node_or_null("Landscape")
		if landscape != null: landscape.set_camera(previous_camera)
	screen_menu.hide()
	screen_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func screen_point(pixel: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	var normal := screen_mesh.global_basis.z
	var plane := Plane(normal, normal.dot(screen_mesh.global_position))
	var point = plane.intersects_ray(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel))
	if point == null: return Vector2(-1, -1)
	var local: Vector3 = screen_mesh.to_local(point)
	var uv := Vector2(local.x / 0.78 + 0.5, 0.5 - local.y / 0.44)
	return uv * Vector2(screen_viewport.size) if Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv) else Vector2(-1, -1)

func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ESCAPE]: close()
		else:
			var option: OptionButton
			for pair in pairs:
				if pair[1] is OptionButton and pair[1].get_popup().visible: option = pair[1]; break
			if option != null:
				var popup := option.get_popup()
				if event.pressed and event.keycode in [KEY_HOME, KEY_END, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER]:
					var index := popup.get_focused_item()
					if event.keycode == KEY_HOME: index = 0
					elif event.keycode == KEY_END: index = option.item_count - 1
					elif event.keycode == KEY_DOWN: index = mini(index + 1, option.item_count - 1)
					elif event.keycode == KEY_UP: index = maxi(index - 1, 0)
					elif index >= 0 and not option.is_item_disabled(index):
						option.select(index)
						option.item_selected.emit(index)
						popup.hide()
					if index >= 0: popup.set_focused_item(index)
				else: popup.push_input(event, true)
			else: screen_viewport.push_input(event, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouse:
		var point := screen_point(event.position)
		if point.x >= 0:
			var copy = event.duplicate()
			copy.position = point
			copy.global_position = point
			screen_viewport.push_input(copy, true)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if active: _sync()

func _exit_tree() -> void:
	if active and is_instance_valid(source): source.modulate = Color.WHITE; source.active_terminal = null
	pairs.clear()
	saved_input.clear()
