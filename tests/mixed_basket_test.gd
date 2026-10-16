extends SceneTree

# Mixed shopping baskets: one customer collects several products from different
# racks, every item is scanned at the counter and the basket sells as one payment.
const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("mixed_basket_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _advance(customer, target: int) -> void:
	for index in range(2400):
		if customer.state == target: return
		customer._physics_process(0.05)
	assert(false, "Customer state %d did not reach %d" % [customer.state, target])

func _run() -> void:
	# Backend: one all-or-nothing transaction for the whole basket.
	var state = Backend.new()
	state.save_path = _path()
	assert(state.order_stock("snack") and state.receive_delivery() and state.pick_up_box() and state.shelve_box())
	var money: int = state.money
	var stock: int = state.stock
	var missed: int = state.missed_sales
	assert(not state.sell_mixed_basket([{"product": "bottle", "count": 1, "rack": -1, "price": 100}, {"product": "honey", "count": 1, "rack": -1, "price": 180}], 200))
	assert(state.money == money and state.stock == stock and state.missed_sales == missed + 1, "Missing honey must cancel the whole basket")
	assert(not state.sell_mixed_basket([{"product": "bottle", "count": 1, "rack": -1, "price": 100}, {"product": "snack", "count": 1, "rack": -1, "price": 80}], 90))
	assert(state.money == money and state.stock == stock)
	assert(state.sell_mixed_basket([{"product": "bottle", "count": 2, "rack": -1, "price": 100}, {"product": "snack", "count": 1, "rack": -1, "price": 80}], 200))
	assert(state.money == money + 280 and state.stock == stock - 3 and state.product_stock("snack") == 9, "money %d->%d stock %d->%d snack %d" % [money, state.money, stock, state.stock, state.product_stock("snack")])
	assert(state.demo.customers_served == 1 and state.demo.revenue == 280)
	assert(state._is_valid_snapshot(state.snapshot()))

	# In the game: walk to two racks, scan three items, pay once.
	var fixture = load("res://main.tscn.tscn").instantiate()
	var save_path := _path()
	fixture.get_node("Shop/ShopArea").save_path = save_path
	fixture.set_meta("mixed_baskets", true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var shop = current_scene.get_node("Shop/ShopArea")
	var business = shop.business
	var ops = current_scene.get_node("ShopOperations")
	assert(business.order_stock("snack") and business.receive_delivery() and business.pick_up_box() and business.shelve_box(false, 1))
	var visitor = current_scene.get_node("Customer")
	visitor.set_physics_process(false)
	visitor.spending_budget = 200
	visitor.shopping_quantity = 2
	visitor.payment_method = "UPI"
	_advance(visitor, visitor.State.ARRIVING)
	# Make this visitor's shopping list deterministic: bottles first, then a snack pack.
	visitor.product_id = "bottle"
	visitor.rack_id = 0
	visitor._set_route(ops.customer_entry_route("bottle", 0))
	visitor.extra_lines = [{"product": "snack", "rack": -1, "count": 1, "taken": false}]
	visitor.line_index = -1
	visitor.wants_discount = false
	_advance(visitor, visitor.State.SHOPPING_MORE)
	assert(visitor.extra_lines[0].rack == 1, "Snack rack is the second stop")
	_advance(visitor, visitor.State.TO_COUNTER)
	assert(visitor.extra_lines[0].taken and visitor.total_items() == 3)
	assert(current_scene.get_node("RackFurnishing").available(1, "snack") == 9, "Snack in the basket is reserved")
	_advance(visitor, visitor.State.SCANNING)
	assert(ops.checkout_items.filter(func(item): return item.visible).size() == 3)
	assert(str(visitor.basket_products()) == str(["bottle", "bottle", "snack"]))
	var before_money: int = shop.money
	for index in range(3): assert(visitor.scan_item(index))
	assert(visitor.state == visitor.State.PAYING and visitor.payment_total() == 280 and visitor.scanned_total() == 280)
	visitor.complete_checkout()
	assert(visitor.deal_sold and shop.money == before_money + 280)
	assert(business.product_stock("snack") == 9 and business.product_stock("bottle") == 8)
	var restored = Backend.new()
	restored.load_progress(save_path)
	assert(restored.save_status == "Save: Loaded" and restored.product_stock("snack") == 9)

	business.save_path = ""
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: mixed baskets: all-or-nothing sale, two-rack shopping route, reservations, multi-product checkout and one payment")
	quit()
