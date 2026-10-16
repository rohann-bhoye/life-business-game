extends RefCounted

# Shared modern "web dashboard" look for the management PC, tablet and menus:
# white rounded cards with soft shadows, pill tabs, teal primary buttons.
const BRAND := Color("0f766e")
const BRAND_HOVER := Color("115e59")
const BRAND_SOFT := Color("ccfbf1")
const NAVY := Color("0f172a")
const PAGE := Color("f1f5f9")
const CARD := Color.WHITE
const BORDER := Color("dbe3ea")
const TEXT := Color("0f172a")
const MUTED := Color("64748b")
const DISABLED_BG := Color("eef2f6")
const PRIMARY_WORDS := ["Order", "Hire", "Buy", "Pay", "Upgrade", "Expand", "Collect", "Confirm", "Save", "Rehire", "Start", "Continue", "Apply"]

static func box(color: Color, radius := 8, border := 0, border_color := BORDER, shadow := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border)
	style.border_color = border_color
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.anti_aliasing = true
	if shadow > 0:
		style.shadow_size = shadow
		style.shadow_color = Color(0.06, 0.09, 0.16, 0.10)
		style.shadow_offset = Vector2(0, 2)
	return style

static func card(radius := 12) -> StyleBoxFlat:
	return box(CARD, radius, 1, BORDER, 6)

static func is_primary(button: Button) -> bool:
	for word in PRIMARY_WORDS:
		if button.text.begins_with(word): return true
	return false

## Styles one button as primary (teal fill) or secondary (white outline).
static func style_button(button: Button, primary := false) -> void:
	var fill := BRAND if primary else CARD
	var hover := BRAND_HOVER if primary else Color("f8fafc")
	var font := Color.WHITE if primary else TEXT
	button.add_theme_stylebox_override("normal", box(fill, 8, 0 if primary else 1))
	button.add_theme_stylebox_override("hover", box(hover, 8, 0 if primary else 1, BRAND))
	button.add_theme_stylebox_override("pressed", box(BRAND_HOVER, 8))
	button.add_theme_stylebox_override("hover_pressed", box(BRAND_HOVER, 8))
	button.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, 8, 2, Color(BRAND, 0.5)))
	button.add_theme_stylebox_override("disabled", box(DISABLED_BG, 8, 1))
	for state in ["font_color", "font_hover_color", "font_focus_color"]: button.add_theme_color_override(state, font)
	for state in ["font_pressed_color", "font_hover_pressed_color"]: button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("94a3b8"))

## Fills a Theme with the modern look. `light` keeps the bright tablet/PC style;
## otherwise a dark navy variant is used for in-game overlay menus.
static func apply(theme: Theme, light := true) -> void:
	var text := TEXT if light else Color("e2e8f0")
	var surface := CARD if light else Color(0.07, 0.1, 0.16, 0.97)
	var raised := Color("f8fafc") if light else Color("1e293b")
	var border := BORDER if light else Color("334155")
	theme.set_stylebox("panel", "Panel", box(surface, 12, 1, border, 8 if light else 0))
	theme.set_stylebox("panel", "PanelContainer", box(surface, 12, 1, border))
	theme.set_stylebox("panel", "PopupMenu", box(surface, 8, 1, border, 6))
	# Dropdown lists (e.g. the PC product list): readable dark text, teal hover row.
	theme.set_stylebox("hover", "PopupMenu", box(BRAND_SOFT if light else Color("134e4a"), 6))
	theme.set_color("font_color", "PopupMenu", text)
	theme.set_color("font_hover_color", "PopupMenu", BRAND if light else Color("5eead4"))
	theme.set_color("font_disabled_color", "PopupMenu", Color("94a3b8"))
	theme.set_color("font_accelerator_color", "PopupMenu", MUTED)
	theme.set_constant("v_separation", "PopupMenu", 6)
	theme.set_constant("item_start_padding", "PopupMenu", 10)
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, box(raised, 8, 1, border))
		theme.set_stylebox("hover", type, box(BRAND_SOFT if light else Color("134e4a"), 8, 1, BRAND))
		theme.set_stylebox("pressed", type, box(BRAND, 8))
		theme.set_stylebox("hover_pressed", type, box(BRAND_HOVER, 8))
		theme.set_stylebox("disabled", type, box(DISABLED_BG if light else Color("1e293b"), 8, 1, border))
		theme.set_stylebox("focus", type, box(Color.TRANSPARENT, 8, 2, Color(BRAND, 0.5)))
		for state in ["font_color", "font_hover_color", "font_focus_color"]: theme.set_color(state, type, text)
		for state in ["font_pressed_color", "font_hover_pressed_color"]: theme.set_color(state, type, Color.WHITE)
		theme.set_color("font_disabled_color", type, Color("94a3b8"))
	# Pill-style navigation tabs, like a website header.
	theme.set_stylebox("tab_unselected", "TabBar", box(Color.TRANSPARENT, 999))
	theme.set_stylebox("tab_hovered", "TabBar", box(BRAND_SOFT if light else Color("134e4a"), 999))
	theme.set_stylebox("tab_selected", "TabBar", box(BRAND, 999))
	theme.set_stylebox("tab_disabled", "TabBar", box(Color.TRANSPARENT, 999))
	theme.set_stylebox("tab_focus", "TabBar", box(Color.TRANSPARENT, 999, 2, Color(BRAND, 0.5)))
	theme.set_color("font_selected_color", "TabBar", Color.WHITE)
	theme.set_color("font_unselected_color", "TabBar", MUTED if light else Color("94a3b8"))
	theme.set_color("font_hovered_color", "TabBar", text)
	for type in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", type, box(CARD if light else Color("0b1220"), 8, 1, border))
		theme.set_stylebox("focus", type, box(Color.TRANSPARENT, 8, 2, BRAND))
	theme.set_color("font_color", "LineEdit", text)
	theme.set_stylebox("panel", "ItemList", box(raised, 10, 1, border))
	theme.set_stylebox("selected", "ItemList", box(BRAND_SOFT if light else Color("134e4a"), 8))
	theme.set_stylebox("selected_focus", "ItemList", box(BRAND_SOFT if light else Color("134e4a"), 8))
	theme.set_color("font_color", "ItemList", text)
	theme.set_color("font_selected_color", "ItemList", BRAND if light else Color("5eead4"))
	theme.set_color("font_color", "Label", text)
	var divider := StyleBoxFlat.new()
	divider.bg_color = border
	divider.content_margin_top = 1
	theme.set_stylebox("separator", "HSeparator", divider)
	theme.set_stylebox("background", "ProgressBar", box(DISABLED_BG if light else Color("1e293b"), 999))
	theme.set_stylebox("fill", "ProgressBar", box(BRAND, 999))

## Dark translucent "glass" panel used by the lobby, pause and settings menus.
static func glass_box(alpha := 0.82) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, alpha)
	style.set_corner_radius_all(16)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.12)
	style.shadow_size = 12
	style.shadow_color = Color(0, 0, 0, 0.35)
	return style
