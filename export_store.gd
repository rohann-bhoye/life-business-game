extends RefCounted

# International (export) orders, saved with the business (business_backend.gd):
# buyers abroad ask for a box of Indian shop products. The player accepts an order
# on the shop PC (APNA Export), fills an open carton at the racks, seals it at the
# prepare-order table in the packing room and carries the parcel to the export
# platform at the airport; the cargo plane (export_world.gd) picks parcels up at the
# flight times and the buyer pays then.
# Order states: "offer" -> "accepted" -> "packed" (sealed, its units out of the
# racks) -> "on_pad" -> shipped (removed, paid as sales).
const MAX_OFFERS := 3
const MAX_ACTIVE := 2
const OFFER_DAYS := 2
const FLIGHTS := [600, 780, 960, 1140]
const BUYERS := [
	["UAE", "Dubai", "Imran", "Snacks for the shop canteen"],
	["UK", "London", "Priya", "Diwali box for the family"],
	["Singapore", "Singapore", "Wei Ling", "Indian kitchen basics"],
	["USA", "New York", "Rahul", "A taste of home"],
	["Canada", "Toronto", "Gurpreet", "Gifts for the gurdwara langar"],
	["Australia", "Sydney", "Ananya", "Student hostel treats"],
	["Kenya", "Nairobi", "Mehul", "Restock for my duka"],
]
var orders: Array = []
var next_id := 1
var shipped := 0
var earned := 0

## The buyer's price for one unit: half again the shop price, at most Rs200.
static func unit_price(shop_price: int) -> int:
	return clampi(ceili(shop_price * 1.5 / 10.0) * 10, 50, 200)

static func units(order: Dictionary) -> int:
	var total := 0
	for line in order.lines: total += int(line.count)
	return total

func find(id: int) -> Dictionary:
	for order in orders:
		if int(order.id) == id: return order
	return {}

func active() -> Array:
	return orders.filter(func(order): return order.state != "offer")

func in_state(state: String) -> Array:
	return orders.filter(func(order): return order.state == state)

## New day: offers and accepted orders past their day go; fresh offers fill up to
## MAX_OFFERS. `available` is product -> {price, stock} for licensed products on the
## shelves: buyers only ask for those, never more than there are.
func refresh(day: int, available: Dictionary) -> void:
	orders = orders.filter(func(order): return order.state in ["packed", "on_pad"] or int(order.expires) >= day)
	# Offers for goods no longer on the shelves (or no longer enough) are withdrawn.
	orders = orders.filter(func(order): return order.state != "offer" or order.lines.all(func(line): return available.has(line.product) and int(available[line.product].stock) >= int(line.count)))
	var products: Array = available.keys()
	if products.is_empty(): return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while in_state("offer").size() < MAX_OFFERS:
		# A different city for each open order.
		var taken: Array = orders.map(func(order): return order.city)
		var free: Array = BUYERS.filter(func(entry): return entry[1] not in taken)
		var buyer: Array = (free if not free.is_empty() else BUYERS)[rng.randi_range(0, (free if not free.is_empty() else BUYERS).size() - 1)]
		products.shuffle()
		var lines: Array = []
		var value := 0
		for product in products.slice(0, mini(rng.randi_range(1, 3), products.size())):
			var count := rng.randi_range(1, mini(3, int(available[product].stock)))
			var unit := unit_price(int(available[product].price))
			lines.append({"product": product, "count": count, "unit": unit})
			value += unit * count
		orders.append({"id": next_id, "country": buyer[0], "city": buyer[1], "buyer": buyer[2], "note": buyer[3], "lines": lines, "value": value, "expires": day + OFFER_DAYS, "state": "offer"})
		next_id += 1

func snapshot() -> Dictionary:
	return {"orders": orders.duplicate(true), "next_id": next_id, "shipped": shipped, "earned": earned}

func restore(data: Dictionary) -> void:
	orders = (data.get("orders", []) as Array).duplicate(true)
	for order in orders:
		order.id = int(order.id)
		order.value = int(order.value)
		order.expires = int(order.expires)
		for line in order.lines:
			line.count = int(line.count)
			line.unit = int(line.unit)
	next_id = int(data.get("next_id", 1))
	shipped = int(data.get("shipped", 0))
	earned = int(data.get("earned", 0))

## Saved data check: known products, 1-3 of each, Rs50-200 a unit in steps of 10,
## the value adding up and no more open work than the limits allow.
static func valid(data, catalog_ids: Array) -> bool:
	if not data is Dictionary: return false
	var saved = data.get("orders", [])
	if not saved is Array or saved.size() > MAX_OFFERS + MAX_ACTIVE + 4: return false
	var busy := 0
	for order in saved:
		if not order is Dictionary or order.get("state") not in ["offer", "accepted", "packed", "on_pad"]: return false
		for field in ["country", "city", "buyer", "note"]:
			if not order.get(field) is String or order[field].length() > 40: return false
		var lines = order.get("lines")
		if not lines is Array or lines.is_empty() or lines.size() > 3: return false
		var value := 0
		for line in lines:
			if not line is Dictionary or line.get("product") not in catalog_ids: return false
			var count = line.get("count")
			var unit = line.get("unit")
			if not (count is int or count is float) or int(count) != count or count < 1 or count > 3: return false
			if not (unit is int or unit is float) or int(unit) != unit or unit < 50 or unit > 200 or int(unit) % 10 != 0: return false
			value += int(unit) * int(count)
		if int(order.get("value", -1)) != value: return false
		if order.state != "offer": busy += 1
	if busy > MAX_ACTIVE: return false
	for field in ["next_id", "shipped", "earned"]:
		var number = data.get(field, 0)
		if not (number is int or number is float) or int(number) != number or number < 0: return false
	return true
