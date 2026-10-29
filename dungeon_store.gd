extends RefCounted

# Gufa Darwaza treasure in the save (business_backend.gd `treasure`): what the player
# has brought up from the dungeon (dungeon_world.gd banks a trip's finds on the way
# out) and what the Darwaza Guild has bought. Prices are fixed per kind, so the guild's
# income is always sold x price, which the save check adds to the money.
const ITEMS := {
	"jar": {"name": "Firefly jar", "price": 40},
	"shard": {"name": "Crystal shard", "price": 120},
	"coin": {"name": "Gold idol coin", "price": 300},
}
const MAX_COUNT := 100000

var held := {"jar": 0, "shard": 0, "coin": 0}
var sold := {"jar": 0, "shard": 0, "coin": 0}
## Deepest floor reached (1-3, 0 before the first visit).
var deepest := 0

func add(kind: String, count: int) -> void:
	if held.has(kind): held[kind] = mini(MAX_COUNT, held[kind] + maxi(0, count))

## Value of what is held now.
func value() -> int:
	var total := 0
	for kind in ITEMS: total += int(held[kind]) * int(ITEMS[kind].price)
	return total

## Money the guild has paid so far.
func income() -> int:
	return income_of(snapshot())

static func income_of(data: Dictionary) -> int:
	var total := 0
	var counts: Dictionary = data.get("sold", {})
	for kind in ITEMS: total += int(counts.get(kind, 0)) * int(ITEMS[kind].price)
	return total

## The guild buys everything held: returns what it paid.
func sell_all() -> int:
	var paid := value()
	for kind in ITEMS:
		sold[kind] = int(sold[kind]) + int(held[kind])
		held[kind] = 0
	return paid

func snapshot() -> Dictionary:
	return {"held": held.duplicate(), "sold": sold.duplicate(), "deepest": deepest}

func restore(data: Dictionary) -> void:
	for kind in ITEMS:
		held[kind] = int(data.get("held", {}).get(kind, 0))
		sold[kind] = int(data.get("sold", {}).get(kind, 0))
	deepest = int(data.get("deepest", 0))

static func valid(data) -> bool:
	if not data is Dictionary: return false
	for part in ["held", "sold"]:
		var counts = data.get(part, {})
		if not counts is Dictionary: return false
		for kind in counts:
			if not ITEMS.has(str(kind)): return false
			var count = counts[kind]
			if not (count is int or count is float) or int(count) != count or int(count) < 0 or int(count) > MAX_COUNT: return false
	var deepest = data.get("deepest", 0)
	return (deepest is int or deepest is float) and int(deepest) >= 0 and int(deepest) <= 3
