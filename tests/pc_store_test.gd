extends SceneTree

# PC "APNA Wholesale" store: cart with several products ordered at once
# (business.order_cart), per-line bulk discount, all-or-nothing checks,
# category filters and the in-monitor page. Temporary saves only.
const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("pc_store_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _run() -> void:
	var state = Backend.new()
	state.save_path = _path()
	var money: int = state.money
	assert(not state.order_cart({}) and not state.order_cart({"gold": 1}) and not state.order_cart({"oil": 0}))
	assert(state.order_cart({"oil": 5, "milk": 2, "apple": 1}))
	assert(state.money == money - (4500 + 800 + 600) and state.supplier_discounts == 500)
	assert(state.incoming_boxes.size() == 8 and state.supply_in_transit == 80)
	assert(state.inventory.oil.purchased == 50 and state.inventory.apple.purchased == 10)
	assert(state._is_valid_snapshot(state.snapshot()))
	var restored = Backend.new()
	restored.load_progress(state.save_path)
	assert(restored.save_status == "Save: Loaded" and restored.incoming_boxes.size() == 8)
	var before: Dictionary = state.snapshot()
	assert(not state.order_cart({"snack": 10, "soap": 3}), "More than the 20-box supply limit")
	assert(state.snapshot() == before)
	state.money = 300
	assert(not state.order_cart({"chocolate": 1, "bread": 1}), "Not enough money for the whole cart")

	# In the game: the store page on the management PC.
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = _path()
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Player").set_physics_process(false)
	var business = current_scene.get_node("Shop/ShopArea").business
	var terminal = current_scene.get_node("ShopOperations").pc.get_node("ComputerTerminal")
	terminal.open(true)
	for frame in range(30): await process_frame
	var store = terminal.store
	assert(store != null and not store.visible)
	assert(terminal.screen_menu.has_node("ShopOnlineButton"))
	terminal.screen_menu.get_node("ShopOnlineButton").pressed.emit()
	assert(store.visible)
	store.select_category(2)
	assert(store.cards.tomato.card.visible and not store.cards.oil.card.visible and not store.cards.bottle.card.visible)
	store.select_category(0)
	assert(store.cards.oil.card.visible and store.cards.apple.card.visible)
	store.cards.honey.add.pressed.emit()
	store.cards.honey.add.pressed.emit()
	store.add_to_cart("corn", 5)
	assert(store.cart_boxes() == 7 and store.cart_total() == 2400 + 1800)
	money = business.money
	store.get_node("Cart/PlaceOrderButton").pressed.emit()
	assert(store.cart.is_empty() and business.money == money - 4200 and business.incoming_boxes.size() == 7)
	store.back_requested.emit()
	assert(not store.visible)
	terminal.open_store()
	terminal.close()
	assert(not store.visible)

	business.save_path = ""
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: PC wholesale store: multi-product cart order, bulk discount, all-or-nothing limits, category filters, monitor page")
	quit()
