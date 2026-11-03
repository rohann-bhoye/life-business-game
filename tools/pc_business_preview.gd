extends SceneTree

# Screenshots the PC desktop and the Business app (temporary save only).
func _initialize() -> void:
	call_deferred("_run")

func _shot(terminal, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	terminal.screen_viewport.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("pcbiz_%s.png" % name))

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("pcbiz_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	packed.pack(fixture)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	root.size = Vector2i(1152, 648)
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Shop/ShopArea").business.save_path = ""
	current_scene.get_node("Player").set_physics_process(false)
	var terminal = current_scene.get_node("ShopOperations").pc.get_node("ComputerTerminal")
	terminal.open()
	for frame in range(30): await process_frame
	await _shot(terminal, "home")
	terminal.show_app("business")
	for frame in range(10): await process_frame
	await _shot(terminal, "business")
	var shop = current_scene.get_node("Shop/ShopArea")
	var before: int = shop.business.money
	shop._on_marketing_button_pressed()
	for frame in range(40): await process_frame
	print("money %d -> %d marketing=%s" % [before, shop.business.money, shop.marketing_active])
	await _shot(terminal, "business2")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS")
	quit()
