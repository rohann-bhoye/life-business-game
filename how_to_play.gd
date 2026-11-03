extends Control

# "How to Play": a picture guide like real games have. Each page shows a picture
# from the game (assets/ui/howto/, made by tools/how_to_play_pictures.gd), a title,
# a short explanation and the keys it uses. Back / Next (or the arrow keys), page
# dots, Close (Esc). Opens from the main menu, the pause menu and F1 in the game,
# and once by itself in a player's first new game.
signal closed

const KenneyTheme = preload("res://kenney_theme.gd")
const SEEN_FILE := "user://help.cfg"
const PAGES := [
	{"picture": "shop", "title": "Your own kirana shop", "text": "Welcome to Apna Mart in Dholkarpur Gaon! Buy stock, fill the shelves, serve customers and grow a small kirana into a Mega Mart.", "keys": []},
	{"picture": "controls", "title": "Moving around", "text": "Walk with W A S D and look with the mouse. The + in the middle shows what you are aiming at; the hint under it says what E or Q will do.", "keys": ["W A S D", "MOUSE", "E", "Q"]},
	{"picture": "pc", "title": "Order stock on the PC", "text": "Aim at the PC on the desk and press E. Open Wholesale, add boxes to the cart and press Place order. Right click leaves the PC.", "keys": ["E", "RMB"]},
	{"picture": "boxes", "title": "Pick up the boxes", "text": "The van brings your boxes to APNA STORAGE across the road. Aim at a box and press E to carry it. Q puts it down.", "keys": ["E", "Q"]},
	{"picture": "stock", "title": "Fill the shelves", "text": "Stand at a rack with a box: E puts one item on the shelf, Q takes one back. Any product fits on any empty row.", "keys": ["E", "Q"]},
	{"picture": "checkout", "title": "Serve customers", "text": "Customers come to the counter with a list. Press E to hear it (it shows on the right with rack codes), E to take a carry bag, then E at each rack to put the items in (Q takes one out). Bring the bag back, press E to hand it over and pick Cash, Card or UPI.", "keys": ["E", "Q"]},
	{"picture": "pc", "title": "International orders", "text": "APNA Export on the PC lists buyers abroad. Accept one, take a carton at the packing table (left of the shop), fill it at the racks with E and seal it. Carry the parcel to the export platform at the airport behind the warehouse: the plane comes at 10, 13, 16 and 19 o'clock and the buyer pays.", "keys": ["E", "Q"]},
	{"picture": "pc", "title": "Carry bags", "text": "Every order uses one carry bag from the box on the counter. You start with 20. Buy more on the PC: Wholesale > Supplies, 25 bags for a small price.", "keys": ["E"]},
	{"picture": "move", "title": "Arrange your shop", "text": "Aim at a rack, the counter or the PC desk and press G. Move it, turn it with R or the wheel, and click to place it. Q packs a bought rack into its box.", "keys": ["G", "R", "LMB", "Q"]},
	{"picture": "tablet", "title": "Your shop PC", "text": "Press E at the PC on your desk: Shop Manager (money, bills, prices, marketing, goals), Wholesale, Staff and more. Talk to staff and customers with E; reply with 1-4.", "keys": ["E", "1-4"]},
	{"picture": "grow", "title": "Grow the business", "text": "On the PC, APNA Builders sells shop expansions and makeovers, and Wholesale > Furniture sells more racks. Licences open more kinds of products. Hire Ramesh and Sunil on the Staff page.", "keys": ["E"]},
	{"picture": "night", "title": "End of the day", "text": "The shop is open 08:00 - 20:00. After 20:00 go home and sleep (E at the bed) to start a new day and see your day report.", "keys": ["E", "ESC"]},
]
var page := 0
var card: Panel
var picture: TextureRect
var title: Label
var body: Label
var counter: Label
var keys: HBoxContainer
var dots: HBoxContainer
var back_button: Button
var next_button: Button
var close_button: Button

func _ready() -> void:
	name = "HowToPlay"
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page_theme := Theme.new()
	page_theme.default_font_size = 16
	KenneyTheme.apply(page_theme)
	theme = page_theme
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	card = Panel.new()
	card.add_theme_stylebox_override("panel", _round(Color("f8fafc"), 16))
	add_child(card)
	var header := Panel.new()
	header.name = "Header"
	header.add_theme_stylebox_override("panel", _round(Color("0f766e"), 16, true))
	card.add_child(header)
	var heading := _label(header, "HOW TO PLAY", 22, Color.WHITE)
	heading.name = "Heading"
	heading.add_theme_font_override("font", KenneyTheme.heading_font())
	counter = _label(header, "", 15, Color("ccfbf1"))
	counter.name = "Counter"
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var frame := Panel.new()
	frame.name = "PictureFrame"
	frame.clip_contents = true
	frame.add_theme_stylebox_override("panel", _round(Color("0f172a"), 12))
	card.add_child(frame)
	picture = TextureRect.new()
	picture.name = "Picture"
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(picture)
	title = _label(card, "", 24, Color("0f172a"))
	title.name = "Title"
	title.add_theme_font_override("font", KenneyTheme.heading_font())
	body = _label(card, "", 16, Color("334155"))
	body.name = "Body"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys = HBoxContainer.new()
	keys.name = "Keys"
	keys.add_theme_constant_override("separation", 8)
	card.add_child(keys)
	dots = HBoxContainer.new()
	dots.name = "Dots"
	dots.add_theme_constant_override("separation", 6)
	card.add_child(dots)
	for index in range(PAGES.size()):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dots.add_child(dot)
	back_button = _button("Back", func(): show_page(page - 1))
	back_button.name = "BackButton"
	next_button = _button("Next", _next)
	next_button.name = "NextButton"
	next_button.theme_type_variation = "PrimaryButton"
	get_viewport().size_changed.connect(_layout)
	_layout()

func _round(colour: Color, radius: int, top_only := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	if top_only:
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
	return style

func _label(parent: Node, value: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	card.add_child(button)
	return button

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var width := minf(940, view.x - 32)
	var picture_height := minf((width - 48) * 9.0 / 16.0, view.y - 330)
	var height := picture_height + 300
	card.position = ((view - Vector2(width, height)) / 2.0).floor()
	card.size = Vector2(width, height)
	var header: Panel = card.get_node("Header")
	header.position = Vector2.ZERO
	header.size = Vector2(width, 54)
	header.get_node("Heading").position = Vector2(20, 12)
	header.get_node("Heading").size = Vector2(width * 0.5, 30)
	counter.position = Vector2(width - 250, 16)
	counter.size = Vector2(120, 24)
	close_button.position = Vector2(width - 116, 9)
	close_button.size = Vector2(100, 36)
	var frame: Panel = card.get_node("PictureFrame")
	frame.position = Vector2(24, 68)
	frame.size = Vector2(width - 48, picture_height)
	picture.position = Vector2.ZERO
	picture.size = frame.size
	title.position = Vector2(24, 80 + picture_height)
	title.size = Vector2(width - 48, 34)
	body.position = Vector2(24, 118 + picture_height)
	body.size = Vector2(width - 48, 64)
	keys.position = Vector2(24, 186 + picture_height)
	keys.size = Vector2(width - 48, 34)
	dots.position = Vector2(24, height - 44)
	back_button.position = Vector2(width - 324, height - 60)
	back_button.size = Vector2(140, 44)
	next_button.position = Vector2(width - 172, height - 60)
	next_button.size = Vector2(150, 44)

## Opens the guide on its first page (or `start`).
func open(start := 0) -> void:
	show()
	move_to_front()
	show_page(start)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var config := ConfigFile.new()
	config.load(SEEN_FILE)
	config.set_value("help", "seen", true)
	config.save(SEEN_FILE)

static func seen() -> bool:
	var config := ConfigFile.new()
	return config.load(SEEN_FILE) == OK and config.get_value("help", "seen", false)

func show_page(index: int) -> void:
	page = clampi(index, 0, PAGES.size() - 1)
	var entry: Dictionary = PAGES[page]
	var path := "res://assets/ui/howto/%s.jpg" % entry.picture
	picture.texture = load(path) if ResourceLoader.exists(path) else null
	title.text = entry.title
	body.text = entry.text
	counter.text = "%d / %d" % [page + 1, PAGES.size()]
	for child in keys.get_children():
		keys.remove_child(child)
		child.queue_free()
	for key in entry["keys"]:
		var chip := Label.new()
		chip.text = key
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.custom_minimum_size = Vector2(maxf(44, key.length() * 11 + 22), 32)
		chip.add_theme_font_size_override("font_size", 14)
		chip.add_theme_color_override("font_color", Color("0f172a"))
		var style := _round(Color.WHITE, 6)
		style.border_color = Color("94a3b8")
		style.set_border_width_all(2)
		style.border_width_bottom = 4
		chip.add_theme_stylebox_override("normal", style)
		keys.add_child(chip)
	for dot_index in range(dots.get_child_count()):
		var dot: Panel = dots.get_child(dot_index)
		dot.add_theme_stylebox_override("panel", _round(Color("0f766e") if dot_index == page else Color("cbd5e1"), 5))
	back_button.disabled = page == 0
	next_button.text = "Start playing" if page == PAGES.size() - 1 else "Next"

func _next() -> void:
	if page >= PAGES.size() - 1: close()
	else: show_page(page + 1)

func close() -> void:
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE, KEY_F1: close()
		KEY_RIGHT, KEY_ENTER, KEY_SPACE: _next()
		KEY_LEFT: show_page(page - 1)
		_: return
	get_viewport().set_input_as_handled()
