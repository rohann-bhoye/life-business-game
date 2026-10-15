extends SceneTree

const DIRECTORY := "res://assets/terrain/neighbourhood"
const SCENE_PATH := "res://neighbourhood_landscape.tscn"

func _initialize() -> void:
	call_deferred("_build")

func _height(x: float, z: float) -> float:
	var edge := smoothstep(38.0, 60.0, maxf(absf(x), absf(z)))
	var hills := 0.0
	for hill in [Vector3(-75, 18, -82), Vector3(83, 22, -55), Vector3(-78, 15, 87), Vector3(72, 20, 97)]:
		var distance := Vector2(x - hill.x, z - hill.z).length_squared()
		hills += hill.y * exp(-distance / 1600.0)
	return 0.08 + edge * hills

func _texture(normal: bool) -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var shade := 0.92 + sin(x * 2.1 + y * 3.7) * 0.025
			image.set_pixel(x, y, Color(0.5, 0.5, 1, 1) if normal else Color(shade, shade, shade, 0.5))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _build() -> void:
	if FileAccess.file_exists(SCENE_PATH) and "--rebuild" not in OS.get_cmdline_user_args():
		push_error("Starter landscape already exists. Use -- --rebuild only to intentionally replace its terrain data.")
		quit(1)
		return
	if not ClassDB.class_exists("Terrain3D"):
		push_error("Terrain3D native extension is not loaded. Import the installed addon in Godot first.")
		quit(1)
		return
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY)) == OK)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 8, 20)
	camera.current = true
	var terrain = ClassDB.instantiate("Terrain3D")
	terrain.name = "Landscape"
	root.add_child(terrain)
	terrain.set_camera(camera)
	terrain.region_size = 128
	terrain.mesh_size = 16
	terrain.mesh_lods = 5
	terrain.collision_mode = 0
	terrain.free_editor_textures = false
	terrain.cast_shadows = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain.assets.mesh_list = []
	var albedo := _texture(false)
	var normal := _texture(true)
	assert(ResourceSaver.save(albedo, DIRECTORY + "/grass_albedo.res", ResourceSaver.FLAG_CHANGE_PATH) == OK)
	assert(ResourceSaver.save(normal, DIRECTORY + "/grass_normal.res", ResourceSaver.FLAG_CHANGE_PATH) == OK)
	albedo.take_over_path(DIRECTORY + "/grass_albedo.res")
	normal.take_over_path(DIRECTORY + "/grass_normal.res")
	var grass = ClassDB.instantiate("Terrain3DTextureAsset")
	grass.name = "Neighbourhood grass"
	grass.albedo_texture = albedo
	grass.normal_texture = normal
	grass.uv_scale = 0.2
	grass.normal_depth = 0.0
	grass.ao_strength = 0.0
	terrain.assets.set_texture(0, grass)
	terrain.material.world_background = 0
	terrain.material.show_checkered = false
	for region_z in [-1, 0]:
		for region_x in [-1, 0]:
			var height := Image.create(128, 128, false, Image.FORMAT_RF)
			var color := Image.create(128, 128, false, Image.FORMAT_RGBA8)
			for z in range(128):
				for x in range(128):
					var altitude := _height(region_x * 128 + x, region_z * 128 + z)
					height.set_pixel(x, z, Color(altitude, 0, 0, 1))
					var tint := Color(0.28, 0.48, 0.31).lerp(Color(0.43, 0.48, 0.38), clampf(altitude / 24.0, 0, 1))
					color.set_pixel(x, z, Color(tint.r, tint.g, tint.b, 1))
			var images: Array[Image] = [height, null, color]
			terrain.data.import_images(images, Vector3(region_x * 128, 0, region_z * 128))
	terrain.data.save_directory(DIRECTORY)
	terrain.data_directory = DIRECTORY
	assert(ResourceSaver.save(terrain.assets, DIRECTORY + "/assets.tres", ResourceSaver.FLAG_CHANGE_PATH) == OK)
	assert(ResourceSaver.save(terrain.material, DIRECTORY + "/material.tres", ResourceSaver.FLAG_CHANGE_PATH) == OK)
	terrain.assets.take_over_path(DIRECTORY + "/assets.tres")
	terrain.material.take_over_path(DIRECTORY + "/material.tres")
	var packed := PackedScene.new()
	assert(packed.pack(terrain) == OK)
	assert(ResourceSaver.save(packed, SCENE_PATH) == OK)
	print("PASS: generated editable Terrain3D landscape, four 128m regions, flat neighbourhood centre and grass assets")
	quit()
