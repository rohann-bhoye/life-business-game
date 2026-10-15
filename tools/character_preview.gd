extends SceneTree

# Screenshots of the in-game characters (temporary save only).
func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("characters_%s.png" % name))

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("character_preview_%d.json" % Time.get_ticks_usec())
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
	for sku in ["soap", "snack"]:
		assert(business.order_stock(sku) and business.receive_delivery() and business.pick_up_box())
		assert(business.shelve_box(false))
	assert(business.hire_worker() and business.hire_stock_worker() and business.hire_warehouse_worker())
	assert(business.order_stock("bottle", 2) and business.receive_delivery())
	var spawner = current_scene.get_node("CustomerSpawner")
	spawner._on_spawn_timer_timeout()
	spawner._on_spawn_timer_timeout()
	current_scene.get_node("StockWorker").assign_delivery()
	var player := current_scene.get_node("Player")
	player.set_physics_process(false)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	current_scene.get_node("Landscape").set_camera(camera)
	var sunil: Node3D = current_scene.get_node("StockWorker")
	for frame in range(1500):
		await process_frame
		if business.worker_carried_stock > 0 and sunil.global_position.z > 6.0 and frame > 300: break
	camera.global_position = sunil.global_position + Vector3(-2.0, 1.5, -2.2)
	camera.look_at(sunil.global_position + Vector3(0, 0.8, 0))
	for frame in range(3): await process_frame
	await _shot("sunil")
	camera.global_position = Vector3(-0.9, 2.1, -5.5)
	camera.look_at(Vector3(-3.0, 0.7, 1.0))
	for frame in range(3): await process_frame
	await _shot("shop")
	player.global_position = Vector3(0, 1.1, 6.5)
	player.rotation.y = 0
	player.player_mesh.show()
	camera.global_position = Vector3(0.6, 1.3, 4.3)
	camera.look_at(Vector3(0, 0.7, 6.5))
	for frame in range(3): await process_frame
	player.player_mesh.show()
	await _shot("player")
	assert(business.order_stock("soap") or true)
	business.queued_boxes.clear()
	business.boxed_stock = 0
	business.carried_stock = 5
	var carried: Node3D = player.get_node("CarriedBox")
	carried.show()
	camera.global_position = Vector3(2.0, 1.5, 4.6)
	camera.look_at(Vector3(0, 0.6, 6.5))
	for frame in range(4): await process_frame
	player.player_mesh.show()
	await _shot("player_carry")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: character preview")
	quit()
