extends SceneTree

# Where do the draw calls come from? For each spot, counts the objects a camera there would
# draw (inside the view cone, inside their draw distance), grouped by the node that owns them
# (two levels deep), biggest first.   Godot --path . --script res://tools/draw_histogram.gd
const SPOTS := {
	"shop_inside": [Vector3(-3.0, 1.75, 2.25), Vector3(-3.0, 1.55, -7.0)],
	"main_road": [Vector3(-6.0, 2.0, 7.0), Vector3(14.0, 2.0, 7.0)],
	"home_lane": [Vector3(-47.0, 2.4, -6.0), Vector3(-61.0, 1.6, -6.0)],
}

func _initialize() -> void:
	call_deferred("_run")

func _owner_key(node: Node, world: Node) -> String:
	var path := world.get_path_to(node).get_concatenated_names().split("/")
	return "/".join(path.slice(0, mini(2, path.size() - 1)))

func _run() -> void:
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("hist_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	packed.pack(fixture)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world = current_scene
	world.get_node("Player").hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 75
	var settings = preload("res://game_settings.gd").new()
	settings.graphics = 0
	settings.apply_graphics(world)
	for frame in range(30): await process_frame
	var items := world.find_children("*", "GeometryInstance3D", true, false)
	for spot in SPOTS:
		camera.global_position = SPOTS[spot][0]
		camera.look_at(SPOTS[spot][1])
		for frame in range(3): await process_frame
		var counts := {}
		var total := 0
		for item in items:
			var node := item as GeometryInstance3D
			if not node.is_visible_in_tree() or node.layers == 0: continue
			var box: AABB = node.global_transform * node.get_aabb()
			var centre := box.get_center()
			if not camera.is_position_in_frustum(centre): continue
			var distance := camera.global_position.distance_to(centre)
			if node.visibility_range_end > 0.0 and distance > node.visibility_range_end: continue
			var key := _owner_key(node, world)
			counts[key] = int(counts.get(key, 0)) + 1
			total += 1
		var keys := counts.keys()
		keys.sort_custom(func(a, b): return counts[a] > counts[b])
		print("HIST ", spot, " total ", total)
		for index in range(mini(12, keys.size())): print("   ", counts[keys[index]], "  ", keys[index])
	quit()
