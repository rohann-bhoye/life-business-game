extends Panel

# "APNA EXPORT" site on the management PC: international orders (export_store.gd).
# Each order is a card: the city, the buyer and their note, the products with
# pictures, what the buyer pays and a button to accept it. Accepted orders show what
# to do next: pack at the prepare-order table in the packing room (left of the shop),
# then carry the parcel to the export platform at the airport for the next flight.
signal back_requested

const KenneyTheme = preload("res://kenney_theme.gd")
const Catalog = preload("res://product_catalog.gd")
const ExportStore = preload("res://export_store.gd")
const SIZE := Vector2(912, 468)
const BRAND := Color("1e3a8a")
const STATE_COLOURS := {"offer": Color("2563eb"), "accepted": Color("ea580c"), "packed": Color("16a34a"), "on_pad": Color("7c3aed")}
const STATE_TEXT := {"accepted": "PACK IT: PACKING ROOM", "packed": "TAKE TO THE AIRPORT", "on_pad": "WAITING FOR THE PLANE"}
var business
var format_money: Callable
var summary: Label
var money_label: Label
var status_label: Label
var cards: Array = []

func setup(business_ref, money_formatter: Callable) -> void:
	business = business_ref
	format_money = money_formatter
	name = "ExportPage"
	size = SIZE
	# Fill the theme before assigning it (see bank_page.gd).
	var page_theme := Theme.new()
	page_theme.default_font_size = 15
	KenneyTheme.apply(page_theme)
	theme = page_theme
	add_theme_stylebox_override("panel", _flat(Color("eff6ff"), 12))
	var bar := Panel.new()
	bar.size = Vector2(SIZE.x, 58)
	bar.add_theme_stylebox_override("panel", _flat(BRAND, 12))
	add_child(bar)
	var logo := _label("APNA EXPORT", Vector2(18, 8), 360, 26, Color.WHITE, bar)
	logo.add_theme_font_override("font", KenneyTheme.heading_font())
	_label("International orders | packed in your shop, flown by APNA AIR CARGO", Vector2(20, 38), 520, 11, Color("dbeafe"), bar)
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
	summary = _label("", Vector2(14, 8), 844, 14, KenneyTheme.TEXT, strip)
	for index in range(ExportStore.MAX_OFFERS + ExportStore.MAX_ACTIVE): cards.append(_card(Vector2(20 + index * 175, 118)))
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

func _card(at: Vector2) -> Dictionary:
	var card := Panel.new()
	card.position = at
	card.size = Vector2(167, 316)
	card.add_theme_stylebox_override("panel", _flat(Color.WHITE, 10))
	add_child(card)
	var band := Panel.new()
	band.size = Vector2(167, 46)
	card.add_child(band)
	var city := _label("", Vector2(10, 4), 150, 18, Color.WHITE, band)
	city.add_theme_font_override("font", KenneyTheme.heading_font())
	var country := _label("", Vector2(10, 26), 150, 11, Color("e0e7ff"), band)
	var buyer := _label("", Vector2(10, 52), 150, 14, KenneyTheme.TEXT, card)
	var note := _label("", Vector2(10, 72), 150, 11, KenneyTheme.MUTED, card)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.clip_text = false
	note.size.y = 30
	var items: Array = []
	for index in range(3):
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(10, 108 + index * 34)
		icon.size = Vector2(28, 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		items.append({"icon": icon, "text": _label("", Vector2(42, 112 + index * 34), 122, 12, KenneyTheme.TEXT, card)})
	var reward := _label("", Vector2(10, 214), 150, 22, KenneyTheme.GREEN, card)
	reward.add_theme_font_override("font", KenneyTheme.heading_font())
	var ends := _label("", Vector2(10, 244), 150, 11, KenneyTheme.MUTED, card)
	var button := Button.new()
	button.position = Vector2(10, 268)
	button.size = Vector2(147, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	card.add_child(button)
	var entry := {"card": card, "band": band, "city": city, "country": country, "buyer": buyer, "note": note, "items": items, "reward": reward, "ends": ends, "button": button, "id": -1}
	button.pressed.connect(func(): _accept(int(entry.id)))
	return entry

func _money(value: int) -> String:
	return String.chr(8377) + (format_money.call(value) if format_money.is_valid() else str(value))

## Opening the page fills the offers on a new game (later, each morning does).
func open() -> void:
	if business.exports.in_state("offer").is_empty(): business.refresh_export_offers()
	status_label.text = ""
	refresh()

func _accept(id: int) -> void:
	var success: bool = business.export_accept(id)
	status_label.text = "Order accepted! Fill a carton at the racks and seal it at the packing table (packing room, left of the shop)." if success else "You can work on %d export orders at a time." % ExportStore.MAX_ACTIVE
	status_label.add_theme_color_override("font_color", KenneyTheme.GREEN if success else Color("b91c1c"))
	refresh()

func next_flight_text() -> String:
	var minutes := int(business.minutes_of_day)
	for slot in ExportStore.FLIGHTS:
		if slot > minutes: return "%02d:%02d" % [slot / 60, slot % 60]
	return "tomorrow %02d:00" % (ExportStore.FLIGHTS[0] / 60)

func refresh() -> void:
	if business == null: return
	var exports = business.exports
	money_label.text = "Money: " + _money(business.money)
	summary.text = "Shipped %d parcel%s  |  Earned %s  |  Next flight %s  |  Pack in the packing room, left of the shop" % [exports.shipped, "" if exports.shipped == 1 else "s", _money(exports.earned), next_flight_text()]
	var shown: Array = exports.active() + exports.in_state("offer")
	var busy: bool = exports.active().size() >= ExportStore.MAX_ACTIVE
	for index in range(cards.size()):
		var entry: Dictionary = cards[index]
		entry.card.visible = index < shown.size()
		if not entry.card.visible: continue
		var order: Dictionary = shown[index]
		entry.id = int(order.id)
		entry.band.add_theme_stylebox_override("panel", _flat(STATE_COLOURS[order.state], 10))
		entry.city.text = order.city.to_upper()
		entry.country.text = order.country + ("  |  OFFER" if order.state == "offer" else "  |  ACCEPTED")
		entry.buyer.text = order.buyer
		entry.note.text = order.note
		for line_index in range(3):
			var item: Dictionary = entry.items[line_index]
			var has_line: bool = line_index < order.lines.size()
			item.icon.visible = has_line
			item.text.visible = has_line
			if not has_line: continue
			var line: Dictionary = order.lines[line_index]
			item.icon.texture = load("res://assets/ui/products/%s.png" % line.product)
			item.text.text = "x%d  %s" % [line.count, Catalog.NAMES[line.product]]
		entry.reward.text = _money(int(order.value))
		entry.ends.text = "Offer ends after day %d" % int(order.expires) if order.state in ["offer", "accepted"] else "%d items packed" % ExportStore.units(order)
		entry.button.text = "ACCEPT ORDER" if order.state == "offer" else STATE_TEXT[order.state]
		entry.button.theme_type_variation = "PrimaryButton" if order.state == "offer" else ""
		entry.button.disabled = order.state != "offer" or busy
	if shown.is_empty(): summary.text += "\nNo orders today. New buyers write every morning."
