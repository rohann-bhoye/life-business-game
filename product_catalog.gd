extends RefCounted

const IDS := ["bottle", "snack", "soap", "tomato"]
const NAMES := {"bottle": "Reusable bottles", "snack": "Snack packs", "soap": "Soap bars", "tomato": "Farm tomatoes"}
const COSTS := {"bottle": 500, "snack": 400, "soap": 600, "tomato": 500}

static func fresh_inventory() -> Dictionary:
	return {"snack": {"stock": 0, "purchased": 0, "sold": 0, "price": 80}, "soap": {"stock": 0, "purchased": 0, "sold": 0, "price": 120}, "tomato": {"stock": 0, "purchased": 0, "sold": 0, "price": 80}}

static func valid(data) -> bool:
	if not data is Dictionary or data.size() not in [2, 3]: return false
	for key in data:
		if key not in ["snack", "soap", "tomato"]: return false
	for id in ["snack", "soap", "tomato"]:
		var item = data.get(id, fresh_inventory().tomato if id == "tomato" else null)
		if not item is Dictionary: return false
		for field in ["stock", "purchased", "sold", "price"]:
			var value = item.get(field)
			if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 1000000000 or value != int(value): return false
		if int(item.purchased) % 10 != 0 or item.sold > item.purchased or item.price < 50 or item.price > 200 or int(item.price) % 10 != 0: return false
	return true
