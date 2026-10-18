extends RefCounted

const IDS := ["bottle", "snack", "soap", "tomato", "oil", "milk", "bread", "chocolate", "honey", "carrot", "cabbage", "corn", "apple"]
# Kirana names (ids stay the same, so saves and racks are unchanged).
const NAMES := {"bottle": "Cold drink", "snack": "Masala namkeen", "soap": "Neem soap", "tomato": "Desi tomatoes", "oil": "Mustard oil", "milk": "Fresh milk", "bread": "Pav bread", "chocolate": "Chocolate", "honey": "Pure honey", "carrot": "Red carrots", "cabbage": "Patta gobhi", "corn": "Bhutta", "apple": "Kashmiri apples"}
const COSTS := {"bottle": 500, "snack": 400, "soap": 600, "tomato": 500, "oil": 1000, "milk": 400, "bread": 350, "chocolate": 300, "honey": 1200, "carrot": 400, "cabbage": 450, "corn": 400, "apple": 600}
const PRICES := {"snack": 80, "soap": 120, "tomato": 80, "oil": 150, "milk": 60, "bread": 50, "chocolate": 50, "honey": 180, "carrot": 60, "cabbage": 70, "corn": 60, "apple": 90}
## Every SKU tracked in the inventory dictionary (bottle stock is derived from the aggregate).
const EXTRA := ["snack", "soap", "tomato", "oil", "milk", "bread", "chocolate", "honey", "carrot", "cabbage", "corn", "apple"]
## SKUs added after the original save format; old saves get zeroed entries for them.
const OPTIONAL := ["tomato", "oil", "milk", "bread", "chocolate", "honey", "carrot", "cabbage", "corn", "apple"]

static func fresh_item(id: String) -> Dictionary:
	return {"stock": 0, "purchased": 0, "sold": 0, "price": PRICES[id]}

static func fresh_inventory() -> Dictionary:
	var result := {}
	for id in EXTRA: result[id] = fresh_item(id)
	return result

static func valid(data) -> bool:
	if not data is Dictionary or not data.has("snack") or not data.has("soap"): return false
	for key in data:
		if key not in EXTRA: return false
	for id in EXTRA:
		var item = data.get(id, fresh_item(id) if id in OPTIONAL else null)
		if not item is Dictionary: return false
		for field in ["stock", "purchased", "sold", "price"]:
			var value = item.get(field)
			if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 1000000000 or value != int(value): return false
		if int(item.purchased) % 10 != 0 or item.sold > item.purchased or item.price < 50 or item.price > 200 or int(item.price) % 10 != 0: return false
	return true
