extends RefCounted

const MAX_REVIEWS := 1000000000
var reputation := 50
var review_count := 0
var last_score := 50

func record(outcome: String, wait_seconds: float, discounted := false) -> bool:
	if outcome not in ["sold", "stock", "price", "timeout"] or not is_finite(wait_seconds) or wait_seconds < 0 or review_count >= MAX_REVIEWS:
		return false
	var score := 80
	match outcome:
		"sold": score = clampi(80 - floori(minf(wait_seconds, 120.0) / 2.0) + (10 if discounted else 0), 20, 100)
		"stock": score = 25
		"price": score = 40
		"timeout": score = 10
	last_score = score
	review_count += 1
	var change := 2 if score >= 70 else (-4 if score < 30 else (-2 if score < 50 else 0))
	reputation = clampi(reputation + change, 0, 100)
	return true

func snapshot() -> Dictionary:
	return {"reputation": reputation, "review_count": review_count, "last_score": last_score}

func restore(data: Dictionary) -> void:
	reputation = int(data.reputation)
	review_count = int(data.review_count)
	last_score = int(data.last_score)

static func valid(data) -> bool:
	if not data is Dictionary: return false
	for field in ["reputation", "review_count", "last_score"]:
		var value = data.get(field)
		if not (value is int or value is float) or not is_finite(float(value)): return false
		if value < 0 or value > (MAX_REVIEWS if field == "review_count" else 100) or value != int(value): return false
	return data.review_count > 0 or (data.reputation == 50 and data.last_score == 50)
