extends SceneTree

# Side wings (business_backend.gd shop_wing, rack_store.gd): they need both back rooms, a
# good rating and the town's word; each widens the floor, adds racks and shoppers, shopper
# paths reach the new floor, and saves check wings are paid for and come after the back rooms.
# Run: Godot --headless --path . --script res://tests/wing_test.gd
const Backend := preload("res://business_backend.gd")
const RackStore := preload("res://rack_store.gd")

func _initialize() -> void:
	var state = Backend.new()
	state.save_path = ""
	state.money = 200000
	assert(state.wing_block_reason() == "Build the Grand Hall first" and not state.build_wing())
	state.shop_expansion = 2
	state.racks.expansion = 2
	state.expansion_expenses = Backend.EXPANSION_COSTS[0] + Backend.EXPANSION_COSTS[1]
	assert(state.wing_block_reason().begins_with("Needs a ★"))
	# A well-rated shop the town knows can build the Side Wing.
	state.customer_reviews.seed_rating = 4.5
	state.customer_reviews.seed_weight = 10.0
	assert(state.wing_block_reason().begins_with("Needs the town"))
	state.popularity = 30.0
	assert(state.can_build_wing())
	var racks_before: int = state.rack_limit()
	var area_before: int = state.shop_floor_area()
	var crowd_before: float = state.customers_per_day()
	assert(state.build_wing())
	assert(state.shop_wing == 1 and state.racks.wing == 1 and state.wing_expenses == Backend.WING_COSTS[0])
	assert(state.rack_limit() == racks_before + RackStore.RACKS_PER_WING and state.shop_floor_area() > area_before)
	assert(state.customers_per_day() > crowd_before)
	assert(is_equal_approx(RackStore.floor_rect(2, 1).end.x, RackStore.FLOOR.end.x + RackStore.WING_WIDTHS[1]))
	# Shoppers can walk from the door to the far side of the new wing.
	var far := Vector3(RackStore.floor_rect(2, 1).end.x - 1.0, 0.1, -5.0)
	assert(not state.racks.route(RackStore.ENTRY, far).is_empty(), "Paths reach the wing")
	# The Super Hall wants a better rating and a Popular shop.
	assert(state.wing_block_reason() == "Needs the town to call you Popular")
	state.popularity = 50.0
	assert(state.build_wing() and state.shop_wing == 2 and state.wing_block_reason() == "Fully built")
	assert(state.rack_limit() == RackStore.rack_limit(2, 2))
	# The wings' coolers, freezers and trolley bay keep their floor: no rack on a freezer,
	# but one in the open wing floor is fine.
	var freezer: Rect2 = RackStore.wing_fittings(2)[3]
	var on_freezer := {"id": 999, "x": freezer.get_center().x, "z": freezer.get_center().y, "turn": 0}
	assert(state.racks.placement_error(on_freezer).begins_with("Keep the coolers"))
	var open_floor := {"id": 999, "x": 2.0, "z": -5.0, "turn": 0}
	assert(state.racks.placement_error(open_floor).is_empty(), "A rack fits in the open Side Wing floor")
	var loaded = Backend.new()
	loaded.restore(state.snapshot())
	assert(loaded.shop_wing == 2 and loaded.racks.wing == 2)
	# Saves: the money must add up, so start from a fresh game that paid for the back rooms
	# and the Side Wing out of its starting money.
	var fresh = Backend.new()
	fresh.save_path = ""
	var good: Dictionary = fresh.snapshot()
	var spent: int = Backend.EXPANSION_COSTS[0] + Backend.EXPANSION_COSTS[1] + Backend.WING_COSTS[0]
	good.money = int(good.money) - spent
	good.shop_expansion = 2
	good.expansion_expenses = Backend.EXPANSION_COSTS[0] + Backend.EXPANSION_COSTS[1]
	good.shop_wing = 1
	good.wing_expenses = Backend.WING_COSTS[0]
	assert(fresh._is_valid_snapshot(good.duplicate(true)), "A paid Side Wing after both back rooms is valid")
	var unpaid: Dictionary = good.duplicate(true)
	unpaid.wing_expenses = 0
	unpaid.money = int(unpaid.money) + Backend.WING_COSTS[0]
	assert(not fresh._is_valid_snapshot(unpaid), "A wing must be paid for")
	var early: Dictionary = good.duplicate(true)
	early.shop_expansion = 1
	early.expansion_expenses = Backend.EXPANSION_COSTS[0]
	early.money = int(early.money) + Backend.EXPANSION_COSTS[1]
	assert(not fresh._is_valid_snapshot(early), "Wings come after both back rooms")
	print("PASS: side wings (needs, floor, racks, shoppers, paths, saves)")
	quit()
