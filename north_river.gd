extends RefCounted

# North of the town hills: the market street runs on as the North Road through a
# pass in the hills (land_shape.gd lowers it) to the Dholkar river, crosses it on
# the Blender arch bridge (tools/blender/build_bridge.py) and ends in the giant
# policeman's meadow. The river is one water strip along its meander. No traffic
# uses the road yet. The player may walk all of it (the Landscape has collision):
# the bridge deck and railings are solid and invisible walls along both banks, the
# whole length of the river, keep the player out of the water.
const LandShape := preload("res://land_shape.gd")
const IndianHouse := preload("res://indian_house.gd")
const ROAD_START := -47.0
const BRIDGE_HALF := 20.0
const ROAD_Y := 0.111
const WATER_HALF := 12.0
## The bank walls stand this far from the river's middle, just above the water.
const BANK := 11.5

func build(expansion: Node) -> void:
	var town: Node3D = expansion.town
	var x := LandShape.NORTH_ROAD_X
	var bridge_z := LandShape.river_z(x)
	var road_material: Material = expansion._road_material()
	var markings := SurfaceTool.new()
	markings.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in [[ROAD_START, bridge_z + BRIDGE_HALF], [bridge_z - BRIDGE_HALF, LandShape.NORTH_ROAD_END]]:
		var length: float = part[0] - part[1]
		var middle: float = (part[0] + part[1]) / 2.0
		var road: MeshInstance3D = expansion._box("NorthRoad%d" % roundi(middle), Vector3(5.5, 0.012, length), Vector3(x, ROAD_Y, middle), Color(0.16, 0.18, 0.19))
		if road_material != null: road.material_override = road_material
		for side in [-1, 1]: IndianHouse.box(markings, Vector3(x + side * 2.6, ROAD_Y + 0.013, middle), Vector3(0.08, 0.008, length), Color(0.83, 0.86, 0.83))
		for dash in range(int(length / 4.0)):
			IndianHouse.box(markings, Vector3(x, ROAD_Y + 0.013, part[0] - 2.0 - dash * 4.0), Vector3(0.12, 0.008, 1.8), Color(0.88, 0.86, 0.68))
	var lines := MeshInstance3D.new()
	lines.name = "NorthRoadMarkings"
	lines.mesh = markings.commit()
	lines.material_override = IndianHouse._material()
	town.add_child(lines)
	var bridge := (load("res://assets/props/bridge/road_bridge.glb") as PackedScene).instantiate() as Node3D
	bridge.name = "DholkarBridge"
	bridge.position = Vector3(x, ROAD_Y, bridge_z)
	town.add_child(bridge)
	town._collider("BridgeDeck", town, Vector3(9.6, 0.7, BRIDGE_HALF * 2.0), Vector3(x, ROAD_Y - 0.35, bridge_z))
	for side in [-1, 1]:
		town._collider("BridgeRail%d" % side, town, Vector3(0.3, 2.0, BRIDGE_HALF * 2.0), Vector3(x + side * 4.65, ROAD_Y + 1.0, bridge_z))
	town.add_child(_river())
	town.add_child(_banks(x))

## Invisible walls along both banks, all the river's length, open only where the
## bridge crosses: one body of short wall pieces following the meander.
func _banks(bridge_x: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "RiverBanks"
	for part in [[-128.0, bridge_x - 5.0], [bridge_x + 5.0, 128.0]]:
		var stops: Array[float] = [part[0]]
		while stops[stops.size() - 1] + 4.0 < part[1]: stops.append(stops[stops.size() - 1] + 4.0)
		stops.append(part[1])
		for index in range(stops.size() - 1):
			for side in [-1, 1]:
				var a := Vector3(stops[index], 0, LandShape.river_z(stops[index]) + side * BANK)
				var b := Vector3(stops[index + 1], 0, LandShape.river_z(stops[index + 1]) + side * BANK)
				var piece := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = Vector3(a.distance_to(b) + 0.4, 6.0, 0.3)
				piece.shape = shape
				piece.position = (a + b) / 2.0 + Vector3(0, LandShape.WATER_Y + 2.0, 0)
				piece.rotation.y = -atan2(b.z - a.z, b.x - a.x)
				body.add_child(piece)
	return body

## The water: one strip along the river's middle line, from one end of the land to
## the other, its edges tucked under the banks.
func _river() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for step in range(64):
		var x0 := -128.0 + step * 4.0
		var x1 := x0 + 4.0
		var z0 := LandShape.river_z(x0)
		var z1 := LandShape.river_z(x1)
		for point in [Vector3(x0, 0, z0 - WATER_HALF), Vector3(x1, 0, z1 - WATER_HALF), Vector3(x1, 0, z1 + WATER_HALF), Vector3(x0, 0, z0 - WATER_HALF), Vector3(x1, 0, z1 + WATER_HALF), Vector3(x0, 0, z0 + WATER_HALF)]:
			st.add_vertex(point)
	var water := MeshInstance3D.new()
	water.name = "DholkarRiver"
	water.mesh = st.commit()
	water.position.y = LandShape.WATER_Y
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/water_flow.gdshader")
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return water
