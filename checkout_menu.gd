extends Panel

# The checkout PC at the counter, laid out like a shop POS screen: a green header,
# the customer (initial avatar, kind of shopper, payment badge), a receipt with each
# product's picture, count and amount, a big total, a coloured status box (what to
# do / udhaar / wrong method) and big Cash, Card and UPI buttons.
const KenneyTheme = preload("res://kenney_theme.gd")
const METHOD_COLOURS := {"Cash": Color("16a34a"), "Card": Color("2563eb"), "UPI": Color("7c3aed")}
const AVATAR_COLOURS := [Color("f97316"), Color("0ea5e9"), Color("db2777"), Color("65a30d"), Color("9333ea")]
const STATUS_STYLES := {"info": [Color("e0f2fe"), Color("7dd3fc")], "warn": [Color("fef3c7"), Color("fbbf24")], "error": [Color("fee2e2"), Color("f87171")]}
var customer: Node3D
var customer_label: Label
var items_label: Label
var total_label: Label
var payment_label: Label
var scan_button: Button
var pay_button: Button
var payment_buttons := {}
var khata_button: Button
var refuse_button: Button
var wrong_payment_seconds := 0.0
var header: Panel
var avatar: Panel
var avatar_letter: Label
var badge: Panel
var badge_label: Label
var receipt: Panel
var rows: Array[Dictionary] = []
var status_box: Panel
var status_kind := ""
var width := 480.0
var avatar_colour := Color.TRANSPARENT
var badge_method := ""
@onready var ui = get_parent()
@onready var operations = get_tree().current_scene.get_node("ShopOperations")
@onready var player = get_tree().current_scene.get_node("Player")

func _ready() -> void:
	hide()
	player.checkout_menu = self
	add_theme_stylebox_override("panel", _flat(Color("f8fafc"), 14, Color("cbd5e1"), 2))
	header = Panel.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header_style := _flat(Color("15803d"), 14)
	header_style.corner_radius_bottom_left = 0
	header_style.corner_radius_bottom_right = 0
	header.add_theme_stylebox_override("panel", header_style)
	add_child(header)
	_text("TitleLabel", "APNA MART  POS", 20, Color.WHITE, header, true)
	_text("SubtitleLabel", "Checkout counter", 11, Color("bbf7d0"), header)
	var close := _button("CloseButton", close_menu)
	close.text = "CLOSE"
	_style_button(close, Color("166534"), 8, 12)
	avatar = Panel.new()
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(avatar)
	avatar_letter = _text("AvatarLetter", "", 22, Color.WHITE, avatar, true)
	avatar_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	customer_label = _text("CustomerLabel", "", 18, KenneyTheme.TEXT, self, true)
	items_label = _text("ItemsLabel", "", 13, KenneyTheme.MUTED)
	badge = Panel.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	badge_label = _text("BadgeLabel", "", 13, Color.WHITE, badge, true)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	receipt = Panel.new()
	receipt.name = "Receipt"
	receipt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt.add_theme_stylebox_override("panel", _flat(Color.WHITE, 10, Color("e2e8f0"), 1))
	add_child(receipt)
	for heading in [["ITEM", 44], ["QTY", -150], ["AMOUNT", -86]]:
		var column := _text("Column" + heading[0], heading[0], 11, KenneyTheme.MUTED, receipt)
		column.set_meta("x", heading[1])
	for index in range(3):
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		receipt.add_child(icon)
		var name_label := _text("Item%d" % index, "", 14, KenneyTheme.TEXT, receipt)
		var count := _text("Count%d" % index, "", 14, KenneyTheme.TEXT, receipt)
		var amount := _text("Amount%d" % index, "", 14, KenneyTheme.TEXT, receipt, true)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rows.append({"icon": icon, "name": name_label, "count": count, "amount": amount})
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = Color("e2e8f0")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt.add_child(rule)
	_text("TotalCaption", "TOTAL", 15, KenneyTheme.TEXT, receipt, true)
	total_label = _text("TotalLabel", "", 24, KenneyTheme.GREEN, receipt, true)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_box = Panel.new()
	status_box.name = "StatusBox"
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_box)
	payment_label = _text("PaymentLabel", "", 13, KenneyTheme.TEXT, status_box)
	payment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	payment_label.clip_text = false
	scan_button = _button("ScanButton", _scan)
	_style_button(scan_button, Color("475569"), 10)
	pay_button = _button("PaymentButton", _pay)
	pay_button.hide()
	for method in ["Cash", "Card", "UPI"]:
		var button := _button(method + "Button", _choose_payment.bind(method))
		button.text = method.to_upper()
		_style_button(button, METHOD_COLOURS[method], 12, 18)
		payment_buttons[method] = button
	khata_button = _button("KhataButton", _give_udhaar)
	_style_button(khata_button, Color("d97706"), 10)
	refuse_button = _button("RefuseUdhaarButton", _refuse_udhaar)
	refuse_button.text = "NO UDHAAR"
	_style_button(refuse_button, Color("64748b"), 10)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _flat(colour: Color, radius := 8, border := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	return style

func _text(node_name: String, value: String, font_size: int, colour: Color, parent: Node = self, heading := false) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	if heading: label.add_theme_font_override("font", KenneyTheme.heading_font())
	parent.add_child(label)
	return label

func _button(node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	button.pressed.connect(action)
	return button

## Flat coloured button with lighter hover, darker press and a faded disabled look.
func _style_button(button: Button, colour: Color, radius := 10, font_size := 14) -> void:
	button.add_theme_stylebox_override("normal", _flat(colour, radius))
	button.add_theme_stylebox_override("hover", _flat(colour.lightened(0.12), radius))
	button.add_theme_stylebox_override("pressed", _flat(colour.darkened(0.18), radius))
	button.add_theme_stylebox_override("disabled", _flat(colour.lerp(Color("cbd5e1"), 0.65), radius))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", KenneyTheme.heading_font())
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]: button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.75))

func _layout() -> void:
	width = minf(480, get_viewport().get_visible_rect().size.x - 32)
	ui._place(header, 0, 0, width, 54)
	ui._place(header.get_node("TitleLabel"), 16, 6, width - 120, 28)
	ui._place(header.get_node("SubtitleLabel"), 17, 33, width - 120, 16)
	ui._place(get_node("CloseButton"), width - 88, 12, 74, 30)
	ui._place(avatar, 16, 66, 46, 46)
	ui._place(avatar_letter, 0, 0, 46, 46)
	ui._place(customer_label, 74, 66, width - 190, 26)
	ui._place(items_label, 74, 92, width - 190, 20)
	ui._place(badge, width - 108, 76, 92, 28)
	ui._place(badge_label, 0, 0, 92, 28)
	ui._place(receipt, 16, 124, width - 32, 156)
	var inner := width - 32
	for column in receipt.get_children():
		if column.has_meta("x"):
			var x: int = column.get_meta("x")
			ui._place(column, x if x > 0 else inner + x, 8, 80, 16)
	for index in range(rows.size()):
		var y := 28 + index * 30
		ui._place(rows[index].icon, 10, y, 26, 26)
		ui._place(rows[index].name, 44, y + 3, inner - 210, 22)
		ui._place(rows[index].count, inner - 150, y + 3, 50, 22)
		ui._place(rows[index].amount, inner - 110, y + 3, 96, 22)
	ui._place(receipt.get_node("Rule"), 10, 120, inner - 20, 1)
	ui._place(receipt.get_node("TotalCaption"), 12, 124, 120, 28)
	ui._place(total_label, inner - 190, 120, 176, 32)
	ui._place(status_box, 16, 290, width - 32, 50)
	ui._place(payment_label, 10, 5, width - 52, 40)
	ui._place(scan_button, 16, 350, width - 32, 38)
	ui._place(khata_button, 16, 350, (width - 40) * 0.62, 38)
	ui._place(refuse_button, 24 + (width - 40) * 0.62, 350, (width - 40) * 0.38, 38)
	_place_payment_row(350)

func _place_payment_row(y: float) -> void:
	var tile := (width - 32 - 16) / 3.0
	for index in range(3): ui._place(payment_buttons[["Cash", "Card", "UPI"][index]], 16 + index * (tile + 8), y, tile, 50)
	ui._place(self, 16, 56, width, y + 64)

func open_menu() -> void:
	ui.shop_menu.hide()
	ui.house_menu.hide()
	ui.supplier_menu.hide()
	customer = operations.checkout_customer()
	wrong_payment_seconds = 0.0
	show()
	_refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	hide()
	customer = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## The basket as receipt lines: the first product at the agreed price, then the rest.
func _lines() -> Array:
	if not customer.has_product or customer.basket_count <= 0: return []
	var result: Array = [{"product": customer.product_id, "count": customer.basket_count, "price": customer.agreed_unit_price}]
	for line in customer.taken_lines(): result.append({"product": line.product, "count": int(line.count), "price": int(line.price)})
	return result

func _avatar(colour: Color) -> void:
	if colour == avatar_colour: return
	avatar_colour = colour
	avatar.add_theme_stylebox_override("panel", _flat(colour, 23))

func _status(kind: String) -> void:
	if kind == status_kind: return
	status_kind = kind
	var colours: Array = STATUS_STYLES[kind]
	status_box.add_theme_stylebox_override("panel", _flat(colours[0], 8, colours[1], 1))
	payment_label.add_theme_color_override("font_color", Color("991b1b") if kind == "error" else KenneyTheme.TEXT)

func _refresh() -> void:
	var rupee := String.chr(8377)
	var paying: bool = is_instance_valid(customer) and customer == operations.checkout_customer() and customer.state == customer.State.PAYING
	var scanning: bool = is_instance_valid(customer) and customer == operations.checkout_customer() and customer.state == customer.State.SCANNING
	# Runs every frame: flipping disabled off and on would cancel a click mid-press.
	for button in payment_buttons.values(): button.disabled = not paying
	var asking: bool = paying and customer.wants_udhaar
	khata_button.visible = asking
	refuse_button.visible = asking
	scan_button.visible = scanning
	scan_button.disabled = true
	pay_button.disabled = true
	_place_payment_row(398 if asking or scanning else 350)
	if not is_instance_valid(customer) or customer != operations.checkout_customer():
		customer_label.text = "Waiting for customer"
		items_label.text = "Nobody at the counter"
		avatar_letter.text = "?"
		_avatar(Color("94a3b8"))
		badge.hide()
		for row in rows:
			for part in row.values(): part.hide()
		total_label.text = "%s0" % rupee
		_status("info")
		payment_label.text = "The next customer will come to the counter."
		return
	var first_name: String = customer.customer_name.get_slice(" - ", 0)
	var kind: String = customer.customer_name.get_slice(" - ", 1)
	customer_label.text = first_name
	avatar_letter.text = first_name.left(1).to_upper()
	_avatar(AVATAR_COLOURS[first_name.length() % AVATAR_COLOURS.size()])
	items_label.text = "%s  |  %d item%s" % [kind, customer.total_items(), "" if customer.total_items() == 1 else "s"]
	badge.visible = paying
	if paying and badge_method != customer.payment_method:
		badge_method = customer.payment_method
		badge_label.text = badge_method.to_upper()
		badge.add_theme_stylebox_override("panel", _flat(METHOD_COLOURS[badge_method], 14))
	var lines := _lines()
	for index in range(rows.size()):
		var shown: bool = index < lines.size()
		for part in rows[index].values(): part.visible = shown
		if not shown: continue
		var line: Dictionary = lines[index]
		rows[index].icon.texture = operations._picture(line.product)
		rows[index].name.text = operations.Catalog.NAMES[line.product]
		rows[index].count.text = "x%d" % line.count
		rows[index].amount.text = "%s%d" % [rupee, int(line.price) * int(line.count)]
	total_label.text = "%s%d" % [rupee, customer.scanned_total()]
	if scanning:
		_status("info")
		payment_label.text = "Scan each product on the counter: aim at it and press E (%d / %d scanned)." % [customer.scanned_count, customer.total_items()]
		scan_button.text = "CLOSE AND SCAN ITEM %d / %d" % [customer.scanned_count + 1, customer.total_items()]
	elif paying:
		_status("info")
		payment_label.text = "%s pays by %s. Press %s below." % [first_name, customer.payment_method, customer.payment_method.to_upper()]
		if customer.payment_method == "Cash":
			payment_label.text += "\nReceived %s%d  |  Give change %s%d" % [rupee, customer.cash_tendered, rupee, customer.change_due()]
		if customer.wants_udhaar:
			_status("warn")
			payment_label.text = "%s asks for udhaar: pay later, in %d days. Write it in the khata, or say no and pick %s." % [first_name, customer.shop_area.business.UDHAAR_DAYS, customer.payment_method]
			khata_button.text = "WRITE IN KHATA  %s%d" % [rupee, customer.payment_total()]
		if wrong_payment_seconds > 0.0:
			_status("error")
			payment_label.text += "\nWrong method. Select %s." % customer.payment_method
	else:
		_status("info")
		payment_label.text = "Customer approaching" if customer.state in [customer.State.QUEUING, customer.State.BUYING] else "Customer wants a discount"

func _give_udhaar() -> void:
	if not visible or not is_instance_valid(customer) or customer.state != customer.State.PAYING or not customer.wants_udhaar: return
	var visitor = customer
	close_menu()
	visitor.complete_checkout(true)

func _refuse_udhaar() -> void:
	if not is_instance_valid(customer) or not customer.wants_udhaar: return
	customer.wants_udhaar = false
	customer.say("Theek hai bhaiya, abhi de deta hoon.", 3.0)
	_refresh()

func _scan() -> void:
	if visible: close_menu()

func _pay() -> void:
	return

func _choose_payment(method: String) -> void:
	if not visible or not is_instance_valid(customer) or customer.state != customer.State.PAYING: return
	if method != customer.payment_method:
		wrong_payment_seconds = 2.5
		ui.show_feedback("Customer is paying by %s." % customer.payment_method, true)
		_refresh()
		return
	var visitor = customer
	close_menu()
	visitor.complete_checkout()

func _process(delta: float) -> void:
	if not visible: return
	wrong_payment_seconds = maxf(0.0, wrong_payment_seconds - delta)
	if not operations.player_at_counter():
		close_menu()
		return
	if not is_instance_valid(customer): customer = operations.checkout_customer()
	if is_instance_valid(customer) and customer.state == customer.State.LEAVING:
		close_menu()
	else:
		_refresh()
