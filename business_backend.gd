extends RefCounted

signal changed
signal clock_changed
const EmployeeRelations := preload("res://employee_relations.gd")
const CustomerReviews := preload("res://customer_reviews.gd")
const DemoProgress := preload("res://demo_progress.gd")
const RackStore := preload("res://rack_store.gd")
var racks = RackStore.new()
var furnishing_expenses := 0
const FarmStore := preload("res://farm_store.gd")
var farm := FarmStore.new()

func farm_time() -> int:
	return day * 1440 + int(minutes_of_day)

func buy_seeds(quantity := 1) -> bool:
	if quantity < 1 or quantity > 10 or farm.bought + quantity > 10000000 or money < quantity * FarmStore.SEED_COST: return false
	var old := snapshot()
	money -= quantity * FarmStore.SEED_COST
	farm.seeds += quantity
	farm.bought += quantity
	return _commit_farm(old)

func upgrade_farm() -> bool:
	if farm.level >= 3 or shop_level <= farm.level: return false
	var cost: int = FarmStore.UPGRADE_COSTS[farm.level - 1]
	if money < cost: return false
	var old := snapshot()
	money -= cost
	farm.level += 1
	return _commit_farm(old)

func plant_crop(index: int) -> bool:
	if carried_stock > 0 or index < 0 or index >= FarmStore.PLOTS[farm.level - 1] or farm.seeds <= 0 or farm.plots[index].planted: return false
	var old := snapshot()
	farm.seeds -= 1
	farm.planted += 1
	farm.plots[index] = {"planted": true, "watered_at": -1, "grow_minutes": FarmStore.GROW_MINUTES[farm.level - 1]}
	return _commit_farm(old)

func water_crop(index: int) -> bool:
	if carried_stock > 0 or index < 0 or index >= FarmStore.PLOTS[farm.level - 1] or not farm.plots[index].planted or farm.plots[index].watered_at >= 0: return false
	var old := snapshot()
	farm.plots[index].watered_at = farm_time()
	return _commit_farm(old)

func harvest_crop(index: int) -> bool:
	if not farm.ready(index, farm_time()) or carried_stock + worker_carried_stock > 0 or supply_box_count() >= MAX_SUPPLY_BOXES: return false
	var old := snapshot()
	farm.plots[index] = FarmStore.empty_plot()
	farm.harvested += 10
	inventory.tomato.purchased += 10
	if boxed_stock > 0: queued_boxes.push_front({"product": pending_product, "amount": boxed_stock})
	pending_product = "tomato"
	boxed_stock = 0
	carried_stock = 10
	stock_collection_assigned = false
	return _commit_farm(old)

func _commit_farm(old: Dictionary) -> bool:
	if not save_progress():
		money = int(old.money)
		farm.restore(old.farm)
		inventory = old.inventory.duplicate(true)
		pending_product = old.pending_product
		boxed_stock = int(old.boxed_stock)
		carried_stock = int(old.carried_stock)
		queued_boxes = old.queued_boxes.duplicate(true)
		stock_collection_assigned = old.stock_collection_assigned
		return false
	changed.emit()
	return true
var last_saved_json := ""
var last_saved_path := ""
const Logistics = preload("res://shop_logistics.gd")
var logistics = Logistics.new()
var warehouse_worker_hired := false
var warehouse_worker_hired_day := 0
var warehouse_shift_start := 480
var warehouse_shift_end := 1080

func warehouse_worker_on_shift() -> bool:
	return staff.on_shift(self, "warehouse") and staff.records.warehouse.work_enabled

func hire_warehouse_worker() -> bool:
	if money < HIRING_COST: return false
	var old := snapshot()
	if not staff.rehire(self, "warehouse"): return false
	money -= HIRING_COST
	hiring_expenses += HIRING_COST
	warehouse_worker_hired = true
	warehouse_worker_hired_day = day
	if not save_progress():
		money = int(old.money)
		hiring_expenses = int(old.hiring_expenses)
		warehouse_worker_hired = old.warehouse_worker_hired
		warehouse_worker_hired_day = int(old.warehouse_worker_hired_day)
		staff.restore(old.staff_relations)
		return false
	changed.emit()
	return true

func warehouse_pick_up_box() -> bool:
	if not warehouse_worker_on_shift() or not logistics.warehouse_carry.is_empty(): return false
	var slot := -1
	for rack in range(Logistics.STORAGE_RACKS):
		slot = logistics.free_slot(rack)
		if slot >= 0: break
	if slot < 0: return false
	var old := snapshot()
	var box: Dictionary
	if not queued_boxes.is_empty(): box = queued_boxes.pop_front()
	elif boxed_stock > 0 and not stock_collection_assigned:
		box = {"product": pending_product, "amount": boxed_stock}
		boxed_stock = 0
		_activate_next_box()
	else: return false
	logistics.warehouse_carry = {"product": box.product, "amount": int(box.amount), "slot": slot}
	return _commit_logistics(old)

func warehouse_store_carried() -> bool:
	if not warehouse_worker_on_shift() or logistics.warehouse_carry.is_empty(): return false
	var old := snapshot()
	logistics.storage.append(logistics.warehouse_carry.duplicate())
	logistics.warehouse_carry.clear()
	return _commit_logistics(old)

func retrieve_receiver_box() -> bool:
	if warehouse_worker_on_shift() or logistics.warehouse_carry.is_empty() or carried_stock + worker_carried_stock > 0 or supply_box_count() >= MAX_SUPPLY_BOXES: return false
	var old := snapshot()
	if boxed_stock > 0: queued_boxes.push_front({"product": pending_product, "amount": boxed_stock})
	boxed_stock = 0
	pending_product = logistics.warehouse_carry.product
	carried_stock = int(logistics.warehouse_carry.amount)
	stock_collection_assigned = false
	logistics.warehouse_carry.clear()
	return _commit_logistics(old)

func can_order_racks(product: String, quantity: int) -> bool:
	return product in Catalog.IDS and quantity > 0 and racks.records.size() + logistics.rack_count() + quantity <= RackStore.MAX_RACKS and money >= quantity * RackStore.COST

func order_racks(product: String, quantity := 1) -> bool:
	if not can_order_racks(product, quantity): return false
	var old: Dictionary = snapshot()
	money -= RackStore.COST * quantity
	furnishing_expenses += RackStore.COST * quantity
	for index in range(quantity): logistics.rack_incoming.append(product)
	return _commit_logistics(old)

func receive_rack_delivery() -> bool:
	if logistics.rack_incoming.is_empty(): return false
	var old: Dictionary = snapshot()
	logistics.rack_delivered.append_array(logistics.rack_incoming)
	logistics.rack_incoming.clear()
	return _commit_logistics(old)

func store_product_box(slot: int) -> bool:
	if carried_stock <= 0 or slot < 0 or slot >= Logistics.STORAGE_CAPACITY or not logistics.at_slot(slot).is_empty() or logistics.warehouse_carry.get("slot", -1) == slot: return false
	var old: Dictionary = snapshot()
	logistics.storage.append({"slot": slot, "product": pending_product, "amount": carried_stock})
	carried_stock = 0
	_activate_next_box()
	return _commit_logistics(old)

func retrieve_product_box(slot: int) -> bool:
	var box: Dictionary = logistics.at_slot(slot)
	if box.is_empty() or carried_stock + worker_carried_stock > 0 or supply_box_count() >= MAX_SUPPLY_BOXES: return false
	var old: Dictionary = snapshot()
	if boxed_stock > 0: queued_boxes.push_front({"product": pending_product, "amount": boxed_stock})
	boxed_stock = 0
	pending_product = box.product
	carried_stock = int(box.amount)
	stock_collection_assigned = false
	logistics.storage.erase(box)
	return _commit_logistics(old)

## Warehouse slot Sunil should fetch: a stored box whose product is low on the
## shelves (3 or fewer) and fits entirely in free shelf space. -1 when none.
func storage_restock_slot() -> int:
	if carried_stock + worker_carried_stock > 0 or boxed_stock > 0 or not queued_boxes.is_empty(): return -1
	var best := -1
	var best_stock := 1000000
	for box in logistics.storage:
		var shelf := product_stock(box.product)
		if shelf > 3 or shelf >= best_stock: continue
		var space := 0
		for record in racks.records: space += racks.free_space(record.id, box.product)
		if space < int(box.amount): continue
		best = int(box.slot)
		best_stock = shelf
	return best

## Sunil takes a stored warehouse box into his hands (then shelves it like a delivery).
func worker_retrieve_stored_box(slot: int) -> bool:
	var box: Dictionary = logistics.at_slot(slot)
	if box.is_empty() or not stock_worker_on_shift() or carried_stock + worker_carried_stock > 0 or boxed_stock > 0: return false
	var old: Dictionary = snapshot()
	pending_product = box.product
	worker_carried_stock = int(box.amount)
	stock_collection_assigned = false
	logistics.storage.erase(box)
	if not save_progress():
		pending_product = old.pending_product
		worker_carried_stock = int(old.worker_carried_stock)
		logistics.restore(old.logistics)
		return false
	changed.emit()
	return true

func _commit_logistics(old: Dictionary) -> bool:
	if not save_progress():
		money = int(old.money)
		furnishing_expenses = int(old.furnishing_expenses)
		carried_stock = int(old.carried_stock)
		boxed_stock = int(old.boxed_stock)
		pending_product = old.pending_product
		queued_boxes = old.queued_boxes.duplicate(true)
		stock_collection_assigned = old.get("stock_collection_assigned", false)
		logistics.restore(old.logistics)
		return false
	changed.emit()
	return true
var demo = DemoProgress.new()
var customer_reviews = CustomerReviews.new()
var staff = EmployeeRelations.new()
var overtime_expenses := 0
const Catalog := preload("res://product_catalog.gd")
var inventory := Catalog.fresh_inventory()
var pending_product := "bottle"
var incoming_boxes: Array = []
var queued_boxes: Array = []
const MAX_SUPPLY_BOXES := 20
var assistant_auto_collect := false
var stock_collection_assigned := false

func assign_stock_collection() -> bool:
	if not stock_worker_on_shift() or boxed_stock <= 0: return false
	if stock_collection_assigned: return true
	stock_collection_assigned = true
	if not save_progress():
		stock_collection_assigned = false
		return false
	changed.emit()
	return true

func product_stock(id: String) -> int:
	if id == "bottle":
		var total := stock
		for item in inventory.values(): total -= int(item.stock)
		return total
	return int(inventory[id].stock) if inventory.has(id) else 0

func product_price(id: String) -> int:
	return selling_price if id == "bottle" else int(inventory[id].price)

func set_product_price(id: String, price: int) -> bool:
	if id == "bottle": return set_selling_price(price)
	if not inventory.has(id) or price < 50 or price > 200 or price % 10 != 0: return false
	inventory[id].price = price
	_commit()
	return true

func set_assistant_auto_collect(enabled: bool) -> void:
	assistant_auto_collect = enabled
	_commit()

const INITIAL_MONEY := 50000
const INITIAL_STOCK := 10
const STOCK_COST := 500
const STOCK_AMOUNT := 10
const MARKETING_COST := 200
const MARKETING_DURATION := 60.0
const HIRING_COST := 1000
const HOUSE_COST := 15000
const DAILY_SHOP_COST := 100
const DAILY_WORKER_WAGE := 200
const SHOP_OPEN_MINUTE := 480
const SHOP_CLOSE_MINUTE := 1200
const UPGRADE_COSTS := [2500, 5000]
const CUSTOMER_INTERVALS := [10.0, 8.0, 6.0]
const SUPPLY_FIELDS := ["supply_in_transit", "boxed_stock", "carried_stock", "worker_carried_stock"]
const STAFF_FIELDS := ["stock_worker_hired_day"]
const EMPLOYEE_FIELDS := ["cashier_level", "cashier_shift_start", "cashier_shift_end", "stock_shift_start", "stock_shift_end"]
const CASHIER_COSTS := [1000, 2000, 3000]
const CASHIER_SCAN_SECONDS := [3.0, 2.0, 1.0]
const DAILY_FIELDS := ["operating_expenses", "wage_expenses", "operating_due", "wages_due", "billing_start_day", "last_billed_day", "worker_hired_day"]
const MAX_SAVED_VALUE := 1000000000
const INTEGER_FIELDS := ["money", "stock", "items_sold", "sales_revenue", "restocking_expenses", "marketing_expenses", "hiring_expenses", "property_expenses", "selling_price", "missed_sales", "shop_level", "upgrade_expenses"]

var money := INITIAL_MONEY
var stock := INITIAL_STOCK
var items_sold := 0
var sales_revenue := 0
var restocking_expenses := 0
var marketing_expenses := 0
var hiring_expenses := 0
var property_expenses := 0
var house_owned := false
var selling_price := 100
var missed_sales := 0
var last_visit := "No customers yet"
var worker_hired := false
var marketing_seconds_left := 0.0
var save_path := ""
var save_status := "Save: New game"
var day := 1
var minutes_of_day := 480.0
var operating_expenses := 0
var wage_expenses := 0
var operating_due := 0
var wages_due := 0
var billing_start_day := 1
var last_billed_day := 1
var worker_hired_day := 0
var shop_level := 1
var upgrade_expenses := 0
var supply_in_transit := 0
var boxed_stock := 0
var carried_stock := 0
var worker_carried_stock := 0
var stock_worker_hired := false
var stock_worker_hired_day := 0
var cashier_level := 1
var cashier_shift_start := 480
var cashier_shift_end := 1200
var stock_shift_start := 480
var stock_shift_end := 1200

func cashier_on_shift() -> bool:
	return staff.on_shift(self, "cashier") and staff.records.cashier.work_enabled

func stock_worker_on_shift() -> bool:
	return staff.on_shift(self, "stock") and staff.records.stock.work_enabled

func set_employee_work(role: String, enabled: bool) -> bool:
	if role not in staff.ROLES or not staff.active(self, role): return false
	if staff.records[role].work_enabled == enabled: return true
	staff.records[role].work_enabled = enabled
	_commit()
	return true

func cashier_scan_seconds() -> float:
	return CASHIER_SCAN_SECONDS[cashier_level - 1]

func set_staff_shift(role: String, start: int, end: int) -> bool:
	if role not in staff.ROLES or not valid_shift(start, end): return false
	set(role + "_shift_start", start)
	set(role + "_shift_end", end)
	_commit()
	return true

func valid_shift(start: int, end: int) -> bool:
	return start >= 360 and end <= 1320 and start < end and start % 60 == 0 and end % 60 == 0

func supply_box_count() -> int:
	return logistics.ground_boxes.size() + incoming_boxes.size() + queued_boxes.size() + (1 if boxed_stock + carried_stock + worker_carried_stock > 0 else 0)

func can_order_stock(id := "bottle", boxes := 1) -> bool:
	return id in Catalog.IDS and boxes >= 1 and boxes <= 10 and supply_box_count() + boxes <= MAX_SUPPLY_BOXES and money >= Catalog.COSTS[id] * boxes

func order_stock(id := "bottle", boxes := 1) -> bool:
	if not can_order_stock(id, boxes):
		return false
	money -= Catalog.COSTS[id] * boxes
	restocking_expenses += Catalog.COSTS[id] * boxes
	if supply_box_count() == 0: pending_product = id
	if inventory.has(id): inventory[id].purchased += STOCK_AMOUNT * boxes
	for index in range(boxes): incoming_boxes.append({"product": id, "amount": STOCK_AMOUNT})
	supply_in_transit += STOCK_AMOUNT * boxes
	demo.record("order")
	_commit()
	return true

func receive_delivery() -> bool:
	if supply_in_transit <= 0 or incoming_boxes.is_empty():
		return false
	queued_boxes.append_array(incoming_boxes)
	incoming_boxes.clear()
	supply_in_transit = 0
	_activate_next_box()
	_commit()
	return true

func _activate_next_box() -> void:
	if boxed_stock + carried_stock + worker_carried_stock > 0 or queued_boxes.is_empty(): return
	var box: Dictionary = queued_boxes.pop_front()
	pending_product = box.product
	boxed_stock = int(box.amount)

func pick_up_box(by_worker := false, queue_index := -1) -> bool:
	if queue_index >= 0:
		if queue_index >= queued_boxes.size() or carried_stock + worker_carried_stock > 0: return false
		if by_worker and not stock_worker_on_shift(): return false
		var selected: Dictionary = queued_boxes[queue_index]
		queued_boxes.remove_at(queue_index)
		if boxed_stock > 0: queued_boxes.push_front({"product": pending_product, "amount": boxed_stock})
		pending_product = selected.product
		boxed_stock = int(selected.amount)
	if boxed_stock <= 0 or boxed_stock > STOCK_AMOUNT or carried_stock + worker_carried_stock != 0:
		return false
	if by_worker:
		if not stock_worker_on_shift(): return false
		worker_carried_stock = boxed_stock
	else:
		carried_stock = boxed_stock
	boxed_stock = 0
	stock_collection_assigned = false
	_commit()
	return true

func shelve_box(by_worker := false, rack_id := -1) -> bool:
	if by_worker and not stock_worker_on_shift(): return false
	var amount := worker_carried_stock if by_worker else carried_stock
	if amount <= 0 or amount > STOCK_AMOUNT:
		return false
	if rack_id < 0: rack_id = racks.restock_rack(pending_product)
	amount = mini(amount, racks.free_space(rack_id, pending_product))
	if amount == 0: return false
	var old := snapshot()
	if not racks.add_stock(pending_product, amount, rack_id): return false
	stock += amount
	if inventory.has(pending_product): inventory[pending_product].stock += amount
	if by_worker:
		worker_carried_stock -= amount
	else:
		carried_stock -= amount
	demo.record("worker" if by_worker else "shelve", amount)
	_activate_next_box()
	return _commit_shelves(old)

func shelve_one(rack_id := -1) -> bool:
	if carried_stock <= 0 or carried_stock > STOCK_AMOUNT:
		return false
	var old := snapshot()
	if not racks.add_stock(pending_product, 1, rack_id): return false
	stock += 1
	if inventory.has(pending_product): inventory[pending_product].stock += 1
	carried_stock -= 1
	demo.record("shelve")
	_activate_next_box()
	return _commit_shelves(old)

func _commit_shelves(old: Dictionary) -> bool:
	if not save_progress():
		for field in ["money", "stock", "restocking_expenses", "carried_stock", "worker_carried_stock", "boxed_stock"]: set(field, int(old[field]))
		inventory = old.inventory.duplicate(true)
		pending_product = old.pending_product
		queued_boxes = old.queued_boxes.duplicate(true)
		stock_collection_assigned = old.stock_collection_assigned
		racks.records = old.rack_layout.duplicate(true)
		racks.last_added_slot = -1
		demo.restore(old.demo_progress)
		return false
	changed.emit()
	return true

func drop_box() -> bool:
	if carried_stock <= 0 or carried_stock > STOCK_AMOUNT or boxed_stock != 0:
		return false
	boxed_stock = carried_stock
	carried_stock = 0
	_commit()
	return true

func put_down_box(position: Vector3) -> bool:
	if carried_stock <= 0 or boxed_stock != 0 or not position.is_finite() or absf(position.x) > 64 or absf(position.z) > 64 or position.y < 0 or position.y > 10: return false
	var old := snapshot()
	# Normalize coordinates to the same precision used by the save encoder.
	var coordinates: Array = JSON.parse_string(JSON.stringify([position.x, position.y, position.z]))
	logistics.ground_boxes.append({"product": pending_product, "amount": carried_stock, "position": coordinates})
	carried_stock = 0
	stock_collection_assigned = false
	_activate_next_box()
	return _commit_logistics(old)

func pick_up_ground_box(index: int) -> bool:
	if index < 0 or index >= logistics.ground_boxes.size() or carried_stock + worker_carried_stock > 0: return false
	var old := snapshot()
	var box: Dictionary = logistics.ground_boxes.pop_at(index)
	if boxed_stock > 0: queued_boxes.push_front({"product": pending_product, "amount": boxed_stock})
	boxed_stock = 0
	pending_product = box.product
	carried_stock = int(box.amount)
	stock_collection_assigned = false
	return _commit_logistics(old)

func next_upgrade_cost() -> int:
	return UPGRADE_COSTS[shop_level - 1] if shop_level < CUSTOMER_INTERVALS.size() else 0

func can_upgrade_shop() -> bool:
	return next_upgrade_cost() > 0 and money >= next_upgrade_cost()

func upgrade_shop() -> bool:
	if not can_upgrade_shop():
		return false
	var cost := next_upgrade_cost()
	money -= cost
	upgrade_expenses += cost
	shop_level += 1
	_commit()
	return true

func customer_spawn_interval(marketing := false) -> float:
	return CUSTOMER_INTERVALS[shop_level - 1] * (0.85 if marketing else 1.0)

func shop_is_open() -> bool:
	return minutes_of_day >= SHOP_OPEN_MINUTE and minutes_of_day < SHOP_CLOSE_MINUTE

func worker_on_duty() -> bool:
	return staff.active(self, "cashier") and wages_due == 0

func stock_worker_on_duty() -> bool:
	return staff.active(self, "stock") and wages_due == 0

func staff_count() -> int:
	return int(staff.active(self, "cashier")) + int(staff.active(self, "stock")) + int(staff.active(self, "warehouse"))

func unpaid_bills() -> int:
	return operating_due + wages_due

func can_pay_bills() -> bool:
	return (operating_due > 0 and money >= DAILY_SHOP_COST) or (wages_due > 0 and money >= DAILY_WORKER_WAGE)

func pay_bills() -> bool:
	if not can_pay_bills():
		return false
	_settle_bills()
	_commit()
	return true

func _settle_bills() -> void:
	var shop_payment := mini(operating_due, (money / DAILY_SHOP_COST) * DAILY_SHOP_COST)
	money -= shop_payment
	operating_due -= shop_payment
	operating_expenses += shop_payment
	var wage_payment := mini(wages_due, (money / DAILY_WORKER_WAGE) * DAILY_WORKER_WAGE)
	money -= wage_payment
	wages_due -= wage_payment
	wage_expenses += wage_payment

func _can_bill(target_day: int) -> bool:
	var wages := ((target_day - worker_hired_day) if worker_hired else 0) + ((target_day - stock_worker_hired_day) if stock_worker_hired else 0)
	if warehouse_worker_hired: wages += target_day - warehouse_worker_hired_day
	return (target_day - billing_start_day) * DAILY_SHOP_COST <= MAX_SAVED_VALUE and wages * DAILY_WORKER_WAGE <= MAX_SAVED_VALUE

func _bill_new_day() -> void:
	var elapsed_days := day - last_billed_day
	operating_due += elapsed_days * DAILY_SHOP_COST
	wages_due += elapsed_days * DAILY_WORKER_WAGE * staff_count()
	last_billed_day = day
	_settle_bills()

func advance_clock(minutes: float) -> void:
	if not is_finite(minutes) or minutes <= 0.0:
		return
	var total := minutes_of_day + minutes
	if not is_finite(total) or total >= (MAX_SAVED_VALUE - day + 1) * 1440.0:
		return
	var elapsed_days := floori(total / 1440.0)
	if day + elapsed_days > MAX_SAVED_VALUE:
		return
	if not _can_bill(day + elapsed_days):
		return
	day += elapsed_days
	minutes_of_day = fmod(total, 1440.0)
	if elapsed_days > 0:
		_bill_new_day()
	staff.tick(self)
	if elapsed_days > 0: _commit()
	clock_changed.emit()

func sleep_time_allowed() -> bool:
	return minutes_of_day >= SHOP_CLOSE_MINUTE or minutes_of_day < SHOP_OPEN_MINUTE

func sleep_until_morning() -> bool:
	var next_day := day + int(minutes_of_day >= SHOP_CLOSE_MINUTE)
	if not house_owned or not sleep_time_allowed() or next_day > MAX_SAVED_VALUE or not _can_bill(next_day):
		return false
	day = next_day
	minutes_of_day = float(SHOP_OPEN_MINUTE)
	if day > last_billed_day:
		_bill_new_day()
	staff.tick(self)
	_commit()
	clock_changed.emit()
	return true

func purchase_stock() -> bool:
	if money < STOCK_COST:
		return false
	var old := snapshot()
	if not racks.add_stock("bottle", STOCK_AMOUNT): return false
	money -= STOCK_COST
	stock += STOCK_AMOUNT
	restocking_expenses += STOCK_COST
	return _commit_shelves(old)

func sell_one_stock(customer_budget: int, agreed_price: int = -1) -> bool:
	return sell_basket(1, customer_budget, agreed_price)

func sell_basket(quantity: int, customer_budget: int, agreed_price: int = -1, product := "bottle", rack_id := -1) -> bool:
	if product not in Catalog.IDS: return false
	if quantity < 1 or quantity > 3: return false
	if customer_budget < 0 or not shop_is_open():
		return false
	var retail := product_price(product)
	var price := retail if agreed_price == -1 else agreed_price
	if price < 50 or price > retail or price % 10 != 0:
		return false
	if product_stock(product) < quantity:
		missed_sales += 1
		last_visit = "Out of stock"
		_commit()
		return false
	if price > customer_budget:
		missed_sales += 1
		last_visit = "Price too high"
		_commit()
		return false
	if not racks.remove_stock(product, quantity, rack_id): return false
	stock -= quantity
	if inventory.has(product):
		inventory[product].stock -= quantity
		inventory[product].sold += quantity
	money += price * quantity
	items_sold += quantity
	sales_revenue += price * quantity
	demo.record("sale", price * quantity)
	last_visit = "Bought for %s%d" % [String.chr(8377), price]
	_commit()
	return true

func record_bargain_refusal(timed_out := false) -> void:
	if not shop_is_open():
		return
	missed_sales += 1
	last_visit = "Customer left" if timed_out else "Offer refused"
	_commit()

func record_stock_shortage() -> void:
	if shop_is_open():
		missed_sales += 1
		last_visit = "Out of stock"
		_commit()

func set_selling_price(value: int) -> bool:
	if value < 50 or value > 200 or value % 10 != 0:
		return false
	if selling_price != value:
		selling_price = value
		_commit()
	return true

func hire_worker(level := 1) -> bool:
	if level < 1 or level > CASHIER_COSTS.size() or staff.active(self, "cashier"):
		return false
	var cost: int = CASHIER_COSTS[level - 1]
	if money < cost: return false
	if not staff.rehire(self, "cashier"): return false
	money -= cost
	hiring_expenses += cost
	cashier_level = level
	worker_hired = true
	worker_hired_day = day
	_commit()
	return true

func hire_stock_worker() -> bool:
	if staff.active(self, "stock") or money < HIRING_COST: return false
	if not staff.rehire(self, "stock"): return false
	money -= HIRING_COST
	hiring_expenses += HIRING_COST
	stock_worker_hired = true
	stock_worker_hired_day = day
	_commit()
	return true

func start_marketing() -> bool:
	if marketing_seconds_left > 0.0 or money < MARKETING_COST:
		return false
	money -= MARKETING_COST
	marketing_expenses += MARKETING_COST
	marketing_seconds_left = MARKETING_DURATION
	_commit()
	return true

func buy_house() -> bool:
	if house_owned or money < HOUSE_COST:
		return false
	money -= HOUSE_COST
	property_expenses += HOUSE_COST
	house_owned = true
	_commit()
	return true

## The player's family home is owned from the start of every game, at no cost.
func grant_home() -> bool:
	if house_owned: return true
	house_owned = true
	if not save_progress():
		house_owned = false
		return false
	changed.emit()
	return true

func finish_marketing() -> void:
	marketing_seconds_left = 0.0
	_commit()

func total_expenses() -> int:
	return restocking_expenses + marketing_expenses + hiring_expenses + operating_expenses + wage_expenses + upgrade_expenses + overtime_expenses + furnishing_expenses + farm.expenses()

func place_rack(product: String, position: Vector2, turn: int, id := -1, from_delivery := false) -> bool:
	if product not in Catalog.IDS or not position.is_finite() or turn < 0 or turn > 3: return false
	var buying := id < 0
	if buying and racks.records.size() >= RackStore.MAX_RACKS: return false
	if buying and (product not in logistics.rack_delivered if from_delivery else money < RackStore.COST or racks.records.size() + logistics.rack_count() >= RackStore.MAX_RACKS): return false
	var previous := racks.find(id)
	if not buying and (previous.is_empty() or previous.product != product): return false
	var candidate := {"id": racks.records.size() if buying else id, "product": product, "x": position.x, "z": position.y, "turn": turn, "amount": 0 if buying else int(previous.amount), "restock": true if buying else previous.get("restock", id < 3)}
	if buying:
		candidate["display"] = "produce" if product == "tomato" else "shelf"
		RackStore.migrate_record(candidate)
		for slot in candidate.slots: slot.product = ""
	else:
		candidate["display"] = previous.get("display", "shelf")
		candidate["slots"] = previous.slots.duplicate(true)
		candidate["legacy_overflow"] = int(previous.get("legacy_overflow", 0))
	if not racks.placement_error(candidate).is_empty(): return false
	var old_layout: Array = racks.records.duplicate(true)
	var old_delivered: Array = logistics.rack_delivered.duplicate()
	if buying:
		for item in racks.records:
			if item.product == product: item.restock = false
		racks.records.append(candidate)
		if from_delivery: logistics.rack_delivered.erase(product)
		else:
			money -= RackStore.COST
			furnishing_expenses += RackStore.COST
	else: racks.records[id] = candidate
	if not save_progress():
		racks.records = old_layout
		if buying and from_delivery: logistics.rack_delivered = old_delivered
		elif buying:
			money += RackStore.COST
			furnishing_expenses -= RackStore.COST
		return false
	changed.emit()
	return true

## Packs an empty purchased rack back into a warehouse furniture package; it can be
## unpacked and placed again later. The three starting racks always stay in the shop.
func pack_rack(id: int) -> bool:
	var record := racks.find(id)
	if record.is_empty() or id < 3 or int(record.amount) != 0 or int(record.get("legacy_overflow", 0)) != 0: return false
	var old_layout: Array = racks.records.duplicate(true)
	var old_delivered: Array = logistics.rack_delivered.duplicate()
	racks.records.erase(record)
	for item in racks.records:
		if int(item.id) > id: item.id = int(item.id) - 1
	if record.get("restock", false):
		for item in racks.records:
			if item.product == record.product:
				item.restock = true
				break
	logistics.rack_delivered.append("tomato" if record.get("display", "shelf") == "produce" else record.product)
	if not save_progress():
		racks.records = old_layout
		logistics.rack_delivered = old_delivered
		return false
	changed.emit()
	return true

func set_stock_rack(id: int) -> bool:
	var selected := racks.find(id)
	if selected.is_empty(): return false
	for item in racks.records:
		if item.product == selected.product: item.restock = item.id == id
	_commit()
	return true

func assign_shelf_slot(id: int, slot: int, product: String) -> bool:
	var old: Array = racks.records.duplicate(true)
	if not racks.assign_slot(id, slot, product): return false
	if not save_progress():
		racks.records = old
		return false
	changed.emit()
	return true

func net_profit() -> int:
	return sales_revenue - total_expenses()

func record_customer_review(outcome: String, wait_seconds: float, discounted := false) -> bool:
	if not customer_reviews.record(outcome, wait_seconds, discounted): return false
	_commit()
	return true

func total_spending() -> int:
	return total_expenses() + property_expenses

func mark_demo_seen() -> void:
	if not demo.completed() or demo.completion_seen: return
	demo.completion_seen = true
	_commit()

func snapshot() -> Dictionary:
	var data := {"version": 10, "inventory": inventory.duplicate(true), "pending_product": pending_product, "assistant_auto_collect": assistant_auto_collect, "staff_relations": staff.snapshot(), "overtime_expenses": overtime_expenses, "day": day, "minutes_of_day": minutes_of_day, "last_visit": last_visit, "worker_hired": worker_hired, "stock_worker_hired": stock_worker_hired, "house_owned": house_owned, "marketing_seconds_left": marketing_seconds_left}
	data["customer_reviews"] = customer_reviews.snapshot()
	data["farm"] = farm.snapshot()
	data["incoming_boxes"] = incoming_boxes.duplicate(true)
	data["queued_boxes"] = queued_boxes.duplicate(true)
	data["demo_progress"] = demo.snapshot()
	data["rack_layout"] = racks.records.duplicate(true)
	data["furnishing_expenses"] = furnishing_expenses
	data["stock_collection_assigned"] = stock_collection_assigned
	data["logistics"] = logistics.snapshot()
	for field in ["warehouse_worker_hired", "warehouse_worker_hired_day", "warehouse_shift_start", "warehouse_shift_end"]: data[field] = get(field)
	for field in INTEGER_FIELDS + DAILY_FIELDS + SUPPLY_FIELDS + STAFF_FIELDS + EMPLOYEE_FIELDS:
		data[field] = get(field)
	return data

func load_progress(path: String) -> void:
	save_path = path
	var data := _read_valid_save(path)
	if data.is_empty():
		data = _read_valid_save(path + ".bak")
		if not data.is_empty():
			save_status = "Save: Backup recovered"
		elif FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
			# Preserve invalid files for inspection rather than overwriting them.
			save_path = path + ".recovered"
			data = _read_valid_save(save_path)
			if data.is_empty():
				data = _read_valid_save(save_path + ".bak")
			save_status = "Save: Recovery loaded" if not data.is_empty() else "Save: Invalid file; new game"
	else:
		save_status = "Save: Loaded"
	if data.is_empty():
		return
	for field in INTEGER_FIELDS + DAILY_FIELDS + SUPPLY_FIELDS + STAFF_FIELDS + EMPLOYEE_FIELDS:
		set(field, int(data[field]))
	last_visit = data["last_visit"]
	worker_hired = data["worker_hired"]
	stock_worker_hired = data["stock_worker_hired"]
	house_owned = data["house_owned"]
	marketing_seconds_left = float(data["marketing_seconds_left"])
	day = int(data["day"])
	minutes_of_day = float(data["minutes_of_day"])
	staff.restore(data.staff_relations)
	overtime_expenses = int(data.overtime_expenses)
	inventory = data.inventory.duplicate(true)
	for id in Catalog.OPTIONAL:
		if not inventory.has(id): inventory[id] = Catalog.fresh_item(id)
	farm.restore(data.get("farm", FarmStore.new().snapshot()))
	for id in inventory:
		for field in inventory[id]: inventory[id][field] = int(inventory[id][field])
	pending_product = data.pending_product
	assistant_auto_collect = data.assistant_auto_collect
	stock_collection_assigned = data.get("stock_collection_assigned", false)
	logistics.restore(data.get("logistics", {}))
	warehouse_worker_hired = data.get("warehouse_worker_hired", false)
	warehouse_worker_hired_day = int(data.get("warehouse_worker_hired_day", 0))
	warehouse_shift_start = int(data.get("warehouse_shift_start", 480))
	warehouse_shift_end = int(data.get("warehouse_shift_end", 1080))
	customer_reviews.restore(data.customer_reviews)
	incoming_boxes = data.incoming_boxes.duplicate(true)
	queued_boxes = data.queued_boxes.duplicate(true)
	for boxes in [incoming_boxes, queued_boxes]:
		for box in boxes: box.amount = int(box.amount)
	demo.restore(data.demo_progress)
	racks.records = data.get("rack_layout", RackStore.fresh(stock, inventory)).duplicate(true)
	for item in racks.records:
		for field in ["id", "turn", "amount"]: item[field] = int(item[field])
		for field in ["x", "z"]: item[field] = float(item[field])
		item.restock = item.get("restock", item.id < 3)
		RackStore.migrate_record(item)
		item.legacy_overflow = int(item.get("legacy_overflow", 0))
		for slot in item.slots: slot.count = int(slot.count)
	furnishing_expenses = int(data.get("furnishing_expenses", 0))

func save_progress() -> bool:
	if save_path.is_empty():
		return true
	var data := snapshot()
	var encoded := JSON.stringify(data)
	var already_valid := save_path == last_saved_path and encoded == last_saved_json
	if already_valid and _matches_saved_file(save_path, encoded) and _matches_saved_file(save_path + ".bak", encoded):
		save_status = "Save: Saved"
		return true
	if not already_valid and not _is_valid_snapshot(data):
		save_status = "Save: Invalid state"
		return false
	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		save_status = "Save: Failed"
		return false
	file.store_string(encoded)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		save_status = "Save: Failed"
		return false
	var known_valid_file := save_path == last_saved_path and _matches_saved_file(save_path, last_saved_json)
	if known_valid_file or not _read_valid_save(save_path).is_empty():
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			save_status = "Save: Backup failed"
			return false
	if DirAccess.rename_absolute(temporary_path, save_path) != OK:
		save_status = "Save: Failed"
		return false
	save_status = "Save: Saved"
	last_saved_json = encoded
	last_saved_path = save_path
	return true

func _matches_saved_file(path: String, encoded: String) -> bool:
	if encoded.is_empty(): return false
	var file := FileAccess.open(path, FileAccess.READ)
	return file != null and file.get_length() <= 65536 and file.get_as_text() == encoded

func _commit() -> void:
	save_progress()
	changed.emit()

func _read_valid_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	var data: Dictionary = parser.data
	var version = data.get("version")
	if (version is int or version is float) and version == 1:
		if data.has("house_owned") or data.has("property_expenses"):
			return {}
		data["version"] = 2
		data["house_owned"] = false
		data["property_expenses"] = 0
	if data.get("version") == 2:
		if data.has("day") or data.has("minutes_of_day"):
			return {}
		data["version"] = 3
		data["day"] = 1
		data["minutes_of_day"] = 480.0
	if data.get("version") == 3:
		for field in DAILY_FIELDS:
			if data.has(field):
				return {}
			data[field] = 0
		data["billing_start_day"] = data.get("day")
		data["last_billed_day"] = data.get("day")
		data["worker_hired_day"] = data.get("day") if data.get("worker_hired") == true else 0
		data["version"] = 4
	if data.get("version") == 4:
		if data.has("shop_level") or data.has("upgrade_expenses"):
			return {}
		data["shop_level"] = 1
		data["upgrade_expenses"] = 0
		data["version"] = 5
	if data.get("version") == 5:
		for field in ["supply_in_transit", "boxed_stock", "carried_stock"]:
			if data.has(field):
				return {}
			data[field] = 0
		data["version"] = 6
	if data.get("version") == 6:
		for field in STAFF_FIELDS + ["stock_worker_hired", "worker_carried_stock"]:
			if data.has(field): return {}
		data["stock_worker_hired"] = false
		data["stock_worker_hired_day"] = 0
		data["worker_carried_stock"] = 0
		data["version"] = 7
	if data.get("version") == 7:
		for field in EMPLOYEE_FIELDS:
			if data.has(field): return {}
		data["cashier_level"] = 1
		data["cashier_shift_start"] = 480
		data["cashier_shift_end"] = 1200
		data["stock_shift_start"] = 480
		data["stock_shift_end"] = 1200
		data["version"] = 8
	if data.get("version") == 8:
		if data.has("staff_relations") or data.has("overtime_expenses"): return {}
		data["staff_relations"] = EmployeeRelations.new().snapshot()
		data["overtime_expenses"] = 0
		data["version"] = 9
	if data.get("version") == 9:
		for field in ["inventory", "pending_product", "assistant_auto_collect"]:
			if data.has(field): return {}
		data["inventory"] = Catalog.fresh_inventory()
		data["pending_product"] = "bottle"
		data["assistant_auto_collect"] = false
		data["version"] = 10
	# Version 10 saves made before reviews have a neutral starting reputation.
	if data.get("version") == 10 and not data.has("customer_reviews"):
		data["customer_reviews"] = CustomerReviews.new().snapshot()
	if data.get("version") == 10 and not data.has("demo_progress"):
		data["demo_progress"] = DemoProgress.new().snapshot()
	if data.get("version") == 10 and not data.has("incoming_boxes") and not data.has("queued_boxes"):
		data["queued_boxes"] = []
		data["incoming_boxes"] = []
		if data.get("supply_in_transit", 0) == STOCK_AMOUNT:
			data.incoming_boxes.append({"product": data.pending_product, "amount": STOCK_AMOUNT})
	return data if _is_valid_snapshot(data) else {}

func _is_valid_snapshot(data: Dictionary) -> bool:
	if not data.get("stock_collection_assigned", false) is bool: return false
	var demo_data = data.get("demo_progress", DemoProgress.new().snapshot())
	if not DemoProgress.valid(demo_data): return false
	if not CustomerReviews.valid(data.get("customer_reviews", CustomerReviews.new().snapshot())): return false
	var version = data.get("version")
	if not (version is int or version is float) or version != 10:
		return false
	var saved_day = data.get("day")
	var saved_minutes = data.get("minutes_of_day")
	if not (saved_day is int or saved_day is float) or not is_finite(float(saved_day)):
		return false
	if saved_day < 1 or saved_day > MAX_SAVED_VALUE or saved_day != int(saved_day):
		return false
	if not (saved_minutes is int or saved_minutes is float) or not is_finite(float(saved_minutes)):
		return false
	if saved_minutes < 0.0 or saved_minutes >= 1440.0:
		return false
	var farm_data: Dictionary = data.get("farm", FarmStore.new().snapshot())
	if not FarmStore.valid(farm_data, int(saved_day) * 1440 + int(saved_minutes)): return false
	var farm_state := FarmStore.new()
	farm_state.restore(farm_data)
	if not Catalog.valid(data.get("inventory")) or data.get("pending_product") not in Catalog.IDS or not data.get("assistant_auto_collect") is bool: return false
	if not EmployeeRelations.valid(data.get("staff_relations"), int(saved_day)): return false
	if not EmployeeRelations.whole(data.get("overtime_expenses"), MAX_SAVED_VALUE): return false
	var relations: Dictionary = data.staff_relations
	var overtime_due := int(relations.records.cashier.unpaid) + int(relations.records.stock.unpaid) + int(relations.records.get("warehouse", EmployeeRelations.fresh_record()).unpaid)
	if data.overtime_expenses + overtime_due != relations.overtime_hours * 50: return false
	for field in INTEGER_FIELDS + DAILY_FIELDS + SUPPLY_FIELDS + STAFF_FIELDS + EMPLOYEE_FIELDS:
		var value = data.get(field)
		if not (value is int or value is float):
			return false
		if not is_finite(float(value)) or value < 0 or value > MAX_SAVED_VALUE or value != int(value):
			return false
	if data.get("stock_collection_assigned", false) and (not data.get("stock_worker_hired", false) or data.boxed_stock <= 0): return false
	var furnishing = data.get("furnishing_expenses", 0)
	if not EmployeeRelations.whole(furnishing, MAX_SAVED_VALUE): return false
	var layout = data.get("rack_layout", RackStore.fresh(int(data.stock), data.inventory))
	if not RackStore.valid(layout, int(data.stock), data.inventory): return false
	var delivery_data = data.get("logistics", {})
	if not Logistics.valid(delivery_data, RackStore.MAX_RACKS - layout.size()): return false
	var pending_racks: int = delivery_data.get("rack_incoming", []).size() + delivery_data.get("rack_delivered", []).size()
	if furnishing != (layout.size() - 3 + pending_racks) * RackStore.COST: return false
	if not data.get("warehouse_worker_hired", false) is bool: return false
	for field in ["warehouse_worker_hired_day", "warehouse_shift_start", "warehouse_shift_end"]:
		if not EmployeeRelations.whole(data.get(field, 0 if field == "warehouse_worker_hired_day" else (480 if field == "warehouse_shift_start" else 1080)), MAX_SAVED_VALUE): return false
	if not valid_shift(int(data.get("warehouse_shift_start", 480)), int(data.get("warehouse_shift_end", 1080))): return false
	if data["cashier_level"] < 1 or data["cashier_level"] > CASHIER_COSTS.size(): return false
	for role in ["cashier", "stock"]:
		if not valid_shift(int(data[role + "_shift_start"]), int(data[role + "_shift_end"])): return false
	var level := int(data["shop_level"])
	var stored_supply := 0
	var supply_by_product := {}
	for id in Catalog.IDS: supply_by_product[id] = 0
	var incoming_amount := 0
	var box_count := 0
	for box in delivery_data.get("storage", []):
		stored_supply += int(box.amount)
		supply_by_product[box.product] += int(box.amount)
	var carry: Dictionary = delivery_data.get("warehouse_carry", {})
	if not carry.is_empty():
		if not data.get("warehouse_worker_hired", false): return false
		stored_supply += int(carry.amount)
		supply_by_product[carry.product] += int(carry.amount)
	for field in ["incoming_boxes", "queued_boxes"]:
		var boxes = data.get(field, [])
		if not boxes is Array or boxes.size() > MAX_SUPPLY_BOXES: return false
		for box in boxes:
			if not box is Dictionary or box.get("product") not in Catalog.IDS: return false
			if not EmployeeRelations.whole(box.get("amount"), STOCK_AMOUNT) or box.amount < 1: return false
			if field == "incoming_boxes" and box.amount != STOCK_AMOUNT: return false
			supply_by_product[box.product] += int(box.amount)
			stored_supply += int(box.amount)
			box_count += 1
			if field == "incoming_boxes": incoming_amount += int(box.amount)
	for box in delivery_data.get("ground_boxes", []):
		supply_by_product[box.product] += int(box.amount)
		stored_supply += int(box.amount)
		box_count += 1
	# Missing manifests are permitted only for the old single-box snapshot format.
	if not data.has("incoming_boxes") and not data.has("queued_boxes"):
		incoming_amount = int(data.supply_in_transit)
		stored_supply += incoming_amount
		supply_by_product[data.pending_product] += incoming_amount
		if incoming_amount > STOCK_AMOUNT: return false
	elif not data.has("incoming_boxes") or not data.has("queued_boxes"): return false
	if incoming_amount != data.supply_in_transit: return false
	var active_amount := 0
	var active_slots := 0
	for field in SUPPLY_FIELDS:
		if field == "supply_in_transit": continue
		if data[field] < 0 or data[field] > STOCK_AMOUNT:
			return false
		stored_supply += int(data[field])
		active_amount += int(data[field])
		if data[field] > 0: active_slots += 1
	supply_by_product[data.pending_product] += active_amount
	if active_slots > 1 or active_amount > STOCK_AMOUNT or box_count + (1 if active_amount > 0 else 0) > MAX_SUPPLY_BOXES:
		return false
	if level < 1 or level > CUSTOMER_INTERVALS.size():
		return false
	var expected_upgrade_expenses := 0
	for index in range(level - 1):
		expected_upgrade_expenses += UPGRADE_COSTS[index]
	if int(data["upgrade_expenses"]) != expected_upgrade_expenses:
		return false
	if not data.get("worker_hired") is bool or not data.get("last_visit") is String:
		return false
	if not data["worker_hired"] and data["cashier_level"] != 1: return false
	if not data.get("house_owned") is bool:
		return false
	if not data.get("stock_worker_hired") is bool: return false
	if data["worker_carried_stock"] > 0 and not data["stock_worker_hired"]: return false
	if data["billing_start_day"] < 1 or data["billing_start_day"] > saved_day or data["last_billed_day"] != saved_day:
		return false
	if data["operating_expenses"] + data["operating_due"] != (saved_day - data["billing_start_day"]) * DAILY_SHOP_COST:
		return false
	var expected_wages := int(relations.retired_wage_days) * DAILY_WORKER_WAGE
	var warehouse_record: Dictionary = relations.records.get("warehouse", EmployeeRelations.fresh_record())
	var warehouse_hired_day: int = int(data.get("warehouse_worker_hired_day", 0))
	if data.get("warehouse_worker_hired", false):
		if warehouse_hired_day < data.billing_start_day or warehouse_hired_day > saved_day or warehouse_record.quit_day > 0 and warehouse_record.quit_day < warehouse_hired_day: return false
		expected_wages += ((int(warehouse_record.quit_day) + 1 if warehouse_record.quit_day > 0 else int(saved_day)) - warehouse_hired_day) * DAILY_WORKER_WAGE
	else:
		if warehouse_hired_day != 0: return false
		var fresh := EmployeeRelations.fresh_record()
		for field in fresh:
			if warehouse_record.get(field, fresh[field]) != fresh[field]: return false
	for pair in [["worker_hired", "worker_hired_day"], ["stock_worker_hired", "stock_worker_hired_day"]]:
		var record: Dictionary = relations.records["cashier" if pair[0] == "worker_hired" else "stock"]
		if data[pair[0]]:
			if data[pair[1]] < data["billing_start_day"] or data[pair[1]] > saved_day: return false
			if record.quit_day > 0 and record.quit_day < data[pair[1]]: return false
			expected_wages += ((int(record.quit_day) + 1 if record.quit_day > 0 else int(saved_day)) - int(data[pair[1]])) * DAILY_WORKER_WAGE
		else:
			if data[pair[1]] != 0: return false
			var fresh := EmployeeRelations.fresh_record()
			for field in fresh:
				if record[field] != fresh[field]: return false
	if data["wage_expenses"] + data["wages_due"] != expected_wages: return false
	for field in ["operating_expenses", "operating_due"]:
		if int(data[field]) % DAILY_SHOP_COST != 0:
			return false
	for field in ["wage_expenses", "wages_due"]:
		if int(data[field]) % DAILY_WORKER_WAGE != 0:
			return false
	# A home is either bought (older saves) or the family home given at start (free).
	if int(data["property_expenses"]) not in ([0, HOUSE_COST] if data["house_owned"] else [0]):
		return false
	if data["last_visit"].length() > 64:
		return false
	var allowed_visits: Array[String] = ["No customers yet", "Out of stock", "Price too high", "Offer refused", "Customer left"]
	for sale_price in range(50, 201, 10):
		allowed_visits.append("Bought for %s%d" % [String.chr(8377), sale_price])
	if data["last_visit"] not in allowed_visits:
		return false
	var duration = data.get("marketing_seconds_left")
	if not (duration is int or duration is float) or not is_finite(float(duration)):
		return false
	if duration < 0.0 or duration > MARKETING_DURATION:
		return false
	if duration > 0.0 and data["marketing_expenses"] < MARKETING_COST:
		return false
	var price := int(data["selling_price"])
	if price < 50 or price > 200 or price % 10 != 0:
		return false
	var extra_cost := 0
	var extra_sold := 0
	var extra_stock := 0
	var extra_purchased := 0
	for id in Catalog.EXTRA:
		var item: Dictionary = data.inventory.get(id, Catalog.fresh_item(id))
		var farm_units: int = farm_data.harvested if id == "tomato" else 0
		if farm_units > item.purchased: return false
		extra_cost += (int(item.purchased) - farm_units) / 10 * Catalog.COSTS[id]
		extra_purchased += int(item.purchased)
		extra_sold += int(item.sold)
		extra_stock += int(item.stock)
		if item.stock + supply_by_product[id] != item.purchased - item.sold: return false
	var bottle_cost := int(data.restocking_expenses) - extra_cost
	if bottle_cost < 0 or bottle_cost % STOCK_COST != 0 or int(data["marketing_expenses"]) % MARKETING_COST != 0:
		return false
	if int(data["hiring_expenses"]) != int(relations.retired_hiring) + CASHIER_COSTS[int(data["cashier_level"]) - 1] * int(data["worker_hired"]) + HIRING_COST * (int(data["stock_worker_hired"]) + int(data.get("warehouse_worker_hired", false))):
		return false
	var revenue := int(data["sales_revenue"])
	var sold := int(data["items_sold"])
	if demo_data.revenue > revenue or demo_data.customers_served > sold: return false
	if extra_sold > sold or extra_stock > data.stock: return false
	if revenue % 10 != 0 or revenue < sold * 50 or revenue > sold * 200:
		return false
	var expenses := int(data["restocking_expenses"]) + int(data["marketing_expenses"]) + int(data["hiring_expenses"]) + int(data["operating_expenses"]) + int(data["wage_expenses"]) + int(data["upgrade_expenses"]) + int(data.overtime_expenses) + int(furnishing) + farm_state.expenses()
	if int(data["money"]) != INITIAL_MONEY + revenue - expenses - int(data["property_expenses"]):
		return false
	var purchased_stock := bottle_cost / STOCK_COST * STOCK_AMOUNT + extra_purchased
	return int(data["stock"]) + stored_supply == INITIAL_STOCK + purchased_stock - sold
