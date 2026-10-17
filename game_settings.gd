extends RefCounted

var volume := 0.8
var music_volume := 0.6
var fullscreen := false
var sensitivity := 0.003
var invert_y := false
var fov := 75.0
var graphics := -1

func load_file(path := "user://settings.cfg") -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	for field in ["volume", "music_volume", "fullscreen", "sensitivity", "invert_y", "fov", "graphics"]:
		var value = config.get_value("game", field, get(field))
		if field in ["fullscreen", "invert_y"]:
			if value is bool: set(field, value)
		elif value is int or value is float:
			if not is_finite(float(value)): continue
			match field:
				"graphics": graphics = clampi(int(value), -1, 2)
				"volume": volume = clampf(value, 0, 1)
				"music_volume": music_volume = clampf(value, 0, 1)
				"sensitivity": sensitivity = clampf(value, 0.001, 0.01)
				"fov": fov = clampf(value, 50, 90)

func save_file(path := "user://settings.cfg") -> bool:
	var config := ConfigFile.new()
	for field in ["volume", "music_volume", "fullscreen", "sensitivity", "invert_y", "fov", "graphics"]:
		config.set_value("game", field, get(field))
	return config.save(path) == OK

## The "Music" audio bus (created on first use) carries background music only.
static func music_bus() -> int:
	var index := AudioServer.get_bus_index("Music")
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, "Music")
		AudioServer.set_bus_send(index, "Master")
	return index

func apply_global() -> void:
	AudioServer.set_bus_mute(0, volume <= 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, volume)))
	var music := music_bus()
	AudioServer.set_bus_mute(music, music_volume <= 0)
	AudioServer.set_bus_volume_db(music, linear_to_db(maxf(0.001, music_volume)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func apply_player(player) -> void:
	player.mouse_sensitivity = sensitivity
	player.invert_y = invert_y
	player.camera.fov = fov
	var tablet = player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D/ShopTablet")
	if is_instance_valid(tablet): tablet._resize()
	player.call_deferred("_apply_graphics_settings")

func detected_quality() -> int:
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	if OS.get_processor_count() <= 4: return 0
	for name in ["mx", "intel", "integrated", "vega", "uhd", "iris"]:
		if name in gpu: return 0
	for name in ["rtx", "rx 6", "rx 7", "rx 9"]:
		if name in gpu: return 2
	if "gtx" in gpu: return 1
	return 0

func effective_quality() -> int:
	return detected_quality() if graphics == -1 else graphics

func apply_graphics(world: Node) -> void:
	if not is_instance_valid(world): return
	var quality := effective_quality()
	var sun := world.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = quality > 0
		sun.directional_shadow_max_distance = 28.0 if quality == 1 else 60.0
	var details = world.get_node_or_null("Neighbourhood/EnvironmentDetails")
	if is_instance_valid(details): details.set_quality(quality)
	var neighbourhood = world.get_node_or_null("Neighbourhood")
	if is_instance_valid(neighbourhood) and neighbourhood.has_method("set_quality"): neighbourhood.set_quality(quality)
	var day_night = world.get_node_or_null("DayNight")
	if is_instance_valid(day_night) and day_night.has_method("set_quality"): day_night.set_quality(quality)
