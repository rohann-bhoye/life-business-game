extends SceneTree

# Town popularity (business_backend.gd): a new shop starts unknown with few shoppers, happy
# shoppers raise it, unhappy ones and shut days lower it, the tiers and the daily rhythm work,
# and it is saved (old saves without it count as a busy, known shop).
# Run: Godot --headless --path . --script res://tests/popularity_test.gd
const Backend := preload("res://business_backend.gd")

func _initialize() -> void:
	var state = Backend.new()
	state.save_path = ""
	assert(is_equal_approx(state.popularity, Backend.POPULARITY_START) and state.popularity_name() == "Unknown")
	var first_day: float = state.customers_per_day() / state.day_mood()
	assert(first_day > 10.0 and first_day < 20.0, "A new shop gets only a few shoppers: %f" % first_day)
	# Happy shoppers spread the word, unhappy ones put people off.
	var tiers := []
	state.popularity_tier_changed.connect(func(tier): tiers.append(tier))
	for visit in range(40): assert(state.record_customer_review("sold", 0.0))
	assert(state.popularity > 15.0 and state.popularity_name() == "Known" and tiers == [1])
	var known: float = state.popularity
	assert(state.record_customer_review("timeout", 200.0) and state.popularity < known)
	assert(state.customers_per_day() / state.day_mood() > first_day)
	# Rushes: the evening is busier than the quiet afternoon.
	assert(Backend.hour_rush(18 * 60) > Backend.hour_rush(14 * 60))
	# A night fades it a little; a day with nobody served fades it more.
	state.shop_owned = true
	state.day_report.last = {"reviews": 5}
	var before: float = state.popularity
	state.day += 1
	state._bill_new_day()
	assert(state.popularity < before and state.popularity > before - 2.0)
	state.day_report.last = {"reviews": 0}
	before = state.popularity
	state.day += 1
	state._bill_new_day()
	assert(state.popularity <= before - Backend.POPULARITY_SHUT_DAY)
	# Saved, and old saves without it are a known, busy shop.
	var data: Dictionary = state.snapshot()
	assert(is_equal_approx(float(data.popularity), state.popularity))
	data.erase("popularity")
	var old = Backend.new()
	old.restore(data)
	assert(is_equal_approx(old.popularity, Backend.POPULARITY_OLD_SAVES))
	print("PASS: popularity")
	quit()
