extends Node3D

const CUSTOMER_SCENE := preload("res://customer.tscn")
const NORMAL_SPAWN_INTERVAL := 10.0
const MARKETING_SPAWN_INTERVAL := 8.5

var active_customer: Node3D
var customers: Array[Node3D] = []
var physical_shop := false

@onready var spawn_point: Marker3D = get_node("../CustomerSpawnPoint")
@onready var shop_area: Area3D = get_node("../Shop/ShopArea")
@onready var purchase_point: Marker3D = get_node("../CustomerPurchasePoint")
@onready var exit_point: Marker3D = get_node("../CustomerExitPoint")

func _ready() -> void:
	active_customer = get_node("../Customer")
	customers.append(active_customer)
	active_customer.tree_exited.connect(_on_customer_departed.bind(active_customer))
	physical_shop = get_node("../ShopOperations").enabled
	$SpawnTimer.one_shot = not physical_shop
	$SpawnTimer.stop()
	$SpawnTimer.timeout.connect(_on_spawn_timer_timeout)
	shop_area.business.changed.connect(_refresh_spawn_interval)
	_refresh_spawn_interval()
	if physical_shop: $SpawnTimer.start()

func set_marketing_active(active: bool) -> void:
	var interval: float = shop_area.business.customer_spawn_interval(active)
	if is_equal_approx($SpawnTimer.wait_time, interval):
		return
	$SpawnTimer.wait_time = interval
	if physical_shop or not is_instance_valid(active_customer):
		$SpawnTimer.start()

func _refresh_spawn_interval() -> void:
	set_marketing_active(shop_area.marketing_active)

func _on_customer_departed(customer: Node3D) -> void:
	customers.erase(customer)
	active_customer = customers[0] if not customers.is_empty() else null
	if is_inside_tree() and not physical_shop:
		$SpawnTimer.start()

func _on_spawn_timer_timeout() -> void:
	if not physical_shop: $SpawnTimer.stop()
	if not shop_area.business.shop_is_open():
		$SpawnTimer.start()
		return
	# Up to 3 shoppers at a time; people already walking away down the street don't
	# count, but the street never holds more than 8 customers in all.
	var shopping := customers.filter(func(customer): return is_instance_valid(customer) and customer.state != customer.State.LEAVING).size()
	if (shopping >= 3 or customers.size() >= 8 if physical_shop else is_instance_valid(active_customer)):
		return

	var customer = CUSTOMER_SCENE.instantiate()
	customer.name = "Customer"
	customer.spawn_delay = 0.0
	customer.shop_area_path = shop_area.get_path()
	customer.purchase_point_path = purchase_point.get_path()
	customer.exit_point_path = exit_point.get_path()
	active_customer = customer
	customers.append(customer)
	customer.tree_exited.connect(_on_customer_departed.bind(customer))
	get_parent().add_child(customer)
	customer.global_position = spawn_point.global_position
