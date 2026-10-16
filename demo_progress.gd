extends RefCounted

const MAX_VALUE := 1000000000
var ordered := false
var player_shelved := 0
var customers_served := 0
var revenue := 0
var worker_stocked := false
var completion_seen := false

func completed() -> bool:
	return ordered and player_shelved >= 10 and customers_served >= 10 and worker_stocked and revenue >= 2000

func record(action: String, amount := 1) -> void:
	if completed() or amount <= 0: return
	match action:
		"order": ordered = true
		"shelve": player_shelved = mini(10, player_shelved + amount)
		"worker": worker_stocked = true
		"sale":
			customers_served += 1
			revenue += amount

func goal_lines() -> Array[String]:
	return [
		"Order products: %d/1" % int(ordered),
		"Stock 10 items yourself: %d/10" % player_shelved,
		"Serve customers: %d/10" % mini(10, customers_served),
		"Sunil stocks a box: %d/1" % int(worker_stocked),
		"Sales: %s%d / %s2,000" % [String.chr(8377), mini(2000, revenue), String.chr(8377)]
	]

# Live "what to do right now" hint for the current goal, read from backend state.
func next_step(business) -> String:
	if completed(): return ""
	var has_box: bool = business.boxed_stock > 0 or not business.queued_boxes.is_empty()
	var stored: bool = not business.logistics.storage.is_empty()
	var box_step := ""
	if business.carried_stock > 0: box_step = "Walk into the shop, aim at a shelf and press E to place items."
	elif has_box: box_step = "Pick up the box at the warehouse delivery bay (E)."
	elif stored: box_step = "Pick up a stored box from the warehouse racks (E)."
	elif business.supply_in_transit > 0: box_step = "Delivery truck is on the way to the warehouse."
	match done_flags().find(false):
		0:
			return "Cross the road to the warehouse office. Aim at the PC, press E and open Orders."
		1:
			return box_step if not box_step.is_empty() else "Order another box at the warehouse PC."
		3:
			if not business.stock_worker_hired: return "Hire Sunil: warehouse PC > Team (Rs1,000)."
			if not business.stock_worker_on_shift(): return "Wait for Sunil's shift, or change his hours on the PC."
			if business.worker_carried_stock > 0: return "Sunil is carrying a box to the shelves."
			if has_box: return "Open the tablet (E in shop) > Staff and press Collect delivery."
			return "Order a box so Sunil has something to stock."
	# Goals 2 and 4: serve customers / reach sales.
	if not business.shop_is_open(): return "Shop opens at 08:00. Sleep at home or wait."
	if business.stock <= 0: return box_step if not box_step.is_empty() else "Shelves are empty. Order and stock products."
	return "Stand behind the counter and scan each item when customers queue."

func done_flags() -> Array[bool]:
	return [ordered, player_shelved >= 10, customers_served >= 10, worker_stocked, revenue >= 2000]

func snapshot() -> Dictionary:
	return {"ordered": ordered, "player_shelved": player_shelved, "customers_served": customers_served, "revenue": revenue, "worker_stocked": worker_stocked, "completion_seen": completion_seen}

func restore(data: Dictionary) -> void:
	for field in ["ordered", "worker_stocked", "completion_seen"]: set(field, data[field])
	for field in ["player_shelved", "customers_served", "revenue"]: set(field, int(data[field]))

static func valid(data) -> bool:
	if not data is Dictionary: return false
	for field in ["ordered", "worker_stocked", "completion_seen"]:
		if not data.get(field) is bool: return false
	for field in ["player_shelved", "customers_served", "revenue"]:
		var value = data.get(field)
		if not (value is int or value is float) or not is_finite(float(value)): return false
		if value < 0 or value > (10 if field == "player_shelved" else MAX_VALUE) or value != int(value): return false
	if int(data.revenue) % 10 != 0 or data.revenue < data.customers_served * 50 or data.revenue > data.customers_served * 1000: return false
	return not data.completion_seen or (data.ordered and data.player_shelved >= 10 and data.customers_served >= 10 and data.worker_stocked and data.revenue >= 2000)
