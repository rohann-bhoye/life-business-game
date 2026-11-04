extends Node

var last_minute := -1
var streetlights_on := false
var street_lights: Array[SpotLight3D] = []
var lamp_materials: Array[StandardMaterial3D] = []
var light_pools: Array[MeshInstance3D] = []
var fallback_pools: Array[MeshInstance3D] = []
var moon: DirectionalLight3D
var interior_light: OmniLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
var low_quality := false

@onready var business = get_tree().current_scene.get_node("Shop/ShopArea").business
@onready var sun: DirectionalLight3D = get_tree().current_scene.get_node("DirectionalLight3D")

func _ready() -> void:
	var world: WorldEnvironment = get_tree().current_scene.get_node("WorldEnvironment")
	# Lighting resources must not leak into other instances of the packed scene.
	environment = world.environment.duplicate(true)
	world.environment = environment
	sky_material = environment.sky.sky_material
	moon = DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-45, 135, 0)
	moon.light_color = Color(0.57, 0.7, 0.94)
	moon.shadow_enabled = false
	add_child(moon)
	interior_light = OmniLight3D.new()
	interior_light.name = "InteriorLight"
	interior_light.position = Vector3(0, 2.25, 0)
	interior_light.omni_range = 4.0
	interior_light.light_color = Color(1.0, 0.86, 0.65)
	interior_light.light_energy = 0.65
	interior_light.shadow_enabled = false
	get_tree().current_scene.get_node("House").add_child(interior_light)
	for lamp in get_tree().current_scene.get_node("Neighbourhood").get_children():
		if not lamp.has_node("Lens"): continue
		lamp_materials.append(lamp.get_node("Lens").material_override)
		if lamp.has_node("Light"): street_lights.append(lamp.get_node("Light"))
		# Town expansion lamps have no real light, only a glowing pool on the ground;
		# town lamps light their pool instead of the spot light on Low Fast.
		if lamp.has_node("Pool"): (fallback_pools if lamp.has_node("Light") else light_pools).append(lamp.get_node("Pool"))
	_build_stars()
	business.clock_changed.connect(_on_clock_changed)
	business.changed.connect(_refresh)
	_refresh()

var stars: MultiMeshInstance3D
var star_material: StandardMaterial3D

## Night stars: small billboards on a dome far beyond the town (one draw call).
func _build_stars() -> void:
	star_material = StandardMaterial3D.new()
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star_material.disable_fog = true
	var quad := QuadMesh.new()
	quad.material = star_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = 360
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for index in range(multimesh.instance_count):
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.12, 1), rng.randf_range(-1, 1)).normalized()
		var size := rng.randf_range(0.7, 1.9)
		multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * size), direction * 300.0))
	stars = MultiMeshInstance3D.new()
	stars.name = "Stars"
	stars.multimesh = multimesh
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)

## Inside the dungeon (dungeon_world.gd) the floor's cave light replaces the sky, the
## sun, the moon and the stars: background, ambient and fog colours from `profile`
## (empty again back in the town).
var underground := {}

func set_underground(profile: Dictionary) -> void:
	underground = profile
	_refresh()

func _on_clock_changed() -> void:
	if floori(business.minutes_of_day) != last_minute:
		_refresh()

func set_quality(quality: int) -> void:
	low_quality = quality == 0
	_refresh()


## Cinematic grade: filmic tone curve, a touch more contrast and colour, and a soft glow
## around bright lights and signs. Low (Fast) skips the extra passes for low-end GPUs.
func _grade() -> void:
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 5.0
	environment.tonemap_exposure = 1.12
	environment.glow_enabled = not low_quality
	environment.glow_intensity = 0.55
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.95
	environment.adjustment_enabled = not low_quality
	environment.adjustment_contrast = 1.07
	environment.adjustment_saturation = 1.12

func _refresh() -> void:
	_grade()
	last_minute = floori(business.minutes_of_day)
	sun.visible = underground.is_empty()
	moon.visible = underground.is_empty()
	if not underground.is_empty():
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = underground.background
		environment.ambient_light_color = underground.ambient
		environment.ambient_light_energy = underground.ambient_energy
		environment.fog_enabled = true
		environment.fog_light_color = underground.background
		environment.fog_light_energy = 1.0
		environment.fog_density = underground.fog_density
		stars.visible = false
		return
	environment.background_mode = Environment.BG_SKY
	var hour: float = business.minutes_of_day / 60.0
	var angle := (hour - 6.0) / 24.0 * TAU
	var elevation := sin(angle)
	var daylight := smoothstep(-0.15, 0.35, elevation)
	var twilight := 1.0 - smoothstep(0.0, 0.3, absf(elevation))
	sun.rotation = Vector3(-angle, deg_to_rad(-45), 0)
	sun.light_energy = 0.9 * smoothstep(0.0, 0.5, elevation)
	sun.light_color = Color(1, 0.64, 0.4).lerp(Color(1, 0.95, 0.87), smoothstep(0.0, 0.6, elevation))
	moon.light_energy = 0.16 * (1.0 - daylight)
	environment.ambient_light_energy = lerpf(0.14, 0.4, daylight)
	environment.ambient_light_color = Color(0.5, 0.64, 0.82).lerp(Color(0.84, 0.9, 1), daylight)
	environment.background_energy_multiplier = lerpf(0.4, 0.9, daylight)
	environment.fog_enabled = not low_quality
	environment.fog_light_color = Color(0.18, 0.23, 0.31).lerp(Color(0.52, 0.69, 0.85), daylight)
	environment.fog_light_energy = lerpf(0.35, 0.7, daylight)
	environment.fog_density = lerpf(0.003, 0.0016, daylight)
	sky_material.sky_top_color = Color(0.03, 0.06, 0.16).lerp(Color(0.3, 0.52, 0.75), daylight)
	var horizon := Color(0.1, 0.15, 0.27).lerp(Color(0.77, 0.86, 0.9), daylight)
	horizon = horizon.lerp(Color(0.88, 0.43, 0.26), twilight * 0.65)
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	# Below the horizon the sky is the same haze, so any gap past the land reads as
	# distance, never as a green wall.
	sky_material.ground_bottom_color = horizon
	sky_material.sun_angle_max = lerpf(2.0, 1.0, daylight)
	sky_material.sun_curve = 0.08
	if business.is_raining():
		# Overcast rainy day: weaker sun, greyer sky, thicker haze.
		sun.light_energy *= 0.45
		environment.ambient_light_energy *= 0.85
		environment.background_energy_multiplier *= 0.65
		var grey := Color(0.45, 0.5, 0.55) * maxf(0.2, daylight)
		sky_material.sky_top_color = sky_material.sky_top_color.lerp(grey, 0.7)
		sky_material.sky_horizon_color = horizon.lerp(grey, 0.6)
		environment.fog_density *= 2.5
	# Lamps glow at night on every setting; Low Fast swaps the real spot lights for
	# the cheap glowing pools on the ground.
	streetlights_on = business.minutes_of_day < 390.0 or business.minutes_of_day >= 1110.0
	for pool in light_pools:
		pool.visible = streetlights_on
	for pool in fallback_pools:
		pool.visible = streetlights_on and low_quality
	for light in street_lights:
		light.visible = streetlights_on and not low_quality
	for material in lamp_materials:
		material.emission_enabled = streetlights_on
		material.emission_energy_multiplier = 3.0 if streetlights_on else 0.0
	interior_light.visible = streetlights_on and business.house_owned
	star_material.albedo_color = Color(1, 1, 1, (1.0 - daylight) * (0.25 if business.is_raining() else 0.9))
	stars.visible = daylight < 0.9
