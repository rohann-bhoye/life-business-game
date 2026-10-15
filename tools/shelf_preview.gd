extends SceneTree

# Close-up screenshots of stocked shop shelves (temporary save only).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("shelf_preview_%d.json" % Time.get_ticks_usec())
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
	business.save_path = ""
	for sku in ["soap", "snack", "tomato"]:
		assert(business.order_stock(sku) and business.receive_delivery() and business.pick_up_box())
		while business.carried_stock > 0 and business.shelve_one(): pass
	business.carried_stock = 0
	current_scene.get_node("Player").set_physics_process(false)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	current_scene.get_node("Landscape").set_camera(camera)
	for frame in range(20): await process_frame
	var shots := {"left": [Vector3(-2.6, 1.5, -2.0), Vector3(-4.8, 0.9, -2.0)], "right": [Vector3(-2.6, 1.5, -2.0), Vector3(-0.2, 0.9, -3.0)], "wide": [Vector3(-1.0, 2.2, 1.6), Vector3(-3.0, 0.8, -5.0)], "signs": [Vector3(-3.2, 1.7, 0.6), Vector3(0, 1.75, 0.6)], "bottles": [Vector3(-4.75, 0.62, -0.2), Vector3(-5.6, 0.35, -0.75)], "snacks": [Vector3(-4.75, 0.62, -3.0), Vector3(-5.6, 0.32, -3.55)], "soap": [Vector3(-4.75, 0.62, -5.7), Vector3(-5.6, 0.3, -6.25)]}
	for name in shots:
		camera.global_position = shots[name][0]
		camera.look_at(shots[name][1])
		for frame in range(3): await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("shelves_%s.png" % name))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: shelf preview")
	quit()
