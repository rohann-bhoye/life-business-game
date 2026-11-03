extends SceneTree

var sheet := Image.create(1152, 648, false, Image.FORMAT_RGBA8)

func _initialize() -> void:
	call_deferred("_run")

func _grab(slot: int) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(576, 324)
	sheet.blit_rect(image, Rect2i(0, 0, 576, 324), Vector2i((slot % 2) * 576, (slot / 2) * 324))

func _run() -> void:
	root.size = Vector2i(1152, 648)
	var loading = load("res://loading_screen.gd").new()
	root.add_child(loading)
	loading.begin(func() -> int: return OK, "Continue | Slot 2 | Day 1 | %s10,000" % String.chr(8377), "", false)
	for i in 40: await process_frame
	loading.stage = "idle"
	loading.shown = 0.69
	loading._set_stage("Building the town...")
	loading._draw_fill()
	await _grab(0)
	loading.queue_free()
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("ui_probe_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	packed.pack(scene)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	for i in 20: await process_frame
	var dungeon = current_scene.find_child("DungeonWorld", true, false)
	var player: Node3D = current_scene.get_node("Player")
	player.global_position = dungeon.cave.to_global(Vector3(0, 1.0, 12.0))
	var to: Vector3 = dungeon.cave.global_position - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	for i in 60: await process_frame
	await _grab(1)
	var map = current_scene.get_node("Ui/WorldMap")
	await map.open()
	await _grab(2)
	map.close()
	current_scene.get_node("Ui").shop_menu.show()
	current_scene.get_node("Ui").select_tab(0)
	await _grab(3)
	sheet.save_png(OS.get_environment("TEMP").path_join("ui_bazaar.png"))
	print("SAVED")
	quit()
