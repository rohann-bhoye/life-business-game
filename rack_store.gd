extends RefCounted

const Catalog = preload("res://product_catalog.gd")
const COST := 1000
const MAX_RACKS := 8
const SHELVES := 3
const SHELF_CAPACITY := 10
const FLOOR := Rect2(-5.97, -7.42, 5.91, 9.84)
const ENTRY := Vector3(-3, 0.1, 1.65)
const FURNITURE := [Rect2(-3.95, -0.02, 2.9, 0.84), Rect2(-1.8, -1.97, 1.4, 0.8)]
const RESERVED := [Rect2(-5.04, -7.42, 0.88, 9.84), Rect2(-4.95, 0.9, 4.4, 1.5)]
var records: Array = fresh()
var grid: AStarGrid2D
var grid_key := ""
var last_added_slot := -1

static func migrate_record(record: Dictionary) -> void:
	if record.has("slots"): return
	var remaining := int(record.amount)
	var slots: Array = []
	for index in range(slot_count(record)):
		var count := mini(remaining, SHELF_CAPACITY)
		slots.append({"product": record.product, "count": count})
		remaining -= count
	record["slots"] = slots
	record["legacy_overflow"] = remaining

static func slot_count(record: Dictionary) -> int:
	return 12 if record.get("display", "shelf") == "produce" else SHELVES

static func count_product(record: Dictionary, product: String) -> int:
	if not record.has("slots"): return int(record.amount) if record.product == product else 0
	var count := int(record.get("legacy_overflow", 0)) if record.product == product else 0
	for slot in record.slots:
		if slot.product == product: count += int(slot.count)
	return count

static func supports(record: Dictionary, product: String) -> bool:
	if not record.has("slots"): return record.product == product
	for slot in record.slots:
		if slot.product in [product, ""]: return true
	return false

func free_space(id: int, product: String) -> int:
	var record := find(id)
	if record.is_empty(): return 0
	migrate_record(record)
	if int(record.legacy_overflow) > 0: return 0
	var space := 0
	for slot in record.slots:
		if slot.product in [product, ""]: space += SHELF_CAPACITY - int(slot.count)
	return space

func restock_rack(product: String) -> int:
	for record in records:
		if record.product == product and record.get("restock", record.id < 3) and free_space(record.id, product) > 0: return record.id
	for record in records:
		if free_space(record.id, product) > 0: return record.id
	return -1

func assign_slot(id: int, index: int, product: String) -> bool:
	var record := find(id)
	if record.is_empty() or index < 0 or index >= slot_count(record) or product not in Catalog.IDS + [""]: return false
	migrate_record(record)
	var slot: Dictionary = record.slots[index]
	if int(slot.count) > 0 or int(record.legacy_overflow) > 0: return false
	slot.product = product
	return true

static func fresh(stock := 10, inventory := {}) -> Array:
	var result: Array = []
	for index in range(3):
		var product: String = Catalog.IDS[index]
		var amount := stock if index == 0 else int(inventory.get(product, {}).get("stock", 0))
		if index == 0:
			for id in ["snack", "soap"]: amount -= int(inventory.get(id, {}).get("stock", 0))
		result.append({"id": index, "product": product, "x": -5.6, "z": [-0.5, -3.3, -6.0][index], "turn": 0, "amount": amount, "restock": true})
		migrate_record(result[-1])
	return result

func find(id: int) -> Dictionary:
	for record in records:
		if record.id == id: return record
	return {}

static func point(record: Dictionary) -> Vector3:
	return Vector3(record.x, 0.1, record.z)

static func approach(record: Dictionary) -> Vector3:
	var angle := int(record.turn) * PI / 2
	return point(record) + Vector3(cos(angle), 0, -sin(angle))

static func footprint(record: Dictionary) -> Rect2:
	var size := Vector2(0.7, 2.16) if int(record.turn) % 2 == 0 else Vector2(2.16, 0.7)
	return Rect2(Vector2(record.x, record.z) - size / 2, size)

static func geometry_error(layout: Array) -> String:
	for record in layout:
		var area := footprint(record)
		if not FLOOR.encloses(area): return "Keep the rack inside the shop."
		var service := approach(record)
		if not FLOOR.grow(-0.3).has_point(Vector2(service.x, service.z)): return "Turn the rack toward a clear aisle."
		for reserved in RESERVED + FURNITURE:
			if area.intersects(reserved.grow(0.08)): return "Keep doors, queues and working aisles clear."
		for other in layout:
			if other.id != record.id and area.grow(0.12).intersects(footprint(other)): return "Too close to another rack."
	return ""

func _navigation(layout: Array) -> AStarGrid2D:
	var key := ""
	for item in layout: key += str([item.id, item.x, item.z, item.turn])
	if grid != null and key == grid_key: return grid
	grid_key = key
	grid = AStarGrid2D.new()
	grid.region = Rect2i(-23, -28, 23, 37)
	grid.cell_size = Vector2.ONE * 0.25
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var obstacles: Array = FURNITURE.duplicate()
	for item in layout: obstacles.append(footprint(item))
	for y in range(-28, 9):
		for x in range(-23, 0):
			var position := Vector2(x, y) * 0.25
			var blocked := not FLOOR.grow(-0.28).has_point(position)
			for area in obstacles:
				if area.grow(0.3).has_point(position): blocked = true
			grid.set_point_solid(Vector2i(x, y), blocked)
	return grid

func route(from: Vector3, to: Vector3, layout: Array = []) -> Array[Vector3]:
	if layout.is_empty(): layout = records
	var navigation := _navigation(layout)
	var start := Vector2i(roundi(from.x * 4), roundi(from.z * 4))
	var finish := Vector2i(roundi(to.x * 4), roundi(to.z * 4))
	var result: Array[Vector3] = []
	if not navigation.is_in_boundsv(start) or not navigation.is_in_boundsv(finish): return result
	if navigation.is_point_solid(start) or navigation.is_point_solid(finish): return result
	for position in navigation.get_point_path(start, finish): result.append(Vector3(position.x, 0.1, position.y))
	if not result.is_empty(): result.append(to)
	return result

func placement_error(candidate: Dictionary) -> String:
	var layout: Array = records.duplicate(true)
	var found := false
	for index in range(layout.size()):
		if layout[index].id == candidate.id:
			layout[index] = candidate
			found = true
	if not found: layout.append(candidate)
	var error := geometry_error(layout)
	if not error.is_empty(): return error
	for item in layout:
		if route(ENTRY, approach(item), layout).is_empty(): return "Leave a reachable aisle in front of every rack."
	return ""

func add_stock(product: String, amount: int, id := -1) -> bool:
	if amount <= 0: return false
	if id < 0: id = restock_rack(product)
	var record := find(id)
	if record.is_empty() or free_space(id, product) < amount: return false
	var remaining := amount
	# Fill assigned rows first; unassigned rows become this SKU only when needed.
	for empty in [false, true]:
		for index in range(slot_count(record)):
			var slot: Dictionary = record.slots[index]
			if slot.product != ("" if empty else product) or remaining == 0: continue
			var added := mini(remaining, SHELF_CAPACITY - int(slot.count))
			if added <= 0: continue
			slot.product = product
			slot.count += added
			remaining -= added
			last_added_slot = index
	record.amount += amount
	return true

func remove_stock(product: String, amount: int, id := -1) -> bool:
	if amount <= 0: return false
	var chosen: Array = records if id < 0 else [find(id)]
	var available := 0
	for item in chosen:
		if not item.is_empty(): available += count_product(item, product)
	if available < amount: return false
	for item in chosen:
		if item.is_empty(): continue
		migrate_record(item)
		for slot in item.slots:
			if slot.product != product: continue
			var used := mini(amount, int(slot.count))
			slot.count -= used
			item.amount -= used
			amount -= used
		if item.product == product:
			var used := mini(amount, int(item.legacy_overflow))
			item.legacy_overflow -= used
			item.amount -= used
			amount -= used
			for slot in item.slots:
				var refill := mini(int(item.legacy_overflow), SHELF_CAPACITY - int(slot.count))
				slot.count += refill
				item.legacy_overflow -= refill
	return true

static func valid(layout, stock: int, inventory: Dictionary) -> bool:
	if not layout is Array or layout.size() < 3 or layout.size() > MAX_RACKS: return false
	var totals := {"bottle": 0, "snack": 0, "soap": 0, "tomato": 0}
	var destinations := {"bottle": 0, "snack": 0, "soap": 0}
	for index in range(layout.size()):
		var item = layout[index]
		if not item is Dictionary or item.get("product") not in Catalog.IDS: return false
		for field in ["id", "turn", "amount"]:
			var value = item.get(field)
			if not value is int and not value is float: return false
			if not is_finite(float(value)) or value < 0 or value != int(value): return false
		if item.id != index or item.turn > 3 or item.amount > 1000000000: return false
		if index < 3 and item.product != Catalog.IDS[index]: return false
		if item.get("display", "shelf") not in ["shelf", "produce"]: return false
		if index < 3 and item.get("display", "shelf") != "shelf": return false
		if not item.get("restock", index < 3) is bool: return false
		if item.get("restock", index < 3) and destinations.has(item.product): destinations[item.product] += 1
		for field in ["x", "z"]:
			var value = item.get(field)
			if not value is int and not value is float: return false
			if not is_finite(float(value)) or absf(float(value)) > 10: return false
		if item.has("slots"):
			if not item.slots is Array or item.slots.size() != slot_count(item): return false
			var overflow = item.get("legacy_overflow", 0)
			if not (overflow is int or overflow is float) or not is_finite(float(overflow)) or overflow < 0 or overflow > 1000000000 or overflow != int(overflow): return false
			var total := int(overflow)
			totals[item.product] += int(overflow)
			for slot in item.slots:
				if not slot is Dictionary or slot.get("product") not in Catalog.IDS + [""]: return false
				var count = slot.get("count")
				if not (count is int or count is float) or not is_finite(float(count)) or count < 0 or count > SHELF_CAPACITY or count != int(count): return false
				if slot.product == "" and count != 0: return false
				if overflow > 0 and (slot.product != item.product or count != SHELF_CAPACITY): return false
				total += int(count)
				if slot.product != "": totals[slot.product] += int(count)
			if total != int(item.amount): return false
		else: totals[item.product] += int(item.amount)
	if not geometry_error(layout).is_empty() or destinations.values().any(func(count): return count != 1): return false
	return totals.snack == int(inventory.snack.stock) and totals.soap == int(inventory.soap.stock) and totals.tomato == int(inventory.get("tomato", {}).get("stock", 0)) and totals.bottle == stock - totals.snack - totals.soap - totals.tomato
