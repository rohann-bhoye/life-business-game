extends SceneTree

# Screenshots for the game website (1920x1080 WebP, High graphics, no HUD) from a
# temporary save. Run graphically:
#   Godot --path . --script res://tools/website_shots.gd -- <output folder>
const Settings := preload("res://game_settings.gd")
var out := ""
var camera: Camera3D

func _initialize() -> void:
	call_deferred("_run")

func _save(image: Image, name: String) -> void:
	assert(image.save_webp(out.path_join(name + ".webp"), true, 0.86) == OK)
	print("SHOT ", name, " ", image.get_size())

func _world(name: String, from: Vector3, to: Vector3, frames := 6) -> void:
	camera.global_position = from
	camera.look_at(to, Vector3.UP)
	for frame in range(frames): await process_frame
	await RenderingServer.frame_post_draw
	_save(root.get_texture().get_image(), name)

func _viewport(viewport: SubViewport, name: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	_save(viewport.get_texture().get_image(), name)

## Product thumbnails and staff portraits trimmed to their content and centred
## on a square, so the website can show them at any size without empty margins.
func _icon(source: String, name: String) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(source))
	image.convert(Image.FORMAT_RGBA8)
	var used := image.get_used_rect()
	var side := int(maxf(used.size.x, used.size.y) * 1.12)
	var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
	square.blit_rect(image, used, Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2))
	if side > 192: square.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	var folder := out.path_join("../icons").simplify_path()
	DirAccess.make_dir_recursive_absolute(folder)
	assert(square.save_png(folder.path_join(name + ".png")) == OK)

func _restock(business) -> void:
	for id in ["bottle", "snack", "milk"]:
		var ordered: bool = business.order_stock(id)
		var received: bool = business.receive_delivery()
		var picked: bool = business.pick_up_box()
		var shelved: bool = business.shelve_box()
		print("RESTOCK ", id, " order=", ordered, " receive=", received, " pick=", picked, " shelve=", shelved, " shelf=", business.product_stock(id))

func _walk(customer, seconds: float) -> void:
	for step in range(int(seconds / 0.05)):
		if not is_instance_valid(customer) or customer.is_queued_for_deletion(): return
		customer._physics_process(0.05)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else OS.get_environment("TEMP").path_join("website_shots")
	DirAccess.make_dir_recursive_absolute(out)
	for id in ["bottle", "snack", "milk", "tomato", "soap", "oil", "apple"]: _icon("res://assets/ui/products/%s.png" % id, id)
	for role in ["cashier", "stock", "warehouse"]: _icon("res://assets/ui/staff/%s.png" % role, role)
	var path :=OS.get_environment("TEMP").path_join("website_shots_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	fixture.set_meta("mixed_baskets", true)
	fixture.set_meta("town_customers", true)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	root.size = Vector2i(1920, 1080)
	current_scene.get_node("DayClock").set_process(false)
	var spawner = current_scene.get_node("CustomerSpawner")
	spawner.get_node("SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	var ops = current_scene.get_node("ShopOperations")
	var ui = current_scene.get_node("Ui")
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	var settings = Settings.new()
	settings.graphics = 2
	settings.apply_graphics(current_scene)
	# Day 1: sell the starting bottles, sleep: the end-of-day report.
	for quantity in [3, 3, 2, 2]: business.sell_basket(quantity, 1000)
	business.record_customer_review("sold", 5.0)
	assert(business.grant_home())
	business.advance_clock(1260.0 - business.minutes_of_day)
	player.indoors = true
	player.global_position = Vector3(3.0, 1.1, -4.7)
	player.rotation.y = PI
	for frame in range(3): await physics_frame
	if current_scene.get_node("House/Bed/SleepArea").try_sleep():
		for frame in range(6): await process_frame
		await RenderingServer.frame_post_draw
		_save(root.get_texture().get_image(), "day_report")
		ui.day_report_screen.close()
	# Day 2 morning: shelves stocked again.
	_restock(business)
	ops.update_rack()
	business.minutes_of_day = 630
	business.clock_changed.emit()
	camera = Camera3D.new()
	camera.far = 400
	current_scene.add_child(camera)
	camera.current = true
	current_scene.get_node("Landscape").set_camera(camera)
	ui.hide()
	var starter = current_scene.get_node_or_null("Customer")
	if is_instance_valid(starter): starter.queue_free()
	await process_frame
	# Street: customers walking in along the pavement.
	var walkers: Array = []
	for index in range(3):
		spawner._on_spawn_timer_timeout()
		var visitor = spawner.customers[-1]
		visitor.set_physics_process(false)
		walkers.append(visitor)
	_walk(walkers[0], 0.05)
	_walk(walkers[1], 0.05)
	_walk(walkers[2], 0.05)
	for index in range(3):
		# Put them at different distances from the door.
		var visitor = walkers[index]
		visitor.global_position.x = signf(visitor.global_position.x) * [3.0, 7.5, 13.0][index]
	await _world("street_day", Vector3(10.5, 3.3, 11.8), Vector3(-3.0, 1.2, 3.4), 10)
	await _world("street_wide", Vector3(22, 5.5, 16), Vector3(-6.0, 1.0, 2.0))
	# Inside: customers at the racks.
	for visitor in walkers: _walk(visitor, 14.0)
	await _world("shop_interior", Vector3(-0.6, 2.6, -6.9), Vector3(-4.0, 0.7, 1.2))
	# Checkout: a mixed basket on the counter (only this customer in view).
	for index in range(1, walkers.size()):
		if is_instance_valid(walkers[index]): walkers[index].hide()
	var buyer = walkers[0]
	buyer.global_position = ops.queue_position(buyer)
	buyer.look_at(ops.cashier_point, Vector3.UP)
	buyer.product_id = "bottle"
	buyer.basket_count = 2
	buyer.has_product = true
	buyer.extra_lines = [{"product": "snack", "rack": -1, "count": 2, "taken": true}, {"product": "soap", "rack": -1, "count": 1, "taken": true}]
	buyer.state = buyer.State.SCANNING
	ops.show_basket(buyer)
	await _world("checkout", ops.counter.global_position + Vector3(0.5, 1.35, -1.9), ops.counter.global_position + Vector3(-0.2, 0.55, 0.7))
	await _world("farm", Vector3(-20.5, 3.2, 3.2), Vector3(-25.0, 0.2, -3.5))
	# Night street.
	business.minutes_of_day = 1250
	business.clock_changed.emit()
	await _world("street_night", Vector3(9.5, 2.6, 12.5), Vector3(-3.0, 1.4, 3.4), 12)
	business.minutes_of_day = 630
	business.clock_changed.emit()
	# Shop PC apps (the PC screen itself is drawn at 1920x1080).
	business.hire_stock_worker()
	ui.show()
	# No leftover game message toast over the PC screen.
	ui.feedback_seconds = 0.0
	var terminal = ops.pc.get_node("ComputerTerminal")
	terminal.open()
	await create_timer(0.6).timeout
	await _viewport(terminal.screen_viewport, "pc_desktop")
	terminal.show_app("staff")
	await _viewport(terminal.screen_viewport, "pc_staff")
	terminal.show_app("store")
	terminal.store.add_to_cart("oil", 5)
	terminal.store.add_to_cart("milk", 2)
	terminal.store.add_to_cart("apple", 1)
	await _viewport(terminal.screen_viewport, "pc_store")
	terminal.show_app("bank")
	await _viewport(terminal.screen_viewport, "pc_bank")
	# Day 3: Sharma's store is open, with its daily sale shown in the Shop Manager.
	business.day = business.RIVAL_OPEN_DAY
	business.clock_changed.emit()
	business.changed.emit()
	terminal.show_app("manager")
	await _viewport(terminal.screen_viewport, "pc_manager")
	terminal.close()
	ui.hide()
	var traffic = current_scene.get_node_or_null("Neighbourhood/Traffic")
	if traffic != null: traffic.hide()
	await _world("rival", Vector3(21.0, 3.4, 8.4), Vector3(25.2, 1.3, 15.0), 30)
	if traffic != null: traffic.show()
	ui.show()
	# Shop tablet.
	ui.shop_menu.show()
	ui.select_tab(0)
	await _viewport(ui.tablet.screen_viewport, "tablet")
	ui.shop._on_close_button_pressed()
	business.save_path = ""
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: website shots in ", out)
	quit()
