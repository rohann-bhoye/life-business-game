extends Panel

var customer: Node3D
var customer_label: Label
var items_label: Label
var total_label: Label
var payment_label: Label
var scan_button: Button
var pay_button: Button
var payment_buttons := {}
var wrong_payment_seconds := 0.0
@onready var ui = get_parent()
@onready var operations = get_tree().current_scene.get_node("ShopOperations")
@onready var player = get_tree().current_scene.get_node("Player")

func _ready() -> void:
	hide()
	player.checkout_menu = self
	ui._label("TitleLabel", self).text = "CHECKOUT PC"
	customer_label = ui._label("CustomerLabel", self)
	items_label = ui._label("ItemsLabel", self)
	total_label = ui._label("TotalLabel", self)
	payment_label = ui._label("PaymentLabel", self)
	payment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scan_button = _button("ScanButton", _scan)
	pay_button = _button("PaymentButton", _pay)
	for method in ["Cash", "Card", "UPI"]:
		var button := _button(method + "Button", _choose_payment.bind(method))
		button.text = method
		payment_buttons[method] = button
	_button("CloseButton", close_menu).text = "Close"
	get_viewport().size_changed.connect(_layout)
	_layout()

func _button(node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	add_child(button)
	button.pressed.connect(action)
	return button

func _layout() -> void:
	var width := minf(440, get_viewport().get_visible_rect().size.x - 32)
	ui._place(self, 16, 56, width, 396)
	ui._place(get_node("TitleLabel"), 16, 12, width - 110, 28)
	ui._place(get_node("CloseButton"), width - 78, 12, 62, 28)
	ui._place(customer_label, 16, 60, width - 32, 32)
	ui._place(items_label, 16, 102, width - 32, 24)
	ui._place(total_label, 16, 138, width - 32, 28)
	ui._place(payment_label, 16, 182, width - 32, 68)
	ui._place(scan_button, 16, 260, width - 32, 32)
	ui._place(pay_button, 16, 300, width - 32, 32)
	var choice_width := (width - 44) / 3.0
	for index in range(3): ui._place(payment_buttons[["Cash", "Card", "UPI"][index]], 16 + index * (choice_width + 6), 344, choice_width, 36)

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

func _refresh() -> void:
	scan_button.disabled = true
	scan_button.show()
	pay_button.disabled = true
	scan_button.text = "Aim at each item and press E"
	pay_button.text = "Awaiting scanned items"
	for button in payment_buttons.values(): button.disabled = true
	if not is_instance_valid(customer) or customer != operations.checkout_customer():
		customer_label.text = "Waiting for customer"
		items_label.text = "Items: 0"
		total_label.text = "Total: %s0" % String.chr(8377)
		payment_label.text = ""
		return
	customer_label.text = customer.customer_name.split(" - ")[0]
	items_label.text = "%s: %d | Scanned: %d" % [operations.Catalog.NAMES[customer.product_id], customer.basket_count, customer.scanned_count]
	total_label.text = "Total: %s%d" % [String.chr(8377), customer.scanned_count * customer.agreed_unit_price]
	if customer.state == customer.State.SCANNING:
		payment_label.text = "Use the counter scanner"
		scan_button.text = "Close, aim at item %d / %d, press E" % [customer.scanned_count + 1, customer.basket_count]
	elif customer.state == customer.State.PAYING:
		scan_button.hide()
		payment_label.text = "Customer presents: %s" % customer.payment_method
		if customer.payment_method == "Cash":
			payment_label.text += "\nReceived: %s%d | Change: %s%d" % [String.chr(8377), customer.cash_tendered, String.chr(8377), customer.change_due()]
		pay_button.text = "Choose the matching payment below"
		for button in payment_buttons.values(): button.disabled = false
		if wrong_payment_seconds > 0.0:
			payment_label.text += "\nWrong method. Select %s." % customer.payment_method
			payment_label.modulate = Color(1.0, 0.55, 0.5)
		else: payment_label.modulate = Color.WHITE
	else:
		payment_label.modulate = Color.WHITE
		payment_label.text = "Customer approaching" if customer.state in [customer.State.QUEUING, customer.State.BUYING] else "Customer wants a discount"

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
