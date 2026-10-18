extends Node3D

# Moving traffic on the main road (Indian left-hand traffic): autos, scooters, a car
# and a city bus. Eastbound (+x) uses the north lane, westbound the south lane. Every
# vehicle stops for the player, customers and staff in its lane, keeps a gap to the
# vehicle ahead, and the westbound bus halts at the bus stop during the day. Fewer
# vehicles drive at night and all of them show headlights. Past the town the road
# goes over a crest and down a valley (horizon.gd): vehicles follow it, tilting on
# the slope, and loop round far below the horizon. Pure scenery: no economy.
const Horizon := preload("res://horizon.gd")
const ROAD_END := 118.0
const EAST_LANE := 5.6
const WEST_LANE := 8.4
const SAFE_GAP := 3.0
const BUS_STOP_X := -24.0
const BUS_STOP_SECONDS := 6.0
# kind, lane direction (+1 east / -1 west), start x, cruise speed (m/s)
const FLEET := [
	["auto", 1, -60.0, 6.0], ["scooter", 1, -20.0, 7.5], ["car", 1, 25.0, 7.0], ["auto", 1, 55.0, 5.5],
	["bus", -1, 60.0, 5.0], ["scooter", -1, 20.0, 8.0], ["auto", -1, -15.0, 6.0], ["scooter", -1, -55.0, 7.0],
]

var town: Node3D
var business
var vehicles: Array[Node3D] = []
var states: Array = []
var headlight_material: StandardMaterial3D
var bus: Node3D
var bus_passenger: Node3D
var night := false
var low_quality := false

func build(neighbourhood: Node3D, business_ref) -> void:
	name = "Traffic"
	town = neighbourhood
	business = business_ref
	headlight_material = StandardMaterial3D.new()
	headlight_material.albedo_color = Color(1, 0.97, 0.85)
	headlight_material.emission = Color(1, 0.93, 0.7)
	for index in range(FLEET.size()):
		var entry: Array = FLEET[index]
		var vehicle := _vehicle(index, entry[0])
		vehicle.position = Vector3(entry[2], 0.1, EAST_LANE if entry[1] > 0 else WEST_LANE)
		vehicle.rotation.y = -PI / 2 if entry[1] > 0 else PI / 2
		vehicles.append(vehicle)
		states.append({"direction": entry[1], "cruise": entry[3], "speed": entry[3], "stop": 0.0, "served": false, "rests_at_night": index % 2 == 1})
		if entry[0] == "bus": bus = vehicle
	bus_passenger = town.find_child("BusWaiting", true, false)
	business.clock_changed.connect(_update_night)
	_update_night()

## Low-poly vehicles; the front is -z so look direction matches Node3D.look_at.
func _vehicle(index: int, kind: String) -> Node3D:
	var vehicle := Node3D.new()
	vehicle.name = "Traffic%s%d" % [kind.capitalize(), index]
	add_child(vehicle)
	var size := Vector3.ZERO
	match kind:
		"auto":
			town._box("Body", vehicle, Vector3(1.3, 0.75, 2.4), Vector3(0, 0.65, 0), Color(0.95, 0.78, 0.1))
			town._box("Lower", vehicle, Vector3(1.32, 0.25, 2.42), Vector3(0, 0.38, 0), Color(0.1, 0.5, 0.25))
			town._box("Canopy", vehicle, Vector3(1.35, 0.12, 1.9), Vector3(0, 1.55, 0.15), Color(0.08, 0.08, 0.09))
			for z in [-0.8, 1.1]: town._box("Pillar%s" % z, vehicle, Vector3(1.25, 0.6, 0.06), Vector3(0, 1.2, z), Color(0.08, 0.08, 0.09))
			_person(vehicle, Color(0.85, 0.85, 0.8), Vector3(0, 0.3, -0.45))
			size = Vector3(1.4, 1.6, 2.5)
		"scooter":
			var colour: Color = [Color(0.8, 0.15, 0.15), Color(0.15, 0.35, 0.8), Color(0.9, 0.9, 0.9)][index % 3]
			town._box("Body", vehicle, Vector3(0.35, 0.45, 1.3), Vector3(0, 0.5, 0), colour)
			town._box("Handle", vehicle, Vector3(0.6, 0.06, 0.06), Vector3(0, 1.05, -0.55), Color(0.2, 0.2, 0.2))
			_person(vehicle, [Color(0.9, 0.4, 0.5), Color(0.3, 0.6, 0.4), Color(0.95, 0.7, 0.2)][index % 3], Vector3(0, 0.45, 0.15))
			size = Vector3(0.7, 1.6, 1.5)
		"car":
			town._box("Body", vehicle, Vector3(1.7, 0.7, 3.8), Vector3(0, 0.6, 0), Color(0.85, 0.85, 0.88))
			town._box("Cabin", vehicle, Vector3(1.5, 0.55, 2.0), Vector3(0, 1.22, 0.2), Color(0.25, 0.35, 0.45))
			size = Vector3(1.8, 1.6, 3.9)
		"bus":
			town._box("Body", vehicle, Vector3(2.4, 2.4, 9.0), Vector3(0, 1.55, 0), Color(0.15, 0.45, 0.75))
			town._box("Stripe", vehicle, Vector3(2.42, 0.3, 9.02), Vector3(0, 1.0, 0), Color(0.95, 0.75, 0.15))
			town._box("Windows", vehicle, Vector3(2.44, 0.7, 7.6), Vector3(0, 2.05, 0.3), Color(0.2, 0.28, 0.35))
			town._box("Windscreen", vehicle, Vector3(2.1, 1.0, 0.05), Vector3(0, 1.9, -4.51), Color(0.2, 0.28, 0.35))
			var sign := Label3D.new()
			sign.text = "MARKET - STATION"
			sign.position = Vector3(0, 2.55, -4.53)
			sign.rotation.y = PI
			sign.font_size = 40
			sign.pixel_size = 0.005
			sign.modulate = Color(1, 0.85, 0.3)
			vehicle.add_child(sign)
			size = Vector3(2.5, 2.8, 9.1)
	for x in ([-0.45, 0.45] if kind != "scooter" else [0.0]):
		var lamp: MeshInstance3D = town._box("Headlight%s" % x, vehicle, Vector3(0.22, 0.14, 0.04), Vector3(x * (2.0 if kind == "bus" else 1.0), 0.75 if kind != "bus" else 0.7, -size.z / 2.0 - 0.01), Color(1, 0.97, 0.85))
		lamp.material_override = headlight_material
	for wheel in [-size.z * 0.32, size.z * 0.32]:
		town._box("Wheel%s" % wheel, vehicle, Vector3(size.x + 0.04 if kind != "scooter" else 0.12, 0.42, 0.42), Vector3(0, 0.22, wheel), Color(0.05, 0.05, 0.05))
	# Moving solid body so the player cannot walk through vehicles.
	var body := AnimatableBody3D.new()
	body.name = "Collider"
	body.sync_to_physics = false
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y / 2.0, 0)
	body.add_child(shape)
	vehicle.add_child(body)
	vehicle.set_meta("length", size.z)
	return vehicle

func _person(vehicle: Node3D, shirt: Color, offset: Vector3) -> void:
	# Seated low-poly rider (an animated character would play its walk cycle while moving).
	town._box("RiderBody", vehicle, Vector3(0.42, 0.55, 0.3), offset + Vector3(0, 0.55, 0), shirt)
	town._box("RiderLegs", vehicle, Vector3(0.38, 0.18, 0.45), offset + Vector3(0, 0.22, -0.15), Color(0.2, 0.22, 0.3))
	town._box("RiderHead", vehicle, Vector3(0.3, 0.3, 0.3), offset + Vector3(0, 1.0, 0), Color(0.62, 0.43, 0.3))
	town._box("RiderHair", vehicle, Vector3(0.32, 0.1, 0.32), offset + Vector3(0, 1.17, 0.01), Color(0.08, 0.07, 0.06))

func is_night() -> bool:
	return business.minutes_of_day < 360.0 or business.minutes_of_day >= 1260.0

func set_quality(quality: int) -> void:
	low_quality = quality == 0
	_update_night()

func _update_night() -> void:
	var was_night := night
	night = is_night()
	headlight_material.emission_enabled = business.minutes_of_day < 390.0 or business.minutes_of_day >= 1110.0
	headlight_material.emission_energy_multiplier = 3.0
	# Late at night (and on Low graphics) only half the fleet keeps driving.
	for index in range(vehicles.size()):
		var parked: bool = (night or low_quality) and states[index].rests_at_night
		vehicles[index].visible = not parked
		vehicles[index].get_node("Collider/CollisionShape3D").disabled = parked
	# Nobody waits for the bus at night.
	if is_instance_valid(bus_passenger) and night != was_night: bus_passenger.visible = not night

func _actors() -> Array:
	var result: Array = []
	for actor in get_tree().current_scene.get_children():
		if actor is Node3D and actor.visible and (actor.name in ["Player", "Worker", "StockWorker"] or actor.has_method("resolve_bargain")):
			result.append(actor)
	return result

## Distance to the nearest thing in this vehicle's lane ahead (people or vehicles).
func _clearance(index: int, actors: Array) -> float:
	var vehicle := vehicles[index]
	var direction: int = states[index].direction
	var front: float = vehicle.global_position.x + direction * float(vehicle.get_meta("length")) / 2.0
	var best := INF
	for actor in actors:
		var ahead: float = (actor.global_position.x - front) * direction
		if ahead > -0.5 and absf(actor.global_position.z - vehicle.global_position.z) < 1.7: best = minf(best, maxf(0.0, ahead))
	for other_index in range(vehicles.size()):
		var other := vehicles[other_index]
		if other_index == index or not other.visible or states[other_index].direction != direction: continue
		var ahead: float = (other.position.x - vehicle.position.x) * direction - (float(other.get_meta("length")) + float(vehicle.get_meta("length"))) / 2.0
		if ahead > -0.5: best = minf(best, maxf(0.0, ahead))
	return best

func _physics_process(delta: float) -> void:
	var actors := _actors()
	for index in range(vehicles.size()):
		var vehicle := vehicles[index]
		if not vehicle.visible: continue
		var state: Dictionary = states[index]
		if state.stop > 0.0:
			state.stop -= delta
			if state.stop <= 0.0 and is_instance_valid(bus_passenger): bus_passenger.visible = false
			continue
		var clearance := _clearance(index, actors)
		var target: float = state.cruise if clearance > SAFE_GAP * 2.0 else (state.cruise * (clearance - SAFE_GAP) / SAFE_GAP if clearance > SAFE_GAP else 0.0)
		state.speed = move_toward(state.speed, target, delta * 6.0)
		var before: float = vehicle.position.x
		vehicle.position.x += state.direction * state.speed * delta
		if vehicle == bus and not night and not state.served and (before - BUS_STOP_X) * (vehicle.position.x - BUS_STOP_X) <= 0.0:
			# The bus halts at the stop; the waiting passenger boards when it leaves.
			vehicle.position.x = BUS_STOP_X
			state.speed = 0.0
			state.stop = BUS_STOP_SECONDS
			state.served = true
		if absf(vehicle.position.x) > ROAD_END:
			vehicle.position.x = -ROAD_END * state.direction
			state.served = false
			if vehicle == bus and is_instance_valid(bus_passenger): bus_passenger.visible = not night
		vehicle.position.y = 0.1 + Horizon.height(vehicle.position.x)
		vehicle.rotation.x = atan(Horizon.slope(vehicle.position.x) * state.direction)
