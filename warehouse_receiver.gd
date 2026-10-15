extends Node3D

var route: Array[Vector3] = []
var route_index := 0
var collecting := false
var box: Node3D
var parked_box: Node3D
@onready var warehouse = get_parent()
@onready var business = warehouse.business
@onready var operations = warehouse.operations

func _ready() -> void:
	box = operations._crate(self, "ReceiverBox")
	box.position = Vector3(0, 0.72, -0.5)
	box.scale = Vector3.ONE * 0.75
	$CharacterVisual.carry_target = box
	parked_box = operations._crate(warehouse, "ReceiverParkedBox")
	parked_box.scale = Vector3.ONE * 0.75
	parked_box.position = warehouse.office_idle + Vector3(0, 0.3, 0)
	business.changed.connect(_sync)
	business.clock_changed.connect(_sync)
	_sync()

func _sync() -> void:
	var record: Dictionary = business.staff.records.warehouse
	visible = business.staff.active(business, "warehouse") and (business.staff.on_shift(business, "warehouse") or record.state in ["leave", "pay"])
	var carrying: bool = not business.logistics.warehouse_carry.is_empty()
	box.visible = carrying and visible
	parked_box.visible = carrying and (not visible or not business.warehouse_worker_on_shift())
	box.visible = carrying and visible and not parked_box.visible
	if carrying:
		var text := "%d %s" % [business.logistics.warehouse_carry.amount, warehouse.Catalog.NAMES[business.logistics.warehouse_carry.product].to_upper()]
		box.get_node("BoxLabel").text = text
		parked_box.get_node("BoxLabel").text = text
	if record.quit_day > 0 or not visible: route.clear()
	if carrying and route.is_empty() and business.warehouse_worker_on_shift(): _storage_route()

func _storage_route() -> void:
	collecting = false
	var id: int = int(business.logistics.warehouse_carry.slot) / 16
	if global_position.z < warehouse.FRONT:
		route = [Vector3(-3, 0.1, 11.2), warehouse.entry]
		route.append_array(warehouse.walk_route(warehouse.entry, warehouse.service_point(id)))
	else: route = warehouse.walk_route(global_position, warehouse.service_point(id))
	route_index = 0

func _collect_route() -> void:
	if business.queued_boxes.is_empty() and (business.boxed_stock == 0 or business.stock_collection_assigned): return
	var free := false
	for id in range(16):
		if business.logistics.free_slot(id) >= 0: free = true; break
	if not free: return
	collecting = true
	if global_position.z >= warehouse.FRONT: route = warehouse.walk_route(global_position, warehouse.entry)
	else: route = []
	var point: Vector3 = operations.product_delivery_point(1 if not business.queued_boxes.is_empty() else 0)
	point.y = 0.1
	route.append_array([Vector3(-3, 0.1, 11.2), Vector3(point.x, 0.1, 11.2), point + Vector3(0, 0, -0.7)])
	route_index = 0

func _physics_process(delta: float) -> void:
	if not business.warehouse_worker_on_shift(): return
	if route.is_empty():
		if not business.logistics.warehouse_carry.is_empty(): _storage_route()
		else: _collect_route()
	if route.is_empty(): return
	var remaining := maxf(0, delta) * 1.8
	while route_index < route.size():
		var target := route[route_index]
		var distance := global_position.distance_to(target)
		if distance > 0.01: look_at(target, Vector3.UP)
		global_position = global_position.move_toward(target, remaining)
		if distance > remaining: return
		remaining = maxf(0, remaining - distance)
		route_index += 1
	route.clear()
	if collecting:
		if business.warehouse_pick_up_box(): _storage_route()
		else: collecting = false
	elif not business.logistics.warehouse_carry.is_empty():
		if business.warehouse_store_carried():
			$CharacterVisual.play_work_animation()
			route = warehouse.walk_route(global_position, warehouse.office_idle)
			route_index = 0
