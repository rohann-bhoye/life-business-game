extends SceneTree

# Screenshot of four beds with different ripe crops (temporary save).
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("farm_preview_%d.json" % Time.get_ticks_usec())
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
	var crops := ["carrot", "cabbage", "corn", "apple"]
	for index in range(4):
		assert(business.buy_seeds(1, crops[index]) and business.plant_crop(index, crops[index]) and business.water_crop(index))
	business.advance_clock(400.0)
	current_scene.get_node("Player").set_physics_process(false)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	current_scene.get_node("Landscape").set_camera(camera)
	camera.global_position = Vector3(-24.1, 2.2, 0.2)
	camera.look_at(Vector3(-24.1, 0.3, -3.2))
	for frame in range(8): await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("farm_crops.png"))
	business.save_path = ""
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: farm preview")
	quit()
