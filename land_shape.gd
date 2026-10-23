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
const Horizon := preload("res://horizon.gd")
const ROAD_Z := 7.0
const FLAT_TOWN := Rect2(-74.0, -56.0, 148.0, 116.0)
## Heights of the 256 x 256 terrain points (x, z from -128), kept while shaping so
## the colours need not read the terrain back.
var land_heights := PackedFloat32Array()

func _land_index(x: int, z: int) -> int:
	return (clampi(z, -128, 127) + 128) * 256 + clampi(x, -128, 127) + 128

## Shapes and paints the whole 256 x 256 m terrain in `data` (a Terrain3DData).
func shape(data) -> void:
	_mountains(data)
	_lower_valley(data)
	_paint_land(data)
	data.calc_height_range(true)
	data.update_maps()

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
	var edge := minf(minf(x + 128.0, 127.0 - x), minf(z + 128.0, 127.0 - z))
	var height := smoothstep(0.0, 0.35, t) * (1.5 + bumps * 7.0) + smoothstep(0.25, 1.0, t) * (body * 32.0 + ridge * 15.0 + bumps * 5.0)
	return 0.08 + height * smoothstep(0.0, 12.0, edge)

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
	land_heights.resize(256 * 256)
	for z in range(-128, 128):
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
	for z in range(-128, 128):
		for x in range(-128, 128):
			var point := Vector3(x, 0, z)
			var height := land_heights[_land_index(x, z)]
			var colour := lush.lerp(fresh, smoothstep(0.3, 0.72, patches.get_noise_2d(x, z) * 0.5 + 0.5))
			colour = colour.lerp(dry, smoothstep(0.5, 0.8, macro.get_noise_2d(x, z) * 0.5 + 0.5) * 0.6)
			colour = colour.lerp(forest, smoothstep(2.0, 9.0, height) * 0.8)
			colour = colour.lerp(rock, clampf(smoothstep(26.0, 40.0, height) + smoothstep(1.3, 2.4, _steepness(x, z)), 0.0, 0.85))
			colour = colour.lerp(snow, smoothstep(44.0, 52.0, height))
			colour.a = 1.0
			data.set_color(point, colour)
