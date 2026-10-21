extends Panel

# Right side of the screen during a counter order (customer.gd counter_order): what
# the customer asked for, what is already in the carry bag, and the next step. It
# sits under the FIRST DAY guide while that is showing.
const Catalog = preload("res://product_catalog.gd")
const DONE := Color(0.5, 0.95, 0.62)
var title: Label
var rows: Array[Label] = []
var step: Label

func _ready() -> void:
	name = "OrderPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = _label(13, Color(1, 0.85, 0.45))
	for index in range(3): rows.append(_label(15, Color.WHITE))
	step = _label(12, Color(0.72, 0.88, 1))
	step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hide()

func _label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = colour
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var operations = scene.get_node_or_null("ShopOperations") if scene != null else null
	var customer = operations.order_customer() if operations != null and operations.enabled else null
	var player = scene.get_node_or_null("Player") if scene != null else null
	visible = customer != null and customer.order_told and player != null and not player._menu_is_open()
	if not visible: return
	title.text = "ORDER - %s   (%ds)" % [customer.customer_name.get_slice(" - ", 0).to_upper(), ceili(maxf(0.0, customer.order_seconds))]
	for index in range(rows.size()):
		var row := rows[index]
		row.visible = index < customer.order_lines.size()
		if not row.visible: continue
		var line: Dictionary = customer.order_lines[index]
		var got: int = customer.in_bag(line.product)
		row.text = "%s  %s   %d / %d" % ["[x]" if got >= int(line.count) else "[  ]", Catalog.NAMES[line.product], got, line.count]
		row.modulate = DONE if got >= int(line.count) else Color.WHITE
	var bags: int = operations.shop.business.carry_bags
	if not operations.holding_bag: step.text = "At the counter press E to take a carry bag (%d on the stand)." % bags if bags > 0 else "No carry bags! Buy a pack on the shop PC: Wholesale > Supplies."
	elif customer.bag_total() < customer.order_items(): step.text = "At each rack press E to put an item in the bag. Q takes one out."
	else: step.text = "All in the bag. Give it to the customer at the counter (E)."
	var lines: int = customer.order_lines.size()
	var guide := get_parent().get_node_or_null("FirstDayGuide") as Control
	var top := 50.0 + (164.0 if guide != null and guide.visible else 0.0)
	var height := 42.0 + lines * 24.0 + 46.0
	position = Vector2(get_viewport().get_visible_rect().size.x - 276.0, top)
	size = Vector2(260, height)
	title.position = Vector2(12, 8)
	title.size = Vector2(236, 22)
	for index in range(rows.size()):
		rows[index].position = Vector2(12, 34 + index * 24)
		rows[index].size = Vector2(236, 22)
	step.position = Vector2(12, 40 + lines * 24)
	step.size = Vector2(236, 42)
