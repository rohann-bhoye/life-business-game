extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("environment_preview_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	business.minutes_of_day = 660
	business.clock_changed.emit()
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	current_scene.get_node("Landscape").set_camera(camera)
	var details = current_scene.get_node("Neighbourhood/EnvironmentDetails")
	assert(details.get_node("WindGrass").multimesh.instance_count > 100)
	var before: float = details.clouds[0].position.x
	details._process(1.0)
	assert(details.clouds[0].position.x > before)
	for shot in [{"name": "street", "position": Vector3(24, 3, 9), "target": Vector3(-7, 2.5, 3)}, {"name": "garden", "position": Vector3(24, 3.2, -4), "target": Vector3(18, 0.9, -10)}]:
		camera.global_position = shot.position
		camera.look_at(shot.target)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		assert(frame.save_png(OS.get_environment("TEMP").path_join("environment_%s.png" % shot.name)) == OK)
	print("PASS: environment preview, moving clouds and populated grass")
	quit()
