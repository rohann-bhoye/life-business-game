extends Control

# Full-screen end-of-day report shown after sleeping. The game stays paused (time,
# customers, player) until the player presses Space/Enter or the Start button.
const UiStyle := preload("res://ui_style.gd")
const KenneyTheme := preload("res://kenney_theme.gd")
const Catalog := preload("res://product_catalog.gd")
const DayReport := preload("res://day_report.gd")
const GREEN := Color("4ade80")
const RED := Color("f87171")
const MUTED := Color("94a3b8")

var business
var format_money: Callable
var shade: ColorRect
var panel: Panel
var form: VBoxContainer
var title: Label
var result: Label
var result_box: PanelContainer
var income: GridContainer
var costs: GridContainer
var status_label: Label
var tomorrow: Label
var tip: Label
var start_button: Button

func _ready() -> void:
	name = "DayReportScreen"
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	shade = ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.05, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", UiStyle.glass_box(0.94))
	add_child(panel)
	form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	panel.add_child(form)
	title = _label("", 26, Color.WHITE, form)
	title.name = "Title"
	title.add_theme_font_override("font", KenneyTheme.heading_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label("Shop closed. Here is how today went.", 14, MUTED, form).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_box = PanelContainer.new()
	form.add_child(result_box)
	result = _label("", 24, Color.WHITE, result_box)
	result.name = "Result"
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_override("font", KenneyTheme.heading_font())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	form.add_child(columns)
	income = _column("INCOME", GREEN, columns)
	costs = _column("EXPENSES", RED, columns)
	status_label = _label("", 14, Color.WHITE, form)
	status_label.name = "Status"
	tomorrow = _label("", 14, Color("93c5fd"), form)
	tomorrow.name = "Tomorrow"
	tip = _label("", 14, Color("fcd34d"), form)
	tip.name = "Tip"
	start_button = Button.new()
	start_button.name = "StartDayButton"
	start_button.theme_type_variation = "PrimaryButton"
	start_button.custom_minimum_size.y = 44
	start_button.pressed.connect(close)
	form.add_child(start_button)
	_label("Press SPACE or ENTER to start the next day", 13, MUTED, form).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_viewport().size_changed.connect(_layout)

func _label(text: String, font_size: int, colour: Color, parent: Control) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label

func _column(heading: String, colour: Color, parent: Control) -> GridContainer:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := UiStyle.box(Color(1, 1, 1, 0.05), 10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", style)
	parent.add_child(box)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	box.add_child(list)
	_label(heading, 15, colour, list)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	list.add_child(grid)
	return grid

func _money(value: int) -> String:
	return String.chr(8377) + (format_money.call(value) if format_money.is_valid() else str(value))

func _row(grid: GridContainer, text: String, value: String, colour := Color.WHITE) -> void:
	_label(text, 14, Color("cbd5e1"), grid).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(value, 14, colour, grid).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func is_open() -> bool:
	return visible

func open(business_ref, money_format := Callable()) -> bool:
	business = business_ref
	format_money = money_format
	var report: Dictionary = business.day_report.last
	if report.is_empty(): return false
	var profit: int = int(report.profit)
	title.text = "END OF DAY %d" % report.day
	result.text = ("PROFIT  +%s" if profit > 0 else "LOSS  -%s" if profit < 0 else "NO PROFIT  %s") % _money(absi(profit))
	var banner := UiStyle.box(Color(0.09, 0.4, 0.2, 0.85) if profit > 0 else Color(0.5, 0.11, 0.11, 0.85) if profit < 0 else Color(0.25, 0.3, 0.36, 0.85), 10)
	banner.content_margin_top = 6
	banner.content_margin_bottom = 6
	result_box.add_theme_stylebox_override("panel", banner)
	for grid in [income, costs]:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	_row(income, "Sales revenue", _money(int(report.revenue)), GREEN)
	_row(income, "Items sold", str(report.items_sold))
	_row(income, "Best seller", "%s (%d)" % [Catalog.NAMES[report.best], report.best_count] if report.best != "" else "none")
	_row(income, "Missed sales", str(report.missed), RED if int(report.missed) > 0 else Color.WHITE)
	var breakdown: Dictionary = report.get("costs", {})
	for key in DayReport.COSTS:
		if int(breakdown.get(key, 0)) != 0: _row(costs, DayReport.COST_NAMES[key], _money(int(breakdown[key])))
	if int(report.expenses) == 0: _row(costs, "No spending today", "")
	_row(costs, "Total", _money(int(report.expenses)), RED if int(report.expenses) > 0 else Color.WHITE)
	var change: int = int(report.reputation_change)
	status_label.text = "Money now: %s   |   Reputation: %d/100 (%s%d)   |   New reviews: %d" % [_money(int(business.money)), report.reputation, "+" if change >= 0 else "", change, report.reviews]
	if business.loan_left() > 0: status_label.text += "\nBank loan left: %s (%s per day)" % [_money(business.loan_left()), _money(business.loan_daily_payment())]
	var next_day: int = business.day
	tomorrow.text = "Tomorrow: Day %d  |  Forecast: %s" % [next_day, "Rain (more customers stay home)" if business.weather_for_day(next_day) == "rain" else "Sunny"]
	var sale: Dictionary = business.rival_sale()
	if not sale.is_empty(): tomorrow.text += "\nSharma's sale: %s for %s (was %s). Match it to keep customers." % [Catalog.NAMES[sale.id], _money(int(sale.price)), _money(business.rival_price(sale.id))]
	elif business.rival_open(): tomorrow.text += "  |  Sharma General Store is open nearby"
	tip.text = _tip(report)
	start_button.text = "START DAY %d" % next_day
	move_to_front()
	show()
	_layout()
	_layout.call_deferred()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_button.grab_focus()
	return true

func _tip(report: Dictionary) -> String:
	if int(report.items_sold) == 0 and int(report.missed) > 0: return "Tip: %d customers left without buying. Order stock on the shop PC and fill the shelves." % report.missed
	if int(report.missed) > 0: return "Tip: %d sales were missed. Keep shelves full and tills staffed." % report.missed
	if int(report.profit) < 0: return "Tip: spending was higher than sales today. Sell more or cut costs."
	if int(report.items_sold) == 0: return "Tip: no sales today. Open the shop from 08:00 and keep stock on the shelves."
	return "Great work! Keep prices fair to beat Sharma General Store." if business.rival_open() else "Great work! Keep the shelves full tomorrow."

func close() -> void:
	if not visible: return
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _layout() -> void:
	if not visible: return
	var screen := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = screen
	shade.size = screen
	var width := minf(640.0, screen.x - 32.0)
	# Wrapped labels need their real width before the panel measures its height.
	for label in [status_label, tomorrow, tip]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = width - 48
	form.position = Vector2(24, 20)
	form.size = Vector2(width - 48, 0)
	form.reset_size()
	panel.size = Vector2(width, form.get_combined_minimum_size().y + 40)
	var fit := minf(1.0, (screen.y - 24.0) / panel.size.y)
	panel.scale = Vector2(fit, fit)
	panel.position = (screen - panel.size * fit) / 2.0

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		close()
		get_viewport().set_input_as_handled()
