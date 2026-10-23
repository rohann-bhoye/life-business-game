extends SceneTree

# Bakes the hills and mountains round the town (land_shape.gd) into the Landscape's
# Terrain3D data, so the game loads them ready-made and the editor shows them too.
# Run after changing land_shape.gd: Godot --headless --path . --script res://tools/bake_land.gd
const LandShape := preload("res://land_shape.gd")
const DIRECTORY := "res://assets/terrain/neighbourhood"

func _initialize() -> void:
	call_deferred("_bake")

func _bake() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	var landscape: Node = load("res://neighbourhood_landscape.tscn").instantiate()
	root.add_child(landscape)
	landscape.set_camera(camera)
	await process_frame
	var data = landscape.data
	if data.get_region_count() != 4:
		push_error("Expected the four 128 m landscape regions, found %d." % data.get_region_count())
		quit(1)
		return
	LandShape.new().shape(data)
	for region in data.get_regions_active(): region.set_modified(true)
	data.save_directory(DIRECTORY)
	print("PASS: land baked into %s" % DIRECTORY)
	quit()
