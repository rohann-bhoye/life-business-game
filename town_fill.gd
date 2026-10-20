extends Node3D

# Fills the empty north part of the town (neighbourhood.gd calls build):
# - a back row of 4 houses behind the houses on the back lane, on a new Back Street;
# - an east colony of 4 houses (2 x 2) past the garden pond;
# - block-paved lanes joining both groups to the back lane, door steps and lamps;
# - a small west park by the farm with a chai stall, a sabzi (vegetable) stall,
#   benches and trees, using KayKit Restaurant Bits models (CC0).
# Houses are one merged mesh each (indian_house.gd) and the lamps use the glow pool
# instead of real lights, so low-end PCs keep their frame rate.

const IndianHouse := preload("res://indian_house.gd")
const BlockPath := preload("res://block_path.gd")
const Kenney := preload("res://kenney_assets.gd")
const KAYKIT := "res://assets/restaurant/kaykit/%s.gltf"
const KAYKIT_FURNITURE := "res://assets/furniture/kaykit/%s.gltf"
const SAFFRON := Color(1.0, 0.55, 0.1)
const GREEN := Color(0.1, 0.5, 0.25)
## [x, z, seed]: every new house faces +z (towards the lanes and the road).
const HOUSES := [
	[-15.0, -26.5, 21], [-6.0, -26.5, 22], [3.0, -26.5, 23], [12.0, -26.5, 24],
	[19.5, -18.0, 25], [27.5, -18.0, 26], [19.5, -26.5, 27], [27.5, -26.5, 28],
]
const LANES := [
	["EastColonyLane", Vector2(14.45, -13.6), Vector2(30.0, -13.6)],
	["BackStreet", Vector2(-18.0, -22.2), Vector2(30.0, -22.2)],
	["BackStreetLinkWest", Vector2(-10.5, -14.3), Vector2(-10.5, -21.5)],
	["BackStreetLinkMiddle", Vector2(7.5, -14.3), Vector2(7.5, -21.5)],
	["BackStreetLinkEast", Vector2(23.5, -14.3), Vector2(23.5, -21.5)],
	["ParkLane", Vector2(-16.6, -13.6), Vector2(-26.0, -13.6)],
	["ParkWalk", Vector2(-24.0, -14.3), Vector2(-24.0, -27.0)],
]
var town: Node3D

func build(neighbourhood: Node3D) -> void:
	town = neighbourhood
	name = "TownFill"
	for index in range(HOUSES.size()):
		var spot: Array = HOUSES[index]
		IndianHouse.build(self, "FillHouse%d" % index, Vector3(5.8, 0, 5.2), Vector3(spot[0], 0.1, spot[1]), 0.0, spot[2])
		town._collider("FillHouseBody%d" % index, self, Vector3(5.4, 4.0, 4.8), Vector3(spot[0], 2.1, spot[1]))
		# Door step from the front door to the lane in front.
		var lane_z: float = -13.6 if spot[1] > -20.0 else -22.2
		BlockPath.lay(self, "FillDoorStep%d" % index, Vector2(spot[0], spot[1] + 3.25), Vector2(spot[0], lane_z - 0.7), 3)
		_porch(index, Vector3(spot[0], 0.1, spot[1] + 2.95))
	for lane in LANES: BlockPath.lay(self, lane[0], lane[1], lane[2], 3)
	for x in [-14.0, 1.5, 16.0, 26.0]: town._streetlight(Vector3(x, 0.1, -21.3), PI, false)
	_park()

## In front of each new house: a potted plant by the door, and on every other house
## two plastic chairs and a small table (KayKit models).
func _porch(index: int, front: Vector3) -> void:
	Kenney.fit(self, "PorchPlant%d" % index, KAYKIT_FURNITURE % ["cactus_small_A", "cactus_medium_B"][index % 2], Vector3(0.35, 0.6, 0.35), front + Vector3(-1.5, 0, 0))
	if index % 2 == 1: return
	Kenney.fit(self, "PorchTable%d" % index, KAYKIT % "table_round_A_small", Vector3(0.6, 0.6, 0.6), front + Vector3(1.9, 0, 0))
	town._collider("PorchTableBody%d" % index, self, Vector3(0.5, 0.6, 0.5), front + Vector3(1.9, 0.3, 0))
	for side in [-1, 1]:
		Kenney.fit(self, "PorchChair%d_%d" % [index, side], KAYKIT % "chair_A", Vector3(0.42, 0.8, 0.42), front + Vector3(1.9 + side * 0.6, 0, 0), side * PI / 2)

## The west park: chai stall, sabzi stall, benches, trees and a lamp.
func _park() -> void:
	var park := Node3D.new()
	park.name = "WestPark"
	add_child(park)
	_stall(park, "ChaiStall", Vector3(-21.5, 0.1, -18.0), "CHAI  %s10" % String.chr(8377), SAFFRON)
	Kenney.fit(park, "Kettle", KAYKIT % "pot_A", Vector3(0.35, 0.3, 0.35), Vector3(-21.9, 1.12, -17.95))
	Kenney.fit(park, "CupStack", KAYKIT % "jar_A_small", Vector3(0.18, 0.2, 0.18), Vector3(-21.2, 1.12, -17.9))
	Kenney.fit(park, "DrinksFridge", KAYKIT % "fridge_A", Vector3(0.75, 1.7, 0.65), Vector3(-20.3, 0.1, -18.6))
	town._collider("DrinksFridgeBody", park, Vector3(0.75, 1.7, 0.65), Vector3(-20.3, 0.95, -18.6))
	for table in [Vector3(-21.0, 0.1, -20.2), Vector3(-19.4, 0.1, -16.6)]:
		Kenney.fit(park, "ChaiTable", KAYKIT % "table_round_A", Vector3(0.9, 0.75, 0.9), table)
		town._collider("ChaiTableBody", park, Vector3(0.8, 0.75, 0.8), table + Vector3(0, 0.38, 0))
		for side in [-1, 1]:
			Kenney.fit(park, "ChaiChair", KAYKIT % "chair_A", Vector3(0.45, 0.85, 0.45), table + Vector3(side * 0.75, 0, 0), side * PI / 2)
	_stall(park, "SabziStall", Vector3(-27.5, 0.1, -18.0), "TAAZI SABZI", GREEN)
	var crates := ["crate_tomatoes", "crate_potatoes", "crate_onions", "crate_carrots", "crate_lettuce"]
	for index in range(crates.size()):
		Kenney.fit(park, "SabziCrate%d" % index, KAYKIT % crates[index], Vector3(0.42, 0.3, 0.34), Vector3(-28.3 + index * 0.4, 1.12, -17.95 + (index % 2) * 0.12))
	for index in range(3):
		Kenney.fit(park, "FloorCrate%d" % index, KAYKIT % crates[index], Vector3(0.5, 0.36, 0.4), Vector3(-28.3 + index * 0.65, 0.1, -17.2))
	for bench in [Vector3(-22.0, 0.1, -25.0), Vector3(-26.0, 0.1, -25.0)]: _bench(park, bench)
	for tree in [Vector3(-20.0, 0.1, -28.5), Vector3(-29.0, 0.1, -27.5), Vector3(-29.5, 0.1, -22.0), Vector3(-19.0, 0.1, -23.5)]: town._tree(tree)
	town._streetlight(Vector3(-25.0, 0.1, -21.5), 0.0, false)

## A market stall: counter, four poles and a striped canopy with a sign.
func _stall(parent: Node3D, node_name: String, at: Vector3, sign: String, colour: Color) -> void:
	var stall := Node3D.new()
	stall.name = node_name
	stall.position = at
	parent.add_child(stall)
	town._box("Counter", stall, Vector3(2.0, 1.0, 0.8), Vector3(0, 0.5, 0), Color(0.55, 0.36, 0.2), true)
	town._box("CounterTop", stall, Vector3(2.1, 0.04, 0.9), Vector3(0, 1.02, 0), Color(0.8, 0.72, 0.58))
	for x in [-1.0, 1.0]:
		for z in [-0.45, 0.45]:
			town._box("Pole", stall, Vector3(0.06, 2.3, 0.06), Vector3(x, 1.15, z), Color(0.25, 0.25, 0.25))
	for stripe in range(5):
		town._box("Canopy%d" % stripe, stall, Vector3(0.46, 0.05, 1.3), Vector3(-0.92 + stripe * 0.46, 2.32, 0.1), colour if stripe % 2 == 0 else Color(0.97, 0.96, 0.9))
	town._box("SignBoard", stall, Vector3(1.6, 0.34, 0.04), Vector3(0, 1.95, 0.58), Color(0.97, 0.95, 0.88))
	var label := Label3D.new()
	label.name = "SignText"
	label.text = sign
	label.font_size = 40
	label.pixel_size = 0.004
	label.modulate = colour.darkened(0.3)
	label.outline_size = 0
	label.position = Vector3(0, 1.95, 0.605)
	stall.add_child(label)

func _bench(parent: Node3D, at: Vector3) -> void:
	var grey := Color(0.39, 0.43, 0.46)
	town._box("BenchSeat", parent, Vector3(1.6, 0.1, 0.45), at + Vector3(0, 0.5, 0), grey, true)
	town._box("BenchBack", parent, Vector3(1.6, 0.4, 0.07), at + Vector3(0, 0.78, -0.2), grey)
	for leg in [-0.65, 0.65]:
		town._box("BenchLeg", parent, Vector3(0.08, 0.45, 0.4), at + Vector3(leg, 0.25, 0), Color(0.15, 0.18, 0.19))
