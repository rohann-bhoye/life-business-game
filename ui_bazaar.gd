extends RefCounted

# The game's UI colours ("bright bazaar"), shared by the tablet, the Journal, the pause menu,
# the map and the other panels: cream pages, a saffron header, the pink, turquoise and yellow
# of the town's houses as accents, white cards with a dark cartoon outline, and dark brown
# ink for text so it reads on the light pages.
# make_theme() is the whole look as a Theme for menus (main menu, settings, co-op, how to
# play, day report), so every menu matches the pause menu.
const CREAM := Color("fff4e0")
const CARD := Color("ffffff")
const SAFFRON := Color("f28c28")
const SAFFRON_DEEP := Color("c8611a")
const PINK := Color("e84a8a")
const TURQUOISE := Color("1fb5ad")
const YELLOW := Color("f6c445")
const GREEN := Color("3cb44b")
const GREEN_DEEP := Color("23853a")
const RED_DEEP := Color("c0392b")
const PURPLE := Color("8e5bd8")
const INK := Color("3a2a1e")
const MUTED := Color("8a7560")
const LINE := Color("ecd9b8")
const HOVER := Color("fff0c2")
const ACCENTS := [PINK, TURQUOISE, YELLOW, GREEN, PURPLE, SAFFRON]

static var cached_theme: Theme
static var icons := {}

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
	style.anti_aliasing = true
	return style

## The menu card: cream with the cartoon outline, a thick saffron top and a soft shadow
## (the pause menu's look).
static func card() -> StyleBoxFlat:
	var style := box(CREAM, 3, 14)
	style.border_color = SAFFRON
	style.border_width_top = 8
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 26
	return style

## Button looks: white with a dark outline, warm yellow on hover, saffron when pressed or
## chosen. `primary` buttons are saffron from the start.
static func button(target: Button, primary := false) -> void:
	var looks := {"normal": SAFFRON if primary else CARD, "hover": Color("ffa04a") if primary else HOVER, "pressed": SAFFRON_DEEP if primary else SAFFRON, "disabled": Color("efe6d6")}
	for state in looks:
		target.add_theme_stylebox_override(state, box(looks[state], 2, 10, INK if state != "disabled" else LINE))
	target.add_theme_font_override("font", ThemeDB.fallback_font)
	target.add_theme_color_override("font_color", Color.WHITE if primary else INK)
	target.add_theme_color_override("font_hover_color", Color.WHITE if primary else INK)
	target.add_theme_color_override("font_pressed_color", Color.WHITE)
	target.add_theme_color_override("font_disabled_color", MUTED)

static var name_font_cache: FontVariation

## A bold, plainly readable font for the town's name in big titles. The pixel heading font
## draws A and R almost alike, so "DHOLKARPUR" read as "Dholkapur".
static func name_font() -> Font:
	if name_font_cache == null:
		name_font_cache = FontVariation.new()
		name_font_cache.base_font = ThemeDB.fallback_font
		name_font_cache.variation_embolden = 1.0
		name_font_cache.spacing_glyph = 4
	return name_font_cache

## A dim over the whole screen behind a menu (add as the menu's first child).
static func dim() -> ColorRect:
	var shade := ColorRect.new()
	shade.name = "Dim"
	shade.color = Color(0.05, 0.03, 0.02, 0.5)
	shade.show_behind_parent = true
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	return shade

## Places `shade` (a child of `menu`) over the whole screen.
static func cover(shade: Control, menu: Control) -> void:
	shade.position = -menu.position
	shade.size = menu.get_viewport().get_visible_rect().size

# --- The theme ---

static func _button_type(theme: Theme, type: String, normal: Color, hover: Color, pressed: Color, words: Color) -> void:
	theme.set_stylebox("normal", type, box(normal, 2, 10))
	theme.set_stylebox("hover", type, box(hover, 2, 10))
	theme.set_stylebox("pressed", type, box(pressed, 2, 10))
	theme.set_stylebox("hover_pressed", type, box(pressed, 2, 10))
	theme.set_stylebox("disabled", type, box(Color("efe6d6"), 2, 10, LINE))
	var focus := box(Color(0, 0, 0, 0), 2, 12, SAFFRON_DEEP)
	focus.set_expand_margin_all(3)
	theme.set_stylebox("focus", type, focus)
	theme.set_font("font", type, ThemeDB.fallback_font)
	for state in ["font_color", "font_focus_color"]: theme.set_color(state, type, words)
	theme.set_color("font_hover_color", type, words)
	for state in ["font_pressed_color", "font_hover_pressed_color"]: theme.set_color(state, type, Color.WHITE)
	theme.set_color("font_disabled_color", type, MUTED)
	for state in ["icon_normal_color", "icon_focus_color", "icon_hover_color"]: theme.set_color(state, type, words)

## The menu Theme: card panels, outlined buttons (Primary saffron, Info turquoise, Danger
## pink), white dropdowns, green on/off switches, saffron sliders and scroll bars.
static func make_theme() -> Theme:
	if cached_theme != null: return cached_theme
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_stylebox("panel", "Panel", card())
	theme.set_stylebox("panel", "PanelContainer", box(CARD, 2, 12, LINE))
	theme.set_color("font_color", "Label", INK)
	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_font("font", "HeadingLabel", preload("res://kenney_theme.gd").heading_font())
	theme.set_color("font_color", "HeadingLabel", INK)
	_button_type(theme, "Button", CARD, HOVER, SAFFRON, INK)
	theme.set_type_variation("PrimaryButton", "Button")
	_button_type(theme, "PrimaryButton", SAFFRON, Color("ffa04a"), SAFFRON_DEEP, Color.WHITE)
	theme.set_type_variation("InfoButton", "Button")
	_button_type(theme, "InfoButton", TURQUOISE, Color("3fcbc3"), Color("158a84"), Color.WHITE)
	theme.set_type_variation("DangerButton", "Button")
	_button_type(theme, "DangerButton", PINK, Color("f06ba1"), Color("c5336f"), Color.WHITE)
	_button_type(theme, "OptionButton", CARD, HOVER, HOVER, INK)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style: StyleBoxFlat = theme.get_stylebox(state, "OptionButton").duplicate()
		style.content_margin_right = 30
		theme.set_stylebox(state, "OptionButton", style)
	theme.set_color("font_pressed_color", "OptionButton", INK)
	theme.set_color("font_hover_pressed_color", "OptionButton", INK)
	theme.set_icon("arrow", "OptionButton", _arrow())
	theme.set_constant("arrow_margin", "OptionButton", 10)
	# On/off switches and checkboxes sit straight on the card.
	for type in ["CheckButton", "CheckBox"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			theme.set_stylebox(state, type, StyleBoxEmpty.new())
		theme.set_font("font", type, ThemeDB.fallback_font)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, INK)
		theme.set_color("font_disabled_color", type, MUTED)
	for state in ["checked", "checked_disabled"]: theme.set_icon(state, "CheckButton", _switch(true))
	for state in ["unchecked", "unchecked_disabled"]: theme.set_icon(state, "CheckButton", _switch(false))
	for state in ["checked", "checked_disabled"]: theme.set_icon(state, "CheckBox", _tick(true))
	for state in ["unchecked", "unchecked_disabled"]: theme.set_icon(state, "CheckBox", _tick(false))
	# Sliders: a cream groove with a saffron fill and a round white knob.
	var groove := box(LINE, 0, 4)
	groove.content_margin_top = 3
	groove.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", groove)
	var filled := box(SAFFRON, 0, 4)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", _knob(CARD))
	theme.set_icon("grabber_highlight", "HSlider", _knob(HOVER))
	theme.set_icon("grabber_disabled", "HSlider", _knob(Color("efe6d6")))
	# Scroll bars: a thin cream track with a saffron handle.
	for type in ["VScrollBar", "HScrollBar"]:
		var track := box(Color(INK, 0.08), 0, 6)
		track.set_content_margin_all(4)
		theme.set_stylebox("scroll", type, track)
		theme.set_stylebox("scroll_focus", type, track)
		theme.set_stylebox("grabber", type, box(SAFFRON, 0, 6))
		theme.set_stylebox("grabber_highlight", type, box(Color("ffa04a"), 0, 6))
		theme.set_stylebox("grabber_pressed", type, box(SAFFRON_DEEP, 0, 6))
	# Text boxes.
	for type in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", type, box(CARD, 2, 8))
		theme.set_stylebox("focus", type, box(Color(0, 0, 0, 0), 2, 8, SAFFRON))
		theme.set_stylebox("read_only", type, box(Color("f6eddc"), 2, 8, LINE))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_color("selection_color", "LineEdit", Color(SAFFRON, 0.35))
	theme.set_font("font", "LineEdit", ThemeDB.fallback_font)
	# Dropdown lists.
	var popup := box(CARD, 2, 10)
	popup.set_content_margin_all(6)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", box(HOVER, 0, 6))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_color("font_disabled_color", "PopupMenu", MUTED)
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_constant("item_start_padding", "PopupMenu", 10)
	theme.set_font("font", "PopupMenu", ThemeDB.fallback_font)
	theme.set_stylebox("panel", "TooltipPanel", box(CARD, 2, 8))
	theme.set_color("font_color", "TooltipLabel", INK)
	# Tabs and progress bars, for completeness.
	theme.set_stylebox("tab_selected", "TabBar", box(SAFFRON, 2, 10))
	theme.set_stylebox("tab_unselected", "TabBar", box(CARD, 2, 10))
	theme.set_stylebox("tab_hovered", "TabBar", box(HOVER, 2, 10))
	theme.set_stylebox("tab_disabled", "TabBar", box(Color("efe6d6"), 2, 10, LINE))
	theme.set_stylebox("tab_focus", "TabBar", StyleBoxEmpty.new())
	theme.set_color("font_selected_color", "TabBar", Color.WHITE)
	theme.set_color("font_unselected_color", "TabBar", INK)
	theme.set_color("font_hovered_color", "TabBar", INK)
	theme.set_stylebox("background", "ProgressBar", box(LINE, 0, 999))
	theme.set_stylebox("fill", "ProgressBar", box(SAFFRON, 0, 999))
	var divider := StyleBoxFlat.new()
	divider.bg_color = LINE
	divider.content_margin_top = 1
	theme.set_stylebox("separator", "HSeparator", divider)
	cached_theme = theme
	return theme

# --- Icons, drawn once (anti-aliased) instead of loaded, so they match the colours ---

## A layer: ["rect", centre, half size, radius, colour], ["circle", centre, radius, colour]
## or ["line", from, to, half width, colour]. Layers are drawn in order.
static func _paint(key: String, width: int, height: int, layers: Array) -> ImageTexture:
	if icons.has(key): return icons[key]
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var point := Vector2(x + 0.5, y + 0.5)
			var result := Color(0, 0, 0, 0)
			for layer in layers:
				var distance := _distance(layer, point)
				var cover := clampf(0.5 - distance, 0.0, 1.0)
				if cover <= 0.0: continue
				var colour: Color = layer[layer.size() - 1]
				var alpha := colour.a * cover
				var total := alpha + result.a * (1.0 - alpha)
				if total <= 0.0: continue
				var mixed := (Color(colour.r, colour.g, colour.b) * alpha + Color(result.r, result.g, result.b) * result.a * (1.0 - alpha)) / total
				result = Color(mixed.r, mixed.g, mixed.b, total)
			image.set_pixel(x, y, result)
	var texture := ImageTexture.create_from_image(image)
	icons[key] = texture
	return texture

static func _distance(layer: Array, point: Vector2) -> float:
	match layer[0]:
		"rect":
			var q: Vector2 = (point - layer[1]).abs() - layer[2] + Vector2(layer[3], layer[3])
			return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - layer[3]
		"circle":
			return point.distance_to(layer[1]) - layer[2]
		"line":
			var a: Vector2 = layer[1]
			var b: Vector2 = layer[2]
			var t := clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			return point.distance_to(a.lerp(b, t)) - layer[3]
	return 1.0

## An on/off switch: a pill track with a white knob, green when on.
static func _switch(on: bool) -> ImageTexture:
	var track := GREEN if on else Color("e6d5b8")
	var knob := Vector2(31, 13) if on else Vector2(13, 13)
	return _paint("switch_%s" % on, 44, 26, [
		["rect", Vector2(22, 13), Vector2(21, 12), 12.0, INK],
		["rect", Vector2(22, 13), Vector2(19, 10), 10.0, track],
		["circle", knob, 8.0, INK],
		["circle", knob, 6.5, CARD],
	])

## A checkbox: white with the outline, saffron with a white tick when checked.
static func _tick(on: bool) -> ImageTexture:
	var layers := [["rect", Vector2(11, 11), Vector2(10, 10), 5.0, INK], ["rect", Vector2(11, 11), Vector2(8, 8), 3.5, SAFFRON if on else CARD]]
	if on:
		layers.append(["line", Vector2(6.5, 11.5), Vector2(9.5, 14.5), 1.4, CARD])
		layers.append(["line", Vector2(9.5, 14.5), Vector2(15.5, 7.5), 1.4, CARD])
	return _paint("tick_%s" % on, 22, 22, layers)

## The round slider knob.
static func _knob(fill: Color) -> ImageTexture:
	return _paint("knob_%s" % fill.to_html(), 22, 22, [["circle", Vector2(11, 11), 10.0, INK], ["circle", Vector2(11, 11), 8.0, fill]])

## The dropdown's down arrow.
static func _arrow() -> ImageTexture:
	return _paint("arrow", 14, 10, [["line", Vector2(2.5, 2.5), Vector2(7, 7.5), 1.3, INK], ["line", Vector2(7, 7.5), Vector2(11.5, 2.5), 1.3, INK]])
