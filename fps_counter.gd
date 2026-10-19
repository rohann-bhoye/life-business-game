extends CanvasLayer

# Frames-per-second readout in the top-right corner (Settings > Show FPS). It lives
# under the tree root, so it stays on from the lobby into the game and through pause.
var label: Label
var wait := 0.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("86efac"))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.offset_left = -120
	label.offset_right = -10
	label.offset_top = 6
	add_child(label)

func _process(delta: float) -> void:
	wait -= delta
	if wait > 0.0: return
	wait = 0.5
	var fps := Engine.get_frames_per_second()
	label.text = "%d FPS" % fps
	label.add_theme_color_override("font_color", Color("86efac") if fps >= 50 else (Color("fde047") if fps >= 30 else Color("fca5a5")))
