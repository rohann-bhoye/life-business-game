extends Panel

# "APNA BUSINESS" page on the management PC: today's numbers, pay bills, marketing and
# the shop level upgrade. These used to live on the Tab tablet; the labels and buttons
# call straight into ShopArea / GameUi so the rules stay in one place.
signal back_requested

const KenneyTheme = preload("res://kenney_theme.gd")
const SIZE := Vector2(912, 468)
var business
var format_money: Callable
var shop
var ui
var numbers_label: Label
var bills_label: Label
var marketing_label: Label
var level_label: Label
var pay_button: Button
var marketing_button: Button
var upgrade_button: Button

func setup(business_ref, money_formatter: Callable, shop_ref, ui_ref) -> void:
	business = business_ref
	format_money = money_formatter
	shop = shop_ref
	ui = ui_ref
	name = "BusinessPage"
	size = SIZE
	var page_theme := Theme.new()
	page_theme.default_font_size = 16
	KenneyTheme.apply(page_theme)
	theme = page_theme
	add_theme_stylebox_override("panel", _flat(Color("fff7ed"), 12))
	var bar := Panel.new()
	bar.size = Vector2(SIZE.x, 58)
	bar.add_theme_stylebox_override("panel", _flat(Color("c2410c"), 12))
	add_child(bar)
	var logo := _label("APNA BUSINESS", Vector2(18, 8), 360, 26, Color.WHITE, bar)
	logo.add_theme_font_override("font", KenneyTheme.heading_font())
	_label("Today's numbers, bills, marketing and shop level", Vector2(20, 38), 460, 11, Color("ffedd5"), bar)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.position = Vector2(748, 12)
	back.size = Vector2(146, 36)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): back_requested.emit())
	bar.add_child(back)
	var today := _card(Vector2(20, 76), Vector2(420, 190), "TODAY")
	numbers_label = _label("", Vector2(16, 44), 388, 16, KenneyTheme.TEXT, today)
	numbers_label.size.y = 136
	numbers_label.clip_text = false
	var bills := _card(Vector2(20, 280), Vector2(420, 170), "BILLS")
	bills_label = _label("", Vector2(16, 44), 388, 16, KenneyTheme.TEXT, bills)
	bills_label.size.y = 50
	bills_label.clip_text = false
	pay_button = _button("PayBillsButton", Vector2(16, 108), Vector2(388, 44), bills)
	pay_button.theme_type_variation = "PrimaryButton"
	pay_button.pressed.connect(func(): shop._on_pay_bills_pressed())
	var marketing := _card(Vector2(460, 76), Vector2(432, 214), "MARKETING")
	marketing_label = _label("", Vector2(16, 44), 400, 15, KenneyTheme.TEXT, marketing)
	marketing_label.size.y = 100
	marketing_label.clip_text = false
	marketing_button = _button("MarketingButton", Vector2(16, 150), Vector2(400, 44), marketing)
	marketing_button.theme_type_variation = "PrimaryButton"
	marketing_button.pressed.connect(func(): shop._on_marketing_button_pressed())
	var level := _card(Vector2(460, 304), Vector2(432, 146), "SHOP LEVEL")
	level_label = _label("", Vector2(16, 44), 400, 15, KenneyTheme.TEXT, level)
	level_label.size.y = 40
	level_label.clip_text = false
	upgrade_button = _button("UpgradeButton", Vector2(16, 90), Vector2(400, 42), level)
	upgrade_button.theme_type_variation = "InfoButton"
	upgrade_button.pressed.connect(func(): ui._on_upgrade_pressed())
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
	parent.add_child(label)
	return label

func _card(position: Vector2, card_size: Vector2, title: String) -> Panel:
	var card := Panel.new()
	card.position = position
	card.size = card_size
	add_child(card)
	var heading := _label(title, Vector2(16, 12), card_size.x - 32, 16, Color("c2410c"), card)
	heading.add_theme_font_override("font", KenneyTheme.heading_font())
	return card

func _button(button_name: String, position: Vector2, button_size: Vector2, parent: Node) -> Button:
	var button := Button.new()
	button.name = button_name
	button.position = position
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button

func _money(value: int) -> String:
	return String.chr(8377) + (format_money.call(value) if format_money.is_valid() else str(value))

func refresh() -> void:
	if business == null or not is_instance_valid(shop): return
	numbers_label.text = "%s\n%s\n%s\n%s\n%s" % [shop.stock_label.text, shop.sales_label.text, shop.revenue_label.text, shop.expenses_label.text, shop.profit_label.text]
	bills_label.text = "%s\n%s" % [shop.daily_cost_label.text, shop.unpaid_bills_label.text]
	pay_button.text = "Pay bills - %s" % _money(business.unpaid_bills()) if business.unpaid_bills() > 0 else "No unpaid bills"
	pay_button.disabled = not business.can_pay_bills()
	marketing_label.text = "%s\n%s\n%s\n%s" % [shop.marketing_label.text, shop.missed_sales_label.text, shop.last_visit_label.text, ui.shop_menu.get_node("ReputationLabel").text]
	marketing_button.text = "Marketing active" if shop.marketing_active else "Start marketing - %s" % _money(shop.MARKETING_COST)
	marketing_button.disabled = shop.marketing_active or business.money < shop.MARKETING_COST
	level_label.text = ui.shop_level_label.text
	var cost: int = business.next_upgrade_cost()
	upgrade_button.text = "Maximum level" if cost == 0 else "Upgrade shop - %s" % _money(cost)
	upgrade_button.disabled = cost == 0 or business.money < cost

var tick := 0.0

func _process(delta: float) -> void:
	if not visible: return
	tick += delta
	if tick >= 0.5:
		tick = 0.0
		refresh()
