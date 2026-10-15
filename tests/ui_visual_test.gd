extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("ShopOperations").enabled = false
	scene.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("life_business_ui_preview_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	var shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("DayClock").set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var ui = current_scene.get_node("Ui")
	shop.shop_menu.show()
	for viewport_size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		ui._layout()
		for tab in range(4):
			ui.select_tab(tab)
			await process_frame
			for menu in [shop.shop_menu, current_scene.get_node("Ui/HouseMenu")]:
				assert(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(menu.get_rect()), "%s viewport %s, rect %s, viewport rect %s" % [menu.name, viewport_size, menu.get_rect(), root.get_visible_rect()])
				var controls = menu.get_children().filter(func(node): return node is Control and node.visible)
				for index in range(controls.size()):
					var control = controls[index]
					assert(Rect2(Vector2.ZERO, menu.size).encloses(control.get_rect()))
					assert(control.get_combined_minimum_size().x <= control.size.x, "%s at %s: minimum %s, actual %s" % [control.name, viewport_size, control.get_combined_minimum_size(), control.size])
					for other in range(index + 1, controls.size()):
						assert(not control.get_rect().intersects(controls[other].get_rect()))
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var path := OS.get_environment("TEMP").path_join("life_business_ui_%dx%d_tab%d.png" % [viewport_size.x, viewport_size.y, tab])
				assert(root.get_texture().get_image().save_png(path) == OK)
		shop.shop_menu.hide()
		shop.player_inside = false
		current_scene.get_node("House/HouseArea").player_inside = false
		ui._process(0.0)
		assert(ui.interaction_label.text == "")
		shop.player_inside = true
		ui._process(0.0)
		assert(ui.interaction_label.text == "My shop")
		shop.player_inside = false
		shop.shop_menu.show()
	shop.buy_stock_button.pressed.emit()
	assert(ui.feedback_label.text.begins_with("10 stock purchased."))
	assert(shop.save_status_label.text == ui.feedback_label.text and not ui.feedback_label.visible)
	assert(ui.hud_money.text == shop.money_label.text)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("life_business_ui_purchase_feedback.png")) == OK)
	ui.select_tab(1)
	shop.sale_price_input.get_line_edit().text = "160"
	ui.select_tab(0)
	assert(shop.selling_price == 160)
	assert(shop.business.set_selling_price(100))
	shop.sale_price_input.set_value_no_signal(100)
	ui._process(5.0)
	assert(not ui.feedback_label.visible)
	while shop.money >= 500:
		assert(shop.business.order_stock() and shop.business.receive_delivery() and shop.business.pick_up_box())
		var slot: int = shop.business.logistics.storage.size()
		assert(shop.business.store_product_box(slot))
	shop.buy_stock_button.pressed.emit()
	assert(ui.feedback_label.text == "Not enough money to buy stock.")
	assert(shop.buy_stock_button.disabled and shop.buy_stock_button.tooltip_text.begins_with("Not enough money."))
	shop.shop_menu.hide()
	current_scene.get_node("Ui/HouseMenu").show()
	ui._process(5.0)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("life_business_ui_home.png")) == OK)
	print("PASS: all shop tabs, HUD/feedback and menu layout at 1152x648, 640x480 and 360x640")
	quit()
