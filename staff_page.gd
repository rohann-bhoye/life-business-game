extends Panel

# "APNA JOBS" — the staff page on the management PC. One card per employee
# (portrait, wage, status, hire button) like the wholesale store, and a manage
# panel for the selected employee: work hours, on/off duty, mood and overtime.
signal back_requested
signal talk_requested(role: String)

const KenneyTheme = preload("res://kenney_theme.gd")
const SIZE := Vector2(912, 468)
const BRAND := Color("6d28d9")
const ROLES := ["cashier", "stock", "warehouse"]
const TITLES := {"cashier": "Cashier", "stock": "Stock assistant", "warehouse": "Warehouse receiver"}
const DUTIES := {"cashier": "Scans and bills customers at the counter.", "stock": "Carries delivered boxes and fills the shelves.", "warehouse": "Stores delivery boxes in the warehouse."}
const TINTS := {"cashier": Color("dcfce7"), "stock": Color("ffedd5"), "warehouse": Color("dbeafe")}
const LEVELS := ["Trainee", "Skilled", "Expert"]

var business
var format_money: Callable
var operations: Node
var selected := "cashier"
var level := 1
var start_hour := 8
var end_hour := 20
var notice := ""
var notice_seconds := 0.0
var money_label: Label
var cards := {}
var level_buttons: Array[Button] = []
var manage := {}

func setup(business_ref, money_formatter: Callable, operations_ref: Node = null) -> void:
	business = business_ref
	format_money = money_formatter
	operations = operations_ref
	name = "StaffPage"
	size = SIZE
	# Fill the theme before assigning it (see pc_store.gd).
	var page_theme := Theme.new()
	page_theme.default_font_size = 15
	KenneyTheme.apply(page_theme)
	theme = page_theme
	add_theme_stylebox_override("panel", _flat(Color("f5f3ff"), 12))
	level = business.cashier_level
	_build_header()
	for index in range(ROLES.size()): _build_card(ROLES[index], Vector2(14 + index * 204, 70))
	_build_manage()
	business.changed.connect(refresh)
	select_role("cashier")

func _flat(colour: Color, radius := 8, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	if border.a > 0:
		style.border_color = border
		style.set_border_width_all(3)
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
	bar.size = Vector2(SIZE.x, 58)
	bar.add_theme_stylebox_override("panel", _flat(BRAND, 12))
	add_child(bar)
	var logo := _label("APNA JOBS", Vector2(18, 8), 320, 26, Color.WHITE, bar)
	logo.add_theme_font_override("font", KenneyTheme.heading_font())
	_label("Hire staff and manage your team | wage %s/day each" % _money(business.DAILY_WORKER_WAGE), Vector2(20, 38), 420, 11, Color("ede9fe"), bar)
	money_label = _label("", Vector2(470, 18), 260, 16, Color.WHITE, bar)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var back := _button("Back", Rect2(748, 12, 146, 36), "", bar)
	back.name = "BackButton"
	back.pressed.connect(func(): back_requested.emit())

func _build_card(role: String, position: Vector2) -> void:
	var card := Panel.new()
	card.name = "Card_" + role
	card.position = position
	card.size = Vector2(196, 388)
	add_child(card)
	var photo_back := Panel.new()
	photo_back.position = Vector2(10, 10)
	photo_back.size = Vector2(176, 124)
	photo_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_back.add_theme_stylebox_override("panel", _flat(TINTS[role], 10))
	card.add_child(photo_back)
	var photo := TextureRect.new()
	photo.texture = load("res://assets/ui/staff/%s.png" % role)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.position = Vector2(26, 2)
	photo.size = Vector2(124, 122)
	photo_back.add_child(photo)
	var name_label := _label(business.staff.name_for(role), Vector2(10, 140), 176, 20, KenneyTheme.TEXT, card)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", KenneyTheme.heading_font())
	var title := _label(TITLES[role], Vector2(10, 166), 176, 13, BRAND, card)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var badge := Label.new()
	badge.position = Vector2(48, 190)
	badge.size = Vector2(100, 22)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_font_override("font", KenneyTheme.heading_font())
	card.add_child(badge)
	var duty := _label(DUTIES[role], Vector2(12, 216), 172, 12, KenneyTheme.MUTED, card)
	duty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	duty.clip_text = false
	# Set the size again after wrapping is on, or the label keeps one long line.
	duty.size = Vector2(172, 40)
	var details := _label("", Vector2(12, 258), 172, 12, KenneyTheme.TEXT, card)
	details.clip_text = false
	details.size = Vector2(172, 40)
	if role == "cashier":
		for index in range(3):
			var chip := _button("L%d" % (index + 1), Rect2(12 + index * 58, 302, 54, 30), "", card)
			chip.name = "Level%d" % (index + 1)
			chip.add_theme_font_size_override("font_size", 13)
			chip.tooltip_text = "%s cashier: %.0f s per item" % [LEVELS[index], business.CASHIER_SCAN_SECONDS[index]]
			chip.pressed.connect(func(): level = index + 1; refresh())
			level_buttons.append(chip)
	var hire := _button("", Rect2(10, 340, 176, 40), "PrimaryButton", card)
	hire.name = "HireButton"
	hire.add_theme_font_size_override("font_size", 14)
	hire.pressed.connect(_on_card_button.bind(role))
	# Clicking anywhere on the card selects that employee in the manage panel.
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: select_role(role))
	cards[role] = {"card": card, "badge": badge, "details": details, "hire": hire}

func _build_manage() -> void:
	var panel := Panel.new()
	panel.name = "Manage"
	panel.position = Vector2(626, 70)
	panel.size = Vector2(272, 388)
	add_child(panel)
	var title := _label("", Vector2(14, 10), 244, 17, BRAND, panel)
	title.add_theme_font_override("font", KenneyTheme.heading_font())
	var status := _label("", Vector2(14, 36), 244, 13, KenneyTheme.MUTED, panel)
	var mood := _label("", Vector2(14, 60), 244, 13, KenneyTheme.TEXT, panel)
	var bar := ProgressBar.new()
	bar.name = "HappinessBar"
	bar.show_percentage = false
	bar.position = Vector2(14, 82)
	bar.size = Vector2(244, 12)
	bar.add_theme_stylebox_override("background", _flat(Color("e5e7eb"), 6))
	panel.add_child(bar)
	var hours := _label("WORK HOURS", Vector2(14, 104), 244, 14, BRAND, panel)
	hours.add_theme_font_override("font", KenneyTheme.heading_font())
	var rows := {}
	for entry in [["start", "Start", 128], ["end", "End", 162]]:
		_label(entry[1], Vector2(14, entry[2] + 4), 60, 14, KenneyTheme.TEXT, panel)
		var minus := _button("-", Rect2(80, entry[2], 40, 30), "", panel)
		minus.name = entry[0].capitalize() + "Minus"
		minus.pressed.connect(_nudge.bind(entry[0], -1))
		var value := _label("", Vector2(124, entry[2] + 3), 86, 17, KenneyTheme.TEXT, panel)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plus := _button("+", Rect2(214, entry[2], 40, 30), "", panel)
		plus.name = entry[0].capitalize() + "Plus"
		plus.pressed.connect(_nudge.bind(entry[0], 1))
		rows[entry[0]] = {"value": value, "minus": minus, "plus": plus}
	var save := _button("Save hours", Rect2(14, 198, 244, 34), "InfoButton", panel)
	save.name = "SaveHoursButton"
	save.pressed.connect(_save_hours)
	var work := CheckButton.new()
	work.name = "WorkSwitch"
	work.text = "Working"
	work.position = Vector2(10, 238)
	work.size = Vector2(248, 32)
	work.focus_mode = Control.FOCUS_NONE
	work.add_theme_font_size_override("font_size", 14)
	work.add_theme_color_override("font_color", KenneyTheme.TEXT)
	work.add_theme_color_override("font_pressed_color", KenneyTheme.GREEN)
	work.add_theme_color_override("font_hover_color", KenneyTheme.TEXT)
	work.add_theme_color_override("font_hover_pressed_color", KenneyTheme.GREEN)
	work.toggled.connect(func(value): business.set_employee_work(selected, value))
	panel.add_child(work)
	var auto := CheckBox.new()
	auto.name = "AutoCollect"
	auto.text = "Collect deliveries automatically"
	auto.position = Vector2(10, 272)
	auto.size = Vector2(248, 26)
	auto.focus_mode = Control.FOCUS_NONE
	auto.add_theme_font_size_override("font_size", 12)
	auto.add_theme_color_override("font_color", KenneyTheme.TEXT)
	auto.add_theme_color_override("font_pressed_color", KenneyTheme.TEXT)
	auto.add_theme_color_override("font_hover_color", KenneyTheme.TEXT)
	auto.add_theme_color_override("font_hover_pressed_color", KenneyTheme.TEXT)
	auto.toggled.connect(func(value): business.set_assistant_auto_collect(value))
	panel.add_child(auto)
	var assign := _button("Assign delivered box", Rect2(14, 302, 244, 30), "", panel)
	assign.name = "AssignButton"
	assign.add_theme_font_size_override("font_size", 13)
	assign.pressed.connect(func():
		if is_instance_valid(operations): operations.stock_worker.assign_delivery()
		_notify("Sunil will collect the box.")
		refresh())
	var talk := _button("Talk", Rect2(14, 342, 118, 34), "", panel)
	talk.name = "TalkButton"
	talk.pressed.connect(func(): talk_requested.emit(selected))
	var pay := _button("", Rect2(140, 342, 118, 34), "PrimaryButton", panel)
	pay.name = "PayOvertimeButton"
	pay.add_theme_font_size_override("font_size", 13)
	pay.pressed.connect(func():
		_notify("Overtime paid." if business.staff.reply(business, selected, "pay") else "Cannot pay overtime now.")
		refresh())
	manage = {"panel": panel, "title": title, "status": status, "mood": mood, "bar": bar, "rows": rows, "save": save, "work": work, "auto": auto, "assign": assign, "talk": talk, "pay": pay}

func _money(value: int) -> String:
	return String.chr(8377) + (format_money.call(value) if format_money.is_valid() else str(value))

func _notify(text: String) -> void:
	notice = text
	notice_seconds = 3.0

func hire_cost(role: String) -> int:
	return business.CASHIER_COSTS[level - 1] if role == "cashier" else business.HIRING_COST

func select_role(role: String) -> void:
	selected = role
	start_hour = int(business.get(role + "_shift_start")) / 60
	end_hour = int(business.get(role + "_shift_end")) / 60
	notice = ""
	refresh()

func _nudge(which: String, step: int) -> void:
	if which == "start": start_hour = clampi(start_hour + step, 6, mini(21, end_hour - 1))
	else: end_hour = clampi(end_hour + step, maxi(7, start_hour + 1), 22)
	refresh()

func _save_hours() -> void:
	_notify("Work hours saved." if business.set_staff_shift(selected, start_hour * 60, end_hour * 60) else "Shift must end after it starts.")
	refresh()

func hire(role: String) -> bool:
	var success: bool
	match role:
		"cashier": success = business.hire_worker(level)
		"stock": success = business.hire_stock_worker()
		_: success = business.hire_warehouse_worker()
	select_role(role)
	_notify("%s hired. Welcome to the team!" % business.staff.name_for(role) if success else "Cannot hire: check money and unpaid overtime.")
	refresh()
	return success

func _on_card_button(role: String) -> void:
	if business.staff.active(business, role): select_role(role)
	else: hire(role)

## Vacant / Quit / Unpaid wages / On duty / Off duty, with a badge colour.
func status(role: String) -> Array:
	if not business.staff.hired(business, role): return ["VACANT", Color("6b7280")]
	if business.staff.records[role].quit_day > 0: return ["QUIT", Color("b91c1c")]
	if business.wages_due > 0: return ["UNPAID WAGES", Color("b45309")]
	var working: bool = business.cashier_on_shift() if role == "cashier" else (business.stock_worker_on_shift() if role == "stock" else business.warehouse_worker_on_shift())
	if not business.staff.records[role].work_enabled: return ["DAY OFF", Color("b45309")]
	return ["ON DUTY", KenneyTheme.GREEN] if working else ["OFF SHIFT", Color("2563eb")]

func _process(delta: float) -> void:
	if notice_seconds > 0.0:
		notice_seconds -= delta
		if notice_seconds <= 0.0: notice = ""; refresh()

func refresh() -> void:
	if business == null or manage.is_empty(): return
	money_label.text = "Money: " + _money(business.money)
	for role in ROLES:
		var entry: Dictionary = cards[role]
		var active: bool = business.staff.active(business, role)
		var state: Array = status(role)
		entry.badge.text = state[0]
		entry.badge.add_theme_color_override("font_color", Color.WHITE)
		entry.badge.add_theme_stylebox_override("normal", _flat(state[1], 11))
		entry.card.add_theme_stylebox_override("panel", _flat(Color.WHITE, 12, BRAND if role == selected else Color("e5e7eb")))
		var shown_level: int = business.cashier_level if active else level
		var hours := "%02d:00 - %02d:00" % [int(business.get(role + "_shift_start")) / 60, int(business.get(role + "_shift_end")) / 60]
		if role == "cashier": entry.details.text = "%s | %.0f s per item\nHours: %s" % [LEVELS[shown_level - 1], business.CASHIER_SCAN_SECONDS[shown_level - 1], hours]
		else: entry.details.text = "Wage: %s/day\nHours: %s" % [_money(business.DAILY_WORKER_WAGE), hours]
		var blocked: bool = business.money < hire_cost(role) or business.staff.records[role].unpaid > 0
		entry.hire.text = "Manage" if active else ("Hire again - %s" if business.staff.records[role].quit_day > 0 else "Hire - %s") % _money(hire_cost(role))
		entry.hire.theme_type_variation = "InfoButton" if active else "PrimaryButton"
		entry.hire.disabled = not active and blocked
		entry.hire.tooltip_text = "" if active or not blocked else ("Not enough money" if business.money < hire_cost(role) else "Pay the overtime you owe first")
	for index in range(level_buttons.size()):
		level_buttons[index].theme_type_variation = "PrimaryButton" if index + 1 == level else ""
		level_buttons[index].disabled = business.staff.active(business, "cashier")
	var record: Dictionary = business.staff.records[selected]
	var hired: bool = business.staff.active(business, selected)
	manage.title.text = "MANAGE " + business.staff.name_for(selected).to_upper()
	manage.status.text = notice if not notice.is_empty() else ("Status: %s" % status(selected)[0].capitalize() if hired else "Hire %s to manage work hours." % business.staff.name_for(selected))
	manage.status.add_theme_color_override("font_color", BRAND if not notice.is_empty() else KenneyTheme.MUTED)
	manage.mood.text = "Happiness: %d / 100" % record.happiness
	manage.bar.value = record.happiness
	manage.bar.add_theme_stylebox_override("fill", _flat(KenneyTheme.GREEN if record.happiness >= 60 else (Color("d97706") if record.happiness >= 35 else Color("dc2626")), 6))
	manage.rows.start.value.text = "%02d:00" % start_hour
	manage.rows.end.value.text = "%02d:00" % end_hour
	manage.rows.start.minus.disabled = start_hour <= 6
	manage.rows.start.plus.disabled = start_hour >= mini(21, end_hour - 1)
	manage.rows.end.minus.disabled = end_hour <= maxi(7, start_hour + 1)
	manage.rows.end.plus.disabled = end_hour >= 22
	var saved: bool = int(business.get(selected + "_shift_start")) == start_hour * 60 and int(business.get(selected + "_shift_end")) == end_hour * 60
	manage.save.disabled = saved
	manage.save.text = "Hours saved" if saved else "Save hours"
	manage.work.set_pressed_no_signal(record.work_enabled)
	manage.work.text = "Working" if record.work_enabled else "Day off"
	manage.work.disabled = not hired
	manage.auto.visible = selected == "stock"
	manage.auto.set_pressed_no_signal(business.assistant_auto_collect)
	manage.auto.disabled = not hired
	manage.assign.visible = selected == "stock"
	var busy: bool = is_instance_valid(operations) and is_instance_valid(operations.stock_worker) and not operations.stock_worker.route.is_empty()
	manage.assign.disabled = not business.stock_worker_on_shift() or business.boxed_stock == 0 or busy
	manage.talk.disabled = not hired
	manage.pay.text = "Pay %s" % _money(record.unpaid) if record.unpaid > 0 else "No overtime"
	manage.pay.disabled = record.unpaid == 0 or record.overtime_end > 0 or business.money < record.unpaid
