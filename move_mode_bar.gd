extends Control

# The button bar at the bottom of the screen while a rack, the checkout counter or
# the PC desk is being moved (rack_furnishing.gd): what each key and mouse button
# does, and a green "ready" or red reason line for the spot under the crosshair.

var furnishing: Node
var title: Label
var status: Label
var pack_row: Control
var panel: Panel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	panel = Panel.new()
	panel.name = "MovePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.05, 0.06, 0.86)
	style.border_color = Color(0.95, 0.7, 0.2)
	style.border_width_top = 3
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	title = _text("Title", "MOVE", 16, Color(1, 0.82, 0.35))
	title.position = Vector2(14, 8)
	status = _text("Status", "", 13, Color.WHITE)
	status.position = Vector2(14, 32)
	var x := 14.0
	for button in [["LMB", "E", "Place"], ["R", "WHEEL", "Rotate"], ["Q", "", "Pack in box"], ["RMB", "G", "Cancel"]]:
		var row := Control.new()
		row.name = "Row" + button[2].replace(" ", "")
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.position = Vector2(x, 58)
		panel.add_child(row)
		var key_x := 0.0
		for key in [button[0], button[1]]:
			if key.is_empty(): continue
			var cap := _keycap(row, key)
			cap.position = Vector2(key_x, 0)
			key_x += cap.size.x + 4
		var label := _text("Action", button[2], 13, Color(0.92, 0.95, 0.96))
		label.reparent(row)
		label.position = Vector2(key_x + 2, 4)
		if button[2] == "Pack in box": pack_row = row
		x += key_x + label.get_minimum_size().x + 22
	panel.size = Vector2(x, 94)

func _text(node_name: String, value: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(label)
	return label

func _keycap(parent: Control, value: String) -> Label:
	var key := Label.new()
	key.name = "Key" + value
	key.text = value
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_theme_color_override("font_color", Color(0.08, 0.11, 0.12))
	key.add_theme_font_size_override("font_size", 12 if value.length() > 1 else 14)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.96, 0.98, 0.99)
	box.border_color = Color(0.55, 0.62, 0.65)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	key.add_theme_stylebox_override("normal", box)
	parent.add_child(key)
	key.size = Vector2(maxf(26, value.length() * 9 + 10), 26)
	return key

func _process(_delta: float) -> void:
	visible = is_instance_valid(furnishing) and furnishing.active
	if not visible: return
	title.text = "MOVE " + furnishing.target_name().to_upper()
	var error: String = furnishing.last_error
	status.text = "Spot is free: click to place." if error.is_empty() else error
	status.add_theme_color_override("font_color", Color(0.45, 1, 0.6) if error.is_empty() else Color(1, 0.45, 0.4))
	pack_row.modulate.a = 1.0 if furnishing.can_pack() else 0.35
	var width := minf(panel.size.x, size.x - 32)
	panel.scale = Vector2.ONE * (width / panel.size.x)
	panel.position = Vector2((size.x - width) / 2.0, size.y - 94 * panel.scale.y - 92)
