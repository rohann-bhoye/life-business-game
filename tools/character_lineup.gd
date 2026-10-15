extends SceneTree

# Renders all Kenney Mini characters side by side and prints their size/animations.
func _initialize() -> void:
	call_deferred("_run")

func _bounds(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var current: Transform3D = xf * (node.transform if node is Node3D else Transform3D.IDENTITY)
	if node is MeshInstance3D and node.mesh != null:
		result = current * node.get_aabb()
	for child in node.get_children():
		var b := _bounds(child, current)
		if b.has_volume(): result = result.merge(b) if result.has_volume() else b
	return result

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.65, 0.75)
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)
	var names := []
	for g in ["male", "female"]:
		for c in ["a", "b", "c", "d", "e", "f"]: names.append("character-%s-%s" % [g, c])
	for i in range(names.size()):
		var model: Node3D = load("res://assets/characters/kenney/%s.glb" % names[i]).instantiate()
		world.add_child(model)
		model.position = Vector3((i % 6) * 1.2 - 3.0, 0, -int(i / 6) * 1.6)
		var box := _bounds(model, Transform3D.IDENTITY)
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0] if not model.find_children("*", "AnimationPlayer", true, false).is_empty() else null
		if i == 0: print("ANIMS ", player.get_animation_list() if player else "none")
		print("MODEL %s size=%s pos=%s" % [names[i], box.size, box.position])
		if player: player.play("idle")
		var label := Label3D.new()
		label.text = names[i].trim_prefix("character-")
		label.font_size = 48
		label.pixel_size = 0.004
		label.position = Vector3(0, -0.15, 0.4)
		model.add_child(label)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.6, 4.2)
	camera.look_at(Vector3(0, 0.3, -0.8))
	camera.current = true
	root.size = Vector2i(1152, 648)
	for f in range(10): await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TEMP").path_join("character_lineup.png"))
	print("PASS: lineup")
	quit()
