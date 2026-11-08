extends RefCounted

var volume := 0.8
var music_volume := 0.6
var fullscreen := false
var sensitivity := 0.003
var invert_y := false
var fov := 75.0
## -1 Auto (picks a preset for this PC), 0 Low, 1 Normal, 2 High, 3 Custom.
var graphics := -1
# Custom graphics (used when graphics is CUSTOM; the presets below fill them otherwise).
var render_scale := 1.0
var shadows := 1
var grass := 2
var antialias := 0
var effects := true
# Display
var max_fps := 60
var vsync := true
var show_fps := false
# Gameplay: 0 Fast, 1 Normal, 2 Relaxed (DAY_SPEEDS).
var day_length := 2
## The look: false Standard (GL Compatibility, every PC), true Cinematic (Forward+: real
## global light, volumetric fog and light shafts, ambient occlusion, reflections). The
## renderer is chosen when the game starts, from RENDERER_FILE (project.godot
## application/config/project_settings_override), so switching needs a restart.
var cinematic := false
const RENDERER_FILE := "user://renderer.cfg"

const CUSTOM := 3
## Game minutes per real second: the 8 AM to 8 PM shop day lasts 6, 9 or 12 minutes.
const DAY_SPEEDS := [2.0, 4.0 / 3.0, 1.0]
const PRESET_NAMES := ["Low", "Medium", "High"]
## render_scale: 3D resolution (UI stays sharp); shadows: 0 off, 1 short, 2 far;
## grass: 0 off, 1 light, 2 medium, 3 full; antialias: 0 off, 1 MSAA 2x, 2 MSAA 4x;
## effects: walking people, clouds, fog, the pond and real street-lamp lights.
const PRESETS := [
	{"render_scale": 0.75, "shadows": 0, "grass": 1, "antialias": 0, "effects": false},
	{"render_scale": 1.0, "shadows": 1, "grass": 2, "antialias": 0, "effects": true},
	{"render_scale": 1.0, "shadows": 2, "grass": 3, "antialias": 2, "effects": true},
]
const GRAPHICS_FIELDS := ["render_scale", "shadows", "grass", "antialias", "effects"]
const FIELDS := ["volume", "music_volume", "fullscreen", "sensitivity", "invert_y", "fov", "graphics", "render_scale", "shadows", "grass", "antialias", "effects", "max_fps", "vsync", "show_fps", "day_length", "cinematic"]

func load_file(path := "user://settings.cfg") -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	for field in FIELDS:
		var value = config.get_value("game", field, get(field))
		if field in ["fullscreen", "invert_y", "effects", "vsync", "show_fps", "cinematic"]:
			if value is bool: set(field, value)
		elif value is int or value is float:
			if not is_finite(float(value)): continue
			match field:
				"graphics": graphics = clampi(int(value), -1, CUSTOM)
				"volume": volume = clampf(value, 0, 1)
				"music_volume": music_volume = clampf(value, 0, 1)
				"sensitivity": sensitivity = clampf(value, 0.001, 0.01)
				"fov": fov = clampf(value, 50, 90)
				"render_scale": render_scale = clampf(value, 0.5, 1.0)
				"shadows": shadows = clampi(int(value), 0, 2)
				"grass": grass = clampi(int(value), 0, 3)
				"antialias": antialias = clampi(int(value), 0, 2)
				"max_fps": max_fps = clampi(int(value), 0, 240)
				"day_length": day_length = clampi(int(value), 0, 2)

func save_file(path := "user://settings.cfg") -> bool:
	var config := ConfigFile.new()
	for field in FIELDS:
		config.set_value("game", field, get(field))
	return config.save(path) == OK

## Writes the renderer the game starts with next time (and the shadow and texture filter
## quality that suits it). The file overrides project.godot at start-up.
func write_renderer() -> bool:
	var config := ConfigFile.new()
	config.set_value("rendering", "renderer/rendering_method", "forward_plus" if cinematic else "gl_compatibility")
	if cinematic:
		config.set_value("rendering", "lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 3)
		config.set_value("rendering", "lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 3)
		config.set_value("rendering", "textures/default_filters/anisotropic_filtering_level", 3)
		config.set_value("rendering", "environment/ssao/quality", 2)
	return config.save(RENDERER_FILE) == OK

## Graphics cards strong enough for Highest. Laptop MX chips and built-in graphics are not:
## on the owner's MX110 Forward+ crashed the card and froze Windows (2026-11-05).
static func can_run_cinematic() -> bool:
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	for weak in ["mx", "intel", "uhd", "iris", "integrated", "vega", "radeon(tm) graphics", "microsoft basic", "llvmpipe", "swiftshader"]:
		if weak in gpu: return false
	for strong in ["rtx", "gtx 16", "gtx 1070", "gtx 1080", "rx 5", "rx 6", "rx 7", "rx 9", "arc a", "arc b"]:
		if strong in gpu: return true
	return false

## The first starts on Highest are a trial (HIGHEST_TRIAL counts them). Playing 45 seconds
## in the world ends it (finish_highest_trial). A second start while the trial is still
## open means the last one crashed or froze the PC, so the game goes back to High and
## restarts on its own: a card that cannot run Highest never traps the player.
const HIGHEST_TRIAL := "user://highest_trial.cfg"

static func start_highest_trial() -> void:
	var trial := ConfigFile.new()
	trial.set_value("trial", "starts", 0)
	trial.save(HIGHEST_TRIAL)

static func finish_highest_trial() -> void:
	if FileAccess.file_exists(HIGHEST_TRIAL): DirAccess.remove_absolute(ProjectSettings.globalize_path(HIGHEST_TRIAL))

## Called first thing by the main menu; true when it is restarting the game on High.
static func check_highest_trial(tree: SceneTree, settings_path: String) -> bool:
	if not cinematic_running() or not FileAccess.file_exists(HIGHEST_TRIAL): return false
	var trial := ConfigFile.new()
	trial.load(HIGHEST_TRIAL)
	var starts := int(trial.get_value("trial", "starts", 0))
	if starts < 1:
		trial.set_value("trial", "starts", starts + 1)
		trial.save(HIGHEST_TRIAL)
		return false
	var settings = load("res://game_settings.gd").new()
	settings.load_file(settings_path)
	settings.cinematic = false
	settings.save_file(settings_path)
	settings.write_renderer()
	finish_highest_trial()
	OS.set_restart_on_exit(true)
	tree.quit()
	return true

## True when this run uses the Cinematic renderer (Forward+); false on Standard (GL
## Compatibility), or when the graphics card could not start Forward+ and Godot fell back.
static func cinematic_running() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"

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
	Engine.max_fps = max_fps
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		_apply_viewport(tree.root)
		_fps_counter(tree)

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

## The preset tier (0 Low, 1 Normal, 2 High) for parts of the world that follow it.
## A Custom mix counts as Low without effects, otherwise Normal, or High with far shadows.
func effective_quality() -> int:
	if graphics == CUSTOM: return 0 if not effects else (2 if shadows == 2 else 1)
	return detected_quality() if graphics == -1 else graphics

## The graphics actually used: the chosen preset, the detected one on Auto, or the
## player's own mix on Custom.
func options() -> Dictionary:
	if graphics != CUSTOM: return PRESETS[effective_quality()]
	var custom := {}
	for field in GRAPHICS_FIELDS: custom[field] = get(field)
	return custom

func apply_graphics(world: Node) -> void:
	if not is_instance_valid(world): return
	var quality := effective_quality()
	var chosen := options()
	_apply_viewport(world.get_viewport())
	var sun := world.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = chosen.shadows > 0
		sun.directional_shadow_max_distance = 28.0 if chosen.shadows == 1 else 60.0
		# Each shadow split draws the scene again: short shadows use one pass, far ones
		# two (four splits halved the frame rate on a low-end GPU).
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if chosen.shadows == 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		# Highest (Cinematic, Forward+): far, sharp, soft-edged shadows in four splits.
		if cinematic_running() and chosen.shadows > 0:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = 140.0
			sun.light_angular_distance = 0.6
	var details = world.get_node_or_null("Neighbourhood/EnvironmentDetails")
	if is_instance_valid(details):
		details.set_quality(quality)
		details.set_grass(chosen.grass)
	var neighbourhood = world.get_node_or_null("Neighbourhood")
	if is_instance_valid(neighbourhood) and neighbourhood.has_method("set_quality"): neighbourhood.set_quality(quality)
	var day_night = world.get_node_or_null("DayNight")
	if is_instance_valid(day_night) and day_night.has_method("set_quality"): day_night.set_quality(quality)
	var sagar = world.get_node_or_null("Neighbourhood/SagarPoint")
	if sagar == null: sagar = world.find_child("SagarPoint", true, false)
	if is_instance_valid(sagar) and sagar.has_method("set_quality"): sagar.set_quality(quality)
	apply_gameplay(world)

## How fast the in-game clock runs (Settings > Gameplay > Day length).
func apply_gameplay(world: Node) -> void:
	var clock = world.get_node_or_null("DayClock")
	if clock != null and "minutes_per_second" in clock: clock.minutes_per_second = DAY_SPEEDS[day_length]

## 3D resolution (bilinear upscale, the UI stays at full resolution) and smooth edges.
func _apply_viewport(viewport: Viewport) -> void:
	if viewport == null: return
	var chosen := options()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = chosen.render_scale
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][chosen.antialias]

## A small FPS readout in the top-right corner, kept across scenes under the root.
func _fps_counter(tree: SceneTree) -> void:
	var counter := tree.root.get_node_or_null("FpsCounter")
	if counter == null and show_fps:
		counter = preload("res://fps_counter.gd").new()
		counter.name = "FpsCounter"
		tree.root.add_child.call_deferred(counter)
	elif counter != null:
		counter.visible = show_fps
