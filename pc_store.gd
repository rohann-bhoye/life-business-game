extends Panel

# "APNA Wholesale" — a shopping-website style order screen on the management PC.
# Category filters, product cards with pictures, and a cart so several different
# products can be ordered in one go (business.order_cart). Kenney UI Pack styling.
# Furniture shows racks the same way: a picture card with an Order button (the
# furniture truck brings the package to the warehouse; unpack it there with E).
signal back_requested

const Catalog = preload("res://product_catalog.gd")
const KenneyTheme = preload("res://kenney_theme.gd")
const CATEGORIES := [
	["All products", []],
	["Groceries", ["snack", "oil", "milk", "bread", "chocolate", "honey"]],
	["Fresh produce", ["tomato", "carrot", "cabbage", "corn", "apple"]],
	["Household", ["bottle", "soap"]],
	["Furniture", ["rack_shelf", "rack_produce", "rack_fridge"]],
]
## Furniture cards: [id, name, what it holds].
const FURNITURE := [["rack_shelf", "Shelf rack", "3 rows, any product"], ["rack_produce", "Produce table", "12 veg baskets"], ["rack_fridge", "Cold-drink fridge", "Drinks + milk, sells more"]]
## The rack product each furniture card orders (a shelf takes the first product
## without its own restock rack; see _shelf_product).
const FURNITURE_PRODUCT := {"rack_produce": "tomato", "rack_fridge": "bottle"}
const SIZE := Vector2(912, 468)

var business
var format_money: Callable
var cart := {}
var category := 0
var grid: GridContainer
var cart_list: VBoxContainer
var category_buttons: Array[Button] = []
var money_label: Label
var cart_title: Label
var totals_label: Label
var status_label: Label
var order_button: Button
var clear_button: Button
var cards := {}
var furniture_cards := {}

func setup(business_ref, money_formatter: Callable) -> void:
	business = business_ref
	format_money = money_formatter
	name = "WholesaleStore"
	size = SIZE
	# Fill the theme before assigning it: every change to an assigned theme re-themes
	# the whole page on the next frame (that made loading the game take ~20 s longer).
	var page_theme := Theme.new()
	page_theme.default_font_size = 15
	KenneyTheme.apply(page_theme)
	theme = page_theme
	add_theme_stylebox_override("panel", _flat(Color("f3f4f6"), 12))
	_build_header()
	_build_sidebar()
	_build_products()
	_build_cart()
	business.changed.connect(refresh)
	select_category(0)

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
	parent.add_child(label)
	return label

func _button(text: String, rect: Rect2, variation := "", parent: Node = self) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.theme_type_variation = variation
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button

func _build_header() -> void:
	var bar := Panel.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(SIZE.x, 58)
	bar.add_theme_stylebox_override("panel", _flat(Color("15803d"), 12))
	add_child(bar)
	var logo := _label("APNA WHOLESALE", Vector2(18, 8), 320, 26, Color.WHITE, bar)
	logo.add_theme_font_override("font", KenneyTheme.heading_font())
	_label("Wholesale stock for your shop | delivered to your warehouse", Vector2(20, 38), 420, 11, Color("dcfce7"), bar)
	money_label = _label("", Vector2(470, 18), 260, 16, Color.WHITE, bar)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var back := _button("Back", Rect2(748, 12, 146, 36), "", bar)
	back.name = "BackButton"
	back.pressed.connect(func(): back_requested.emit())

func _build_sidebar() -> void:
	var heading := _label("CATEGORIES", Vector2(16, 70), 150, 15, KenneyTheme.GREEN)
	heading.add_theme_font_override("font", KenneyTheme.heading_font())
	for index in range(CATEGORIES.size()):
		var button := _button(CATEGORIES[index][0], Rect2(14, 98 + index * 46, 152, 40))
		button.name = "Category%d" % index
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(select_category.bind(index))
		category_buttons.append(button)
	var deal := Panel.new()
	deal.position = Vector2(14, 336)
	deal.size = Vector2(152, 116)
	deal.add_theme_stylebox_override("panel", KenneyTheme.button_box("yellow"))
	add_child(deal)
	var title := _label("BULK DEAL", Vector2(10, 10), 132, 18, Color("713f12"), deal)
	title.add_theme_font_override("font", KenneyTheme.heading_font())
	var text := Label.new()
	text.text = "Order 5 or more boxes of one product and get 10% off that line."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 13)
	text.add_theme_color_override("font_color", Color("713f12"))
	deal.add_child(text)
	text.position = Vector2(10, 36)
	text.size = Vector2(132, 76)

func _build_products() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "ProductScroll"
	scroll.position = Vector2(178, 68)
	scroll.size = Vector2(474, 390)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	grid = GridContainer.new()
	grid.name = "ProductGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for id in Catalog.IDS:
		var card := Panel.new()
		card.name = "Card_" + id
		card.custom_minimum_size = Vector2(150, 196)
		grid.add_child(card)
		var image := TextureRect.new()
		image.texture = load("res://assets/ui/products/%s.png" % id)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.position = Vector2(25, 6)
		image.size = Vector2(100, 92)
		card.add_child(image)
		var title := _label(Catalog.NAMES[id], Vector2(8, 98), 134, 15, KenneyTheme.TEXT, card)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var price := _label("", Vector2(8, 120), 134, 14, KenneyTheme.GREEN, card)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var stock := _label("", Vector2(8, 140), 134, 11, KenneyTheme.MUTED, card)
		stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var add := _button("Add to cart", Rect2(12, 158, 126, 32), "PrimaryButton", card)
		add.name = "AddButton"
		add.pressed.connect(add_to_cart.bind(id))
		cards[id] = {"card": card, "price": price, "stock": stock, "add": add}
	for entry in FURNITURE:
		var card := Panel.new()
		card.name = "Card_" + entry[0]
		card.custom_minimum_size = Vector2(150, 196)
		grid.add_child(card)
		var image := TextureRect.new()
		image.texture = load("res://assets/ui/products/%s.png" % entry[0])
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.position = Vector2(25, 6)
		image.size = Vector2(100, 84)
		card.add_child(image)
		var title := _label(entry[1], Vector2(8, 88), 134, 15, KenneyTheme.TEXT, card)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var about := _label(entry[2], Vector2(8, 108), 134, 11, KenneyTheme.MUTED, card)
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var price := _label("", Vector2(8, 124), 134, 14, KenneyTheme.GREEN, card)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var stock := _label("", Vector2(8, 142), 134, 11, KenneyTheme.MUTED, card)
		stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var order := _button("Order", Rect2(12, 158, 126, 32), "PrimaryButton", card)
		order.name = "OrderButton"
		order.pressed.connect(order_furniture.bind(entry[0]))
		furniture_cards[entry[0]] = {"card": card, "price": price, "stock": stock, "order": order}

func _build_cart() -> void:
	var panel := Panel.new()
	panel.name = "Cart"
	panel.position = Vector2(662, 68)
	panel.size = Vector2(236, 390)
	add_child(panel)
	cart_title = _label("", Vector2(12, 10), 212, 16, KenneyTheme.GREEN, panel)
	cart_title.add_theme_font_override("font", KenneyTheme.heading_font())
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 38)
	scroll.size = Vector2(220, 186)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	cart_list = VBoxContainer.new()
	cart_list.custom_minimum_size.x = 210
	cart_list.add_theme_constant_override("separation", 4)
	scroll.add_child(cart_list)
	totals_label = _label("", Vector2(12, 228), 212, 13, KenneyTheme.TEXT, panel)
	totals_label.size.y = 58
	totals_label.clip_text = false
	status_label = _label("", Vector2(12, 286), 212, 12, KenneyTheme.MUTED, panel)
	status_label.size.y = 34
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.clip_text = false
	order_button = _button("Place order", Rect2(10, 322, 216, 38), "PrimaryButton", panel)
	order_button.name = "PlaceOrderButton"
	order_button.pressed.connect(place_order)
	clear_button = _button("Clear cart", Rect2(10, 362, 216, 24), "", panel)
	clear_button.add_theme_font_size_override("font_size", 12)
	clear_button.pressed.connect(func():
		cart.clear()
		status_label.text = ""
		refresh())

func select_category(index: int) -> void:
	category = index
	for button_index in range(category_buttons.size()):
		category_buttons[button_index].theme_type_variation = "PrimaryButton" if button_index == index else ""
	var allowed: Array = CATEGORIES[index][1]
	for id in cards: cards[id].card.visible = allowed.is_empty() or id in allowed
	for id in furniture_cards: furniture_cards[id].card.visible = id in allowed
	refresh()

## A shelf rack is for the first product without its own restock rack yet, so the
## stock helper (Sunil) knows where new boxes go; a produce table holds tomatoes.
func _shelf_product() -> String:
	for id in Catalog.IDS:
		if id == "tomato": continue
		if business.RackStore.display_for(id) != "shelf": continue
		if not business.racks.records.any(func(record): return record.product == id and record.get("restock", false)): return id
	return "snack"

func order_furniture(kind: String) -> bool:
	var success: bool = business.order_racks(FURNITURE_PRODUCT.get(kind, _shelf_product()), 1)
	status_label.text = "Rack ordered: the furniture truck brings it to your warehouse. Unpack it there with E." if success else "Cannot order: check money and the rack limit (%d)." % business.rack_limit()
	status_label.add_theme_color_override("font_color", KenneyTheme.GREEN if success else Color("b91c1c"))
	refresh()
	return success

func add_to_cart(id: String, boxes := 1) -> void:
	cart[id] = clampi(int(cart.get(id, 0)) + boxes, 0, 10)
	if cart[id] == 0: cart.erase(id)
	status_label.text = ""
	refresh()

func cart_boxes() -> int:
	var total := 0
	for id in cart: total += int(cart[id])
	return total

func cart_total() -> int:
	var total := 0
	for id in cart: total += business.order_cost(id, cart[id])
	return total

func place_order() -> bool:
	if cart.is_empty(): return false
	var boxes := cart_boxes()
	var success: bool = business.order_cart(cart)
	if success:
		cart.clear()
		status_label.text = "Order placed: %d box%s on the way to your warehouse." % [boxes, "" if boxes == 1 else "es"]
		status_label.add_theme_color_override("font_color", KenneyTheme.GREEN)
	else:
		status_label.text = "Cannot order: check money and the 20-box supply limit."
		status_label.add_theme_color_override("font_color", Color("b91c1c"))
	refresh()
	return success

func _money(value: int) -> String:
	return String.chr(8377) + (format_money.call(value) if format_money.is_valid() else str(value))

func refresh() -> void:
	if business == null: return
	money_label.text = "Money: " + _money(business.money)
	for id in cards:
		var entry: Dictionary = cards[id]
		entry.price.text = "%s / box of 10" % _money(Catalog.COSTS[id])
		entry.stock.text = "Shelf %d  |  Warehouse %d" % [business.product_stock(id), business.logistics.stored_units(id)]
		# Products need their own kind of rack in new games: warn before buying.
		var store = business.RackStore
		var fits: bool = business.racks.records.any(func(record): return store.holds(record, id, business.racks.strict))
		entry.stock.add_theme_color_override("font_color", KenneyTheme.MUTED if fits else Color("b91c1c"))
		if not fits: entry.stock.text = {"fridge": "Needs a fridge", "produce": "Needs a produce table"}.get(store.display_for(id), "Needs a shelf rack")
		entry.add.text = "In cart: %d  +1" % cart[id] if cart.has(id) else "Add to cart"
	var owned: int = business.racks.records.size() + business.logistics.rack_count()
	for id in furniture_cards:
		var entry: Dictionary = furniture_cards[id]
		entry.price.text = "%s each" % _money(business.RackStore.COST)
		entry.stock.text = "Racks %d / %d  |  Coming %d" % [owned, business.rack_limit(), business.logistics.rack_count()]
		entry.order.disabled = not business.can_order_racks(FURNITURE_PRODUCT.get(id, _shelf_product()), 1)
		entry.order.text = "Rack limit" if owned >= business.rack_limit() else "Order"
	for child in cart_list.get_children():
		cart_list.remove_child(child)
		child.queue_free()
	var full := 0
	for id in Catalog.IDS:
		if not cart.has(id): continue
		full += Catalog.COSTS[id] * int(cart[id])
		var row := Control.new()
		row.custom_minimum_size = Vector2(210, 42)
		cart_list.add_child(row)
		var line := _label("%s x%d" % [Catalog.NAMES[id], cart[id]], Vector2(2, 0), 140, 13, KenneyTheme.TEXT, row)
		line.name = "Line_" + id
		var cost := _label(_money(business.order_cost(id, cart[id])) + ("  -10%" if int(cart[id]) >= business.BULK_BOXES else ""), Vector2(2, 20), 140, 12, KenneyTheme.GREEN, row)
		cost.name = "Cost_" + id
		var minus := _button("-", Rect2(146, 4, 30, 30), "", row)
		minus.pressed.connect(add_to_cart.bind(id, -1))
		var plus := _button("+", Rect2(180, 4, 30, 30), "", row)
		plus.pressed.connect(add_to_cart.bind(id, 1))
	var boxes := cart_boxes()
	var total := cart_total()
	cart_title.text = "YOUR CART (%d)" % boxes
	totals_label.text = "Items: %d | Boxes: %d\nDiscount: %s\nTotal: %s" % [boxes * 10, boxes, _money(full - total), _money(total)]
	var room: int = business.MAX_SUPPLY_BOXES - business.supply_box_count()
	order_button.disabled = cart.is_empty() or total > business.money or boxes > room
	if not cart.is_empty() and status_label.text == "":
		status_label.text = "Not enough money." if total > business.money else ("Only %d more boxes fit in delivery." % room if boxes > room else "Ready to order.")
		status_label.add_theme_color_override("font_color", KenneyTheme.MUTED)
