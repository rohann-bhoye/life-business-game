extends SceneTree

# Bakes the Landscape's ground texture (assets/terrain/neighbourhood): a 256 px tile
# of grass detail (tufts, fine blades and soft patches, grey so the painted colour
# map tints it, about 0.92 bright on average) and its normal map, both with
# mipmaps. Run: Godot --headless --path . --script res://tools/bake_terrain_texture.gd
const DIRECTORY := "res://assets/terrain/neighbourhood"
const SIZE := 256

func _initialize() -> void:
	var tufts := _noise(FastNoiseLite.TYPE_CELLULAR, 0.045, 5)
	var blades := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.32, 9)
	var patches := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 13)
	var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var bump := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var patch := patches.get_pixel(x, y).r
			var height := tufts.get_pixel(x, y).r * 0.45 + blades.get_pixel(x, y).r * 0.4 + patch * 0.15
			var shade := 0.8 + height * 0.24
			var warm := (patch - 0.5) * 0.06
			albedo.set_pixel(x, y, Color(shade + warm, shade, shade - warm, 0.5))
			bump.set_pixel(x, y, Color(height, height, height, 1.0))
	bump.bump_map_to_normal_map(3.0)
	for y in range(SIZE):
		for x in range(SIZE):
			var normal := bump.get_pixel(x, y)
			normal.a = 0.6
			bump.set_pixel(x, y, normal)
	for part in [[albedo, "grass_albedo"], [bump, "grass_normal"]]:
		part[0].generate_mipmaps()
		var texture := ImageTexture.create_from_image(part[0])
		assert(ResourceSaver.save(texture, "%s/%s.res" % [DIRECTORY, part[1]]) == OK)
	print("PASS: ground texture baked")
	quit()

func _noise(kind: int, frequency: float, seed: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.noise_type = kind
	noise.frequency = frequency
	noise.seed = seed
	return noise.get_seamless_image(SIZE, SIZE)
