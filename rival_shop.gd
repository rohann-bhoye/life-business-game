extends Node3D

# Sharma General Store (rival shop, open from business.RIVAL_OPEN_DAY): a paved path
# and forecourt from the south pavement, a produce display, Mr. Sharma at the door
# and customers who walk in from the street, shop for a while and walk away. A sale
# board by the path shows the price-war offer of the day (business.rival_sale()).
const DOOR := Vector3(25.0, 0.1, 14.7)
const PATH_START := Vector3(25.0, 0.1, 11.0)
const SPEED := 1.25
const MODELS := ["aunty", "uncle"]
const Catalog := preload("res://product_catalog.gd")

var business
var town: Node3D
var keeper: Node3D
var helper: Node3D
var sale_board: Node3D
var sale_label: Label3D
var shoppers: Array[Node3D] = []
var states: Array = []

func build(neighbourhood: Node3D, business_ref) -> void:
	name = "RivalShopLife"
	town = neighbourhood
	business = business_ref
	var store: Node3D = town.get_node("RivalStore")
	var paving := Color(0.7, 0.71, 0.68)
	town._box("RivalPath", store, Vector3(2.2, 0.016, 3.9), Vector3(0, 0.008, -1.95), paving)
	town._box("RivalForecourt", store, Vector3(5.0, 0.018, 1.6), Vector3(0, 0.01, -0.6), paving)
	town._box("RivalDisplay", store, Vector3(1.6, 0.75, 0.7), Vector3(-1.6, 0.4, -0.9), Color(0.45, 0.3, 0.18), true)
	var produce := ["tomato", "apple", "carrot", "cabbage", "corn"]
	for index in range(produce.size()):
		var item: Node3D = preload("res://produce_assets.gd").attach(store, produce[index], Vector3(0.24, 0.24, 0.24), "RivalProduce%d" % index)
		item.position = Vector3(-2.2 + index * 0.3, 0.78, -0.9)
	# Price war: a chalk board by the path shows today's sale.
	sale_board = Node3D.new()
	sale_board.name = "SaleBoard"
	sale_board.position = Vector3(-2.2, 0, -3.0)
	store.add_child(sale_board)
	town._box("Board", sale_board, Vector3(1.3, 0.95, 0.06), Vector3(0, 1.05, 0), Color(0.1, 0.16, 0.12))
	town._box("Frame", sale_board, Vector3(1.4, 0.08, 0.08), Vector3(0, 1.55, 0), Color(0.55, 0.36, 0.2))
	for x in [-0.55, 0.55]: town._box("Leg%s" % x, sale_board, Vector3(0.06, 0.6, 0.06), Vector3(x, 0.3, 0), Color(0.55, 0.36, 0.2))
	sale_label = Label3D.new()
	sale_label.name = "SaleText"
	sale_label.position = Vector3(0, 1.05, -0.04)
	sale_label.rotation.y = PI
	sale_label.font_size = 30
	sale_label.pixel_size = 0.0042
	sale_label.outline_size = 0
	sale_label.modulate = Color(1, 0.95, 0.6)
	sale_board.add_child(sale_label)
	# Sharma's people wear the store's red uniform.
	keeper = _person("MrSharma", "rival-m", store.to_global(Vector3(1.0, 0, -0.5)), 0.0)
	helper = _person("SharmaHelper", "rival-f", store.to_global(Vector3(-2.75, 0, -0.9)), 0.0)
	var tag := Label3D.new()
	tag.text = "Mr. Sharma"
	tag.position = Vector3(0, 1.85, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.004
	keeper.add_child(tag)
	for index in range(MODELS.size()):
		var shopper := _person("RivalShopper%d" % index, MODELS[index], Vector3(15.0 + index * 22.0, 0.1, 10.9), 0.0)
		shoppers.append(shopper)
		# phase: 0 walk to path start, 1 walk to door, 2 inside, 3 back to path, 4 walk away
		states.append({"phase": 0, "timer": float(index) * 6.0, "away": Vector3(5.0 if index == 0 else 30.0, 0.1, 10.9)})
	_update_visibility()
	business.clock_changed.connect(_update_visibility)

func _person(node_name: String, model: String, position: Vector3, yaw: float) -> Node3D:
	var person := Node3D.new()
	person.name = node_name
	var visual := Node3D.new()
	visual.name = "CharacterVisual"
	visual.set_script(preload("res://character_visual.gd"))
	visual.model = model
	person.add_child(visual)
	add_child(person)
	person.global_position = position
	person.rotation.y = yaw
	return person

func _update_visibility() -> void:
	var open: bool = business.rival_open() and business.shop_is_open()
	var sale: Dictionary = business.rival_sale()
	sale_board.visible = open and not sale.is_empty()
	if not sale.is_empty():
		sale_label.text = "TODAY'S SALE\n%s\n%s%d  (was %s%d)" % [Catalog.NAMES[sale.id], String.chr(8377), sale.price, String.chr(8377), business.rival_price(sale.id)]
	keeper.visible = open
	helper.visible = open
	for shopper in shoppers: shopper.visible = open and shopper.visible
	set_physics_process(open)

func _walk(person: Node3D, target: Vector3, delta: float) -> bool:
	var offset := target - person.global_position
	offset.y = 0
	if offset.length() < 0.05: return true
	person.look_at(person.global_position + offset, Vector3.UP)
	person.global_position = person.global_position.move_toward(target, SPEED * delta)
	return false

func _physics_process(delta: float) -> void:
	for index in range(shoppers.size()):
		var person := shoppers[index]
		var state: Dictionary = states[index]
		if state.timer > 0.0:
			state.timer -= delta
			continue
		match state.phase:
			0:
				person.visible = true
				if _walk(person, PATH_START, delta): state.phase = 1
			1:
				if _walk(person, DOOR, delta):
					person.visible = false
					state.phase = 2
					state.timer = 6.0
			2:
				person.visible = true
				state.phase = 3
			3:
				if _walk(person, PATH_START, delta): state.phase = 4
			4:
				if _walk(person, state.away, delta):
					person.visible = false
					state.phase = 0
					state.timer = 8.0 + index * 5.0
