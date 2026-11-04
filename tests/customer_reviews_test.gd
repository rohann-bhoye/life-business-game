extends SceneTree

# Customer reviews (customer_reviews.gd): each visit's score and stars, who writes a review
# (deterministic credit, unhappy shoppers more), Hinglish comments, the recency-weighted
# star rating, reputation following it, bounds, the save roundtrip and older saves.
const Backend := preload("res://business_backend.gd")
const Reviews := preload("res://customer_reviews.gd")

func _initialize() -> void:
	var state = Backend.new()
	var reviews = state.customer_reviews
	assert(reviews.reputation == 50 and reviews.rating_text() == "No reviews yet")
	assert(Reviews.stars_for(80) == 5 and Reviews.stars_for(65) == 4 and Reviews.stars_for(45) == 3 and Reviews.stars_for(25) == 2 and Reviews.stars_for(10) == 1)
	assert(state.record_customer_review("sold", 0, false, "Ramesh", "snack"))
	assert(reviews.last_score == 80 and reviews.last_stars == 5)
	assert(state.record_customer_review("sold", 60))
	assert(reviews.last_score == 50 and reviews.last_stars == 3)
	assert(state.record_customer_review("sold", 120))
	assert(reviews.last_score == 20 and reviews.last_stars == 1)
	assert(state.record_customer_review("sold", 0, true))
	assert(reviews.last_score == 90)
	for outcome in ["stock", "price", "timeout"]:
		assert(state.record_customer_review(outcome, 0, false, "Sunita", "oil"))
	assert(not state.record_customer_review("closed", 0))
	assert(not state.record_customer_review("sold", -1))
	assert(not state.record_customer_review("sold", NAN))
	assert(reviews.review_count == 7)
	# Writing credit: two 1-star visits (0.6 each) and two 2-star ones (0.5 each) fill it;
	# the happy 5-star and 3-star visits (0.3 each) have not written yet.
	assert(reviews.written_count() == 2 and reviews.written[0].stars == 2 and reviews.written[1].stars == 1)
	assert(reviews.written[0].name == "Sunita" and reviews.written[0].text.length() > 5)
	assert(is_equal_approx(reviews.rating(), (1.0 + 2.0 * 0.97) / 1.97))
	assert(reviews.reputation < 50, "Two bad reviews pull the reputation down gently")
	assert(state.money == 50000 and state.stock == 10 and state.missed_sales == 0)
	assert(state._is_valid_snapshot(state.snapshot()))
	var path := OS.get_environment("TEMP").path_join("reviews_%d.json" % Time.get_ticks_usec())
	state.save_path = path
	assert(state.save_progress())
	var loaded = Backend.new()
	loaded.load_progress(path)
	assert(loaded.customer_reviews.snapshot() == state.customer_reviews.snapshot())
	var legacy: Dictionary = state.snapshot()
	legacy.erase("customer_reviews")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	loaded = Backend.new()
	loaded.load_progress(path)
	assert(loaded.customer_reviews.reputation == 50 and loaded.customer_reviews.review_count == 0)
	# A save from before stars keeps its standing as a starting rating.
	var older = Reviews.new()
	older.restore({"reputation": 80, "review_count": 30, "last_score": 80})
	assert(is_equal_approx(older.rating(), 4.2) and older.rating_text() == "★ 4.2" and older.reputation == 80)
	for value in [-1, 101, 1.5, true, "50"]:
		var invalid: Dictionary = state.snapshot()
		invalid.customer_reviews.reputation = value
		assert(not state._is_valid_snapshot(invalid))
	var broken: Dictionary = state.snapshot()
	broken.customer_reviews.written[0].stars = 6
	assert(not state._is_valid_snapshot(broken))
	for index in range(100): assert(state.record_customer_review("sold", 0))
	assert(reviews.reputation >= 95 and reviews.rating() > 4.8)
	for index in range(100): assert(state.record_customer_review("timeout", 0))
	assert(reviews.reputation == 0 and is_equal_approx(reviews.rating(), 1.0))
	assert(reviews.written.size() == Reviews.KEPT)
	assert(state._is_valid_snapshot(state.snapshot()))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: customer reviews, stars, written reviews, rating, reputation, bounds, save roundtrip and older saves")
	quit()
