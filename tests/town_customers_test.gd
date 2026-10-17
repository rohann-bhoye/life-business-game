extends SceneTree

# Real-game customers: shopper types with different baskets and budgets, walking in
# along the pavement from the end of the street and walking away after shopping.
const Customer := preload("res://customer.gd")
var path: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	path = OS.get_environment("TEMP").path_join("town_customers_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	fixture.set_meta("mixed_baskets", true)
	fixture.set_meta("town_customers", true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	var spawner = current_scene.get_node("CustomerSpawner")
	spawner.get_node("SpawnTimer").stop()
	current_scene.get_node("Player").set_physics_process(false)
	var business = current_scene.get_node("Shop/ShopArea").business
	business.save_path = ""
	var starter = current_scene.get_node_or_null("Customer")
	if is_instance_valid(starter): starter.queue_free()
	await process_frame
	# Shopper types: every kind shows up, with its own basket size and budget.
	spawner._on_spawn_timer_timeout()
	var visitor = spawner.customers[-1]
	visitor.set_physics_process(false)
	var seen := {}
	var biggest := 0
	var smallest := 99
	for index in range(400):
		visitor._pick_shopper_type()
		var kind: Dictionary = Customer.SHOPPER_TYPES[visitor.shopper_type]
		seen[visitor.shopper_type] = seen.get(visitor.shopper_type, 0) + 1
		assert(visitor.shopping_quantity >= kind.items[0] and visitor.shopping_quantity <= kind.items[1])
		assert(visitor.spending_budget >= kind.budget[0] * 10 and visitor.spending_budget <= kind.budget[1] * 10)
		assert(absf(visitor.pavement_lane - Customer.PAVEMENT_Z) <= 0.3)
		if visitor.shopper_type in ["family", "bulk"]: assert(not visitor.wants_discount)
		biggest = maxi(biggest, visitor.shopping_quantity)
		smallest = mini(smallest, visitor.shopping_quantity)
	assert(seen.size() == 4 and seen.quick > seen.bulk and seen.regular > seen.bulk, "Shopper mix: %s" % seen)
	assert(smallest == 1 and biggest >= 5)
	visitor._pick_shopper_type()
	# Walking in: starts at an end of the street on the pavement, visible all the way.
	visitor.set_physics_process(true)
	visitor._physics_process(0.016)
	assert(visitor.visible and visitor.state == visitor.State.ARRIVING)
	assert(absf(visitor.global_position.x) >= 22.0 and absf(visitor.global_position.z - visitor.pavement_lane) < 0.01, "Starts on the pavement: %s" % visitor.global_position)
	assert(visitor.arrival_side == signf(visitor.global_position.x))
	visitor.set_physics_process(false)
	var reached_door := false
	for step in range(1200):
		visitor._physics_process(0.05)
		assert(visitor.visible)
		if visitor.global_position.z > 3.35 and absf(visitor.global_position.x - (-3.0)) > 0.05: assert(absf(visitor.global_position.z - visitor.pavement_lane) < 0.01, "Stays on the pavement until the door: %s" % visitor.global_position)
		if visitor.global_position.z < 3.0: reached_door = true
		if visitor.state != visitor.State.ARRIVING: break
	assert(reached_door and visitor.state in [visitor.State.TAKING, visitor.State.LEAVING], "Walked into the shop: state %d at %s" % [visitor.state, visitor.global_position])
	# Walking out: through the door, onto the pavement and down the street.
	visitor.leave_shop()
	var exit_route: Array = visitor.route
	assert(absf(exit_route[-1].x) == Customer.STREET_END_X and absf(exit_route[-1].z - visitor.pavement_lane) < 0.01)
	assert(absf(exit_route[-2].z - visitor.pavement_lane) < 0.01 and absf(exit_route[-2].x - (-3.0)) < 0.01)
	# Someone walking away does not stop new shoppers from coming.
	for extra in range(3): spawner._on_spawn_timer_timeout()
	assert(spawner.customers.size() == 4, "Leaving customers don't count as shopping: %d" % spawner.customers.size())
	for other in spawner.customers:
		if other != visitor: other.set_physics_process(false)
	var walked_out := false
	for step in range(1600):
		if not is_instance_valid(visitor) or visitor.is_queued_for_deletion(): break
		visitor._physics_process(0.05)
		if visitor.global_position.z > 3.5: walked_out = true
		if not visitor.is_queued_for_deletion(): assert(visitor.visible, "Visible while walking away")
	assert(walked_out)
	await process_frame
	assert(not is_instance_valid(visitor), "Freed only after reaching the end of the street")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: shopper types and budgets, pavement arrival from the street end, walk-in, walk-out down the street, leaving customers don't block new ones")
	quit()
