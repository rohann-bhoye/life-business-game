extends SceneTree

# Screenshot of the orders page with a too-high price, to check the coloured price tag
# (supplier_menu.gd, business_backend.gd price rules). Saves TEMP/price_tag.png.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("price_tag_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	root.size = Vector2i(1152, 648)
	for frame in range(8): await process_frame
	current_scene.get_node("DayClock").set_process(false)
	var business = current_scene.get_node("Shop/ShopArea").business
	business.save_path = ""
	var menu = current_scene.get_node("Ui/SupplierMenu")
	menu.open_menu()
	menu.product_input.select(business.Catalog.IDS.find("snack"))
	business.set_product_price("snack", 110)
	menu._load_product()
	for frame in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("price_tag.png"))
	print("PASS: price tag preview  feel=", business.PRICE_FEELS[business.price_feel("snack")])
	quit()
