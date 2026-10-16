extends RefCounted

const ROOT := "res://assets/ui/kenney/"
const UiStyle := preload("res://ui_style.gd")
const KenneyTheme := preload("res://kenney_theme.gd")

static func texture(asset: String, icon_size := 0) -> Texture2D:
	var resource := load(ROOT + asset + ".png") as Texture2D
	if icon_size <= 0: return resource
	var image := resource.get_image()
	image.resize(icon_size, icon_size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

static func surface(asset: String, tint: Color, inset := 6.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture(asset)
	style.modulate_color = tint
	style.set_texture_margin_all(inset)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

# Modern flat web-dashboard styling (ui_style.gd) with the licensed Kenney icons.
static func apply(theme: Theme, light := false) -> void:
	UiStyle.apply(theme, light)
	# Kenney UI Pack buttons, tabs, cards and inputs on top of the base colours.
	KenneyTheme.apply(theme)
	for type in ["Button", "OptionButton", "TabBar"]:
		theme.set_constant("icon_max_width", type, 16)
	theme.set_icon("checked", "CheckBox", texture("checked", 18))
	theme.set_icon("unchecked", "CheckBox", texture("unchecked", 18))
	theme.set_icon("arrow", "OptionButton", texture("arrow_down" if light else "arrow_down_light", 12))
	theme.set_icon("up", "SpinBox", texture("arrow_up" if light else "arrow_up_light", 12))
	theme.set_icon("down", "SpinBox", texture("arrow_down" if light else "arrow_down_light", 12))
	theme.set_constant("icon_max_width", "OptionButton", 12)
	theme.set_constant("h_separation", "TabBar", 6)
	theme.set_constant("tab_separation", "TabBar", 6)
