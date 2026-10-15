extends SceneTree

# Screenshots of the management PC, the tablet and rack labels (temporary save only).
func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("ui_%s.png" % name))

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("ui_preview_%d.json" % Time.get_ticks_usec())
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
	# Mixed rack check: put soap on the snack rack's empty rows.
	var snack_rack: int = 1
	assert(business.order_stock("soap") and business.receive_delivery() and business.pick_up_box())
	assert(business.racks.free_space(snack_rack, "soap") > 0)
	while business.carried_stock > 0 and business.shelve_one(snack_rack): pass
	print("MIX rack1 slots: ", business.racks.find(snack_rack).slots)
	var ui = current_scene.get_node("Ui")
	var player = current_scene.get_node("Player")
	player.set_physics_process(false)
	player.shop_indoors = true
	for frame in range(10): await process_frame
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	camera.global_position = Vector3(-3.6, 1.4, -3.3)
	camera.look_at(Vector3(-5.6, 0.9, -3.3))
	for frame in range(4): await process_frame
	await _shot("rack")
	camera.queue_free()
	await process_frame
	player.global_position = Vector3(-2.5, 1.1, -4)
	player.rotation.y = PI
	player.spring_arm.spring_length = 0
	ui.shop_menu.show()
	ui.select_tab(0)
	for frame in range(6): await process_frame
	await _shot("tablet")
	ui.shop_menu.hide()
	for frame in range(3): await process_frame
	var terminal = current_scene.get_node("ShopOperations").pc.get_node("ComputerTerminal")
	terminal.open(true)
	for frame in range(60): await process_frame
	await _shot("pc")
	terminal.screen_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() != "headless":
		terminal.screen_viewport.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("ui_pc_screen.png"))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: ui preview")
	quit()
