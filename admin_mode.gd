extends RefCounted

# Admin (developer) mode. Testers get the demo with the unfinished parts shut: the Gufa
# Darwaza is sealed and the road ends are closed with barricades (road_block.gd). Admin mode opens
# them. It is on when the game runs from the Godot editor, with the --admin argument, or
# when a file named admin.txt sits beside the .exe (or in the game's user folder).
static func enabled() -> bool:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	# --tester previews the tester build from the editor.
	if "--tester" in args: return false
	if OS.has_feature("editor"): return true
	if "--admin" in args: return true
	return FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join("admin.txt")) or FileAccess.file_exists("user://admin.txt")
