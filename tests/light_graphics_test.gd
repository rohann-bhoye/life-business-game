extends SceneTree

const Settings = preload("res://game_settings.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("light_graphics_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var settings = Settings.new()
	settings.graphics = 0
	settings.apply_graphics(current_scene)
	await process_frame
	var details = current_scene.get_node("Neighbourhood/EnvironmentDetails")
	assert(details.get_node("WindGrass").visible and details.grass_chunks.all(func(chunk): return chunk.multimesh.visible_instance_count < chunk.multimesh.instance_count and chunk.visibility_range_end < 30.0))
	assert(not details.get_node("GardenWater").visible and not details.is_processing())
	assert(details.clouds.all(func(cloud): return not cloud.visible))
	var neighbourhood = current_scene.get_node("Neighbourhood")
	var tree = neighbourhood.find_child("Tree*", false, false)
	assert(tree != null and tree.visible and not neighbourhood.get_node("StreetLife").visible and not neighbourhood.get_node("StreetLife").is_physics_processing())
	assert(not current_scene.get_node("DirectionalLight3D").shadow_enabled)
	var lighting = current_scene.get_node("DayNight")
	assert(not lighting.environment.fog_enabled and not lighting.streetlights_on)
	assert(current_scene.get_node("Road").visible and current_scene.get_node("Shop").visible and current_scene.get_node("Warehouse").visible)
	assert(current_scene.get_node("ShopOperations").rack.visible and current_scene.get_node("Farm").visible)
	settings.graphics = 1
	settings.apply_graphics(current_scene)
	await process_frame
	assert(details.get_node("WindGrass").visible and details.get_node("GardenWater").visible and details.is_processing())
	assert(tree.visible and neighbourhood.get_node("StreetLife").visible and neighbourhood.get_node("StreetLife").is_physics_processing())
	assert(current_scene.get_node("DirectionalLight3D").shadow_enabled and lighting.environment.fog_enabled)
	if DisplayServer.get_name() != "headless":
		settings.graphics = 0
		settings.apply_graphics(current_scene)
		root.size = Vector2i(1152, 648)
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.current = true
		camera.position = Vector3(5, 2, 10)
		camera.look_at(Vector3(-3, 1, 0))
		current_scene.get_node("Landscape").set_camera(camera)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("light_graphics_preview.png")) == OK)
	print("PASS: Low Fast keeps light close-by grass and removes other decorative scenery effects while preserving road, shop, warehouse, racks and farm; Balanced restores them")
	quit()
