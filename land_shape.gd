extends RefCounted

# The land round the town (the Landscape Terrain3D): rolling
# foothills (about 2-9 m) starting a few metres past the flat town along a wavy
# line, then broad rounded mountains (a smooth mass plus gentle ridges, up to about
# 55 m); the main road keeps its valley pass both ways (_lower_valley).
# The colour map follows height and steepness: the lawn's own colours low down
# (grass_ground.gdshader, the terrain texture is about 0.92 bright), darker forest
# green up the slopes, rock only where it is high or steep, and snow on the peaks.
# Baked into the terrain data by tools/bake_land.gd (run it after changing this), so
# the game loads the land ready-made and the editor shows it; town_expansion.gd only
# plants the pines at load.
# North of the town hills (z -128..-256, two more 128 m regions) the land drops to
# the Dholkar river (RIVER_Z, a gentle meander) and rises again into the giant
# policeman's meadow and far mountains. A road pass (NORTH_ROAD_X) cuts through the
# hills from the market street to the river bridge and on north.
const Horizon := preload("res://horizon.gd")
const ROAD_Z := 7.0
const FLAT_TOWN := Rect2(-74.0, -56.0, 148.0, 116.0)
## The land runs x -128..127 and z NORTH_EDGE..127.
const NORTH_EDGE := -256
const RIVER_Z := -146.0
const WATER_Y := -3.0
const NORTH_ROAD_X := 50.0
const NORTH_ROAD_END := -230.0
## The Gufa Darwaza cave mouth (dungeon_world.gd) on the west hill, facing the town
## (+x): the land is levelled to CAVE_FLOOR in front of it and cut away under its
## tunnel.
const CAVE_X := -94.0
const CAVE_Z := -32.0
const CAVE_FLOOR := 3.2
## The Darwaza Guild office (dungeon_world.gd) at the hill's foot, facing the road
## (+z), on a level pad.
const GUILD_X := -80.0
const GUILD_Z := -18.0
const GUILD_FLOOR := 0.4
## Kisan Gram, the farming village across the river (farm_village.gd): a level pad round the
## North Road. The playable farm (farm_world.gd, farm_details.gd) is shifted there by FARM_OFFSET.
const VILLAGE := Rect2(20.0, -228.0, 82.0, 68.0)
const VILLAGE_FLOOR := 0.08
const FARM_OFFSET := Vector3(100.0, 0.0, -190.0)
## Heights of the 256 x 384 terrain points, kept while shaping so the colours need
## not read the terrain back.
var land_heights := PackedFloat32Array()

## The island coast: the last COAST metres of land round every edge drop into the sea
## (SEA_Y, the river's own level) down to SEA_BED, as cliffs under the hills and beaches
## where the land is low. The sea (sagar_point.gd) covers everything past OCEAN_HOLE's
## edge; inside it the land always stays above the water.
const SEA_Y := WATER_Y
const SEA_BED := -7.0
const COAST := 14.0
const OCEAN_HOLE := Rect2(-114.0, -242.0, 228.0, 354.0)
## Sagar Point: the peak of the low south coast hills, a flat round top PEAK_H high with
## the sea on three sides, reached by a ghat road (VIEW_ROAD control points, rising evenly)
## from the West Colony lane's south turning circle.
const PEAK := Vector2(-6.0, 102.0)
const PEAK_H := 18.0
const PLATEAU_R := 9.0
const VIEW_ROAD := [Vector2(-52.0, 57.5), Vector2(-52.0, 66.0), Vector2(-47.0, 74.0), Vector2(-34.0, 77.0), Vector2(-14.0, 77.0), Vector2(8.0, 78.0), Vector2(26.0, 82.0), Vector2(34.0, 92.0), Vector2(28.0, 104.0), Vector2(14.0, 107.0), Vector2(1.0, 104.0)]
const VIEW_ROAD_HALF := 3.0
## Sagar Beach: a sandy cove west of the peak, the land sloping gently from the ghat road
## (BEACH x range, from z BEACH.position.y) down into the sea, its waterline near z 117.
const BEACH := Rect2(-88.0, 84.0, 46.0, 43.0)
## The lighthouse on the south-east headland (sagar_point.gd), on a levelled pad.
const LIGHTHOUSE := Vector2(62.0, 108.0)
const VIEW_ROAD_START_Y := 0.111
const VIEW_ROAD_BOX := Rect2(-66.0, 50.0, 114.0, 70.0)
static var _view_road := PackedVector3Array()

## The ghat road's middle line as points about 1 m apart (a Catmull-Rom curve through
## VIEW_ROAD); y is the road surface, rising evenly from the town to the peak's top.
static func view_road() -> PackedVector3Array:
	if not _view_road.is_empty(): return _view_road
	var flat: Array[Vector2] = []
	for k in range(VIEW_ROAD.size() - 1):
		var p0: Vector2 = VIEW_ROAD[maxi(k - 1, 0)]
		var p1: Vector2 = VIEW_ROAD[k]
		var p2: Vector2 = VIEW_ROAD[k + 1]
		var p3: Vector2 = VIEW_ROAD[mini(k + 2, VIEW_ROAD.size() - 1)]
		var steps := maxi(2, ceili(p1.distance_to(p2)))
		for i in range(steps):
			var t := float(i) / steps
			flat.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	flat.append(VIEW_ROAD[VIEW_ROAD.size() - 1])
	var lengths := [0.0]
	for i in range(1, flat.size()): lengths.append(lengths[i - 1] + flat[i].distance_to(flat[i - 1]))
	var total: float = lengths[lengths.size() - 1]
	for i in range(flat.size()):
		var rise := clampf((lengths[i] - 5.0) / (total - 9.0), 0.0, 1.0)
		_view_road.append(Vector3(flat[i].x, lerpf(VIEW_ROAD_START_Y, PEAK_H + 0.03, rise), flat[i].y))
	return _view_road

## Distance from (x, z) to the ghat road's middle line and the road's height there
## (x = 1000 when far from it).
static func view_road_near(x: float, z: float) -> Vector2:
	if not VIEW_ROAD_BOX.has_point(Vector2(x, z)): return Vector2(1000.0, 0.0)
	var road := view_road()
	var best := Vector2(1000.0, 0.0)
	var point := Vector3(x, 0.0, z)
	for i in range(road.size() - 1):
		var a := Vector3(road[i].x, 0.0, road[i].z)
		var b := Vector3(road[i + 1].x, 0.0, road[i + 1].z)
		var along := clampf((point - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
		var distance := point.distance_to(a + (b - a) * along)
		if distance < best.x: best = Vector2(distance, lerpf(road[i].y, road[i + 1].y, along))
	return best

func _land_index(x: int, z: int) -> int:
	return (clampi(z, NORTH_EDGE, 127) - NORTH_EDGE) * 256 + clampi(x, -128, 127) + 128

## Middle of the river at `x`.
static func river_z(x: float) -> float:
	return RIVER_Z + 5.0 * sin((x - NORTH_ROAD_X) * 0.03)

## Shapes and paints the whole terrain in `data` (a Terrain3DData).
func shape(data) -> void:
	_mountains(data)
	_lower_valley(data)
	_cave_ground(data)
	_village_ground(data)
	_view_road_ground(data)
	_paint_land(data)
	data.calc_height_range(true)
	# All maps of all regions, with fresh mipmaps (distant land reads those; new
	# regions start with blank white ones). 3 is Terrain3DRegion.TYPE_MAX.
	data.update_maps(3, true, true)

func _land_height(x: float, z: float, mass: FastNoiseLite, ridges: FastNoiseLite, rolling: FastNoiseLite) -> float:
	var out := maxf(maxf(FLAT_TOWN.position.x - x, x - FLAT_TOWN.end.x), maxf(FLAT_TOWN.position.y - z, z - FLAT_TOWN.end.y))
	var bumps := rolling.get_noise_2d(x, z) * 0.5 + 0.5
	out -= bumps * 7.0
	if out <= 0.0: return 0.08
	var t := clampf(out / 56.0, 0.0, 1.0)
	var ridge := 1.0 - absf(ridges.get_noise_2d(x, z))
	ridge *= ridge
	var body := mass.get_noise_2d(x, z) * 0.5 + 0.5
	var edge := minf(minf(x + 128.0, 127.0 - x), minf(z - NORTH_EDGE, 127.0 - z))
	var to_river := z - river_z(x)
	var height := smoothstep(0.0, 0.35, t) * (1.5 + bumps * 7.0) + smoothstep(0.25, 1.0, t) * (body * 32.0 + ridge * 15.0 + bumps * 5.0)
	if to_river > 0.0:
		# The town hills slope down to the river over their last 45 m.
		height *= smoothstep(8.0, 50.0, to_river)
		# South of the airport the hills sink to low coast hills under Sagar Point's peak.
		height *= lerpf(1.0, 0.32, smoothstep(64.0, 92.0, z))
		var peak := PEAK_H * (1.0 - smoothstep(PLATEAU_R, PLATEAU_R + 40.0, Vector2(x, z).distance_to(PEAK)))
		height = maxf(height, peak * smoothstep(0.0, 10.0, out))
	else:
		# North bank: a low meadow (the giant policeman's) rising to far mountains.
		var far := smoothstep(-185.0, -240.0, z)
		height = 1.0 + bumps * 5.0 + far * (body * 30.0 + ridge * 14.0)
	# The island coast: the last COAST metres (wavy, for bays and headlands) fall into the sea.
	var wavy := rolling.get_noise_2d(x * 1.7 + 300.0, z * 1.7) * 0.5 + 0.5
	height = lerpf(SEA_BED, 0.08 + height, smoothstep(0.0, COAST, edge * (0.75 + 0.5 * wavy)))
	# Sagar Beach: a gentle grassy slope down to the sand, then the sand into the sea.
	var beach_side := maxf(BEACH.position.x - x, x - BEACH.end.x)
	var beach := (1.0 - smoothstep(0.0, 12.0, beach_side)) * smoothstep(BEACH.position.y - 8.0, BEACH.position.y + 2.0, z)
	if beach > 0.0:
		var shore_height := lerpf(3.0, 0.8, smoothstep(BEACH.position.y + 2.0, 104.0, z)) - maxf(z - 104.0, 0.0) * 0.3 + bumps * 0.25
		height = lerpf(height, shore_height, beach)
	# The road pass from the market street through the hills to the bridge and on.
	var road := (1.0 - smoothstep(6.0, 30.0, absf(x - NORTH_ROAD_X))) * smoothstep(NORTH_ROAD_END - 12.0, NORTH_ROAD_END, z)
	if z < FLAT_TOWN.position.y: height = lerpf(height, 0.08, road)
	# The river bed and its banks.
	var bank := absf(to_river)
	var bed := lerpf(WATER_Y - 3.0, WATER_Y + 0.6, smoothstep(4.0, 13.0, bank))
	# By the bridge the banks reach road level where its deck ends (19 m out).
	return lerpf(bed, height, smoothstep(lerpf(12.0, 13.0, road), lerpf(30.0, 19.0, road), bank))

func _mountains(data) -> void:
	var mass := FastNoiseLite.new()
	mass.seed = 3
	mass.frequency = 0.011
	mass.fractal_octaves = 3
	var ridges := FastNoiseLite.new()
	ridges.seed = 7
	ridges.frequency = 0.013
	ridges.fractal_octaves = 3
	ridges.fractal_gain = 0.4
	var rolling := FastNoiseLite.new()
	rolling.seed = 19
	rolling.frequency = 0.035
	rolling.fractal_octaves = 3
	land_heights.resize(256 * (128 - NORTH_EDGE))
	for z in range(NORTH_EDGE, 128):
		for x in range(-128, 128):
			var height := _land_height(x, z, mass, ridges, rolling)
			land_heights[_land_index(x, z)] = height
			data.set_height(Vector3(x, 0, z), height)

## Lowers the land along the road into the valley, blending back to the hills and
## mountains 45 m to each side. Past x 100 (where the road is already out of sight
## behind the crest) the mountains close the valley again, so the far end shows a
## mountain and never the empty sky past the edge of the land.
func _lower_valley(data) -> void:
	for side in [-1, 1]:
		for step in range(53):
			var x: float = side * (Horizon.START + step)
			var closing := 1.0 - smoothstep(100.0, 122.0, absf(x))
			for z in range(int(ROAD_Z) - 45, int(ROAD_Z) + 46):
				var weight := (1.0 - smoothstep(6.0, 45.0, absf(z - ROAD_Z))) * closing
				var index := _land_index(int(x), z)
				land_heights[index] = lerpf(land_heights[index], 0.06 + Horizon.height(x), weight)
				data.set_height(Vector3(x, 0, z), land_heights[index])

## A level apron in front of the cave mouth, the hill cut away under its tunnel (the
## tunnel's own floor and the mouth's rocks cover the cut), and the guild's pad.
func _cave_ground(data) -> void:
	for z in range(int(CAVE_Z) - 16, int(CAVE_Z) + 17):
		for x in range(int(CAVE_X) - 6, int(CAVE_X) + 20):
			var index := _land_index(x, z)
			var across := absf(z - CAVE_Z)
			var ahead := x - CAVE_X
			var height := land_heights[index]
			if ahead < 0.5 and ahead > -4.5 and across < 2.6:
				height = CAVE_FLOOR - 0.4
			elif ahead >= 0.5:
				height = lerpf(height, CAVE_FLOOR, (1.0 - smoothstep(7.0, 13.0, across)) * (1.0 - smoothstep(10.0, 17.0, ahead)))
			land_heights[index] = height
			data.set_height(Vector3(x, 0, z), height)
	for z in range(int(GUILD_Z) - 14, int(GUILD_Z) + 9):
		for x in range(int(GUILD_X) - 10, int(GUILD_X) + 11):
			var index := _land_index(x, z)
			var away := maxf(absf(x - GUILD_X) - 6.0, maxf(GUILD_Z - 9.0 - z, z - GUILD_Z - 4.0))
			land_heights[index] = lerpf(land_heights[index], GUILD_FLOOR, 1.0 - smoothstep(0.0, 4.0, away))
			data.set_height(Vector3(x, 0, z), land_heights[index])

## Levels the village pad to VILLAGE_FLOOR, blending into the land over 12 m round its edge.
func _village_ground(data) -> void:
	for z in range(int(VILLAGE.position.y) - 14, int(VILLAGE.end.y) + 14):
		for x in range(int(VILLAGE.position.x) - 14, int(VILLAGE.end.x) + 14):
			var away := maxf(maxf(VILLAGE.position.x - x, x - VILLAGE.end.x), maxf(VILLAGE.position.y - z, z - VILLAGE.end.y))
			var index := _land_index(x, z)
			land_heights[index] = lerpf(land_heights[index], VILLAGE_FLOOR, 1.0 - smoothstep(0.0, 12.0, away))
			data.set_height(Vector3(x, 0, z), land_heights[index])

## Cuts and fills the hill along the ghat road (level across, blending back over 7 m each
## side) and levels Sagar Point's round top and the lighthouse's pad.
func _view_road_ground(data) -> void:
	var pad := maxf(land_heights[_land_index(int(LIGHTHOUSE.x), int(LIGHTHOUSE.y))], 1.5)
	for z in range(int(LIGHTHOUSE.y) - 9, int(LIGHTHOUSE.y) + 10):
		for x in range(int(LIGHTHOUSE.x) - 9, int(LIGHTHOUSE.x) + 10):
			var index := _land_index(x, z)
			land_heights[index] = lerpf(land_heights[index], pad, 1.0 - smoothstep(4.0, 8.0, Vector2(x, z).distance_to(LIGHTHOUSE)))
			data.set_height(Vector3(x, 0, z), land_heights[index])
	for z in range(int(VIEW_ROAD_BOX.position.y), int(VIEW_ROAD_BOX.end.y)):
		for x in range(int(VIEW_ROAD_BOX.position.x), int(VIEW_ROAD_BOX.end.x)):
			var index := _land_index(x, z)
			var height := land_heights[index]
			var near := view_road_near(x, z)
			height = lerpf(height, near.y - 0.03, 1.0 - smoothstep(VIEW_ROAD_HALF + 0.8, VIEW_ROAD_HALF + 7.0, near.x))
			height = lerpf(height, PEAK_H, 1.0 - smoothstep(PLATEAU_R, PLATEAU_R + 3.0, Vector2(x, z).distance_to(PEAK)))
			land_heights[index] = height
			data.set_height(Vector3(x, 0, z), height)

## The village footpath: from the Main Road's west end past the guild office, up to the cave
## plaza. Painted into the land colours so it follows the ground. Each point is x, z.
const PATH := [Vector2(-73.0, 3.0), Vector2(-72.5, -4.0), Vector2(-72.0, -12.0), Vector2(-71.0, -22.0), Vector2(-71.5, -30.0), Vector2(-80.0, -31.0), Vector2(-87.5, -30.0)]
const PATH_HALF := 1.2
const PLAZA := Vector2(-89.0, -30.0)
const GUILD_YARD := Vector2(-80.0, -15.0)

func _path_distance(x: float, z: float) -> float:
	var best := 1000.0
	var point := Vector2(x, z)
	for k in range(PATH.size() - 1):
		var a: Vector2 = PATH[k]
		var b: Vector2 = PATH[k + 1]
		var along := clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, point.distance_to(a + (b - a) * along))
	return best

func _steepness(x: int, z: int) -> float:
	var height := land_heights[_land_index(x, z)]
	return absf(land_heights[_land_index(x + 1, z)] - height) + absf(land_heights[_land_index(x, z + 1)] - height)

func _paint_land(data) -> void:
	var lush := Color(0.2, 0.31, 0.1) / 0.92
	var fresh := Color(0.32, 0.44, 0.15) / 0.92
	var dry := Color(0.5, 0.5, 0.26) / 0.92
	var forest := Color(0.14, 0.26, 0.11) / 0.92
	var rock := Color(0.4, 0.38, 0.33) / 0.92
	var snow := Color(0.97, 0.97, 0.98)
	var macro := FastNoiseLite.new()
	macro.seed = 11
	macro.frequency = 0.05
	var patches := FastNoiseLite.new()
	patches.seed = 29
	patches.frequency = 0.25
	for z in range(NORTH_EDGE, 128):
		for x in range(-128, 128):
			var point := Vector3(x, 0, z)
			var height := land_heights[_land_index(x, z)]
			var colour := lush.lerp(fresh, smoothstep(0.3, 0.72, patches.get_noise_2d(x, z) * 0.5 + 0.5))
			colour = colour.lerp(dry, smoothstep(0.5, 0.8, macro.get_noise_2d(x, z) * 0.5 + 0.5) * 0.6)
			colour = colour.lerp(forest, smoothstep(2.0, 9.0, height) * 0.8)
			colour = colour.lerp(rock, clampf(smoothstep(26.0, 40.0, height) + smoothstep(1.3, 2.4, _steepness(x, z)), 0.0, 0.85))
			colour = colour.lerp(snow, smoothstep(44.0, 52.0, height))
			# Golden beach sand where the coast is low (wet and darker at the water), wet mud
			# and sand down the river banks.
			var edge := minf(minf(x + 128.0, 127.0 - x), minf(z - NORTH_EDGE, 127.0 - z))
			var shore := maxf(1.0 - smoothstep(16.0, 24.0, edge), smoothstep(95.0, 101.0, z) * (1.0 - smoothstep(-1.0, 3.0, maxf(BEACH.position.x - x, x - BEACH.end.x))))
			var sand := Color(0.86, 0.76, 0.55).lerp(Color(0.62, 0.53, 0.38), 1.0 - smoothstep(SEA_Y - 0.2, SEA_Y + 0.7, height)) / 0.92
			colour = colour.lerp(sand, shore * (1.0 - smoothstep(0.4, 2.6, height)) * (1.0 - smoothstep(1.6, 2.6, _steepness(x, z))))
			colour = colour.lerp(Color(0.42, 0.37, 0.28) / 0.92, (1.0 - shore) * (1.0 - smoothstep(WATER_Y - 0.5, WATER_Y + 1.6, height)))
			# Sagar Point: gravel shoulders along the ghat road, stone paving on the top.
			var near := view_road_near(x, z)
			colour = colour.lerp(Color(0.5, 0.45, 0.37) / 0.92, 1.0 - smoothstep(VIEW_ROAD_HALF + 0.4, VIEW_ROAD_HALF + 1.8, near.x))
			colour = colour.lerp(Color(0.64, 0.6, 0.52) / 0.92, 1.0 - smoothstep(PLATEAU_R - 0.5, PLATEAU_R + 0.5, Vector2(x, z).distance_to(PEAK)))
			# Packed earth footpath, stone paving round the cave and in front of the guild.
			var earth := Color(0.55, 0.46, 0.32) / 0.92
			var stone := Color(0.58, 0.57, 0.53) / 0.92
			colour = colour.lerp(earth, 1.0 - smoothstep(PATH_HALF - 0.3, PATH_HALF + 0.4, _path_distance(x, z)))
			colour = colour.lerp(stone, 1.0 - smoothstep(5.0, 6.0, Vector2(x, z).distance_to(PLAZA)))
			colour = colour.lerp(stone, (1.0 - smoothstep(5.0, 6.0, absf(x - GUILD_YARD.x) * 0.6)) * (1.0 - smoothstep(2.0, 3.0, absf(z - GUILD_YARD.y))))
			colour.a = 1.0
			data.set_color(point, colour)
