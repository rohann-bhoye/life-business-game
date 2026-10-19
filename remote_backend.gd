extends "res://business_backend.gd"

# The shop in a friend's game during co-op; the host's game keeps the real shop.
# A player action runs here at once, so menus answer straight away, and is also
# sent to the host (coop_world.gd), whose result comes back in its next snapshot
# through restore(). Each friend carries their own box: the host runs their box
# actions with business_backend.gd coop_begin/coop_end. Sleeping waits for a later
# co-op phase. A friend's game never saves: progress lives in the host's save slot.
# Mirrors the player actions in business_backend.gd: give a new action an override here.
signal coop_blocked(message: String)
const SLEEP_HOST := "In co-op the host sleeps to skip the night."
## Set by coop_world.gd: forward.call(method, args) sends an action to the host.
var forward := Callable()
## Actions call each other inside; only the outermost one goes to the host.
var depth := 0

func save_progress() -> bool:
	save_status = "Save: Host saves co-op progress"
	return true

func _send(method: String, args: Array) -> void:
	if depth == 0 and forward.is_valid(): forward.call(method, args)
	depth += 1

func take_loan() -> bool:
	_send("take_loan", [])
	var result := super()
	depth -= 1
	return result

func repay_loan() -> bool:
	_send("repay_loan", [])
	var result := super()
	depth -= 1
	return result

func plant_crop(index: int, crop := "") -> bool:
	_send("plant_crop", [index, crop])
	var result := super(index, crop)
	depth -= 1
	return result

func water_crop(index: int) -> bool:
	_send("water_crop", [index])
	var result := super(index)
	depth -= 1
	return result

func harvest_crop(index: int) -> bool:
	_send("harvest_crop", [index])
	var result := super(index)
	depth -= 1
	return result

func buy_seeds(quantity := 1, crop := "") -> bool:
	_send("buy_seeds", [quantity, crop])
	var result := super(quantity, crop)
	depth -= 1
	return result

func hire_farm_worker() -> bool:
	_send("hire_farm_worker", [])
	var result := super()
	depth -= 1
	return result

func set_farm_crop(crop: String) -> bool:
	_send("set_farm_crop", [crop])
	var result := super(crop)
	depth -= 1
	return result

func upgrade_farm() -> bool:
	_send("upgrade_farm", [])
	var result := super()
	depth -= 1
	return result

func upgrade_shop() -> bool:
	_send("upgrade_shop", [])
	var result := super()
	depth -= 1
	return result

func order_racks(product: String, quantity := 1) -> bool:
	_send("order_racks", [product, quantity])
	var result := super(product, quantity)
	depth -= 1
	return result

func set_assistant_auto_collect(enabled: bool) -> void:
	_send("set_assistant_auto_collect", [enabled])
	super(enabled)
	depth -= 1

func set_employee_work(role: String, enabled: bool) -> bool:
	_send("set_employee_work", [role, enabled])
	var result := super(role, enabled)
	depth -= 1
	return result

func mark_demo_seen() -> void:
	_send("mark_demo_seen", [])
	super()
	depth -= 1

func buy_house() -> bool:
	_send("buy_house", [])
	var result := super()
	depth -= 1
	return result

func order_cart(cart: Dictionary) -> bool:
	_send("order_cart", [cart])
	var result := super(cart)
	depth -= 1
	return result

func order_stock(id := "bottle", boxes := 1) -> bool:
	_send("order_stock", [id, boxes])
	var result := super(id, boxes)
	depth -= 1
	return result

func purchase_stock() -> bool:
	_send("purchase_stock", [])
	var result := super()
	depth -= 1
	return result

func pack_rack(id: int) -> bool:
	_send("pack_rack", [id])
	var result := super(id)
	depth -= 1
	return result

func place_rack(product: String, position: Vector2, turn: int, id := -1, from_delivery := false) -> bool:
	_send("place_rack", [product, position, turn, id, from_delivery])
	var result := super(product, position, turn, id, from_delivery)
	depth -= 1
	return result

func hire_worker(level := 1) -> bool:
	_send("hire_worker", [level])
	var result := super(level)
	depth -= 1
	return result

func hire_stock_worker() -> bool:
	_send("hire_stock_worker", [])
	var result := super()
	depth -= 1
	return result

func hire_warehouse_worker() -> bool:
	_send("hire_warehouse_worker", [])
	var result := super()
	depth -= 1
	return result

func pay_bills() -> bool:
	_send("pay_bills", [])
	var result := super()
	depth -= 1
	return result

func set_selling_price(value: int) -> bool:
	_send("set_selling_price", [value])
	var result := super(value)
	depth -= 1
	return result

func set_product_price(id: String, price: int) -> bool:
	_send("set_product_price", [id, price])
	var result := super(id, price)
	depth -= 1
	return result

func set_staff_shift(role: String, start: int, end: int) -> bool:
	_send("set_staff_shift", [role, start, end])
	var result := super(role, start, end)
	depth -= 1
	return result

func set_stock_rack(id: int) -> bool:
	_send("set_stock_rack", [id])
	var result := super(id)
	depth -= 1
	return result

func assign_shelf_slot(id: int, slot: int, product: String) -> bool:
	_send("assign_shelf_slot", [id, slot, product])
	var result := super(id, slot, product)
	depth -= 1
	return result

func start_marketing() -> bool:
	_send("start_marketing", [])
	var result := super()
	depth -= 1
	return result

func sell_one_stock(customer_budget: int, agreed_price: int = -1) -> bool:
	_send("sell_one_stock", [customer_budget, agreed_price])
	var result := super(customer_budget, agreed_price)
	depth -= 1
	return result

func drop_box() -> bool:
	_send("drop_box", [])
	var result := super()
	depth -= 1
	return result

func pick_up_box(by_worker := false, queue_index := -1) -> bool:
	_send("pick_up_box", [by_worker, queue_index])
	var result := super(by_worker, queue_index)
	depth -= 1
	return result

func pick_up_ground_box(index: int) -> bool:
	_send("pick_up_ground_box", [index])
	var result := super(index)
	depth -= 1
	return result

func put_down_box(position: Vector3) -> bool:
	_send("put_down_box", [position])
	var result := super(position)
	depth -= 1
	return result

func shelve_one(rack_id := -1) -> bool:
	_send("shelve_one", [rack_id])
	var result := super(rack_id)
	depth -= 1
	return result

func shelve_box(by_worker := false, rack_id := -1) -> bool:
	_send("shelve_box", [by_worker, rack_id])
	var result := super(by_worker, rack_id)
	depth -= 1
	return result

func store_product_box(slot: int) -> bool:
	_send("store_product_box", [slot])
	var result := super(slot)
	depth -= 1
	return result

func retrieve_product_box(slot: int) -> bool:
	_send("retrieve_product_box", [slot])
	var result := super(slot)
	depth -= 1
	return result

func retrieve_receiver_box() -> bool:
	_send("retrieve_receiver_box", [])
	var result := super()
	depth -= 1
	return result

func warehouse_pick_up_box() -> bool:
	_send("warehouse_pick_up_box", [])
	var result := super()
	depth -= 1
	return result

func warehouse_store_carried() -> bool:
	_send("warehouse_store_carried", [])
	var result := super()
	depth -= 1
	return result

func sleep_until_morning() -> bool:
	coop_blocked.emit(SLEEP_HOST)
	return false

## The host's own van delivers; its next snapshot brings the boxes here.
func receive_delivery() -> bool:
	return true

## The host's own van delivers; its next snapshot brings the boxes here.
func receive_rack_delivery() -> bool:
	return true

## The host decides which bay box comes next; a friend sees every bay box queued
## (business_backend.gd coop_view), so a friend's game never activates one itself.
func _activate_next_box() -> void:
	pass

## Actions a friend may send; the host checks every request against this list.
const ACTIONS := ["take_loan", "repay_loan", "plant_crop", "water_crop", "harvest_crop", "buy_seeds", "hire_farm_worker", "set_farm_crop", "upgrade_farm", "upgrade_shop", "order_racks", "set_assistant_auto_collect", "set_employee_work", "mark_demo_seen", "buy_house", "order_cart", "order_stock", "purchase_stock", "pack_rack", "place_rack", "hire_worker", "hire_stock_worker", "hire_warehouse_worker", "pay_bills", "set_selling_price", "set_product_price", "set_staff_shift", "set_stock_rack", "assign_shelf_slot", "start_marketing", "sell_one_stock", "drop_box", "pick_up_box", "pick_up_ground_box", "put_down_box", "shelve_one", "shelve_box", "store_product_box", "retrieve_product_box", "retrieve_receiver_box", "warehouse_pick_up_box", "warehouse_store_carried"]
