extends Panel

var order_button: Button
var money_label: Label
var status_label: Label
var tabs: TabBar
var cashier_button: Button
var stock_worker_button: Button
var assign_button: Button
var cashier_label: Label
var stock_worker_label: Label
var role_input: OptionButton
var level_input: OptionButton
var start_hour: SpinBox
var end_hour: SpinBox
var shift_button: Button
var contract_label: Label
var expansion_button: Button
var happiness_bar: ProgressBar
var product_input: OptionButton
var box_quantity: SpinBox
var retail_price: SpinBox
var auto_collect: CheckBox
var rack_product: OptionButton
var rack_selector: OptionButton
var rack_quantity: SpinBox
var rack_signature := ""
var company_column: Control
var company_list: ItemList
var selected_tab := 0
var active_terminal
var warehouse_work: CheckBox
var shelf_selector: OptionButton
var shelf_product: OptionButton
var shelf_draft_key := ""
const Catalog = preload("res://product_catalog.gd")
@onready var ui = get_parent()
@onready var shop = get_tree().current_scene.get_node("Shop/ShopArea")
@onready var player = get_tree().current_scene.get_node("Player")

func _ready() -> void:
	hide()
	player.supplier_menu = self
	ui._label("TitleLabel", self).text = "MANAGEMENT PC"
	ui._label("ProductLabel", self).text = "Reusable bottles | Box of 10"
	ui._label("PriceLabel", self).text = "Wholesale: %s500" % String.chr(8377)
	product_input = OptionButton.new()
	product_input.name = "ProductSelector"
	for id in Catalog.IDS: product_input.add_item(Catalog.NAMES[id])
	add_child(product_input)
	product_input.item_selected.connect(func(_index): _load_product(); _refresh())
	ui._label("BoxQuantityLabel", self).text = "Boxes"
	box_quantity = SpinBox.new()
	box_quantity.name = "BoxQuantityInput"
	box_quantity.min_value = 1
	box_quantity.max_value = 10
	box_quantity.step = 1
	box_quantity.value = 1
	add_child(box_quantity)
	box_quantity.value_changed.connect(func(_value): _refresh())
	ui._label("RetailPriceLabel", self).text = "Sale price"
	retail_price = SpinBox.new()
	retail_price.name = "RetailPriceInput"
	retail_price.min_value = 50
	retail_price.max_value = 200
	retail_price.step = 10
	retail_price.prefix = String.chr(8377)
	add_child(retail_price)
	retail_price.value_changed.connect(func(value): shop.business.set_product_price(Catalog.IDS[product_input.selected], int(value)))
	money_label = ui._label("MoneyLabel", self)
	status_label = ui._label("OrderStatusLabel", self)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_button = Button.new()
	order_button.name = "OrderButton"
	order_button.text = "Order 10 bottles - %s500" % String.chr(8377)
	add_child(order_button)
	order_button.pressed.connect(_order)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	add_child(close_button)
	close_button.pressed.connect(close_menu)
	tabs = TabBar.new()
	tabs.name = "ManagementTabs"
	tabs.add_tab("Orders")
	tabs.add_tab("Staff")
	tabs.add_tab("Space")
	tabs.add_tab("People")
	tabs.add_tab("Racks")
	tabs.add_tab("Slots")
	add_child(tabs)
	tabs.tab_changed.connect(_select_tab)
	cashier_label = ui._label("CashierLabel", self)
	stock_worker_label = ui._label("StockWorkerLabel", self)
	cashier_button = _button("HireCashierButton", func(): shop.business.hire_worker(level_input.selected + 1))
	stock_worker_button = _button("HireStockWorkerButton", func(): shop.business.hire_stock_worker())
	ui._label("WarehouseStaffLabel", self)
	ui._label("WarehouseWageLabel", self).text = "%s200/day | Bay to warehouse storage" % String.chr(8377)
	_button("HireWarehouseButton", func(): shop.business.hire_warehouse_worker())
	warehouse_work = CheckBox.new()
	warehouse_work.name = "WarehouseWorkSwitch"
	warehouse_work.text = "Receiving enabled"
	add_child(warehouse_work)
	warehouse_work.toggled.connect(func(value): shop.business.set_employee_work("warehouse", value))
	assign_button = _button("AssignRestockingButton", func(): get_tree().current_scene.get_node("ShopOperations").stock_worker.assign_delivery())
	role_input = OptionButton.new()
	role_input.name = "EmployeeRole"
	role_input.add_item("Cashier")
	role_input.add_item("Stock assistant")
	role_input.add_item("Warehouse receiver")
	add_child(role_input)
	role_input.item_selected.connect(func(_index): _load_staff_settings(); _select_tab(tabs.current_tab))
	level_input = OptionButton.new()
	level_input.name = "CashierLevel"
	for title in ["Level 1 - Trainee", "Level 2 - Skilled", "Level 3 - Expert"]: level_input.add_item(title)
	add_child(level_input)
	level_input.item_selected.connect(func(_index): _refresh())
	contract_label = ui._label("ContractLabel", self)
	ui._label("ShiftLabel", self).text = "Work hours"
	ui._label("SavedShiftLabel", self)
	auto_collect = CheckBox.new()
	auto_collect.name = "AutomaticCollection"
	auto_collect.text = "Collect delivered boxes automatically"
	add_child(auto_collect)
	auto_collect.toggled.connect(func(value): shop.business.set_assistant_auto_collect(value))
	ui._label("ShiftToLabel", self).text = "to"
	start_hour = _hour_input("ShiftStartHour", 6, 21)
	end_hour = _hour_input("ShiftEndHour", 7, 22)
	shift_button = _button("ApplyShiftButton", _save_shift)
	shift_button.text = "Save work hours"
	ui._label("SpaceLevelLabel", self)
	ui._label("SpaceDimensionsLabel", self)
	ui._label("SpaceQuoteLabel", self)
	expansion_button = _button("ExpandSpaceButton", ui._on_upgrade_pressed)
	ui._label("HappinessLabel", self)
	ui._label("EmployeeMessageLabel", self).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	happiness_bar = ProgressBar.new()
	happiness_bar.name = "HappinessBar"
	happiness_bar.show_percentage = false
	add_child(happiness_bar)
	_button("TalkEmployeeButton", func(): ui.staff_dialog.open_for(_role())).text = "Talk to employee"
	_button("PayOvertimeButton", func(): shop.business.staff.reply(shop.business, _role(), "pay"))
	rack_product = OptionButton.new()
	rack_product.name = "RackProductSelector"
	for id in Catalog.IDS: rack_product.add_item("Produce table - 12 baskets" if id == "tomato" else "Shelf - " + Catalog.NAMES[id])
	add_child(rack_product)
	ui._label("FurnitureQuoteLabel", self)
	rack_quantity = SpinBox.new()
	rack_quantity.name = "RackQuantity"
	rack_quantity.min_value = 1
	rack_quantity.max_value = 5
	rack_quantity.step = 1
	add_child(rack_quantity)
	_button("BuyRackButton", _buy_rack).text = "Order racks"
	ui._label("RackDeliveryLabel", self)
	rack_selector = OptionButton.new()
	rack_selector.name = "RackSelector"
	add_child(rack_selector)
	rack_selector.item_selected.connect(func(_index): shelf_draft_key = ""; _refresh_racks())
	ui._label("RackInfoLabel", self)
	_button("MoveRackButton", _move_rack).text = "Move / rotate rack"
	_button("SetRestockRackButton", _set_restock_rack).text = "Restock here"
	shelf_selector = OptionButton.new()
	shelf_selector.name = "ShelfSlotSelector"
	for row in ["Lower shelf", "Middle shelf", "Upper shelf"]: shelf_selector.add_item(row)
	add_child(shelf_selector)
	shelf_selector.item_selected.connect(func(_index): shelf_draft_key = ""; _refresh_racks())
	shelf_product = OptionButton.new()
	shelf_product.name = "ShelfProductSelector"
	shelf_product.add_item("Unassigned")
	for id in Catalog.IDS: shelf_product.add_item(Catalog.NAMES[id])
	add_child(shelf_product)
	ui._label("ShelfCapacityLabel", self)
	ui._label("ShelfSummaryLabel", self).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("AssignShelfButton", _assign_shelf).text = "Assign shelf product"
	company_column = Control.new()
	company_column.name = "CompanyColumn"
	add_child(company_column)
	ui._label("CompanyHeading", company_column).text = "COMPANIES"
	company_list = ItemList.new()
	company_list.name = "CompanyList"
	company_list.add_item("Apna Wholesale")
	company_list.add_item("Rackworks Furniture")
	company_list.fixed_column_width = 176
	company_list.same_column_width = true
	company_list.add_theme_font_size_override("font_size", 14)
	company_list.add_theme_constant_override("v_separation", 12)
	company_column.add_child(company_list)
	company_list.item_selected.connect(func(index): tabs.current_tab = 0 if index == 0 else 4)
	_load_staff_settings()
	_load_product()
	_select_tab(0)
	shop.business.changed.connect(_refresh)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()

func _button(node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	add_child(button)
	button.pressed.connect(action)
	return button

func _select_tab(index: int) -> void:
	selected_tab = index
	for node_name in ["ProductSelector", "ProductLabel", "PriceLabel", "OrderStatusLabel", "OrderButton", "RetailPriceLabel", "RetailPriceInput", "BoxQuantityLabel", "BoxQuantityInput"]:
		get_node(node_name).visible = index == 0
	for node_name in ["EmployeeRole", "ContractLabel", "ShiftLabel", "ShiftToLabel", "ShiftStartHour", "ShiftEndHour", "ApplyShiftButton"]:
		get_node(node_name).visible = index == 1
	for node_name in ["CashierLabel", "CashierLevel", "HireCashierButton"]:
		get_node(node_name).visible = index == 1 and role_input.selected == 0
	for node_name in ["StockWorkerLabel", "HireStockWorkerButton", "AssignRestockingButton", "SavedShiftLabel", "AutomaticCollection"]:
		get_node(node_name).visible = index == 1 and role_input.selected == 1
	for node_name in ["WarehouseStaffLabel", "WarehouseWageLabel", "HireWarehouseButton", "WarehouseWorkSwitch"]:
		get_node(node_name).visible = index == 1 and role_input.selected == 2
	contract_label.visible = index == 1 and role_input.selected == 0
	for node_name in ["SpaceLevelLabel", "SpaceDimensionsLabel", "SpaceQuoteLabel", "ExpandSpaceButton"]:
		get_node(node_name).visible = index == 2
	role_input.visible = index in [1, 3]
	for node_name in ["HappinessLabel", "HappinessBar", "EmployeeMessageLabel", "TalkEmployeeButton", "PayOvertimeButton"]:
		get_node(node_name).visible = index == 3
	for node_name in ["RackProductSelector", "FurnitureQuoteLabel", "RackQuantity", "BuyRackButton", "RackDeliveryLabel", "RackSelector", "RackInfoLabel", "MoveRackButton", "SetRestockRackButton"]:
		get_node(node_name).visible = index == 4
	rack_selector.visible = index in [4, 5]
	for node_name in ["ShelfSlotSelector", "ShelfProductSelector", "ShelfCapacityLabel", "ShelfSummaryLabel", "AssignShelfButton"]: get_node(node_name).visible = index == 5
	_refresh()
	_layout()

func _hour_input(node_name: String, minimum: int, maximum: int) -> SpinBox:
	var input := SpinBox.new()
	input.name = node_name
	input.min_value = minimum
	input.max_value = maximum
	input.step = 1
	input.suffix = ":00"
	add_child(input)
	return input

func _load_staff_settings() -> void:
	var business = shop.business
	var role := _role()
	start_hour.value = business.get(role + "_shift_start") / 60
	end_hour.value = business.get(role + "_shift_end") / 60
	level_input.select(business.cashier_level - 1)

func _save_shift() -> void:
	start_hour.apply()
	end_hour.apply()
	var role := _role()
	var saved: bool = shop.business.set_staff_shift(role, int(start_hour.value) * 60, int(end_hour.value) * 60)
	ui.show_feedback("Work hours saved." if saved else "Shift must end after it starts.", not saved)

func _layout() -> void:
	var companies := selected_tab in [0, 4] and get_viewport().get_visible_rect().size.x >= 760
	var width := minf(720 if companies else 440, get_viewport().get_visible_rect().size.x - 32)
	ui._place(self, 16, 56, width, minf(424, get_viewport().get_visible_rect().size.y - 72))
	ui._place(get_node("TitleLabel"), 16, 12, width - 110, 28)
	ui._place(get_node("CloseButton"), width - 78, 12, 62, 28)
	ui._place(tabs, 16, 52, width - 32, 32)
	ui._place(money_label, 16, 94, width - 32, 24)
	ui._place(product_input, 16, 126, width - 32, 32)
	ui._place(get_node("ProductLabel"), 16, 166, width - 32, 24)
	ui._place(get_node("BoxQuantityLabel"), 16, 194, 100, 30)
	ui._place(box_quantity, 120, 194, width - 136, 30)
	ui._place(get_node("PriceLabel"), 16, 230, width - 32, 24)
	ui._place(status_label, 16, 258, width - 32, 48)
	ui._place(order_button, 16, 314, width - 32, 32)
	ui._place(get_node("RetailPriceLabel"), 16, 354, 100, 30)
	ui._place(retail_price, 120, 354, width - 136, 30)
	ui._place(role_input, 16, 126, width - 32, 32)
	ui._place(cashier_label, 16, 166, width - 32, 24)
	ui._place(stock_worker_label, 16, 166, width - 32, 24)
	ui._place(level_input, 16, 196, width - 32, 32)
	ui._place(auto_collect, 16, 196, width - 32, 32)
	ui._place(get_node("SavedShiftLabel"), 16, 234, width - 32, 24)
	ui._place(contract_label, 16, 234, width - 32, 24)
	ui._place(cashier_button, 16, 264, width - 32, 32)
	ui._place(stock_worker_button, 16, 264, width - 32, 32)
	ui._place(get_node("ShiftLabel"), 16, 304, 78, 32)
	var input_width := (width - 146) / 2
	ui._place(start_hour, 98, 304, input_width, 32)
	ui._place(get_node("ShiftToLabel"), 102 + input_width, 304, 20, 32)
	ui._place(end_hour, 130 + input_width, 304, input_width, 32)
	ui._place(shift_button, 16, 344, width - 32, 28)
	ui._place(assign_button, 16, 378, width - 32, 28)
	ui._place(get_node("SpaceLevelLabel"), 16, 130, width - 32, 24)
	ui._place(get_node("SpaceDimensionsLabel"), 16, 166, width - 32, 24)
	ui._place(get_node("SpaceQuoteLabel"), 16, 208, width - 32, 24)
	ui._place(expansion_button, 16, 260, width - 32, 36)
	ui._place(get_node("HappinessLabel"), 16, 166, width - 32, 24)
	ui._place(happiness_bar, 16, 196, width - 32, 18)
	ui._place(get_node("EmployeeMessageLabel"), 16, 228, width - 32, 64)
	ui._place(get_node("TalkEmployeeButton"), 16, 304, width - 32, 32)
	ui._place(get_node("PayOvertimeButton"), 16, 344, width - 32, 32)
	ui._place(rack_product, 16, 126, width - 32, 32)
	ui._place(get_node("FurnitureQuoteLabel"), 16, 166, width - 148, 30)
	ui._place(rack_quantity, width - 122, 166, 106, 30)
	ui._place(get_node("BuyRackButton"), 16, 202, width - 32, 36)
	ui._place(get_node("RackDeliveryLabel"), 16, 244, width - 32, 24)
	ui._place(rack_selector, 16, 276, width - 32, 32)
	ui._place(get_node("RackInfoLabel"), 16, 316, width - 32, 24)
	ui._place(get_node("MoveRackButton"), 16, 348, width - 32, 28)
	ui._place(get_node("SetRestockRackButton"), 16, 384, width - 32, 28)
	ui._place(get_node("WarehouseStaffLabel"), 16, 166, width - 32, 24)
	ui._place(warehouse_work, 16, 196, width - 32, 32)
	ui._place(get_node("WarehouseWageLabel"), 16, 234, width - 32, 24)
	ui._place(get_node("HireWarehouseButton"), 16, 264, width - 32, 32)
	if selected_tab == 5: ui._place(rack_selector, 16, 126, width - 32, 32)
	ui._place(shelf_selector, 16, 166, width - 32, 32)
	ui._place(shelf_product, 16, 206, width - 32, 32)
	ui._place(get_node("ShelfCapacityLabel"), 16, 246, width - 32, 24)
	ui._place(get_node("AssignShelfButton"), 16, 278, width - 32, 32)
	ui._place(get_node("ShelfSummaryLabel"), 16, 322, width - 32, 84)
	company_column.visible = companies
	if companies:
		ui._place(company_column, 16, 126, 176, 272)
		ui._place(company_column.get_node("CompanyHeading"), 0, 0, 176, 24)
		ui._place(company_list, 0, 34, 176, 144)
		company_list.select(0 if selected_tab == 0 else 1)
		for node_name in ["ProductSelector", "ProductLabel", "PriceLabel", "OrderStatusLabel", "OrderButton", "RetailPriceLabel", "RetailPriceInput", "BoxQuantityLabel", "BoxQuantityInput", "RackProductSelector", "FurnitureQuoteLabel", "BuyRackButton", "RackDeliveryLabel", "RackSelector", "RackInfoLabel", "MoveRackButton", "SetRestockRackButton"]:
			var control: Control = get_node(node_name)
			control.position.x += 192
			if node_name not in ["RetailPriceLabel", "BoxQuantityLabel"]: control.size.x -= 192

func _refresh() -> void:
	var business = shop.business
	_refresh_racks()
	var role := _role()
	get_node("WarehouseStaffLabel").text = "Anil - Receiver: " + _duty_status("warehouse", business.warehouse_worker_hired, business.warehouse_worker_on_shift())
	warehouse_work.set_pressed_no_signal(business.staff.records.warehouse.work_enabled)
	warehouse_work.disabled = not business.staff.active(business, "warehouse")
	get_node("HireWarehouseButton").text = "Hire warehouse receiver - %s1,000" % String.chr(8377)
	get_node("HireWarehouseButton").disabled = business.staff.active(business, "warehouse") or business.money < 1000 or business.staff.records.warehouse.unpaid > 0
	var record: Dictionary = business.staff.records[role]
	get_node("HappinessLabel").text = "%s | Happiness: %d / 100" % [business.staff.name_for(role), record.happiness]
	happiness_bar.value = record.happiness
	get_node("EmployeeMessageLabel").text = record.message
	get_node("TalkEmployeeButton").disabled = not business.staff.active(business, role)
	get_node("PayOvertimeButton").text = "Overtime owed: %s%d" % [String.chr(8377), record.unpaid]
	get_node("PayOvertimeButton").disabled = record.unpaid == 0 or record.overtime_end > 0 or business.money < record.unpaid
	money_label.text = "Money: %s%s" % [String.chr(8377), shop._format_money(business.money)]
	var product: String = Catalog.IDS[product_input.selected]
	var quantity := int(box_quantity.value)
	get_node("ProductLabel").text = "Shelf: %d | Warehouse: %d | Box of 10" % [business.product_stock(product), business.logistics.stored_units(product)]
	get_node("PriceLabel").text = "%d items | Total: %s%s" % [quantity * 10, String.chr(8377), shop._format_money(Catalog.COSTS[product] * quantity)]
	order_button.text = "Order %d box%s - %s%s" % [quantity, "" if quantity == 1 else "es", String.chr(8377), shop._format_money(Catalog.COSTS[product] * quantity)]
	order_button.disabled = not business.can_order_stock(product, quantity)
	order_button.tooltip_text = "Supply limit: 20 boxes" if business.supply_box_count() + quantity > business.MAX_SUPPLY_BOXES else ("Not enough money" if order_button.disabled else Catalog.NAMES[product])
	auto_collect.set_pressed_no_signal(business.assistant_auto_collect)
	get_node("SpaceLevelLabel").text = "Shop level %d" % business.shop_level
	get_node("SpaceDimensionsLabel").text = "Floor: 60 m2 | Ceiling: 3.8 m"
	get_node("SpaceQuoteLabel").text = "Full room available"
	expansion_button.text = "Room ready"
	expansion_button.disabled = true
	cashier_label.text = ("Ramesh - Cashier: " if business.worker_hired else "Cashier: ") + _duty_status("cashier", business.worker_hired, business.cashier_on_shift())
	stock_worker_label.text = ("Sunil - Stock: " if business.stock_worker_hired else "Stock assistant: ") + _duty_status("stock", business.stock_worker_hired, business.stock_worker_on_shift())
	get_node("SavedShiftLabel").text = "Scheduled: %02d:00 - %02d:00" % [business.stock_shift_start / 60, business.stock_shift_end / 60]
	level_input.disabled = business.staff.active(business, "cashier")
	var level: int = business.cashier_level if business.staff.active(business, "cashier") else level_input.selected + 1
	var cost: int = business.CASHIER_COSTS[level - 1]
	contract_label.text = "%s200/day | %.0fs / item" % [String.chr(8377), business.CASHIER_SCAN_SECONDS[level - 1]] if role_input.selected == 0 else "%s200/day | Assigned deliveries" % String.chr(8377)
	cashier_button.text = "Hire cashier - %s%s" % [String.chr(8377), shop._format_money(cost)]
	stock_worker_button.text = "Hire stock assistant - %s1,000" % String.chr(8377)
	stock_worker_button.tooltip_text = "Wage: %s200/day. Collects delivered boxes by assignment or automatic collection." % String.chr(8377)
	cashier_button.disabled = business.staff.active(business, "cashier") or business.money < cost or business.staff.records.cashier.unpaid > 0
	stock_worker_button.disabled = business.staff.active(business, "stock") or business.money < business.HIRING_COST or business.staff.records.stock.unpaid > 0
	assign_button.text = "Assign delivered box"
	assign_button.disabled = not business.stock_worker_on_shift() or business.boxed_stock == 0
	var assistant = get_tree().current_scene.get_node("ShopOperations").stock_worker
	if is_instance_valid(assistant) and not assistant.route.is_empty():
		assign_button.disabled = true
		if business.stock_worker_on_shift(): stock_worker_label.text = "Sunil - Stock: Restocking"
		elif business.wages_due == 0: stock_worker_label.text = "Sunil - Stock: Paused (off shift)"
	elif business.stock_worker_on_shift():
		stock_worker_label.text = "Sunil: Waiting for delivery" if business.assistant_auto_collect else "Sunil: Awaiting assignment"
	if business.worker_carried_stock > 0 and business.racks.restock_rack(business.pending_product) < 0: stock_worker_label.text = "Sunil: Waiting for shelf space"
	if business.stock_collection_assigned and (not is_instance_valid(assistant) or assistant.route.is_empty()):
		stock_worker_label.text = "Sunil: Assigned collection" if business.stock_worker_on_shift() else "Sunil: Assigned collection (paused)"
	if business.supply_in_transit > 0:
		status_label.text = "Delivery van on the way"
	elif business.boxed_stock > 0:
		status_label.text = "Delivered outside: %d %s" % [business.boxed_stock, Catalog.NAMES[business.pending_product]]
	elif business.carried_stock > 0:
		status_label.text = "Carrying: " + Catalog.NAMES[business.pending_product]
	elif business.worker_carried_stock > 0:
		status_label.text = "Assistant carrying: " + Catalog.NAMES[business.pending_product]
	else:
		status_label.text = "Ready to order" if business.money >= Catalog.COSTS[product] else "Not enough money"
	if business.supply_box_count() > 1:
		status_label.text = "%d in transit | %d boxes outside\n%s" % [business.incoming_boxes.size(), business.queued_boxes.size() + (1 if business.boxed_stock > 0 else 0), "Handling: " + Catalog.NAMES[business.pending_product] if business.carried_stock + business.worker_carried_stock > 0 else "Ready for pickup"]

func open_menu(from_warehouse := false) -> void:
	shop.sale_price_input.apply()
	shop.shop_menu.hide()
	shop.house_menu.hide()
	ui.bargain_menu.close_menu()
	if is_instance_valid(ui.checkout_menu): ui.checkout_menu.hide()
	_load_staff_settings()
	get_node("TitleLabel").text = "WAREHOUSE ORDERS" if from_warehouse else "MANAGEMENT PC"
	if from_warehouse: tabs.current_tab = 0
	_refresh()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	if is_instance_valid(active_terminal) and active_terminal.active:
		active_terminal.close()
		return
	hide()
	if not shop.shop_menu.visible and not shop.house_menu.visible and not ui.bargain_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _order() -> void:
	retail_price.apply()
	box_quantity.apply()
	var product: String = Catalog.IDS[product_input.selected]
	if shop.business.order_stock(product, int(box_quantity.value)):
		ui.show_feedback("Ordered %d boxes: %s." % [int(box_quantity.value), Catalog.NAMES[product]])
	else: ui.show_feedback("Cannot order: check funds or supply limit.", true)
	_refresh()

func _load_product() -> void:
	retail_price.set_value_no_signal(shop.business.product_price(Catalog.IDS[product_input.selected]))

func _process(_delta: float) -> void:
	if visible: _refresh()

func _duty_status(role: String, hired: bool, on_shift: bool) -> String:
	if not hired: return "Vacant"
	if shop.business.staff.records[role].quit_day > 0: return "Quit"
	if shop.business.wages_due > 0: return "Unpaid wages"
	return "On duty" if on_shift else "Off shift"

func _role() -> String:
	return ["cashier", "stock", "warehouse"][role_input.selected]

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		close_menu()
		get_viewport().set_input_as_handled()

func _refresh_racks() -> void:
	if not is_instance_valid(rack_selector): return
	var business = shop.business
	var signature := str(business.racks.records)
	if signature != rack_signature:
		var selected := maxi(0, rack_selector.selected)
		rack_selector.clear()
		for record in business.racks.records:
			var types: Array = []
			for slot in record.slots:
				if slot.product != "" and slot.product not in types: types.append(slot.product)
			var title: String = "Mixed products" if types.size() > 1 else Catalog.NAMES[types[0]] if not types.is_empty() else "Unassigned rack"
			rack_selector.add_item("%d - %s (%d)" % [record.id + 1, title, record.amount], record.id)
		rack_selector.select(mini(selected, rack_selector.item_count - 1))
		rack_signature = signature
	var record: Dictionary = business.racks.find(rack_selector.get_selected_id())
	var quantity := int(rack_quantity.value)
	get_node("FurnitureQuoteLabel").text = "%s%s | %d racks" % [String.chr(8377), shop._format_money(quantity * business.RackStore.COST), business.racks.records.size()]
	get_node("BuyRackButton").text = "Order %d %s%s" % [quantity, "produce table" if Catalog.IDS[rack_product.selected] == "tomato" else "shelf", "" if quantity == 1 else "s"]
	get_node("RackDeliveryLabel").text = "In transit: %d | Packages outside: %d" % [business.logistics.rack_incoming.size(), business.logistics.rack_delivered.size()]
	get_node("RackInfoLabel").text = "%d items | %s" % [record.amount, "Restocking destination" if record.get("restock", false) else "Display rack"]
	get_node("BuyRackButton").disabled = not business.can_order_racks(Catalog.IDS[rack_product.selected], quantity)
	get_node("MoveRackButton").disabled = business.carried_stock > 0
	get_node("SetRestockRackButton").disabled = record.get("restock", false) or business.worker_carried_stock > 0
	if not is_instance_valid(shelf_selector): return
	var slots: int = business.RackStore.slot_count(record)
	if shelf_selector.item_count != slots:
		shelf_selector.clear()
		for index in range(slots):
			shelf_selector.add_item("Basket R%d C%d" % [index / 4 + 1, index % 4 + 1] if slots == 12 else ["Lower shelf", "Middle shelf", "Upper shelf"][index])
		shelf_selector.select(0)
		shelf_draft_key = ""
	var row := shelf_selector.selected
	var slot: Dictionary = record.slots[row]
	var key := str([record.id, row, slot.product])
	if shelf_draft_key != key:
		shelf_product.select(Catalog.IDS.find(slot.product) + 1)
		shelf_draft_key = key
	get_node("ShelfCapacityLabel").text = "%d / 10 items | %s" % [slot.count, "Occupied" if slot.count > 0 else "Available"]
	get_node("AssignShelfButton").disabled = slot.count > 0 or record.legacy_overflow > 0
	var lines: PackedStringArray = []
	if slots == 12:
		for index in range(3):
			lines.append("Row %d: %d/10 | %d/10 | %d/10 | %d/10" % [index + 1, record.slots[index * 4].count, record.slots[index * 4 + 1].count, record.slots[index * 4 + 2].count, record.slots[index * 4 + 3].count])
	else:
		for index in range(3):
			var item: Dictionary = record.slots[index]
			lines.append("%s: %s (%d / 10)" % [["Lower", "Middle", "Upper"][index], "Unassigned" if item.product == "" else Catalog.NAMES[item.product], item.count])
	get_node("AssignShelfButton").text = "Assign basket product" if slots == 12 else "Assign shelf product"
	get_node("ShelfSummaryLabel").text = "\n".join(lines)
	if record.legacy_overflow > 0: get_node("ShelfCapacityLabel").text = "Legacy surplus: %d | New stocking blocked" % record.legacy_overflow

func _assign_shelf() -> void:
	var product: String = "" if shelf_product.selected == 0 else Catalog.IDS[shelf_product.selected - 1]
	var success: bool = shop.business.assign_shelf_slot(rack_selector.get_selected_id(), shelf_selector.selected, product)
	ui.show_feedback("Shelf assignment saved." if success else "Empty this shelf first, or check save status.", not success)

func _buy_rack() -> void:
	rack_quantity.apply()
	var success: bool = shop.business.order_racks(Catalog.IDS[rack_product.selected], int(rack_quantity.value))
	ui.show_feedback("Rack order placed. Furniture truck on the way." if success else "Cannot order racks: check funds, rack limit and save status.", not success)

func _move_rack() -> void:
	var furnishing = get_tree().current_scene.get_node("RackFurnishing")
	if furnishing.begin_move(rack_selector.get_selected_id()): close_menu()

func _set_restock_rack() -> void:
	if shop.business.set_stock_rack(rack_selector.get_selected_id()): ui.show_feedback("Restocking destination updated.")
