extends Node3D

# The giant policeman of Dholkarpur Gaon: a 140 m constable (Blender model,
# tools/blender/build_giant_police.py) standing on the meadow across the Dholkar river,
# past the north hills (north_river.gd). The hills hide him below the chest; from the town you see his chest and big-headed face over
# the roofs and the ridge. His head turns to follow the player and his body slowly turns with it,
# so he is always keeping an eye on the town. Added by town_expansion.gd.
const SCALE := 80.0
## The head is drawn 1.4x so his face reads from anywhere in town.
const HEAD_SIZE := 1.4
const SPOT := Vector3(-20.0, -1.0, -185.0)
const NECK := 1.52
const HEAD_TURN := 0.75
const BODY_TURN := 0.2

var body: Node3D
var head: Node3D
var player: Node3D

func _ready() -> void:
	name = "GiantPolice"
	position = SPOT
	scale = Vector3.ONE * SCALE
	body = _part("Body", "giant_police_body")
	head = _part("Head", "giant_police_head")
	head.position.y = NECK
	# Looking down over the hills at the town.
	head.rotation.x = 0.4
	head.scale = Vector3.ONE * HEAD_SIZE
	player = get_tree().current_scene.get_node_or_null("Player")

func _part(node_name: String, model: String) -> Node3D:
	var part := (load("res://assets/props/police/%s.glb" % model) as PackedScene).instantiate() as Node3D
	part.name = node_name
	add_child(part)
	for mesh in part.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	var to_player := player.global_position - global_position
	var look := clampf(atan2(to_player.x, to_player.z), -HEAD_TURN, HEAD_TURN)
	body.rotation.y = lerp_angle(body.rotation.y, look * BODY_TURN, delta * 0.4)
	head.rotation.y = lerp_angle(head.rotation.y, look, delta * 0.8)
