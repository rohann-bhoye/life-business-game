extends Panel

var customer: Node3D
var customer_label: Label
var price_label: Label
var dialogue_label: Label
var patience_label: Label
var counter_input: SpinBox
var accept_button: Button
var counter_button: Button
var keep_button: Button

@onready var ui = get_parent()
@onready var shop = get_tree().current_scene.get_node("Shop/ShopArea")
@onready var player = get_tree().current_scene.get_node("Player")

func _ready() -> void:
	hide()
	player.bargain_menu = self
	ui._label("TitleLabel", self).text = "CUSTOMER OFFER"
	customer_label = ui._label("CustomerLabel", self)
	price_label = ui._label("PriceLabel", self)
	dialogue_label = ui._label("DialogueLabel", self)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	patience_label = ui._label("PatienceLabel", self)
	ui._label("CounterPriceLabel", self).text = "Your counter"
	counter_input = SpinBox.new()
	counter_input.name = "CounterPriceInput"
	counter_input.step = 10
	counter_input.prefix = String.chr(8377) + " "
	add_child(counter_input)
	accept_button = _button("AcceptOfferButton", func(): _choose("accept"))
	counter_button = _button("CounterOfferButton", func(): _choose("counter"))
	keep_button = _button("KeepPriceButton", func(): _choose("keep"))
	var close_button := _button("CloseButton", close_menu)
	close_button.text = "Close"
	counter_input.value_changed.connect(func(value): counter_button.text = "Counter %s%d" % [String.chr(8377), int(value)])
	get_viewport().size_changed.connect(_layout)
	_layout()

func _button(node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	add_child(button)
	button.pressed.connect(action)
	return button

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(440, viewport_size.x - 32)
	ui._place(self, 16, 56, width, 402)
	var content_width := width - 32
	ui._place(get_node("TitleLabel"), 16, 12, content_width - 74, 28)
	ui._place(get_node("CloseButton"), width - 78, 12, 62, 28)
	ui._place(customer_label, 16, 52, content_width, 24)
	ui._place(price_label, 16, 86, content_width, 24)
	ui._place(dialogue_label, 16, 120, content_width, 48)
	ui._place(patience_label, 16, 178, content_width, 24)
	ui._place(get_node("CounterPriceLabel"), 16, 214, content_width * 0.45, 32)
	ui._place(counter_input, 16 + content_width * 0.5, 214, content_width * 0.5, 32)
	for pair in [[accept_button, 262], [counter_button, 304], [keep_button, 346]]:
		ui._place(pair[0], 16, pair[1], content_width, 32)

func open_for(visitor: Node3D) -> void:
	if not is_instance_valid(visitor) or visitor.state != visitor.State.NEGOTIATING or not visitor.player_is_near():
		return
	customer = visitor
	shop.sale_price_input.apply()
	shop.shop_menu.hide()
	shop.house_menu.hide()
	customer_label.text = customer.customer_name
	price_label.text = "Asking: %s%d | Offer: %s%d" % [String.chr(8377), customer.quoted_price, String.chr(8377), customer.offer_price]
	dialogue_label.text = "%s%d mein doge? Thoda kam karo." % [String.chr(8377), customer.offer_price]
	counter_input.min_value = 50
	counter_input.max_value = customer.quoted_price
	counter_input.min_value = customer.offer_price + 10
	counter_input.value = clampi((customer.offer_price + customer.quoted_price) / 20 * 10, int(counter_input.min_value), int(counter_input.max_value))
	accept_button.text = "Accept %s%d" % [String.chr(8377), customer.offer_price]
	counter_button.text = "Counter %s%d" % [String.chr(8377), int(counter_input.value)]
	keep_button.text = "Keep %s%d" % [String.chr(8377), customer.quoted_price]
	patience_label.text = "Waiting: %ds" % ceili(customer.bargain_seconds_left)
	show()
	ui.feedback_label.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	hide()
	customer = null
	if not shop.shop_menu.visible and not shop.house_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _choose(choice: String) -> void:
	if not is_instance_valid(customer):
		close_menu()
		return
	if choice == "counter":
		counter_input.apply()
	if customer.resolve_bargain(choice, int(counter_input.value)):
		var message: String = customer.deal_result
		var pending: bool = customer.physical_shop() and customer.state == customer.State.PAYING
		var failed: bool = not customer.deal_sold and not pending
		close_menu()
		ui.show_feedback(message, failed)
		if pending: ui.checkout_menu.open_menu()

func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(customer):
		close_menu()
	elif customer.state != customer.State.NEGOTIATING:
		var message: String = customer.deal_result
		var failed: bool = not customer.deal_sold
		close_menu()
		ui.show_feedback(message, failed)
	elif not customer.player_is_near():
		close_menu()
	else:
		patience_label.text = "Waiting: %ds" % ceili(customer.bargain_seconds_left)
