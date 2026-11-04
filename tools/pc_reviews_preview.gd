extends SceneTree

# Screenshots the PC desktop (with the Reviews tile) and the APNA REVIEWS app after a few
# made-up days of shoppers (temporary save only). Pictures: TEMP/pcrev_home.png, pcrev_app.png.
func _initialize() -> void:
	call_deferred("_run")

func _shot(terminal, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	terminal.screen_viewport.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("pcrev_%s.png" % name))

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("pcrev_%d.json" % Time.get_ticks_usec())
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
	# Five days: more shoppers each day, mostly happy, a few out-of-stock and dear ones.
	var names := ["Ramesh", "Sunita", "Arjun", "Meena", "Kiran", "Pooja", "Vikram", "Asha"]
	var products := ["snack", "soap", "milk", "oil", "bread"]
	for day_index in range(5):
		business.day = day_index + 1
		business.minutes_of_day = 480.0
		business.day_report.begin(business)
		for visit in range(14 + day_index * 5):
			business.minutes_of_day = 480.0 + visit * 20.0
			var roll := (visit * 7 + day_index) % 10
			var outcome := "stock" if roll == 3 else ("price" if roll == 7 else "sold")
			business.record_customer_review(outcome, [0.0, 6.0, 25.0, 50.0][visit % 4], roll == 5, names[visit % names.size()], products[visit % products.size()])
		business.day_report.close(business)
	var terminal = current_scene.get_node("ShopOperations").pc.get_node("ComputerTerminal")
	terminal.open()
	for frame in range(30): await process_frame
	await _shot(terminal, "home")
	terminal.show_app("reviews")
	for frame in range(10): await process_frame
	await _shot(terminal, "app")
	print("PASS: pc reviews preview  rating=%.1f written=%d history=%d" % [business.customer_reviews.rating(), business.customer_reviews.written_count(), business.day_report.history.size()])
	quit()
