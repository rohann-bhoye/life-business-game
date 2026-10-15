extends Control

var entries := {}
var rows := {}
var list: VBoxContainer
var scroll: ScrollContainer
var refresh_seconds := 0.0
@onready var ui = get_parent()
@onready var business = ui.shop.business

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll = ScrollContainer.new()
	scroll.name = "NotificationScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scroll)
	list = VBoxContainer.new()
	list.name = "NotificationList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	position = Vector2(16, 56)
	size = Vector2(minf(300, maxf(120, viewport_size.x - 32)), maxf(64, minf(360, viewport_size.y - 156)))
	scroll.position = Vector2.ZERO
	scroll.size = size

func _entry(title: String, detail: String, role := "", warning := false) -> Dictionary:
	return {"title": title, "detail": detail, "role": role, "warning": warning}

func refresh() -> void:
	var next := {}
	var ready_beds := 0
	for index in range(business.farm.PLOTS[business.farm.level - 1]):
		if business.farm.ready(index, business.farm_time()): ready_beds += 1
	if ready_beds > 0:
		next["farm_ready"] = _entry("Tomatoes ready to harvest", "%d farm beds ready. Carry produce to storage or shop shelves." % ready_beds)
	var operations = ui.get_tree().current_scene.get_node_or_null("ShopOperations")
	if is_instance_valid(operations) and operations.enabled:
		for customer in operations.queue:
			if not is_instance_valid(customer) or customer.is_queued_for_deletion() or not customer.queue_is_impatient(): continue
			var seconds := ceili(maxf(0, customer.queue_patience_limit() - customer.queue_wait_seconds))
			next["queue:" + str(customer.get_instance_id())] = _entry(customer.customer_name.get_slice(" - ", 0) + " is getting impatient", "Queue patience: %ds left." % seconds, "", true)
	for role in business.staff.ROLES:
		var record: Dictionary = business.staff.records[role]
		if business.staff.active(business, role) and record.state in ["leave", "pay"]:
			var detail := "Shift finished: may I go home?" if record.state == "leave" else "Overtime payment requested: %s%d" % [String.chr(8377), record.unpaid]
			next["staff:" + role] = _entry(business.staff.name_for(role) + " wants to talk", detail, role)
	for id in business.Catalog.IDS:
		# Do not warn about products the owner has never stocked or ordered.
		if id != "bottle" and business.inventory[id].purchased == 0: continue
		var stock: int = business.product_stock(id)
		if stock <= 2:
			var detail := "Order more at the management PC."
			if business.incoming_boxes.any(func(box): return box.product == id): detail = "Delivery is on the way."
			elif business.queued_boxes.any(func(box): return box.product == id) or (business.pending_product == id and business.boxed_stock > 0): detail = "Box in the product bay outside the warehouse."
			elif business.pending_product == id and business.carried_stock + business.worker_carried_stock > 0: detail = "A box is waiting to be shelved."
			elif business.logistics.stored_units(id) > 0: detail = "Warehouse: %d items ready to collect." % business.logistics.stored_units(id)
			next["stock:" + id] = _entry(business.Catalog.NAMES[id] + (" out of stock" if stock == 0 else " running low: %d left" % stock), detail, "", true)
	if business.worker_carried_stock > 0 and business.racks.restock_rack(business.pending_product) < 0:
		next["shelf_space"] = _entry("Sunil needs shelf space", "%d %s held. No shelf space available." % [business.worker_carried_stock, business.Catalog.NAMES[business.pending_product]], "", true)
	if business.boxed_stock > 0 or not business.queued_boxes.is_empty():
		var ready_boxes: int = business.queued_boxes.size() + (1 if business.boxed_stock > 0 else 0)
		next["delivery"] = _entry("Delivery ready", "%d %s in the warehouse product bay." % [ready_boxes, "box" if ready_boxes == 1 else "boxes"])
	if not business.logistics.rack_delivered.is_empty():
		next["furniture"] = _entry("Furniture delivery ready", "%d packages outside the warehouse." % business.logistics.rack_delivered.size())
	elif not business.logistics.rack_incoming.is_empty():
		next["furniture"] = _entry("Furniture truck on the way", "%d displays ordered." % business.logistics.rack_incoming.size())
	if business.unpaid_bills() > 0:
		next["bills"] = _entry("Unpaid bills: %s%s" % [String.chr(8377), ui.shop._format_money(business.unpaid_bills())], "Employees stop work when wages are unpaid.", "", true)
	entries = next
	for key in rows.keys():
		if not entries.has(key):
			list.remove_child(rows[key])
			rows[key].queue_free()
			rows.erase(key)
	var index := 0
	for key in entries:
		if not rows.has(key): _add_row(key)
		var row: Button = rows[key]
		var entry: Dictionary = entries[key]
		row.text = entry.title + "\n" + entry.detail
		row.tooltip_text = "Talk to " + business.staff.name_for(entry.role) if not entry.role.is_empty() else entry.detail
		row.mouse_filter = Control.MOUSE_FILTER_STOP if not entry.role.is_empty() else Control.MOUSE_FILTER_IGNORE
		row.focus_mode = Control.FOCUS_ALL if not entry.role.is_empty() else Control.FOCUS_NONE
		var style: StyleBoxFlat = ui._style(Color(0.055, 0.07, 0.075, 0.94))
		style.border_width_left = 3
		style.border_color = Color(0.95, 0.66, 0.22) if entry.warning else Color(0.25, 0.75, 0.62)
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		for state in ["normal", "pressed", "hover"]: row.add_theme_stylebox_override(state, style)
		list.move_child(row, index)
		index += 1
	visible = not entries.is_empty() and not ui.player._menu_is_open()

func _add_row(key: String) -> void:
	var row := Button.new()
	row.name = key.replace(":", "_").capitalize().replace(" ", "") + "Notice"
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.custom_minimum_size.y = 68
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_font_size_override("font_size", 14)
	row.add_theme_color_override("font_color", Color(0.95, 0.97, 0.97))
	row.add_theme_color_override("font_hover_color", Color.WHITE)
	row.add_theme_color_override("font_pressed_color", Color.WHITE)
	list.add_child(row)
	rows[key] = row
	row.pressed.connect(func():
		if ui.player._menu_is_open() or not entries.has(key): return
		var role: String = entries[key].role
		if not role.is_empty(): ui.staff_dialog.open_for(role))

func _process(delta: float) -> void:
	visible = not entries.is_empty() and not ui.player._menu_is_open()
	refresh_seconds -= delta
	if refresh_seconds <= 0:
		refresh_seconds = 0.25
		refresh()
