extends Node

var last_minute := -1
var streetlights_on := false
var street_lights: Array[SpotLight3D] = []
var lamp_materials: Array[StandardMaterial3D] = []
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
		if lamp.has_node("Light") and lamp.has_node("Lens"):
			street_lights.append(lamp.get_node("Light"))
			lamp_materials.append(lamp.get_node("Lens").material_override)
	business.clock_changed.connect(_on_clock_changed)
	business.changed.connect(_refresh)
	_refresh()

func _on_clock_changed() -> void:
	if floori(business.minutes_of_day) != last_minute:
		_refresh()

func set_quality(quality: int) -> void:
	low_quality = quality == 0
	_refresh()

func _refresh() -> void:
	last_minute = floori(business.minutes_of_day)
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
	environment.background_energy_multiplier = lerpf(0.18, 0.9, daylight)
	environment.fog_enabled = not low_quality
	environment.fog_light_color = Color(0.18, 0.23, 0.31).lerp(Color(0.52, 0.69, 0.85), daylight)
	environment.fog_light_energy = lerpf(0.35, 0.7, daylight)
	environment.fog_density = lerpf(0.003, 0.0006, daylight)
	sky_material.sky_top_color = Color(0.025, 0.045, 0.085).lerp(Color(0.3, 0.52, 0.75), daylight)
	var horizon := Color(0.08, 0.12, 0.18).lerp(Color(0.77, 0.86, 0.9), daylight)
	horizon = horizon.lerp(Color(0.88, 0.43, 0.26), twilight * 0.65)
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	sky_material.ground_bottom_color = Color(0.045, 0.065, 0.075).lerp(Color(0.2, 0.28, 0.24), daylight)
	sky_material.sun_angle_max = lerpf(2.0, 1.0, daylight)
	sky_material.sun_curve = 0.08
	streetlights_on = not low_quality and (business.minutes_of_day < 390.0 or business.minutes_of_day >= 1110.0)
	for light in street_lights:
		light.visible = streetlights_on
	for material in lamp_materials:
		material.emission_enabled = streetlights_on
		material.emission_energy_multiplier = 1.8 if streetlights_on else 0.0
	interior_light.visible = streetlights_on and business.house_owned
