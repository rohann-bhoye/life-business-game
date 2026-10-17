extends Node3D

# Night in the town (21:00-06:00): market shops pull their shutters down, the chai
# stall closes late, most passers-by go home and the houses switch on porch lamps
# with a warm pool of light. Streetlights and traffic headlights are handled by
# day_night.gd and traffic.gd. Pure scenery: no economy.
const MARKET_OPEN := 480.0
const MARKET_CLOSE := 1260.0
const CHAI_OPEN := 300.0
const CHAI_CLOSE := 1380.0

var town: Node3D
var business
var shutters: Array[MeshInstance3D] = []
var chai_people: Array[Node3D] = []
var porch_lamps: Array[Node3D] = []
var lamp_material: StandardMaterial3D
var last_state := ""

func build(neighbourhood: Node3D, business_ref) -> void:
	name = "NightLife"
	town = neighbourhood
	business = business_ref
	# Market shops and houses live in TownExpansion's FutureTown (hidden until unlocked).
	var places: Array = town.get_children()
	var future := town.get_node_or_null("FutureTown")
	if future != null: places += future.get_children()
	for shop in places:
		if not shop.name.begins_with("MarketShop"): continue
		var shutter: MeshInstance3D = town._box("ClosedShutter", shop, Vector3(3.8, 2.1, 0.06), Vector3(0, 1.15, 0.6), Color(0.5, 0.53, 0.55))
		shutter.visible = false
		shutters.append(shutter)
	for person_name in ["ChaiWala", "ChaiCustomer1", "ChaiCustomer2"]:
		var person := town.find_child(person_name, true, false) as Node3D
		if person != null: chai_people.append(person)
	lamp_material = StandardMaterial3D.new()
	lamp_material.albedo_color = Color(1, 0.9, 0.65)
	lamp_material.emission = Color(1, 0.8, 0.45)
	lamp_material.emission_energy_multiplier = 2.5
	for house in places:
		if not house.name.begins_with("TownHouse") or house.name.begins_with("TownHouseBody") or house.name.begins_with("TownHousePath"): continue
		_porch_lamp(house)
	business.clock_changed.connect(_refresh)
	_refresh()

## A small lamp beside the front door with a soft light pool on the path.
func _porch_lamp(house: Node3D) -> void:
	var front := Vector3(0, 0, 1).rotated(Vector3.UP, house.rotation.y)
	var lamp := Node3D.new()
	lamp.name = "PorchLamp"
	house.get_parent().add_child(lamp)
	lamp.global_position = Vector3(house.global_position.x, 0.1, house.global_position.z) + front * 3.0
	lamp.rotation.y = house.rotation.y
	var bulb: MeshInstance3D = town._box("Bulb", lamp, Vector3(0.22, 0.22, 0.12), Vector3(0.9, 2.3, 0), Color(1, 0.9, 0.65))
	bulb.material_override = lamp_material
	var pool := MeshInstance3D.new()
	pool.name = "Pool"
	var plane := PlaneMesh.new()
	plane.size = Vector2(4, 4)
	pool.mesh = plane
	pool.position = Vector3(0.5, 0.03, 0.8)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.material_override = town._light_pool_material()
	lamp.add_child(pool)
	porch_lamps.append(lamp)

func is_night() -> bool:
	return business.minutes_of_day < 360.0 or business.minutes_of_day >= 1260.0

func _refresh() -> void:
	var minute: float = business.minutes_of_day
	var market_open := minute >= MARKET_OPEN and minute < MARKET_CLOSE
	var chai_open := minute >= CHAI_OPEN and minute < CHAI_CLOSE
	var lamps_on := minute < 390.0 or minute >= 1110.0
	var state := "%s%s%s%s" % [market_open, chai_open, lamps_on, is_night()]
	if state == last_state: return
	last_state = state
	for shutter in shutters: shutter.visible = not market_open
	for person in chai_people: person.visible = chai_open
	lamp_material.emission_enabled = lamps_on
	for lamp in porch_lamps: lamp.get_node("Pool").visible = lamps_on
	# Most passers-by go home at night; every third one keeps walking.
	var street := town.get_node_or_null("StreetLife")
	if street != null:
		for index in range(street.walkers.size()):
			street.walkers[index].visible = not is_night() or index % 3 == 0
