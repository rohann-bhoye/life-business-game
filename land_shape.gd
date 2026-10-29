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
	# The last 12 m before the end of the land slope down behind the outer crest, so
	# the edge (where Terrain3D blends towards its blank white colour) is never on
	# the skyline seen from the town.
	var edge := minf(minf(x + 128.0, 127.0 - x), minf(z - NORTH_EDGE, 127.0 - z))
	var to_river := z - river_z(x)
	var height := smoothstep(0.0, 0.35, t) * (1.5 + bumps * 7.0) + smoothstep(0.25, 1.0, t) * (body * 32.0 + ridge * 15.0 + bumps * 5.0)
	if to_river > 0.0:
		# The town hills slope down to the river over their last 45 m.
		height *= smoothstep(8.0, 50.0, to_river)
	else:
		# North bank: a low meadow (the giant policeman's) rising to far mountains.
		var far := smoothstep(-185.0, -240.0, z)
		height = 1.0 + bumps * 5.0 + far * (body * 30.0 + ridge * 14.0)
	height = 0.08 + height * smoothstep(0.0, 12.0, edge)
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
	for z in range(int(CAVE_Z) - 10, int(CAVE_Z) + 11):
		for x in range(int(CAVE_X) - 6, int(CAVE_X) + 12):
			var index := _land_index(x, z)
			var across := absf(z - CAVE_Z)
			var ahead := x - CAVE_X
			var height := land_heights[index]
			if ahead < 0.5 and ahead > -4.5 and across < 2.6:
				height = CAVE_FLOOR - 0.4
			elif ahead >= 0.5:
				height = lerpf(height, CAVE_FLOOR, (1.0 - smoothstep(3.0, 9.0, across)) * (1.0 - smoothstep(6.0, 11.0, ahead)))
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
			# Wet mud and sand down the river banks.
			colour = colour.lerp(Color(0.42, 0.37, 0.28) / 0.92, 1.0 - smoothstep(WATER_Y - 0.5, WATER_Y + 1.6, height))
			colour.a = 1.0
			data.set_color(point, colour)
