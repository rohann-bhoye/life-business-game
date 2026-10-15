extends Node3D

const CharacterVisual = preload("res://character_visual.gd")
const WALK_SPEED := 1.15
var walkers: Array[Node3D] = []
var directions: Array[int] = []

func _ready() -> void:
	var shirts := [Color(0.8, 0.31, 0.38), Color(0.24, 0.49, 0.76), Color(0.7, 0.62, 0.2), Color(0.53, 0.38, 0.67)]
	for index in range(6):
		var person := Node3D.new()
		person.name = "Passerby%d" % index
		person.position = Vector3(-24 + index * 9, 0.12, 3.9 if index % 2 == 0 else 10.9)
		var visual := Node3D.new()
		visual.name = "CharacterVisual"
		visual.set_script(CharacterVisual)
		visual.shirt_color = shirts[index % shirts.size()]
		visual.skin_color = Color(0.6 + (index % 3) * 0.09, 0.39 + (index % 3) * 0.07, 0.25 + (index % 3) * 0.06)
		visual.face_movement = true
		person.add_child(visual)
		add_child(person)
		walkers.append(person)
		directions.append(1 if index % 2 == 0 else -1)

func _physics_process(delta: float) -> void:
	for index in range(walkers.size()):
		var person := walkers[index]
		person.position.x += directions[index] * WALK_SPEED * delta
		if absf(person.position.x) >= 29:
			person.position.x = clampf(person.position.x, -29, 29)
			directions[index] *= -1
