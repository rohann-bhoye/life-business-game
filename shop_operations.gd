extends Node3D

@export var enabled := true

enum DeliveryState { IDLE, ARRIVING, UNLOADING, LEAVING }
var delivery_state := DeliveryState.IDLE
var unload_seconds := 0.0
var queue: Array[Node3D] = []
var extra_delivery_boxes: Array[Node3D] = []
var rack_bottles: Array[Node3D] = []
var ground_boxes: Array[Node3D] = []
var rack_label: Label3D
var pc: Node3D
var rack: Node3D
var counter: Node3D
var van: Node3D
var delivery_box: Node3D
var carried_box: Node3D
## Counter orders (customer.gd counter_order): the carry bag in the player's hand,
## the stand of folded bags on the counter and the filled bag shown at payment.
var holding_bag := false
## APNA EXPORT: packing room, airport and cargo plane (export_world.gd).
var export_world: Node3D
## Gufa Darwaza: the cave on the west hill and its dungeon (dungeon_world.gd).
var dungeon_world: Node3D
## The doorway from the shop into the packing room, in the left wall (world z).
const SIDE_DOOR := Vector2(0.75, 1.95)
const SIDE_DOOR_HEIGHT := 2.2
var held_bag: Node3D
var counter_bag: Node3D
var bag_layers: Array[Node3D] = []
var bag_stand_label: Label3D
## The order screen on the counter (faces the cashier): each listed product's
## picture, its rack code and how many are still needed.
var order_title: Label3D
var order_icons: Array[Sprite3D] = []
var order_texts: Array[Label3D] = []
var product_pictures := {}
var order_screen_due := 0
var checkout_pc: Node3D
var checkout_display: Label3D
var checkout_items: Array[Node3D] = []
var scanner: Node3D
var scanner_light: OmniLight3D
var scan_flash_remaining := 0.0
var basket_customer: Node3D
var payment_prop: Node3D
var phone_screen: Node3D
var card_chip: Node3D
var stock_worker: Node3D
var drop_point := Vector3(-10.8, 0.1, 11.85)
var rack_point := Vector3(-4.6, 0.1, -0.5)
var cashier_point := Vector3(-2.5, 0.1, -0.6)
const ROOM_HEIGHT := 3.8
const Catalog = preload("res://product_catalog.gd")
const Store = preload("res://rack_store.gd")
const IndianHouse = preload("res://indian_house.gd")
## Movable furniture (G): each fixture's nodes with their transforms at its home spot.
var fixture_parts := {}
var product_racks := {}
var product_items := {}
var product_labels := {}
var furnishing
## The bought expansions the room is built for (-1 until the first build).
var room_expansion := -1
## What the back wall decor, skirting and plot were last moved for.
var followed := []
var departures := {}
## Each leaving employee's walk to the door, worked out once when they set off.
var departure_paths := {}
var screen_payment := false

@onready var shop = get_parent().get_node("Shop/ShopArea")
@onready var player = get_parent().get_node("Player")
@onready var ui = get_parent().get_node("Ui")

func build_room(builder: Node3D) -> void:
	var building: MeshInstance3D = get_parent().get_node("Shop")
	building.mesh = null
	building.get_node("ShopDoor").hide()
	var wall := Color(0.78, 0.83, 0.8)
	var trim := Color(0.12, 0.3, 0.26)
	builder._box("BackWall", building, Vector3(6, 3, 0.12), Vector3(0, 0, -2.5), wall, true)
	for x in [-3.0, 3.0]:
		builder._box("SideWall%s" % x, building, Vector3(0.12, 3, 5), Vector3(x, 0, 0), wall, true)
	# Front walls keep a full-height collider (the glass stops you) but the visible
	# brick has a real window opening, so you can see into the shop from the street.
	for x in [-2.0, 2.0]:
		var front: MeshInstance3D = builder._box("FrontWall%s" % x, building, Vector3(2, ROOM_HEIGHT, 0.12), Vector3(x, 0.5, 2.5), wall, true)
		front.mesh = _window_wall(ROOM_HEIGHT)
		front.material_override = builder._material(wall)
		builder._box("WindowGlass%s" % x, building, Vector3(1.5, 1.4, 0.05), Vector3(x, -0.05, 2.59), Color(0.32, 0.61, 0.67)).hide()
	builder._box("DoorLintel", building, Vector3(2, 0.6, 0.12), Vector3(0, 1.2, 2.5), wall, true)
	builder._box("RoofTrim", building, Vector3(6.3, 0.18, 5.3), Vector3(0, 1.6, 0), trim, true)
	# Pink roof edge all round (resized with the room in _update_room_size).
	for part in ["ParapetFront", "ParapetBack", "ParapetLeft", "ParapetRight"]:
		builder._box(part, building, Vector3(6.3, 0.3, 0.16), Vector3(0, 2.55, 2.66), Color(0.86, 0.2, 0.56))
	builder._box("Floor", building, Vector3(5.9, 0.012, 4.9), Vector3(0, -1.394, 0), Color(0.72, 0.75, 0.73))
	builder._box("SignBoard", building, Vector3(5.8, 0.62, 0.12), Vector3(0, 1.62, 2.64), trim)
	building.get_node("ShopSign").position = Vector3(0, 1.62, 2.72)
	# Striped awning sloping out over the windows, with a hanging valance.
	for index in range(12):
		var colour := Color(0.86, 0.29, 0.29) if index % 2 == 0 else Color(0.93, 0.94, 0.9)
		var awning: MeshInstance3D = builder._box("Awning%d" % index, building, Vector3(0.5, 0.06, 0.8), Vector3(-2.75 + index * 0.5, 1.08, 2.98), colour)
		awning.rotation.x = 0.35
		var valance: MeshInstance3D = builder._box("Valance", awning, Vector3(0.5, 0.18, 0.02), Vector3(0, -0.06, 0.4), colour)
		valance.rotation.x = -0.35
	var interior := Area3D.new()
	interior.name = "ShopInterior"
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.8, 3, 4.8)
	collision.shape = shape
	interior.add_child(collision)
	building.add_child(interior)
	interior.body_entered.connect(func(body):
		if body.name == "Player": body.shop_indoors = true)
	interior.body_exited.connect(func(body):
		if body.name == "Player": body.shop_indoors = false)
	building.get_node("ShopArea/CollisionShape3D").shape = BoxShape3D.new()
	building.get_node("ShopArea/CollisionShape3D").shape.size = Vector3(7, 3, 6)
	# New games start with a cold-drink fridge in place of the cold-drink shelf.
	var opening = get_parent().get_node("Shop/ShopArea").business
	var first := build_fridge(builder, "StockRack", Vector3(-5.6, 0.1, -0.5)) if opening.racks.find(0).get("display", "shelf") == "fridge" else build_stock_rack(builder, "StockRack", "bottle", Vector3(-5.6, 0.1, -0.5))
	rack = first.node
	rack_bottles = first.items
	rack_label = first.label
	# Waist height for the 1.45 m characters (top at 0.88 m): the 1 m box sinks
	# 0.3 m into the floor so everything on the counter keeps its local layout.
	counter = builder._box("CheckoutCounter", self, Vector3(2.8, 1, 0.7), Vector3(-2.5, 0.3, 0.4), Color(0.58, 0.37, 0.2), true)
	counter.mesh = null
	_prop(counter, "CounterModel", "shop/counter", Vector3(0, -0.3, 0))
	# The monitor stands at the cashier's side, turned toward the cashier, so it
	# never hides the customer's face at the middle of the counter.
	checkout_pc = builder._box("CheckoutPC", counter, Vector3(0.64, 0.4, 0.08), Vector3(1.0, 0.98, -0.2), Color(0.08, 0.12, 0.14))
	checkout_pc.rotation.y = 0.6
	builder._box("Screen", checkout_pc, Vector3(0.58, 0.34, 0.015), Vector3(0, 0, -0.05), Color(0.07, 0.25, 0.28))
	builder._box("MonitorStand", counter, Vector3(0.08, 0.2, 0.08), Vector3(1.0, 0.68, -0.2), Color(0.12, 0.17, 0.18))
	checkout_display = _sign(checkout_pc, "TotalDisplay", "CHECKOUT", Vector3(0, 0, -0.063))
	checkout_display.rotation.y = PI
	checkout_display.font_size = 24
	checkout_display.pixel_size = 0.002
	checkout_display.outline_size = 0
	scanner = builder._box("Scanner", counter, Vector3(0.35, 0.045, 0.35), Vector3(0.58, 0.605, 0.08), Color(0.2, 0.55, 0.5))
	scanner_light = OmniLight3D.new()
	scanner_light.name = "ScanLight"
	scanner_light.position = Vector3(0, 0.18, 0)
	scanner_light.light_color = Color(0.25, 1.0, 0.58)
	scanner_light.light_energy = 0.0
	scanner_light.omni_range = 0.8
	scanner.add_child(scanner_light)
	builder._box("CardTerminal", counter, Vector3(0.19, 0.08, 0.25), Vector3(1.05, 0.63, 0.2), Color(0.1, 0.17, 0.19))
	_build_bag_stand(builder)
	var desk = builder._box("ComputerDesk", self, Vector3(1.3, 0.85, 0.65), Vector3(-1.1, 0.525, -1.6), Color(0.39, 0.44, 0.43), true)
	desk.mesh = null
	var office = preload("res://office_assets.gd")
	office.attach(self, "ManagementDeskAsset", "desk", Vector3(1.3, 0.85, 0.7), Vector3(-1.1, 0.1, -1.6))
	pc = Node3D.new()
	pc.name = "ShopPC"
	pc.position = Vector3(0, 0.25, -0.08)
	desk.add_child(pc)
	# Same fitted casing as the warehouse PC, built around ComputerTerminal's
	# 0.78 x 0.44 live screen so the screen sits exactly inside the bezel.
	var casing := Color(0.06, 0.09, 0.11)
	builder._box("MonitorBack", pc, Vector3(0.9, 0.54, 0.08), Vector3(0, 0.43, 0.075), casing)
	builder._box("MonitorTop", pc, Vector3(0.9, 0.05, 0.08), Vector3(0, 0.695, 0.13), casing)
	builder._box("MonitorBottom", pc, Vector3(0.9, 0.05, 0.08), Vector3(0, 0.165, 0.13), casing)
	builder._box("MonitorLeft", pc, Vector3(0.06, 0.48, 0.08), Vector3(-0.42, 0.43, 0.13), casing)
	builder._box("MonitorRight", pc, Vector3(0.06, 0.48, 0.08), Vector3(0.42, 0.43, 0.13), casing)
	builder._box("MonitorNeck", pc, Vector3(0.1, 0.2, 0.1), Vector3(0, 0.05, 0.06), casing)
	builder._box("MonitorBase", pc, Vector3(0.52, 0.055, 0.3), Vector3(0, -0.045, 0.08), casing)
	office.attach(desk, "Keyboard", "computerKeyboard", Vector3(0.55, 0.06, 0.21), Vector3(0, 0.255, 0.17))
	office.attach(desk, "Mouse", "computerMouse", Vector3(0.1, 0.05, 0.15), Vector3(0.45, 0.255, 0.17))
	var terminal := Node3D.new()
	terminal.name = "ComputerTerminal"
	terminal.set_script(preload("res://computer_terminal.gd"))
	pc.add_child(terminal)
	_sign(pc, "PCSign", "MANAGEMENT", Vector3(0, 0.42, 0))
	get_parent().get_node("CustomerPurchasePoint").position = Vector3(-2.5, 0.1, 1.2)
	get_parent().get_node("Worker").position = cashier_point
	get_parent().get_node("Worker").rotation.y = PI
	_register_fixture("counter", [counter, get_node("CheckoutCounterBody")])
	_register_fixture("desk", [desk, get_node("ComputerDeskBody"), get_node("ManagementDeskAsset")])
	var light := OmniLight3D.new()
	light.name = "ShopLight"
	light.position = Vector3(-3, 2.6, 0)
	light.light_color = Color(1, 0.93, 0.82)
	light.light_energy = 0.65
	light.omni_range = 6
	add_child(light)
	_update_room_size()
	var decor := Node3D.new()
	decor.set_script(preload("res://shop_decor.gd"))
	add_child(decor)
	decor.build(counter)
	_build_expansion_plot()
	# Older games started with snack and soap racks too; new games buy them.
	var free_racks: int = get_parent().get_node("Shop/ShopArea").business.starting_racks
	for id in ["snack", "soap"]:
		if free_racks < 3: break
		var extra := build_stock_rack(builder, "SnackRack" if id == "snack" else "SoapRack", id, Vector3(-5.6, 0.1, -3.3 if id == "snack" else -6.0))
		product_racks[id] = extra.node
		product_items[id] = extra.items
		product_labels[id] = extra.label

## Three rows of ten on a gondola (`frame` "rack") or inside a cooler ("fridge"): the
## model from tools/blender/build_shop_fixtures.py, its shelves at the item heights.
func build_stock_rack(builder: Node3D, node_name: String, product: String, position: Vector3, frame := "rack") -> Dictionary:
	var node := Node3D.new()
	node.name = node_name
	node.position = position
	add_child(node)
	var items: Array[Node3D] = []
	for z in [-1.0, 1.0]: builder._collider("Upright%sBody" % z, node, Vector3(0.55, 1.9, 0.07), Vector3(0, 0.95, z))
	for level in range(3):
		builder._collider("Shelf%dBody" % level, node, Vector3(0.65, 0.06, 2.1), Vector3(0, 0.22 + level * 0.55, 0))
		for index in range(10): items.append(make_product(node, ("Bottle" if product == "bottle" else "Product") + str(level * 10 + index), Vector3(0, 0.26 + level * 0.55, -0.86 + index * 0.19), product))
	_prop(node, "RackFrame", "shop/" + frame)
	var label := _sign(node, "StockSign", "", Vector3(0.4, 2.1, 0))
	label.rotation.y = PI / 2
	return {"node": node, "items": items, "label": label}

## The carry-bag dispenser at the cashier's end of the counter, open toward the
## cashier; the pile of folded bags and the count follow business.carry_bags
## (_refresh_bag_stand).
func _build_bag_stand(builder: Node3D) -> void:
	var top := 0.58
	_prop(counter, "BagStand", "shop/bag_box", Vector3(-1.22, top, -0.22))
	for layer in range(8):
		var folded := _prop(counter, "BagLayer%d" % layer, "shop/folded_bag", Vector3(-1.22, top + 0.02 + layer * 0.016, -0.22))
		folded.rotation.y = PI * (layer % 2)
		bag_layers.append(folded)
	bag_stand_label = _sign(counter, "BagStandLabel", "", Vector3(-1.22, top + 0.3, -0.22))
	bag_stand_label.rotation.y = PI
	bag_stand_label.font_size = 26
	bag_stand_label.pixel_size = 0.0022
	counter_bag = make_carry_bag(counter, "CounterBag", Vector3(0.2, top, 0.15))
	counter_bag.hide()
	_build_order_screen(builder)

## A small tilted screen on the customer's side of the counter, facing the cashier.
func _build_order_screen(builder: Node3D) -> void:
	var screen := Node3D.new()
	screen.name = "OrderScreen"
	screen.position = Vector3(-0.75, 0.58, 0.3)
	screen.rotation = Vector3(-0.3, PI, 0)
	counter.add_child(screen)
	var dark := Color(0.08, 0.1, 0.12)
	builder._box("ScreenBase", screen, Vector3(0.26, 0.02, 0.14), Vector3(0, 0.01, 0), dark)
	builder._box("ScreenStand", screen, Vector3(0.06, 0.1, 0.04), Vector3(0, 0.06, 0), dark)
	builder._box("ScreenBezel", screen, Vector3(0.62, 0.32, 0.03), Vector3(0, 0.26, 0), dark)
	var glass: MeshInstance3D = builder._box("ScreenGlass", screen, Vector3(0.58, 0.28, 0.004), Vector3(0, 0.26, 0.017), Color(0.12, 0.3, 0.62))
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(0.12, 0.3, 0.62)
	lit.emission_enabled = true
	lit.emission = Color(0.12, 0.3, 0.62)
	lit.emission_energy_multiplier = 0.5
	glass.material_override = lit
	order_title = _sign(screen, "OrderTitle", "APNA MART", Vector3(0, 0.37, 0.021))
	order_title.font_size = 20
	order_title.pixel_size = 0.0018
	order_title.outline_size = 0
	for slot in range(3):
		var x := -0.18 + slot * 0.18
		var icon := Sprite3D.new()
		icon.name = "OrderIcon%d" % slot
		icon.position = Vector3(x, 0.27, 0.021)
		icon.pixel_size = 0.11 / 256.0
		icon.shaded = false
		screen.add_child(icon)
		order_icons.append(icon)
		var text := _sign(screen, "OrderText%d" % slot, "", Vector3(x, 0.165, 0.021))
		text.font_size = 18
		text.pixel_size = 0.0018
		text.outline_size = 0
		order_texts.append(text)

func _picture(id: String) -> Texture2D:
	if not product_pictures.has(id): product_pictures[id] = load("res://assets/ui/products/%s.png" % id)
	return product_pictures[id]

func _update_order_screen() -> void:
	if not is_instance_valid(order_title) or Time.get_ticks_msec() < order_screen_due: return
	order_screen_due = Time.get_ticks_msec() + 250
	var customer := order_customer()
	var told: bool = customer != null and customer.order_told
	order_title.text = ("ORDER - %s" % customer.customer_name.get_slice(" - ", 0).to_upper()) if told else ("COUNTER ORDER - PRESS E" if customer != null else "APNA MART")
	for slot in range(order_icons.size()):
		var shown: bool = told and slot < customer.order_lines.size()
		order_icons[slot].visible = shown
		order_texts[slot].visible = shown
		if not shown: continue
		var line: Dictionary = customer.order_lines[slot]
		var need: int = customer.still_needed(line.product)
		order_icons[slot].texture = _picture(line.product)
		order_icons[slot].modulate = Color(1, 1, 1, 0.45) if need == 0 else Color.WHITE
		var code: String = furnishing.product_code(line.product) if is_instance_valid(furnishing) else ""
		order_texts[slot].text = "DONE" if need == 0 else "%s  x%d" % [code if not code.is_empty() else "--", need]
		order_texts[slot].modulate = Color(0.55, 1, 0.65) if need == 0 else Color.WHITE

func _refresh_bag_stand() -> void:
	if not is_instance_valid(bag_stand_label): return
	var bags: int = shop.business.carry_bags
	for index in range(bag_layers.size()): bag_layers[index].visible = bags > index * 3
	bag_stand_label.text = "CARRY BAGS: %d" % bags if bags > 0 else "NO CARRY BAGS\nBuy on the shop PC"

## One of our Blender props (assets/props/<path>.glb), its origin at `offset`.
func _prop(parent: Node3D, node_name: String, path: String, offset := Vector3.ZERO) -> Node3D:
	var prop: Node3D = (load("res://assets/props/%s.glb" % path) as PackedScene).instantiate()
	prop.name = node_name
	prop.position = offset
	parent.add_child(prop)
	return prop

## Our green APNA MART carry bag (tools/blender/build_carry_bag.py): printed front
## (+z), hem, loop handles; `full` is the packed one with groceries on top. Its
## bottom centre sits at `offset`.
func make_carry_bag(parent: Node3D, node_name: String, offset: Vector3, full := true) -> Node3D:
	return _prop(parent, node_name, "carry_bag/carry_bag%s" % ("_full" if full else ""), offset)

## A double glass-door cold-drink cooler (the fridge model: THANDA sides, wire shelves,
## door frames) around the usual three shelves of ten, on the rack footprint
## (rack_store.gd), with glass doors, a lit blue THANDA header and an inner light.
func build_fridge(builder: Node3D, node_name: String, position: Vector3) -> Dictionary:
	var model := build_stock_rack(builder, node_name, "bottle", position, "fridge")
	var node: Node3D = model.node
	var header: MeshInstance3D = builder._box("FridgeHeader", node, Vector3(0.05, 0.28, 2.1), Vector3(0.36, 1.9, 0), Color(0.1, 0.36, 0.78))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.12, 0.4, 0.85)
	glow.emission_enabled = true
	glow.emission = Color(0.12, 0.4, 0.85)
	glow.emission_energy_multiplier = 0.6
	header.material_override = glow
	var sign := _sign(node, "FridgeSign", "THANDA  -  COLD DRINKS", Vector3(0.39, 1.9, 0))
	sign.rotation.y = PI / 2
	sign.font_size = 30
	sign.modulate = Color.WHITE
	var strip: MeshInstance3D = builder._box("FridgeLight", node, Vector3(0.04, 0.03, 1.9), Vector3(0.2, 1.74, 0), Color(0.9, 0.97, 1.0))
	var light := StandardMaterial3D.new()
	light.albedo_color = Color(0.9, 0.97, 1.0)
	light.emission_enabled = true
	light.emission = Color(0.85, 0.95, 1.0)
	strip.material_override = light
	# Glass in the model's two door frames; items stay visible behind it.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.88, 0.95, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	for z in [-0.52, 0.52]:
		var door: MeshInstance3D = builder._box("FridgeGlass%s" % z, node, Vector3(0.02, 1.62, 1.0), Vector3(0.355, 0.97, z), Color.WHITE)
		door.material_override = glass
		door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model["fridge"] = true
	return model

## Customers pick cold drinks more often while a fridge has some (customer.gd).
func cold_drinks_chilled() -> bool:
	if not is_instance_valid(furnishing): return false
	for record in shop.business.racks.records:
		if record.get("display", "shelf") == "fridge" and furnishing.available(int(record.id), "bottle") > 0: return true
	return false

static func basket_position(slot: int) -> Vector3:
	return Vector3(0.22 - (slot / 4) * 0.22, 0.7 + (slot / 4) * 0.12, -0.78 + (slot % 4) * 0.52)

func build_produce_table(builder: Node3D, node_name: String, position: Vector3) -> Dictionary:
	var node := Node3D.new()
	node.name = node_name
	node.position = position
	add_child(node)
	builder._collider("TableBaseBody", node, Vector3(0.65, 0.65, 2.1), Vector3(0, 0.325, 0))
	_produce_stand(node)
	var items: Array[Node3D] = []
	for slot in range(12):
		var point := basket_position(slot)
		builder._box("BasketFloor%d" % slot, node, Vector3(0.2, 0.04, 0.49), point, Color(0.5, 0.34, 0.18))
		for side in [-1, 1]:
			builder._box("BasketEdge%d_%d" % [slot, side], node, Vector3(0.015, 0.085, 0.49), point + Vector3(side * 0.095, 0.04, 0), Color(0.66, 0.46, 0.26))
			builder._box("BasketEnd%d_%d" % [slot, side], node, Vector3(0.2, 0.085, 0.015), point + Vector3(0, 0.04, side * 0.237), Color(0.66, 0.46, 0.26))
		for index in range(10):
			var item := make_product(node, "BasketItem%d" % (slot * 10 + index), point + Vector3(-0.04 + (index % 2) * 0.08, 0.025, -0.19 + (index / 2) * 0.095), "tomato")
			item.scale = Vector3.ONE * 0.4
			items.append(item)
	var label := _sign(node, "StockSign", "PRODUCE TABLE", Vector3(0.4, 1.3, 0))
	label.rotation.y = PI / 2
	label.font_size = 24
	label.pixel_size = 0.003
	return {"node": node, "items": items, "label": label, "produce": true}

## Wooden market stand under the produce crates: three plank steps (one per crate
## row), corner posts and a "Fresh veggies daily" chalkboard on the front (+x).
func _produce_stand(node: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.62, 0.43, 0.25)
	var groove := Color(0.44, 0.29, 0.15)
	for tier in range(3):
		var x := 0.22 - tier * 0.22
		var height := 0.68 + tier * 0.12
		IndianHouse.box(st, Vector3(x, height / 2.0, 0), Vector3(0.22, height, 2.06), wood.darkened(tier * 0.04))
		for line in range(int(height / 0.14)): IndianHouse.box(st, Vector3(x + 0.111, 0.14 + line * 0.14, 0), Vector3(0.004, 0.012, 2.06), groove)
	for x in [-0.31, 0.31]:
		for z in [-1.04, 1.04]: IndianHouse.box(st, Vector3(x, 0.46, z), Vector3(0.05, 0.92, 0.05), groove)
	IndianHouse.box(st, Vector3(0.345, 0.34, 0), Vector3(0.02, 0.38, 0.6), wood.lightened(0.15))
	IndianHouse.box(st, Vector3(0.356, 0.34, 0), Vector3(0.01, 0.32, 0.54), Color(0.12, 0.16, 0.14))
	var stand := MeshInstance3D.new()
	stand.name = "ProduceStand"
	stand.mesh = st.commit()
	stand.material_override = IndianHouse._material()
	node.add_child(stand)
	var board := _sign(node, "ChalkBoard", "FRESH\nVEGGIES DAILY", Vector3(0.364, 0.34, 0))
	board.rotation.y = PI / 2
	board.font_size = 26
	board.pixel_size = 0.003
	board.outline_size = 0
	board.modulate = Color(0.95, 0.95, 0.88)

## A 2 m front wall piece (`height` tall, 0.12 thick, centred) with a 1.6 x 1.7 m
## window opening from 0.65 m to 2.35 m above the floor.
func _window_wall(height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom := -height / 2.0
	var sill := bottom + 0.55
	var head := sill + 1.7
	var top := height / 2.0
	IndianHouse.box(st, Vector3(0, (bottom + sill) / 2.0, 0), Vector3(2, sill - bottom, 0.12), Color.WHITE)
	IndianHouse.box(st, Vector3(0, (head + top) / 2.0, 0), Vector3(2, top - head, 0.12), Color.WHITE)
	for x in [-0.9, 0.9]: IndianHouse.box(st, Vector3(x, (sill + head) / 2.0, 0), Vector3(0.2, head - sill, 0.12), Color.WHITE)
	return st.commit()

func _resize_room_box(building: Node3D, node_name: String, size: Vector3, offset: Vector3) -> void:
	var instance: MeshInstance3D = building.get_node(node_name.validate_node_name())
	instance.mesh.size = size
	instance.position = offset
	var body := building.get_node_or_null((node_name + "Body").validate_node_name()) as StaticBody3D
	if body != null:
		body.position = offset
		body.get_node("CollisionShape3D").shape.size = size

func _update_room_size() -> void:
	var business = get_parent().get_node("Shop/ShopArea").business
	if room_expansion == business.shop_expansion: return
	room_expansion = business.shop_expansion
	var building: Node3D = get_parent().get_node("Shop")
	var depth: float = 10.0 + room_expansion * Store.EXPANSION_DEPTH
	var extension := depth - 5.0
	var center_z := -extension / 2.0
	_resize_room_box(building, "BackWall", Vector3(6, ROOM_HEIGHT, 0.12), Vector3(0, 0.5, -2.5 - extension))
	_resize_room_box(building, "SideWall%s" % 3.0, Vector3(0.12, ROOM_HEIGHT, depth), Vector3(3.0, 0.5, center_z))
	_left_wall_with_door(building, depth, center_z)
	_resize_room_box(building, "DoorLintel", Vector3(2, 1.4, 0.12), Vector3(0, 1.7, 2.5))
	_resize_room_box(building, "RoofTrim", Vector3(6.3, 0.18, depth + 0.3), Vector3(0, 2.5, center_z))
	_resize_room_box(building, "ParapetFront", Vector3(6.3, 0.3, 0.16), Vector3(0, 2.55, 2.66))
	_resize_room_box(building, "ParapetBack", Vector3(6.3, 0.3, 0.16), Vector3(0, 2.55, 2.43 - depth))
	for side in [-1, 1]:
		_resize_room_box(building, "ParapetLeft" if side < 0 else "ParapetRight", Vector3(0.16, 0.3, depth + 0.3), Vector3(side * 3.07, 2.55, center_z))
	_resize_room_box(building, "Floor", Vector3(5.9, 0.012, depth - 0.1), Vector3(0, -1.394, center_z))
	building.get_node("ShopInterior/CollisionShape3D").shape.size = Vector3(5.8, ROOM_HEIGHT, depth - 0.2)
	building.get_node("ShopInterior/CollisionShape3D").position = Vector3(0, 0.5, center_z)
	building.get_node("ShopArea/CollisionShape3D").shape.size = Vector3(7, ROOM_HEIGHT, depth + 1)
	building.get_node("ShopArea/CollisionShape3D").position = Vector3(0, 0.5, center_z)
	get_node("ShopLight").position.y = 3.3
	get_node("ShopLight").omni_range = depth + 1
	# Bought expansions (PC: Space) move the back wall; the room keeps its width.
	if is_instance_valid(player):
		var point: Vector3 = building.to_local(player.global_position)
		player.shop_indoors = absf(point.x) < 2.9 and point.z > -2.5 - extension and point.z < 2.4 and point.y < 2.4

## The left wall (any depth) with the doorway into the packing room: the mesh gets a
## hole and the collider is split into the parts behind, in front of and above it.
func _left_wall_with_door(building: Node3D, depth: float, center_z: float) -> void:
	var wall: MeshInstance3D = building.get_node(("SideWall%s" % -3.0).validate_node_name())
	wall.position = Vector3(-3.0, 0.5, center_z)
	var back := center_z - depth / 2.0
	var front := center_z + depth / 2.0
	var bottom := -ROOM_HEIGHT / 2.0
	var door_top := bottom + SIDE_DOOR_HEIGHT
	var pieces := [
		[Vector3(0.12, ROOM_HEIGHT, SIDE_DOOR.x - back), Vector3(0, 0, (back + SIDE_DOOR.x) / 2.0 - center_z)],
		[Vector3(0.12, ROOM_HEIGHT, front - SIDE_DOOR.y), Vector3(0, 0, (SIDE_DOOR.y + front) / 2.0 - center_z)],
		[Vector3(0.12, ROOM_HEIGHT / 2.0 - door_top, SIDE_DOOR.y - SIDE_DOOR.x), Vector3(0, (door_top + ROOM_HEIGHT / 2.0) / 2.0, (SIDE_DOOR.x + SIDE_DOOR.y) / 2.0 - center_z)],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in pieces: IndianHouse.box(st, piece[1], piece[0], Color.WHITE)
	wall.mesh = st.commit()
	if wall.material_override == null: wall.material_override = (get_parent().get_node("Neighbourhood") as Node)._material(Color(0.78, 0.83, 0.8))
	for index in range(pieces.size()):
		var body_name: String = ("SideWall%sBody" % -3.0).validate_node_name() if index == 0 else "SideDoorBody%d" % index
		var body := building.get_node_or_null(body_name) as StaticBody3D
		if body == null:
			body = StaticBody3D.new()
			body.name = body_name
			var collision := CollisionShape3D.new()
			collision.name = "CollisionShape3D"
			collision.shape = BoxShape3D.new()
			body.add_child(collision)
			building.add_child(body)
		body.position = wall.position + pieces[index][1]
		var shape := BoxShape3D.new()
		shape.size = pieces[index][0]
		body.get_node("CollisionShape3D").shape = shape

## World z of the inside of the back wall.
func back_z() -> float:
	return Store.floor_rect(room_expansion).position.y - 0.02

## Keeps everything that belongs to the back wall with it after an expansion: the
## back-wall decor, side paint and skirting, the interior sign, an extra ceiling
## light per expansion, and the expansion plot outside.
func follow_back_wall() -> void:
	var building: Node3D = get_parent().get_node("Shop")
	var decor := get_node_or_null("ShopDecor")
	var key := [room_expansion, decor != null, building.has_node("InteriorCategory")]
	if key == followed: return
	followed = key
	var back := back_z()
	if decor != null: decor.set_back(back)
	for skirting in building.find_children("WallSkirting*", "MeshInstance3D", false, false):
		# The left skirting stops at the packing room doorway (the rest is DoorSkirting).
		var front: float = SIDE_DOOR.x if skirting.position.x < 0.0 else 2.44
		skirting.mesh.size.z = front - back - 0.2
		skirting.position.z = (front + back) / 2.0
	var sign := building.get_node_or_null("InteriorCategory") as Node3D
	if sign != null: sign.position.z = back + 0.02
	# Store-room door and clock inside, back door and vent outside (shop_presentation.gd).
	var inside := building.get_node_or_null("BackWallInside") as Node3D
	if inside != null: inside.position.z = back + 0.02
	var outside := building.get_node_or_null("BackWallOutside") as Node3D
	if outside != null: outside.position.z = building.get_node("BackWall").position.z - 0.06
	for index in range(Store.MAX_EXPANSION):
		var fixture := get_node_or_null("ExpansionLight%d" % index) as Node3D
		if fixture == null:
			fixture = _box(self, "ExpansionLight%d" % index, Vector3(1.7, 0.07, 0.24), Vector3(-3, 3.82, -8.6 - index * Store.EXPANSION_DEPTH), Color(0.94, 0.98, 1))
			var glow := _material(Color(0.94, 0.98, 1)).duplicate() as StandardMaterial3D
			glow.emission_enabled = true
			glow.emission = Color(0.9, 0.96, 1)
			glow.emission_energy_multiplier = 0.6
			fixture.material_override = glow
			var lamp := OmniLight3D.new()
			lamp.name = "Lamp"
			lamp.position = Vector3(0, -0.15, 0)
			lamp.light_color = Color(0.96, 0.97, 1)
			lamp.light_energy = 0.7
			lamp.omni_range = 4.5
			lamp.shadow_enabled = false
			fixture.add_child(lamp)
		fixture.visible = index < room_expansion
	_place_expansion_plot()

## The cement plot behind the shop that expansions build on, with a rope and a
## sign while some of it is still for sale. It is laid at the start so no grass
## grows where the room will go (environment_details.gd masks it).
func _build_expansion_plot() -> void:
	var plot := Node3D.new()
	plot.name = "ExpansionPlot"
	add_child(plot)
	var far := Store.floor_rect(Store.MAX_EXPANSION).position.y - 0.14
	# The hidden copy keeps grass off the whole plot for good (environment_details.gd
	# reads hidden meshes too); the visible slab covers only the part not built on.
	var keep_clear := _box(plot, "GrassMask", Vector3(6.12, 0.01, -7.56 - far), Vector3(-3, 0.1, (-7.56 + far) / 2.0), Color(0.62, 0.61, 0.58))
	keep_clear.hide()
	_box(plot, "Slab", Vector3(6.12, 0.04, 1.0), Vector3(-3, 0.105, -9.0), Color(0.62, 0.61, 0.58))
	for index in range(4): _box(plot, "Post%d" % index, Vector3(0.06, 0.9, 0.06), Vector3.ZERO, Color(0.95, 0.5, 0.1))
	for index in range(3): _box(plot, "Rope%d" % index, Vector3(0.02, 0.02, 0.02), Vector3.ZERO, Color(0.95, 0.5, 0.1))
	var board := _box(plot, "SignBoard", Vector3(1.6, 0.6, 0.05), Vector3(-3, 1.1, far + 0.3), Color(0.97, 0.96, 0.9))
	var text := _sign(board, "SignText", "SHOP EXPANSION PLOT\nBuy more space on the shop PC: Space", Vector3(0, 0, -0.03))
	text.rotation.y = PI
	text.font_size = 28
	text.modulate = Color(0.12, 0.2, 0.18)
	_box(plot, "SignLeg", Vector3(0.06, 0.8, 0.06), Vector3(-3, 0.45, far + 0.3), Color(0.3, 0.3, 0.3))

func _place_expansion_plot() -> void:
	var plot := get_node_or_null("ExpansionPlot")
	if plot == null: return
	var far := Store.floor_rect(Store.MAX_EXPANSION).position.y - 0.14
	var near := back_z() - 0.2
	var open := room_expansion < Store.MAX_EXPANSION
	var corners := [Vector3(-6.0, 0.55, near), Vector3(-6.0, 0.55, far), Vector3(0.0, 0.55, far), Vector3(0.0, 0.55, near)]
	for index in range(4):
		plot.get_node("Post%d" % index).position = corners[index]
		plot.get_node("Post%d" % index).visible = open
	for index in range(3):
		var rope: MeshInstance3D = plot.get_node("Rope%d" % index)
		var from: Vector3 = corners[index] + Vector3(0, 0.3, 0)
		var to: Vector3 = corners[index + 1] + Vector3(0, 0.3, 0)
		rope.mesh.size = Vector3(maxf(0.02, absf(to.x - from.x)), 0.03, maxf(0.02, absf(to.z - from.z)))
		rope.position = (from + to) / 2.0
		rope.visible = open
	for node_name in ["SignBoard", "SignLeg", "Slab"]: plot.get_node(node_name).visible = open
	var slab: MeshInstance3D = plot.get_node("Slab")
	slab.mesh.size.z = maxf(0.1, near + 0.14 - far)
	slab.position.z = (near + 0.14 + far) / 2.0

func employee_tag(employee: Node3D, text: String) -> Label3D:
	var label := _sign(employee, "EmployeeNameLabel", text, Vector3(0, 1.85, 0))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.0035
	return label

func _ready() -> void:
	if not enabled:
		set_process(false)
		set_process_unhandled_input(false)
		return
	export_world = preload("res://export_world.gd").new()
	get_parent().add_child.call_deferred(export_world)
	dungeon_world = preload("res://dungeon_world.gd").new()
	dungeon_world.ops = self
	get_parent().add_child.call_deferred(dungeon_world)
	var audio := Node.new()
	audio.name = "ShopAudio"
	audio.set_script(load("res://shop_audio.gd"))
	add_child(audio)
	if absf(player.global_position.x) < 0.6 and absf(player.global_position.z) < 2.6:
		player.global_position.x = 1.1
	delivery_box = _crate(self, "DeliveryBox")
	delivery_box.position = drop_point + Vector3(0, 0.4, 0)
	carried_box = _crate(player, "CarriedBox")
	carried_box.position = Vector3(0, 0.05, -0.85)
	carried_box.scale = Vector3.ONE * 0.85
	carried_box.set_script(preload("res://box_carry_visual.gd"))
	carried_box.initialize(player)
	held_bag = make_carry_bag(player, "HeldCarryBag", Vector3(0.46, 0.16, -0.82), false)
	held_bag.scale = Vector3.ONE * 1.1
	held_bag.hide()
	for index in range(3):
		var bottle := make_bottle(counter, "CheckoutBottle%d" % index, Vector3(-1.0 + index * 0.27, 0.59, 0.1))
		bottle.hide()
		checkout_items.append(bottle)
	payment_prop = _box(counter, "PaymentProp", Vector3(0.18, 0.02, 0.28), Vector3(-0.95, 0.59, -0.25), Color(0.1, 0.15, 0.2))
	payment_prop.hide()
	phone_screen = _box(payment_prop, "PhoneScreen", Vector3(0.14, 0.005, 0.21), Vector3(0, 0.014, 0), Color(0.65, 0.89, 0.88))
	card_chip = _box(payment_prop, "CardChip", Vector3(0.035, 0.005, 0.045), Vector3(-0.04, 0.014, 0), Color(0.88, 0.75, 0.3))
	stock_worker = load("res://worker.tscn").instantiate()
	stock_worker.name = "StockWorker"
	stock_worker.set_script(load("res://stock_worker.gd"))
	stock_worker.position = Vector3(-4.6, 0.1, -1.8)
	stock_worker.get_node("CharacterVisual").shirt_color = Color(0.7, 0.42, 0.18)
	stock_worker.get_node("CharacterVisual").model = "staff-f"
	employee_tag(shop.worker, "Ramesh")
	employee_tag(stock_worker, "Sunil")
	get_parent().add_child.call_deferred(stock_worker)
	var doors := Node3D.new()
	doors.name = "SlidingDoor"
	doors.set_script(load("res://sliding_door.gd"))
	add_child(doors)
	_build_van()
	# Twin WET/DRY dustbin against the front wall, right of the door.
	var bins := Node3D.new()
	bins.name = "Dustbin"
	bins.set_script(preload("res://dustbin.gd"))
	bins.position = Vector3(-1.0, 0.1, 2.86)
	add_child(bins)
	shop.business.changed.connect(_sync_state)
	_sync_state()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func _mesh(parent: Node3D, node_name: String, mesh: Mesh, offset: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = offset
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, node_name: String, size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, node_name, mesh, offset, color)

func make_bottle(parent: Node3D, node_name: String, offset: Vector3) -> Node3D:
	var bottle := Node3D.new()
	bottle.name = node_name
	bottle.position = offset
	parent.add_child(bottle)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.065
	mesh.bottom_radius = 0.09
	mesh.height = 0.34
	mesh.radial_segments = 8
	_mesh(bottle, "BottleBody", mesh, Vector3(0, 0.17, 0), Color(0.2, 0.66, 0.67))
	bottle.get_node("BottleBody").hide()
	preload("res://product_assets.gd").attach(bottle, "bottle", Vector3(0.18, 0.4, 0.18))
	# Small screw cap fitted over the model's own neck; it still turns green when scanned.
	var cap := CylinderMesh.new()
	cap.top_radius = 0.03
	cap.bottom_radius = 0.032
	cap.height = 0.035
	cap.radial_segments = 10
	_mesh(bottle, "Cap", cap, Vector3(0, _asset_box("bottle", Vector3(0.18, 0.4, 0.18)).end.y - 0.015, 0), Color(0.92, 0.93, 0.9))
	return bottle

const PRODUCE_SIZES := {"tomato": Vector3(0.19, 0.18, 0.19), "carrot": Vector3(0.2, 0.2, 0.2), "cabbage": Vector3(0.2, 0.19, 0.2), "corn": Vector3(0.2, 0.22, 0.2), "apple": Vector3(0.17, 0.17, 0.17)}
const GROCERY_SIZES := {"oil": Vector3(0.14, 0.3, 0.11), "milk": Vector3(0.14, 0.24, 0.11), "bread": Vector3(0.16, 0.13, 0.17), "chocolate": Vector3(0.16, 0.06, 0.15), "honey": Vector3(0.13, 0.16, 0.13)}
static var asset_boxes: Dictionary = {}
# Real size of a fitted product model, so caps/seals sit exactly on top of it.
func _asset_box(id: String, size: Vector3) -> AABB:
	if not asset_boxes.has(id):
		var Assets = preload("res://product_assets.gd")
		var probe := Node3D.new()
		Assets.attach(probe, id, size)
		var asset: Node3D = probe.get_node("ProductAsset")
		asset_boxes[id] = Assets._bounds(asset, Transform3D.IDENTITY)
		probe.free()
	return asset_boxes[id]

func make_product(parent: Node3D, node_name: String, offset: Vector3, id: String) -> Node3D:
	if id == "bottle": return make_bottle(parent, node_name, offset)
	var item := Node3D.new()
	item.name = node_name
	item.position = offset
	parent.add_child(item)
	if PRODUCE_SIZES.has(id):
		preload("res://produce_assets.gd").attach(item, id, PRODUCE_SIZES[id], "ProductBody")
		# Checkout retains its existing Cap hook; produce has no packaging cap.
		_box(item, "Cap", Vector3(0.01, 0.01, 0.01), Vector3.ZERO, Color.WHITE).hide()
		return item
	if GROCERY_SIZES.has(id):
		# Kenney Food Kit grocery models (cooking oil, milk, bread, chocolate, honey).
		preload("res://product_assets.gd").attach(item, id, GROCERY_SIZES[id])
		_box(item, "Cap", Vector3(0.01, 0.01, 0.01), Vector3.ZERO, Color.WHITE).hide()
		return item
	var height := 0.26 if id == "snack" else 0.12
	_box(item, "ProductBody", Vector3(0.16, height, 0.11), Vector3(0, height / 2, 0), Color(0.87, 0.25, 0.24) if id == "snack" else Color(0.35, 0.65, 0.94))
	if id == "snack":
		item.get_node("ProductBody").hide()
		preload("res://product_assets.gd").attach(item, id, Vector3(0.16, height, 0.11))
	else:
		preload("res://product_assets.gd").label_product(item, id)
	if id == "snack":
		# Thin heat-seal strip along the real top edge of the bag model.
		var bag := _asset_box(id, Vector3(0.16, height, 0.11))
		_box(item, "Cap", Vector3(bag.size.x * 0.92, 0.018, minf(bag.size.z * 0.5, 0.04)), Vector3(0, bag.end.y - 0.009, 0), Color(0.92, 0.93, 0.9))
	else:
		_box(item, "Cap", Vector3(0.165, 0.025, 0.115), Vector3(0, height, 0), Color(0.92, 0.93, 0.9))
	return item

func rack_target(id: String, rack_id := -1) -> Vector3:
	if is_instance_valid(furnishing):
		var record: Dictionary = furnishing.business.racks.find(rack_id if rack_id >= 0 else furnishing.stock_rack(id))
		if not record.is_empty(): return furnishing.Store.approach(record)
	return rack_point if id == "bottle" or not product_racks.has(id) else product_racks[id].position + Vector3(1, 0, 0)

func play_sound(effect: String) -> void:
	get_node("ShopAudio").play_effect(effect)

func _sign(parent: Node3D, node_name: String, value: String, offset: Vector3) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = value
	label.font_size = 32
	label.pixel_size = 0.002
	label.outline_size = 3
	label.position = offset
	parent.add_child(label)
	return label

func _crate(parent: Node3D, node_name: String) -> Node3D:
	var crate := Node3D.new()
	crate.name = node_name
	parent.add_child(crate)
	# The carton model prints the tape, the shipping label and the handling marks.
	_prop(crate, "Carton", "shop/carton")
	var label := _sign(crate, "BoxLabel", "10 BOTTLES", Vector3(0, 0.01, 0.405))
	label.font_size = 28
	label.outline_size = 0
	label.modulate = Color(0.08, 0.12, 0.15)
	var company := _sign(crate, "SupplierLabel", "RACKWORKS" if node_name.begins_with("RackPackage") else "APNA WHOLESALE", Vector3(0, -0.17, 0.405))
	company.font_size = 20
	company.outline_size = 0
	company.modulate = Color(0.15, 0.2, 0.22)
	return crate

func _build_van() -> void:
	van = Node3D.new()
	van.name = "DeliveryVan"
	add_child(van)
	_box(van, "CargoBody", Vector3(3.2, 1.5, 1.65), Vector3(-0.3, 1.3, 0), Color(0.85, 0.9, 0.86))
	_box(van, "Cab", Vector3(1.2, 1.3, 1.55), Vector3(1.75, 1.1, 0), Color(0.14, 0.5, 0.41))
	_box(van, "Windshield", Vector3(0.03, 0.5, 1.25), Vector3(2.37, 1.43, 0), Color(0.25, 0.48, 0.58))
	_sign(van, "SupplySign", "SHOP SUPPLY", Vector3(-0.3, 1.4, 0.84))
	for x in [-1.2, 1.65]:
		for z in [-0.87, 0.87]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.37
			wheel.bottom_radius = 0.37
			wheel.height = 0.18
			wheel.radial_segments = 10
			var instance := _mesh(van, "Wheel%s_%s" % [x, z], wheel, Vector3(x, 0.43, z), Color(0.08, 0.1, 0.11))
			instance.rotation.x = PI / 2
	van.hide()

func _sync_state() -> void:
	if not enabled or not is_instance_valid(delivery_box):
		return
	_refresh_bag_stand()
	_update_room_size()
	follow_back_wall()
	apply_fixtures()
	var decor := get_node_or_null("ShopDecor")
	if decor != null:
		var counts := {}
		# Everything the shop owns: on the racks, in storage, in boxes at the bay or in hand.
		var business = shop.business
		for id in decor.WALL_PRODUCTS: counts[id] = business.product_stock(id) + business.logistics.stored_units(id)
		for box in business.queued_boxes: counts[box.product] = int(counts.get(box.product, 0)) + int(box.amount)
		if counts.has(business.pending_product): counts[business.pending_product] += business.boxed_stock + business.carried_stock
		decor.show_stock(counts)
	delivery_box.visible = shop.business.boxed_stock > 0
	delivery_box.scale = Vector3.ONE * 0.75
	delivery_box.rotation.y = PI
	delivery_box.position = product_delivery_point(0)
	carried_box.visible = shop.business.carried_stock > 0
	delivery_box.get_node("BoxLabel").text = "%d %s" % [shop.business.boxed_stock, Catalog.NAMES[shop.business.pending_product].to_upper()]
	if shop.business.carried_stock > 0:
		carried_box.get_node("BoxLabel").text = "%d %s" % [shop.business.carried_stock, Catalog.NAMES[shop.business.pending_product].to_upper()]
	while extra_delivery_boxes.size() < shop.business.queued_boxes.size():
		extra_delivery_boxes.append(_crate(self, "DeliveryBox%d" % (extra_delivery_boxes.size() + 2)))
	for index in range(extra_delivery_boxes.size()):
		var crate := extra_delivery_boxes[index]
		crate.visible = index < shop.business.queued_boxes.size()
		if not crate.visible: continue
		var box: Dictionary = shop.business.queued_boxes[index]
		var slot := index + 1
		crate.scale = Vector3.ONE * 0.75
		crate.rotation.y = PI
		crate.position = product_delivery_point(slot)
		crate.get_node("BoxLabel").text = "%d %s" % [box.amount, Catalog.NAMES[box.product].to_upper()]
	var warehouse = get_parent().get_node_or_null("Warehouse")
	var lane_available: bool = warehouse == null or warehouse.truck_state == 0
	_refresh_ground_boxes()
	if shop.business.supply_in_transit > 0 and delivery_state == DeliveryState.IDLE and lane_available:
		delivery_state = DeliveryState.ARRIVING
		van.position = Vector3(-26, 0.1, 8.6)
		van.show()
	update_rack()

func _register_fixture(fixture: String, nodes: Array) -> void:
	fixture_parts[fixture] = nodes.map(func(node): return [node, node.transform])

## Moves a point of the shop as built (the fixture at its home spot) to where the
## fixture stands now, or at `place` ({x, z, turn}).
func fixture_transform(fixture: String, place := {}) -> Transform3D:
	var home: Dictionary = Store.FIXTURE_HOME[fixture]
	if place.is_empty(): place = shop.business.racks.fixtures[fixture]
	return Transform3D(Basis(Vector3.UP, int(place.turn) * PI / 2), Vector3(place.x, 0, place.z)) * Transform3D(Basis(), Vector3(-home.x, 0, -home.z))

func apply_fixtures() -> void:
	for fixture in fixture_parts:
		var moved := fixture_transform(fixture)
		for part in fixture_parts[fixture]: part[0].transform = moved * part[1]
	var counter_moved := fixture_transform("counter")
	var previous := cashier_point
	cashier_point = counter_moved * Vector3(-2.5, 0.1, -0.6)
	get_parent().get_node("CustomerPurchasePoint").position = counter_moved * Vector3(-2.5, 0.1, 1.2)
	# A moved counter takes its cashier along instead of walking them through it.
	if not previous.is_equal_approx(cashier_point) and not departures.has("cashier"):
		shop.worker.position = cashier_point
		shop.worker.rotation.y = counter_moved.basis.get_euler().y + PI

## Where customers join the queue and where they step out after paying.
func queue_entry() -> Vector3:
	return fixture_transform("counter") * Vector3(-4.6, 0.1, 1.65)

func counter_at_home() -> bool:
	return shop.business.racks.fixtures.counter == Store.FIXTURE_HOME.counter

## Customers walking to, waiting in or paying at the queue keep the counter in place.
func counter_busy() -> bool:
	for child in get_parent().get_children():
		if child.get("product_id") != null and child.get("state") in [2, 4, 6, 7, 8, 9, 10]: return true
	return not queue.is_empty()

func product_delivery_point(slot: int) -> Vector3:
	return drop_point + Vector3((slot % 5) * 0.7, 0.3, (slot / 5) * 0.7)

func _refresh_ground_boxes() -> void:
	var boxes: Array = shop.business.logistics.ground_boxes
	while ground_boxes.size() < boxes.size():
		var crate := _crate(self, "GroundBox%d" % ground_boxes.size())
		crate.scale = Vector3.ONE * 0.75
		var body := StaticBody3D.new()
		body.name = "GroundBody"
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		collision.shape = BoxShape3D.new()
		collision.shape.size = Vector3.ONE * 0.8
		body.add_child(collision)
		crate.add_child(body)
		ground_boxes.append(crate)
	for index in range(ground_boxes.size()):
		var crate := ground_boxes[index]
		crate.visible = index < boxes.size()
		crate.get_node("GroundBody").collision_layer = 1 if crate.visible else 0
		if not crate.visible: continue
		var box: Dictionary = boxes[index]
		crate.position = Vector3(box.position[0], box.position[1], box.position[2])
		crate.get_node("BoxLabel").text = "%d %s" % [box.amount, Catalog.NAMES[box.product].to_upper()]

func ground_box_target() -> int:
	var best := -1
	var alignment := 0.75
	for index in range(ground_boxes.size()):
		var crate := ground_boxes[index]
		if not crate.visible or not _near(crate.global_position, 1.8): continue
		var dot: float = (-player.camera.global_basis.z).dot(player.camera.global_position.direction_to(crate.global_position))
		if dot > alignment:
			alignment = dot
			best = index
	return best

func release_held_item() -> bool:
	if not enabled or player._menu_is_open(): return false
	if is_instance_valid(furnishing) and furnishing.active:
		furnishing.cancel()
		return true
	if is_instance_valid(export_world) and export_world.release(): return true
	if holding_bag:
		var customer := order_customer()
		var product: String = customer.take_from_bag() if customer != null else ""
		if not product.is_empty():
			ui.show_feedback("Took 1 %s out of the bag." % Catalog.NAMES[product])
		else:
			holding_bag = false
			held_bag.hide()
			shop.business.return_carry_bag()
			ui.show_feedback("Carry bag put back on the stand.")
		return true
	if shop.business.carried_stock <= 0: return false
	# At a rack holding this box's product, Q takes one item back into the box.
	var product: String = shop.business.pending_product
	var take_rack: int = furnishing.near_stocked_rack(product) if is_instance_valid(furnishing) else -1
	if take_rack >= 0:
		if shop.business.carried_stock >= shop.business.STOCK_AMOUNT:
			ui.show_feedback("The box is full. Put items on the shelf with E.", true)
		elif shop.business.unshelve_one(take_rack):
			play_sound("stock")
			ui.show_feedback("Took 1 %s back. %d in the box." % [Catalog.NAMES[product], shop.business.carried_stock])
		return true
	var point: Vector3 = player.global_position - player.global_basis.z * 1.0
	var space := get_world_3d().direct_space_state
	var clearance := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.6, point + Vector3.UP * 0.6)
	clearance.exclude = [player.get_rid()]
	if not space.intersect_ray(clearance).is_empty():
		ui.show_feedback("The spot ahead is blocked. Move to a clear spot.", true)
		return true
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.5, point - Vector3.UP * 2.0)
	ray.exclude = [player.get_rid()]
	var floor_hit := space.intersect_ray(ray)
	if floor_hit.is_empty() or floor_hit.normal.y < 0.7:
		ui.show_feedback("No safe surface here. Move to a clear spot.", true)
		return true
	point = floor_hit.position + Vector3.UP * 0.32
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = BoxShape3D.new()
	query.shape.size = Vector3.ONE * 0.59
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.exclude = [player.get_rid()]
	if not space.intersect_shape(query, 1).is_empty():
		ui.show_feedback("Not enough room to put down the box here.", true)
		return true
	if shop.business.put_down_box(point):
		play_sound("stock")
		ui.show_feedback("Box put down. Aim at it and press E to pick it up.")
	else: ui.show_feedback("Could not put down the box. Check save status.", true)
	return true

func _process(delta: float) -> void:
	scan_flash_remaining = maxf(0.0, scan_flash_remaining - delta)
	if is_instance_valid(scanner_light): scanner_light.light_energy = 0.75 if scan_flash_remaining > 0.0 else 0.0
	_employee_presence(shop.worker, "cashier", delta)
	if is_instance_valid(stock_worker): _employee_presence(stock_worker, "stock", delta)
	_update_checkout_display()
	match delivery_state:
		DeliveryState.IDLE:
			if shop.business.supply_in_transit > 0: _sync_state()
		DeliveryState.ARRIVING:
			van.position.x = move_toward(van.position.x, -9.4, delta * 4.0)
			if is_equal_approx(van.position.x, -9.4):
				delivery_state = DeliveryState.UNLOADING
				unload_seconds = 1.5
		DeliveryState.UNLOADING:
			unload_seconds -= delta
			if unload_seconds <= 0:
				delivery_state = DeliveryState.LEAVING
				if shop.business.receive_delivery():
					ui.show_feedback("Delivery arrived in the warehouse product bay.")
					play_sound("delivery")
		DeliveryState.LEAVING:
			van.position.x = move_toward(van.position.x, 29.0, delta * 5.0)
			if is_equal_approx(van.position.x, 29.0):
				van.hide()
				delivery_state = DeliveryState.IDLE
				_sync_state()

func _employee_presence(actor: Node3D, role: String, delta: float) -> void:
	var business = shop.business
	var record: Dictionary = business.staff.records[role]
	var on_shift: bool = business.staff.on_shift(business, role)
	var pending: bool = business.staff.active(business, role) and record.state in ["leave", "pay"]
	if on_shift or pending:
		if departures.has(role):
			actor.position = cashier_point if role == "cashier" else Vector3(-4.6, 0.1, -1.8)
			departure_paths.erase(role)
			departures.erase(role)
		actor.show()
		if role == "cashier":
			var counter_moved := fixture_transform("counter")
			var target := counter_moved * Vector3(-3.7, 0.1, -1.0) if player_at_counter() else cashier_point
			actor.position = actor.position.move_toward(target, delta * 1.5)
			actor.rotation.y = counter_moved.basis.get_euler().y + PI
		return
	if not business.staff.hired(business, role): actor.hide(); return
	if not departures.has(role):
		if role == "stock" and not actor.route.is_empty():
			# A simple off-hours pause keeps existing assigned tasks intact.
			if record.state != "done" and record.quit_day == 0: return
			actor.route.clear()
		departures[role] = 0
		departure_paths[role] = _departure_path(actor, role)
	if not departure_paths.has(role): departure_paths[role] = _departure_path(actor, role)
	var path: Array[Vector3] = departure_paths[role]
	var index: int = departures[role]
	if index >= path.size(): actor.hide(); return
	actor.show()
	if actor.global_position.distance_squared_to(path[index]) > 0.0001: actor.look_at(path[index], Vector3.UP)
	actor.position = actor.position.move_toward(path[index], delta * 1.8)
	if actor.position.is_equal_approx(path[index]): departures[role] = index + 1

func _departure_path(actor: Node3D, role: String) -> Array[Vector3]:
	var path: Array[Vector3] = [Vector3(-4.6, 0.1, -0.6), Vector3(-4.6, 0.1, 1.65), Vector3(-3, 0.1, 1.65), Vector3(-3, 0.1, 3.3), Vector3(-3, 0.1, 5)]
	# From a moved counter the cashier finds a way round the racks to the door.
	if role == "cashier" and not counter_at_home():
		var walk: Array[Vector3] = shop.business.racks.route(actor.position, Store.ENTRY)
		if not walk.is_empty():
			walk.append_array([Vector3(-3, 0.1, 3.3), Vector3(-3, 0.1, 5)])
			return walk
	return path

func _near(point: Vector3, distance := 1.65) -> bool:
	var offset: Vector3 = player.global_position - point
	offset.y = 0
	return offset.length_squared() <= distance * distance

func player_at_counter() -> bool:
	return _near(cashier_point, 1.25)

## Co-op host: a friend stands at the counter (coop_world.gd), so the hired cashier
## leaves the checkout to them.
var coop_friend_at_counter := false

func someone_at_counter() -> bool:
	return player_at_counter() or coop_friend_at_counter

func available_stock(product := "bottle") -> int:
	var reserved := 0
	for child in get_parent().get_children():
		if child.has_method("resolve_bargain") and child.product_id == product and child.has_product and child.state != child.State.LEAVING and not child.is_queued_for_deletion():
			reserved += child.basket_count
		if child.has_method("resolve_bargain") and child.has_product and child.state != child.State.LEAVING and not child.is_queued_for_deletion():
			for line in child.extra_lines:
				if line.taken and line.product == product: reserved += int(line.count)
		# Items in a counter order's carry bag or an export carton.
		if child.get("bag_lines") is Array:
			for line in child.bag_lines:
				if line.product == product: reserved += int(line.count)
	return maxi(0, shop.business.product_stock(product) - reserved)

func update_rack() -> void:
	if is_instance_valid(furnishing):
		furnishing.refresh_stock()
		return
	if not is_instance_valid(rack_label):
		return
	var available := available_stock()
	for index in range(rack_bottles.size()):
		rack_bottles[index].visible = index < available
	rack_label.text = "BOTTLES: %d" % available
	for id in product_items:
		var count := available_stock(id)
		for index in range(product_items[id].size()): product_items[id][index].visible = index < count
		product_labels[id].text = "%s: %d" % [Catalog.NAMES[id].to_upper(), count]

func animate_shelf_item(product: String, rack_id := -1) -> void:
	var items: Array = rack_bottles if product == "bottle" else product_items.get(product, [])
	var index := mini(available_stock(product) - 1, items.size() - 1)
	if rack_id >= 0 and is_instance_valid(furnishing):
		items = furnishing.models[rack_id].items
		var row: int = shop.business.racks.last_added_slot
		var record: Dictionary = shop.business.racks.find(rack_id)
		if row < 0: return
		index = row * 10 + int(record.slots[row].count) - 1
	if index < 0: return
	var item: Node3D = items[index]
	var resting_position := item.position
	item.visible = true
	var resting_scale := Vector3.ONE * (0.4 if rack_id >= 0 and is_instance_valid(furnishing) and furnishing.models[rack_id].get("produce", false) else 1.0)
	item.scale = resting_scale * 0.18
	item.position = resting_position + Vector3(0.48, 0.22, 0)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", resting_scale, 0.28)
	tween.tween_property(item, "position", resting_position, 0.28)

func enqueue(customer: Node3D) -> void:
	if customer not in queue:
		queue.append(customer)

func remove_customer(customer: Node3D) -> void:
	queue.erase(customer)
	update_rack()

func show_basket(customer: Node3D) -> void:
	basket_customer = customer
	var products: Array[String] = customer.basket_products()
	while checkout_items.size() < products.size():
		var spare := make_bottle(counter, "CheckoutBottle%d" % checkout_items.size(), Vector3.ZERO)
		spare.hide()
		checkout_items.append(spare)
	for index in range(checkout_items.size()):
		var previous := checkout_items[index]
		counter.remove_child(previous)
		previous.queue_free()
		checkout_items[index] = make_product(counter, "CheckoutBottle%d" % index, Vector3.ZERO, products[index] if index < products.size() else customer.product_id)
		# Two rows of five keep big family baskets on the free end of the counter.
		checkout_items[index].position = Vector3(-1.12 + (index % 5) * 0.24, 0.59, 0.16 - (index / 5 % 2) * 0.24)
		checkout_items[index].visible = index < products.size()
		checkout_items[index].get_node("Cap").material_override = _material(Color(0.92, 0.93, 0.9))
	_update_checkout_display()

func _update_checkout_display() -> void:
	_update_order_screen()
	if is_instance_valid(basket_customer) and basket_customer.counter_order and basket_customer.state == basket_customer.State.ORDERING:
		checkout_display.text = "COUNTER ORDER\n%d/%d IN BAG\n%s" % [basket_customer.bag_total(), basket_customer.order_items(), "FILL THE BAG" if basket_customer.order_told else "TAKE ORDER"]
		return
	if is_instance_valid(basket_customer):
		var status: String = basket_customer.payment_method if basket_customer.state == basket_customer.State.PAYING else "READY TO SCAN"
		if basket_customer.state == basket_customer.State.SCANNING and basket_customer.cashier_active:
			status = "SCAN %.1fs" % maxf(0, basket_customer.auto_checkout_seconds)
		elif basket_customer.state == basket_customer.State.NEGOTIATING: status = "PRICE DISCUSSION"
		elif basket_customer.state == basket_customer.State.SCANNING and not player_at_counter(): status = "CASHIER NEEDED"
		checkout_display.text = "%d/%d SCANNED\n%s%d\n%s" % [basket_customer.scanned_count, basket_customer.total_items(), String.chr(8377), basket_customer.scanned_total(), status]
		var paid: bool = basket_customer.state == basket_customer.State.PAYING
		if screen_payment != paid:
			screen_payment = paid
			checkout_pc.get_node("Screen").material_override = _material(Color(0.12, 0.38, 0.24) if paid else Color(0.07, 0.25, 0.28))

func mark_scanned(customer: Node3D, index: int) -> void:
	if basket_customer == customer and index < checkout_items.size():
		var item: Node3D = checkout_items[index]
		var scanned_position := Vector3(0.7 + (index % 3) * 0.22, 0.59, 0.1 - (index / 3) * 0.22)
		var tween := create_tween()
		tween.tween_property(item, "position", Vector3(0.58, 0.65, 0.08), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_finish_scan_animation.bind(item))
		tween.tween_property(item, "position", scanned_position, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_update_checkout_display()

func _finish_scan_animation(item) -> void:
	scan_flash_remaining = 0.16
	if is_instance_valid(item): item.get_node("Cap").material_override = _material(Color(0.4, 0.9, 0.65))

func aimed_checkout_item(customer: Node3D) -> int:
	if not is_instance_valid(customer) or customer.state != customer.State.SCANNING or not player_at_counter(): return -1
	var camera: Camera3D = player.camera
	var best_alignment := 0.965
	var result := -1
	for index in range(mini(customer.total_items(), checkout_items.size())):
		if index in customer.scanned_items: continue
		var item: Node3D = checkout_items[index]
		if not item.visible: continue
		var direction := camera.global_position.direction_to(item.global_position + Vector3(0, 0.15, 0))
		var alignment := (-camera.global_basis.z).dot(direction)
		if alignment > best_alignment:
			best_alignment = alignment
			result = index
	return result

func scan_aimed_checkout_item(customer: Node3D) -> bool:
	var index := aimed_checkout_item(customer)
	if index < 0:
		ui.show_feedback("Aim at an unscanned product on the counter.", true)
		return false
	return customer.scan_item(index)

## Counter orders: nothing to scan on the counter; the filled bag stands there
## while the customer pays (place_counter_bag).
func show_bag(customer: Node3D) -> void:
	basket_customer = customer
	for item in checkout_items: item.hide()
	place_counter_bag(false)
	_update_checkout_display()

func place_counter_bag(shown: bool) -> void:
	if is_instance_valid(counter_bag): counter_bag.visible = shown

## The customer at the till waiting for their counter order, or null.
func order_customer() -> Node3D:
	var customer := checkout_customer()
	return customer if customer != null and customer.get("counter_order") == true and customer.state == customer.State.ORDERING else null

## E for counter orders: at the till take the order, then a carry bag, then hand the
## filled bag over (the payment menu opens); at a rack put one listed item in the bag.
func _try_counter_order() -> bool:
	var customer := order_customer()
	if customer == null or not is_instance_valid(furnishing): return false
	var name: String = customer.customer_name.get_slice(" - ", 0)
	if player_at_counter():
		if not customer.order_told:
			customer.tell_order()
			ui.show_feedback("%s's list is on the right. Take a carry bag (E) and fill it at the racks." % name)
		elif not holding_bag:
			if is_instance_valid(export_world) and export_world.holding():
				ui.show_feedback("Your hands are full with the export parcel. Put it down first.", true)
			elif shop.business.carried_stock > 0:
				ui.show_feedback("Put the box down first (Q), then take a carry bag.", true)
			elif shop.business.use_carry_bag():
				holding_bag = true
				held_bag.show()
				play_sound("stock")
				ui.show_feedback("Carry bag in hand. At each rack press E to put a listed item in.")
			else: ui.show_feedback("No carry bags left! Buy a pack on the shop PC (Wholesale > Supplies).", true)
		elif customer.bag_total() == 0:
			ui.show_feedback("The bag is empty. Put the listed items in at the racks.", true)
		elif customer.hand_over_bag():
			holding_bag = false
			held_bag.hide()
			play_sound("stock")
			if customer.state == customer.State.PAYING: ui.checkout_menu.open_menu()
		return true
	if not holding_bag: return false
	var record: Dictionary = furnishing.near_any_rack()
	if record.is_empty(): return false
	for line in customer.order_lines:
		if customer.still_needed(line.product) > 0 and furnishing.available(int(record.id), line.product) > 0 and customer.add_to_bag(line.product, int(record.id)):
			play_sound("stock")
			ui.show_feedback("In the bag: %s %d/%d" % [Catalog.NAMES[line.product], customer.in_bag(line.product), line.count])
			return true
	if customer.bag_total() < customer.order_items(): ui.show_feedback("Nothing from %s's list on this rack." % name, true)
	else: ui.show_feedback("The bag is full. Give it to %s at the counter." % name)
	return true

func _counter_order_hint() -> String:
	var customer := order_customer()
	if customer == null or not is_instance_valid(furnishing):
		return "Q: put the carry bag back" if holding_bag and player_at_counter() else ""
	var name: String = customer.customer_name.get_slice(" - ", 0)
	if player_at_counter():
		if not customer.order_told: return "Take %s's order" % name
		if not holding_bag: return "Take a carry bag (%d left)" % shop.business.carry_bags if shop.business.carry_bags > 0 else "No carry bags! Buy a pack on the shop PC"
		if customer.bag_total() == 0: return "Fill the bag at the racks   |   Q: put the bag back"
		return "Give the bag to %s (%d/%d items)" % [name, customer.bag_total(), customer.order_items()]
	if not holding_bag: return ""
	var record: Dictionary = furnishing.near_any_rack()
	if record.is_empty(): return ""
	for line in customer.order_lines:
		if customer.still_needed(line.product) > 0 and furnishing.available(int(record.id), line.product) > 0:
			return "Put 1 %s in the bag (%d/%d)   |   Q: take 1 out" % [Catalog.NAMES[line.product], customer.in_bag(line.product), line.count]
	return "Nothing from the list here"

func show_payment(customer: Node3D) -> void:
	if basket_customer != customer: return
	payment_prop.show()
	payment_prop.material_override = _material(Color(0.42, 0.7, 0.4) if customer.payment_method == "Cash" else (Color(0.13, 0.16, 0.19) if customer.payment_method == "UPI" else Color(0.18, 0.47, 0.8)))
	phone_screen.visible = customer.payment_method == "UPI"
	card_chip.visible = customer.payment_method == "Card"
	_update_checkout_display()

func clear_basket(customer: Node3D) -> void:
	if basket_customer != customer: return
	basket_customer = null
	place_counter_bag(false)
	for bottle in checkout_items: bottle.hide()
	payment_prop.hide()
	checkout_display.text = "CHECKOUT\n%s0" % String.chr(8377)
	checkout_pc.get_node("Screen").material_override = _material(Color(0.07, 0.25, 0.28))
	screen_payment = false

func checkout_customer() -> Node3D:
	queue = queue.filter(func(customer): return is_instance_valid(customer) and not customer.is_queued_for_deletion())
	return queue[0] if not queue.is_empty() else null

func queue_position(customer: Node3D) -> Vector3:
	return fixture_transform("counter") * Vector3(-2.5 - max(0, queue.find(customer)) * 0.85, 0.1, 1.2)

func customer_entry_route(product := "bottle", rack_id := -1) -> Array[Vector3]:
	var points: Array[Vector3] = [Vector3(-3, 0.1, 3.3), Vector3(-3, 0.1, 1.65)]
	points.append_array(shop.business.racks.route(points[-1], rack_target(product, rack_id)))
	return points

func customer_exit_route() -> Array[Vector3]:
	var exit: Vector3 = get_parent().get_node("CustomerExitPoint").global_position
	if counter_at_home(): return [Vector3(-2.5, 0.1, 1.6), Vector3(-3, 0.1, 1.7), Vector3(-3, 0.1, 3.3), exit]
	var front: Vector3 = fixture_transform("counter") * Vector3(-2.5, 0.1, 1.6)
	var points: Array[Vector3] = [front]
	points.append_array(shop.business.racks.route(front, Store.ENTRY))
	points.append_array([Vector3(-3, 0.1, 3.3), exit])
	return points

func open_supplier() -> void:
	if player.shop_indoors and _near(pc.global_position):
		pc.get_node("ComputerTerminal").open()
	else:
		ui.show_feedback("Order at the shop PC.", true)

func delivery_box_target() -> int:
	var best := -2
	var alignment := 0.8
	for index in range(-1, shop.business.queued_boxes.size()):
		var crate: Node3D = delivery_box if index == -1 else extra_delivery_boxes[index]
		if not crate.visible or not _near(crate.global_position, 1.8): continue
		var direction: Vector3 = (crate.global_position - player.camera.global_position).normalized()
		var dot: float = (-player.camera.global_basis.z).dot(direction)
		if dot > alignment:
			alignment = dot
			best = index
	# Preserve the original nearby-E interaction for the first box.
	if best == -2 and shop.business.boxed_stock > 0 and _near(drop_point): return -1
	return best

func interaction_hint() -> String:
	if is_instance_valid(furnishing) and furnishing.active: return "Place %s" % furnishing.target_name().to_lower()
	var dungeon_hint: String = dungeon_world.hint() if is_instance_valid(dungeon_world) and dungeon_world.is_inside_tree() else ""
	if not dungeon_hint.is_empty(): return dungeon_hint
	var export_hint: String = export_world.hint() if is_instance_valid(export_world) else ""
	if not export_hint.is_empty(): return export_hint
	var order_hint := _counter_order_hint() if enabled else ""
	if not order_hint.is_empty(): return order_hint
	if shop.business.carried_stock == 0 and ground_box_target() >= 0: return "Pick up ground box"
	var warehouse = get_parent().get_node_or_null("Warehouse")
	if is_instance_valid(warehouse):
		var value: String = warehouse.hint()
		if not value.is_empty(): return value
	if not enabled:
		return ""
	if shop.business.carried_stock > 0:
		var amount: int = shop.business.carried_stock
		var product_name: String = Catalog.NAMES[shop.business.pending_product]
		var nearby: Dictionary = furnishing.near_any_rack() if is_instance_valid(furnishing) else {}
		if not nearby.is_empty() and not Store.holds(nearby, shop.business.pending_product, shop.business.racks.strict): return Store.place_hint(shop.business.pending_product)
		var can_place: bool = furnishing.near_rack(shop.business.pending_product) >= 0 if is_instance_valid(furnishing) else false
		var can_take: bool = furnishing.near_stocked_rack(shop.business.pending_product) >= 0 if is_instance_valid(furnishing) else false
		if can_place and can_take: return "E: place 1 %s   |   Q: take 1 back   (%d in box)" % [product_name, amount]
		if can_take: return "Q: take 1 %s back (%d in box)" % [product_name, amount]
		return "Place 1 %s (%d left)" % [Catalog.NAMES[shop.business.pending_product], amount] if (furnishing.near_rack(shop.business.pending_product) >= 0 if is_instance_valid(furnishing) else _near(rack_target(shop.business.pending_product))) else ("Return box (%d left)" % amount if _near(drop_point) else "Carrying: %d %s" % [amount, Catalog.NAMES[shop.business.pending_product]])
	var box_index := delivery_box_target()
	if box_index >= -1:
		var box: Dictionary = shop.business.queued_boxes[box_index] if box_index >= 0 else {"amount": shop.business.boxed_stock, "product": shop.business.pending_product}
		return "Pick up: %d %s" % [box.amount, Catalog.NAMES[box.product]]
	var customer = checkout_customer()
	if customer != null and player_at_counter():
		if customer.state == customer.State.SCANNING:
			return "Scan product %d/%d" % [customer.scanned_count + 1, customer.total_items()] if aimed_checkout_item(customer) >= 0 else "Aim at a product to scan"
		if customer.state == customer.State.NEGOTIATING: return "Customer wants a discount"
		if customer.state == customer.State.PAYING: return "Payment: %s" % customer.payment_method
	var employee := employee_target()
	if not employee.is_empty(): return "Talk to %s | %s" % [shop.business.staff.name_for(employee), "Cashier" if employee == "cashier" else "Stock assistant"]
	var shopper := shopper_target() if shop.business.carried_stock == 0 else null
	if shopper != null: return "Talk to %s" % shopper.customer_name.get_slice(" - ", 0)
	if player.shop_indoors and _near(pc.global_position, 1.0): return "Shop PC"
	if player.shop_indoors and player_at_counter(): return "Checkout PC"
	return ""

func try_interact() -> bool:
	if not enabled or player._menu_is_open():
		return false
	if is_instance_valid(dungeon_world) and dungeon_world.is_inside_tree() and dungeon_world.try_interact(): return true
	if is_instance_valid(export_world) and export_world.try_interact(): return true
	if _try_counter_order(): return true
	if shop.business.carried_stock == 0:
		var ground_index := ground_box_target()
		if ground_index >= 0:
			var success: bool = shop.business.pick_up_ground_box(ground_index)
			ui.show_feedback("Picked up ground box." if success else "Wait until the worker finishes, or check save status.", not success)
			return true
	if shop.business.carried_stock > 0:
		var rack_id: int = furnishing.near_rack(shop.business.pending_product) if is_instance_valid(furnishing) else -1
		if rack_id >= 0 or not is_instance_valid(furnishing) and _near(rack_target(shop.business.pending_product), 1.0):
			var product: String = shop.business.pending_product
			if shop.business.shelve_one(rack_id):
				var remaining: int = shop.business.carried_stock
				carried_box.play_place_animation(remaining == 0)
				animate_shelf_item(product, rack_id)
				play_sound("stock")
				ui.show_feedback("Box empty. %s stocked." % Catalog.NAMES[product] if remaining == 0 else "Shelved 1 %s. %d left in box." % [Catalog.NAMES[product], remaining])
			else: ui.show_feedback("Rack full. Use another rack with an empty row, or warehouse storage.", true)
			return true
		# At a rack that can never hold this product: say where it goes.
		var nearby: Dictionary = furnishing.near_any_rack() if is_instance_valid(furnishing) else {}
		if not nearby.is_empty() and not Store.holds(nearby, shop.business.pending_product, shop.business.racks.strict):
			ui.show_feedback(Store.place_hint(shop.business.pending_product), true)
			return true
		for id in Catalog.IDS:
			if id != shop.business.pending_product and (furnishing.near_rack(id) >= 0 if is_instance_valid(furnishing) else _near(rack_target(id), 1.0)):
				ui.show_feedback("No free row here for %s. Use a rack with an empty row." % Catalog.NAMES[shop.business.pending_product], true)
				return true
		if _near(drop_point):
			shop.business.drop_box()
			return true
	var box_index := delivery_box_target()
	if box_index >= -1:
		if shop.business.pick_up_box(false, box_index): ui.show_feedback("Picked up: %d %s" % [shop.business.carried_stock, Catalog.NAMES[shop.business.pending_product]])
		else: ui.show_feedback("Wait until Sunil finishes his box.", true)
		return true
	var customer = checkout_customer()
	if customer != null and player_at_counter():
		if customer.state == customer.State.SCANNING:
			if scan_aimed_checkout_item(customer):
				if customer.state == customer.State.NEGOTIATING: ui.bargain_menu.open_for(customer)
				elif customer.state == customer.State.PAYING: ui.checkout_menu.open_menu()
			return true
		if customer.state == customer.State.NEGOTIATING:
			ui.bargain_menu.open_for(customer)
			return true
		if customer.state == customer.State.PAYING:
			ui.checkout_menu.open_menu()
			return true
	if shop.business.carried_stock == 0:
		var employee := employee_target()
		if not employee.is_empty():
			ui.staff_dialog.open_for(employee)
			return true
		var shopper := shopper_target()
		if shopper != null:
			ui.customer_chat.open_for(shopper)
			return true
	if player.shop_indoors and _near(pc.global_position, 1.0):
		open_supplier()
		return true
	if player.shop_indoors and player_at_counter():
		ui.checkout_menu.open_menu()
		return true
	return false

## The shopper the crosshair is on while they shop or queue (not at the till,
## where E scans and takes payment), or null.
func shopper_target() -> Node3D:
	if not player.shop_indoors: return null
	var result: Node3D = null
	var best := 0.94
	var camera: Camera3D = player.camera
	for child in get_parent().get_children():
		if child.get("customer_name") == null or not child.visible or child.coop_mirror: continue
		if child.state not in [child.State.ARRIVING, child.State.TAKING, child.State.SHOPPING_MORE, child.State.TO_COUNTER, child.State.QUEUING] or child == checkout_customer(): continue
		if not _near(child.global_position, 2.2): continue
		var alignment := (-camera.global_basis.z).dot(camera.global_position.direction_to(child.global_position + Vector3(0, 1.1, 0)))
		if alignment > best:
			best = alignment
			result = child
	return result

func employee_target() -> String:
	if not player.shop_indoors: return ""
	var result := ""
	var best := 0.94
	var camera: Camera3D = player.camera
	for role in ["cashier", "stock"]:
		var actor: Node3D = shop.worker if role == "cashier" else stock_worker
		if not is_instance_valid(actor) or not actor.visible or not shop.business.staff.active(shop.business, role) or not _near(actor.global_position, 2.2): continue
		var direction := camera.global_position.direction_to(actor.global_position + Vector3(0, 1.5, 0))
		var alignment := (-camera.global_basis.z).dot(direction)
		if alignment > best:
			best = alignment
			result = role
	return result

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		if release_held_item(): get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if try_interact(): get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		if is_instance_valid(furnishing) and furnishing.move_key(): get_viewport().set_input_as_handled()
