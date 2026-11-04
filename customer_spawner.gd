extends Node3D

# Sends shoppers to Apna Mart. How often comes from the business (customer_gap_minutes:
# the town's popularity, rating, prices, Sharma, rain, marketing and the hour, with a morning
# and an evening rush), counted in game minutes so every Day length setting gets the same
# number of shoppers. Each gap gets some chance, so people never arrive like clockwork.
const CUSTOMER_SCENE := preload("res://customer.tscn")
## Spread of each gap around the average (0.55x .. 1.45x).
const GAP_SPREAD := Vector2(0.55, 1.45)
## While the shop is shut it looks again this often (real seconds).
const CLOSED_CHECK := 3.0

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
	$SpawnTimer.one_shot = true
	$SpawnTimer.stop()
	$SpawnTimer.timeout.connect(_on_spawn_timer_timeout)
	shop_area.business.changed.connect(_refresh_spawn_interval)
	if physical_shop: _schedule()

## Real seconds between shoppers at this hour, on average.
func average_gap_seconds(marketing := false) -> float:
	var clock := get_node_or_null("../DayClock")
	var speed: float = clock.minutes_per_second if clock != null and "minutes_per_second" in clock else 1.0
	return shop_area.business.customer_gap_minutes(marketing) / maxf(0.1, speed)

## Waits for the next shopper: the average gap with some chance, or `seconds` when given.
func _schedule(seconds := -1.0) -> void:
	if seconds < 0.0: seconds = average_gap_seconds(shop_area.marketing_active) * randf_range(GAP_SPREAD.x, GAP_SPREAD.y)
	$SpawnTimer.start(maxf(1.0, seconds))

## A campaign (or the end of one) changes the pace from the next shopper on; a long wait
## already running is cut short so the change shows at once.
func set_marketing_active(active: bool) -> void:
	if not physical_shop: return
	if $SpawnTimer.is_stopped() or $SpawnTimer.time_left > average_gap_seconds(active) * GAP_SPREAD.y: _schedule()

func _refresh_spawn_interval() -> void:
	set_marketing_active(shop_area.marketing_active)

func _on_customer_departed(customer: Node3D) -> void:
	customers.erase(customer)
	active_customer = customers[0] if not customers.is_empty() else null
	if is_inside_tree() and not physical_shop: _schedule()

func _on_spawn_timer_timeout() -> void:
	if not shop_area.business.shop_is_open():
		_schedule(CLOSED_CHECK)
		return
	if physical_shop: _schedule()
	# Up to 3 shoppers at a time (more in a shop with wings); people already walking away
	# down the street don't count, but the street never holds more than 8 customers (more
	# with wings). Someone who finds the shop full walks on (no queue builds up out of sight).
	var business = shop_area.business
	var wing: int = clampi(business.shop_wing, 0, business.WING_SHOPPERS.size() - 1)
	var shopping := customers.filter(func(customer): return is_instance_valid(customer) and customer.state != customer.State.LEAVING).size()
	if (shopping >= business.WING_SHOPPERS[wing] or customers.size() >= 8 + wing * 3 if physical_shop else is_instance_valid(active_customer)):
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
