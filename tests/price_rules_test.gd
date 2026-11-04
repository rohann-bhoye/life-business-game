extends SceneTree

# Price rules (business_backend.gd): near the MRP everyone buys, dearer means fewer, half as
# much again means nobody; difficulty shifts how dear it feels; Sharma being cheaper loses
# more shoppers; walk-outs are counted and saved.
# Run: Godot --headless --path . --script res://tests/price_rules_test.gd
const Backend := preload("res://business_backend.gd")

func _initialize() -> void:
	var state = Backend.new()
	state.save_path = ""
	state.day = 1
	assert(Backend.fair_price("snack") == 80 and Backend.fair_price("bottle") == 100)
	assert(state.set_product_price("snack", 80))
	assert(is_equal_approx(state.buy_chance("snack"), 1.0) and state.price_feel("snack") == 1)
	assert(state.set_product_price("snack", 70))
	assert(state.price_feel("snack") == 0 and is_equal_approx(state.buy_chance("snack"), 1.0), "Under the MRP is a bargain")
	assert(state.set_product_price("snack", 100))
	assert(state.price_feel("snack") == 2 and is_equal_approx(state.buy_chance("snack"), 0.6625), "25% over: some walk out")
	assert(state.set_product_price("snack", 110))
	assert(state.price_feel("snack") == 3 and state.buy_chance("snack") < 0.45 and state.buy_chance("snack") > 0.3, "Far over: most walk out")
	assert(state.set_product_price("snack", 130))
	assert(state.price_feel("snack") == 4 and state.buy_chance("snack") == 0.0, "Half as much again: nobody buys")
	# Difficulty: 10 over the MRP is fine on Aasaan, a bit high on Mushkil.
	assert(state.set_product_price("snack", 90))
	state.difficulty = 0
	assert(state.price_feel("snack") == 1)
	state.difficulty = 2
	assert(state.price_feel("snack") == 2)
	state.difficulty = 1
	# Once Sharma is open, being much dearer than him loses a quarter more.
	assert(state.set_product_price("snack", 100))
	var alone: float = state.buy_chance("snack")
	state.day = Backend.RIVAL_OPEN_DAY
	assert(state.buy_chance("snack") < alone)
	# Walk-outs are counted while the shop is open and saved.
	state.shop_owned = true
	state.minutes_of_day = 600.0
	state.record_price_walkout()
	assert(state.price_walkouts == 1 and state.last_visit == "Price too high")
	var data: Dictionary = state.snapshot()
	var loaded = Backend.new()
	loaded.restore(data)
	assert(loaded.price_walkouts == 1)
	print("PASS: price rules")
	quit()
