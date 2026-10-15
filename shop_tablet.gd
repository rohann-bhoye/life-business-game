extends Node3D

const DISTANCE := 0.9
var ui: CanvasLayer
var source: Panel
var screen_viewport: SubViewport
var screen_menu: Panel
var screen_mesh: MeshInstance3D
var housing: MeshInstance3D
var grips: Array[Node3D] = []
var pairs: Array = []
var screen_size := Vector2.ZERO
var lift := 0.0
var dragging := false
var last_pointer := Vector2.ZERO
var syncing := false
var rest_position := Vector3.ZERO

func configure(owner_ui: CanvasLayer) -> void:
	ui = owner_ui
	source = ui.shop_menu
	name = "ShopTablet"
	_build_device()
	_resize()
	ui._layout()
	# Keep the original nodes and signals as the model; this viewport is their view.
	screen_menu = source.duplicate(0) as Panel
	screen_menu.name = "ShopMenu"
	screen_menu.modulate = Color.WHITE
	screen_viewport.add_child(screen_menu)
	_bind(source, screen_menu)
	for pair in pairs:
		pair[0].mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair[0].focus_mode = Control.FOCUS_NONE
	source.modulate = Color(1, 1, 1, 0)
	source.visibility_changed.connect(_visibility_changed)
	get_viewport().size_changed.connect(_resize)
	_visibility_changed()

func _material(color: Color, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = priority
	return material

func _box(parent: Node3D, node_name: String, size: Vector3, color: Color, priority := 110) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = BoxMesh.new()
	instance.mesh.size = size
	instance.material_override = _material(color, priority)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _build_device() -> void:
	screen_viewport = SubViewport.new()
	screen_viewport.name = "TabletViewport"
	screen_viewport.disable_3d = true
	screen_viewport.gui_disable_input = false
	screen_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(screen_viewport)
	housing = _box(self, "TabletBody", Vector3.ONE, Color(0.075, 0.085, 0.095))
	screen_mesh = MeshInstance3D.new()
	screen_mesh.name = "TabletScreen"
	screen_mesh.mesh = QuadMesh.new()
	screen_mesh.position.z = 0.027
	screen_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := _material(Color.WHITE, 112)
	material.albedo_texture = screen_viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	screen_mesh.material_override = material
	add_child(screen_mesh)
	for side in [-1, 1]:
		var grip := Node3D.new()
		grip.name = "LeftHand" if side == -1 else "RightHand"
		add_child(grip)
		_box(grip, "Palm", Vector3(0.09, 0.19, 0.075), Color(0.72, 0.48, 0.32), 114)
		var thumb := _box(grip, "Thumb", Vector3(0.045, 0.085, 0.035), Color(0.78, 0.54, 0.37), 115)
		thumb.position = Vector3(-side * 0.035, 0.012, 0.055)
		var sleeve := _box(grip, "Sleeve", Vector3(0.12, 0.23, 0.09), Color(0.18, 0.48, 0.78), 113)
		sleeve.position = Vector3(side * 0.035, -0.18, -0.015)
		sleeve.rotation.z = side * 0.16
		grips.append(grip)

func _resize() -> void:
	var camera := get_parent() as Camera3D
	var size := get_viewport().get_visible_rect().size
	var portrait := size.x < size.y
	screen_viewport.size = Vector2i(400, 600) if portrait else Vector2i(840, 600)
	var aspect := size.x / maxf(1, size.y)
	var height := 2.0 * DISTANCE * tan(deg_to_rad(camera.fov) / 2)
	if camera.keep_aspect == Camera3D.KEEP_WIDTH: height /= aspect
	var screen_aspect := float(screen_viewport.size.x) / screen_viewport.size.y
	var screen_height := minf(height * 0.73, height * aspect * 0.83 / screen_aspect)
	screen_size = Vector2(screen_height * screen_aspect, screen_height)
	var rim := minf(0.09, screen_size.x * 0.08)
	housing.mesh.size = Vector3(screen_size.x + rim, screen_size.y + rim, 0.045)
	screen_mesh.mesh.size = screen_size
	for index in range(grips.size()):
		grips[index].scale = Vector3(0.4, 0.7, 0.7) if portrait else Vector3.ONE
		grips[index].position = Vector3((-1 if index == 0 else 1) * (screen_size.x / 2 + rim / 2 + 0.015), -screen_size.y * 0.3, 0.02)
	rotation.x = deg_to_rad(-4)
	scale = Vector3.ONE
	position = Vector3(0, 0, -DISTANCE)
	_fit_device(camera, size, height)
	rest_position = position
	if is_instance_valid(screen_menu):
		ui._layout()
		sync_controls()

func device_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = [housing, screen_mesh]
	for grip in grips:
		for child in grip.get_children():
			if child is MeshInstance3D: meshes.append(child)
	return meshes

func device_pixel_bounds(camera: Camera3D) -> Rect2:
	var bounds := Rect2()
	var first := true
	for mesh in device_meshes():
		var aabb := mesh.get_aabb()
		for index in range(8):
			var pixel := camera.unproject_position(mesh.to_global(aabb.get_endpoint(index)))
			if first:
				bounds = Rect2(pixel, Vector2.ZERO)
				first = false
			else: bounds = bounds.expand(pixel)
	return bounds

func _fit_device(camera: Camera3D, viewport_size: Vector2, view_height: float) -> void:
	# Fit the bezel and both hands, not just the screen quad.
	var safe := Rect2(Vector2(24, 56), viewport_size - Vector2(48, 80))
	for iteration in range(5):
		var bounds := device_pixel_bounds(camera)
		var ratio := minf(1.0, minf(safe.size.x / maxf(1, bounds.size.x), safe.size.y / maxf(1, bounds.size.y)))
		if ratio < 1.0:
			scale *= ratio * 0.98
			bounds = device_pixel_bounds(camera)
		var shift := safe.get_center() - bounds.get_center()
		position.x += shift.x * view_height / viewport_size.y
		position.y -= shift.y * view_height / viewport_size.y

func _bind(original: Control, copy: Control) -> void:
	pairs.append([original, copy])
	if copy is Button:
		copy.pressed.connect(func(): commit_input(); original.pressed.emit())
		if copy.toggle_mode:
			copy.toggled.connect(func(enabled):
				if not syncing: original.button_pressed = enabled)
	elif copy is SpinBox:
		copy.value_changed.connect(func(value):
			if not syncing: original.value = value)
	elif copy is TabBar:
		copy.tab_changed.connect(func(index):
			if not syncing:
				commit_input()
				ui.select_tab(index))
	for child in original.get_children():
		if child is Control:
			var other := copy.get_node_or_null(NodePath(str(child.name))) as Control
			if other != null: _bind(child, other)

func sync_controls() -> void:
	if not is_instance_valid(screen_menu): return
	syncing = true
	screen_menu.theme = source.theme
	for pair in pairs:
		var original: Control = pair[0]
		var copy: Control = pair[1]
		copy.position = original.position
		copy.size = original.size
		copy.visible = original.visible if original != source else true
		if original != source: copy.modulate = original.modulate
		copy.tooltip_text = original.tooltip_text
		copy.add_theme_font_size_override("font_size", original.get_theme_font_size("font_size"))
		if original is Label:
			copy.text = original.text
			copy.label_settings = original.label_settings
			copy.add_theme_font_size_override("font_size", original.get_theme_font_size("font_size"))
		elif original is Button:
			copy.text = original.text
			copy.icon = original.icon
			copy.disabled = original.disabled
			if original.toggle_mode: copy.set_pressed_no_signal(original.button_pressed)
		elif original is SpinBox:
			if not copy.get_line_edit().has_focus(): copy.set_value_no_signal(original.value)
			copy.editable = original.editable
		elif original is TabBar:
			copy.current_tab = original.current_tab
		copy.size = original.size
	syncing = false

func commit_input() -> void:
	if not is_instance_valid(screen_menu): return
	var price := screen_menu.get_node("SalePriceInput") as SpinBox
	price.apply()
	ui.shop.sale_price_input.value = price.value
	# apply() on the hidden model must not restore its old line-edit draft.
	ui.shop.sale_price_input.get_line_edit().text = price.get_line_edit().text
	ui.shop.sale_price_input.apply()

func _visibility_changed() -> void:
	visible = source.visible
	dragging = false
	screen_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if visible:
		lift = 0.0
		sync_controls()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		var focus := screen_viewport.gui_get_focus_owner()
		if focus != null: focus.release_focus()

func close_menu() -> void:
	commit_input()
	ui.shop._on_close_button_pressed()

func screen_point(pointer: Vector2) -> Vector2:
	var camera := get_parent() as Camera3D
	var inverse := global_transform.affine_inverse()
	var origin := inverse * camera.project_ray_origin(pointer)
	var direction := inverse.basis * camera.project_ray_normal(pointer)
	if absf(direction.z) < 0.0001: return Vector2(-1, -1)
	var distance := (screen_mesh.position.z - origin.z) / direction.z
	if distance < 0: return Vector2(-1, -1)
	var hit := origin + direction * distance
	var uv := Vector2(hit.x / screen_size.x + 0.5, 0.5 - hit.y / screen_size.y)
	return uv * Vector2(screen_viewport.size)

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey:
		if event.pressed and event.keycode in [KEY_E, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
			if not event.echo: close_menu()
			get_viewport().set_input_as_handled()
			return
		screen_viewport.push_input(event, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouse:
		var point := screen_point(event.position)
		var inside := Rect2(Vector2.ZERO, Vector2(screen_viewport.size)).has_point(point)
		if inside or dragging:
			var mapped := event.duplicate() as InputEventMouse
			mapped.position = point
			mapped.global_position = point
			if mapped is InputEventMouseMotion: mapped.relative = point - last_pointer
			screen_viewport.push_input(mapped, true)
			last_pointer = point
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed and inside
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible: return
	lift = move_toward(lift, 1, delta * 8)
	position.y = rest_position.y - (1 - lift) * 0.32
	sync_controls()
