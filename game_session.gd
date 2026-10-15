extends RefCounted

const Backend := preload("res://business_backend.gd")

static func save_summary(path: String) -> Dictionary:
	var state = Backend.new()
	state.load_progress(path)
	var valid: bool = state.save_status in ["Save: Loaded", "Save: Backup recovered", "Save: Recovery loaded"]
	return {"valid": valid, "state": state}

static func new_game(path: String) -> String:
	# Archive every prior save/recovery file before replacing the active slot.
	var archive := path.get_base_dir().path_join("save_history")
	for suffix in ["", ".bak", ".recovered", ".recovered.bak"]:
		if not FileAccess.file_exists(path + suffix): continue
		if DirAccess.make_dir_recursive_absolute(archive) != OK: return "Could not create save archive."
		var target := archive.path_join("%s_%d_%d.json" % [path.get_file(), int(Time.get_unix_time_from_system()), Time.get_ticks_usec()])
		if DirAccess.copy_absolute(path + suffix, target) != OK: return "Could not archive existing progress."
	var state = Backend.new()
	state.save_path = path
	return "" if state.save_progress() else "Could not create a new save."

static func launch_game(tree: SceneTree, path: String, settings_path: String) -> Error:
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = path
	scene.set_meta("session_save_path", path)
	scene.set_meta("session_settings_path", settings_path)
	return _launch(tree, scene)

static func launch_menu(tree: SceneTree, path: String, settings_path: String) -> Error:
	var scene = load("res://main_menu.tscn").instantiate()
	scene.save_path = path
	scene.settings_path = settings_path
	return _launch(tree, scene)

static func _launch(tree: SceneTree, scene: Node) -> Error:
	var packed := PackedScene.new()
	var error := packed.pack(scene)
	scene.free()
	if error != OK: return error
	return tree.change_scene_to_packed(packed)
