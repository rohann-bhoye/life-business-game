extends Node3D

@export var shirt_color := Color(0.18, 0.48, 0.78)
@export var skin_color := Color(0.72, 0.48, 0.32)
@export var hair_color := Color(0.1, 0.085, 0.07)
@export var feet_offset := 0.0
@export var face_movement := false
## Kenney Mini character id ("male-a".."female-f"); empty picks a random customer look.
@export var model := ""

const MODEL_DIR := "res://assets/characters/kenney/character-%s.glb"
const RANDOM_MODELS := ["female-a", "female-b", "female-c", "female-d", "female-e", "female-f", "male-c", "male-f"]
const MODEL_SCALE := 2.15
const LOOPED := ["idle", "walk", "holding-both"]
static var model_scenes: Dictionary = {}

var kenney: Node3D
var anim_tree: AnimationTree
var model_id := ""

var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var body: MeshInstance3D
var head: MeshInstance3D
var previous_position := Vector3.ZERO
var walk_blend := 0.0
var phase := 0.0
var idle_phase := 0.0
var work_remaining := 0.0
var carry_target: Node3D
var carry_was_active := false

func pose_carry(left: Vector3, right: Vector3) -> void:
	rotation.y = 0.0
	for entry in [[left_arm, left, -1], [right_arm, right, 1]]:
		var arm: Node3D = entry[0]
		arm.basis = Basis.IDENTITY
		var shoulder := arm.position
		var wrist: Vector3 = to_local(entry[1])
		var direction := (wrist - shoulder).normalized()
		var distance := clampf(shoulder.distance_to(wrist), 0.04, 0.679)
		var upper := 0.32
		var lower := 0.36
		var along := (upper * upper - lower * lower + distance * distance) / (2 * distance)
		var bend := Vector3(entry[2], -0.25, 0.4)
		bend = (bend - direction * bend.dot(direction)).normalized()
		var elbow := shoulder + direction * along + bend * sqrt(maxf(0, upper * upper - along * along))
		var hand := shoulder + direction * distance
		_segment(arm.get_node("Sleeve"), (shoulder + elbow) / 2 - shoulder, elbow - shoulder, 0.28)
		_segment(arm.get_node("Forearm"), (elbow + hand) / 2 - shoulder, hand - elbow, 0.27)
		var palm: Node3D = arm.get_node("Hand")
		palm.position = hand - shoulder
		palm.basis = Basis(Quaternion(Vector3.DOWN, (hand - elbow).normalized()))
	carry_was_active = true

func _segment(node: Node3D, center: Vector3, direction: Vector3, original_length: float) -> void:
	node.position = center
	node.basis = Basis(Quaternion(Vector3.DOWN, direction.normalized())).scaled(Vector3(1, direction.length() / original_length, 1))

func reset_carry_pose() -> void:
	if not carry_was_active: return
	for arm in [left_arm, right_arm]:
		arm.scale = Vector3.ONE
		arm.rotation.y = 0
		arm.rotation.z = 0
		for entry in [["Sleeve", -0.12], ["Forearm", -0.37], ["Hand", -0.57]]:
			var node: Node3D = arm.get_node(entry[0])
			node.position = Vector3(0, entry[1], 0)
			node.basis = Basis.IDENTITY
		arm.get_node("Hand").show()
	carry_was_active = false

func _ready() -> void:
	if is_class("MeshInstance3D"):
		set("mesh", null)
	var shirt := _material(shirt_color)
	var skin := _material(skin_color)
	var trousers := _material(Color(0.17, 0.19, 0.22))
	var shoes := _material(Color(0.055, 0.065, 0.07))
	body = get_parent().get_node_or_null("Body") as MeshInstance3D
	head = get_parent().get_node_or_null("Head") as MeshInstance3D
	if body == null:
		body = MeshInstance3D.new()
		body.name = "Body"
		add_child(body)
	if head == null:
		head = MeshInstance3D.new()
		head.name = "Head"
		add_child(head)
	body.mesh = _box_mesh(Vector3(0.48, 0.66, 0.3), shirt)
	body.position = Vector3(0, feet_offset + 1.11, 0)
	var face := CylinderMesh.new()
	face.top_radius = 0.19
	face.bottom_radius = 0.17
	face.height = 0.38
	face.radial_segments = 8
	face.rings = 1
	face.material = skin
	head.mesh = face
	head.position = Vector3(0, feet_offset + 1.7, 0)
	_box("Neck", self, Vector3(0.16, 0.16, 0.16), Vector3(0, feet_offset + 1.48, 0), skin)
	_box("Waist", self, Vector3(0.44, 0.16, 0.28), Vector3(0, feet_offset + 0.81, 0), trousers)
	var hair := CylinderMesh.new()
	hair.top_radius = 0.2
	hair.bottom_radius = 0.205
	hair.height = 0.16
	hair.radial_segments = 8
	hair.rings = 1
	hair.material = _material(hair_color)
	var hair_node := MeshInstance3D.new()
	hair_node.name = "Hair"
	hair_node.mesh = hair
	hair_node.position.y = 0.15
	head.add_child(hair_node)
	var white := _material(Color(0.95, 0.95, 0.92))
	var dark := _material(Color(0.06, 0.07, 0.075))
	for side in [-1, 1]:
		_box("Eye%d" % side, head, Vector3(0.065, 0.045, 0.035), Vector3(side * 0.075, 0.02, -0.17), white)
		_box("Pupil%d" % side, head, Vector3(0.026, 0.03, 0.015), Vector3(side * 0.075, 0.02, -0.195), dark)
	_box("Nose", head, Vector3(0.05, 0.065, 0.075), Vector3(0, -0.045, -0.19), skin)
	_box("Mouth", head, Vector3(0.075, 0.015, 0.018), Vector3(0, -0.105, -0.17), dark)
	left_arm = _arm("LeftArm", -1, shirt, skin)
	right_arm = _arm("RightArm", 1, shirt, skin)
	left_leg = _leg("LeftLeg", -1, trousers, shoes)
	right_leg = _leg("RightLeg", 1, trousers, shoes)
	previous_position = global_position
	_attach_model()

# The block-built rig above stays (hidden) so carry grips, hands and tests keep
# working; the visible body is an animated Kenney Mini character.
func _attach_model() -> void:
	model_id = model if not model.is_empty() else RANDOM_MODELS.pick_random()
	var path := MODEL_DIR % model_id
	if not model_scenes.has(model_id):
		model_scenes[model_id] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if model_scenes[model_id] == null: return
	kenney = model_scenes[model_id].instantiate()
	kenney.name = "KenneyModel"
	kenney.scale = Vector3.ONE * MODEL_SCALE
	kenney.position.y = feet_offset
	kenney.rotation.y = PI
	add_child(kenney)
	for part in [body, head, left_arm, right_arm, left_leg, right_leg, get_node("Neck"), get_node("Waist")]:
		part.visible = false
	var players := kenney.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty(): return
	var player: AnimationPlayer = players[0]
	for loop_name in LOOPED:
		if player.has_animation(loop_name): player.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
	var tree := AnimationNodeBlendTree.new()
	for entry in [["idle", "idle"], ["walk", "walk"], ["carry", "holding-both"], ["work", "interact-right"]]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = entry[1]
		tree.add_node(entry[0], clip)
	tree.add_node("move", AnimationNodeBlend2.new())
	var carry_blend := AnimationNodeBlend2.new()
	carry_blend.filter_enabled = true
	var holding := player.get_animation("holding-both")
	for track in range(holding.get_track_count()):
		var track_path := holding.track_get_path(track)
		if str(track_path).contains("arm"): carry_blend.set_filter_path(track_path, true)
	tree.add_node("carry_blend", carry_blend)
	var work_shot := AnimationNodeOneShot.new()
	work_shot.fadein_time = 0.1
	work_shot.fadeout_time = 0.15
	tree.add_node("work_shot", work_shot)
	tree.add_node("speed", AnimationNodeTimeScale.new())
	tree.connect_node("move", 0, "idle")
	tree.connect_node("move", 1, "walk")
	tree.connect_node("speed", 0, "move")
	tree.connect_node("carry_blend", 0, "speed")
	tree.connect_node("carry_blend", 1, "carry")
	tree.connect_node("work_shot", 0, "carry_blend")
	tree.connect_node("work_shot", 1, "work")
	tree.connect_node("output", 0, "work_shot")
	anim_tree = AnimationTree.new()
	anim_tree.name = "KenneyAnimation"
	anim_tree.tree_root = tree
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	kenney.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(player)
	anim_tree.active = true

func _update_model(delta: float, speed: float, carrying: bool) -> void:
	if not is_instance_valid(anim_tree): return
	anim_tree.set("parameters/move/blend_amount", walk_blend)
	anim_tree.set("parameters/speed/scale", clampf(speed / 1.5, 0.7, 1.8) if walk_blend > 0.1 else 1.0)
	anim_tree.set("parameters/carry_blend/blend_amount", 1.0 if carrying else 0.0)
	anim_tree.advance(delta)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh

func _box(node_name: String, parent: Node3D, size: Vector3, offset: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	part.mesh = _box_mesh(size, material)
	part.position = offset
	parent.add_child(part)

func _arm(node_name: String, side: int, shirt: Material, skin: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = Vector3(side * 0.32, feet_offset + 1.39, 0)
	add_child(pivot)
	_box("Sleeve", pivot, Vector3(0.18, 0.28, 0.24), Vector3(0, -0.12, 0), shirt)
	_box("Forearm", pivot, Vector3(0.14, 0.27, 0.18), Vector3(0, -0.37, 0), skin)
	_box("Hand", pivot, Vector3(0.16, 0.15, 0.2), Vector3(0, -0.57, 0), skin)
	return pivot

func _leg(node_name: String, side: int, trousers: Material, shoes: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = Vector3(side * 0.13, feet_offset + 0.79, 0)
	add_child(pivot)
	_box("Leg", pivot, Vector3(0.19, 0.34, 0.23), Vector3(0, -0.17, 0), trousers)
	_box("Calf", pivot, Vector3(0.17, 0.32, 0.22), Vector3(0, -0.50, 0), trousers)
	_box("Shoe", pivot, Vector3(0.22, 0.16, 0.34), Vector3(0, -0.71, -0.055), shoes)
	return pivot

func _bend_knee(leg: Node3D, angle: float) -> void:
	var bend := Basis(Vector3.RIGHT, angle)
	var knee := Vector3(0, -0.34, 0)
	var calf: Node3D = leg.get_node("Calf")
	calf.position = knee + bend * Vector3(0, -0.16, 0)
	calf.rotation.x = angle
	var shoe: Node3D = leg.get_node("Shoe")
	shoe.position = knee + bend * Vector3(0, -0.37, -0.055)
	shoe.rotation.x = angle * 0.25

func play_work_animation() -> void:
	work_remaining = 1.0
	if is_instance_valid(anim_tree):
		anim_tree.set("parameters/work_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

var animation_elapsed := 0.0

func _process(delta: float) -> void:
	animation_elapsed += delta
	var view := get_viewport().get_camera_3d()
	if is_instance_valid(view) and global_position.distance_squared_to(view.global_position) > 625.0 and animation_elapsed < 0.12:
		return
	delta = animation_elapsed
	animation_elapsed = 0.0
	var carrying := is_instance_valid(carry_target) and carry_target.visible
	if not carrying: reset_carry_pose()
	var displacement := global_position - previous_position
	previous_position = global_position
	displacement.y = 0.0
	var speed := displacement.length() / maxf(delta, 0.001)
	# Ignore teleports so scene placement does not trigger a walking pose.
	# Speed-based so walking still animates during frame drops; only real teleports (>12 m/s) are ignored.
	var walking := speed > 0.08 and speed < 12.0
	walk_blend = move_toward(walk_blend, 1.0 if walking else 0.0, delta * 8.0)
	phase += delta * clampf(speed * 3.0, 5.0, 13.0)
	idle_phase += delta * 2.0
	var swing := sin(phase) * (0.42 if carrying else 0.55) * walk_blend
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	_bend_knee(left_leg, -maxf(0, cos(phase)) * 0.55 * walk_blend)
	_bend_knee(right_leg, -maxf(0, -cos(phase)) * 0.55 * walk_blend)
	left_arm.rotation.x = -swing * 0.8
	right_arm.rotation.x = swing * 0.8
	work_remaining = maxf(0.0, work_remaining - delta)
	if work_remaining > 0.0:
		var lift := sin(work_remaining * PI) * 1.1
		left_arm.rotation.x += lift
		right_arm.rotation.x += lift
	var bob := sin(idle_phase) * 0.008 * (1.0 - walk_blend) + absf(sin(phase)) * 0.025 * walk_blend
	body.position.y = feet_offset + 1.11 + bob
	head.position.y = feet_offset + 1.7 + bob
	if face_movement and walking and not carrying:
		var direction: Vector3 = get_parent().global_basis.inverse() * displacement
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(delta * 12.0, 1.0))
	if carrying:
		pose_carry(carry_target.to_global(Vector3(-0.45, -0.08, 0.18)), carry_target.to_global(Vector3(0.45, -0.08, 0.18)))
	_update_model(delta, speed, carrying)
