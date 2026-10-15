extends Node3D

@export var doorway_width := 1.25
@export var doorway_height := 2.25

var panel: StaticBody3D
var hinge: Node3D
var openness := 0.0
var opening := false

func _ready() -> void:
	hinge = Node3D.new()
	hinge.name = "Hinge"
	add_child(hinge)
	panel = StaticBody3D.new()
	panel.name = "DoorPanel"
	panel.position = Vector3(doorway_width * 0.5, doorway_height * 0.5, 0)
	hinge.add_child(panel)
	var shape := BoxShape3D.new()
	shape.size = Vector3(doorway_width, doorway_height, 0.08)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	panel.add_child(collision)
	var mesh := MeshInstance3D.new()
	mesh.name = "Door"
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = shape.size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.28, 0.12)
	material.roughness = 0.82
	mesh.material_override = material
	panel.add_child(mesh)
	_add_handle(Vector3(doorway_width - 0.14, doorway_height * 0.48, -0.075))
	_add_handle(Vector3(doorway_width - 0.14, doorway_height * 0.48, 0.075))

func _add_handle(at: Vector3) -> void:
	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	handle.mesh = SphereMesh.new()
	handle.mesh.radius = 0.055
	handle.mesh.height = 0.11
	handle.position = at - panel.position
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.66, 0.28)
	material.metallic = 0.7
	handle.material_override = material
	panel.add_child(handle)

func toggle() -> void:
	opening = not opening
	get_tree().current_scene.get_node("ShopOperations").play_sound("door")

func _process(delta: float) -> void:
	openness = move_toward(openness, 1.0 if opening else 0.0, delta * 2.2)
	# Swing outward around the frame-side hinge, leaving the opening completely clear.
	hinge.rotation.y = openness * PI * 0.5
