extends SceneTree

# Story start: Apna Mart for sale at the door, Seth Ramlal's talk, then the bought shop (temp save).
func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	for index in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("sale_%s.png" % name))

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("sale_%d.json" % Time.get_ticks_usec())
	assert(preload("res://game_session.gd").new_game(path, 1, true) == "")
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	for index in range(10): await process_frame
	var business = current_scene.get_node("Shop/ShopArea").business
	print("owned=", business.shop_owned, " money=", business.money, " price=", business.shop_price())
	var player = current_scene.get_node("Player")
	player.global_position = Vector3(-3.0, 1.2, 8.5)
	player.rotation.y = 0.0
	await _shot("1_door")
	var ops = current_scene.get_node("Shop/ShopOperations") if current_scene.has_node("Shop/ShopOperations") else null
	print("hint=", ops.interaction_hint() if ops != null else "no ops")
	current_scene.get_node("Ui/ShopSaleDialog").open_for(current_scene.get_node("ShopSale"))
	await _shot("2_talk")
	print("can_buy=", business.can_buy_shop(), " save=", business.save_path)
	var ok := false
	print("buy_shop=", ok, " status=", business.save_status)
	for step in range(4):
		current_scene.get_node("Ui/ShopSaleDialog")._reply(0)
		await _shot("story%d" % step)
	await _shot("3_bought")
	print("after owned=", business.shop_owned, " money=", business.money)
	for index in range(120): await process_frame
	await _shot("4_open")
	quit()
