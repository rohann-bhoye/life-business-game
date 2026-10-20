extends SceneTree

# Renders the pictures of the How to Play guide (how_to_play.gd) from the game:
# assets/ui/howto/<page>.jpg at 800x450. Run with a window, then import:
#   Godot --path . --script res://tools/how_to_play_pictures.gd
#   Godot --headless --path . --import
const OUT := "res://assets/ui/howto/"

func _initialize() -> void:
	call_deferred("_run")

func _save(name: String, frames := 14) -> void:
	for frame in range(frames): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(800, 450, Image.INTERPOLATE_LANCZOS)
	image.save_jpg(ProjectSettings.globalize_path(OUT + name + ".jpg"), 0.86)
	print("PICTURE ", name)

func _aim(player: Node3D, from: Vector3, at: Vector3, pitch_degrees: float) -> void:
	player.global_position = from
	player.look_at(Vector3(at.x, from.y, at.z), Vector3.UP)
	player.rotation.x = 0
	player.camera_pivot.rotation.x = deg_to_rad(pitch_degrees)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 720)
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("howto_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	var settings = preload("res://game_settings.gd").new()
	settings.graphics = 2
	settings.apply_graphics(world)
	var business = world.get_node("Shop/ShopArea").business
	business.money = 50000
	var ui = world.get_node("Ui")
	var ops = world.get_node("ShopOperations")
	var player = world.get_node("Player")
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var camera := Camera3D.new()
	world.add_child(camera)
	# 1 Shop front.
	ui.visible = false
	camera.current = true
	camera.fov = 62
	camera.global_position = Vector3(-1.6, 2.1, 9.6)
	camera.look_at(Vector3(-3.0, 1.9, 2.5))
	await _save("shop")
	camera.current = false
	ui.visible = true
	# 2 Moving around: inside, crosshair on the cold drink rack.
	player.shop_indoors = true
	_aim(player, Vector3(-3.4, 1.1, 0.6), Vector3(-5.6, 1.0, -0.5), -12)
	await _save("controls")
	# 3 The PC Wholesale page.
	_aim(player, ops.pc.global_position + Vector3(0, 0.6, 1.2), ops.pc.global_position, -10)
	var terminal = ops.pc.get_node("ComputerTerminal")
	terminal.open()
	terminal.show_app("store")
	await _save("pc", 30)
	# 9 APNA Builders on the same PC.
	terminal.show_app("builders")
	await _save("grow", 14)
	terminal.close()
	# 4 Boxes at the warehouse bay.
	assert(business.order_stock("snack", 2) and business.receive_delivery())
	player.shop_indoors = false
	ui.visible = false
	camera.current = true
	camera.fov = 60
	var box: Vector3 = ops.product_delivery_point(0)
	camera.global_position = box + Vector3(2.4, 1.6, -2.6)
	camera.look_at(box + Vector3(0.5, 0.2, 0.3))
	await _save("boxes")
	camera.current = false
	ui.visible = true
	# 5 Stocking a rack with a box in hand.
	assert(business.pick_up_box())
	player.shop_indoors = true
	var record: Dictionary = business.racks.find(0)
	var approach: Vector3 = preload("res://rack_store.gd").approach(record)
	_aim(player, approach + Vector3(0, 1.0, 0), Vector3(record.x, 1.0, record.z), -12)
	await _save("stock")
	business.drop_box()
	# 6 Serving a customer at the counter.
	var visitor = world.get_node("Customer")
	visitor.set_physics_process(false)
	visitor.shopping_quantity = 2
	visitor.wants_discount = false
	visitor.spending_budget = 300
	for step in range(2000):
		if visitor.state == visitor.State.SCANNING: break
		visitor._physics_process(0.05)
	_aim(player, ops.cashier_point + Vector3(0, 1.0, 0), ops.counter.global_position + Vector3(-0.6, 0, 0.3), -28)
	await _save("checkout")
	# 7 Moving the counter with G.
	visitor.hide()
	visitor.state = visitor.State.WAITING
	ops.queue.clear()
	_aim(player, Vector3(-2.0, 1.0, 1.9), Vector3(-2.5, 1.0, -3.0), -24)
	var furnishing = world.get_node("RackFurnishing")
	if furnishing.begin_fixture("counter"):
		furnishing.turn = 3
		await process_frame
		furnishing.set_process(false)
		furnishing._fixture_candidate(Vector3(-2.0, 0.1, -4.5))
	await _save("move")
	furnishing.cancel()
	furnishing.set_process(true)
	# 8 The tablet on the Goals tab.
	_aim(player, Vector3(-3, 1.1, -1), Vector3(-3, 1.1, -4), -6)
	player.open_tablet()
	ui.select_tab(4)
	await _save("tablet", 20)
	ui.shop_menu.hide()
	# 10 The shop at night.
	business.advance_clock(780)
	ui.visible = false
	camera.current = true
	camera.fov = 62
	camera.global_position = Vector3(-1.6, 2.1, 9.6)
	camera.look_at(Vector3(-3.0, 1.9, 2.5))
	await _save("night", 24)
	print("Saved How to Play pictures to ", OUT)
	quit()
