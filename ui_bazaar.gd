extends RefCounted

# The game's UI colours ("bright bazaar"), shared by the tablet, the Journal, the pause menu,
# the map and the other panels: cream pages, a saffron header, the pink, turquoise and yellow
# of the town's houses as accents, white cards with a dark cartoon outline, and dark brown
# ink for text so it reads on the light pages.
const CREAM := Color("fff4e0")
const CARD := Color("ffffff")
const SAFFRON := Color("f28c28")
const SAFFRON_DEEP := Color("c8611a")
const PINK := Color("e84a8a")
const TURQUOISE := Color("1fb5ad")
const YELLOW := Color("f6c445")
const GREEN := Color("3cb44b")
const PURPLE := Color("8e5bd8")
const INK := Color("3a2a1e")
const MUTED := Color("8a7560")
const LINE := Color("ecd9b8")
const ACCENTS := [PINK, TURQUOISE, YELLOW, GREEN, PURPLE, SAFFRON]

## A rounded box; `outline` > 0 draws the dark cartoon edge.
static func box(fill: Color, outline := 0, radius := 10, edge := INK) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(outline)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

## Button looks: white with a dark outline, warm yellow on hover, saffron when pressed or
## chosen. `primary` buttons are saffron from the start.
static func button(target: Button, primary := false) -> void:
	var looks := {"normal": SAFFRON if primary else CARD, "hover": Color("ffa04a") if primary else Color("fff0c2"), "pressed": SAFFRON_DEEP if primary else SAFFRON, "disabled": Color("efe6d6")}
	for state in looks:
		target.add_theme_stylebox_override(state, box(looks[state], 2, 10, INK if state != "disabled" else LINE))
	target.add_theme_font_override("font", ThemeDB.fallback_font)
	target.add_theme_color_override("font_color", Color.WHITE if primary else INK)
	target.add_theme_color_override("font_hover_color", Color.WHITE if primary else INK)
	target.add_theme_color_override("font_pressed_color", Color.WHITE)
	target.add_theme_color_override("font_disabled_color", MUTED)
