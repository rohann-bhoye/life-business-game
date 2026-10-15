extends Node3D

@export var doorway_position := Vector3(-3, 0.1, 2.5)
@export var doorway_width := 2.0
@export var doorway_height := 2.3

var panels: Array[StaticBody3D] = []
var openness := 0.0
var hold_seconds := 0.0
var opening := false

func _ready() -> void:
	position = doorway_position
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.45, 0.8, 0.86, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for side in [-1, 1]:
		var panel := StaticBody3D.new()
		panel.name = "LeftPanel" if side == -1 else "RightPanel"
		panel.position = Vector3(side * doorway_width / 4, doorway_height / 2, 0)
		add_child(panel)
		var shape := BoxShape3D.new()
		shape.size = Vector3(doorway_width / 2 - 0.04, doorway_height, 0.06)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = shape
		panel.add_child(collision)
		var mesh := MeshInstance3D.new()
		mesh.name = "Glass"
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = shape.size
		mesh.material_override = glass
		panel.add_child(mesh)
		for x in [-1, 1]:
			var frame := MeshInstance3D.new()
			frame.name = "Frame%s" % x
			frame.mesh = BoxMesh.new()
			frame.mesh.size = Vector3(0.04, doorway_height, 0.08)
			frame.position.x = x * (doorway_width / 4 - 0.03)
			panel.add_child(frame)
		for y in [-1, 1]:
			var rail := MeshInstance3D.new()
			rail.name = "HorizontalFrame%d" % y
			rail.mesh = BoxMesh.new()
			rail.mesh.size = Vector3(doorway_width / 2 - 0.04, 0.04, 0.08)
			rail.position.y = y * (doorway_height / 2 - 0.02)
			panel.add_child(rail)
		panels.append(panel)

func actor_near() -> bool:
	for actor in get_tree().current_scene.get_children() + get_tree().get_nodes_in_group("door_actors"):
		if not actor is Node3D or not actor.visible: continue
		if actor.name != "Player" and actor.name != "Worker" and actor.name != "StockWorker" and not actor.has_method("resolve_bargain") and not actor.is_in_group("door_actors"): continue
		var offset: Vector3 = actor.global_position - global_position
		if absf(offset.x) < doorway_width / 2 + 0.8 and absf(offset.z) < 2.4 and offset.y < doorway_height + 0.5: return true
	return false

func _process(delta: float) -> void:
	if actor_near(): hold_seconds = 1.0
	else: hold_seconds = maxf(0, hold_seconds - delta)
	var target_open := hold_seconds > 0
	if target_open != opening:
		opening = target_open
		var audio = get_parent() if get_parent().has_method("play_sound") else get_tree().current_scene.get_node("ShopOperations")
		audio.play_sound("door")
	openness = move_toward(openness, 1.0 if hold_seconds > 0 else 0.0, delta * 2.5)
	for index in range(panels.size()):
		panels[index].position.x = (-1 if index == 0 else 1) * (doorway_width / 4 + openness * (doorway_width / 2 + 0.05))
