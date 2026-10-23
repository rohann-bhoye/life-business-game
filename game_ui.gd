extends CanvasLayer

const BargainMenu := preload("res://bargain_menu.gd")
const SupplierMenu := preload("res://supplier_menu.gd")
const CheckoutMenu := preload("res://checkout_menu.gd")
const StaffDialog := preload("res://staff_dialog.gd")
const CustomerChat := preload("res://customer_chat.gd")
const FriendChat := preload("res://friend_chat.gd")
const HowToPlay := preload("res://how_to_play.gd")
const ShopTablet := preload("res://shop_tablet.gd")
const NotificationFeed := preload("res://notification_feed.gd")
const MenuSkin := preload("res://menu_skin.gd")
const PauseMenu := preload("res://pause_menu.gd")
var notifications: Control
var tablet: Node3D
var staff_dialog: Panel
var customer_chat: Panel
## Counter order list on the right of the screen (order_panel.gd).
var order_panel: Panel
var friend_chat: Panel
var how_to_play: Control
var employee_role := "cashier"
const EMPLOYEE_CONTROLS := ["CashierSelectButton", "StockSelectButton", "WorkSwitch", "AutoCollectSwitch", "CollectDeliveryButton", "TalkEmployeeButton"]

const TAB_CONTROLS := [
	["SalesLabel", "RevenueLabel", "ExpensesLabel", "ProfitLabel", "DailyCostLabel", "UnpaidBillsLabel", "PayBillsButton", "HomeOwnershipLabel"],
	["SalePriceLabel", "SalePriceInput", "BuyStockButton", "ShopStatusLabel", "ShopHoursLabel", "ShopLevelLabel", "UpgradeShopButton"],
	["WorkerLabel", "WorkerStatusLabel", "HireWorkerButton", "WageLabel"],
	["MarketingLabel", "MarketingButton", "MissedSalesLabel", "LastVisitLabel", "ReputationLabel"],
	["DemoStatusLabel", "DemoGoal0", "DemoGoal1", "DemoGoal2", "DemoGoal3", "DemoGoal4", "DemoResultsLabel", "DemoContinueButton"],
	["FarmSummary", "BuySeedsButton", "FarmUpgradeButton", "FarmCropButton", "SeedQuantityInput", "BuyProduceTableButton", "HireFarmerButton"]
]

var tabs: TabBar
var hud_money: Label
## The town's name, top centre of the HUD.
var town_label: Label
var interaction_label: Label
var feedback_label: Label
var controls_panel: Panel
var crosshair: Control
var first_day_panel: Panel
var first_day_label: Label
var first_day_step: Label
var day_report_screen: Control
const UiStyle := preload("res://ui_style.gd")
var feedback_seconds := 0.0
var employee_refresh_seconds := 0.0
var selected_tab := 0
var shop_status: Label
var shop_level_label: Label
var upgrade_button: Button
var bargain_menu: Panel
var supplier_menu: Panel
var checkout_menu: Panel

@onready var shop = get_tree().current_scene.get_node("Shop/ShopArea")
@onready var house = get_tree().current_scene.get_node("House/HouseArea")
@onready var sleep_area = get_tree().current_scene.get_node("House/Bed/SleepArea")
@onready var player = get_tree().current_scene.get_node("Player")
@onready var shop_menu: Panel = $ShopMenu
@onready var house_menu: Panel = $HouseMenu

func _ready() -> void:
	get_tree().root.content_scale_size = Vector2i.ZERO
	var theme := _make_theme()
	shop_menu.theme = theme
	shop.pay_bills_button.icon = MenuSkin.texture("checkmark", 16)
	house_menu.theme = theme
	shop_menu.remove_theme_stylebox_override("panel")
	house_menu.remove_theme_stylebox_override("panel")
	for button in [shop.buy_stock_button, shop.marketing_button, shop.hire_worker_button, shop.pay_bills_button]:
		for state in ["normal", "hover", "pressed"]:
			button.remove_theme_stylebox_override(state)
	hud_money = _label("HudMoneyLabel", self)
	town_label = _label("TownLabel", self)
	town_label.text = preload("res://town_boundary.gd").TOWN_NAME
	town_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	town_label.add_theme_font_size_override("font_size", 16)
	town_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	crosshair = preload("res://crosshair.gd").new()
	crosshair.name = "Crosshair"
	add_child(crosshair)
	interaction_label = _label("InteractionLabel", self)
	# What the crosshair is on (product, box, rack, PC...) reads right under it.
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	interaction_label.add_theme_constant_override("outline_size", 6)
	feedback_label = _label("FeedbackLabel", self)
	_build_first_day_guide(theme)
	_build_day_report(theme)
	_build_controls_hint()
	_label("FarmSummary", shop_menu)
	_label("SeedQuantityLabel", shop_menu).text = "Seed packets"
	shop_menu.get_node("SeedQuantityLabel").hide()
	# Cycles the farm crop used for buying seeds and planting (works on the tablet too).
	var crop_button := Button.new()
	crop_button.name = "FarmCropButton"
	shop_menu.add_child(crop_button)
	crop_button.pressed.connect(func():
		var crops: Array = shop.business.farm.CROPS
		shop.business.set_farm_crop(crops[(crops.find(shop.business.farm.crop) + 1) % crops.size()])
		_refresh_farm())
	var seed_quantity := SpinBox.new()
	seed_quantity.name = "SeedQuantityInput"
	seed_quantity.min_value = 1
	seed_quantity.max_value = 10
	seed_quantity.step = 1
	seed_quantity.value = 1
	shop_menu.add_child(seed_quantity)
	seed_quantity.value_changed.connect(func(_value): _refresh_farm())
	for item in [["BuySeedsButton", "Buy tomato seed - %s100" % String.chr(8377)], ["FarmUpgradeButton", "Expand farm"], ["BuyProduceTableButton", "Order produce table - %s1,000" % String.chr(8377)], ["HireFarmerButton", "Hire farmer Kiran - %s1,500" % String.chr(8377)]]:
		var button := Button.new()
		button.name = item[0]
		button.text = item[1]
		shop_menu.add_child(button)
	shop_menu.get_node("BuySeedsButton").pressed.connect(func():
		var success: bool = shop.business.buy_seeds(int(shop_menu.get_node("SeedQuantityInput").value))
		show_feedback("%s seeds purchased." % shop.business.farm.CROP_NAMES[shop.business.farm.crop] if success else "Not enough money or save failed.", not success))
	shop_menu.get_node("HireFarmerButton").pressed.connect(func():
		var success: bool = shop.business.hire_farm_worker()
		show_feedback("Kiran hired. He plants, waters and harvests by day; harvests go to warehouse storage." if success else "Not enough money or save failed.", not success))
	shop_menu.get_node("FarmUpgradeButton").pressed.connect(func():
		var success: bool = shop.business.upgrade_farm()
		show_feedback("Farm expanded." if success else "Farm needs the next shop level, money, or a successful save.", not success))
	shop_menu.get_node("BuyProduceTableButton").pressed.connect(func():
		var success: bool = shop.business.order_racks("tomato", 1)
		show_feedback("Produce table ordered. Collect its package at the warehouse." if success else "Cannot order: check money, display limit or save status.", not success))
	_label("ReputationLabel", shop_menu)
	for node_name in TAB_CONTROLS[4]:
		if node_name == "DemoContinueButton":
			var button := Button.new()
			button.name = node_name
			button.text = "Continue shop"
			shop_menu.add_child(button)
			button.pressed.connect(func(): shop._on_close_button_pressed())
		else: _label(node_name, shop_menu)
	var wage_label := _label("WageLabel", shop_menu)
	wage_label.text = "Wage: %s200 / day" % String.chr(8377)
	shop_status = _label("ShopStatusLabel", shop_menu)
	var hours_label := _label("ShopHoursLabel", shop_menu)
	hours_label.text = "Hours: %02d:00 - %02d:00" % [shop.business.SHOP_OPEN_MINUTE / 60, shop.business.SHOP_CLOSE_MINUTE / 60]
	shop_level_label = _label("ShopLevelLabel", shop_menu)
	upgrade_button = Button.new()
	upgrade_button.name = "UpgradeShopButton"
	shop_menu.add_child(upgrade_button)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	tabs = TabBar.new()
	tabs.name = "ShopTabs"
	shop_menu.add_child(tabs)
	for title in ["Overview", "Stock", "Staff", "Marketing", "Goals", "Farm"]:
		tabs.add_tab(title)
	tabs.tab_changed.connect(select_tab)
	shop_menu.visibility_changed.connect(_on_shop_visibility_changed)
	get_viewport().size_changed.connect(_layout)
	shop.business.changed.connect(_update_hud)
	shop.business.clock_changed.connect(_update_shop_status)
	_update_shop_status()
	_update_hud()
	select_tab(0)
	_layout()
	bargain_menu = Panel.new()
	bargain_menu.name = "BargainMenu"
	bargain_menu.set_script(BargainMenu)
	bargain_menu.theme = theme
	add_child(bargain_menu)
	supplier_menu = Panel.new()
	supplier_menu.name = "SupplierMenu"
	supplier_menu.set_script(SupplierMenu)
	supplier_menu.theme = theme
	add_child(supplier_menu)
	checkout_menu = Panel.new()
	checkout_menu.name = "CheckoutMenu"
	checkout_menu.set_script(CheckoutMenu)
	checkout_menu.theme = theme
	add_child(checkout_menu)
	staff_dialog = Panel.new()
	staff_dialog.name = "StaffDialog"
	staff_dialog.set_script(StaffDialog)
	staff_dialog.theme = theme
	add_child(staff_dialog)
	customer_chat = Panel.new()
	customer_chat.name = "CustomerChat"
	customer_chat.set_script(CustomerChat)
	customer_chat.theme = theme
	add_child(customer_chat)
	friend_chat = Panel.new()
	friend_chat.name = "FriendChat"
	friend_chat.set_script(FriendChat)
	friend_chat.theme = theme
	add_child(friend_chat)
	order_panel = preload("res://order_panel.gd").new()
	order_panel.theme = theme
	add_child(order_panel)
	shop.business.khata_news.connect(func(message: String, good: bool): show_feedback(message, not good))
	how_to_play = HowToPlay.new()
	add_child(how_to_play)
	how_to_play.closed.connect(func():
		if not player._menu_is_open(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	# A player's first new game from the menu shows the guide once by itself.
	var scene := get_tree().current_scene
	if scene.has_meta("session_save_path") and not HowToPlay.seen() and shop.business.day == 1 and shop.business.items_sold == 0:
		get_tree().create_timer(1.0).timeout.connect(func():
			if not player._menu_is_open(): how_to_play.open())
	notifications = NotificationFeed.new()
	notifications.name = "NotificationFeed"
	add_child(notifications)
	if get_tree().current_scene.get_node("ShopOperations").enabled:
		_label("SectionLabel", shop_menu)
		for node_name in ["HeaderDivider", "FooterDivider"]:
			var divider := HSeparator.new()
			divider.name = node_name
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shop_menu.add_child(divider)
		_build_employee_actions()
		tablet = ShopTablet.new()
		player.camera.add_child(tablet)
		tablet.configure(self)
		_refresh_employee()
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	pause.theme = theme
	add_child(pause)
	if get_tree().current_scene.get_node("ShopOperations").enabled:
		var farm := Node3D.new()
		farm.name = "Farm"
		farm.set_script(preload("res://farm_world.gd"))
		get_tree().current_scene.add_child.call_deferred(farm)

func _build_controls_hint() -> void:
	controls_panel = Panel.new()
	controls_panel.name = "DesktopControls"
	controls_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.05, 0.06, 0.82)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	controls_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(controls_panel)
	_keycap("W", Vector2(42, 8))
	_keycap("A", Vector2(8, 42))
	_keycap("S", Vector2(42, 42))
	_keycap("D", Vector2(76, 42))
	_keycap("E", Vector2(8, 82))
	var interact := _label("InteractText", controls_panel)
	interact.text = "INTERACT"
	_place(interact, 42, 84, 68, 24)
	interact.add_theme_font_size_override("font_size", 12)
	var mouse := _label("MouseLookText", controls_panel)
	mouse.text = "MOUSE\nLOOK"
	mouse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(mouse, 122, 20, 72, 46)
	mouse.add_theme_font_size_override("font_size", 12)
	_keycap("Q", Vector2(122, 82))
	var drop := _label("DropText", controls_panel)
	drop.text = "DROP"
	_place(drop, 154, 84, 42, 24)
	drop.add_theme_font_size_override("font_size", 12)
	_keycap("G", Vector2(8, 116))
	var move := _label("MoveText", controls_panel)
	move.text = "MOVE"
	_place(move, 42, 118, 68, 24)
	move.add_theme_font_size_override("font_size", 12)
	_keycap("TAB", Vector2(112, 116))
	controls_panel.get_node("KeyTAB").add_theme_font_size_override("font_size", 10)
	controls_panel.get_node("KeyTAB").size.x = 38
	var tablet_text := _label("TabletText", controls_panel)
	tablet_text.text = "TABLET"
	_place(tablet_text, 154, 118, 48, 24)
	tablet_text.add_theme_font_size_override("font_size", 11)

func _keycap(text: String, at: Vector2) -> void:
	var key := Label.new()
	key.name = "Key" + text
	key.text = text
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_theme_color_override("font_color", Color(0.08, 0.11, 0.12))
	key.add_theme_font_size_override("font_size", 15)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.96, 0.98, 0.99)
	box.border_color = Color(0.55, 0.62, 0.65)
	box.set_border_width_all(1)
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	key.add_theme_stylebox_override("normal", box)
	controls_panel.add_child(key)
	_place(key, at.x, at.y, 28, 28)

func _build_employee_actions() -> void:
	for node_name in EMPLOYEE_CONTROLS:
		var button: Button = CheckButton.new() if node_name in ["WorkSwitch", "AutoCollectSwitch"] else Button.new()
		button.name = node_name
		shop_menu.add_child(button)
		button.hide()
	shop_menu.get_node("CashierSelectButton").text = "Ramesh"
	shop_menu.get_node("StockSelectButton").text = "Sunil"
	shop_menu.get_node("CashierSelectButton").toggle_mode = true
	shop_menu.get_node("StockSelectButton").toggle_mode = true
	shop_menu.get_node("CollectDeliveryButton").text = "Collect delivery"
	shop_menu.get_node("TalkEmployeeButton").text = "Talk"
	shop_menu.get_node("AutoCollectSwitch").text = "Auto collect deliveries"
	shop_menu.get_node("CashierSelectButton").pressed.connect(func(): employee_role = "cashier"; _refresh_employee())
	shop_menu.get_node("StockSelectButton").pressed.connect(func(): employee_role = "stock"; _refresh_employee())
	shop_menu.get_node("WorkSwitch").toggled.connect(func(enabled): shop.business.set_employee_work(employee_role, enabled); _refresh_employee())
	shop_menu.get_node("AutoCollectSwitch").toggled.connect(func(enabled): shop.business.set_assistant_auto_collect(enabled))
	shop_menu.get_node("CollectDeliveryButton").pressed.connect(func():
		var worker = get_tree().current_scene.get_node("StockWorker")
		if worker.assign_delivery(): show_feedback("Sunil is collecting the delivery.")
		_refresh_employee())
	shop_menu.get_node("TalkEmployeeButton").pressed.connect(func(): staff_dialog.open_for(employee_role))

func open_employee(role: String) -> void:
	if role not in shop.business.staff.ROLES or not is_instance_valid(tablet): return
	employee_role = role
	house_menu.hide()
	shop_menu.show()
	select_tab(2)
	_refresh_employee()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _refresh_employee() -> void:
	if not is_instance_valid(tablet) or selected_tab != 2: return
	var business = shop.business
	var active: bool = business.staff.active(business, employee_role)
	var record: Dictionary = business.staff.records[employee_role]
	var work = shop_menu.get_node("WorkSwitch")
	work.set_pressed_no_signal(record.work_enabled)
	work.text = "Work: ON" if record.work_enabled else "Work: OFF"
	work.disabled = not active
	var is_stock := employee_role == "stock"
	shop_menu.get_node("CashierSelectButton").set_pressed_no_signal(not is_stock)
	shop_menu.get_node("StockSelectButton").set_pressed_no_signal(is_stock)
	shop.worker_label.text = "%s | %s" % [business.staff.name_for(employee_role), "Stock assistant" if is_stock else "Cashier L%d" % business.cashier_level]
	var status := "Not hired" if not business.staff.hired(business, employee_role) else "Off shift"
	if record.quit_day > 0: status = "Resigned"
	elif active:
		if business.wages_due > 0: status = "Unpaid wages"
		elif not record.work_enabled: status = "Paused by owner"
		elif business.staff.on_shift(business, employee_role):
			if is_stock:
				var worker = get_tree().current_scene.get_node("StockWorker")
				status = "Restocking" if not worker.route.is_empty() else ("Delivery ready" if business.boxed_stock > 0 else "Waiting for delivery")
				if business.worker_carried_stock > 0 and business.racks.restock_rack(business.pending_product) < 0: status = "Waiting for shelf space"
			else: status = "Serving customers"
		elif record.state in ["leave", "pay"]: status = "Waiting to talk"
	shop.worker_status_label.text = status
	shop.hire_worker_button.text = "Hiring - Shop PC"
	var auto = shop_menu.get_node("AutoCollectSwitch")
	auto.visible = is_stock
	auto.set_pressed_no_signal(business.assistant_auto_collect)
	auto.disabled = not active
	var collect = shop_menu.get_node("CollectDeliveryButton")
	collect.visible = is_stock
	collect.disabled = not business.stock_worker_on_shift() or business.boxed_stock == 0 or not get_tree().current_scene.get_node("StockWorker").route.is_empty()
	shop_menu.get_node("TalkEmployeeButton").disabled = not business.staff.hired(business, employee_role)
	shop_menu.get_node("WageLabel").text = "%02d:00 - %02d:00 | %s200/day" % [business.get(employee_role + "_shift_start") / 60, business.get(employee_role + "_shift_end") / 60, String.chr(8377)]

func _label(node_name: String, parent: Node) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14
	var panel := _style(Color(0.075, 0.085, 0.09, 0.97))
	panel.border_color = Color(0.28, 0.31, 0.32)
	panel.set_border_width_all(1)
	theme.set_stylebox("panel", "Panel", panel)
	var focus := _style(Color(0, 0, 0, 0))
	focus.border_color = Color(0.4, 0.8, 0.68)
	focus.set_border_width_all(2)
	for type in ["Button", "OptionButton", "TabBar"]:
		theme.set_stylebox("normal" if type != "TabBar" else "tab_unselected", type, _style(Color(0.17, 0.19, 0.2)))
		theme.set_stylebox("hover" if type != "TabBar" else "tab_hovered", type, _style(Color(0.22, 0.29, 0.28)))
		theme.set_stylebox("pressed" if type != "TabBar" else "tab_selected", type, _style(Color(0.12, 0.4, 0.33)))
		theme.set_stylebox("disabled", type, _style(Color(0.12, 0.13, 0.14)))
		theme.set_stylebox("focus", type, focus)
		theme.set_color("font_disabled_color", type, Color(0.58, 0.6, 0.6))
	var input := _style(Color(0.12, 0.14, 0.15))
	input.border_color = Color(0.32, 0.37, 0.38)
	input.set_border_width_all(1)
	theme.set_stylebox("normal", "LineEdit", input)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_stylebox("panel", "PopupMenu", panel)
	theme.set_stylebox("hover", "PopupMenu", _style(Color(0.12, 0.4, 0.33)))
	MenuSkin.apply(theme)
	return theme

func _place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2(x, y)
	control.size = Vector2(width, height)

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < 320 or viewport_size.y < 480:
		return
	var width := minf(440.0, viewport_size.x - 32.0)
	var height := minf(424.0, viewport_size.y - 72.0)
	_place(shop_menu, 16, 56, width, height)
	_place(house_menu, 16, 56, minf(340.0, width), 280)
	var content_width := width - 32.0
	_place(shop_menu.get_node("TitleLabel"), 16, 12, content_width - 74, 28)
	_place(shop.close_button, width - 78, 12, 62, 28)
	shop.close_button.text = "Close"
	_place(shop.money_label, 16, 50, content_width * 0.6, 24)
	_place(shop.stock_label, 16 + content_width * 0.6, 50, content_width * 0.4, 24)
	_place(tabs, 16, 88, content_width, 34)
	_place(shop.save_status_label, 16, height - 36, content_width, 24)
	for tab_index in range(TAB_CONTROLS.size()):
		for index in range(TAB_CONTROLS[tab_index].size()):
			var control: Control = shop_menu.get_node(TAB_CONTROLS[tab_index][index])
			_place(control, 16, 140 + index * 26, content_width, 24)
	_place(shop.pay_bills_button, 16, 304, content_width, 32)
	_place(shop.home_ownership_label, 16, 344, content_width, 24)
	_place(shop.sale_price_input, 16 + content_width * 0.5, 140, content_width * 0.5, 32)
	_place(shop_menu.get_node("SalePriceLabel"), 16, 140, content_width * 0.45, 32)
	_place(shop.buy_stock_button, 16, 190, content_width, 36)
	_place(shop_status, 16, 240, content_width, 24)
	_place(shop_menu.get_node("ShopHoursLabel"), 16, 272, content_width, 24)
	_place(shop_level_label, 16, 304, content_width, 24)
	_place(upgrade_button, 16, 334, content_width, 32)
	_place(shop.worker_status_label, 16, 170, content_width, 24)
	_place(shop.hire_worker_button, 16, 208, content_width, 36)
	_place(shop_menu.get_node("WageLabel"), 16, 258, content_width, 24)
	_place(shop.marketing_button, 16, 178, content_width, 36)
	_place(shop.missed_sales_label, 16, 232, content_width, 24)
	_place(shop.last_visit_label, 16, 264, content_width, 48)
	_place(shop_menu.get_node("ReputationLabel"), 16, 320, content_width, 44)
	_place(shop_menu.get_node("DemoStatusLabel"), 16, 140, content_width, 24)
	for index in range(5): _place(shop_menu.get_node("DemoGoal%d" % index), 16, 180 + index * 32, content_width, 28)
	_place(shop_menu.get_node("DemoResultsLabel"), 16, 180, content_width, 144)
	_place(shop_menu.get_node("DemoContinueButton"), 16, 336, content_width, 32)
	_place(shop_menu.get_node("FarmSummary"), 16, 140, content_width, 116)
	shop_menu.get_node("FarmSummary").add_theme_font_size_override("font_size", 16)
	_place(shop_menu.get_node("SeedQuantityLabel"), 16, 260, content_width * 0.5, 32)
	_place(shop_menu.get_node("FarmCropButton"), 16, 260, content_width * 0.5 - 6, 32)
	_place(shop_menu.get_node("SeedQuantityInput"), 16 + content_width * 0.5, 260, content_width * 0.5, 32)
	_place(shop_menu.get_node("BuySeedsButton"), 16, 304, content_width * 0.5 - 4, 36)
	_place(shop_menu.get_node("HireFarmerButton"), 16 + content_width * 0.5 + 4, 304, content_width * 0.5 - 4, 36)
	_place(shop_menu.get_node("FarmUpgradeButton"), 16, 348, content_width, 36)
	_place(shop_menu.get_node("BuyProduceTableButton"), 16, 392, content_width, 36)
	shop.last_visit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop.unpaid_bills_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	for child in house_menu.get_children():
		if child is Control:
			child.size.x = house_menu.size.x - 40.0
	house.close_house_button.size.x = 80.0
	_place(hud_money, 16, 12, maxf(120, viewport_size.x - 240), 28)
	_place($ClockLabel, viewport_size.x - 256, 12, 240, 28)
	_place(town_label, (viewport_size.x - 240) / 2.0, 12, 240, 28)
	$ClockLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(first_day_panel, viewport_size.x - 276, 50, 260, 156)
	_place(first_day_panel.get_node("Title"), 12, 8, 236, 20)
	_place(first_day_label, 12, 30, 236, 64)
	_place(first_day_step, 12, 98, 236, 52)
	_place(interaction_label, (viewport_size.x - minf(520, viewport_size.x - 32)) / 2.0, viewport_size.y / 2.0 + 18, minf(520, viewport_size.x - 32), 24)
	_place(feedback_label, 16, viewport_size.y - 80, viewport_size.x - 32, 28)
	_place(controls_panel, viewport_size.x - 218, viewport_size.y - 166, 202, 150)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.clip_text = true
	if is_instance_valid(tablet): _layout_tablet()

func _tablet_theme(compact: bool) -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18 if compact else 22
	theme.set_stylebox("panel", "Panel", _style(Color(0.94, 0.96, 0.97)))
	for type in ["Label", "Button", "TabBar", "LineEdit", "SpinBox"]:
		theme.set_color("font_color", type, Color(0.12, 0.18, 0.2))
		theme.set_color("font_selected_color", type, Color.WHITE)
		theme.set_color("font_disabled_color", type, Color(0.45, 0.5, 0.52))
	theme.set_color("font_unselected_color", "TabBar", Color(0.2, 0.3, 0.33))
	for type in ["Button", "TabBar"]:
		theme.set_stylebox("normal" if type == "Button" else "tab_unselected", type, _style(Color(0.84, 0.89, 0.91)))
		theme.set_stylebox("hover" if type == "Button" else "tab_hovered", type, _style(Color(0.74, 0.84, 0.85)))
		theme.set_stylebox("pressed" if type == "Button" else "tab_selected", type, _style(Color(0.08, 0.38, 0.33)))
		theme.set_stylebox("disabled", type, _style(Color(0.89, 0.92, 0.93)))
		theme.set_color("font_pressed_color", type, Color.WHITE)
	var input := _style(Color.WHITE)
	input.border_color = Color(0.6, 0.7, 0.73)
	input.set_border_width_all(1)
	theme.set_stylebox("normal", "LineEdit", input)
	var focus := _style(Color(0, 0, 0, 0))
	focus.border_color = Color(0.05, 0.5, 0.42)
	focus.set_border_width_all(2)
	for type in ["Button", "LineEdit", "TabBar"]: theme.set_stylebox("focus", type, focus)
	theme.set_font_size("font_size", "TabBar", 14 if compact else 20)
	MenuSkin.apply(theme, true)
	theme.set_constant("tab_separation", "TabBar", 6 if compact else 10)
	# Kenney Future is wide: narrow (portrait) screens keep the compact standard font.
	if compact: theme.set_font("font", "TabBar", ThemeDB.fallback_font)
	theme.set_font_size("font_size", "TabBar", 14 if compact else 15)
	for state in ["tab_unselected", "tab_hovered", "tab_selected", "disabled"]:
		var style := theme.get_stylebox(state, "TabBar")
		style.content_margin_left = 8 if compact else 16
		style.content_margin_right = 8 if compact else 16
	return theme

func _layout_tablet() -> void:
	var size: Vector2 = tablet.screen_viewport.size
	var compact := size.x < 600
	shop_menu.theme = _tablet_theme(compact)
	_place(shop_menu, 0, 0, size.x, size.y)
	var width := size.x - 48
	if width < 380:
		shop_menu.theme.set_font_size("font_size", "TabBar", 12)
		for state in ["tab_unselected", "tab_hovered", "tab_selected", "disabled"]:
			var style := shop_menu.theme.get_stylebox(state, "TabBar")
			style.content_margin_left = 5
			style.content_margin_right = 5
	for child in shop_menu.get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size", 18 if compact else 22)
			child.add_theme_constant_override("shadow_offset_x", 0)
			child.add_theme_constant_override("shadow_offset_y", 0)
	shop_menu.get_node("TitleLabel").text = "SHOP MANAGER"
	_place(shop_menu.get_node("TitleLabel"), 24, 16, width - 64, 36)
	shop.close_button.text = ""
	shop.close_button.icon = MenuSkin.texture("close")
	shop.close_button.add_theme_constant_override("icon_max_width", 16)
	shop.close_button.tooltip_text = "Put away tablet"
	_place(shop.close_button, size.x - 68, 16, 44, 40)
	_place(shop.money_label, 24, 66, width * 0.67, 42)
	shop.money_label.add_theme_font_size_override("font_size", 20 if compact else 30)
	_place(shop.stock_label, 24 + width * 0.67, 66, width * 0.33, 42)
	_place(tabs, 24, 126, width, 44)
	_place(shop_menu.get_node("HeaderDivider"), 24, 114, width, 1)
	_place(shop_menu.get_node("FooterDivider"), 24, 550, width, 1)
	_place(shop_menu.get_node("SectionLabel"), 24, 190, width, 28)
	shop_menu.get_node("SectionLabel").text = ["BUSINESS SUMMARY", "INVENTORY & GROWTH", "EMPLOYEES", "CUSTOMER REACH", "DEMO GOALS", "FARM & SEEDS"][selected_tab]
	shop_menu.get_node("SectionLabel").add_theme_font_size_override("font_size", 14)
	shop_menu.get_node("SectionLabel").modulate = Color(0.38, 0.47, 0.5)
	for tab_index in range(TAB_CONTROLS.size()):
		for index in range(TAB_CONTROLS[tab_index].size()):
			_place(shop_menu.get_node(TAB_CONTROLS[tab_index][index]), 24, 236 + index * 36, width, 28)
	_place(shop.pay_bills_button, 24, 464, width, 42)
	_place(shop.home_ownership_label, 24, 514, width, 28)
	if not compact:
		for index in range(6):
			_place(shop_menu.get_node(TAB_CONTROLS[0][index]), 24 + (width * 0.52 if index % 2 else 0.0), 236 + (index / 2) * 68, width * 0.48, 32)
	_place(shop_menu.get_node("SalePriceLabel"), 24, 236, width * 0.5, 44)
	_place(shop.sale_price_input, 24 + width * 0.55, 236, width * 0.45, 44)
	_place(shop.buy_stock_button, 24, 296, width, 44)
	_place(shop_status, 24, 368, width, 28)
	_place(shop_menu.get_node("ShopHoursLabel"), 24, 408, width, 28)
	_place(shop_level_label, 24, 448, width, 28)
	_place(upgrade_button, 24, 492, width, 44)
	_place(shop.worker_status_label, 24, 280, width, 28)
	_place(shop.hire_worker_button, 24, 344, width, 44)
	_place(shop_menu.get_node("WageLabel"), 24, 408, width, 28)
	_place(shop_menu.get_node("CashierSelectButton"), 24, 230, width * 0.5 - 6, 40)
	_place(shop_menu.get_node("StockSelectButton"), 30 + width * 0.5, 230, width * 0.5 - 6, 40)
	_place(shop.worker_label, 24, 282, width, 28)
	_place(shop.worker_status_label, 24, 316, width, 28)
	_place(shop_menu.get_node("WorkSwitch"), 24, 354, width, 40)
	_place(shop_menu.get_node("WageLabel"), 24, 400, width, 28)
	_place(shop_menu.get_node("AutoCollectSwitch"), 24, 438, width * 0.65, 40)
	_place(shop_menu.get_node("CollectDeliveryButton"), 24 + width * 0.66, 438, width * 0.34, 40)
	_place(shop.hire_worker_button, 24, 504, width * 0.72 - 6, 40)
	_place(shop_menu.get_node("TalkEmployeeButton"), 24 + width * 0.72, 504, width * 0.28, 40)
	shop.hire_worker_button.text = "Hiring - Shop PC"
	shop.hire_worker_button.add_theme_font_size_override("font_size", 14 if compact else 20)
	shop_menu.get_node("CollectDeliveryButton").add_theme_font_size_override("font_size", 12 if compact else 18)
	shop_menu.get_node("AutoCollectSwitch").add_theme_font_size_override("font_size", 12 if compact else 18)
	if compact:
		_place(shop_menu.get_node("AutoCollectSwitch"), 24, 434, width, 34)
		_place(shop_menu.get_node("CollectDeliveryButton"), 24, 474, width, 30)
		_place(shop.hire_worker_button, 24, 514, width * 0.72 - 6, 32)
		_place(shop_menu.get_node("TalkEmployeeButton"), 24 + width * 0.72, 514, width * 0.28, 32)
	_place(shop.marketing_button, 24, 292, width, 44)
	_place(shop.missed_sales_label, 24, 368, width, 28)
	_place(shop.last_visit_label, 24, 408, width, 56)
	_place(shop_menu.get_node("ReputationLabel"), 24, 480, width, 56)
	_place(shop_menu.get_node("DemoStatusLabel"), 24, 236, width, 32)
	for index in range(5): _place(shop_menu.get_node("DemoGoal%d" % index), 24, 280 + index * 44, width, 32)
	_place(shop_menu.get_node("DemoResultsLabel"), 24, 288, width, 160)
	_place(shop_menu.get_node("DemoContinueButton"), 24, 488, width, 42)
	_place(shop_menu.get_node("FarmSummary"), 24, 236, width, 144)
	shop_menu.get_node("FarmSummary").add_theme_font_size_override("font_size", 18)
	_place(shop_menu.get_node("SeedQuantityLabel"), 24, 386, width * 0.5, 34)
	_place(shop_menu.get_node("FarmCropButton"), 24, 386, width * 0.5 - 8, 34)
	_place(shop_menu.get_node("SeedQuantityInput"), 24 + width * 0.5, 386, width * 0.5, 34)
	_place(shop_menu.get_node("BuySeedsButton"), 24, 434, width * 0.48, 38)
	_place(shop_menu.get_node("HireFarmerButton"), 24 + width * 0.52, 434, width * 0.48, 38)
	_place(shop_menu.get_node("FarmUpgradeButton"), 24, 478, width * 0.48, 42)
	_place(shop_menu.get_node("BuyProduceTableButton"), 24 + width * 0.52, 478, width * 0.48, 42)
	if not compact: _layout_tablet_cards(width)
	_place(shop.save_status_label, 24, 560, width, 24)
	shop.save_status_label.add_theme_font_size_override("font_size", 14)
	shop.profit_label.modulate = Color(0.04, 0.42, 0.3) if shop.business.net_profit() >= 0 else Color(0.75, 0.18, 0.14)
	shop.unpaid_bills_label.modulate = Color(0.65, 0.35, 0.04) if shop.business.unpaid_bills() > 0 else Color.WHITE

## Landscape tablet: each tab's text sits on white cards (drawn by shop_tablet.gd
## from tablet_tiles) with room between them; the Farm tab uses two columns.
func _layout_tablet_cards(width: float) -> void:
	var half := width * 0.5
	# Stock: price card, PC button, status and hours side by side, level, upgrade.
	_place(shop_menu.get_node("SalePriceLabel"), 40, 238, half - 40, 40)
	_place(shop.sale_price_input, 24 + half, 238, half - 16, 40)
	_place(shop.buy_stock_button, 24, 300, width, 42)
	_place(shop_status, 40, 370, half - 44, 28)
	_place(shop_menu.get_node("ShopHoursLabel"), 40 + half, 370, half - 44, 28)
	_place(shop_level_label, 40, 430, width - 32, 28)
	_place(upgrade_button, 24, 490, width, 42)
	# Marketing: status card, button, two small cards, reputation card.
	_place(shop_menu.get_node("MarketingLabel"), 40, 238, width - 32, 30)
	_place(shop.marketing_button, 24, 292, width, 42)
	_place(shop.missed_sales_label, 40, 366, half - 44, 30)
	_place(shop.last_visit_label, 40 + half, 366, half - 44, 30)
	shop.last_visit_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	shop.last_visit_label.clip_text = true
	_place(shop_menu.get_node("ReputationLabel"), 40, 436, width - 32, 64)
	# Goals: the count, then one card per goal with a progress bar.
	_place(shop_menu.get_node("DemoStatusLabel"), 28, 230, width - 8, 30)
	for index in range(5): _place(shop_menu.get_node("DemoGoal%d" % index), 40, 272 + index * 54, width - 96, 28)
	# Farm: summary card on the left, actions stacked on the right.
	_place(shop_menu.get_node("FarmSummary"), 40, 238, half - 52, 216)
	shop_menu.get_node("FarmSummary").add_theme_font_size_override("font_size", 17)
	# Clip first, so long prices never widen the buttons past the column.
	for node_name in ["FarmCropButton", "BuySeedsButton", "HireFarmerButton", "FarmUpgradeButton", "BuyProduceTableButton"]:
		shop_menu.get_node(node_name).add_theme_font_size_override("font_size", 14)
		shop_menu.get_node(node_name).clip_text = true
	var right := 24 + half + 8
	var column := half - 8
	_place(shop_menu.get_node("FarmCropButton"), right, 232, column, 40)
	_place(shop_menu.get_node("SeedQuantityLabel"), right, 232, column, 40)
	_place(shop_menu.get_node("SeedQuantityInput"), right, 280, column, 40)
	_place(shop_menu.get_node("BuySeedsButton"), right, 328, column, 40)
	_place(shop_menu.get_node("HireFarmerButton"), right, 376, column, 40)
	_place(shop_menu.get_node("FarmUpgradeButton"), right, 424, column, 40)
	_place(shop_menu.get_node("BuyProduceTableButton"), right, 472, column, 40)

## Cards the tablet draws behind the text of tab `tab` (shop_tablet.gd _draw_chrome):
## {rect, accent, progress}; progress is 0..1 on goal cards, -1 elsewhere.
func tablet_tiles(tab: int) -> Array:
	var groups: Array = [[], [["SalePriceLabel", "SalePriceInput"], ["ShopStatusLabel"], ["ShopHoursLabel"], ["ShopLevelLabel"]], [["WorkerLabel", "WorkerStatusLabel", "WorkSwitch", "WageLabel"], ["AutoCollectSwitch", "CollectDeliveryButton"]], [["MarketingLabel"], ["MissedSalesLabel"], ["LastVisitLabel"], ["ReputationLabel"]], [["DemoGoal0"], ["DemoGoal1"], ["DemoGoal2"], ["DemoGoal3"], ["DemoGoal4"]], [["FarmSummary"]]][clampi(tab, 0, 5)]
	var accents := [Color("2563eb"), Color("16a34a"), Color("ea580c"), Color("7c3aed"), Color("0891b2"), Color("dc2626")]
	var tiles: Array = []
	for index in range(groups.size()):
		var area := Rect2()
		var found := false
		for node_name in groups[index]:
			var control: Control = shop_menu.get_node(node_name)
			if not control.visible: continue
			area = Rect2(control.position, control.size) if not found else area.merge(Rect2(control.position, control.size))
			found = true
		if not found: continue
		var progress := _goal_progress(shop_menu.get_node(groups[index][0]).text) if tab == 4 else -1.0
		var grown := area.grow_individual(16, 8, 14 + (56 if tab == 4 else 0), 8 + (12 if tab == 4 else 0))
		tiles.append({"rect": grown, "accent": accents[index % accents.size()], "progress": progress})
	return tiles

## "Order products: 0/1" or "Sales: Rs0 / Rs2,000" -> 0..1 (-1 without a count).
func _goal_progress(text: String) -> float:
	var parts := text.get_slice(":", 1).replace(String.chr(8377), "").replace(",", "").split("/")
	if parts.size() != 2 or not parts[1].strip_edges().is_valid_float(): return -1.0
	var total := float(parts[1].strip_edges())
	return clampf(float(parts[0].strip_edges()) / total, 0.0, 1.0) if total > 0 else -1.0

func select_tab(index: int) -> void:
	if index != 1 and selected_tab == 1:
		shop.sale_price_input.apply()
		shop.sale_price_input.get_line_edit().release_focus()
	selected_tab = index
	if tabs.current_tab != index:
		tabs.current_tab = index
	for tab_index in range(TAB_CONTROLS.size()):
		for node_name in TAB_CONTROLS[tab_index]:
			shop_menu.get_node(node_name).visible = tab_index == index
	if is_instance_valid(tablet):
		shop_menu.get_node("SectionLabel").text = ["BUSINESS SUMMARY", "INVENTORY & GROWTH", "EMPLOYEES", "CUSTOMER REACH", "DEMO GOALS", "FARM & SEEDS"][index]
		for node_name in EMPLOYEE_CONTROLS: shop_menu.get_node(node_name).visible = index == 2
		_refresh_employee()
	_update_demo_goals()

func _on_shop_visibility_changed() -> void:
	if shop_menu.visible:
		select_tab(0)

func _update_hud() -> void:
	_refresh_employee()
	_refresh_farm()
	_update_demo_goals()
	_update_first_day_guide()
	var reviews = shop.business.customer_reviews
	shop_menu.get_node("ReputationLabel").text = "Reputation: %d/100\n%s" % [reviews.reputation, "No reviews yet" if reviews.review_count == 0 else "Last satisfaction: %d/100" % reviews.last_score]
	shop_menu.get_node("ReputationLabel").tooltip_text = "%d customer reviews | Customer visits %+d%%" % [reviews.review_count, roundi((1.0 / shop.business.reputation_traffic_factor() - 1.0) * 100.0)]
	hud_money.text = "Money: %s%s" % [String.chr(8377), shop._format_money(shop.money)]
	shop.profit_label.modulate = Color(0.48, 0.88, 0.67) if shop.business.net_profit() >= 0 else Color(1, 0.61, 0.57)
	shop.unpaid_bills_label.modulate = Color(1, 0.74, 0.43) if shop.business.unpaid_bills() > 0 else Color.WHITE
	_update_upgrade_controls()
	if is_instance_valid(tablet):
		shop.profit_label.modulate = Color(0.04, 0.42, 0.3) if shop.business.net_profit() >= 0 else Color(0.75, 0.18, 0.14)
		shop.unpaid_bills_label.modulate = Color(0.65, 0.35, 0.04) if shop.business.unpaid_bills() > 0 else Color.WHITE

func _update_demo_goals() -> void:
	var demo = shop.business.demo
	var done: bool = demo.completed()
	shop_menu.get_node("DemoStatusLabel").text = "Demo completed" if done else "Your first shop: %d/5 goals" % demo.done_flags().count(true)
	for index in range(5):
		var label: Label = shop_menu.get_node("DemoGoal%d" % index)
		label.text = demo.goal_lines()[index]
		label.modulate = Color(0.3, 0.7, 0.52) if demo.done_flags()[index] else Color.WHITE
		label.visible = selected_tab == 4 and not done
	shop_menu.get_node("DemoResultsLabel").text = "Customers served: %d\nSales: %s%s\nManual stocking goal: %d/10\nSunil's stocking job: Complete" % [demo.customers_served, String.chr(8377), shop._format_money(demo.revenue), demo.player_shelved]
	shop_menu.get_node("DemoResultsLabel").visible = selected_tab == 4 and done
	shop_menu.get_node("DemoContinueButton").visible = selected_tab == 4 and done

func _build_first_day_guide(theme: Theme) -> void:
	first_day_panel = Panel.new()
	first_day_panel.name = "FirstDayGuide"
	first_day_panel.theme = theme
	first_day_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(first_day_panel)
	var title := _label("Title", first_day_panel)
	title.text = "FIRST DAY"
	title.add_theme_font_size_override("font_size", 13)
	first_day_label = _label("NextAction", first_day_panel)
	first_day_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	first_day_label.add_theme_font_size_override("font_size", 14)
	first_day_step = _label("NextStep", first_day_panel)
	first_day_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	first_day_step.add_theme_font_size_override("font_size", 13)
	first_day_step.modulate = Color(1, 0.85, 0.45)
	_update_first_day_guide()

# Full-screen end-of-day report after sleeping; the next day starts on Space/Enter.
func _build_day_report(theme: Theme) -> void:
	day_report_screen = Control.new()
	day_report_screen.set_script(preload("res://day_report_screen.gd"))
	day_report_screen.theme = theme
	add_child(day_report_screen)

func show_day_report(team: Array = []) -> void:
	day_report_screen.open(shop.business, shop._format_money, team)

func _update_first_day_guide() -> void:
	if not is_instance_valid(first_day_panel): return
	var demo = shop.business.demo
	var actions := [
		"Use the shop PC and order products.",
		"Pick up a delivery box and stock 10 items.",
		"Serve 10 customers at checkout.",
		"Let Sunil stock one box while on shift.",
		"Reach %s2,000 in sales." % String.chr(8377)
	]
	var lines: Array[String] = demo.goal_lines()
	var flags: Array[bool] = demo.done_flags()
	var next := flags.find(false)
	first_day_panel.visible = next >= 0 and not player._menu_is_open()
	if next >= 0:
		first_day_label.text = "%d/5  %s\n%s" % [next + 1, actions[next], lines[next]]
		first_day_step.text = "> " + demo.next_step(shop.business)

func _present_demo_completion() -> void:
	var demo = shop.business.demo
	if not is_instance_valid(tablet) or not demo.completed() or demo.completion_seen: return
	if shop_menu.visible and selected_tab == 4:
		shop.business.mark_demo_seen()
	elif not player._menu_is_open():
		feedback_seconds = 0
		shop_menu.show()
		select_tab(4)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		shop.business.mark_demo_seen()

func _update_upgrade_controls() -> void:
	shop_level_label.text = "Level %d | Visit wait: %ss" % [shop.business.shop_level, str(shop.business.customer_spawn_interval(shop.marketing_active))]
	var cost: int = shop.business.next_upgrade_cost()
	upgrade_button.disabled = not shop.business.can_upgrade_shop()
	upgrade_button.text = "Maximum level" if cost == 0 else "Upgrade to level %d - %s%s" % [shop.business.shop_level + 1, String.chr(8377), shop._format_money(cost)]
	upgrade_button.tooltip_text = "Maximum shop level reached" if cost == 0 else ("Not enough money" if upgrade_button.disabled else "Visit wait: %ss" % str(shop.business.CUSTOMER_INTERVALS[shop.business.shop_level] * (0.85 if shop.marketing_active else 1.0)))
	if get_tree().current_scene.get_node("ShopOperations").enabled:
		shop_level_label.text = "Level %d %s | %d m2 | Ceiling: 3.8 m" % [shop.business.shop_level, ["Kirana", "Super Store", "Mega Mart"][shop.business.shop_level - 1], shop.business.shop_floor_area()]
		if cost > 0:
			upgrade_button.text = "%s - %s%s" % [["Super Store", "Mega Mart"][shop.business.shop_level - 1], String.chr(8377), shop._format_money(cost)]
			upgrade_button.tooltip_text = "New shop design inside and out, and more customers; current stock is unchanged."

func _on_upgrade_pressed() -> void:
	var cost: int = shop.business.next_upgrade_cost()
	if shop.business.upgrade_shop():
		show_feedback("Upgraded: Level %d (-%s%s)" % [shop.business.shop_level, String.chr(8377), shop._format_money(cost)])
	else:
		show_feedback("Maximum shop level reached." if cost == 0 else "Not enough money to upgrade.", true)

func _update_shop_status() -> void:
	_refresh_farm()
	var open: bool = shop.business.shop_is_open()
	shop_status.text = "Shop: Open" if open else "Shop: Closed"
	shop_status.modulate = Color(0.48, 0.88, 0.67) if open else Color(1, 0.74, 0.43)
	if is_instance_valid(tablet): shop_status.modulate = Color(0.04, 0.42, 0.3) if open else Color(0.65, 0.35, 0.04)

func _refresh_farm() -> void:
	var farm = shop.business.farm
	shop_menu.get_node("BuyProduceTableButton").disabled = not shop.business.can_order_racks("tomato", 1)
	var count: int = farm.PLOTS[farm.level - 1]
	var crop_name: String = farm.CROP_NAMES[farm.crop]
	shop_menu.get_node("FarmSummary").text = "Farm level %d | %d beds\n%s seeds: %d (all seeds: %d)\nGrowth after water: %d game min\nHarvest: 10 per bed\nTotal harvested: %d" % [farm.level, count, crop_name, farm.crop_seeds[farm.crop], farm.seeds, farm.GROW_MINUTES[farm.level - 1], farm.harvested]
	shop_menu.get_node("FarmCropButton").text = "Crop: %s >" % crop_name
	var seed_cost: int = int(shop_menu.get_node("SeedQuantityInput").value) * farm.SEED_COSTS[farm.crop]
	shop_menu.get_node("BuySeedsButton").disabled = shop.business.money < seed_cost
	shop_menu.get_node("BuySeedsButton").text = "Buy %s seeds - %s%s" % [crop_name.to_lower(), String.chr(8377), shop._format_money(seed_cost)]
	var hire: Button = shop_menu.get_node("HireFarmerButton")
	hire.text = "Kiran works the farm" if farm.worker_hired else "Hire farmer - %s%s" % [String.chr(8377), shop._format_money(farm.WORKER_COST)]
	hire.disabled = farm.worker_hired or shop.business.money < farm.WORKER_COST
	hire.tooltip_text = "%s%d per harvest; harvests go to warehouse storage" % [String.chr(8377), farm.HARVEST_FEE]
	var button: Button = shop_menu.get_node("FarmUpgradeButton")
	button.text = "Maximum farm size" if farm.level == 3 else "Expand to %d beds - %s%s" % [farm.PLOTS[farm.level], String.chr(8377), shop._format_money(farm.UPGRADE_COSTS[farm.level - 1])]
	button.disabled = farm.level == 3 or shop.business.shop_level <= farm.level or shop.business.money < farm.UPGRADE_COSTS[mini(farm.level - 1, 1)]

func show_feedback(message: String, failed := false) -> void:
	feedback_label.text = message
	feedback_label.modulate = Color(1, 0.64, 0.59) if failed else Color(0.65, 1, 0.8)
	feedback_seconds = 4.0
	feedback_label.visible = not shop_menu.visible
	_update_save_footer()

func _update_save_footer() -> void:
	shop.save_status_label.text = feedback_label.text if feedback_seconds > 0.0 and shop_menu.visible else shop.business.save_status
	shop.save_status_label.modulate = feedback_label.modulate if feedback_seconds > 0.0 and shop_menu.visible else Color(0.7, 0.75, 0.75)

func _process(delta: float) -> void:
	_present_demo_completion()
	feedback_seconds = maxf(0, feedback_seconds - delta)
	feedback_label.visible = feedback_seconds > 0 and not shop_menu.visible and not bargain_menu.visible and not supplier_menu.visible and not checkout_menu.visible
	_update_save_footer()
	employee_refresh_seconds -= delta
	if shop_menu.visible and selected_tab == 2 and employee_refresh_seconds <= 0:
		employee_refresh_seconds = 0.15
		_refresh_employee()
	interaction_label.text = ""
	controls_panel.visible = not player._menu_is_open()
	crosshair.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not player._menu_is_open()
	_update_first_day_guide()
	if player._menu_is_open():
		return
	if player.indoors and sleep_area.overlaps_body(player) and shop.business.house_owned:
		interaction_label.text = "Sleep until morning" if shop.business.sleep_time_allowed() else "Sleep after 20:00"
	elif house.player_inside:
		interaction_label.text = "My home" if shop.business.house_owned else "Home for sale"
	elif shop.player_inside:
		interaction_label.text = "Customer wants a discount" if shop.get_bargaining_customer() != null else ("My shop" if shop.business.shop_is_open() else "My shop (closed)")
	var operations = get_tree().current_scene.get_node_or_null("ShopOperations")
	if operations != null and operations.enabled:
		var hint: String = operations.interaction_hint()
		if not hint.is_empty(): interaction_label.text = hint
	var coop_world = get_tree().current_scene.get_node_or_null("CoopWorld")
	if coop_world != null and shop.business.carried_stock == 0:
		var friend: int = coop_world.aimed_friend()
		if friend != 0: interaction_label.text = "Talk to %s" % coop_world.peers[friend].name
