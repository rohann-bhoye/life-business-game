extends CharacterBody3D

# A car you can drive. The models are Quaternius' CC0 Realistic Car Pack (converted by
# tools/blender/import_car_pack.py into assets/props/cars/pack/*.glb: Body, Wheel_FL,
# Wheel_FR, Wheels_Back). Arcade driving: throttle and brake, steering that tightens at low
# speed, gentle drag, gravity and a tilt that follows the ground. The front wheels turn, all
# wheels spin, the lamps glow at night, and inside there is a dashboard and a steering
# wheel that turns. car_world.gd puts the player in the seat (first person) and calls drive().
## name, top speed (m/s), acceleration, collision box (width, height, length), wheel radius,
## and the driver's eye in the cabin (right-hand seat), all in the car's own space (front -z).
const MODELS := {
	"normal1": {"name": "City Car", "top": 23.0, "accel": 7.5, "box": Vector3(1.7, 1.0, 4.1), "radius": 0.26, "eye": Vector3(0.4, 0.8, 0.15)},
	"normal2": {"name": "Mini", "top": 21.0, "accel": 7.0, "box": Vector3(1.55, 0.95, 3.2), "radius": 0.26, "eye": Vector3(0.38, 0.78, 0.1)},
	"taxi": {"name": "Taxi", "top": 20.0, "accel": 6.5, "box": Vector3(1.7, 1.12, 4.1), "radius": 0.25, "eye": Vector3(0.4, 0.84, 0.15)},
	"suv": {"name": "SUV", "top": 22.0, "accel": 6.4, "box": Vector3(2.0, 1.25, 4.1), "radius": 0.33, "eye": Vector3(0.45, 0.98, 0.15)},
	"sports": {"name": "Sports Car", "top": 30.0, "accel": 9.5, "box": Vector3(1.7, 0.95, 3.85), "radius": 0.26, "eye": Vector3(0.4, 0.74, 0.15)},
	"sports2": {"name": "Racer", "top": 32.0, "accel": 10.0, "box": Vector3(1.75, 1.0, 3.8), "radius": 0.26, "eye": Vector3(0.4, 0.78, 0.15)},
	"volterra": {"name": "Volterra S7", "own": true, "top": 36.0, "accel": 11.0, "box": Vector3(1.9, 1.15, 4.6), "radius": 0.36, "eye": Vector3(0.45, 1.04, 0.35)},
	"cop": {"name": "Police Car", "top": 27.0, "accel": 8.5, "box": Vector3(1.7, 1.1, 3.6), "radius": 0.275, "eye": Vector3(0.4, 0.86, 0.12)},
}
## The player's eye height above its own origin (player.gd EYE_HEIGHT): the seat position is
## the driver's eye (data.eye) minus this.
const EYE_DROP := 0.7

var kind := "normal1"
var data: Dictionary
## Repaint colour for the body; alpha 0 keeps the model's own paint (taxi yellow, police white).
var paint := Color(0, 0, 0, 0)
## Livery pattern (car_paint.gdshader): -1 picks one at random.
var livery := -1
const LIVERY_COLOURS := [Color(0.95, 0.95, 0.93), Color(0.08, 0.08, 0.09), Color(0.85, 0.12, 0.1), Color(0.95, 0.7, 0.15), Color(0.1, 0.3, 0.75)]
var speed := 0.0
var steer := 0.0
var spinners: Array[Node3D] = []
var front_wheels: Array[Node3D] = []
var lamp_materials: Array[StandardMaterial3D] = []
var occupied := false
var wheel_node: Node3D
var spin_node: Node3D

static func create(type: String, colour := Color(0, 0, 0, 0)) -> CharacterBody3D:
	var car := preload("res://drivable_car.gd").new()
	car.kind = type
	car.data = MODELS[type]
	car.paint = colour
	return car

func _ready() -> void:
	name = "Car" + data.name.replace(" ", "")
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.6
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = data.box
	shape.shape = box
	shape.position.y = data.box.y / 2.0 + 0.12
	add_child(shape)
	var own: bool = data.get("own", false)
	var path := "res://assets/props/cars/%s.glb" % kind if own else "res://assets/props/cars/pack/%s.glb" % kind
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	# The pack models face +z (the car drives towards -z); our own Blender car already faces -z.
	if not own: scene.rotation.y = PI
	add_child(scene)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if str(part.name) == "Body" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for index in range(part.mesh.get_surface_count()):
			var source := part.mesh.surface_get_material(index) as StandardMaterial3D
			if source == null: continue
			var material := source.duplicate() as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			if own:
				# One shared atlas: the part decides (Body paint, Glass, Lamps, Trim).
				match str(part.name).split("_")[0]:
					"Body":
						if paint.a > 0.0: material.albedo_color = paint
						material.metallic = 0.4
						material.roughness = 0.22
						# Only the outside of the shell is drawn, so from the seat you see into the cabin.
						material.cull_mode = BaseMaterial3D.CULL_BACK
					"Glass":
						material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						material.albedo_color = Color(1, 1, 1, 0.5)
						material.roughness = 0.08
					"Lamps":
						material.emission_enabled = true
						material.emission_texture = material.albedo_texture
						material.emission_energy_multiplier = 0.9
						lamp_materials.append(material)
				part.set_surface_override_material(index, material)
				continue
			# The pack's materials arrive with alpha 0 in alpha-scissor mode, which draws
			# nothing (the bodies were invisible): every surface but the windows is solid.
			material.albedo_color.a = 1.0
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			match str(source.resource_name):
				"Paint":
					part.set_surface_override_material(index, _livery(part, material.albedo_color))
					continue
				"Windows":
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					material.albedo_color = Color(0.1, 0.13, 0.17, 0.62)
					material.metallic = 0.6
					material.roughness = 0.05
				"Grey":
					material.metallic = 0.75
					material.roughness = 0.3
				"Black":
					material.roughness = 0.65
				"Headlights", "TailLights", "WhiteLights", "BlueLights":
					material.emission_enabled = true
					material.emission = material.albedo_color
					material.emission_energy_multiplier = 0.5
					lamp_materials.append(material)
			part.set_surface_override_material(index, material)
		if str(part.name).begins_with("Wheel"):
			# The bodies have no wheel openings, so the tyres are widened and pushed out to show
			# beside the body (the rear pair is one mesh with its axle, so it only widens).
			if own: pass
			elif str(part.name) == "Wheels_Back": part.scale.x *= 1.26
			else:
				part.scale.x *= 1.9
				part.position.x += signf(part.position.x) * 0.13
			spinners.append(part)
			if str(part.name).begins_with("Wheel_F"): front_wheels.append(part)
	_build_cabin()

## The body paint (car_paint.gdshader): a colour and a livery over it. Taxis are
## kaali-peeli (black with a yellow roof), police cars white with a blue band; the rest get
## a random livery in a second colour that stands out from the first.
func _livery(part: MeshInstance3D, model_colour: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/car_paint.gdshader")
	var box := part.mesh.get_aabb()
	material.set_shader_parameter("box_pos", box.position)
	material.set_shader_parameter("box_size", box.size)
	var base := paint if paint.a > 0.0 else model_colour
	var second: Color = LIVERY_COLOURS[randi() % LIVERY_COLOURS.size()]
	var pattern := randi() % 4 if livery < 0 else livery
	if kind == "taxi":
		base = Color(0.07, 0.07, 0.08)
		second = Color(0.98, 0.78, 0.1)
		pattern = 2
	elif kind == "cop":
		base = Color(0.95, 0.95, 0.95)
		second = Color(0.1, 0.25, 0.7)
		pattern = 3
	elif Vector3(base.r - second.r, base.g - second.g, base.b - second.b).length() < 0.35:
		second = Color(0.08, 0.08, 0.09) if base.get_luminance() > 0.5 else Color(0.95, 0.95, 0.93)
	material.set_shader_parameter("base", base)
	material.set_shader_parameter("second", second)
	material.set_shader_parameter("pattern", pattern)
	return material

## Inside: a dark floor and dashboard and a black steering wheel (rim and two spokes) that
## turns with the steering.
func _build_cabin() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.11)
	dark.roughness = 0.8
	var floor_plate := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(data.box.x - 0.3, 0.03, data.box.z * 0.55)
	plate.material = dark
	floor_plate.mesh = plate
	floor_plate.position = Vector3(0, data.radius + 0.08, 0.1)
	add_child(floor_plate)
	var dash := MeshInstance3D.new()
	var board := BoxMesh.new()
	board.size = Vector3(data.box.x - 0.3, 0.22, 0.4)
	board.material = dark
	dash.mesh = board
	dash.position = Vector3(0, data.eye.y - 0.5, data.eye.z - 0.95)
	add_child(dash)
	wheel_node = Node3D.new()
	wheel_node.name = "SteeringWheel"
	wheel_node.position = Vector3(data.eye.x, data.eye.y - 0.36, data.eye.z - 0.58)
	wheel_node.rotation.x = deg_to_rad(62)
	spin_node = Node3D.new()
	wheel_node.add_child(spin_node)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.12
	ring.outer_radius = 0.155
	ring.rings = 18
	ring.ring_segments = 8
	ring.material = dark
	rim.mesh = ring
	spin_node.add_child(rim)
	for angle in [0.0, PI / 2.0]:
		var spoke := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.27, 0.012, 0.025)
		bar.material = dark
		spoke.mesh = bar
		spoke.rotation.y = angle
		spin_node.add_child(spoke)
	add_child(wheel_node)

func set_night(night: bool) -> void:
	for material in lamp_materials: material.emission_energy_multiplier = 2.6 if night else 0.5

## One physics step of driving: throttle -1..1 (forward positive), steering -1..1 (right positive).
func drive(throttle: float, steering: float, handbrake: bool, delta: float) -> void:
	var limit: float = data.top
	if throttle > 0.0: speed += throttle * data.accel * delta * (1.0 - clampf(speed / limit, 0.0, 1.0) * 0.7)
	elif throttle < 0.0: speed += throttle * (14.0 if speed > 0.5 else 4.0) * delta
	else: speed = move_toward(speed, 0.0, 3.2 * delta)
	if handbrake: speed = move_toward(speed, 0.0, 18.0 * delta)
	speed = clampf(speed, -limit * 0.3, limit)
	var steer_rate := lerpf(1.7, 0.55, clampf(absf(speed) / limit, 0.0, 1.0))
	steer = move_toward(steer, steering, delta * 5.0)
	if absf(speed) > 0.3: rotation.y -= steer * steer_rate * delta * signf(speed)
	var forward := -global_transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y = velocity.y - 22.0 * delta if not is_on_floor() else -1.0
	move_and_slide()
	if get_slide_collision_count() > 0 and absf(speed) > 1.0:
		for index in range(get_slide_collision_count()):
			if absf(get_slide_collision(index).get_normal().y) < 0.5: speed *= 0.4
	# Tilt with the ground, wheels spin and the front pair turns.
	if is_on_floor():
		var normal := get_floor_normal()
		var tilt := Basis(Vector3.UP, rotation.y)
		var right := tilt.x.slide(normal).normalized()
		var back := right.cross(normal).normalized()
		var target := Basis(right, normal, back).orthonormalized()
		global_transform.basis = global_transform.basis.slerp(target, clampf(delta * 6.0, 0.0, 1.0))
	for wheel in spinners:
		wheel.rotation.x += speed * delta / data.radius * (-1.0 if data.get("own", false) else 1.0)
	for wheel in front_wheels: wheel.rotation.y = -steer * 0.5
	if spin_node != null: spin_node.rotation.y = steer * 2.4

func seat_position() -> Vector3:
	return to_global(data.eye - Vector3(0, EYE_DROP, 0))
