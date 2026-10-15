extends Node3D

var route: Array[Vector3] = []
var route_index := 0
var collecting := false
var target_rack := -1
var fetch_slot := -1
var carrying_box: Node3D
@onready var operations = get_tree().current_scene.get_node("ShopOperations")
@onready var business = get_tree().current_scene.get_node("Shop/ShopArea").business
@onready var warehouse = get_tree().current_scene.get_node_or_null("Warehouse")

func _ready() -> void:
	carrying_box = operations._crate(self, "WorkerBox")
	carrying_box.position = Vector3(0, 0.72, -0.5)
	carrying_box.scale = Vector3.ONE * 0.75
	$CharacterVisual.carry_target = carrying_box
	business.changed.connect(_sync)
	business.clock_changed.connect(_sync)
	_sync()

func _sync() -> void:
	if collecting and not business.stock_collection_assigned and business.worker_carried_stock == 0:
		route.clear()
		collecting = false
	visible = business.stock_worker_on_shift() or business.worker_carried_stock > 0 or not route.is_empty()
	if business.staff.records.stock.state in ["leave", "pay"]: visible = true
	if business.staff.records.stock.quit_day > 0 or business.staff.records.stock.state == "done" and not business.staff.on_shift(business, "stock"): route.clear()
	carrying_box.visible = business.worker_carried_stock > 0
	carrying_box.get_node("BoxLabel").text = "%d %s" % [business.worker_carried_stock, operations.Catalog.NAMES[business.pending_product].to_upper()]
	if business.worker_carried_stock > 0 and route.is_empty(): _return_to_rack()

func _inside_warehouse() -> bool:
	return is_instance_valid(warehouse) and global_position.z >= warehouse.FRONT - 0.2

# Leg from the shop floor to the road outside (empty if already outside).
func _shop_exit() -> Array[Vector3]:
	var path: Array[Vector3] = []
	if global_position.z > 2.1: return path
	path = business.racks.route(global_position, business.RackStore.ENTRY)
	if path.is_empty(): return path
	path.append_array([Vector3(-3, 0.1, 3.3), Vector3(4, 0.1, 3.9)])
	return path

func assign_delivery() -> bool:
	if not business.stock_worker_on_shift() or business.boxed_stock == 0 or not route.is_empty(): return false
	collecting = true
	if _inside_warehouse():
		route = warehouse.walk_route(global_position, warehouse.entry)
		route.append_array([Vector3(-3, 0.1, 11.2), operations.drop_point])
	elif global_position.z > 9.65:
		route = [operations.drop_point]
	elif global_position.z > 4.35:
		route = [Vector3(4, 0.1, 10.7), operations.drop_point]
	elif global_position.z > 2.1:
		route = [Vector3(4, 0.1, 3.9), Vector3(4, 0.1, 10.7), operations.drop_point]
	else:
		route = business.racks.route(global_position, business.RackStore.ENTRY)
		if route.is_empty():
			collecting = false
			return false
		route.append_array([Vector3(-3, 0.1, 3.3), Vector3(4, 0.1, 3.9), Vector3(4, 0.1, 10.7), operations.drop_point])
	route_index = 0
	if not business.assign_stock_collection():
		route.clear()
		collecting = false
		return false
	return true

## With automatic collection on, Sunil also restocks low products from warehouse storage.
func fetch_from_storage() -> bool:
	if not is_instance_valid(warehouse) or not route.is_empty() or not business.stock_worker_on_shift(): return false
	var slot: int = business.storage_restock_slot()
	if slot < 0: return false
	var path: Array[Vector3] = []
	if not _inside_warehouse():
		path = _shop_exit()
		if path.is_empty() and global_position.z <= 2.1: return false
		if global_position.z <= 9.65: path.append(Vector3(4, 0.1, 10.7))
		path.append_array([Vector3(-3, 0.1, 11.2), warehouse.entry])
		path.append_array(warehouse.walk_route(warehouse.entry, warehouse.service_point(slot / 16)))
	else:
		path = warehouse.walk_route(global_position, warehouse.service_point(slot / 16))
	route = path
	route_index = 0
	fetch_slot = slot
	return true

func _return_to_rack() -> void:
	collecting = false
	target_rack = business.racks.restock_rack(business.pending_product)
	if target_rack < 0:
		route.clear()
		return
	var destination: Vector3 = business.RackStore.approach(business.racks.find(target_rack))
	if global_position.z > 2.6:
		route = []
		if _inside_warehouse():
			route.append_array(warehouse.walk_route(global_position, warehouse.entry))
			route.append(Vector3(-3, 0.1, 11.2))
		if global_position.z > 9.65: route.append_array([Vector3(4, 0.1, 10.7), Vector3(4, 0.1, 3.9)])
		route.append_array([Vector3(-3, 0.1, 3.3), business.RackStore.ENTRY])
		route.append_array(business.racks.route(business.RackStore.ENTRY, destination))
	else:
		route = business.racks.route(global_position, destination)
	route_index = 0

func _physics_process(delta: float) -> void:
	if route.is_empty() and business.worker_carried_stock > 0 and business.stock_worker_on_shift(): _return_to_rack()
	if route.is_empty() and (business.stock_collection_assigned or business.assistant_auto_collect) and business.stock_worker_on_shift() and business.boxed_stock > 0: assign_delivery()
	if route.is_empty() and business.assistant_auto_collect and business.worker_carried_stock == 0: fetch_from_storage()
	if route.is_empty() or not business.stock_worker_on_shift(): return
	var remaining := maxf(0, delta) * 1.8
	while route_index < route.size():
		var target := route[route_index]
		var distance := global_position.distance_to(target)
		if distance > 0.0001: look_at(target, Vector3.UP)
		global_position = global_position.move_toward(target, remaining)
		if distance > remaining: return
		remaining = maxf(0, remaining - distance)
		route_index += 1
	route.clear()
	if fetch_slot >= 0:
		var slot := fetch_slot
		fetch_slot = -1
		if business.worker_retrieve_stored_box(slot):
			$CharacterVisual.play_work_animation()
			_return_to_rack()
		elif business.worker_carried_stock == 0 and not fetch_from_storage():
			_go_back_to_shop()
	elif collecting:
		if business.pick_up_box(true): _return_to_rack()
		else: collecting = false
	elif business.worker_carried_stock > 0:
		if business.shelve_box(true, target_rack): $CharacterVisual.play_work_animation()
		if business.worker_carried_stock > 0: _return_to_rack()
		else:
			route = business.racks.route(global_position, Vector3(-4.6, 0.1, -1.8))
			route_index = 0

# Box was taken by someone else: walk back to the shop's idle spot.
func _go_back_to_shop() -> void:
	route = []
	if _inside_warehouse():
		route.append_array(warehouse.walk_route(global_position, warehouse.entry))
		route.append(Vector3(-3, 0.1, 11.2))
	if global_position.z > 2.6:
		route.append_array([Vector3(4, 0.1, 10.7), Vector3(4, 0.1, 3.9), Vector3(-3, 0.1, 3.3), business.RackStore.ENTRY])
		route.append_array(business.racks.route(business.RackStore.ENTRY, Vector3(-4.6, 0.1, -1.8)))
	route_index = 0
