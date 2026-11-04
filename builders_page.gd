extends Panel

# "APNA BUILDERS" website on the management PC, with two pages in its menu bar:
# SPACE - the two back expansions (the back wall moves onto the plot behind the shop) and
#   the two side wings (the shop opens east over the plot beside it: Side Wing, then Super
#   Hall; they need both back rooms, a good rating and the town's word);
# MAKEOVERS - the Super Store and Mega Mart looks (more customers).
# Each offer is a card with a picture from the game (tools/pc_builder_pictures.gd,
# tools/wing_views.gd), what you get, the price and a button that says Built / Done once
# bought, or what is still needed.
signal back_requested

const KenneyTheme = preload("res://kenney_theme.gd")
const SIZE := Vector2(912, 468)
const BRAND := Color("c2410c")
const OFFERS := [
	{"kind": "expand", "step": 0, "tag": "EXPANSION 1", "title": "Back Room", "picture": "res://assets/ui/pc/expand_1.jpg", "about": "+14 m2 of floor at the back.\nRoom for 2 more racks."},
	{"kind": "expand", "step": 1, "tag": "EXPANSION 2", "title": "Grand Hall", "picture": "res://assets/ui/pc/expand_2.jpg", "about": "+13 m2 more floor.\nRoom for 2 more racks."},
	{"kind": "wing", "step": 0, "tag": "SIDE WING", "title": "Side Wing", "picture": "res://assets/ui/pc/wing_1.jpg", "about": "+60 m2 east over the plot.\n4 more racks, more shoppers."},
	{"kind": "wing", "step": 1, "tag": "SIDE WING 2", "title": "Super Hall", "picture": "res://assets/ui/pc/wing_2.jpg", "about": "+60 m2 more: one big hall.\n4 more racks, the most shoppers."},
	{"kind": "look", "step": 2, "tag": "MAKEOVER", "title": "Super Store", "picture": "res://assets/ui/pc/look_2.jpg", "about": "Blue LED front, tiles, freezer.\nMore customers every day."},
	{"kind": "look", "step": 3, "tag": "MAKEOVER", "title": "Mega Mart", "picture": "res://assets/ui/pc/look_3.jpg", "about": "Maroon and gold, marble floor.\nThe most customers."},
]
var business
var format_money: Callable
var summary: Label
var money_label: Label
var status_label: Label
var cards: Array = []
## The website page shown: "space" or "looks".
var page := "space"
var nav: Dictionary = {}

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
	# The website's menu bar: its two pages, and the shop's numbers on the right.
	for entry in [["space", "SPACE"], ["looks", "MAKEOVERS"]]:
		var link := Button.new()
		link.name = "Nav_" + entry[0]
		link.text = entry[1]
		link.position = Vector2(6 + nav.size() * 124, 4)
		link.size = Vector2(118, 30)
		link.focus_mode = Control.FOCUS_NONE
		link.add_theme_font_size_override("font_size", 13)
		link.pressed.connect(show_page.bind(entry[0]))
		strip.add_child(link)
		nav[entry[0]] = link
	summary = _label("", Vector2(262, 9), 598, 13, KenneyTheme.TEXT, strip)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for index in range(OFFERS.size()): cards.append(_card(OFFERS[index], Vector2.ZERO))
	show_page(page)
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
	var tag := _label(offer.tag, Vector2(12, 8), 188, 12, BRAND if offer.kind == "expand" else (Color("0f766e") if offer.kind == "wing" else Color("7c3aed")), card)
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
	return {"offer": offer, "panel": card, "badge": badge, "price": price, "note": note, "button": button, "picture": picture}

## Shows one page of the website: "space" (expansions and wings) or "looks" (makeovers).
func show_page(target: String) -> void:
	page = target
	var slot := 0
	for card in cards:
		var shown: bool = (card.offer.kind in ["expand", "wing"]) == (page == "space")
		card.panel.visible = shown
		if shown:
			card.panel.position = Vector2(20 + slot * 220, 118)
			slot += 1
	for key in nav: nav[key].theme_type_variation = "PrimaryButton" if key == page else ""
	if business != null: refresh()

func _buy(offer: Dictionary) -> void:
	if offer.kind == "wing":
		var reason: String = business.wing_block_reason()
		if business.build_wing(): _show_status("Built! The %s is open: %d m2 with room for %d racks." % [offer.title, business.shop_floor_area(), business.rack_limit()], true)
		else: _show_status("%s: %s." % [offer.title, reason if not reason.is_empty() else "could not build it now"], false)
	elif offer.kind == "expand":
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
	summary.text = "%s  |  %d m2  |  Racks %d / %d  |  %s  |  Town: %s" % [_shop_name(), business.shop_floor_area(), business.racks.records.size(), business.rack_limit(), business.customer_reviews.rating_text().get_slice(" (", 0), business.popularity_name()]
	for card in cards:
		var offer: Dictionary = card.offer
		var done: bool
		var ready: bool
		var cost: int
		var needs: String
		# What still stops a ready offer (a side wing's rating and town's word, or money).
		var blocked := ""
		if offer.kind == "expand":
			done = business.shop_expansion > offer.step
			ready = business.shop_expansion == offer.step
			cost = business.EXPANSION_COSTS[offer.step]
			needs = "Build Back Room first"
		elif offer.kind == "wing":
			done = business.shop_wing > offer.step
			ready = business.shop_wing == offer.step and business.shop_expansion >= business.RackStore.MAX_EXPANSION
			cost = business.WING_COSTS[offer.step]
			needs = "Build the Side Wing first" if offer.step > 0 and business.shop_wing < offer.step else "Build the Grand Hall first"
			if ready: blocked = business.wing_block_reason()
		else:
			done = business.shop_level >= offer.step
			ready = business.shop_level == offer.step - 1
			cost = business.UPGRADE_COSTS[offer.step - 2]
			needs = "Get Super Store first"
		if blocked.is_empty() and ready and business.money < cost: blocked = "Not enough money yet"
		var building: bool = offer.kind in ["expand", "wing"]
		card.badge.visible = done
		card.badge.text = "BUILT" if building else "DONE"
		card.picture.modulate = Color.WHITE if done or ready else Color(1, 1, 1, 0.55)
		card.price.text = "Bought" if done else _money(cost)
		var button: Button = card.button
		button.theme_type_variation = "PrimaryButton" if ready and not done and blocked.is_empty() else ""
		button.text = ("Built" if building else "Done") if done else (("Build - " if building else "Upgrade - ") + _money(cost) if ready else "Locked")
		card.note.text = "" if done else (needs if not ready else blocked)
		button.disabled = done or not ready or not blocked.is_empty()
		button.tooltip_text = "" if done or not ready else (blocked if not blocked.is_empty() else "Pay %s" % _money(cost))

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
