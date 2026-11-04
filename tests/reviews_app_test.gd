extends SceneTree

# Data behind the PC's Reviews app: each written review knows what it was about (kind), the
# complaints are counted from them, and the day report keeps 14 days of history (shoppers,
# rating, popularity), all saved and checked on load.
# Run: Godot --headless --path . --script res://tests/reviews_app_test.gd
const Backend := preload("res://business_backend.gd")
const DayReport := preload("res://day_report.gd")

func _initialize() -> void:
	var state = Backend.new()
	state.save_path = ""
	# Seventeen shop days of ten shoppers (the calendar stays put: no bills to settle).
	for day_number in range(1, 18):
		state.day_report.begin(state)
		for visit in range(10):
			state.record_customer_review(["sold", "stock", "price", "timeout"][visit % 4], 0.0, false, "Ravi", "soap")
		state.day_report.close(state)
	var reviews = state.customer_reviews
	for entry in reviews.written: assert(entry.kind in reviews.COMMENTS)
	var counts: Dictionary = reviews.complaints()
	assert(counts.stock > 0 and counts.price > 0 and counts.wait > 0)
	var history: Array = state.day_report.history
	assert(history.size() == DayReport.HISTORY_DAYS and int(history.back().shoppers) == 10)
	assert(int(history.back().rating10) > 0)
	var data: Dictionary = state.snapshot()
	assert(state._is_valid_snapshot(data))
	var loaded = Backend.new()
	loaded.restore(data)
	assert(loaded.day_report.history.size() == DayReport.HISTORY_DAYS and loaded.customer_reviews.complaints() == counts)
	var broken: Dictionary = state.snapshot()
	broken.day_report.history[0].shoppers = -1
	assert(not state._is_valid_snapshot(broken))
	broken = state.snapshot()
	broken.customer_reviews.written[0].kind = "made up"
	assert(not state._is_valid_snapshot(broken))
	print("PASS: reviews app data (kinds, complaints, 14-day history, saved and checked)")
	quit()
