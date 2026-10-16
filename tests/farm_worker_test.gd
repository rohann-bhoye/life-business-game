extends SceneTree

# Farm worker Kiran: hire cost, daytime planting/watering/harvesting, harvests go to
# warehouse storage with a per-harvest fee, saves/validation, plus the walking NPC.
# Also covers the 10% bulk supplier discount. Temporary saves only.
const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("farm_worker_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _run() -> void:
	# Bulk discount: 5+ boxes in one order cost 10% less, and saves stay valid.
	var bulk = Backend.new()
	bulk.save_path = _path()
	assert(bulk.order_cost("snack", 4) == 1600 and bulk.order_cost("snack", 5) == 1800)
	var money: int = bulk.money
	assert(bulk.order_stock("snack", 5) and bulk.money == money - 1800 and bulk.supplier_discounts == 200)
	assert(bulk._is_valid_snapshot(bulk.snapshot()))
	var reloaded = Backend.new()
	reloaded.load_progress(bulk.save_path)
	assert(reloaded.save_status == "Save: Loaded" and reloaded.supplier_discounts == 200)

	# Farm worker backend.
	var state = Backend.new()
	state.save_path = _path()
	assert(state.farm_worker_next_bed() == -1 and not state.farm_worker_work(0), "Not hired yet")
	money = state.money
	assert(state.hire_farm_worker() and state.money == money - 1500 and not state.hire_farm_worker())
	assert(state.farm_worker_next_bed() == -1, "No seeds, nothing to do")
	assert(state.set_farm_crop("corn") and state.buy_seeds(2))
	assert(state.farm_worker_next_bed() == 0 and state.farm_worker_work(0))
	assert(state.farm.plots[0].crop == "corn" and state.farm.crop_seeds.corn == 1)
	assert(state.farm_worker_next_bed() == 0 and state.farm_worker_work(0) and state.farm.plots[0].watered_at >= 0)
	assert(state.farm_worker_next_bed() == 1, "Plants the next bed while corn grows")
	state.advance_clock(400.0)
	money = state.money
	assert(state.farm_worker_next_bed() == 0, "Harvest comes first")
	assert(state.farm_worker_work(0))
	assert(state.logistics.storage.size() == 1 and state.logistics.storage[0].product == "corn" and state.logistics.storage[0].amount == 10)
	assert(state.money == money - 50 and state.farm.worker_fees == 1550 and state.inventory.corn.purchased == 10)
	assert(state.carried_stock == 0, "The player's hands stay free")
	assert(state._is_valid_snapshot(state.snapshot()))
	state.minutes_of_day = 1260.0
	assert(state.farm_worker_next_bed() == -1, "Kiran goes home at 20:00")
	state.minutes_of_day = 880.0
	assert(state.save_progress())
	var restored = Backend.new()
	restored.load_progress(state.save_path)
	assert(restored.save_status == "Save: Loaded" and restored.snapshot() == state.snapshot())
	var invalid: Dictionary = state.snapshot()
	invalid.farm.worker_fees = 1520
	assert(not state._is_valid_snapshot(invalid))

	# In the game: Kiran walks to an empty bed and plants it.
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
	var worker = current_scene.get_node("Farm/FarmWorker")
	assert(not worker.visible)
	var ui = current_scene.get_node("Ui")
	ui.shop_menu.show()
	ui.select_tab(5)
	assert(ui.shop_menu.get_node("HireFarmerButton").visible)
	ui.shop_menu.get_node("HireFarmerButton").pressed.emit()
	assert(business.farm.worker_hired and worker.visible)
	assert(ui.shop_menu.get_node("HireFarmerButton").disabled)
	ui.shop_menu.hide()
	assert(business.buy_seeds(1, "apple") and business.set_farm_crop("apple"))
	for step in range(1200):
		worker._physics_process(0.05)
		if business.farm.plots[0].planted: break
	assert(business.farm.plots[0].planted and business.farm.plots[0].crop == "apple", "Kiran must plant the apple seed")

	business.save_path = ""
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: bulk discount, farm worker hire/plant/water/harvest-to-storage/fees/hours/saves and walking farmer NPC")
	quit()
