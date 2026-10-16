extends SceneTree

const Backend = preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("mixed_shelves_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _run() -> void:
	var state = Backend.new()
	assert(not state.assign_shelf_slot(0, 0, "soap"))
	assert(state.assign_shelf_slot(0, 1, "soap") and state.assign_shelf_slot(0, 2, "snack"))
	assert(state.order_stock("soap", 2) and state.receive_delivery() and state.pick_up_box())
	assert(state.shelve_box(false, 0) and state.racks.find(0).slots[1].count == 10)
	assert(state.pick_up_box())
	# Racks are mixed: the empty row assigned to snacks still accepts soap.
	assert(state.shelve_one(0) and state.racks.find(0).slots[2].product == "soap" and state.racks.find(0).slots[2].count == 1)
	assert(state.sell_basket(2, 240, 120, "soap", 0))
	assert(state.shelve_box(false, 0) and state.carried_stock == 0)
	assert(state.racks.find(0).slots[1].count == 10 and state.racks.find(0).slots[2].count == 8)
	var before: Dictionary
	assert(state._is_valid_snapshot(state.snapshot()))
	var invalid: Dictionary = state.snapshot()
	invalid.rack_layout[0].slots[1].count = 11
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid.rack_layout[0].slots[1].product = ""
	assert(not state._is_valid_snapshot(invalid))
	state.save_path = _path().path_join("missing.json")
	before = state.snapshot()
	assert(not state.assign_shelf_slot(0, 2, "soap") and state.snapshot() == before)
	assert(not state.shelve_one(2) and state.snapshot() == before)
	var old: Dictionary = Backend.new().snapshot()
	old.stock = 100
	old.money = 45500
	old.restocking_expenses = 4500
	old.rack_layout[0].amount = 100
	for rack in old.rack_layout:
		rack.erase("slots")
		rack.erase("legacy_overflow")
	var legacy_path := _path()
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var migrated = Backend.new()
	migrated.load_progress(legacy_path)
	assert(migrated.stock == 100 and migrated.racks.find(0).legacy_overflow == 70)
	# (Racks are mixed now: empty rows on other racks could accept bottles, so no purchase check here.)
	assert(migrated.sell_basket(3, 300, 100, "bottle", 0))
	assert(migrated.stock == 97 and migrated.racks.find(0).legacy_overflow == 67)
	assert(migrated._is_valid_snapshot(migrated.snapshot()))
	var path := _path()
	state = Backend.new()
	state.load_progress(path)
	assert(state.assign_shelf_slot(0, 1, "soap") and state.assign_shelf_slot(0, 2, "snack"))
	for product in ["soap", "snack"]:
		assert(state.order_stock(product) and state.receive_delivery() and state.pick_up_box() and state.shelve_box(false, 0))
	assert(state.racks.find(0).amount == 30 and state.save_progress())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	for name in ["Customer", "Player", "StockWorker"]: current_scene.get_node(name).set_physics_process(false)
	var business = current_scene.get_node("Shop/ShopArea").business
	var furnishing = current_scene.get_node("RackFurnishing")
	var operations = current_scene.get_node("ShopOperations")
	var player = current_scene.get_node("Player")
	var customer = current_scene.get_node("Customer")
	assert(business.racks.find(0).slots[2].product == "snack")
	assert(furnishing.choose_rack("soap") == 0 and furnishing.choose_rack("snack") == 0)
	assert(furnishing.models[0].skus[10] == "soap" and furnishing.models[0].skus[20] == "snack")
	customer.product_id = "soap"
	customer.rack_id = 0
	customer.basket_count = 2
	customer.has_product = true
	customer.deal_sold = false
	assert(furnishing.available(0, "soap") == 8 and furnishing.available(0, "bottle") == 10 and furnishing.available(0, "snack") == 10)
	furnishing.refresh_stock()
	assert(not furnishing.models[0].items[18].visible and furnishing.models[0].items[20].visible)
	assert(business.sell_basket(2, 240, 120, "soap", 0))
	customer.has_product = false
	customer.hide()
	assert(business.order_stock("soap") and business.receive_delivery() and business.pick_up_box())
	player.global_position = business.RackStore.approach(business.racks.find(0))
	assert(operations.try_interact() and business.carried_stock == 9)
	assert(operations.try_interact() and business.carried_stock == 8)
	before = business.snapshot()
	assert(operations.try_interact() and business.snapshot() == before)
	assert(current_scene.get_node("Ui").feedback_label.text.contains("Rack full"))
	assert(business.drop_box() and business.hire_stock_worker())
	# Racks are mixed, so "no shelf space" now means every row is physically full:
	# fill the six empty rows on racks 1 and 2 with bottles.
	for box in range(6): assert(business.purchase_stock())
	assert(not business.purchase_stock())
	assert(business.pick_up_box(true))
	var worker = operations.stock_worker
	for frame in range(30): worker._physics_process(0.1)
	assert(worker.route.is_empty() and business.worker_carried_stock == 8)
	var feed = current_scene.get_node("Ui/NotificationFeed")
	feed.refresh()
	assert(feed.entries.has("shelf_space"))
	# Selling the ten bottles on rack 1's lower row empties it, so Sunil can use it.
	for quantity in [3, 3, 3, 1]: assert(business.sell_basket(quantity, 1000, -1, "bottle", 1))
	assert(business.racks.find(1).slots[0].count == 0)
	for frame in range(500): worker._physics_process(0.1)
	assert(business.worker_carried_stock == 0 and business.racks.find(1).slots[0].count == 8)
	feed.refresh()
	assert(not feed.entries.has("shelf_space"))
	assert(business._is_valid_snapshot(business.snapshot()))
	var menu = current_scene.get_node("Ui/SupplierMenu")
	menu.open_menu()
	menu.tabs.current_tab = 5
	menu.rack_selector.select(1)
	menu.rack_selector.item_selected.emit(1)
	menu.shelf_selector.select(1)
	menu.shelf_selector.item_selected.emit(1)
	menu.shelf_product.select(1)
	menu.get_node("AssignShelfButton").pressed.emit()
	assert(business.racks.find(1).slots[1].product == "bottle")
	menu.close_menu()
	if DisplayServer.get_name() != "headless":
		player.hide()
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.current = true
		current_scene.get_node("Landscape").set_camera(camera)
		camera.global_position = Vector3(-3.5, 1.8, 0.3)
		camera.look_at(Vector3(-5.6, 1, -0.5))
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("mixed_shop_shelves.png")) == OK)
		var terminal = operations.pc.get_node("ComputerTerminal")
		terminal.open()
		menu.tabs.current_tab = 5
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("mixed_shelves_pc.png")) == OK)
		terminal.close()
	for temporary in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(temporary + suffix): DirAccess.remove_absolute(temporary + suffix)
	print("PASS: mixed SKU shelf rows, finite capacities, partial boxes, independent reservations, physical stocking/warnings, Sunil waiting/resume, PC assignment, save rollback and legacy surplus")
	quit()
