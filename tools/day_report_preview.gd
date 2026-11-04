extends SceneTree

# Screenshot of the end-of-day summary card after sleeping (temporary save).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("day_report_preview_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	root.size = Vector2i(1152, 648)
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	# Story games rent the home now; the free home only matters for the bed.
	business.grant_home()
	assert(business.order_stock("snack") and business.receive_delivery() and business.pick_up_box() and business.shelve_box())
	for quantity in [3, 2]: assert(business.sell_basket(quantity, 1000, -1, "snack"))
	assert(business.sell_basket(2, 1000))
	assert(business.record_customer_review("sold", 5.0) and business.record_customer_review("price", 5.0))
	business.advance_clock(1260.0 - business.minutes_of_day)
	var player = current_scene.get_node("Player")
	player.indoors = true
	# Beside the bed, wherever the home stands now.
	player.global_position = current_scene.get_node("House").to_global(preload("res://home_decor.gd").SPAWN)
	player.rotation.y = PI
	for frame in range(3): await physics_frame
	assert(current_scene.get_node("House/Bed/SleepArea").try_sleep())
	for frame in range(4): await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("day_report.png"))
	business.save_path = ""
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: day report preview")
	quit()
