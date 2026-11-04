extends RefCounted

# Customer reviews. Every visit ends with a satisfaction score (0..100: a fast, fair sale is
# 80, waiting costs a point every 2 s, a bargain or discount adds 10; empty shelf 25, too
# dear 40, gave up in the queue 10) and 1-5 stars from it. Some shoppers write it down as a
# review with a short Hinglish comment, unhappy ones more often (deterministic: each star
# level gathers "writing credit" and writes whenever it reaches 1). The shop's star rating is
# the average of the newest written reviews, newer counting more; reputation (0..100, used for
# traffic, Sharma and the day report) follows the rating, gently while there are few reviews.
# Saves from before stars keep their reputation as a starting rating (seed).
const MAX_REVIEWS := 1000000000
## Stars from a score: at least 80 is 5, 65 is 4, 45 is 3, 25 is 2, below is 1.
const STAR_SCORES := [80, 65, 45, 25]
## Share of shoppers who write a review, for 1..5 stars.
const WRITE_SHARE := [0.6, 0.5, 0.3, 0.25, 0.3]
## Written reviews kept (for the rating and the PC's Reviews app), newest last.
const KEPT := 60
## Each older review counts this much less in the rating.
const RECENCY := 0.97
## Written reviews before the rating fully sets the reputation.
const SETTLED := 8.0
const OUTCOMES := ["sold", "stock", "price", "timeout"]
## Comments by what happened: [stars, text]. {product} is the product's name.
const COMMENTS := {
	"great": ["Sab kuch mil gaya, bhaiya ache hain!", "Jaldi billing, saaf dukaan. Wah!", "Dholkarpur ka best kirana!", "{product} ekdum fresh. Phir aaunga."],
	"bargain": ["Sasta aur accha! {product} MRP se kam.", "Daam bilkul sahi hai, mazaa aa gaya.", "Discount bhi mila, bahut badhiya!"],
	"good": ["Accha shop hai, thoda wait karna pada.", "{product} mil gaya, theek hai.", "Saaman accha hai, line thodi lambi."],
	"slow": ["Line lambi thi, par saaman mil gaya.", "Theek-thaak. Billing bahut slow hai.", "{product} liya, par bahut der lagi."],
	"very_slow": ["Billing mein itna time? Haath dukh gaye.", "Line mein khade khade thak gaya."],
	"stock": ["{product} khatam tha. Time waste.", "Shelf khaali thi! Maal rakho bhaiya.", "Jo chahiye tha wahi nahi mila."],
	"price": ["Bahut mehenga! {product} MRP se zyada.", "Sharma ji ke yahan sasta milta hai.", "Itne daam mein kaun lega?"],
	"timeout": ["Line mein itna wait! Kabhi nahi aaunga.", "Koi billing karne wala hi nahi tha.", "Aadha ghanta khada raha, phir chala gaya."],
}

var reputation := 50
## Every visit, written down or not (the day report's shoppers).
var review_count := 0
var last_score := 50
var last_stars := 3
## Written reviews: {"name", "stars", "text", "day", "minute"}, newest last.
var written: Array = []
## Written reviews ever, per star (index 0 = 1 star).
var star_counts := [0, 0, 0, 0, 0]
var write_credit := [0.0, 0.0, 0.0, 0.0, 0.0]
## Older saves: their reputation as a starting rating and how much it counts.
var seed_rating := 0.0
var seed_weight := 0.0

static func stars_for(score: int) -> int:
	for index in range(STAR_SCORES.size()):
		if score >= STAR_SCORES[index]: return 5 - index
	return 1

## Records a visit; returns false for a bad outcome or wait. `name`, `product` (a catalog
## name), `day` and `minute` go into a written review.
func record(outcome: String, wait_seconds: float, discounted := false, name := "", product := "", day := 0, minute := 0) -> bool:
	if outcome not in OUTCOMES or not is_finite(wait_seconds) or wait_seconds < 0 or review_count >= MAX_REVIEWS:
		return false
	var score := 80
	match outcome:
		"sold": score = clampi(80 - floori(minf(wait_seconds, 120.0) / 2.0) + (10 if discounted else 0), 20, 100)
		"stock": score = 25
		"price": score = 40
		"timeout": score = 10
	last_score = score
	last_stars = stars_for(score)
	review_count += 1
	# Kept to 4 decimals so a save stores it exactly (0.6 + 0.6 - 1 is not quite 0.2).
	write_credit[last_stars - 1] = snappedf(write_credit[last_stars - 1] + WRITE_SHARE[last_stars - 1], 0.0001)
	if write_credit[last_stars - 1] >= 1.0:
		write_credit[last_stars - 1] = snappedf(write_credit[last_stars - 1] - 1.0, 0.0001)
		_write(outcome, wait_seconds, discounted, name, product, day, minute)
	return true

## What a visit was like (a COMMENTS key): great, bargain, good, slow, very_slow, stock,
## price or timeout.
static func kind_for(outcome: String, stars: int, wait_seconds: float, discounted: bool) -> String:
	if outcome != "sold": return outcome
	if discounted and stars >= 4: return "bargain"
	if stars >= 5: return "great"
	if stars == 4: return "good"
	return "slow" if wait_seconds < 100.0 else "very_slow"

## A comment for that kind of visit, picked from COMMENTS.
static func comment(kind: String, product: String) -> String:
	var lines: Array = COMMENTS[kind]
	if product.is_empty(): lines = lines.filter(func(line): return not "{product}" in line)
	return str(lines.pick_random()).replace("{product}", product)

## What the complaints are about, for the PC's Reviews app: {"stock", "price", "wait"} counts
## over the kept written reviews.
func complaints() -> Dictionary:
	var counts := {"stock": 0, "price": 0, "wait": 0}
	for entry in written:
		var kind: String = entry.get("kind", "")
		if kind in ["stock", "price"]: counts[kind] += 1
		elif kind in ["slow", "very_slow", "timeout"]: counts.wait += 1
	return counts

func _write(outcome: String, wait_seconds: float, discounted: bool, name: String, product: String, day: int, minute: int) -> void:
	var kind := kind_for(outcome, last_stars, wait_seconds, discounted)
	written.append({"name": name if not name.is_empty() else "A shopper", "stars": last_stars, "text": comment(kind, product), "kind": kind, "day": day, "minute": minute})
	if written.size() > KEPT: written = written.slice(written.size() - KEPT)
	star_counts[last_stars - 1] += 1
	_update_reputation()

## Written reviews ever.
func written_count() -> int:
	var total := 0
	for count in star_counts: total += int(count)
	return total

## The star rating (1.0..5.0) from the newest written reviews, or 0.0 with none yet.
func rating() -> float:
	var weight := seed_weight
	var total := seed_rating * seed_weight
	var step := 1.0
	for index in range(written.size() - 1, -1, -1):
		total += float(written[index].stars) * step
		weight += step
		step *= RECENCY
	return total / weight if weight > 0.0 else 0.0

## "★★★★☆" for 4 stars.
static func star_text(stars: int) -> String:
	return "★".repeat(clampi(stars, 0, 5)) + "☆".repeat(5 - clampi(stars, 0, 5))

## "★ 4.2 (35 reviews)", "★ 3.0" for an older save's standing, or "No reviews yet".
func rating_text() -> String:
	var count := written_count()
	if count == 0 and seed_weight <= 0.0: return "No reviews yet"
	if count == 0: return "★ %.1f" % rating()
	return "★ %.1f (%d review%s)" % [rating(), count, "" if count == 1 else "s"]

func _update_reputation() -> void:
	var count := seed_weight + written.size()
	if count <= 0.0: return
	reputation = clampi(roundi(lerpf(50.0, (rating() - 1.0) * 25.0, minf(1.0, count / SETTLED))), 0, 100)

func snapshot() -> Dictionary:
	return {"reputation": reputation, "review_count": review_count, "last_score": last_score, "written": written.duplicate(true), "star_counts": star_counts.duplicate(), "write_credit": write_credit.duplicate(), "seed_rating": seed_rating, "seed_weight": seed_weight}

func restore(data: Dictionary) -> void:
	reputation = int(data.reputation)
	review_count = int(data.review_count)
	last_score = int(data.last_score)
	last_stars = stars_for(last_score)
	if data.has("written"):
		written = []
		for entry in data.written: written.append({"name": str(entry.name), "stars": int(entry.stars), "text": str(entry.text), "kind": str(entry.get("kind", "")), "day": int(entry.day), "minute": int(entry.minute)})
		star_counts = (data.star_counts as Array).map(func(value): return int(value))
		write_credit = (data.write_credit as Array).map(func(value): return float(value))
		seed_rating = float(data.seed_rating)
		seed_weight = float(data.seed_weight)
	else:
		# A save from before stars: its reputation becomes a starting rating that counts
		# like up to ten reviews, so the shop keeps its standing while new reviews come in.
		written = []
		star_counts = [0, 0, 0, 0, 0]
		write_credit = [0.0, 0.0, 0.0, 0.0, 0.0]
		seed_weight = minf(10.0, review_count)
		seed_rating = 1.0 + reputation / 25.0 if seed_weight > 0.0 else 0.0

static func valid(data) -> bool:
	if not data is Dictionary: return false
	for field in ["reputation", "review_count", "last_score"]:
		var value = data.get(field)
		if not (value is int or value is float) or not is_finite(float(value)): return false
		if value < 0 or value > (MAX_REVIEWS if field == "review_count" else 100) or value != int(value): return false
	if data.has("written"):
		if not data.written is Array or data.written.size() > KEPT: return false
		for entry in data.written:
			if not entry is Dictionary or not entry.get("name") is String or not entry.get("text") is String: return false
			if entry.name.length() > 40 or entry.text.length() > 120: return false
			if entry.has("kind") and (not entry.kind is String or (entry.kind != "" and not COMMENTS.has(entry.kind))): return false
			for field in ["stars", "day", "minute"]:
				var number = entry.get(field)
				if not (number is int or number is float) or not is_finite(float(number)) or number != int(number) or number < 0: return false
			if entry.stars < 1 or entry.stars > 5 or entry.minute >= 1440: return false
		for field in ["star_counts", "write_credit"]:
			var list = data.get(field)
			if not list is Array or list.size() != 5: return false
			for value in list:
				if not (value is int or value is float) or not is_finite(float(value)) or value < 0: return false
		for value in data.star_counts:
			if value > MAX_REVIEWS or value != int(value): return false
		for value in data.write_credit:
			if value >= 1.0: return false
		for field in ["seed_rating", "seed_weight"]:
			var number = data.get(field)
			if not (number is int or number is float) or not is_finite(float(number)) or number < 0: return false
		if data.seed_rating > 5.0 or data.seed_weight > 10.0: return false
	return data.review_count > 0 or (data.reputation == 50 and data.last_score == 50)
