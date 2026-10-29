extends CharacterBody3D

# A car you can drive (Blender model from tools/blender/build_cars.py). Arcade driving:
# throttle and brake, steering that tightens at low speed, gentle drag, gravity and
# a tilt that follows the ground. The front wheels turn, all four spin, and the lamps glow
# at night. car_world.gd puts the player in the seat (first person) and calls drive().
const MODELS := {
	"hatchback": {"name": "Hatchback", "top": 21.0, "accel": 7.5, "box": Vector3(1.8, 1.3, 3.7), "radius": 0.3, "eye": Vector3(0.37, 1.17, 0.32)},
	"sedan": {"name": "Sedan", "top": 24.0, "accel": 7.0, "box": Vector3(1.9, 1.3, 4.3), "radius": 0.32, "eye": Vector3(0.37, 1.17, 0.3)},
	"suv": {"name": "SUV", "top": 22.0, "accel": 6.2, "box": Vector3(2.0, 1.6, 4.5), "radius": 0.38, "eye": Vector3(0.4, 1.42, 0.3)},
	"pickup": {"name": "Pickup", "top": 20.0, "accel": 5.8, "box": Vector3(2.0, 1.6, 5.0), "radius": 0.4, "eye": Vector3(0.4, 1.45, 0.3)},
}
const ATLAS := "res://assets/props/cars/cars_print.png"
## The player's eye height above its own origin (player.gd EYE_HEIGHT): the seat position is
## the driver's eye (data.eye, right-hand seat, inside the cabin) minus this.
const EYE_DROP := 0.7

var kind := "hatchback"
var data: Dictionary
var paint := Color.WHITE
var speed := 0.0
var steer := 0.0
var wheels: Array[Node3D] = []
var front_wheels: Array[Node3D] = []
var lamps: MeshInstance3D
var lamp_material: StandardMaterial3D
var occupied := false
var wheel_node: Node3D
var spin_node: Node3D

static func create(type: String, colour: Color) -> CharacterBody3D:
	var car := preload("res://drivable_car.gd").new()
	car.kind = type
	car.data = MODELS[type]
	car.paint = colour
	return car

func _ready() -> void:
	name = "Car" + data.name
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.6
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = data.box
	shape.shape = box
	shape.position.y = data.box.y / 2.0
	add_child(shape)
	var scene := (load("res://assets/props/cars/%s.glb" % kind) as PackedScene).instantiate() as Node3D
	add_child(scene)
	var atlas: Texture2D = load(ATLAS)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_texture = atlas
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.55
		var part_name := str(part.name).split("_")[0]
		match part_name:
			"Body":
				material.albedo_color = paint
				material.metallic = 0.25
				material.roughness = 0.35
			"Glass":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color = Color(1, 1, 1, 0.42)
				material.roughness = 0.1
			"Lamps":
				material.emission_enabled = true
				material.emission_texture = atlas
				material.emission_energy_multiplier = 0.4
				lamp_material = material
				lamps = part
		part.material_override = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if part_name != "Body" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if str(part.name).begins_with("Wheel"):
			wheels.append(part)
			if str(part.name).begins_with("Wheel_F"): front_wheels.append(part)
	_build_wheel()

## A black steering wheel (rim, hub and two spokes) that turns with the steering.
func _build_wheel() -> void:
	wheel_node = Node3D.new()
	wheel_node.name = "SteeringWheel"
	wheel_node.position = Vector3(data.eye.x, data.eye.y - 0.2, data.eye.z - 0.62)
	wheel_node.rotation.x = deg_to_rad(62)
	spin_node = Node3D.new()
	wheel_node.add_child(spin_node)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.07, 0.07, 0.08)
	black.roughness = 0.6
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.15
	ring.outer_radius = 0.19
	ring.rings = 18
	ring.ring_segments = 8
	ring.material = black
	rim.mesh = ring
	spin_node.add_child(rim)
	for angle in [0.0, PI / 2.0]:
		var spoke := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.33, 0.012, 0.03)
		bar.material = black
		spoke.mesh = bar
		spoke.rotation.y = angle
		spin_node.add_child(spoke)
	add_child(wheel_node)

func set_night(night: bool) -> void:
	if lamp_material != null: lamp_material.emission_energy_multiplier = 2.4 if night else 0.4

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
	for wheel in wheels:
		wheel.rotation.x -= speed * delta / data.radius
	for wheel in front_wheels: wheel.rotation.y = -steer * 0.5
	if spin_node != null: spin_node.rotation.y = steer * 2.4

func seat_position() -> Vector3:
	return to_global(data.eye - Vector3(0, EYE_DROP, 0))
