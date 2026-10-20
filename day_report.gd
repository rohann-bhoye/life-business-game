extends RefCounted

# End-of-day summary. `start` holds the business counters at the beginning of the
# current day; close() turns the difference into `last`, the finished report of the
# day that just ended, shown when the player wakes up. Both are saved.
const Catalog = preload("res://product_catalog.gd")
const NUMBERS := ["day", "items_sold", "revenue", "expenses", "missed", "reputation", "reviews"]
# Expense breakdown for the end-of-day screen; together they add up to total_expenses().
const COSTS := ["stock", "staff", "bills", "marketing", "upgrades", "farm", "loan"]
const COST_NAMES := {"stock": "Stock purchases", "staff": "Staff wages and hiring", "bills": "Shop rent and bills", "marketing": "Marketing", "upgrades": "Upgrades and furniture", "farm": "Farm", "loan": "Loan interest"}

var start := {}
var last := {}

static func counters(business) -> Dictionary:
	var sold := {}
	var extras := 0
	for id in Catalog.EXTRA:
		sold[id] = int(business.inventory.get(id, {}).get("sold", 0))
		extras += sold[id]
	sold["bottle"] = maxi(0, int(business.items_sold) - extras)
	var costs := {"stock": business.restocking_expenses, "staff": business.hiring_expenses + business.wage_expenses + business.overtime_expenses, "bills": business.operating_expenses, "marketing": business.marketing_expenses, "upgrades": business.upgrade_expenses + business.furnishing_expenses + business.expansion_expenses, "farm": business.farm.expenses(), "loan": business.loan_interest_paid}
	return {"day": int(business.day), "items_sold": int(business.items_sold), "revenue": int(business.sales_revenue), "expenses": int(business.total_expenses()), "missed": int(business.missed_sales), "reputation": int(business.customer_reviews.reputation), "reviews": int(business.customer_reviews.review_count), "sold": sold, "costs": costs}

func begin(business) -> void:
	start = counters(business)

## Finishes the current day: builds `last` from today's changes and starts a new day.
func close(business) -> Dictionary:
	if start.is_empty(): begin(business)
	var now := counters(business)
	var best := ""
	var best_count := 0
	for id in now.sold:
		var count: int = int(now.sold[id]) - int(start.sold.get(id, 0))
		if count > best_count:
			best = id
			best_count = count
	var revenue: int = now.revenue - int(start.revenue)
	var expenses: int = now.expenses - int(start.expenses)
	last = {"day": int(start.day), "items_sold": now.items_sold - int(start.items_sold), "revenue": revenue, "expenses": expenses, "profit": revenue - expenses, "missed": now.missed - int(start.missed), "reputation": now.reputation, "reputation_change": now.reputation - int(start.reputation), "reviews": now.reviews - int(start.reviews), "best": best, "best_count": best_count}
	# Saves from before the breakdown have no start costs; they show only the total.
	if start.has("costs"):
		var costs := {}
		for key in COSTS: costs[key] = int(now.costs[key]) - int(start.costs.get(key, 0))
		last["costs"] = costs
	start = now
	return last

func snapshot() -> Dictionary:
	return {"start": start.duplicate(true), "last": last.duplicate(true)}

func restore(data: Dictionary) -> void:
	start = _ints(data.get("start", {}))
	last = _ints(data.get("last", {}))

static func _ints(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		var value = source[key]
		if value is Dictionary: result[key] = _ints(value)
		elif value is float: result[key] = int(value)
		else: result[key] = value
	return result

static func valid(data) -> bool:
	if not data is Dictionary: return false
	for part in ["start", "last"]:
		var item = data.get(part, {})
		if not item is Dictionary: return false
		for key in item:
			var value = item[key]
			if key == "sold" or key == "costs":
				if not value is Dictionary: return false
				for id in value:
					if id not in (Catalog.IDS if key == "sold" else COSTS) or not (value[id] is int or value[id] is float) or not is_finite(float(value[id])): return false
			elif key == "best":
				if not value is String or (value != "" and value not in Catalog.IDS): return false
			elif not (value is int or value is float) or not is_finite(float(value)): return false
	return true
