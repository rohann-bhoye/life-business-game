extends SceneTree

# Stocks every new grocery SKU on the starting racks and screenshots them (temporary save).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("products_preview_%d.json" % Time.get_ticks_usec())
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
	business.save_path = path
	for sku in ["oil", "milk", "bread", "chocolate", "honey"]:
		assert(business.order_stock(sku), sku)
		assert(business.receive_delivery() and business.pick_up_box(), sku)
		while business.carried_stock > 0: assert(business.shelve_one(), sku)
		print("SKU %s stock=%d price=%d" % [sku, business.product_stock(sku), business.product_price(sku)])
	# Save/reload must accept the new SKUs.
	var reloaded = load("res://business_backend.gd").new()
	reloaded.load_progress(path)
	print("RELOAD status=%s oil=%d honey=%d" % [reloaded.save_status, reloaded.product_stock("oil"), reloaded.product_stock("honey")])
	assert(reloaded.product_stock("honey") == 10)
	business.save_path = ""
	current_scene.get_node("Player").set_physics_process(false)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	current_scene.get_node("Landscape").set_camera(camera)
	for frame in range(12): await process_frame
	var shots := {"racks": [Vector3(-3.4, 1.5, -1.6), Vector3(-5.6, 0.7, -3.3)], "close": [Vector3(-4.7, 1.1, -2.6), Vector3(-5.6, 0.75, -3.6)]}
	for name in shots:
		camera.global_position = shots[name][0]
		camera.look_at(shots[name][1])
		for frame in range(3): await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("products_%s.png" % name))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: products preview")
	quit()
