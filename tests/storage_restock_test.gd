extends SceneTree

# Player jump, Sunil restocking from warehouse storage, and packing a bought rack
# back into a warehouse package. Uses temporary saves only.
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("storage_restock_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	var save_path := _path()
	fixture.get_node("Shop/ShopArea").save_path = save_path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	var player: CharacterBody3D = current_scene.get_node("Player")

	# Jump: Space lifts the player off the floor, gravity brings them back.
	player.global_position = Vector3(0, 1.2, 6.5)
	for frame in range(30): await physics_frame
	assert(player.is_on_floor())
	var start_y := player.global_position.y
	var press := InputEventKey.new()
	press.keycode = KEY_SPACE
	press.physical_keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	var peak := start_y
	for frame in range(12):
		await physics_frame
		peak = maxf(peak, player.global_position.y)
	var release := press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	assert(peak > start_y + 0.5, "Space must jump: %f -> %f" % [start_y, peak])
	for frame in range(90): await physics_frame
	assert(player.is_on_floor() and absf(player.global_position.y - start_y) < 0.1)

	# Sunil fetches a stored snack box when snacks are out on the shelves.
	assert(business.order_stock("snack") and business.receive_delivery() and business.pick_up_box())
	assert(business.store_product_box(0))
	assert(business.product_stock("snack") == 0 and business.logistics.storage.size() == 1)
	assert(business.storage_restock_slot() == -1 or not business.stock_worker_hired)
	assert(business.hire_stock_worker())
	business.assistant_auto_collect = false
	var sunil = current_scene.get_node("StockWorker")
	sunil._physics_process(0.016)
	assert(sunil.fetch_slot == -1, "Manual mode must not fetch from storage")
	business.assistant_auto_collect = true
	assert(business.storage_restock_slot() == 0)
	for step in range(4000):
		sunil._physics_process(0.05)
		if business.product_stock("snack") == 10: break
	assert(business.product_stock("snack") == 10, "Sunil must shelve the stored box")
	assert(business.logistics.storage.is_empty() and business.worker_carried_stock == 0)
	var restored = load("res://business_backend.gd").new()
	restored.load_progress(save_path)
	assert(restored.save_status == "Save: Loaded" and restored.product_stock("snack") == 10)

	# Pack an empty bought rack back into the warehouse, then unpack it again.
	business.assistant_auto_collect = false
	sunil.route.clear()
	assert(business.order_racks("oil") and business.receive_rack_delivery())
	assert(business.place_rack("oil", Vector2(-2.0, -5.5), 0, -1, true))
	assert(business.racks.records.size() == 4 and business.logistics.rack_delivered.is_empty())
	await process_frame
	var furnishing = current_scene.get_node("RackFurnishing")
	assert(furnishing.models.size() == 4)
	assert(not business.pack_rack(1), "Starting racks stay in the shop")
	assert(furnishing.pack(3))
	assert(business.racks.records.size() == 3 and business.logistics.rack_delivered == ["oil"])
	assert(furnishing.models.size() == 3)
	restored = load("res://business_backend.gd").new()
	restored.load_progress(save_path)
	assert(restored.save_status == "Save: Loaded" and restored.logistics.rack_delivered == ["oil"])
	assert(business.place_rack("oil", Vector2(-2.0, -5.5), 0, -1, true))
	await process_frame
	assert(business.racks.records.size() == 4 and furnishing.models.size() == 4)

	business.save_path = ""
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: player jump, Sunil restocks low products from warehouse storage, pack/unpack bought racks with save reload")
	quit()
