extends SceneTree

# Renders a 256x256 transparent head-and-shoulders portrait of each employee (the
# same Kenney Mini models they use in the shop) into assets/ui/staff/<role>.png for
# the PC staff page. Run graphically: Godot --path . --script res://tools/staff_portraits.gd
const MODELS := {"cashier": "male-a", "stock": "male-e", "warehouse": "male-b"}

func _initialize() -> void:
	call_deferred("_run")

func _bounds(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var studio := Node3D.new()
	viewport.add_child(studio)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.75
	studio.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 25, 0)
	key.light_energy = 1.0
	studio.add_child(key)
	var camera := Camera3D.new()
	camera.fov = 26
	studio.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/staff"))
	for role in MODELS:
		var model: Node3D = (load("res://assets/characters/kenney/character-%s.glb" % MODELS[role]) as PackedScene).instantiate()
		studio.add_child(model)
		model.rotation.y = 0.35
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			players[0].play("idle")
			players[0].seek(0.4, true)
		for frame in range(2): await process_frame
		var box := _bounds(model)
		# Kenney Mini characters are mostly head: frame the head and upper body.
		var center := Vector3(box.get_center().x, box.position.y + box.size.y * 0.66, box.get_center().z)
		var half := box.size.y * 0.47
		camera.position = center + Vector3(0, half * 0.12, half / tan(deg_to_rad(camera.fov * 0.5)))
		camera.look_at(center, Vector3.UP)
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://assets/ui/staff/%s.png" % role))
		print("PORTRAIT ", role, " ", box.size)
		model.free()
	print("PASS: staff portraits")
	quit()
