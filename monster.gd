extends CharacterBody3D

# A Gufa Darwaza monster (Blender parts from tools/blender/build_monsters.py), animated
# in code. No weapon yet: it wanders near its home, notices the player in sight within
# its notice radius ("!"), chases (always slower than the player's 5 m/s) and, on
# touching, tells dungeon_world.gd, which throws the player back to the entry stone and
# drops the trip's treasure. It gives up after 3 s out of sight and walks home.
const KINDS := {
	"slime": {"name": "Jugnu Slime", "model": "jugnu_slime", "speed": 2.8, "notice": 7.0, "levels": [1, 3], "radius": 0.5, "hp": 2},
	"bat": {"name": "Chamgadar", "model": "chamgadar", "speed": 3.8, "notice": 9.0, "levels": [2, 5], "radius": 0.35, "flies": 1.5, "hp": 1},
	"mushroom": {"name": "Khumbi", "model": "khumbi", "speed": 2.4, "notice": 6.0, "levels": [3, 5], "radius": 0.4, "hp": 3},
	"boss": {"name": "Raja Jelly", "model": "raja_jelly", "speed": 2.6, "notice": 11.0, "levels": [5, 5], "radius": 1.1, "boss": true, "hp": 12},
}
const ATLAS := "res://assets/characters/monsters/monsters_print.png"
const CATCH := 0.95
const TINTS := [Color(0.6, 1.0, 0.7), Color(0.55, 0.78, 1.15), Color(1.1, 0.85, 0.35)]

var kind := ""
var data: Dictionary
var level := 1
var elite := false
var home := Vector3.ZERO
var player: Node3D
var dungeon: Node
var state := "wander"
var lost := 0.0
var wander_target := Vector3.ZERO
var wait := 0.0
var phase := 0.0
var parts := {}
var tag: Label3D
var alert: Label3D
var alert_time := 0.0
var notice := 6.0
var hp := 1
var max_hp := 1
var dying := false
var knock := Vector3.ZERO

static func create(type: String, lvl: int, at: Vector3, is_elite: bool, world: Node, who: Node3D) -> CharacterBody3D:
	var monster := preload("res://monster.gd").new()
	monster.kind = type
	monster.data = KINDS[type]
	monster.level = lvl
	monster.elite = is_elite
	monster.home = at
	monster.dungeon = world
	monster.player = who
	monster.notice = monster.data.notice * (1.5 if is_elite else 1.0)
	monster.hp = int(monster.data.hp) * (2 if is_elite else 1)
	monster.max_hp = monster.hp
	return monster

func _ready() -> void:
	name = data.name.replace(" ", "")
	collision_layer = 0
	collision_mask = 1
	position = home + Vector3(0, data.get("flies", 0.05), 0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = data.radius
	capsule.height = maxf(data.radius * 2.0, 1.0)
	shape.shape = capsule
	shape.position.y = capsule.height / 2.0
	add_child(shape)
	var scene := (load("res://assets/characters/monsters/%s.glb" % data.model) as PackedScene).instantiate() as Node3D
	# The models face +z; the monster walks towards -z.
	scene.rotation.y = PI
	add_child(scene)
	var tint: Color = TINTS[2] if elite else TINTS[0 if level <= 3 else 1]
	var atlas: Texture2D = load(ATLAS)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var body := node as MeshInstance3D
		# Blender numbers repeated object names (Body_001): keep the part name.
		body.name = str(body.name).split("_")[0]
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/materials/toon.gdshader")
		material.set_shader_parameter("albedo_texture", atlas)
		if body.name in ["Body", "WingL", "WingR", "Cap"] and not data.get("boss", false): material.set_shader_parameter("albedo", tint)
		var outline := ShaderMaterial.new()
		outline.shader = preload("res://assets/materials/outline.gdshader")
		outline.set_shader_parameter("width", 0.05 if data.get("boss", false) else 0.03)
		material.next_pass = outline
		body.material_override = material
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parts[body.name] = body
		parts[body.name + "_rest"] = body.position
	tag = Label3D.new()
	tag.text = "Lv %d %s%s" % [level, "Elite " if elite else "", data.name]
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 30
	tag.pixel_size = 0.0035
	tag.outline_size = 8
	tag.modulate = Color(1, 0.95, 0.6) if elite else Color(0.9, 1.0, 1.0)
	tag.no_depth_test = true
	tag.position = Vector3(0, (2.9 if data.get("boss", false) else 1.1) + data.get("flies", 0.0) * 0.4, 0)
	add_child(tag)
	alert = Label3D.new()
	alert.text = "!"
	alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert.font_size = 120
	alert.pixel_size = 0.006
	alert.outline_size = 14
	alert.modulate = Color(1, 0.25, 0.2)
	alert.no_depth_test = true
	alert.position = tag.position + Vector3(0, 0.55, 0)
	alert.visible = false
	add_child(alert)
	phase = randf() * TAU
	wander_target = home

func _sees_player() -> bool:
	var from := global_position + Vector3(0, 0.6, 0)
	var to := player.global_position + Vector3(0, 0.6, 0)
	if from.distance_to(to) > notice: return false
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player

func _physics_process(delta: float) -> void:
	if dying or not is_instance_valid(player) or dungeon.busy: return
	phase += delta
	var seen := _sees_player()
	if state != "chase" and seen:
		state = "chase"
		alert.visible = true
		alert_time = 0.9
		dungeon.sound("alert")
	elif state == "chase":
		lost = 0.0 if seen else lost + delta
		if lost > 3.0 or global_position.distance_to(player.global_position) > notice * 1.8: state = "return"
	var goal := wander_target
	var pace := 0.5
	match state:
		"chase":
			goal = player.global_position
			pace = 1.0
		"return":
			goal = dungeon.floor_root.to_global(home)
			if Vector2(global_position.x - goal.x, global_position.z - goal.z).length() < 1.0: state = "wander"
		"wander":
			wait -= delta
			goal = dungeon.floor_root.to_global(wander_target)
			if Vector2(global_position.x - goal.x, global_position.z - goal.z).length() < 0.6:
				if wait < 0.0:
					wait = randf_range(1.0, 3.0)
					wander_target = home + Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5))
				goal = global_position
	var flat := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	var moving := flat.length() > 0.3
	var speed: float = data.speed * pace
	if moving:
		flat = flat.normalized()
		velocity.x = flat.x * speed
		velocity.z = flat.z * speed
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), delta * 8.0)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if data.has("flies"):
		velocity.y = (data.flies + sin(phase * 3.0) * 0.25 - (global_position.y - dungeon.floor_root.global_position.y)) * 3.0
	elif not is_on_floor(): velocity.y -= 20.0 * delta
	else: velocity.y = 0.0
	velocity += knock
	knock = knock.move_toward(Vector3.ZERO, 40.0 * delta)
	move_and_slide()
	if state == "chase" and Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z).length() < CATCH + data.radius:
		dungeon.monster_touch(self)
	_animate(delta, moving)

func _animate(delta: float, moving: bool) -> void:
	if alert.visible:
		alert_time -= delta
		alert.position.y = tag.position.y + 0.55 + absf(sin(phase * 12.0)) * 0.12
		if alert_time <= 0.0: alert.visible = false
	var body: Node3D = parts.get("Body")
	var rate := 7.0 if state == "chase" else 4.5
	match kind:
		"slime", "boss":
			var hop := absf(sin(phase * rate * (0.55 if kind == "boss" else 1.0))) if moving else 0.0
			var squash := 1.0 + (0.18 - hop * 0.3 if moving else 0.0) + sin(phase * 2.0) * 0.03
			body.scale = Vector3(1.0 / sqrt(squash), 1.0 / sqrt(squash), squash)
			body.position.z = hop * (0.2 if kind == "boss" else 0.35)
			if kind == "boss" and parts.has("Crown"): parts["Crown"].position.z = parts["Crown_rest"].z + body.position.z + (squash - 1.0) * 1.2
		"bat":
			var flap := sin(phase * (22.0 if state == "chase" else 13.0))
			parts["WingL"].rotation.y = flap * 0.75
			parts["WingR"].rotation.y = -flap * 0.75
			body.rotation.x = 0.25 if state == "chase" else 0.0
		"mushroom":
			var step := sin(phase * rate * 1.3) if moving else 0.0
			parts["FootL"].position.y = parts["FootL_rest"].y - step * 0.08
			parts["FootR"].position.y = parts["FootR_rest"].y + step * 0.08
			parts["Cap"].rotation.x = step * 0.08
			parts["Stem"].position.z = absf(step) * 0.04

## A lathi hit from the player: a little knock-back and a white flash; at 0 hit points
## the monster dissolves into smoke (dungeon_effects.gd) and is gone.
func hurt(damage: int, from: Vector3) -> void:
	if dying: return
	dungeon.target_hit(self, float(hp) / float(max_hp))
	hp -= damage
	state = "chase"
	lost = 0.0
	var away := global_position - from
	away.y = 0.0
	knock = away.normalized() * (5.0 if not data.get("boss", false) else 1.5)
	for key in parts:
		var piece = parts[key]
		if piece is MeshInstance3D and piece.material_override is ShaderMaterial: piece.material_override.set_shader_parameter("glow", Color(0.8, 0.8, 0.8))
	get_tree().create_timer(0.1).timeout.connect(_unflash)
	_damage_number(damage, hp <= 0)
	if hp > 0:
		dungeon.sound("hit")
		return
	dying = true
	# Nothing to bump into while it melts away.
	for child in get_children():
		if child is CollisionShape3D: child.set_deferred("disabled", true)
	dungeon.monster_died(self)
	dungeon.sound("poof")
	var big: float = 2.4 if data.get("boss", false) else 1.0
	var Effects := preload("res://dungeon_effects.gd")
	Effects.smoke(dungeon.floor_root, position + Vector3(0, 0.5 * big, 0), big, 26 if big > 1.0 else 18)
	tag.visible = false
	alert.visible = false
	var fade := create_tween().set_parallel(true)
	fade.tween_property(self, "scale", Vector3(1.25, 0.05, 1.25), 0.7).set_ease(Tween.EASE_IN)
	fade.tween_property(self, "position:y", position.y + 0.8, 0.7)
	fade.chain().tween_callback(queue_free)

## The damage of a hit rising off the monster: white, or big and gold on the killing blow.
func _damage_number(damage: int, killing: bool) -> void:
	var number := Label3D.new()
	number.text = "-%d" % damage if not killing else "-%d  KO!" % damage
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	number.font_size = 64 if killing else 48
	number.pixel_size = 0.005
	number.outline_size = 12
	number.modulate = Color(1.0, 0.82, 0.25) if killing else Color(1, 1, 1)
	number.position = position + Vector3(randf_range(-0.25, 0.25), tag.position.y - 0.2, 0)
	dungeon.floor_root.add_child(number)
	var rise := number.create_tween().set_parallel(true)
	rise.tween_property(number, "position:y", number.position.y + 0.9, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	rise.tween_property(number, "modulate:a", 0.0, 0.35).set_delay(0.45)
	rise.tween_property(number, "outline_modulate:a", 0.0, 0.35).set_delay(0.45)
	rise.chain().tween_callback(number.queue_free)

func _unflash() -> void:
	for key in parts:
		var piece = parts[key]
		if is_instance_valid(piece) and piece is MeshInstance3D and piece.material_override is ShaderMaterial: piece.material_override.set_shader_parameter("glow", Color(0, 0, 0))

## Back to the spot it started at, calm (after catching the player).
func reset() -> void:
	state = "wander"
	lost = 0.0
	alert.visible = false
	wander_target = home
	global_position = dungeon.floor_root.to_global(home + Vector3(0, data.get("flies", 0.05), 0))
	velocity = Vector3.ZERO
