extends SceneTree

# Captures the First Day guide HUD at two sizes using a temporary save.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("guide_preview_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	business.save_path = ""
	assert(business.order_stock("bottle") and business.receive_delivery())
	var ui = current_scene.get_node("Ui")
	for size in [Vector2i(1152, 648), Vector2i(640, 480)]:
		root.size = size
		for i in range(4): await process_frame
		ui._update_first_day_guide()
		var panel: Control = ui.first_day_panel
		var step: Label = ui.first_day_step
		print("GUIDE %dx%d visible=%s text='%s' lines=%d fits=%s" % [size.x, size.y, panel.visible, step.text, step.get_line_count(), step.get_line_count() * step.get_line_height() <= step.size.y])
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("guide_preview_%dx%d.png" % [size.x, size.y]))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: guide preview")
	quit()
