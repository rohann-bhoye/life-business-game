extends Node3D

const Store = preload("res://rack_store.gd")
const Catalog = preload("res://product_catalog.gd")
var models: Dictionary = {}
var active := false
var selected_id := -1
var product := "bottle"
var turn := 2
var candidate: Dictionary = {}
var preview: Node3D
var preview_material: StandardMaterial3D
var last_error := ""
@onready var world = get_parent()
@onready var operations = world.get_node("ShopOperations")
@onready var business = world.get_node("Shop/ShopArea").business
@onready var player = world.get_node("Player")
@onready var ui = world.get_node("Ui")

func _ready() -> void:
	if not operations.enabled: return
	operations.furnishing = self
	models[0] = {"node": operations.rack, "items": operations.rack_bottles, "label": operations.rack_label}
	for id in [1, 2]:
		var sku: String = Catalog.IDS[id]
		models[id] = {"node": operations.product_racks[sku], "items": operations.product_items[sku], "label": operations.product_labels[sku]}
	preview = Node3D.new()
	preview.name = "PlacementPreview"
	add_child(preview)
	preview_material = StandardMaterial3D.new()
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for level in range(3): _preview_box(Vector3(0.65, 0.06, 2.1), Vector3(0, 0.22 + level * 0.55, 0))
	for z in [-1.0, 1.0]: _preview_box(Vector3(0.55, 1.9, 0.07), Vector3(0, 0.95, z))
	_preview_box(Vector3(0.3, 0.025, 0.3), Vector3(1, 0.02, 0))
	preview.hide()
	business.changed.connect(_sync)
	_sync()
	call_deferred("refresh_stock")

func _preview_box(size: Vector3, position: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position
	mesh.material_override = preview_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.add_child(mesh)

func _sync() -> void:
	for record in business.racks.records:
		if not models.has(record.id):
			var model: Dictionary
			if record.get("display", "shelf") == "produce":
				model = operations.build_produce_table(world.get_node("Neighbourhood"), "ProduceTable%d" % record.id, Store.point(record))
			else:
				model = operations.build_stock_rack(world.get_node("Neighbourhood"), "PurchasedRack%d" % record.id, record.product, Store.point(record))
				model.price = world.get_node("ShopPresentation").decorate_rack(model.node, record.product)
			models[record.id] = model
		var model: Dictionary = models[record.id]
		model.node.position = Store.point(record)
		model.node.rotation.y = record.turn * PI / 2
		if model.has("price"): model.price.text = "%s%d" % [String.chr(8377), business.product_price(record.product)]
	refresh_stock()

func stock_rack(sku: String) -> int:
	var destination: int = business.racks.restock_rack(sku)
	if destination >= 0: return destination
	for record in business.racks.records:
		if record.product == sku and record.get("restock", record.id < 3): return record.id
	return Catalog.IDS.find(sku)

func available(id: int, sku := "") -> int:
	var record: Dictionary = business.racks.find(id)
	if record.is_empty(): return 0
	if sku == "": sku = record.product
	var count := Store.count_product(record, sku)
	for child in world.get_children():
		if child.get("has_product") == true and child.get("product_id") == sku and not child.get("deal_sold"):
			var source: int = child.rack_id if child.rack_id >= 0 else Catalog.IDS.find(child.product_id)
			if source == id: count -= child.basket_count
	return maxi(0, count)

func choose_rack(sku: String) -> int:
	for record in business.racks.records:
		if available(record.id, sku) > 0: return record.id
	return stock_rack(sku)

func near_rack(sku: String) -> int:
	var distance := 1.0
	var selected := -1
	for record in business.racks.records:
		if not Store.supports(record, sku): continue
		var offset: Vector3 = player.global_position - Store.approach(record)
		offset.y = 0
		if offset.length() <= distance:
			distance = offset.length()
			selected = record.id
	return selected

func refresh_stock() -> void:
	for record in business.racks.records:
		if not models.has(record.id): continue
		var model: Dictionary = models[record.id]
		Store.migrate_record(record)
		if not model.has("skus"): model.skus = []; model.skus.resize(model.items.size()); model.skus.fill("tomato" if model.get("produce", false) else record.product)
		var reservations := {}
		for sku in Catalog.IDS: reservations[sku] = Store.count_product(record, sku) - available(record.id, sku)
		var types: Array = []
		var visible_total := 0
		for level in range(Store.slot_count(record)):
			var slot: Dictionary = record.slots[level]
			var count := int(slot.count)
			if slot.product != "":
				if slot.product not in types and count > 0: types.append(slot.product)
				var reserved := mini(count, int(reservations[slot.product]))
				count -= reserved
				reservations[slot.product] -= reserved
			visible_total += count
			for offset in range(10):
				var index := level * 10 + offset
				if slot.product != "" and model.skus[index] != slot.product:
					var previous: Node3D = model.items[index]
					var item: Node3D = operations.make_product(model.node, "ShelfItem%d" % index, previous.position, slot.product)
					item.scale = previous.scale
					previous.hide()
					previous.queue_free()
					model.items[index] = item
					model.skus[index] = slot.product
				model.items[index].visible = offset < count
			_update_slot_label(model.node, level, slot, record)
		var category: Label3D = model.node.get_node_or_null("CategoryName")
		if category != null: category.text = "MIXED PRODUCTS" if types.size() > 1 else (Catalog.NAMES[types[0]].to_upper() if not types.is_empty() else "OPEN SHELF - ANY PRODUCT")
		model.label.text = "%s: %d / %d" % ["MIXED" if types.size() > 1 else Catalog.NAMES[types[0]].to_upper() if not types.is_empty() else "OPEN SHELF", visible_total, Store.slot_count(record) * 10]
		if record.legacy_overflow > 0: model.label.text += " | surplus %d" % record.legacy_overflow

func _update_slot_label(node: Node3D, level: int, slot: Dictionary, record: Dictionary) -> void:
	if record.get("display", "shelf") == "produce":
		var basket_label: Label3D = node.get_node_or_null("BasketLabel%d" % level)
		if basket_label == null:
			basket_label = operations._sign(node, "BasketLabel%d" % level, "", operations.basket_position(level) + Vector3(0.105, 0.05, 0))
			basket_label.rotation.y = PI / 2
			basket_label.font_size = 16
			basket_label.pixel_size = 0.0012
		basket_label.text = "EMPTY\nany product" if slot.product == "" or int(slot.count) == 0 else "%s\n%s%d | %d/10" % [Catalog.NAMES[slot.product], String.chr(8377), business.product_price(slot.product), slot.count]
		return
	if not node.has_node("CategoryName"): return
	var name := "ShelfSlotLabel%d" % level
	var label: Label3D = node.get_node_or_null(name)
	if label == null:
		label = world.get_node("ShopPresentation")._label(node, name, "", Vector3(0.41, 0.2 + level * 0.55, 0), 24, 0.002, Color(0.08, 0.13, 0.15))
		label.rotation.y = PI / 2
	label.text = "Empty row | any product" if slot.product == "" or int(slot.count) == 0 else "%s | %s%d | %d / 10" % [Catalog.NAMES[slot.product], String.chr(8377), business.product_price(slot.product), slot.count]
	label.visible = level > 0 or int(slot.count) == 0 or slot.product != business.racks.find(_model_id(node)).product
	if level == 0:
		node.get_node("ShelfPrice").visible = not label.visible
		node.get_node("PriceCard").visible = not label.visible

func _model_id(node: Node3D) -> int:
	for id in models:
		if models[id].node == node: return id
	return -1

func busy(id: int) -> bool:
	var record: Dictionary = business.racks.find(id)
	if record.is_empty(): return false
	for child in world.get_children():
		if child.get("rack_id") == id and child.get("state") in [1, 5]: return true
	var worker = operations.stock_worker
	return is_instance_valid(worker) and not worker.route.is_empty()

## Packs an empty bought rack into a warehouse package (PC Racks tab).
func pack(id: int) -> bool:
	for record in business.racks.records:
		if int(record.id) >= id and busy(int(record.id)):
			ui.show_feedback("Rack is in use. Wait until stocking and browsing finish.", true)
			return false
	if active or not business.pack_rack(id):
		ui.show_feedback("Only an empty rack you bought can be packed.", true)
		return false
	# Record ids above the packed rack shifted down by one; keep models matched.
	models[id].node.queue_free()
	var shifted := {}
	for key in models:
		if key < id: shifted[key] = models[key]
		elif key > id: shifted[key - 1] = models[key]
	models = shifted
	_sync()
	ui.show_feedback("Rack packed. Its package is waiting in the warehouse.")
	return true

func begin_buy(sku: String) -> bool:
	if sku not in business.logistics.rack_delivered or business.racks.records.size() >= Store.MAX_RACKS: return false
	return _begin(sku, -1, 2)

func begin_move(id: int) -> bool:
	var record: Dictionary = business.racks.find(id)
	if record.is_empty() or busy(id):
		ui.show_feedback("Rack is in use. Wait until stocking and browsing finish.", true)
		return false
	return _begin(record.product, id, int(record.turn))

func _begin(sku: String, id: int, orientation: int) -> bool:
	if active or business.carried_stock > 0: return false
	for child in preview.get_children():
		preview.remove_child(child)
		child.queue_free()
	var produce: bool = business.racks.find(id).get("display", "shelf") == "produce" if id >= 0 else sku == "tomato"
	if produce:
		_preview_box(Vector3(0.65, 0.65, 2.1), Vector3(0, 0.325, 0))
		for slot in range(12): _preview_box(Vector3(0.2, 0.1, 0.49), operations.basket_position(slot))
	else:
		for level in range(3): _preview_box(Vector3(0.65, 0.06, 2.1), Vector3(0, 0.22 + level * 0.55, 0))
		for z in [-1.0, 1.0]: _preview_box(Vector3(0.55, 1.9, 0.07), Vector3(0, 0.95, z))
	_preview_box(Vector3(0.3, 0.025, 0.3), Vector3(1, 0.02, 0))
	product = sku
	selected_id = id
	turn = orientation
	active = true
	preview.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return true

func cancel() -> void:
	active = false
	preview.hide()
	candidate.clear()
	ui.show_feedback("Placement cancelled.")

func _actor_error(record: Dictionary) -> String:
	var area := Store.footprint(record).grow(0.3)
	var actors: Array = [player, operations.stock_worker, world.get_node("Worker")]
	for child in world.get_children():
		if child.get("product_id") != null: actors.append(child)
	for actor in actors:
		if not is_instance_valid(actor) or not actor.visible: continue
		if area.has_point(Vector2(actor.global_position.x, actor.global_position.z)): return "Someone is standing there."
		var route = actor.get("route")
		if route == null: continue
		var index: int = actor.route_index
		for step in range(index, route.size()):
			if area.has_point(Vector2(route[step].x, route[step].z)): return "Someone is walking through that spot."
	return ""

func confirm() -> bool:
	if not active or candidate.is_empty(): return false
	var error: String = business.racks.placement_error(candidate)
	if error.is_empty(): error = _actor_error(candidate)
	if selected_id >= 0 and busy(selected_id): error = "Rack is in use."
	if not error.is_empty():
		ui.show_feedback(error, true)
		return false
	if not business.place_rack(product, Vector2(candidate.x, candidate.z), turn, selected_id, selected_id < 0):
		ui.show_feedback("Could not place rack. Check package availability and save status.", true)
		return false
	active = false
	preview.hide()
	ui.show_feedback("Rack placed." if selected_id < 0 else "Rack moved.")
	return true

func _process(_delta: float) -> void:
	if not active: return
	var camera: Camera3D = player.camera
	var centre := get_viewport().get_visible_rect().size / 2
	var origin := camera.project_ray_origin(centre)
	var direction := camera.project_ray_normal(centre)
	var point = Plane(Vector3.UP, 0.1).intersects_ray(origin, direction)
	if point == null or point.distance_to(player.global_position) > 4.5:
		point = player.global_position + Vector3(direction.x, 0, direction.z).normalized() * 3
	candidate = {"id": business.racks.records.size() if selected_id < 0 else selected_id, "product": product, "x": snappedf(point.x, 0.25), "z": snappedf(point.z, 0.25), "turn": turn, "amount": 0}
	preview.position = Store.point(candidate)
	preview.rotation.y = turn * PI / 2
	last_error = business.racks.placement_error(candidate)
	if last_error.is_empty(): last_error = _actor_error(candidate)
	preview_material.albedo_color = Color(0.1, 0.9, 0.5, 0.5) if last_error.is_empty() else Color(1, 0.2, 0.15, 0.5)

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE: cancel()
		KEY_R: turn = (turn + 1) % 4
		KEY_E, KEY_ENTER: confirm()
		_: return
	get_viewport().set_input_as_handled()
