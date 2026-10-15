extends Area3D

const BusinessBackend := preload("res://business_backend.gd")
const STOCK_PURCHASE_COST := BusinessBackend.STOCK_COST
const MARKETING_COST := BusinessBackend.MARKETING_COST
const WORKER_HIRING_COST := BusinessBackend.HIRING_COST

var player_inside := false
@export var save_path := "user://business_save.json"
var business = BusinessBackend.new()

var money: int:
	get:
		return business.money
var stock: int:
	get:
		return business.stock
var items_sold: int:
	get:
		return business.items_sold
var sales_revenue: int:
	get:
		return business.sales_revenue
var restocking_expenses: int:
	get:
		return business.restocking_expenses
var marketing_expenses: int:
	get:
		return business.marketing_expenses
var hiring_expenses: int:
	get:
		return business.hiring_expenses
var marketing_active: bool:
	get:
		return business.marketing_seconds_left > 0.0
var selling_price: int:
	get:
		return business.selling_price
var missed_sales: int:
	get:
		return business.missed_sales
var last_visit: String:
	get:
		return business.last_visit

@onready var shop_menu: Control = get_tree().current_scene.get_node("Ui/ShopMenu")
@onready var money_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/MoneyLabel")
@onready var stock_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/StockLabel")
@onready var buy_stock_button: Button = get_tree().current_scene.get_node("Ui/ShopMenu/BuyStockButton")
@onready var close_button: Button = get_tree().current_scene.get_node("Ui/ShopMenu/CloseButton")
@onready var sales_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/SalesLabel")
@onready var revenue_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/RevenueLabel")
@onready var expenses_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/ExpensesLabel")
@onready var profit_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/ProfitLabel")
@onready var sale_price_input: SpinBox = get_tree().current_scene.get_node("Ui/ShopMenu/SalePriceInput")
@onready var missed_sales_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/MissedSalesLabel")
@onready var last_visit_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/LastVisitLabel")
@onready var marketing_button: Button = get_tree().current_scene.get_node("Ui/ShopMenu/MarketingButton")
@onready var marketing_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/MarketingLabel")
@onready var marketing_timer: Timer = $MarketingTimer
@onready var customer_spawner: Node3D = get_tree().current_scene.get_node("CustomerSpawner")
@onready var worker: Node3D = get_tree().current_scene.get_node("Worker")
@onready var hire_worker_button: Button = get_tree().current_scene.get_node("Ui/ShopMenu/HireWorkerButton")
@onready var worker_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/WorkerLabel")
@onready var worker_status_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/WorkerStatusLabel")
@onready var save_status_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/SaveStatusLabel")
@onready var home_ownership_label: Label = get_tree().current_scene.get_node("Ui/ShopMenu/HomeOwnershipLabel")
@onready var house_menu: Control = get_tree().current_scene.get_node("Ui/HouseMenu")
@onready var daily_cost_label: Label = shop_menu.get_node("DailyCostLabel")
@onready var unpaid_bills_label: Label = shop_menu.get_node("UnpaidBillsLabel")
@onready var pay_bills_button: Button = shop_menu.get_node("PayBillsButton")

func _ready():
	business.load_progress(save_path)
	business.changed.connect(_on_business_changed)
	business.clock_changed.connect(_update_shop_labels)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	buy_stock_button.pressed.connect(_on_buy_stock_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	pay_bills_button.pressed.connect(_on_pay_bills_pressed)
	marketing_button.pressed.connect(_on_marketing_button_pressed)
	marketing_timer.timeout.connect(_on_marketing_finished)
	hire_worker_button.pressed.connect(_on_hire_worker_button_pressed)
	$AutosaveTimer.timeout.connect(_on_autosave_timer_timeout)
	sale_price_input.value = selling_price
	sale_price_input.value_changed.connect(_on_sale_price_changed)
	_update_shop_labels()
	call_deferred("_sync_runtime_state")

func _process(_delta: float) -> void:
	if not marketing_timer.is_stopped():
		business.marketing_seconds_left = marketing_timer.time_left
		marketing_label.text = "Marketing: %ds left" % ceili(marketing_timer.time_left)

func _exit_tree() -> void:
	_capture_marketing_time()
	business.save_progress()

func _on_autosave_timer_timeout() -> void:
	_capture_marketing_time()
	business.save_progress()
	save_status_label.text = business.save_status

func _capture_marketing_time() -> void:
	if is_instance_valid(marketing_timer) and not marketing_timer.is_stopped():
		business.marketing_seconds_left = marketing_timer.time_left

func _on_business_changed() -> void:
	_sync_runtime_state()

func _sync_runtime_state() -> void:
	if business.worker_hired and not worker.hired:
		worker.hire()
	worker.update_duty()
	if marketing_active and marketing_timer.is_stopped():
		marketing_timer.start(business.marketing_seconds_left)
		customer_spawner.set_marketing_active(true)
	elif not marketing_active:
		marketing_timer.stop()
		if customer_spawner.get_node("SpawnTimer").wait_time != business.customer_spawn_interval():
			customer_spawner.set_marketing_active(false)
	_update_shop_labels()

func _on_marketing_button_pressed() -> void:
	if business.start_marketing():
		_feedback("Marketing started. -%s200" % String.chr(8377))
	else:
		_feedback("Marketing is already active." if marketing_active else "Not enough money for marketing.", true)

func _on_pay_bills_pressed() -> void:
	var before := money
	if business.pay_bills():
		_feedback("Bills paid: %s%s" % [String.chr(8377), _format_money(before - money)])
	else:
		_feedback("No unpaid bills." if business.unpaid_bills() == 0 else "Not enough money to pay bills.", true)

func _feedback(message: String, failed := false) -> void:
	get_tree().current_scene.get_node("Ui").show_feedback(message, failed)

func _on_marketing_finished() -> void:
	business.finish_marketing()

func _unhandled_input(event):
	if player_inside and event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_E:
			var operations = get_tree().current_scene.get_node("ShopOperations")
			if operations.enabled:
				if get_tree().current_scene.get_node("Player")._menu_is_open(): return
				if operations.try_interact():
					get_viewport().set_input_as_handled()
					return
			var customer = get_bargaining_customer()
			if customer != null:
				get_tree().current_scene.get_node("Ui/BargainMenu").open_for(customer)
				get_viewport().set_input_as_handled()
				return
			house_menu.hide()
			shop_menu.visible = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()

func get_bargaining_customer() -> Node3D:
	var customer = customer_spawner.active_customer
	var operations = get_tree().current_scene.get_node("ShopOperations")
	if operations.enabled: customer = operations.checkout_customer()
	if is_instance_valid(customer) and not customer.is_queued_for_deletion() and customer.state == customer.State.NEGOTIATING and customer.player_is_near():
		return customer
	return null

func _on_body_entered(body):
	if body.name == "Player":
		player_inside = true

func _on_body_exited(body):
	if body.name == "Player":
		player_inside = false

func _on_buy_stock_button_pressed():
	var operations = get_tree().current_scene.get_node("ShopOperations")
	if operations.enabled:
		operations.open_supplier()
		return
	if purchase_stock():
		_feedback("10 stock purchased. -%s500" % String.chr(8377))
	else:
		_feedback("Not enough money to buy stock.", true)

func purchase_stock() -> bool:
	return business.purchase_stock()

func _on_hire_worker_button_pressed() -> void:
	var operations = get_tree().current_scene.get_node("ShopOperations")
	if operations.enabled:
		operations.open_supplier()
		if get_tree().current_scene.get_node("Ui/SupplierMenu").visible:
			get_tree().current_scene.get_node("Ui/SupplierMenu").tabs.current_tab = 1
		return
	if business.hire_worker():
		_feedback("Worker hired. -%s1,000" % String.chr(8377))
	else:
		_feedback("Worker is already hired." if business.worker_hired else "Not enough money to hire a worker.", true)

func _on_close_button_pressed():
	sale_price_input.apply()
	shop_menu.visible = false
	if not house_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_sale_price_changed(value: float) -> void:
	if not business.set_selling_price(int(value)):
		sale_price_input.set_value_no_signal(selling_price)

func sell_one_stock(customer_budget: int = 200) -> bool:
	return business.sell_one_stock(customer_budget)

func _update_shop_labels():
	money_label.text = "Money: ₹%s" % _format_money(money)
	stock_label.text = "Stock: %d" % stock
	sales_label.text = "Items sold: %d" % items_sold
	revenue_label.text = "Revenue: ₹%s" % _format_money(sales_revenue)
	var total_expenses: int = business.total_expenses()
	expenses_label.text = "Paid expenses: ₹%s" % _format_money(total_expenses)
	profit_label.text = "Net profit: ₹%s" % _format_money(sales_revenue - total_expenses)
	missed_sales_label.text = "Missed sales: %d" % missed_sales
	last_visit_label.text = "Last visit: %s" % last_visit
	marketing_button.disabled = marketing_active or money < MARKETING_COST
	marketing_label.text = "Marketing: %ds left" % ceili(marketing_timer.time_left) if marketing_active else "Marketing: Inactive"
	buy_stock_button.disabled = money < STOCK_PURCHASE_COST
	if get_tree().current_scene.get_node("ShopOperations").enabled:
		buy_stock_button.text = "Shop PC - Order products"
		buy_stock_button.disabled = false
	hire_worker_button.disabled = business.worker_hired or money < WORKER_HIRING_COST
	if get_tree().current_scene.get_node("ShopOperations").enabled:
		hire_worker_button.text = "Staff - Management PC"
		hire_worker_button.disabled = false
	worker_label.text = "Worker: Hired" if business.worker_hired else "Worker: Not hired"
	save_status_label.text = business.save_status
	home_ownership_label.text = "Home: Owned" if business.house_owned else "Home: Not owned"
	var daily_cost: int = business.DAILY_SHOP_COST + business.DAILY_WORKER_WAGE * business.staff_count()
	daily_cost_label.text = "Daily bills: %s%s" % [String.chr(8377), _format_money(daily_cost)]
	unpaid_bills_label.text = "Unpaid bills: %s%s" % [String.chr(8377), _format_money(business.unpaid_bills())]
	pay_bills_button.disabled = not business.can_pay_bills()
	buy_stock_button.tooltip_text = "Not enough money. Requires %s500." % String.chr(8377) if buy_stock_button.disabled else "Buy 10 stock"
	if get_tree().current_scene.get_node("ShopOperations").enabled:
		buy_stock_button.tooltip_text = "Order products at the management PC"
	marketing_button.tooltip_text = "Marketing already active" if marketing_active else ("Not enough money. Requires %s200." % String.chr(8377) if marketing_button.disabled else "Start marketing")
	hire_worker_button.tooltip_text = "Worker already hired" if business.worker_hired else ("Not enough money. Requires %s1,000." % String.chr(8377) if hire_worker_button.disabled else "Hire worker")
	if get_tree().current_scene.get_node("ShopOperations").enabled:
		hire_worker_button.tooltip_text = "Hire cashier and stock assistant at the management PC"
	pay_bills_button.tooltip_text = "No unpaid bills" if business.unpaid_bills() == 0 else ("Not enough money to pay bills" if pay_bills_button.disabled else "Pay outstanding bills")
	if not business.worker_hired:
		worker_status_label.text = "Status: Vacant"
	elif not business.worker_on_duty():
		worker_status_label.text = "Status: Unpaid wages"
	elif get_tree().current_scene.get_node("ShopOperations").enabled:
		worker_status_label.text = "Cashier: On duty" if business.cashier_on_shift() else "Cashier: Off shift"
	elif stock > worker.RESTOCK_THRESHOLD:
		worker_status_label.text = "Status: On duty"
	elif money < STOCK_PURCHASE_COST:
		worker_status_label.text = "Status: Needs ₹500"
	else:
		worker_status_label.text = "Status: Restock pending"

func _format_money(value: int) -> String:
	var digits := str(absi(value))
	var formatted := ""
	var digit_count := 0

	for index in range(digits.length() - 1, -1, -1):
		if digit_count > 0 and digit_count % 3 == 0:
			formatted = "," + formatted

		formatted = digits.substr(index, 1) + formatted
		digit_count += 1

	return "-" + formatted if value < 0 else formatted
