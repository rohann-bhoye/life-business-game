extends Node3D

var player: CharacterBody3D
var visual: Node3D
var forearms: Array[Node3D] = []
var previous_position := Vector3.ZERO
var walk_blend := 0.0
var phase := 0.0
var place_animation_remaining := 0.0
var hide_after_place := false
const PLACE_DURATION := 0.32

func initialize(actor: CharacterBody3D) -> void:
	player = actor
	visual = player.get_node("MeshInstance3D")
	visual.carry_target = self
	previous_position = player.global_position
	for side in [-1, 1]:
		var prefix := "Left" if side == -1 else "Right"
		_part(prefix + "Grip", Vector3(0.13, 0.18, 0.23), Vector3(side * 0.45, -0.08, 0.18), visual.skin_color)
		_part(prefix + "Thumb", Vector3(0.08, 0.07, 0.13), Vector3(side * 0.39, 0.025, 0.18), visual.skin_color)
		forearms.append(_part(prefix + "CarryForearm", Vector3(0.14, 0.16, 0.48), Vector3(side * 0.46, -0.11, 0.52), visual.skin_color))
	set_process(true)
	process_priority = 10

func play_place_animation(final_item := false) -> void:
	place_animation_remaining = PLACE_DURATION
	hide_after_place = final_item
	if final_item: show()

func _part(node_name: String, size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material = material
	part.mesh = mesh
	part.position = offset
	add_child(part)
	return part

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	var distance := Vector2(player.global_position.x - previous_position.x, player.global_position.z - previous_position.z).length()
	previous_position = player.global_position
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.08 or (distance > 0.001 and distance < 0.5)
	var walking: bool = visible and not player._menu_is_open() and moving
	walk_blend = move_toward(walk_blend, 1.0 if walking else 0.0, delta * 6.0)
	phase += delta * 8.0
	var first_person: bool = player.indoors or player.shop_indoors or player.warehouse_indoors
	var bob := Vector3(sin(phase) * 0.012, absf(sin(phase)) * 0.018, 0) * walk_blend
	place_animation_remaining = maxf(0.0, place_animation_remaining - delta)
	var place_arc := sin((1.0 - place_animation_remaining / PLACE_DURATION) * PI) if place_animation_remaining > 0.0 else 0.0
	var place_offset := Vector3(0.055, -0.025, -0.035) * place_arc
	# Follow the view indoors without changing the player's camera or movement.
	if first_person:
		global_transform = player.camera.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.7), Vector3(0, -0.35, -1.15) + bob + place_offset)
	else:
		transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.85), Vector3(0, -0.3, -0.5) + bob + place_offset)
	rotate_object_local(Vector3.FORWARD, sin(phase) * 0.015 * walk_blend)
	get_node("RightGrip").position = Vector3(0.45, -0.08, 0.18) + Vector3(0.22, 0.14, -0.08) * place_arc
	get_node("RightThumb").position = Vector3(0.39, 0.025, 0.18) + Vector3(0.22, 0.14, -0.08) * place_arc
	forearms[1].position = Vector3(0.46, -0.11, 0.52) + Vector3(0.11, 0.07, -0.04) * place_arc
	for arm in forearms: arm.visible = first_person
	# Third person: the animated character model's own arms hold the box.
	for part in ["LeftGrip", "RightGrip", "LeftThumb", "RightThumb"]: get_node(part).visible = first_person or not is_instance_valid(visual.kenney)
	if visible and not first_person: visual.pose_carry(get_node("LeftGrip").global_position, get_node("RightGrip").global_position)
	elif not visible: visual.reset_carry_pose()
	for arm in [visual.left_arm, visual.right_arm]: arm.get_node("Hand").visible = not visible
	if is_zero_approx(place_animation_remaining) and hide_after_place:
		hide_after_place = false
		hide()
