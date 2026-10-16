extends SceneTree

# Lobby save slots: three separate save files, the last slot is remembered, and
# returning from a game in slot 2/3 reopens that slot. Temporary files only.
const MainMenu := preload("res://main_menu.gd")
const Backend := preload("res://business_backend.gd")

func _initialize() -> void:
	call_deferred("_run")

func _menu(save_path: String, settings_path: String) -> Control:
	var menu = load("res://main_menu.tscn").instantiate()
	menu.save_path = save_path
	menu.settings_path = settings_path
	root.add_child(menu)
	return menu

func _run() -> void:
	var dir := OS.get_environment("TEMP").path_join("save_slots_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	var base := dir.path_join("business_save.json")
	var settings := dir.path_join("settings.cfg")
	assert(MainMenu.slot_path(base, 1) == base)
	assert(MainMenu.slot_path(base, 2) == dir.path_join("business_save_2.json"))
	var first = Backend.new()
	first.save_path = base
	assert(first.save_progress())
	var menu = _menu(base, settings)
	await process_frame
	assert(menu.slot == 1 and menu.save_path == base and not menu.continue_button.disabled)
	assert(menu.save_label.text.begins_with("Slot 1"))
	menu.get_node("MainActions/SlotRow/Slot2").pressed.emit()
	assert(menu.slot == 2 and menu.save_path == MainMenu.slot_path(base, 2))
	assert(menu.continue_button.disabled and menu.save_label.text.contains("Slot 2 is empty"))
	assert(menu.get_node("MainActions/SlotRow/Slot2").theme_type_variation == "PrimaryButton")
	# A new game in slot 2 leaves slot 1 untouched.
	var before := FileAccess.get_file_as_string(base)
	assert(menu.Session.new_game(menu.save_path) == "")
	assert(FileAccess.file_exists(MainMenu.slot_path(base, 2)) and FileAccess.get_file_as_string(base) == before)
	menu.queue_free()
	await process_frame
	# The lobby remembers slot 2 next time.
	menu = _menu(base, settings)
	await process_frame
	assert(menu.slot == 2 and not menu.continue_button.disabled)
	menu.queue_free()
	await process_frame
	# Returning from a slot-3 game opens slot 3 and still knows the base path.
	menu = _menu(MainMenu.slot_path(base, 3), settings)
	await process_frame
	assert(menu.slot == 3 and menu.base_save_path == base)
	menu.select_slot(1)
	assert(menu.save_path == base and not menu.continue_button.disabled)
	menu.queue_free()
	for name in DirAccess.get_files_at(dir): DirAccess.remove_absolute(dir.path_join(name))
	print("PASS: three save slots, separate files, remembered slot and return-to-slot")
	quit()
