extends Panel

# Right side of the screen during a counter order (customer.gd counter_order) or an
# export order in hand (export_world.gd, carton or sealed parcel): each
# product's picture, the rack it is on (R1, R2, ...), how many are in the carry bag
# and the next step. It sits under the FIRST DAY guide while that is showing.
const Catalog = preload("res://product_catalog.gd")
const DONE := Color(0.08, 0.5, 0.22)
const TEXT := Color(0.1, 0.12, 0.14)
var title: Label
var icons: Array[TextureRect] = []
var rows: Array[Label] = []
var step: Label
var refresh_due := 0

func _ready() -> void:
	name = "OrderPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = _label(13, Color(0.75, 0.4, 0.02))
	for index in range(3):
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		icons.append(icon)
		rows.append(_label(14, TEXT))
	step = _label(12, Color(0.12, 0.32, 0.62))
	step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hide()

func _label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var operations = scene.get_node_or_null("ShopOperations") if scene != null else null
	var customer = operations.order_customer() if operations != null and operations.enabled else null
	var player = scene.get_node_or_null("Player") if scene != null else null
	# An export carton or parcel in hand (export_world.gd) comes first.
	var export_world = scene.get_node_or_null("ExportWorld") if scene != null else null
	var exporting: bool = export_world != null and export_world.holding()
	visible = (exporting or customer != null and customer.order_told) and player != null and not player._menu_is_open()
	if not visible or Time.get_ticks_msec() < refresh_due: return
	refresh_due = Time.get_ticks_msec() + 250
	if exporting:
		_show_export(operations, export_world)
		return
	title.text = "ORDER - %s   (%ds)" % [customer.customer_name.get_slice(" - ", 0).to_upper(), ceili(maxf(0.0, customer.order_seconds))]
	var got_counts: Array = []
	for line in customer.order_lines: got_counts.append(customer.in_bag(line.product))
	_rows(operations, customer.order_lines, got_counts)
	var bags: int = operations.shop.business.carry_bags
	if not operations.holding_bag: step.text = "At the counter press E to take a carry bag (%d in the box)." % bags if bags > 0 else "No carry bags! Buy a pack on the shop PC: Wholesale > Supplies."
	elif customer.bag_total() < customer.order_items(): step.text = "Find the rack code, press E there to put an item in the bag. Q takes one out."
	else: step.text = "All in the bag. Give it to the customer at the counter (E)."
	_place(customer.order_lines.size())

func _show_export(operations, export_world) -> void:
	var picking: bool = export_world.carton_order >= 0
	var order: Dictionary = export_world.picking_order() if picking else operations.shop.business.exports.find(export_world.carrying_parcel)
	if order.is_empty(): return
	title.text = "EXPORT - %s, %s" % [order.city.to_upper(), order.country]
	var got_counts: Array = []
	for line in order.lines: got_counts.append(export_world.in_carton(line.product) if picking else int(line.count))
	_rows(operations, order.lines, got_counts)
	if not picking: step.text = "Sealed! Take it to the export platform at the airport (walk down past the warehouse). Next flight %s." % export_world.next_flight()
	elif export_world._still_needed(order).is_empty(): step.text = "All in the carton. Seal it at the packing table in the packing room (E)."
	else: step.text = "Find the rack code, press E there to put an item in the carton. Q takes one out."
	_place(order.lines.size())

func _rows(operations, lines: Array, got_counts: Array) -> void:
	for index in range(rows.size()):
		var shown: bool = index < lines.size()
		rows[index].visible = shown
		icons[index].visible = shown
		if not shown: continue
		var line: Dictionary = lines[index]
		var got: int = got_counts[index]
		var done := got >= int(line.count)
		var code: String = operations.furnishing.product_code(line.product) if is_instance_valid(operations.furnishing) else ""
		icons[index].texture = load("res://assets/ui/products/%s.png" % line.product)
		icons[index].modulate = Color(1, 1, 1, 0.5) if done else Color.WHITE
		rows[index].text = "%s  %s   %d / %d" % [code if not code.is_empty() else "--", Catalog.NAMES[line.product], got, line.count]
		rows[index].add_theme_color_override("font_color", DONE if done else TEXT)

func _place(lines: int) -> void:
	var guide := get_parent().get_node_or_null("FirstDayGuide") as Control
	var top := 50.0 + (164.0 if guide != null and guide.visible else 0.0)
	position = Vector2(get_viewport().get_visible_rect().size.x - 276.0, top)
	size = Vector2(260, 40.0 + lines * 34.0 + 52.0)
	title.position = Vector2(12, 8)
	title.size = Vector2(236, 22)
	for index in range(rows.size()):
		icons[index].position = Vector2(10, 32 + index * 34)
		icons[index].size = Vector2(30, 30)
		rows[index].position = Vector2(46, 36 + index * 34)
		rows[index].size = Vector2(204, 22)
	step.position = Vector2(12, 40 + lines * 34)
	step.size = Vector2(236, 48)
