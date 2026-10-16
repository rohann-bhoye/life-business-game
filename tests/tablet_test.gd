extends SceneTree

var path := ""

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	root.push_input(event)
	await process_frame

func _click(tablet, point: Vector2) -> void:
	var uv := point / Vector2(tablet.screen_viewport.size)
	var local := Vector3((uv.x - 0.5) * tablet.screen_size.x, (0.5 - uv.y) * tablet.screen_size.y, tablet.screen_mesh.position.z)
	var pixel: Vector2 = tablet.get_parent().unproject_position(tablet.to_global(local))
	assert(tablet.screen_point(pixel).distance_to(point) < 0.01)
	var motion := InputEventMouseMotion.new()
	motion.position = pixel
	root.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pixel
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func _tab(tablet, index: int) -> void:
	var tabs := tablet.screen_menu.get_node("ShopTabs") as TabBar
	await _click(tablet, tabs.position + tabs.get_tab_rect(index).get_center())
	assert(tablet.ui.selected_tab == index and tabs.current_tab == index)

func _capture(tablet, label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var screen: Image = tablet.screen_viewport.get_texture().get_image()
	assert(not screen.is_empty())
	var bright := 0
	for x in range(20, screen.get_width() - 20, 20):
		for y in range(20, screen.get_height() - 20, 20):
			var pixel := screen.get_pixel(x, y)
			if pixel.r > 0.7 and pixel.g > 0.7 and pixel.b > 0.7: bright += 1
	assert(bright > 100, "Tablet viewport is blank or missing its menu")
	var img := root.get_texture().get_image()
	for grip in tablet.grips:
		var thumb: MeshInstance3D = grip.get_node("Thumb")
		var pixel: Vector2i = Vector2i(tablet.get_parent().unproject_position(thumb.global_position))
		var color := img.get_pixelv(pixel)
		assert(color.r > color.g and color.g > color.b, "Tablet screen painted over the hand")
	assert(img.save_png(OS.get_environment("TEMP").path_join("tablet_%s.png" % label)) == OK)

func _run() -> void:
	var scene = load("res://main.tscn.tscn").instantiate()
	path = OS.get_environment("TEMP").path_join("life_tablet_%d.json" % Time.get_ticks_usec())
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
	current_scene.get_node("ShopOperations").set_process(false)
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	player.shop_indoors = true
	player.position = Vector3(-2.5, 1.1, -4.0)
	player.rotation.y = PI
	player.camera_pivot.rotation.x = deg_to_rad(-6)
	player.spring_arm.spring_length = 0
	var shop = current_scene.get_node("Shop/ShopArea")
	assert(shop.business.record_customer_review("sold", 10))
	shop.player_inside = true
	var ui = current_scene.get_node("Ui")
	var tablet = ui.tablet
	assert(tablet != null and not tablet.visible)
	assert(tablet.get_parent() == player.camera)
	await _key(KEY_E)
	assert(tablet.visible and shop.shop_menu.visible and player._menu_is_open())
	assert(shop.shop_menu.modulate.a == 0 and tablet.screen_menu.modulate.a == 1)
	assert(tablet.screen_mesh.material_override.albedo_texture == tablet.screen_viewport.get_texture())
	tablet._process(1)
	var transform: Transform3D = player.transform
	var look := InputEventMouseMotion.new()
	look.position = Vector2(10, 10)
	look.relative = Vector2(90, 90)
	root.push_input(look)
	assert(player.transform == transform)
	await _key(KEY_E, true)
	assert(tablet.visible)
	for size in [Vector2i(1152, 648), Vector2i(994, 618), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		await process_frame
		tablet._process(1)
		var safe := Rect2(Vector2(20, 52), Vector2(size) - Vector2(40, 72))
		assert(safe.encloses(tablet.device_pixel_bounds(player.camera)), "Bezel/hands clipped at %s: %s" % [size, tablet.device_pixel_bounds(player.camera)])
		assert(tablet.screen_menu.theme.get_stylebox("panel", "Panel") is StyleBoxFlat)
		await process_frame
		await process_frame
		var menu_tabs := tablet.screen_menu.get_node("ShopTabs") as TabBar
		assert(menu_tabs.get_theme_constant("tab_separation") >= 6)
		for tab_index in range(1, 5):
			assert(menu_tabs.get_tab_rect(tab_index).position.x - menu_tabs.get_tab_rect(tab_index - 1).end.x >= 6, "viewport=%s tab=%d previous=%s next=%s" % [size, tab_index, menu_tabs.get_tab_rect(tab_index - 1), menu_tabs.get_tab_rect(tab_index)])
		assert(tablet.screen_menu.theme.get_stylebox("tab_selected", "TabBar") is StyleBoxFlat and tablet.screen_menu.theme.get_stylebox("tab_selected", "TabBar").bg_color == preload("res://ui_style.gd").BRAND)
		assert(tablet.screen_menu.theme.get_stylebox("hover_pressed", "Button") is StyleBoxFlat)
		for grip in tablet.grips:
			for part in grip.get_children():
				assert(part.material_override.render_priority > tablet.screen_mesh.material_override.render_priority)
		for index in range(5):
			await _tab(tablet, index)
			tablet.sync_controls()
			if index == 3:
				assert(tablet.screen_menu.get_node("ReputationLabel").text == "Reputation: 52/100\nLast satisfaction: 75/100")
			var controls = tablet.screen_menu.get_children().filter(func(node): return node is Control and node.visible)
			for i in range(controls.size()):
				assert(Rect2(Vector2.ZERO, tablet.screen_menu.size).encloses(controls[i].get_rect()), "%s: rect=%s parent=%s source=%s" % [controls[i].name, controls[i].get_rect(), tablet.screen_menu.size, shop.shop_menu.size])
				assert(controls[i].get_combined_minimum_size().x <= controls[i].size.x, "%s: min=%s size=%s" % [controls[i].name, controls[i].get_combined_minimum_size(), controls[i].size])
				for j in range(i + 1, controls.size()): assert(not controls[i].get_rect().intersects(controls[j].get_rect()), str(controls[i].name))
			await _capture(tablet, "%dx%d_tab%d" % [size.x, size.y, index])
		for corner in [Vector2(-0.5, -0.5), Vector2(0.5, 0.5)]:
			var world: Vector3 = tablet.to_global(Vector3(corner.x * tablet.screen_size.x, corner.y * tablet.screen_size.y, 0.027))
			var pixel: Vector2 = player.camera.unproject_position(world)
			assert(Rect2(Vector2.ZERO, Vector2(size)).has_point(pixel), "Tablet extends beyond viewport")
	root.size = Vector2i(1152, 648)
	await process_frame
	var original_fov: float = player.camera.fov
	var original_aspect: int = player.camera.keep_aspect
	for mode in [Camera3D.KEEP_HEIGHT, Camera3D.KEEP_WIDTH]:
		for fov in [50.0, 90.0]:
			player.camera.keep_aspect = mode
			player.camera.fov = fov
			tablet._resize()
			tablet._process(1)
			assert(Rect2(Vector2(20, 52), Vector2(1112, 576)).encloses(tablet.device_pixel_bounds(player.camera)), "FOV framing: %s/%s" % [mode, fov])
	player.camera.fov = original_fov
	player.camera.keep_aspect = original_aspect
	tablet._resize()
	await _tab(tablet, 3)
	var money: int = shop.money
	var button := tablet.screen_menu.get_node("MarketingButton") as Button
	await _click(tablet, button.get_rect().get_center())
	assert(shop.money == money - 200 and shop.marketing_active)
	tablet.sync_controls()
	assert(button.disabled and tablet.screen_menu.get_node("MoneyLabel").text == shop.money_label.text)
	await _tab(tablet, 1)
	var price := tablet.screen_menu.get_node("SalePriceInput") as SpinBox
	price.get_line_edit().text = "160"
	price.get_line_edit().grab_focus()
	await _key(KEY_ENTER)
	assert(not tablet.visible and not player._menu_is_open() and shop.selling_price == 160, "visible=%s menu=%s price=%s copy=%s source=%s" % [tablet.visible, player._menu_is_open(), shop.selling_price, price.get_line_edit().text, shop.sale_price_input.get_line_edit().text])
	for code in [KEY_E, KEY_ESCAPE, KEY_KP_ENTER]:
		await _key(KEY_E)
		assert(tablet.visible)
		await _key(code)
		assert(not tablet.visible and not shop.shop_menu.visible and not player._menu_is_open())
	await _key(KEY_E)
	tablet._process(1)
	var close := tablet.screen_menu.get_node("CloseButton") as Button
	await _click(tablet, close.get_rect().get_center())
	assert(not tablet.visible)
	await _key(KEY_E)
	ui.supplier_menu.open_menu()
	assert(not tablet.visible and ui.supplier_menu.visible)
	ui.supplier_menu.close_menu()
	var restored = load("res://business_backend.gd").new()
	assert(shop.business.save_progress())
	restored.load_progress(path)
	for field in shop.business.snapshot():
		if shop.business.snapshot()[field] is float:
			assert(is_equal_approx(restored.snapshot()[field], shop.business.snapshot()[field]))
		else: assert(restored.snapshot()[field] == shop.business.snapshot()[field], field)
	shop.business.save_path = ""
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: real 3D held tablet, preserved ShopMenu paths, clickable viewport tabs/actions, single-charge marketing, live labels, price drafts/Enter, E/Escape/close, echo guard, look lock, PC transition, responsive layouts/framing and save compatibility")
	quit()
