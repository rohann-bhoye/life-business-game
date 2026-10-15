extends SceneTree

var path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	path = OS.get_environment("TEMP").path_join("life_notifications_%d.json" % Time.get_ticks_usec())
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	root.size = Vector2i(1152, 648)
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("StockWorker").set_physics_process(false)
	current_scene.get_node("Player").set_physics_process(false)
	var ui = current_scene.get_node("Ui")
	var business = ui.shop.business
	var feed = ui.notifications
	feed.refresh()
	assert(feed.entries.is_empty() and not feed.visible)
	assert(business.hire_worker() and business.hire_stock_worker())
	assert(business.set_staff_shift("cashier", 480, 600))
	assert(business.set_staff_shift("stock", 480, 600))
	business.advance_clock(120)
	feed.refresh()
	assert(feed.entries.size() == 2 and feed.visible)
	assert(feed.entries["staff:cashier"].title == "Ramesh wants to talk")
	assert(feed.entries["staff:stock"].title == "Sunil wants to talk")
	assert(not ui.staff_dialog.visible and not ui.player._menu_is_open())
	var row = feed.rows["staff:cashier"]
	for repeat in range(20): feed.refresh()
	assert(feed.rows.size() == 2 and feed.rows["staff:cashier"] == row)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = row.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	assert(ui.staff_dialog.visible and ui.staff_dialog.role == "cashier")
	feed.refresh()
	assert(not feed.visible)
	ui.staff_dialog.close_menu()
	feed.refresh()
	assert(feed.entries.has("staff:cashier"), "Closing is not an answer")
	assert(business.staff.reply(business, "cashier", "overtime"))
	feed.refresh()
	assert(not feed.entries.has("staff:cashier") and feed.entries.has("staff:stock"))
	business.advance_clock(60)
	feed.refresh()
	assert(feed.entries["staff:cashier"].detail.contains("50"))
	assert(business.staff.reply(business, "cashier", "pay"))
	assert(business.staff.reply(business, "stock", "home"))
	for index in range(8): assert(business.sell_one_stock(200))
	feed.refresh()
	assert(feed.entries["stock:bottle"].title.contains("2 left"))
	for index in range(2): assert(business.sell_one_stock(200))
	feed.refresh()
	assert(feed.entries.size() == 1 and feed.entries["stock:bottle"].title.contains("out of stock"))
	assert(not feed.entries.has("stock:snack") and not feed.entries.has("stock:soap"))
	assert(business.order_stock() and business.receive_delivery())
	feed.refresh()
	assert(feed.entries.has("delivery") and feed.entries["stock:bottle"].detail.contains("outside"))
	assert(business.pick_up_box() and business.shelve_box())
	feed.refresh()
	assert(feed.entries.is_empty())
	assert(business.order_stock("snack"))
	feed.refresh()
	assert(feed.entries["stock:snack"].detail.contains("on the way"))
	assert(business.receive_delivery())
	# Re-create both outstanding requests for crowded-feed layout checks.
	business.staff.records.cashier.state = "pay"
	business.staff.records.cashier.unpaid = 50
	business.staff.records.stock.state = "leave"
	business.operating_due = 100
	feed.refresh()
	assert(feed.entries.size() == 5)
	for size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		await process_frame
		feed.refresh()
		assert(Rect2(Vector2.ZERO, Vector2(size)).encloses(feed.get_rect()))
		assert(feed.list.size.x <= feed.scroll.size.x)
		assert(feed.rows.size() == feed.entries.size())
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			assert(not img.is_empty())
			assert(img.save_png(OS.get_environment("TEMP").path_join("notifications_%dx%d.png" % [size.x, size.y])) == OK)
	ui.shop_menu.show()
	feed.refresh()
	assert(not feed.visible)
	ui.shop_menu.hide()
	feed.refresh()
	assert(feed.visible and not ui.player._menu_is_open())
	business.save_path = ""
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: nonblocking left notifications, real clickable staff requests, unresolved persistence, overtime/pay clearing, deduplication, low/out-of-stock, restock clearing, unpurchased SKU guard, delivery/bills and responsive feed")
	quit()
