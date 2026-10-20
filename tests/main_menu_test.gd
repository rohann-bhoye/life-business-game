extends SceneTree

const Backend := preload("res://business_backend.gd")
const Session := preload("res://game_session.gd")
var directory := ""
var save_path := ""
var settings_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	root.push_input(event)

## The loading screen covers the scene change, then waits paused for any key and
## fades out with a welcome message.
func _through_loading(expected: String) -> void:
	var loading = root.get_node_or_null("LoadingScreen")
	assert(loading != null and loading.info.text.begins_with(expected), "Loading screen must show the save line")
	assert(loading.get_index() == root.get_child_count() - 1, "Loading screen must take input before the game")
	for frame in range(900):
		if loading.stage == "ready": break
		await process_frame
	assert(loading.stage == "ready" and paused and loading.ready_label.visible and not loading.tip_label.text.is_empty())
	await _capture("loading_ready_%s" % expected.split(" ")[0].to_lower())
	await _key(KEY_SPACE)
	assert(not paused and loading.stage == "done")
	assert(current_scene.get_node("Ui").feedback_label.text.begins_with("Welcome"))
	await create_timer(0.7).timeout
	assert(root.get_node_or_null("LoadingScreen") == null)

func _stop_game() -> void:
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("ShopOperations").set_process(false)
	current_scene.get_node("StockWorker").set_physics_process(false)

func _run() -> void:
	directory = OS.get_environment("TEMP").path_join("main_menu_%d" % Time.get_ticks_usec())
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	save_path = directory.path_join("business.json")
	settings_path = directory.path_join("settings.cfg")
	assert(Session.launch_menu(self, save_path, settings_path) == OK)
	await scene_changed
	await process_frame
	var menu = current_scene
	assert(not menu.launching and menu.continue_button.disabled and not FileAccess.file_exists(save_path))
	assert(menu.get_node("ShopBackground").texture != null)
	for size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		await process_frame
		menu._layout()
		assert(Rect2(Vector2.ZERO, Vector2(size)).encloses(menu.content.get_rect()), "Main menu %s: %s" % [size, menu.content.get_rect()])
		for control in menu.content.get_children(): assert(control.get_combined_minimum_size().x <= control.size.x, str(control.name))
		await _capture("menu_%dx%d" % [size.x, size.y])
	menu._open_settings()
	var settings = menu.settings_menu
	for size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		settings._layout()
		assert(Rect2(Vector2.ZERO, Vector2(size)).encloses(settings.get_rect()))
		assert(Rect2(Vector2.ZERO, settings.size).encloses(settings.footer.get_rect()))
		await _capture("settings_%dx%d" % [size.x, size.y])
	settings.volume.value = 30
	settings.sensitivity.value = 6
	settings.fov.value = 68
	settings.invert.set_pressed_no_signal(true)
	settings._apply()
	assert(not settings.visible and menu.content.visible and FileAccess.file_exists(settings_path))
	menu.new_button.pressed.emit()
	# New Game always asks for the difficulty first.
	assert(menu.confirmation.visible and menu.confirmation.has_node("EasyButton") and menu.confirmation.has_node("HardButton"))
	menu.confirmation.get_node("ConfirmButton").pressed.emit()
	assert(root.get_node_or_null("LoadingScreen") != null and menu.launching)
	await scene_changed
	await process_frame
	_stop_game()
	await _through_loading("New shop")
	var shop = current_scene.get_node("Shop/ShopArea")
	var player = current_scene.get_node("Player")
	assert(shop.money == 10000 and shop.business.starting_money == 10000 and shop.stock == 10 and shop.business.save_path == save_path, "New Game starts with beginner money")
	assert(player.mouse_sensitivity == 0.006 and player.invert_y and player.camera.fov == 68)
	assert(not current_scene.get_node("DirectionalLight3D").shadow_enabled, "Default Low preset must disable sun shadows")
	assert(current_scene.get_meta("session_settings_path") == settings_path)
	# New Game starts at home: the family home is owned free and the player is beside the bed.
	await process_frame
	var house: Node3D = current_scene.get_node("House")
	assert(shop.business.house_owned and shop.business.property_expenses == 0, "New game must own the family home")
	assert(house.to_local(player.global_position).distance_to(preload("res://home_decor.gd").SPAWN) < 0.4, "New game must spawn at home")
	assert(shop.business.order_stock("soap", 2))
	var money: int = shop.money
	# Escape pauses the actual game, not just the mouse.
	current_scene.get_node("DayClock").set_process(true)
	await _key(KEY_ESCAPE)
	var pause = current_scene.get_node("Ui/PauseMenu")
	assert(paused and pause.visible and player._menu_is_open())
	var minute: float = shop.business.minutes_of_day
	await create_timer(0.05).timeout
	assert(shop.business.minutes_of_day == minute)
	await _capture("pause")
	await _key(KEY_ESCAPE)
	assert(not paused and not pause.visible)
	current_scene.get_node("DayClock").set_process(false)
	pause.open_menu()
	pause._settings()
	assert(paused and pause.settings_menu.visible and not pause.visible)
	pause.settings_menu.fov.value = 70
	pause.settings_menu.graphics.select(2)
	pause.settings_menu._apply()
	assert(paused and pause.visible and player.camera.fov == 70)
	await process_frame
	assert(current_scene.get_node("DirectionalLight3D").shadow_enabled)
	assert(current_scene.get_node("DirectionalLight3D").directional_shadow_max_distance == 28.0)
	var saved_graphics := ConfigFile.new()
	assert(saved_graphics.load(settings_path) == OK and saved_graphics.get_value("game", "graphics") == 1)
	pause._return_menu()
	await scene_changed
	await process_frame
	menu = current_scene
	assert(not menu.continue_button.disabled and menu.save_label.text.contains(str(money)))
	var before := FileAccess.get_file_as_string(save_path)
	menu._request_new()
	assert(menu.confirmation.visible)
	await process_frame
	var message: Label = menu.confirmation.get_node("Message")
	assert(Rect2(Vector2.ZERO, menu.confirmation.size).encloses(message.get_rect()))
	await _capture("new_confirmation")
	await _key(KEY_ESCAPE)
	assert(not menu.confirmation.visible and FileAccess.get_file_as_string(save_path) == before)
	menu.continue_button.pressed.emit()
	await scene_changed
	await process_frame
	_stop_game()
	await _through_loading("Continue")
	shop = current_scene.get_node("Shop/ShopArea")
	assert(shop.money == money and shop.business.incoming_boxes.size() == 2)
	current_scene.get_node("Ui/PauseMenu").open_menu()
	current_scene.get_node("Ui/PauseMenu")._return_menu()
	await scene_changed
	await process_frame
	menu = current_scene
	menu._request_new()
	menu.confirmation.get_node("ConfirmButton").pressed.emit()
	await scene_changed
	await process_frame
	_stop_game()
	await _through_loading("New shop")
	shop = current_scene.get_node("Shop/ShopArea")
	assert(shop.money == 10000 and shop.stock == 10 and shop.business.incoming_boxes.is_empty())
	var history := DirAccess.open(directory.path_join("save_history"))
	assert(history != null and history.get_files().size() > 0)
	var found_old := false
	for file_name in history.get_files():
		var archived = Backend.new()
		archived.load_progress(directory.path_join("save_history").path_join(file_name))
		if archived.money == money: found_old = true
	assert(found_old)
	# Backups remain valid Continue sources even if the primary is corrupted.
	shop.business.save_path = ""
	var recovery := directory.path_join("recover.json")
	assert(DirAccess.copy_absolute(save_path, recovery + ".bak") == OK)
	var invalid := FileAccess.open(recovery, FileAccess.WRITE)
	invalid.store_string("invalid")
	invalid.close()
	assert(Session.save_summary(recovery).valid)
	print("PASS: startup lobby, save summary/Continue, confirmed archived New Game, real saved settings, pause/resume, save-return, backup recovery and responsive layouts")
	print("PREVIEWS: " + directory)
	quit()
