extends SceneTree

# Orders stock, lets the van arrive, unloads it by hand (E) and checks the boxes land.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("van_probe_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	packed.pack(fixture)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	business.save_path = ""
	var ops = current_scene.get_node("ShopOperations")
	assert(business.order_stock("soap"))
	for frame in range(600):
		await process_frame
		if ops.delivery_state == ops.DeliveryState.UNLOADING: break
	print("state=%d wait=%.1f label=%s" % [ops.delivery_state, ops.van_wait, ops.van_status.text])
	assert(ops.delivery_state == ops.DeliveryState.UNLOADING and ops.van_wait > 0.0)
	var player = current_scene.get_node("Player")
	player.global_position = ops.van.global_position + Vector3(0, 0, 2.5)
	print("ready=%s hint=%s" % [ops.van_ready_to_unload(), ops.interaction_hint()])
	assert(ops.try_interact() and ops.van_wait == 0.0)
	for frame in range(400):
		await process_frame
		if business.boxed_stock > 0 or not business.queued_boxes.is_empty(): break
	print("boxed=%d queued=%d supply=%d state=%d" % [business.boxed_stock, business.queued_boxes.size(), business.supply_in_transit, ops.delivery_state])
	assert(business.boxed_stock > 0 or not business.queued_boxes.is_empty())
	print("PASS: van unload")
	quit()
