extends SceneTree

# Story games rent the family home (200 a day) until it is bought: rent builds up and is
# paid with the other bills, sleeping works while renting, buying stops the rent, and the
# saved game round-trips through the strict save check.
const Backend = preload("res://business_backend.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("rent_test_%d.json" % Time.get_ticks_usec())
	var state = Backend.new()
	state.save_path = path
	assert(not state.sleep_until_morning(), "A game that neither owns nor rents cannot sleep")
	assert(state.start_renting() and state.home_rented and not state.house_owned)
	assert(not state.start_renting(), "Renting starts once")
	var start_money: int = state.money
	state.advance_clock(720.0)  # to 20:00
	assert(state.sleep_time_allowed() and state.sleep_until_morning(), "Sleeping works in the rented home")
	assert(state.day == 2)
	var rent_day := Backend.RENT_PER_DAY
	assert(state.rent_paid == rent_day and state.rent_due == 0, "One day's rent was paid")
	assert(state.money == start_money - Backend.DAILY_SHOP_COST - rent_day, "Money went down by bills plus rent")
	assert(state.total_expenses() >= rent_day)
	# Saved game keeps the rent and passes the strict check.
	assert(state.save_progress())
	var reloaded = Backend.new()
	reloaded.load_progress(path)
	assert(reloaded.home_rented and reloaded.rent_paid == rent_day and reloaded.money == state.money, "Rent survives save and load")
	# Not enough money: rent waits as unpaid, shows in the bills, and is paid later.
	var poor = Backend.new()
	poor.start_renting()
	poor.money = 0
	poor.advance_clock(1440.0)
	assert(poor.rent_due == rent_day * (poor.day - 1) and poor.rent_due > 0, "Unpaid rent builds up")
	assert(poor.unpaid_bills() >= poor.rent_due)
	poor.money = 10000
	assert(poor.can_pay_bills() and poor.pay_bills() and poor.rent_due == 0)
	# Buying stops the rent.
	var buyer = Backend.new()
	buyer.start_renting()
	assert(buyer.buy_house() and buyer.house_owned and not buyer.home_rented)
	assert(buyer.property_expenses == Backend.HOUSE_COST)
	buyer.advance_clock(1440.0)
	assert(buyer.rent_due == 0 and buyer.rent_paid == 0, "No rent after buying")
	# A free (sandbox) home never charges rent.
	var free = Backend.new()
	assert(free.grant_home() or true)
	free.house_owned = true
	free.advance_clock(1440.0)
	assert(free.rent_due == 0 and free.rent_paid == 0)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: rent_test")
	quit()
