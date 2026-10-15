extends SceneTree

const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("demo_goals_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _capture(ui, label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	ui.tablet._process(1)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("demo_%s.png" % label)) == OK)

func _layout(ui) -> void:
	ui.tablet._process(1)
	var panel = ui.tablet.screen_menu
	var controls = panel.get_children().filter(func(node): return node is Control and node.visible)
	for index in range(controls.size()):
		assert(Rect2(Vector2.ZERO, panel.size).encloses(controls[index].get_rect()), str(controls[index].name))
		assert(controls[index].get_combined_minimum_size().x <= controls[index].size.x, str(controls[index].name))
		for other in range(index + 1, controls.size()):
			assert(not controls[index].get_rect().intersects(controls[other].get_rect()), "%s/%s" % [controls[index].name, controls[other].name])

func _run() -> void:
	var state = Backend.new()
	state.save_path = _path()
	assert(not state.demo.completed() and state.demo.done_flags().count(true) == 0)
	assert(not state.order_stock("bad") and not state.shelve_one() and not state.sell_basket(0, 100))
	assert(state.demo.done_flags().count(true) == 0)
	assert(state.order_stock("bottle", 2) and state.receive_delivery() and state.pick_up_box())
	for index in range(10): assert(state.shelve_one())
	assert(state.demo.player_shelved == 10 and state.demo.ordered)
	assert(state.hire_stock_worker() and not state.demo.worker_stocked)
	assert(state.pick_up_box(true) and state.shelve_box(true))
	assert(state.demo.worker_stocked)
	for index in range(9): assert(state.sell_basket(2, 200, 100))
	assert(state.demo.customers_served == 9 and state.demo.revenue == 1800 and not state.demo.completed())
	assert(state.save_progress())
	var restored = Backend.new()
	restored.load_progress(state.save_path)
	assert(restored.snapshot() == state.snapshot())
	var invalid: Dictionary = state.snapshot()
	invalid.demo_progress.completion_seen = true
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid.demo_progress.player_shelved = 11
	assert(not state._is_valid_snapshot(invalid))
	var legacy: Dictionary = state.snapshot()
	legacy.erase("demo_progress")
	var legacy_path := _path()
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var old_save = Backend.new()
	old_save.load_progress(legacy_path)
	assert(old_save.money == state.money and old_save.stock == state.stock and old_save.stock_worker_hired)
	assert(old_save.demo.customers_served == 0 and old_save.demo.revenue == 0 and not old_save.demo.completed())
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = state.save_path
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("StockWorker").set_physics_process(false)
	current_scene.get_node("ShopOperations").set_process(false)
	var shop = current_scene.get_node("Shop/ShopArea")
	var ui = current_scene.get_node("Ui")
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	player.shop_indoors = true
	player.position = Vector3(-2.5, 1.1, -4)
	player.rotation.y = PI
	player.camera_pivot.rotation.x = deg_to_rad(-6)
	player.spring_arm.spring_length = 0
	ui.shop_menu.show()
	ui.select_tab(4)
	assert(ui.tabs.get_tab_title(4) == "Goals")
	for size in [Vector2i(1152, 648), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		await process_frame
		_layout(ui)
		assert(ui.tablet.screen_menu.get_node("DemoGoal2").text == "Serve customers: 9/10")
		await _capture(ui, "goals_%dx%d" % [size.x, size.y])
	shop._on_close_button_pressed()
	assert(not ui.tablet.visible)
	ui.supplier_menu.open_menu()
	assert(shop.business.sell_basket(2, 200, 100))
	await process_frame
	assert(ui.supplier_menu.visible and not ui.tablet.visible and not shop.business.demo.completion_seen)
	ui.supplier_menu.close_menu()
	await process_frame
	assert(shop.business.demo.completed() and shop.business.demo.completion_seen)
	assert(ui.tablet.visible and ui.selected_tab == 4 and player._menu_is_open())
	assert(ui.shop_menu.get_node("DemoStatusLabel").text == "Demo completed")
	assert(ui.shop_menu.get_node("DemoResultsLabel").text.contains("2,000"))
	for size in [Vector2i(1152, 648), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		await process_frame
		_layout(ui)
		await _capture(ui, "complete_%dx%d" % [size.x, size.y])
	ui.tablet.screen_menu.get_node("DemoContinueButton").pressed.emit()
	assert(not player._menu_is_open())
	ui._process(0)
	assert(not ui.tablet.visible)
	var finished: Dictionary = shop.business.demo.snapshot()
	assert(shop.business.sell_basket(1, 200, 100))
	assert(shop.business.demo.snapshot() == finished)
	restored = Backend.new()
	restored.load_progress(state.save_path)
	assert(restored.demo.snapshot() == finished and restored.demo.completion_seen)
	assert(restored.money == shop.money and restored.stock == shop.stock)
	shop.business.save_path = ""
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: five real-action demo goals, transaction counts/revenue, manual stocking, Sunil fulfillment, old-save preservation, persistence, responsive tablet results, one-time completion and continued gameplay")
	quit()
