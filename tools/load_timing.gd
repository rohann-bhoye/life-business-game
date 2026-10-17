extends SceneTree

# Measures how long Continue takes: scene load, instantiate+pack, scene change
# (_ready of every node) and the first frames, and prints the biggest gaps between
# nodes entering the tree (the slow setup steps). Temporary save only.
var events: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("TEMP").path_join("load_timing_%d.json" % Time.get_ticks_usec())
	var start := Time.get_ticks_msec()
	var resource: PackedScene = load("res://main.tscn.tscn")
	var loaded := Time.get_ticks_msec()
	var scene = resource.instantiate()
	scene.get_node("Shop/ShopArea").save_path = path
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	var repacked := Time.get_ticks_msec()
	node_added.connect(func(node): events.append([Time.get_ticks_msec(), str(node.get_path())]))
	change_scene_to_packed(packed)
	await scene_changed
	var ready := Time.get_ticks_msec()
	var names := OS.get_cmdline_user_args()
	for child in current_scene.get_children():
		if "ALL" in names or child.name in names: child.process_mode = Node.PROCESS_MODE_DISABLED
	var bodies := current_scene.find_children("*", "CollisionObject3D", true, false)
	var shapes := current_scene.find_children("*", "CollisionShape3D", true, false)
	var kinds := {}
	for shape in shapes: kinds[shape.shape.get_class() if shape.shape != null else "none"] = kinds.get(shape.shape.get_class() if shape.shape != null else "none", 0) + 1
	print("BODIES %d SHAPES %s" % [bodies.size(), str(kinds)])
	var frames: Array[int] = []
	for frame in range(5):
		await process_frame
		frames.append(Time.get_ticks_msec())
		print("FRAME %d process=%.2fs physics=%.2fs navigation=%.2fs" % [frame, Performance.get_monitor(Performance.TIME_PROCESS), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS), Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS)])
	print("TIMING load=%d instantiate+pack=%d change_scene(ready)=%d frames=%s total=%d ms" % [loaded - start, repacked - loaded, ready - repacked, str(frames.map(func(t): return t - ready)), frames[-1] - start])
	var gaps: Array = []
	for index in range(1, events.size()):
		gaps.append([events[index][0] - events[index - 1][0], events[index - 1][1], events[index][1]])
	gaps.sort_custom(func(a, b): return a[0] > b[0])
	for gap in gaps.slice(0, 12): print("GAP %d ms after %s (next %s)" % gap)
	var by_part := {}
	for index in range(events.size() - 1):
		var parts: PackedStringArray = events[index][1].split("/")
		var key := "/".join(parts.slice(3, 5 if parts.size() > 4 and parts[3] in ["Neighbourhood", "ShopOperations", "Warehouse", "House"] else 4))
		by_part[key] = by_part.get(key, 0) + events[index + 1][0] - events[index][0]
	var keys := by_part.keys()
	keys.sort_custom(func(a, b): return by_part[a] > by_part[b])
	for key in keys.slice(0, 14): print("PART %5d ms %s" % [by_part[key], key])
	print("LAST node added at +%d ms: %s" % [events[-1][0] - ready, events[-1][1]])
	current_scene.get_node("Shop/ShopArea").business.save_path = ""
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	quit()
