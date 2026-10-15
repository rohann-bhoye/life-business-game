extends SceneTree

const Backend = preload("res://business_backend.gd")
var path: String

func _initialize() -> void:
	call_deferred("_run")

func _load_world() -> void:
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
	current_scene.get_node("Customer").set_physics_process(false)
	current_scene.get_node("StockWorker").set_physics_process(false)

func _run() -> void:
	path = OS.get_environment("TEMP").path_join("worker_job_%d_%d.json" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	var state = Backend.new()
	state.load_progress(path)
	assert(state.hire_stock_worker())
	assert(state.place_rack("soap", Vector2(-2.5, -4), 2))
	assert(state.order_stock("soap") and state.receive_delivery())
	assert(state.assign_stock_collection())
	assert(state.stock_collection_assigned and not state.assistant_auto_collect)
	assert(state.set_staff_shift("stock", 540, 1080))
	assert(state.set_employee_work("stock", false))
	await _load_world()
	var business = current_scene.get_node("Shop/ShopArea").business
	var worker = current_scene.get_node("StockWorker")
	assert(business.stock_collection_assigned and not business.assistant_auto_collect)
	worker._physics_process(0.1)
	assert(worker.route.is_empty())
	assert(business.set_employee_work("stock", true))
	worker._physics_process(0.1)
	assert(worker.route.is_empty() and business.stock_collection_assigned)
	business.advance_clock(60)
	worker._physics_process(0.1)
	assert(worker.collecting and not worker.route.is_empty())
	assert(Vector3(4, 0.1, 3.9) in worker.route and Vector3(4, 0.1, 10.7) in worker.route)
	assert(business.save_progress())
	await _load_world()
	business = current_scene.get_node("Shop/ShopArea").business
	worker = current_scene.get_node("StockWorker")
	worker._physics_process(0.1)
	assert(worker.collecting and business.stock_collection_assigned)
	for index in range(500):
		worker._physics_process(0.1)
		if business.worker_carried_stock > 0: break
	assert(business.worker_carried_stock == 10 and not business.stock_collection_assigned)
	assert(worker.target_rack == 3)
	assert(business.save_progress())
	await _load_world()
	business = current_scene.get_node("Shop/ShopArea").business
	worker = current_scene.get_node("StockWorker")
	assert(worker.target_rack == 3)
	assert(worker.route.back().is_equal_approx(business.RackStore.approach(business.racks.find(3))))
	for index in range(500):
		worker._physics_process(0.1)
		if business.worker_carried_stock == 0: break
	assert(business.racks.find(3).amount == 10 and business.inventory.soap.stock == 10)
	assert(not business.stock_collection_assigned)
	assert(business.order_stock("bottle") and business.receive_delivery())
	worker.route.clear()
	assert(worker.assign_delivery())
	worker.global_position = current_scene.get_node("ShopOperations").drop_point
	assert(business.pick_up_box())
	assert(not business.stock_collection_assigned and not worker.collecting and worker.route.is_empty())
	assert(business.drop_box())
	assert(worker.assign_delivery() and business.stock_collection_assigned)
	assert(worker.route.back() == current_scene.get_node("ShopOperations").drop_point)
	var old: Dictionary = business.snapshot()
	old.erase("stock_collection_assigned")
	assert(business._is_valid_snapshot(old))
	old.stock_collection_assigned = "yes"
	assert(not business._is_valid_snapshot(old))
	old.stock_collection_assigned = true
	old.boxed_stock = "invalid"
	assert(not business._is_valid_snapshot(old))
	assert(business._is_valid_snapshot(business.snapshot()))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: assigned collection survives Continue, work-off/on pause, mid-carry moved-rack restore, single fulfillment and manual pickup cancellation")
	quit()
