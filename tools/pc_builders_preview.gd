extends SceneTree

# Screenshots the APNA BUILDERS website (Space and Makeovers pages) with both back rooms
# built, a good rating and a known shop (temporary save only). Pictures: TEMP/pcbuild_*.png.
func _initialize() -> void:
	call_deferred("_run")

func _shot(terminal, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	terminal.screen_viewport.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("pcbuild_%s.png" % name))

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("pcbuild_%d.json" % Time.get_ticks_usec())
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
	var business = current_scene.get_node("Shop/ShopArea").business
	business.save_path = ""
	current_scene.get_node("Player").set_physics_process(false)
	business.shop_expansion = 2
	business.racks.expansion = 2
	business.customer_reviews.seed_rating = 4.2
	business.customer_reviews.seed_weight = 10.0
	business.popularity = 30.0
	var terminal = current_scene.get_node("ShopOperations").pc.get_node("ComputerTerminal")
	terminal.open()
	for frame in range(30): await process_frame
	terminal.show_app("builders")
	for frame in range(10): await process_frame
	await _shot(terminal, "space")
	terminal.builders.show_page("looks")
	for frame in range(6): await process_frame
	await _shot(terminal, "looks")
	print("PASS: pc builders preview  wing block: ", business.wing_block_reason())
	quit()
