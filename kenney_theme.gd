extends RefCounted

# Kenney UI Pack theme (assets/ui/kenney_pack, CC0): 9-slice depth buttons, white
# bordered cards and inputs, and the Kenney Future Narrow font for buttons, tabs and
# headings. Colours: grey = normal, blue = hover, green = primary / selected.
const ROOT := "res://assets/ui/kenney_pack/"
const TEXT := Color("1f2937")
const MUTED := Color("6b7280")
const GREEN := Color("15803d")
static var font: Font

static func heading_font() -> Font:
	if font == null: font = load(ROOT + "kenney_future_narrow.ttf")
	return font

## Depth button textures have a 4 px shadow at the bottom: keep it out of the stretch.
static func button_box(colour: String, pressed := false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(ROOT + "%s_button%s.png" % [colour, "_pressed" if pressed else ""])
	style.texture_margin_left = 10
	style.texture_margin_right = 10
	style.texture_margin_top = 10
	style.texture_margin_bottom = 4 if pressed else 12
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4 if pressed else 7
	return style

static func card_box() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(ROOT + "card.png")
	style.set_texture_margin_all(10)
	style.set_content_margin_all(8)
	return style

static func input_box() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(ROOT + "input.png")
	style.set_texture_margin_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func _button_states(theme: Theme, type: String, normal: String, hover: String) -> void:
	theme.set_stylebox("normal", type, button_box(normal))
	theme.set_stylebox("hover", type, button_box(hover))
	theme.set_stylebox("pressed", type, button_box("green", true))
	theme.set_stylebox("hover_pressed", type, button_box("green", true))
	theme.set_stylebox("disabled", type, button_box("grey", true))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	var white := Color.WHITE if normal != "grey" else TEXT
	for state in ["font_color", "font_focus_color"]: theme.set_color(state, type, white)
	theme.set_color("font_hover_color", type, Color.WHITE)
	for state in ["font_pressed_color", "font_hover_pressed_color"]: theme.set_color(state, type, Color.WHITE)
	theme.set_color("font_disabled_color", type, Color("9ca3af"))
	theme.set_font("font", type, heading_font())

## Buttons, tabs, panels and inputs in Kenney style. "PrimaryButton" is a green
## type variation for the main action on a screen.
static func apply(theme: Theme) -> void:
	_button_states(theme, "Button", "grey", "blue")
	theme.set_type_variation("PrimaryButton", "Button")
	_button_states(theme, "PrimaryButton", "green", "blue")
	theme.set_type_variation("DangerButton", "Button")
	_button_states(theme, "DangerButton", "red", "red")
	_button_states(theme, "OptionButton", "grey", "blue")
	theme.set_stylebox("panel", "Panel", card_box())
	theme.set_stylebox("panel", "PanelContainer", card_box())
	for type in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", type, input_box())
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_stylebox("tab_selected", "TabBar", button_box("green"))
	theme.set_stylebox("tab_unselected", "TabBar", button_box("grey"))
	theme.set_stylebox("tab_hovered", "TabBar", button_box("blue"))
	theme.set_stylebox("tab_disabled", "TabBar", button_box("grey", true))
	theme.set_stylebox("tab_focus", "TabBar", StyleBoxEmpty.new())
	theme.set_color("font_selected_color", "TabBar", Color.WHITE)
	theme.set_color("font_unselected_color", "TabBar", TEXT)
	theme.set_color("font_hovered_color", "TabBar", Color.WHITE)
	theme.set_font("font", "TabBar", heading_font())
	theme.set_font_size("font_size", "TabBar", 15)
	for state in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled"]:
		var tab: StyleBoxTexture = theme.get_stylebox(state, "TabBar")
		tab.content_margin_left = 8
		tab.content_margin_right = 8
	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_font("font", "HeadingLabel", heading_font())
	theme.set_color("font_color", "HeadingLabel", GREEN)
