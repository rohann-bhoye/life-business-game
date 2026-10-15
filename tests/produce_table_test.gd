extends SceneTree

const Backend = preload("res://business_backend.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("produce_table_%d.json" % Time.get_ticks_usec())
	var state = Backend.new()
	state.load_progress(path)
	assert(state.order_racks("tomato") and state.receive_rack_delivery())
	assert(state.place_rack("tomato", Vector2(-2.5, -4), 2, -1, true))
	var table: Dictionary = state.racks.find(3)
	assert(table.display == "produce" and table.slots.size() == 12)
	assert(table.slots.all(func(slot): return slot.product == "" and slot.count == 0))
	assert(state.assign_shelf_slot(3, 11, "soap"))
	assert(state.assign_shelf_slot(3, 4, "snack"))
	for product in ["tomato", "soap", "snack"]:
		assert(state.order_stock(product) and state.receive_delivery() and state.pick_up_box())
		assert(state.shelve_box(false, 3))
	assert(table.slots[0].product == "tomato" and table.slots[0].count == 10)
	assert(table.slots[4].product == "snack" and table.slots[11].product == "soap")
	assert(not state.assign_shelf_slot(3, 0, "bottle"))
	assert(state.assign_shelf_slot(3, 8, "bottle"))
	assert(state.order_stock("bottle") and state.receive_delivery() and state.pick_up_box())
	assert(state.shelve_box(false, 3) and table.slots[8].count == 10)
	assert(not state.assign_shelf_slot(3, 12, "tomato"))
	assert(state.sell_basket(2, 160, 80, "tomato", 3))
	assert(state.racks.free_space(3, "tomato") == 82)
	var unchanged: Dictionary = state.snapshot()
	assert(not state.racks.add_stock("tomato", 83, 3) and state.snapshot() == unchanged)
	assert(state._is_valid_snapshot(state.snapshot()))
	assert(state.place_rack("tomato", Vector2(-1, -4), 2, 3))
	assert(state.racks.find(3).display == "produce" and state.racks.find(3).slots[11].count == 10)
	assert(state.place_rack("tomato", Vector2(-2.5, -4), 2, 3))
	var restored = Backend.new()
	restored.load_progress(path)
	assert(restored.snapshot() == state.snapshot())
	for corruption in ["count", "shape", "kind"]:
		var bad: Dictionary = state.snapshot()
		if corruption == "count": bad.rack_layout[3].slots[11].count = 11
		elif corruption == "shape": bad.rack_layout[3].slots.pop_back()
		else: bad.rack_layout[3].display = "unknown"
		assert(not state._is_valid_snapshot(bad))
	var before: Dictionary = state.snapshot()
	state.save_path = path.path_join("missing/save.json")
	assert(not state.assign_shelf_slot(3, 10, "soap") and state.snapshot() == before)
	state.save_path = path
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	await process_frame
	root.size = Vector2i(1152, 648)
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	for name in ["Customer", "Player", "StockWorker"]: current_scene.get_node(name).set_physics_process(false)
	var business = current_scene.get_node("Shop/ShopArea").business
	var furnishing = current_scene.get_node("RackFurnishing")
	var model: Dictionary = furnishing.models[3]
	assert(model.produce and model.items.size() == 120)
	assert(model.skus[0] == "tomato" and model.skus[40] == "snack" and model.skus[110] == "soap" and model.skus[80] == "bottle")
	assert(model.node.has_node("BasketFloor11") and model.label.text.begins_with("MIXED"))
	assert(furnishing.choose_rack("tomato") == 3)
	assert(business.order_stock("tomato") and business.receive_delivery() and business.pick_up_box())
	var player = current_scene.get_node("Player")
	player.global_position = business.RackStore.approach(business.racks.find(3))
	assert(current_scene.get_node("ShopOperations").try_interact())
	await create_timer(0.4).timeout
	assert(is_equal_approx(model.items[8].scale.x, 0.4))
	assert(business.drop_box())
	var menu = current_scene.get_node("Ui/SupplierMenu")
	menu.open_menu()
	menu.tabs.current_tab = 5
	menu.rack_selector.select(3)
	menu.rack_selector.item_selected.emit(3)
	assert(menu.shelf_selector.item_count == 12)
	menu.shelf_selector.select(10)
	menu.shelf_selector.item_selected.emit(10)
	menu.shelf_product.select(2)
	menu.get_node("AssignShelfButton").pressed.emit()
	assert(business.racks.find(3).slots[10].product == "snack")
	menu.rack_selector.select(0)
	menu.rack_selector.item_selected.emit(0)
	assert(menu.shelf_selector.item_count == 3 and menu.shelf_selector.selected == 0)
	menu.close_menu()
	var ui = current_scene.get_node("Ui")
	ui.shop_menu.show()
	ui.select_tab(5)
	var summary: Label = ui.shop_menu.get_node("FarmSummary")
	assert(summary.position.y + summary.get_minimum_size().y <= ui.shop_menu.get_node("SeedQuantityLabel").position.y)
	ui.tablet.screen_menu.get_node("BuyProduceTableButton").pressed.emit()
	assert(business.logistics.rack_incoming == ["tomato"])
	ui.shop._on_close_button_pressed()
	assert(business._is_valid_snapshot(business.snapshot()))
	if DisplayServer.get_name() != "headless":
		player.hide()
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.current = true
		camera.global_position = Vector3(-4.2, 2.3, -2.7)
		camera.look_at(Vector3(-2.5, 0.8, -4))
		current_scene.get_node("Landscape").set_camera(camera)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("produce_table_preview.png"))
		ui.shop_menu.show()
		ui.select_tab(5)
		await process_frame
		await RenderingServer.frame_post_draw
		ui.tablet.screen_viewport.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("produce_table_tablet_preview.png"))
		ui.shop._on_close_button_pressed()
		var terminal = current_scene.get_node("ShopOperations").pc.get_node("ComputerTerminal")
		terminal.open()
		menu.tabs.current_tab = 5
		menu.rack_selector.select(3)
		menu.rack_selector.item_selected.emit(3)
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("produce_table_pc_preview.png"))
		terminal.close()
	print("PASS: delivered 12-basket table, mixed products, capacities, stocking animation, sales, movement, saves/rollback, PC basket selection and tablet purchase")
	quit()
