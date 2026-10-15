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
	if int(data.revenue) % 10 != 0 or data.revenue < data.customers_served * 50 or data.revenue > data.customers_served * 600: return false
	return not data.completion_seen or (data.ordered and data.player_shelved >= 10 and data.customers_served >= 10 and data.worker_stocked and data.revenue >= 2000)
