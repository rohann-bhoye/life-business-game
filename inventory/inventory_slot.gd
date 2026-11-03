class_name InventorySlotUI
extends PanelContainer
## One slot: renders its item as a live 3D model (spins on hover),
## shows stack count + rarity bar, supports drag & drop.

signal clicked(index: int, button: int, double_click: bool)
signal drop_requested(from_index: int, to_index: int, split: bool)

const C_SLOT := Color("1a202b")
const C_SLOT_HOVER := Color("232b3a")
const C_BORDER := Color("2b3343")
const C_SELECTED := Color("e9b44c")

var index: int = -1
var item: ItemData
var count: int = 0
var selected: bool = false:
	set(v):
		selected = v
		_update_style()

var _hovered := false
var _style := StyleBoxFlat.new()
var _viewport: SubViewport
var _pivot: Node3D
var _count_label: Label
var _rarity_bar: ColorRect


func _init() -> void:
	custom_minimum_size = Vector2(80, 80)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style.set_corner_radius_all(10)
	_style.set_content_margin_all(3)
	_style.anti_aliasing = true
	add_theme_stylebox_override("panel", _style)

	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	svc.add_child(_viewport)
	_pivot = PreviewStage.build(_viewport, 2.9, false)

	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	_rarity_bar = ColorRect.new()
	_rarity_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rarity_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_rarity_bar.offset_left = 14
	_rarity_bar.offset_right = -14
	_rarity_bar.offset_top = -4
	_rarity_bar.offset_bottom = -2
	overlay.add_child(_rarity_bar)

	_count_label = Label.new()
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.add_theme_font_size_override("font_size", 14)
	_count_label.add_theme_color_override("font_color", Color("f2f4f8"))
	_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_count_label.add_theme_constant_override("outline_size", 5)
	_count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count_label.offset_left = -48
	_count_label.offset_top = -26
	_count_label.offset_right = -6
	_count_label.offset_bottom = -6
	overlay.add_child(_count_label)

	_update_style()
	set_process(false)


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_data(p_item: ItemData, p_count: int) -> void:
	if p_item != item:
		for c in _pivot.get_children():
			_pivot.remove_child(c)
			c.queue_free()
		if p_item != null:
			_pivot.add_child(PreviewStage.make_model(p_item))
		_pivot.rotation = Vector3(0, 0.6, 0)
	item = p_item
	count = p_count if p_item != null else 0
	_count_label.text = str(count) if count > 1 else ""
	_rarity_bar.visible = item != null
	if item != null:
		_rarity_bar.color = ItemData.rarity_color(item.rarity)
	_update_style()
	refresh_render()


## Re-draws the 3D thumbnail once (cheap: slots only render when needed).
func refresh_render() -> void:
	if not _hovered:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	_pivot.rotate_y(delta * 2.2)


func _on_mouse_entered() -> void:
	_hovered = true
	_update_style()
	if item != null:
		_pivot.scale = Vector3.ONE * 1.12
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		set_process(true)


func _on_mouse_exited() -> void:
	_hovered = false
	_update_style()
	set_process(false)
	_pivot.scale = Vector3.ONE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _update_style() -> void:
	var border := C_BORDER
	var bw := 1
	if item != null:
		border = ItemData.rarity_color(item.rarity).lerp(C_BORDER, 0.55)
	if _hovered:
		border = border.lightened(0.25)
	if selected:
		border = C_SELECTED
		bw = 2
	_style.bg_color = C_SLOT_HOVER if (_hovered or selected) else C_SLOT
	_style.border_color = border
	_style.set_border_width_all(bw)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			clicked.emit(index, mb.button_index, mb.double_click)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null:
		return null
	var holder := Control.new()
	var tex := TextureRect.new()
	tex.texture = _viewport.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.size = size
	tex.position = -size * 0.5
	tex.modulate = Color(1, 1, 1, 0.9)
	holder.add_child(tex)
	set_drag_preview(holder)
	modulate.a = 0.35
	return {"inv_from": index, "split": Input.is_key_pressed(KEY_SHIFT)}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("inv_from")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_requested.emit(int(data["inv_from"]), index, bool(data["split"]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
