extends RefCounted

const Catalog = preload("res://product_catalog.gd")
const COST := 1000
## Racks a save may hold; how many fit today is rack_limit() (more after expansions).
const MAX_RACKS := 20
const BASE_RACKS := 8
const RACKS_PER_EXPANSION := 2
const SHELVES := 3
const SHELF_CAPACITY := 10
## The shop floor before any expansion; each bought expansion (PC: Space) moves the
## back wall EXPANSION_DEPTH further back.
const FLOOR := Rect2(-5.97, -7.42, 5.91, 9.84)
const EXPANSION_DEPTH := 2.25
const MAX_EXPANSION := 2
## Side wings over the plot east of the shop (business_backend.gd shop_wing): how much wider
## the floor gets (m) and the racks each adds. They need both back expansions first, so the
## floor stays one rectangle.
const WING_WIDTHS := [0.0, 4.2, 8.4]
const MAX_WING := 2
const RACKS_PER_WING := 4
## Grid cells east of x 0 the shopper paths cover (the widest wing, 0.25 m cells).
const GRID_EAST := 34
## The wings' fittings (shop_operations.gd _build_wing places the Blender models): [the wing
## that brings them, what, floor (world x, z)]. Racks, the counter, the desk and shopper paths
## keep clear of them.
const WING_FITTINGS := [
	[1, "trolleys", Rect2(0.8, 1.37, 2.0, 0.76)],
	[1, "coolers", Rect2(0.1, -11.92, 3.05, 0.75)],
	[2, "coolers", Rect2(7.54, -11.15, 0.8, 4.6)],
	[2, "freezer", Rect2(5.475, -3.5, 0.85, 1.8)],
	[2, "freezer", Rect2(5.475, -6.3, 0.85, 1.8)],
]
const ENTRY := Vector3(-3, 0.1, 1.65)
## The stock worker's back aisle and the doorway: nothing is ever built there.
const RESERVED := [Rect2(-5.04, -7.42, 0.88, 9.84), Rect2(-3.9, 1.2, 1.8, 1.25)]
## Shop furniture the player can move with G: where each starts and its floor size.
const FIXTURE_HOME := {"counter": {"x": -2.5, "z": 0.4, "turn": 0}, "desk": {"x": -1.1, "z": -1.57, "turn": 0}}
const FIXTURE_SIZE := {"counter": Vector2(2.9, 0.84), "desk": Vector2(1.4, 0.8)}
## In the counter's own frame (+z is the customer side): the queue in front and
## the cashier's space behind it stay clear.
const QUEUE_ZONE := Rect2(-2.45, 0.5, 4.4, 1.5)
const CASHIER_ZONE := Rect2(-1.5, -1.55, 2.7, 1.13)
var records: Array = fresh()
var fixtures: Dictionary = FIXTURE_HOME.duplicate(true)
## Bought shop expansions (business_backend.gd shop_expansion keeps this in step).
var expansion := 0
## Built side wings (business_backend.gd shop_wing keeps this in step).
var wing := 0

static func floor_rect(expansion_level: int, wing_level := 0) -> Rect2:
	var extra := clampi(expansion_level, 0, MAX_EXPANSION) * EXPANSION_DEPTH
	var wider: float = WING_WIDTHS[clampi(wing_level, 0, MAX_WING)]
	return Rect2(FLOOR.position.x, FLOOR.position.y - extra, FLOOR.size.x + wider, FLOOR.size.y + extra)

static func rack_limit(expansion_level: int, wing_level := 0) -> int:
	return BASE_RACKS + clampi(expansion_level, 0, MAX_EXPANSION) * RACKS_PER_EXPANSION + clampi(wing_level, 0, MAX_WING) * RACKS_PER_WING

## The floor the built wings' fittings stand on.
static func wing_fittings(wing_level: int) -> Array[Rect2]:
	var areas: Array[Rect2] = []
	for entry in WING_FITTINGS:
		if int(entry[0]) <= wing_level: areas.append(entry[2])
	return areas
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

## Where products go. A fridge only ever holds drinks. In new games (`strict`, one
## free rack) fruit and vegetables also need produce baskets, and packed goods
## shelf racks, like real store sims; older saves keep their mixed shelves.
const FRIDGE_PRODUCTS := ["bottle", "milk"]
const PRODUCE_PRODUCTS := ["tomato", "carrot", "cabbage", "corn", "apple"]
var strict := false

static func display_for(product: String) -> String:
	return "produce" if product in PRODUCE_PRODUCTS else ("fridge" if product in FRIDGE_PRODUCTS else "shelf")

static func holds(record: Dictionary, product: String, strict_rules := false) -> bool:
	var display: String = record.get("display", "shelf")
	if display == "fridge": return product in FRIDGE_PRODUCTS
	if not strict_rules: return true
	return display == display_for(product)

## What to tell a player carrying `product` to the wrong kind of rack.
static func place_hint(product: String) -> String:
	match display_for(product):
		"fridge": return "%s goes in a fridge (PC: Wholesale > Furniture)." % Catalog.NAMES[product]
		"produce": return "%s goes in produce baskets (a produce table)." % Catalog.NAMES[product]
	return "%s goes on a shelf rack." % Catalog.NAMES[product]

static func supports(record: Dictionary, product: String, strict_rules := false) -> bool:
	if not holds(record, product, strict_rules): return false
	if not record.has("slots"): return record.product == product
	for slot in record.slots:
		if slot.product in [product, ""] or int(slot.count) == 0: return true
	return false

func free_space(id: int, product: String) -> int:
	var record := find(id)
	if record.is_empty(): return 0
	migrate_record(record)
	if int(record.legacy_overflow) > 0 or not holds(record, product, strict): return 0
	var space := 0
	for slot in record.slots:
		if slot.product in [product, ""] or int(slot.count) == 0: space += SHELF_CAPACITY - int(slot.count)
	return space

func restock_rack(product: String) -> int:
	for record in records:
		if record.product == product and record.get("restock", record.id < 3) and free_space(record.id, product) > 0: return record.id
	for record in records:
		if free_space(record.id, product) > 0: return record.id
	return -1

func assign_slot(id: int, index: int, product: String) -> bool:
	var record := find(id)
	if record.is_empty() or index < 0 or index >= slot_count(record) or product not in Catalog.IDS + [""] or product != "" and not holds(record, product, strict): return false
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

## A point given in a fixture's own frame, on the shop floor.
static func fixture_point(fixture: Dictionary, local: Vector2) -> Vector2:
	var angle := int(fixture.turn) * PI / 2
	return Vector2(fixture.x, fixture.z) + Vector2(local.x * cos(angle) + local.y * sin(angle), -local.x * sin(angle) + local.y * cos(angle))

static func fixture_rect(fixture: Dictionary, local: Rect2) -> Rect2:
	return Rect2(fixture_point(fixture, local.position), Vector2.ZERO).expand(fixture_point(fixture, local.end))

static func fixture_body(fixture_name: String, fixture: Dictionary) -> Rect2:
	var size: Vector2 = FIXTURE_SIZE[fixture_name]
	return fixture_rect(fixture, Rect2(-size / 2, size))

## Floor racks must keep clear of: the aisles, both fixtures and the queue (and,
## for a rack being placed now, the cashier's space too).
static func blocked_areas(fx: Dictionary, strict := false) -> Array:
	var areas: Array = RESERVED.duplicate()
	for fixture_name in FIXTURE_SIZE: areas.append(fixture_body(fixture_name, fx[fixture_name]))
	areas.append(fixture_rect(fx.counter, QUEUE_ZONE))
	if strict: areas.append(fixture_rect(fx.counter, CASHIER_ZONE))
	return areas

static func geometry_error(layout: Array, fx: Dictionary = {}, strict_id := -1, expansion_level := 0, wing_level := 0) -> String:
	if fx.is_empty(): fx = FIXTURE_HOME
	var floor_area := floor_rect(expansion_level, wing_level)
	for record in layout:
		var area := footprint(record)
		if not floor_area.encloses(area): return "Keep the rack inside the shop."
		var service := approach(record)
		if not floor_area.grow(-0.3).has_point(Vector2(service.x, service.z)): return "Turn the rack toward a clear aisle."
		for reserved in blocked_areas(fx, int(record.id) == strict_id):
			if area.intersects(reserved.grow(0.08)): return "Keep doors, queues and working aisles clear."
		for fitting in wing_fittings(wing_level):
			if area.intersects(fitting.grow(0.1)): return "Keep the coolers, freezers and trolleys clear."
		for other in layout:
			if other.id != record.id and area.grow(0.12).intersects(footprint(other)): return "Too close to another rack."
	return ""

func _navigation(layout: Array, fx: Dictionary) -> AStarGrid2D:
	var key := str(fx) + str(expansion) + "w" + str(wing)
	for item in layout: key += str([item.id, item.x, item.z, item.turn])
	if grid != null and key == grid_key: return grid
	grid_key = key
	grid = AStarGrid2D.new()
	# 0.25 m cells over the largest shop (two expansions, two wings) and the doorway.
	grid.region = Rect2i(-23, -50, 23 + GRID_EAST, 59)
	grid.cell_size = Vector2.ONE * 0.25
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var obstacles: Array = []
	for fixture_name in FIXTURE_SIZE: obstacles.append(fixture_body(fixture_name, fx[fixture_name]))
	for item in layout: obstacles.append(footprint(item))
	obstacles.append_array(wing_fittings(wing))
	var floor_area := floor_rect(expansion, wing)
	for y in range(-50, 9):
		for x in range(-23, GRID_EAST):
			var position := Vector2(x, y) * 0.25
			var blocked := not floor_area.grow(-0.28).has_point(position)
			for area in obstacles:
				if area.grow(0.3).has_point(position): blocked = true
			grid.set_point_solid(Vector2i(x, y), blocked)
	return grid

func route(from: Vector3, to: Vector3, layout: Array = [], fx: Dictionary = {}) -> Array[Vector3]:
	if layout.is_empty(): layout = records
	if fx.is_empty(): fx = fixtures
	var navigation := _navigation(layout, fx)
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
	var error := geometry_error(layout, fixtures, int(candidate.id), expansion, wing)
	if not error.is_empty(): return error
	for item in layout:
		if route(ENTRY, approach(item), layout).is_empty(): return "Leave a reachable aisle in front of every rack."
	for point in service_points(fixtures):
		if route(ENTRY, point, layout).is_empty(): return "Leave a way to the counter and the PC."
	return ""

## Where people stand to use the fixtures: the front and the end of the queue,
## the cashier's spot and the PC.
static func service_points(fx: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for spot in [[fx.counter, Vector2(0, 0.8)], [fx.counter, Vector2(-2.1, 1.25)], [fx.counter, Vector2(0, -1.0)], [fx.desk, Vector2(0, 0.85)]]:
		var floor_point := fixture_point(spot[0], spot[1])
		points.append(Vector3(floor_point.x, 0.1, floor_point.y))
	return points

## Why a fixture can't stand at `candidate` ({x, z, turn}); "" when it can.
func fixture_error(fixture_name: String, candidate: Dictionary) -> String:
	var fx: Dictionary = fixtures.duplicate(true)
	fx[fixture_name] = candidate
	var bodies := {}
	for key in FIXTURE_SIZE: bodies[key] = fixture_body(key, fx[key])
	var floor_area := floor_rect(expansion, wing)
	for key in bodies:
		if not floor_area.encloses(bodies[key]): return "Keep it inside the shop."
		for fitting in wing_fittings(wing):
			if bodies[key].intersects(fitting.grow(0.1)): return "Keep it clear of the coolers, freezers and trolleys."
		for reserved in RESERVED:
			if bodies[key].intersects(reserved.grow(0.08)): return "Keep the door and the back aisle clear."
	if bodies.counter.intersects(bodies.desk.grow(0.12)): return "Too close to the other furniture."
	for zone in [fixture_rect(fx.counter, QUEUE_ZONE), fixture_rect(fx.counter, CASHIER_ZONE)]:
		if not floor_area.encloses(zone): return "Turn the counter so customers can queue in front."
		if zone.intersects(bodies.desk): return "Keep the queue and the cashier's space clear."
	var moved: Array = [bodies[fixture_name]]
	if fixture_name == "counter": moved.append_array([fixture_rect(fx.counter, QUEUE_ZONE), fixture_rect(fx.counter, CASHIER_ZONE)])
	for record in records:
		for area in moved:
			if footprint(record).intersects(area.grow(0.08)): return "A rack is in the way."
	for item in records:
		if route(ENTRY, approach(item), records, fx).is_empty(): return "Leave an aisle to every rack."
	for point in service_points(fx):
		if route(ENTRY, point, records, fx).is_empty(): return "Leave a way to the counter and the PC."
	return ""

## Saved fixture places: known names, finite numbers and quarter turns.
static func fixtures_valid(fx) -> bool:
	if not fx is Dictionary or fx.size() != FIXTURE_HOME.size(): return false
	for fixture_name in FIXTURE_HOME:
		var item = fx.get(fixture_name)
		if not item is Dictionary: return false
		for field in ["x", "z", "turn"]:
			var value = item.get(field)
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > 16: return false
		if item.turn < 0 or item.turn > 3 or item.turn != int(item.turn): return false
	return true

func add_stock(product: String, amount: int, id := -1) -> bool:
	if amount <= 0: return false
	if id < 0: id = restock_rack(product)
	var record := find(id)
	if record.is_empty() or free_space(id, product) < amount: return false
	var remaining := amount
	# Fill rows already holding/assigned to this SKU first; any empty row then
	# takes it, so every rack can hold a mix of products (one SKU per row).
	for empty in [false, true]:
		for index in range(slot_count(record)):
			var slot: Dictionary = record.slots[index]
			if remaining == 0 or (int(slot.count) > 0 if empty else slot.product != product): continue
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

## `base`: the free starting racks (3 in older games, 1 in games started from the
## menu now); they stay in the shop and keep their first products.
static func valid(layout, stock: int, inventory: Dictionary, fx = FIXTURE_HOME, expansion_level := 0, base := 3, wing_level := 0) -> bool:
	if not fixtures_valid(fx): return false
	if not layout is Array or layout.size() < base or layout.size() > rack_limit(expansion_level, wing_level): return false
	# New games' one free rack is the cold-drink fridge.
	var base_displays: Array = ["shelf", "fridge"] if base == 1 else ["shelf"]
	var totals := {}
	for id in Catalog.IDS: totals[id] = 0
	var destinations := {"bottle": 0, "snack": 0, "soap": 0}
	for index in range(layout.size()):
		var item = layout[index]
		if not item is Dictionary or item.get("product") not in Catalog.IDS: return false
		for field in ["id", "turn", "amount"]:
			var value = item.get(field)
			if not value is int and not value is float: return false
			if not is_finite(float(value)) or value < 0 or value != int(value): return false
		if item.id != index or item.turn > 3 or item.amount > 1000000000: return false
		if index < base and item.product != Catalog.IDS[index]: return false
		if item.get("display", "shelf") not in ["shelf", "produce", "fridge"]: return false
		if index < base and item.get("display", "shelf") not in base_displays: return false
		if not item.get("restock", index < base) is bool: return false
		if item.get("restock", index < base) and destinations.has(item.product): destinations[item.product] += 1
		for field in ["x", "z"]:
			var value = item.get(field)
			if not value is int and not value is float: return false
			if not is_finite(float(value)) or absf(float(value)) > 16: return false
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
	if not geometry_error(layout, fx, -1, expansion_level, wing_level).is_empty(): return false
	# One restock rack per product at most; the starting racks' products always have one.
	for product in destinations:
		if destinations[product] > 1 or Catalog.IDS.find(product) < base and destinations[product] != 1: return false
	var extras := 0
	for id in Catalog.EXTRA:
		if totals[id] != int(inventory.get(id, {}).get("stock", 0)): return false
		extras += totals[id]
	return totals.bottle == stock - extras
