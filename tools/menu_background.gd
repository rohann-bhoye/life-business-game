extends SceneTree

# Renders candidate pictures for the main menu and loading screen background on High,
# whatever the player's own settings: several views of the town at a few times of day.
# The menu card and the loading text sit on the left, so each view keeps its subject right
# of centre. Run with a window:  Godot --path . --script res://tools/menu_background.gd
# Pictures go to MENU_BG_OUT (a folder) or user://menu_background. MENU_BG_ONLY=<prefix>
# renders some views; MENU_BG_SAVE=<view>@<hour> also writes that one to
# res://assets/ui/main_menu_town.png. Pass "-- --tester" to leave admin-only things out.
const VIEWS := {
	"hero_far": [Vector3(12.0, 5.5, 18.0), Vector3(-9.0, 1.2, 3.0)],
	"hero_near": [Vector3(6.0, 3.2, 13.0), Vector3(-8.0, 2.0, 1.0)],
	# The one in use (main_menu_town.png): hero_near turned 8 degrees left with a narrower lens,
	# so the giant policeman's legs stay out of the top corner, and tilted up so the shop
	# sits below the What's New card and the loading title. [position, target, fov].
	"hero": [Vector3(6.0, 3.3, 13.0), Vector3(-9.5, 2.9, 3.1), 52.0],
	"hero_high": [Vector3(16.0, 8.5, 22.0), Vector3(-6.0, 0.5, 2.0)],
	"shop_east": [Vector3(9.5, 4.2, 15.0), Vector3(1.5, 1.6, 1.5)],
	"street_west": [Vector3(10.0, 1.9, 6.4), Vector3(-12.0, 1.6, 3.4)],
}
const HOURS := [8.0, 16.5]
const SIZE := Vector2i(1920, 1080)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var folder := OS.get_environment("MENU_BG_OUT")
	if folder == "": folder = ProjectSettings.globalize_path("user://menu_background")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = SIZE
	var fixture = load("res://main.tscn.tscn").instantiate()
	var path := OS.get_environment("TEMP").path_join("menu_background_%d.json" % Time.get_ticks_usec())
	fixture.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = world.get_node("Shop/ShopArea").business
	business.save_path = ""
	world.get_node("Ui").visible = false
	var settings = preload("res://game_settings.gd").new()
	settings.graphics = 2
	settings.render_scale = 1.0
	settings.antialias = 2
	settings.apply_graphics(world)
	for node_name in ["Player", "Customer", "Worker", "StockWorker"]:
		var node := world.get_node_or_null(node_name)
		if node == null: continue
		node.hide()
		node.set_physics_process(false)
	# The hotbar has a layer of its own.
	var bar := world.get_node_or_null("Ui/InventoryBar")
	if bar != null: bar.set_process(false)
	if bar != null and bar.layer != null: bar.layer.visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 58
	camera.make_current()
	# Let walkers and traffic spread along the streets first.
	for frame in range(240): await process_frame
	var only := OS.get_environment("MENU_BG_ONLY")
	var keep := OS.get_environment("MENU_BG_SAVE")
	for hour in HOURS:
		business.minutes_of_day = hour * 60.0
		# The sky and sun follow the clock only when it ticks (DayClock is stopped here).
		world.get_node("DayNight")._refresh()
		for frame in range(30): await process_frame
		for view in VIEWS:
			var label := "%s@%s" % [view, str(hour)]
			if only != "" and not view.begins_with(only) and keep != label: continue
			camera.global_position = VIEWS[view][0]
			camera.look_at(VIEWS[view][1])
			camera.fov = VIEWS[view][2] if VIEWS[view].size() > 2 else 58.0
			for frame in range(12): await process_frame
			# A person or a scooter right in front of the lens fills the picture with a blur
			# (someone stands under this camera all day): hide whatever is that close. The
			# drawing itself is hidden, as the street scripts set their walkers' visibility.
			var hidden := _hide_near(world, camera.global_position, 9.0)
			for frame in range(2): await process_frame
			print("  hid %d close to the lens" % hidden)
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_jpg(folder.path_join("%s_%02d.jpg" % [view, int(hour * 10)]), 0.9)
			print("VIEW %s %dx%d" % [label, image.get_width(), image.get_height()])
			if label == keep:
				assert(image.save_png("res://assets/ui/main_menu_town.png") == OK)
				print("SAVED res://assets/ui/main_menu_town.png")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	quit()

## Hides every person (any node drawn by character_visual.gd, whatever its name) and every
## moving vehicle (town traffic, market autos and scooters) within `radius` of `point`, by
## hiding its drawing; returns how many.
func _hide_near(world: Node, point: Vector3, radius: float) -> int:
	var Visual := preload("res://character_visual.gd")
	var count := 0
	for node in world.find_children("*", "Node3D", true, false):
		if node.get_script() == Visual and node.global_position.distance_to(point) < radius:
			node.visible = false
			count += 1
	for pattern in ["Traffic*", "Market*"]:
		for vehicle in world.find_children(pattern, "Node3D", true, false):
			if "Walker" in vehicle.name or vehicle.global_position.distance_to(point) >= radius: continue
			for part in vehicle.get_children():
				if part is Node3D: part.visible = false
			count += 1
	return count
