extends Panel

# "APNA BUILDERS" site on the management PC: buy the two shop expansions (the back
# wall moves onto the plot behind the shop, more floor and racks) and the two shop
# makeovers (Super Store and Mega Mart looks, more customers). Each offer is a card
# with a picture from the game (tools/pc_builder_pictures.gd), what you get, the
# price and a button that says Built / Done once bought.
signal back_requested

const KenneyTheme = preload("res://kenney_theme.gd")
const SIZE := Vector2(912, 468)
const BRAND := Color("c2410c")
const OFFERS := [
	{"kind": "expand", "step": 0, "tag": "EXPANSION 1", "title": "Back Room", "picture": "res://assets/ui/pc/expand_1.jpg", "about": "+14 m2 of floor at the back.\nRoom for 2 more racks."},
	{"kind": "expand", "step": 1, "tag": "EXPANSION 2", "title": "Grand Hall", "picture": "res://assets/ui/pc/expand_2.jpg", "about": "+13 m2 more floor.\nRoom for 2 more racks."},
	{"kind": "look", "step": 2, "tag": "MAKEOVER", "title": "Super Store", "picture": "res://assets/ui/pc/look_2.jpg", "about": "Blue LED front, tiles, freezer.\nMore customers every day."},
	{"kind": "look", "step": 3, "tag": "MAKEOVER", "title": "Mega Mart", "picture": "res://assets/ui/pc/look_3.jpg", "about": "Maroon and gold, marble floor.\nThe most customers."},
]
var business
var format_money: Callable
var summary: Label
var money_label: Label
var status_label: Label
var cards: Array = []

func setup(business_ref, money_formatter: Callable) -> void:
	business = business_ref
	format_money = money_formatter
	name = "BuildersPage"
	size = SIZE
	# Fill the theme before assigning it (see bank_page.gd).
	var page_theme := Theme.new()
	page_theme.default_font_size = 16
	KenneyTheme.apply(page_theme)
	theme = page_theme
	add_theme_stylebox_override("panel", _flat(Color("fff7ed"), 12))
	var bar := Panel.new()
	bar.size = Vector2(SIZE.x, 58)
	bar.add_theme_stylebox_override("panel", _flat(BRAND, 12))
	add_child(bar)
	var logo := _label("APNA BUILDERS", Vector2(18, 8), 360, 26, Color.WHITE, bar)
	logo.add_theme_font_override("font", KenneyTheme.heading_font())
	_label("Shop expansions and makeovers | We build while you sell", Vector2(20, 38), 460, 11, Color("ffedd5"), bar)
	money_label = _label("", Vector2(520, 16), 210, 18, Color.WHITE, bar)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.position = Vector2(748, 12)
	back.size = Vector2(146, 36)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): back_requested.emit())
	bar.add_child(back)
	var strip := Panel.new()
	strip.position = Vector2(20, 70)
	strip.size = Vector2(872, 38)
	strip.add_theme_stylebox_override("panel", _flat(Color.WHITE, 10))
	add_child(strip)
	summary = _label("", Vector2(14, 7), 844, 15, KenneyTheme.TEXT, strip)
	for index in range(OFFERS.size()): cards.append(_card(OFFERS[index], Vector2(20 + index * 220, 118)))
	status_label = _label("", Vector2(20, 442), 872, 13, KenneyTheme.GREEN)
	business.changed.connect(refresh)
	refresh()

func _card(offer: Dictionary, at: Vector2) -> Dictionary:
	var card := Panel.new()
	card.name = "Offer_" + offer.title.replace(" ", "")
	card.position = at
	card.size = Vector2(212, 318)
	card.add_theme_stylebox_override("panel", _flat(Color.WHITE, 10))
	add_child(card)
	var tag := _label(offer.tag, Vector2(12, 8), 188, 12, BRAND if offer.kind == "expand" else Color("7c3aed"), card)
	tag.add_theme_font_override("font", KenneyTheme.heading_font())
	# The picture, cropped to the card like a website banner.
	var frame := Control.new()
	frame.position = Vector2(8, 30)
	frame.size = Vector2(196, 110)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.texture = load(offer.picture)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.size = frame.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(picture)
	var badge := _label("BUILT", Vector2(124, 6), 66, 12, Color.WHITE, frame)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", _flat(KenneyTheme.GREEN, 8))
	var title := _label(offer.title, Vector2(12, 146), 188, 18, KenneyTheme.TEXT, card)
	title.add_theme_font_override("font", KenneyTheme.heading_font())
	var about := _label(offer.about, Vector2(12, 174), 188, 12, KenneyTheme.MUTED, card)
	about.size.y = 44
	about.clip_text = false
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var price := _label("", Vector2(12, 216), 188, 18, KenneyTheme.GREEN, card)
	var note := _label("", Vector2(12, 240), 188, 11, Color("b45309"), card)
	var button := Button.new()
	button.name = "BuyButton"
	button.position = Vector2(12, 262)
	button.size = Vector2(188, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(_buy.bind(offer))
	card.add_child(button)
	return {"offer": offer, "badge": badge, "price": price, "note": note, "button": button, "picture": picture}

func _buy(offer: Dictionary) -> void:
	if offer.kind == "expand":
		if business.expand_shop(): _show_status("Built! Your shop is now %d m2 with room for %d racks." % [business.shop_floor_area(), business.rack_limit()], true)
		else: _show_status("Not enough money for the %s yet." % offer.title, false)
	else:
		if business.upgrade_shop(): _show_status("Makeover done: welcome to %s!" % _shop_name(), true)
		else: _show_status("Not enough money for the %s makeover yet." % offer.title, false)
	refresh()

func _shop_name() -> String:
	return ["Apna Mart", "Apna Super Mart", "Apna Mega Mart"][clampi(business.shop_level, 1, 3) - 1]

func refresh() -> void:
	if business == null: return
	money_label.text = "Money: " + _money(business.money)
	summary.text = "Your shop: %s  |  %d m2  |  Racks %d / %d  |  Expansions %d / %d  |  Level %d" % [_shop_name(), business.shop_floor_area(), business.racks.records.size(), business.rack_limit(), business.shop_expansion, business.EXPANSION_COSTS.size(), business.shop_level]
	for card in cards:
		var offer: Dictionary = card.offer
		var done: bool
		var ready: bool
		var cost: int
		var needs: String
		if offer.kind == "expand":
			done = business.shop_expansion > offer.step
			ready = business.shop_expansion == offer.step
			cost = business.EXPANSION_COSTS[offer.step]
			needs = "Build Back Room first"
		else:
			done = business.shop_level >= offer.step
			ready = business.shop_level == offer.step - 1
			cost = business.UPGRADE_COSTS[offer.step - 2]
			needs = "Get Super Store first"
		card.badge.visible = done
		card.badge.text = "BUILT" if offer.kind == "expand" else "DONE"
		card.picture.modulate = Color.WHITE if done or ready else Color(1, 1, 1, 0.55)
		card.price.text = "Bought" if done else _money(cost)
		var button: Button = card.button
		button.theme_type_variation = "PrimaryButton" if ready and not done else ""
		button.text = ("Built" if offer.kind == "expand" else "Done") if done else (("Build - " if offer.kind == "expand" else "Upgrade - ") + _money(cost) if ready else "Locked")
		card.note.text = needs if not done and not ready else ""
		button.disabled = done or not ready or business.money < cost
		button.tooltip_text = "" if done or not ready else ("Not enough money" if business.money < cost else "Pay %s" % _money(cost))

func _flat(colour: Color, radius := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	return style

func _label(text: String, position: Vector2, width: float, font_size := 14, colour := KenneyTheme.TEXT, parent: Node = self) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = Vector2(width, font_size + 8)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _money(value: int) -> String:
	return String.chr(8377) + (format_money.call(value) if format_money.is_valid() else str(value))

func _show_status(text: String, good: bool) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", KenneyTheme.GREEN if good else Color("b91c1c"))
