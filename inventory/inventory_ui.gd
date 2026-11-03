class_name InventoryUI
extends CanvasLayer
## Full 3D inventory screen. Add it to any scene, assign `inventory`, press I / Tab.
##
##   var ui := InventoryUI.new()
##   ui.inventory = my_inventory
##   add_child(ui)

signal item_used(item: ItemData, slot_index: int)
signal item_dropped(item: ItemData, amount: int, slot_index: int)
signal hotbar_returned(slot: int)
signal opened
signal closed

@export var inventory: Inventory:
	set = set_inventory
@export var columns: int = 6
@export var title_text: String = "INVENTORY"
@export var toggle_keys: Array[Key] = [KEY_I, KEY_TAB]
@export var max_weight: float = 60.0
## Weight carried outside the grid (the hotbar), added to the weight bar.
var extra_weight := 0.0
@export var pause_game_when_open: bool = false
@export var start_open: bool = false
## Size of the whole window (1.0 = full size).
@export var ui_scale: float = 0.72

const C_PANEL := Color("12161f")
const C_PANEL_BORDER := Color("2b3343")
const C_STAGE := Color("0b0e14")
const C_ACCENT := Color("e9b44c")
const C_TEXT := Color("e7eaf0")
const C_MUTED := Color("8b94a7")
const C_DANGER := Color("e5636b")

var is_open := false
var selected_index := -1

var _root: Control
var _window: PanelContainer
var _stage: Control
var _grid: GridContainer
var _slots: Array[InventorySlotUI] = []
var _subtitle: Label
var _preview_vp: SubViewport
var _preview_pivot: Node3D
var _preview_cam: Camera3D
var _preview_light: OmniLight3D
var _empty_hint: Label
var _name_label: Label
var _meta_label: Label
var _desc_label: Label
var _stat_values := {}
var _weight_label: Label
var _weight_bar: ProgressBar
var _weight_fill: StyleBoxFlat
var _use_btn: Button
var _split_btn: Button
var _drop_btn: Button

var _shown_item: ItemData
var _yaw := 0.6
var _pitch := 0.0
var _zoom := 4.4
var _cam_dist := 4.4
var _dragging := false
var _idle := 10.0
var _time := 0.0
var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _tween: Tween


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	if inventory == null:
		inventory = Inventory.new()
	_build()
	_rebuild_slots()
	_root.visible = false
	set_process(false)
	if start_open:
		open()


# ---------------------------------------------------------------- public API

func set_inventory(inv: Inventory) -> void:
	if inventory != null and inventory.slot_changed.is_connected(_on_slot_changed):
		inventory.slot_changed.disconnect(_on_slot_changed)
	inventory = inv
	if inventory != null:
		inventory.slot_changed.connect(_on_slot_changed)
	if is_node_ready():
		_rebuild_slots()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	_root.visible = true
	set_process(true)
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if pause_game_when_open:
		get_tree().paused = true
	for s in _slots:
		s.refresh_render()
	if selected_index < 0 or inventory.get_item(selected_index) == null:
		select_slot(_first_filled())
	_animate(true)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	Input.mouse_mode = _prev_mouse_mode
	if pause_game_when_open:
		get_tree().paused = false
	_animate(false)
	closed.emit()


func select_slot(i: int) -> void:
	if selected_index >= 0 and selected_index < _slots.size():
		_slots[selected_index].selected = false
	selected_index = i
	if i >= 0 and i < _slots.size():
		_slots[i].selected = true
	_show_selected()


func use_slot(i: int) -> void:
	var item := inventory.get_item(i)
	if item == null:
		return
	item_used.emit(item, i)
	if item.consumable:
		inventory.remove_at(i, 1)


func drop_slot(i: int) -> void:
	var item := inventory.get_item(i)
	if item == null:
		return
	var amount := inventory.get_count(i)
	item_dropped.emit(item, amount, i)
	inventory.remove_at(i, amount)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k in toggle_keys:
			toggle()
			get_viewport().set_input_as_handled()
		elif is_open and k == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_idle = 0.0
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - 0.25, 1.8, 5.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + 0.25, 1.8, 5.0)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_yaw += mm.relative.x * 0.012
		_pitch = clampf(_pitch + mm.relative.y * 0.01, -1.2, 1.2)
		_idle = 0.0


## Window scale that keeps it fully on screen and clear of the hotbar strip.
func _fit() -> float:
	var view := get_viewport().get_visible_rect().size
	var window_size := _window.get_combined_minimum_size()
	return minf(ui_scale, minf((view.y - 110.0) / window_size.y, (view.x - 40.0) / window_size.x))

## The window is a plain child of `_stage`, centred by hand: a container would reset its
## scale to 1 every time it re-laid out, which showed as a one-frame flash of a huge window.
func _place_window() -> void:
	var fit := _fit()
	_window.size = _window.get_combined_minimum_size()
	_window.pivot_offset = _window.size * 0.5
	_window.scale = Vector2.ONE * fit
	_window.position = ((_stage.size - _window.size) * 0.5).floor()

func _process(delta: float) -> void:
	_place_window()
	_time += delta
	if not _dragging:
		_idle += delta
		if _idle > 1.2:
			_yaw += delta * 0.7
			_pitch = lerpf(_pitch, 0.0, delta * 1.5)
	_preview_pivot.rotation = Vector3(_pitch, _yaw, 0)
	_preview_pivot.position.y = sin(_time * 1.6) * 0.04
	_cam_dist = lerpf(_cam_dist, _zoom, minf(1.0, delta * 8.0))
	_preview_cam.position = Vector3(0, _cam_dist * 0.22, _cam_dist)
	_preview_cam.look_at(Vector3(0, -0.05, 0))


# ---------------------------------------------------------------- slots

func _rebuild_slots() -> void:
	if _grid == null:
		return
	for s in _slots:
		s.queue_free()
	_slots.clear()
	selected_index = -1
	_grid.columns = columns
	for i in inventory.size:
		var slot := InventorySlotUI.new()
		slot.index = i
		_grid.add_child(slot)
		slot.clicked.connect(_on_slot_clicked)
		slot.drop_requested.connect(_on_slot_drop)
		slot.set_data(inventory.get_item(i), inventory.get_count(i))
		_slots.append(slot)
	_update_footer()
	_show_selected()


func _on_slot_changed(i: int) -> void:
	if i < 0 or i >= _slots.size():
		return
	_slots[i].set_data(inventory.get_item(i), inventory.get_count(i))
	_update_footer()
	if i == selected_index:
		_show_selected()


func _on_slot_clicked(i: int, button: int, double_click: bool) -> void:
	select_slot(i)
	if button == MOUSE_BUTTON_RIGHT or double_click:
		use_slot(i)


func _on_slot_drop(from_i: int, to_i: int, split: bool) -> void:
	# A negative source is a hotbar slot (-1 = slot 1 ...): the item goes back to the grid.
	if from_i < 0:
		hotbar_returned.emit(-from_i - 1)
		return
	if split:
		inventory.split_stack(from_i, to_i)
	else:
		inventory.move(from_i, to_i)
	select_slot(to_i)


func _first_filled() -> int:
	for i in inventory.size:
		if inventory.get_item(i) != null:
			return i
	return -1


# ---------------------------------------------------------------- details panel

func _show_selected() -> void:
	if _name_label == null:
		return
	var item := inventory.get_item(selected_index)
	if item != _shown_item:
		_shown_item = item
		for c in _preview_pivot.get_children():
			_preview_pivot.remove_child(c)
			c.queue_free()
		if item != null:
			var model := PreviewStage.make_model(item)
			_preview_pivot.add_child(model)
			model.scale = Vector3.ONE * 0.55
			var t := create_tween()
			t.tween_property(model, "scale", Vector3.ONE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_idle = 10.0
			_zoom = 4.4
	_empty_hint.visible = item == null
	var has := item != null
	_use_btn.disabled = not has
	_drop_btn.disabled = not has
	_split_btn.disabled = not has or inventory.get_count(selected_index) < 2 or inventory.first_empty() < 0
	if not has:
		_name_label.text = "Nothing selected"
		_name_label.add_theme_color_override("font_color", C_MUTED)
		_meta_label.text = ""
		_desc_label.text = "Click an item to inspect it."
		for k in _stat_values:
			(_stat_values[k] as Label).text = "—"
		_preview_light.light_color = Color(0.4, 0.45, 0.55)
		return
	var rc := ItemData.rarity_color(item.rarity)
	var amount := inventory.get_count(selected_index)
	_name_label.text = item.display_name
	_name_label.add_theme_color_override("font_color", rc)
	_meta_label.text = "%s  •  %s" % [ItemData.rarity_name(item.rarity).to_upper(), item.category.to_upper()]
	_desc_label.text = item.description if item.description != "" else "No description."
	(_stat_values["Weight"] as Label).text = "%.2f  (%.2f total)" % [item.weight, item.weight * amount] if amount > 1 else "%.2f" % item.weight
	(_stat_values["Value"] as Label).text = "%s%d" % [String.chr(8377), item.value]
	(_stat_values["Stack"] as Label).text = "%d / %d" % [amount, item.max_stack]
	_use_btn.text = "Use" if item.consumable else "Equip"
	_preview_light.light_color = rc


func _update_footer() -> void:
	if _weight_bar == null:
		return
	var w := inventory.total_weight() + extra_weight
	_weight_bar.max_value = max_weight
	_weight_bar.value = minf(w, max_weight)
	_weight_label.text = "%.1f / %.1f" % [w, max_weight]
	_weight_fill.bg_color = C_DANGER if w > max_weight else C_ACCENT
	_subtitle.text = "%d / %d slots used" % [inventory.used_slots(), inventory.size]


# ---------------------------------------------------------------- open/close anim

func _animate(show_it: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	# Only a fade: the window is at its final size from the first frame (a scale "pop" made it
	# look big for a moment and then small).
	_place_window()
	if show_it:
		_root.modulate.a = 0.0
		_tween.tween_property(_root, "modulate:a", 1.0, 0.12)
	else:
		_tween.tween_property(_root, "modulate:a", 0.0, 0.1)
		_tween.chain().tween_callback(func() -> void:
			_root.visible = false
			set_process(false))


# ---------------------------------------------------------------- UI building

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	_root.add_child(dim)

	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The window sits in the area above the hotbar strip.
	_stage.offset_bottom = -90
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)

	_window = PanelContainer.new()
	# A fixed size (bigger than any content), so changing text never resizes the window.
	_window.custom_minimum_size = Vector2(940, 620)
	var ws := _flat(C_PANEL, C_PANEL_BORDER, 1, 18)
	ws.shadow_color = Color(0, 0, 0, 0.55)
	ws.shadow_size = 32
	_window.add_theme_stylebox_override("panel", ws)
	_stage.add_child(_window)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_window.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)
	title_box.add_child(_label(title_text, 24, C_TEXT))
	_subtitle = _label("", 13, C_MUTED)
	title_box.add_child(_subtitle)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var sort_btn := _button("Sort", "ghost")
	sort_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sort_btn.pressed.connect(func() -> void:
		inventory.sort_items()
		select_slot(_first_filled()))
	header.add_child(sort_btn)
	var close_btn := _button("✕", "ghost")
	close_btn.custom_minimum_size = Vector2(40, 36)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = C_PANEL_BORDER
	line.thickness = 1
	sep.add_theme_stylebox_override("separator", line)
	vbox.add_child(sep)

	# Body
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	vbox.add_child(body)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	left.add_child(_grid)

	var wrow := HBoxContainer.new()
	left.add_child(wrow)
	wrow.add_child(_label("WEIGHT", 12, C_MUTED))
	var wsp := Control.new()
	wsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrow.add_child(wsp)
	_weight_label = _label("", 12, C_TEXT)
	wrow.add_child(_weight_label)
	_weight_bar = ProgressBar.new()
	_weight_bar.show_percentage = false
	_weight_bar.custom_minimum_size = Vector2(0, 6)
	_weight_bar.add_theme_stylebox_override("background", _flat(Color("1f2633"), Color(0, 0, 0, 0), 0, 3))
	_weight_fill = _flat(C_ACCENT, Color(0, 0, 0, 0), 0, 3)
	_weight_bar.add_theme_stylebox_override("fill", _weight_fill)
	left.add_child(_weight_bar)

	# Right: 3D preview + details
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(320, 0)
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)

	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(320, 260)
	stage.add_theme_stylebox_override("panel", _flat(C_STAGE, C_PANEL_BORDER, 1, 14))
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.mouse_default_cursor_shape = Control.CURSOR_MOVE
	stage.gui_input.connect(_on_preview_input)
	right.add_child(stage)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(svc)
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = true
	_preview_vp.msaa_3d = Viewport.MSAA_4X
	_preview_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	svc.add_child(_preview_vp)
	_preview_pivot = PreviewStage.build(_preview_vp, 3.0, true)
	_preview_cam = _preview_vp.get_node("Camera")
	_preview_light = _preview_vp.get_node("RarityLight")

	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(overlay)
	var hint := _label("Drag to rotate  •  Scroll to zoom", 11, Color(C_MUTED, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -24
	hint.offset_bottom = -8
	overlay.add_child(hint)
	_empty_hint = _label("Empty", 14, C_MUTED)
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(_empty_hint)

	_name_label = _label("", 22, C_TEXT)
	right.add_child(_name_label)
	_meta_label = _label("", 11, C_MUTED)
	right.add_child(_meta_label)
	_desc_label = _label("", 14, Color("c3c9d5"))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(320, 66)
	right.add_child(_desc_label)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 2)
	right.add_child(stats)
	for key in ["Weight", "Value", "Stack"]:
		var row := HBoxContainer.new()
		stats.add_child(row)
		var k := _label(key, 13, C_MUTED)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		var v := _label("—", 13, C_TEXT)
		row.add_child(v)
		_stat_values[key] = v

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(gap)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	right.add_child(buttons)
	_use_btn = _button("Use", "primary")
	_use_btn.pressed.connect(func() -> void: use_slot(selected_index))
	_split_btn = _button("Split", "ghost")
	_split_btn.pressed.connect(func() -> void:
		var empty := inventory.first_empty()
		if empty >= 0:
			inventory.split_stack(selected_index, empty))
	_drop_btn = _button("Drop", "danger")
	_drop_btn.pressed.connect(func() -> void: drop_slot(selected_index))
	for b in [_use_btn, _split_btn, _drop_btn]:
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)

	var footer := _label("Click: inspect    Drag onto a hotbar slot, or Equip, to put it in the hotbar    Keys 1-5: hold an item    B / I / Esc: close", 12, Color(C_MUTED, 0.85))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Wraps instead of stretching the whole window to the text's length.
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.custom_minimum_size = Vector2(100, 0)
	vbox.add_child(footer)


func _flat(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, kind: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(72, 38)
	b.add_theme_font_size_override("font_size", 14)
	var base: Color
	var fg: Color
	var border: Color
	match kind:
		"primary":
			base = C_ACCENT
			fg = Color("1a1406")
			border = C_ACCENT
		"danger":
			base = Color("2a1a1d")
			fg = C_DANGER
			border = Color("5a2a30")
		_:
			base = Color("1c2230")
			fg = C_TEXT
			border = C_PANEL_BORDER
	var normal := _flat(base, border, 1, 9)
	var hover := _flat(base.lightened(0.12), border.lightened(0.2), 1, 9)
	var pressed := _flat(base.darkened(0.15), border, 1, 9)
	var disabled := _flat(Color("171c26"), Color("232a37"), 1, 9)
	for s in [normal, hover, pressed, disabled]:
		(s as StyleBoxFlat).content_margin_left = 12
		(s as StyleBoxFlat).content_margin_right = 12
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color("4b5366"))
	return b
