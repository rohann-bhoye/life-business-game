extends SceneTree

var save_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(not image.is_empty())
	assert(image.save_png(OS.get_environment("TEMP").path_join(file_name)) == OK)

func _go_to(minutes: float) -> void:
	var business = current_scene.get_node("Shop/ShopArea").business
	business.advance_clock(fposmod(minutes - business.minutes_of_day, 1440.0))
	current_scene.get_node("DayNight")._refresh()

func _stop_simulation() -> void:
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _run() -> void:
	save_path = OS.get_environment("TEMP").path_join("life_business_daynight_%d.json" % Time.get_ticks_usec())
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("ShopOperations").enabled = false
	scene.get_node("Shop/ShopArea").save_path = save_path
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	var graphics = preload("res://game_settings.gd").new()
	graphics.graphics = 1
	graphics.apply_graphics(current_scene)
	_stop_simulation()
	var shop = current_scene.get_node("Shop/ShopArea")
	shop.business.save_path = ""
	assert(shop.business.buy_house())
	var lighting = current_scene.get_node("DayNight")
	assert(lighting.street_lights.size() == 8)
	var north_count := 0
	var south_count := 0
	for light in lighting.street_lights:
		var pole := light.get_parent() as Node3D
		var housing: MeshInstance3D = pole.get_node("Housing")
		var lens: MeshInstance3D = pole.get_node("Lens")
		if pole.global_position.z < 7.0:
			north_count += 1
			assert(housing.global_position.z > pole.global_position.z and light.global_position.z > pole.global_position.z)
		else:
			south_count += 1
			assert(housing.global_position.z < pole.global_position.z and light.global_position.z < pole.global_position.z)
		assert(absf(lens.global_position.z - 7.0) < absf(pole.global_position.z - 7.0))
		assert((-light.global_basis.z).dot(Vector3.DOWN) > 0.99)
	assert(north_count == 4 and south_count == 4)
	assert(not lighting.streetlights_on and not lighting.interior_light.visible)
	var reference = packed.instantiate()
	var original_environment: Environment = reference.get_node("WorldEnvironment").environment
	assert(lighting.environment != original_environment)
	assert(lighting.environment.sky != original_environment.sky)
	assert(lighting.sky_material != original_environment.sky.sky_material)
	reference.free()
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.position = Vector3(10, 8, 16)
	camera.look_at(Vector3(0, 0.9, 1))
	camera.current = true
	_go_to(720.0)
	assert(is_equal_approx(lighting.sun.light_energy, 0.9))
	assert(not lighting.streetlights_on and is_zero_approx(lighting.moon.light_energy))
	var noon_top: Color = lighting.sky_material.sky_top_color
	await _capture("life_business_daynight_noon.png")
	_go_to(1095.0)
	assert(lighting.sun.light_energy < 0.1)
	assert(lighting.sky_material.sky_horizon_color.r > lighting.sky_material.sky_horizon_color.b)
	await _capture("life_business_daynight_sunset.png")
	_go_to(1110.0)
	assert(lighting.streetlights_on and lighting.interior_light.visible)
	_go_to(1260.0)
	assert(is_zero_approx(lighting.sun.light_energy) and lighting.moon.light_energy > 0.1)
	assert(lighting.sky_material.sky_top_color != noon_top)
	for light in lighting.street_lights:
		assert(light.visible and not light.shadow_enabled and light.light_energy > 0)
	for material in lighting.lamp_materials:
		assert(material.emission_enabled)
	var night_state: Dictionary = shop.business.snapshot()
	for iteration in range(10):
		lighting._refresh()
	assert(shop.business.snapshot() == night_state)
	await _capture("life_business_daynight_night.png")
	root.size = Vector2i(640, 480)
	await process_frame
	await _capture("life_business_daynight_night_small.png")
	shop.business.save_path = save_path
	assert(shop.business.save_progress())
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	await process_frame
	_stop_simulation()
	graphics.apply_graphics(current_scene)
	shop = current_scene.get_node("Shop/ShopArea")
	lighting = current_scene.get_node("DayNight")
	assert(lighting.streetlights_on and lighting.interior_light.visible)
	assert(shop.money == night_state["money"] and shop.business.day == night_state["day"])
	assert(absf(shop.business.minutes_of_day - night_state["minutes_of_day"]) < 1.0)
	var money_before_sleep: int = shop.money
	var day_before_sleep: int = shop.business.day
	assert(shop.business.sleep_until_morning())
	assert(shop.business.day == day_before_sleep + 1 and shop.money == money_before_sleep - 100)
	assert(not lighting.streetlights_on and not lighting.interior_light.visible)
	assert(lighting.sun.light_energy > 0.8)
	_go_to(0.0)
	assert(lighting.streetlights_on)
	_go_to(389.0)
	assert(lighting.streetlights_on)
	_go_to(390.0)
	assert(not lighting.streetlights_on)
	_go_to(480.0)
	assert(not lighting.streetlights_on and lighting.sun.light_energy > 0.8)
	shop.business.save_path = ""
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	print("PASS: inward-facing streetlight rows and downward beams, noon/sunset/night/dawn, owned-home light, independent skies, unchanged economy, night restore and morning sleep/billing")
	quit()
