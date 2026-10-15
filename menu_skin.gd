extends RefCounted

const ROOT := "res://assets/ui/kenney/"

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

static func apply(theme: Theme, light := false) -> void:
	var normal := Color(0.97, 1, 1) if light else Color(0.25, 0.29, 0.3)
	var hover := Color(0.87, 0.96, 0.98) if light else Color(0.33, 0.42, 0.41)
	var active := Color(0.13, 0.58, 0.47)
	var disabled := Color(0.96, 0.98, 0.98) if light else Color(0.2, 0.23, 0.24)
	var panel := Color(0.97, 0.985, 0.985) if light else Color(0.1, 0.125, 0.13, 0.98)
	theme.set_stylebox("panel", "Panel", surface("input", panel, 4))
	theme.set_stylebox("panel", "PopupMenu", surface("input", panel, 4))
	for type in ["Button", "OptionButton", "TabBar"]:
		theme.set_stylebox("normal" if type != "TabBar" else "tab_unselected", type, surface("button", normal))
		theme.set_stylebox("hover" if type != "TabBar" else "tab_hovered", type, surface("button", hover))
		theme.set_stylebox("pressed" if type != "TabBar" else "tab_selected", type, surface("active", Color(0.85, 0.72, 0.86)))
		if type != "TabBar":
			theme.set_stylebox("hover_pressed", type, surface("active", Color(0.95, 0.82, 0.95)))
		theme.set_stylebox("disabled", type, surface("button", disabled))
		theme.set_color("font_pressed_color", type, Color.WHITE)
		theme.set_color("font_selected_color", type, Color.WHITE)
		theme.set_constant("icon_max_width", type, 16)
	theme.set_stylebox("normal", "LineEdit", surface("input", Color.WHITE if light else Color(0.17, 0.21, 0.22), 4))
	theme.set_icon("checked", "CheckBox", texture("checked", 18))
	theme.set_icon("unchecked", "CheckBox", texture("unchecked", 18))
	theme.set_icon("arrow", "OptionButton", texture("arrow_down" if light else "arrow_down_light", 12))
	theme.set_icon("up", "SpinBox", texture("arrow_up" if light else "arrow_up_light", 12))
	theme.set_icon("down", "SpinBox", texture("arrow_down" if light else "arrow_down_light", 12))
	theme.set_constant("icon_max_width", "OptionButton", 12)
	theme.set_constant("h_separation", "TabBar", 6)
	theme.set_constant("tab_separation", "TabBar", 6)
	var divider := StyleBoxFlat.new()
	divider.bg_color = Color(0.79, 0.84, 0.85) if light else Color(0.27, 0.33, 0.34)
	divider.content_margin_top = 1
	theme.set_stylebox("separator", "HSeparator", divider)
	theme.set_stylebox("background", "ProgressBar", surface("input", disabled, 4))
	theme.set_stylebox("fill", "ProgressBar", surface("button", active))
