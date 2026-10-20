extends SceneTree

# Buying shop space (PC: Space): two expansions move the back wall onto the plot
# behind the shop, add floor and two more racks each, and are paid, saved and
# validated. In the world the walls, floor, roof, back-wall decor, lights and the
# plot outside follow, and the new floor is walkable and usable for racks.

const Backend = preload("res://business_backend.gd")
const Store = preload("res://rack_store.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = Backend.new()
	var path := OS.get_environment("TEMP").path_join("expand_%d_%d.json" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	state.load_progress(path)
	assert(state.shop_expansion == 0 and state.rack_limit() == 8 and state.shop_floor_area() == 60)
	assert(state.can_order_racks("bottle", 5) and not state.can_order_racks("bottle", 6))
	# The plot behind the wall is not shop floor yet.
	assert(not state.place_rack("bottle", Vector2(-2.5, -8.5), 3))
	assert(state.next_expansion_cost() == 6000 and state.expand_shop())
	assert(state.money == 44000 and state.expansion_expenses == 6000 and state.total_expenses() == 6000)
	assert(state.shop_expansion == 1 and state.racks.expansion == 1 and state.rack_limit() == 10 and state.shop_floor_area() == 74)
	assert(state._is_valid_snapshot(state.snapshot()))
	assert(state.place_rack("bottle", Vector2(-2.5, -8.5), 3))
	assert(not state.racks.route(Store.ENTRY, Store.approach(state.racks.find(3))).is_empty())
	# A rack on the new floor is refused in a save that never bought the space.
	var invalid: Dictionary = state.snapshot()
	invalid.shop_expansion = 0
	invalid.expansion_expenses = 0
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid.expansion_expenses = 5000
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid.shop_expansion = 3
	assert(not state._is_valid_snapshot(invalid))
	assert(state.save_progress())
	var loaded = Backend.new()
	loaded.load_progress(path)
	assert(loaded.shop_expansion == 1 and loaded.racks.expansion == 1 and loaded.snapshot() == state.snapshot())
	assert(state.expand_shop() and state.shop_expansion == 2 and state.expansion_expenses == 18000 and state.rack_limit() == 12 and state.shop_floor_area() == 87)
	assert(state.next_expansion_cost() == 0 and not state.can_expand_shop() and not state.expand_shop())
	var legacy: Dictionary = Backend.new().snapshot()
	legacy.erase("shop_expansion")
	legacy.erase("expansion_expenses")
	assert(state._is_valid_snapshot(legacy))
	var poor = Backend.new()
	poor.money = 5000
	assert(not poor.can_expand_shop() and not poor.expand_shop() and poor.shop_expansion == 0)
	var failed = Backend.new()
	failed.save_path = path.path_join("missing.json")
	var before: Dictionary = failed.snapshot()
	assert(not failed.expand_shop())
	assert(failed.snapshot() == before and failed.racks.expansion == 0)

	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("expand_world_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	world.get_node("Player").set_physics_process(false)
	var business = world.get_node("Shop/ShopArea").business
	var ops = world.get_node("ShopOperations")
	var building = world.get_node("Shop")
	var plot = ops.get_node("ExpansionPlot")
	var decor = ops.get_node("ShopDecor")
	var welcome_z: float = decor.back_wall.get_node("WelcomeBoard").global_position.z
	assert(is_equal_approx(building.get_node("BackWall").global_position.z, -7.5))
	assert(plot.get_node("SignBoard").visible and plot.get_node("Post0").visible)
	assert(not ops.get_node("ExpansionLight0").visible)
	var menu = world.get_node("Ui/SupplierMenu")
	menu.open_menu()
	menu.tabs.current_tab = 2
	menu._refresh()
	assert(menu.expansion_button.text.ends_with("6,000") and not menu.expansion_button.disabled)
	assert(menu.get_node("SpaceDimensionsLabel").text.begins_with("Floor: 60 m2"))
	menu.expansion_button.pressed.emit()
	assert(business.shop_expansion == 1 and business.money == 44000)
	assert(is_equal_approx(building.get_node("BackWall").global_position.z, -9.75))
	assert(is_equal_approx(building.get_node("Floor").mesh.size.z, 12.15))
	assert(is_equal_approx(building.get_node("RoofTrim").mesh.size.z, 12.55))
	assert(is_equal_approx(decor.back_wall.get_node("WelcomeBoard").global_position.z, welcome_z - 2.25))
	assert(is_equal_approx(building.get_node("InteriorCategory").global_position.z, ops.back_z() + 0.02))
	assert(ops.get_node("ExpansionLight0").visible and not ops.get_node("ExpansionLight1").visible)
	assert(plot.get_node("Post0").position.z < ops.back_z() - 0.1 and plot.get_node("SignBoard").visible)
	assert(menu.expansion_button.text.ends_with("12,000"))
	assert(world.get_node("Ui").shop_level_label.text.contains("74 m2") or not world.get_node("Ui").shop_level_label.text.contains("60 m2"))
	# The new floor is inside the shop and reachable.
	var interior: CollisionShape3D = building.get_node("ShopInterior/CollisionShape3D")
	var inside := AABB(interior.global_position - interior.shape.size / 2, interior.shape.size)
	assert(inside.has_point(Vector3(-3, 1, -9.3)))
	assert(not business.racks.route(Store.ENTRY, Vector3(-3, 0.1, -9.2)).is_empty())
	menu.expansion_button.pressed.emit()
	assert(business.shop_expansion == 2 and is_equal_approx(building.get_node("BackWall").global_position.z, -12.0))
	assert(menu.expansion_button.disabled and menu.expansion_button.text == "Shop fully expanded")
	assert(not plot.get_node("SignBoard").visible and not plot.get_node("Post0").visible)
	assert(ops.get_node("ExpansionLight1").visible)
	menu.close_menu()
	print("PASS: two paid shop expansions, rack limits, new floor for racks and routes, saves/validation/rollback, walls/floor/roof/decor/lights/plot follow, PC Space tab")
	quit()
