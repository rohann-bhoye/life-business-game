extends SceneTree

var sheet := Image.create(1152, 972, false, Image.FORMAT_RGBA8)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("tab_probe_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	packed.pack(scene)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	for i in 25: await process_frame
	var ui = current_scene.get_node("Ui")
	ui.shop_menu.show()
	for tab in 6:
		ui.select_tab(tab)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(576, 324)
		sheet.blit_rect(image, Rect2i(0, 0, 576, 324), Vector2i((tab % 2) * 576, (tab / 2) * 324))
	sheet.save_png(OS.get_environment("TEMP").path_join("tabs.png"))
	print("SAVED")
	quit()
