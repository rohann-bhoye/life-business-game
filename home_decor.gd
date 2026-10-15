extends Node3D

# Furnishes the player's home with Kenney Furniture Kit models. The original
# walls, door, bed collider and SleepArea are unchanged; the block bed mesh is
# hidden behind a real bed model. Large pieces get simple box colliders.
const Kenney = preload("res://kenney_assets.gd")
const FURNITURE := "res://assets/furniture/kenney/%s.glb"

# [model, fit size, position, yaw, collider?]
const PIECES := [
	["bedDouble", Vector3(1.15, 1.0, 1.95), Vector3(-1.1, 0.0, -0.8), 0.0, false],
	["sideTable", Vector3(0.42, 0.5, 0.4), Vector3(-0.3, 0.0, -1.55), 0.0, true],
	["lampRoundTable", Vector3(0.25, 0.42, 0.25), Vector3(-0.3, 0.5, -1.55), 0.0, false],
	["cabinetTelevision", Vector3(1.2, 0.55, 0.45), Vector3(1.0, 0.0, -1.55), 0.0, true],
	["televisionModern", Vector3(1.0, 0.65, 0.25), Vector3(1.0, 0.55, -1.6), 0.0, false],
	["rugRectangle", Vector3(1.6, 0.02, 1.2), Vector3(0.95, 0.004, -0.45), 0.0, false],
	["tableCoffee", Vector3(0.8, 0.4, 0.5), Vector3(1.0, 0.0, -0.45), 0.0, true],
	["loungeSofa", Vector3(1.5, 0.85, 0.8), Vector3(1.0, 0.0, 0.6), PI, true],
	["kitchenFridge", Vector3(0.6, 1.7, 0.6), Vector3(-1.48, 0.0, 1.45), PI / 2, true],
	["kitchenStove", Vector3(0.6, 0.9, 0.6), Vector3(-1.48, 0.0, 0.8), PI / 2, true],
	["pottedPlant", Vector3(0.45, 1.0, 0.45), Vector3(1.5, 0.0, 1.5), 0.0, false],
	["plantSmall1", Vector3(0.4, 0.55, 0.4), Vector3(-1.0, 0.0, 2.3), 0.0, false],
	["plantSmall1", Vector3(0.4, 0.55, 0.4), Vector3(1.0, 0.0, 2.3), 0.0, false],
]

func _ready() -> void:
	name = "HomeDecor"
	var house := get_parent()
	for part in ["Bed/MeshInstance3D", "Bed/Pillow"]:
		var node := house.get_node_or_null(part) as Node3D
		if node != null: node.hide()
	for index in range(PIECES.size()):
		var piece: Array = PIECES[index]
		var holder := Kenney.fit(self, "%s%d" % [piece[0], index], FURNITURE % piece[0], piece[1], piece[2], piece[3])
		if piece[4]: _collider(holder.name + "Body", piece[1], piece[2], piece[3])

func _collider(node_name: String, size: Vector3, position: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position + Vector3(0, size.y / 2, 0)
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	add_child(body)
