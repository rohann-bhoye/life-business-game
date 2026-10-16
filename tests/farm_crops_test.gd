extends SceneTree

# Carrot/cabbage/corn/apple farming: per-crop seeds, planting, harvest boxes that
# shelve and sell, saves, validation, legacy tomato-only saves and the tablet picker.
const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("farm_crops_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _run() -> void:
	var state = Backend.new()
	state.save_path = _path()
	var money: int = state.money
	assert(state.set_farm_crop("carrot") and not state.set_farm_crop("gold"))
	assert(state.buy_seeds(2) and state.money == money - 160)
	assert(state.buy_seeds(1, "apple") and state.money == money - 310)
	assert(state.farm.crop_seeds.carrot == 2 and state.farm.crop_seeds.apple == 1 and state.farm.seeds == 3)
	assert(not state.plant_crop(0, "corn"), "No corn seeds")
	assert(state.plant_crop(0) and state.farm.plots[0].crop == "carrot")
	assert(state.plant_crop(1, "apple") and state.farm.crop_seeds.apple == 0)
	assert(state.water_crop(0) and state.water_crop(1))
	state.advance_clock(400.0)
	assert(state.harvest_crop(0))
	assert(state.carried_stock == 10 and state.pending_product == "carrot")
	assert(state.inventory.carrot.purchased == 10 and state.farm.crop_harvested.carrot == 10 and state.farm.harvested == 10)
	assert(state.shelve_box() and state.product_stock("carrot") == 10)
	assert(state.sell_basket(2, 1000, -1, "carrot") and state.product_stock("carrot") == 8)
	assert(state.harvest_crop(1) and state.pending_product == "apple" and state.farm.crop_harvested.apple == 10)
	assert(state._is_valid_snapshot(state.snapshot()))

	# Saved and restored exactly.
	assert(state.save_progress())
	var restored = Backend.new()
	restored.load_progress(state.save_path)
	assert(restored.save_status == "Save: Loaded" and restored.snapshot() == state.snapshot())
	assert(restored.farm.crop == "carrot" and restored.farm.crop_harvested.apple == 10)

	# Per-crop counters must match the totals; unknown crops are rejected.
	var invalid: Dictionary = state.snapshot()
	invalid.farm.crop_harvested.carrot = 20
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid.farm.plots[2].crop = "gold"
	assert(not state._is_valid_snapshot(invalid))

	# Older tomato-only farm data loads with every count belonging to tomatoes.
	var legacy = Backend.new()
	legacy.save_path = _path()
	assert(legacy.buy_seeds(3) and legacy.plant_crop(0))
	var old: Dictionary = legacy.snapshot()
	for field in ["crop", "crop_seeds", "crop_bought", "crop_harvested"]: old.farm.erase(field)
	old.farm.plots[0].erase("crop")
	assert(legacy._is_valid_snapshot(old))
	var file := FileAccess.open(legacy.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var migrated = Backend.new()
	migrated.load_progress(legacy.save_path)
	assert(migrated.save_status == "Save: Loaded")
	assert(migrated.farm.crop == "tomato" and migrated.farm.crop_seeds.tomato == 2 and migrated.farm.crop_bought.tomato == 3)
	assert(migrated.farm.expenses() == legacy.farm.expenses())

	# In the game: the tablet crop button cycles crops and beds show the crop's models.
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = _path()
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	var ui = current_scene.get_node("Ui")
	var farm = current_scene.get_node("Farm")
	ui.shop_menu.show()
	ui.select_tab(5)
	var crop_button: Button = ui.shop_menu.get_node("FarmCropButton")
	assert(crop_button.visible and crop_button.text == "Crop: Tomato >")
	crop_button.pressed.emit()
	assert(business.farm.crop == "carrot" and crop_button.text == "Crop: Carrot >")
	assert(ui.shop_menu.get_node("BuySeedsButton").text == "Buy carrot seeds - Rs80")
	ui.shop_menu.get_node("BuySeedsButton").pressed.emit()
	assert(business.farm.crop_seeds.carrot == 1)
	ui.shop_menu.hide()
	assert(farm.labels[0].text == "EMPTY | E: PLANT CARROT (1)")
	assert(business.plant_crop(0) and business.water_crop(0))
	assert(farm.crop_kinds[0] == "carrot" and farm.labels[0].text.begins_with("CARROT"))

	business.save_path = ""
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: per-crop seeds/planting/harvest, crop boxes shelve and sell, saves, validation, legacy tomato farms, tablet crop picker and bed models")
	quit()
