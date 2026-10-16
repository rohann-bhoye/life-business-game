extends SceneTree

const Backend := preload("res://business_backend.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("farm_test_%d.json" % Time.get_ticks_usec())
	var state := Backend.new()
	state.load_progress(path)
	assert(state.buy_seeds(2))
	assert(state.money == 49800 and state.farm.seeds == 2)
	assert(not state.plant_crop(4) and not state.upgrade_farm())
	assert(state.plant_crop(0) and not state.plant_crop(0))
	assert(not state.harvest_crop(0) and state.water_crop(0) and not state.water_crop(0))
	state.advance_clock(359)
	assert(not state.harvest_crop(0))
	state.advance_clock(1)
	assert(state.harvest_crop(0) and not state.harvest_crop(0))
	assert(state.carried_stock == 10 and state.inventory.tomato.purchased == 10)
	assert(state.store_product_box(0))
	assert(state.logistics.stored_units("tomato") == 10)
	assert(state.retrieve_product_box(0))
	assert(state.assign_shelf_slot(1, 0, "tomato") and state.shelve_box(false, 1))
	assert(state.product_stock("tomato") == 10 and state.product_stock("bottle") == 10)
	assert(state.sell_basket(2, 160, 80, "tomato", 1))
	assert(state._is_valid_snapshot(state.snapshot()))
	var reload := Backend.new()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(state._is_valid_snapshot(raw))
	reload.load_progress(path)
	assert(reload.snapshot() == state.snapshot())
	assert(state.upgrade_shop() and state.upgrade_farm() and state.farm.level == 2)
	assert(state.plant_crop(10) and state.water_crop(10))
	assert(state.farm.plots[10].grow_minutes == 300)
	var before := state.snapshot()
	state.save_path = path.path_join("missing/save.json")
	assert(not state.buy_seeds() and state.snapshot() == before)
	state.save_path = path
	var bad := state.snapshot()
	bad.farm.harvested += 10
	assert(not state._is_valid_snapshot(bad))
	var legacy := Backend.new().snapshot()
	legacy.erase("farm")
	legacy.inventory.erase("tomato")
	assert(state._is_valid_snapshot(legacy))
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
	current_scene.get_node("Customer").set_physics_process(false)
	var ui = current_scene.get_node("Ui")
	var farm = current_scene.get_node("Farm")
	assert(farm.beds.size() == 24 and farm.labels[0].text.begins_with("EMPTY"))
	for index in range(4):
		assert(is_equal_approx(farm.beds[index].position.z, -3.0))
	assert(farm.beds[4].position.z < farm.beds[0].position.z)
	assert(is_equal_approx(farm.beds[23].position.z, -11.0))
	assert(is_equal_approx(farm.get_node("RoadToFarmPath").mesh.size.z, 5.45))
	assert(is_equal_approx(farm.farm_title.position.y, 2.72))
	for product in ["tomato", "carrot", "apple", "cabbage", "corn"]:
		assert(farm.get_node("Display" + product).find_children("*", "MeshInstance3D", true, false).size() > 0)
	await physics_frame
	var space = current_scene.get_world_3d().direct_space_state
	assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-24, 0.8, 1), Vector3(-24, 0.8, -2))).is_empty())
	assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-27, 0.95, 1), Vector3(-27, 0.95, -2))).is_empty())
	ui.shop_menu.show()
	ui.select_tab(5)
	assert(ui.tablet.screen_menu.has_node("BuySeedsButton"))
	ui.tablet.screen_menu.get_node("BuySeedsButton").pressed.emit()
	assert(current_scene.get_node("Shop/ShopArea").business.farm.seeds == 1)
	ui.shop._on_close_button_pressed()
	var business = ui.shop.business
	var ops = current_scene.get_node("ShopOperations")
	var visitor = load("res://customer.tscn").instantiate()
	visitor.shop_area_path = "../Shop/ShopArea"
	visitor.purchase_point_path = "../CustomerPurchasePoint"
	visitor.exit_point_path = "../CustomerExitPoint"
	current_scene.add_child(visitor)
	visitor.set_physics_process(false)
	visitor.product_id = "tomato"
	visitor.rack_id = 1
	visitor.has_product = true
	visitor.basket_count = 2
	visitor.quoted_price = 80
	visitor.wants_discount = false
	visitor.spending_budget = 200
	visitor.state = visitor.State.SCANNING
	ops.enqueue(visitor)
	ops.show_basket(visitor)
	assert(ops.checkout_items[0].has_node("ProductBody"))
	assert(ops.checkout_items[0].get_node("ProductBody").find_children("*", "MeshInstance3D", true, false).size() > 0)
	assert(visitor.scan_next() and visitor.scan_next())
	assert(visitor.state == visitor.State.PAYING and visitor.payment_total() == 160)
	visitor.complete_checkout()
	assert(visitor.deal_sold and business.product_stock("tomato") == 6)
	business.advance_clock(300)
	assert(business.farm.ready(10, business.farm_time()))
	ui.notifications.refresh()
	assert(ui.notifications.entries.has("farm_ready"))
	farm.suggestions_path = path + ".suggestions"
	farm.suggestion.text = "More tomato varieties please"
	farm.save_suggestion()
	assert(JSON.parse_string(FileAccess.get_file_as_string(farm.suggestions_path)).size() == 1)
	assert(farm.feedback.text.contains("Saved on this PC"))
	farm.roadmap.show()
	assert(current_scene.get_node("Player")._menu_is_open())
	farm.close_roadmap()
	if DisplayServer.get_name() != "headless":
		business.advance_clock(960)
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.current = true
		camera.global_position = Vector3(-23, 6, 3)
		camera.look_at(Vector3(-24, 0.7, -6))
		current_scene.get_node("Landscape").set_camera(camera)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("farm_preview.png"))
		camera.global_position = Vector3(-17, 2.1, -2.8)
		camera.look_at(Vector3(-18, 1.1, -5.55))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("farm_produce_preview.png"))
		farm.roadmap.show()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("roadmap_preview.png"))
	print("PASS: seed purchase, locked beds, watering, growth timing, harvest/storage/shelf/sale, farm levels, reload/rollback/legacy saves, tablet and local suggestions")
	quit()
