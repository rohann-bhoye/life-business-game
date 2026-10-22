extends Panel

# "APNA LICENCES" on the management PC: one card per product licence
# (business_backend.gd LICENCES). A card shows the products it opens, how many,
# their average shop price, the price of the licence and a Buy button (Owned once
# bought, or what it still needs). Owned products can be ordered on APNA Wholesale
# and buyers abroad (APNA Export) can ask for them.
signal back_requested

const KenneyTheme = preload("res://kenney_theme.gd")
const Catalog = preload("res://product_catalog.gd")
const SIZE := Vector2(912, 468)
const BRAND := Color("7c3aed")
const COLOURS := {"basics": Color("16a34a"), "dairy": Color("0ea5e9"), "packaged": Color("ea580c"), "fresh": Color("65a30d")}
const LEVEL_NAMES := ["", "Apna Mart", "Super Store", "Mega Mart"]
var business
var format_money: Callable
var money_label: Label
var status_label: Label
var cards: Array = []

func setup(business_ref, money_formatter: Callable) -> void:
	business = business_ref
	format_money = money_formatter
	name = "LicencePage"
	size = SIZE
	# Fill the theme before assigning it (see bank_page.gd).
	var page_theme := Theme.new()
	page_theme.default_font_size = 15
	KenneyTheme.apply(page_theme)
	theme = page_theme
	add_theme_stylebox_override("panel", _flat(Color("f5f3ff"), 12))
	var bar := Panel.new()
	bar.size = Vector2(SIZE.x, 58)
	bar.add_theme_stylebox_override("panel", _flat(BRAND, 12))
	add_child(bar)
	var logo := _label("APNA LICENCES", Vector2(18, 8), 360, 26, Color.WHITE, bar)
	logo.add_theme_font_override("font", KenneyTheme.heading_font())
	_label("Product licences | order more kinds of goods and sell them abroad", Vector2(20, 38), 520, 11, Color("ede9fe"), bar)
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
	_label("Own a licence to order its products on APNA Wholesale. Buyers abroad (APNA Export) only ask for licensed goods on your shelves.", Vector2(14, 9), 844, 13, KenneyTheme.TEXT, strip)
	for index in range(business.LICENCES.size()): cards.append(_card(business.LICENCES[index], Vector2(20 + index * 220, 118)))
	status_label = _label("", Vector2(20, 442), 872, 13, KenneyTheme.GREEN)
	business.changed.connect(refresh)
	refresh()

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

func _card(entry: Dictionary, at: Vector2) -> Dictionary:
	var card := Panel.new()
	card.name = "Licence_" + entry.id
	card.position = at
	card.size = Vector2(212, 316)
	card.add_theme_stylebox_override("panel", _flat(Color.WHITE, 10))
	add_child(card)
	var band := Panel.new()
	band.size = Vector2(212, 50)
	band.add_theme_stylebox_override("panel", _flat(COLOURS.get(entry.id, BRAND), 10))
	card.add_child(band)
	var title := _label(entry.name.to_upper(), Vector2(12, 6), 190, 16, Color.WHITE, band)
	title.add_theme_font_override("font", KenneyTheme.heading_font())
	var state := _label("", Vector2(12, 28), 190, 11, Color("f0fdf4"), band)
	for index in range(entry.products.size()):
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ui/products/%s.png" % entry.products[index])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(12 + (index % 3) * 64, 60 + (index / 3) * 58)
		icon.size = Vector2(56, 52)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
	var names: Array[String] = []
	var total := 0
	for product in entry.products:
		names.append(Catalog.NAMES[product])
		total += business.product_price(product)
	var list := _label(", ".join(names), Vector2(12, 178), 190, 11, KenneyTheme.MUTED, card)
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.clip_text = false
	list.size.y = 30
	_label("Items included", Vector2(12, 212), 120, 13, KenneyTheme.TEXT, card)
	_label(str(entry.products.size()), Vector2(140, 212), 60, 13, KenneyTheme.TEXT, card).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label("Average price", Vector2(12, 232), 120, 13, KenneyTheme.TEXT, card)
	var average := _label(_money(total / entry.products.size()), Vector2(140, 232), 60, 13, KenneyTheme.TEXT, card)
	average.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var price := _label("", Vector2(12, 252), 190, 18, KenneyTheme.GREEN, card)
	price.add_theme_font_override("font", KenneyTheme.heading_font())
	var button := Button.new()
	button.position = Vector2(12, 272)
	button.size = Vector2(188, 36)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(_buy.bind(entry.id))
	card.add_child(button)
	return {"entry": entry, "state": state, "price": price, "button": button}

func _buy(id: String) -> void:
	var success: bool = business.buy_licence(id)
	var entry: Dictionary = business.licence(id)
	status_label.text = "%s licence bought! Order its products on APNA Wholesale." % entry.name if success else "Cannot buy the %s licence yet." % entry.name
	status_label.add_theme_color_override("font_color", KenneyTheme.GREEN if success else Color("b91c1c"))
	refresh()

func refresh() -> void:
	if business == null: return
	money_label.text = "Money: " + _money(business.money)
	for card in cards:
		var entry: Dictionary = card.entry
		var owned: bool = business.licences.has(entry.id)
		var level_ok: bool = business.shop_level >= int(entry.level)
		card.state.text = "OWNED" if owned else ("LOCKED: needs %s" % LEVEL_NAMES[int(entry.level)] if not level_ok else "NOT OWNED")
		card.price.text = "FREE" if int(entry.price) == 0 else _money(int(entry.price))
		card.button.disabled = not business.can_buy_licence(entry.id)
		card.button.theme_type_variation = "" if owned else "PrimaryButton"
		if owned: card.button.text = "OWNED"
		elif not level_ok: card.button.text = "NEEDS %s" % LEVEL_NAMES[int(entry.level)].to_upper()
		elif business.money < int(entry.price): card.button.text = "NOT ENOUGH MONEY"
		else: card.button.text = "BUY LICENCE"
