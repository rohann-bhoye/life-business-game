extends Control

# The "+" in the middle of the screen, so it is clear which product, box, rack or
# person E and Q will act on. Drawn white with a dark edge so it shows on any
# background; game_ui.gd shows it only while the mouse looks around.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	var centre := size / 2.0
	for pass_index in range(2):
		var colour := Color(0, 0, 0, 0.65) if pass_index == 0 else Color(1, 1, 1, 0.95)
		var width := 4.0 if pass_index == 0 else 2.0
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(centre + direction * 3.0, centre + direction * 10.0, colour, width)
	draw_circle(centre, 1.6, Color.WHITE)
