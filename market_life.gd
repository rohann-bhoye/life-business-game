extends Node3D

# Life on the market street (town_expansion.gd builds it): people strolling up and
# down both pavements, and scooters, autos and cars driving on the left, Indian
# style, up the market street and the North Road over the bridge (north_river.gd).
# The vehicles run one loop: north in the west lane, a U-turn at the far end of the
# North Road (out of sight past the river), south in the east lane and a U-turn at
# the market street's mouth before the main road. They keep their distance and stop
# for the player or anyone else in their lane.
const CharacterVisual := preload("res://character_visual.gd")
const Models := preload("res://vehicle_models.gd")
const LandShape := preload("res://land_shape.gd")
const ROAD_X := 50.0
const LANE := 1.2
const SOUTH_TURN := 1.0
const NORTH_TURN := -226.0
const ROAD_Y := 0.11
const SPEED := 5.5
const GAP := 7.0
const KINDS := ["scooter", "auto", "car", "scooter", "auto", "scooter", "car", "scooter"]
const WALK_SPEED := 1.1
const WALK_ENDS := Vector2(-45.0, 1.5)

var town: Node3D
var path := PackedVector3Array()
var lengths := PackedFloat32Array()
var vehicles: Array[Node3D] = []
var progress: Array[float] = []
var walkers: Array[Node3D] = []
var walk_directions: Array[int] = []
var player: Node3D

func build(neighbourhood: Node3D) -> void:
	name = "MarketLife"
	town = neighbourhood
	_build_path()
	var loop := lengths[lengths.size() - 1]
	for index in range(KINDS.size()):
		vehicles.append(_vehicle(index, KINDS[index]))
		progress.append(loop - index * loop / KINDS.size())
	var shirts := [Color(0.85, 0.35, 0.3), Color(0.25, 0.5, 0.8), Color(0.95, 0.75, 0.2), Color(0.45, 0.7, 0.4), Color(0.75, 0.45, 0.8), Color(0.95, 0.55, 0.65)]
	for index in range(6):
		var side := -1 if index % 2 == 0 else 1
		var person := Node3D.new()
		person.name = "MarketWalker%d" % index
		person.position = Vector3(ROAD_X + side * 3.55, 0.12, lerpf(WALK_ENDS.x, WALK_ENDS.y, (index + 0.5) / 6.0))
		var visual := Node3D.new()
		visual.name = "CharacterVisual"
		visual.set_script(CharacterVisual)
		visual.shirt_color = shirts[index]
		visual.skin_color = Color(0.58 + (index % 3) * 0.08, 0.38 + (index % 3) * 0.06, 0.25 + (index % 3) * 0.05)
		visual.face_movement = true
		person.add_child(visual)
		add_child(person)
		walkers.append(person)
		walk_directions.append(1 if index % 3 == 0 else -1)

func _ready() -> void:
	player = get_tree().current_scene.get_node_or_null("Player")

## The loop as points with running lengths: north lane, far U-turn, south lane, near U-turn.
func _build_path() -> void:
	path.append(Vector3(ROAD_X - LANE, ROAD_Y, SOUTH_TURN))
	path.append(Vector3(ROAD_X - LANE, ROAD_Y, NORTH_TURN))
	for step in range(1, 8): path.append(Vector3(ROAD_X - LANE * cos(PI * step / 8.0), ROAD_Y, NORTH_TURN - LANE * sin(PI * step / 8.0)))
	path.append(Vector3(ROAD_X + LANE, ROAD_Y, NORTH_TURN))
	path.append(Vector3(ROAD_X + LANE, ROAD_Y, SOUTH_TURN))
	for step in range(1, 9): path.append(Vector3(ROAD_X + LANE * cos(PI * step / 8.0), ROAD_Y, SOUTH_TURN + LANE * sin(PI * step / 8.0)))
	lengths.append(0.0)
	for index in range(1, path.size()): lengths.append(lengths[index - 1] + path[index].distance_to(path[index - 1]))

func _vehicle(index: int, kind: String) -> Node3D:
	var vehicle := Node3D.new()
	vehicle.name = "Market%s%d" % [kind.capitalize(), index]
	add_child(vehicle)
	var model := MeshInstance3D.new()
	model.name = "Model"
	match kind:
		"scooter":
			model.mesh = Models.scooter([Color(0.8, 0.15, 0.15), Color(0.15, 0.35, 0.8), Color(0.9, 0.9, 0.9), Color(0.1, 0.1, 0.1)][index % 4])
			_rider(vehicle, [Color(0.3, 0.6, 0.4), Color(0.9, 0.4, 0.5), Color(0.95, 0.7, 0.2)][index % 3], Vector3(0, 0.68, 0.22))
		"auto":
			model.mesh = Models.auto_rickshaw()
			_rider(vehicle, Color(0.85, 0.85, 0.8), Vector3(0, 0.55, -0.3))
		"car":
			model.mesh = Models.car([Color(0.75, 0.15, 0.15), Color(0.2, 0.3, 0.55)][index % 2])
	vehicle.add_child(model)
	return vehicle

func _rider(vehicle: Node3D, shirt: Color, offset: Vector3) -> void:
	town._box("RiderBody", vehicle, Vector3(0.42, 0.55, 0.3), offset + Vector3(0, 0.55, 0), shirt)
	town._box("RiderLegs", vehicle, Vector3(0.38, 0.18, 0.45), offset + Vector3(0, 0.22, -0.15), Color(0.2, 0.22, 0.3))
	town._box("RiderHead", vehicle, Vector3(0.3, 0.3, 0.3), offset + Vector3(0, 1.0, 0), Color(0.62, 0.43, 0.3))
	town._box("RiderHair", vehicle, Vector3(0.32, 0.1, 0.32), offset + Vector3(0, 1.17, 0.01), Color(0.08, 0.07, 0.06))

## Where on the loop `distance` is, and which way the road runs there.
func _place(distance: float) -> Array:
	var loop := lengths[lengths.size() - 1]
	distance = fposmod(distance, loop)
	var index := 1
	while index < lengths.size() - 1 and lengths[index] < distance: index += 1
	var from := path[index - 1]
	var to := path[index]
	var span := lengths[index] - lengths[index - 1]
	return [from.lerp(to, (distance - lengths[index - 1]) / span if span > 0.0 else 0.0), (to - from).normalized()]

func _physics_process(delta: float) -> void:
	var loop := lengths[lengths.size() - 1]
	for index in range(vehicles.size()):
		var ahead := progress[(index + vehicles.size() - 1) % vehicles.size()]
		var gap := fposmod(ahead - progress[index], loop)
		var at: Array = _place(progress[index])
		if gap > GAP and not _blocked(at[0], at[1]): progress[index] = fposmod(progress[index] + SPEED * delta, loop)
		at = _place(progress[index])
		vehicles[index].position = at[0]
		vehicles[index].rotation.y = atan2(-at[1].x, -at[1].z)
	for index in range(walkers.size()):
		var person := walkers[index]
		person.position.z += walk_directions[index] * WALK_SPEED * delta
		if person.position.z < WALK_ENDS.x or person.position.z > WALK_ENDS.y:
			person.position.z = clampf(person.position.z, WALK_ENDS.x, WALK_ENDS.y)
			walk_directions[index] *= -1

## Someone (the player or a market walker) standing in the lane just ahead.
func _blocked(at: Vector3, heading: Vector3) -> bool:
	var actors: Array[Node3D] = walkers.duplicate()
	if is_instance_valid(player): actors.append(player)
	for actor in actors:
		var offset := actor.global_position - at
		var along := offset.x * heading.x + offset.z * heading.z
		var across := absf(offset.x * heading.z - offset.z * heading.x)
		if along > 0.0 and along < 4.5 and across < 1.3: return true
	return false
