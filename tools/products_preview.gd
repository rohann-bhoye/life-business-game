extends SceneTree
# Lines up every custom product at its shelf size and saves a screenshot.
# godot --path . --script res://tools/products_preview.gd -- out.png
const Assets = preload("res://product_assets.gd")
const SIZES := {"tomato": Vector3(0.19, 0.18, 0.19), "carrot": Vector3(0.2, 0.2, 0.2), "cabbage": Vector3(0.2, 0.19, 0.2), "corn": Vector3(0.2, 0.22, 0.2), "apple": Vector3(0.17, 0.17, 0.17), "bottle": Vector3(0.18, 0.4, 0.18), "snack": Vector3(0.16, 0.26, 0.11), "soap": Vector3(0.16, 0.12, 0.11), "oil": Vector3(0.14, 0.3, 0.11), "milk": Vector3(0.14, 0.24, 0.11), "bread": Vector3(0.2, 0.14, 0.17), "chocolate": Vector3(0.13, 0.15, 0.1), "honey": Vector3(0.13, 0.16, 0.13)}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1400, 500)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.8, 0.82, 0.84)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	world.add_child(sun)
	var x := 0.0
	for id in SIZES:
		var holder := Node3D.new()
		holder.position = Vector3(x, 0, 0)
		world.add_child(holder)
		(preload("res://produce_assets.gd") if id in ["tomato", "carrot", "cabbage", "corn", "apple"] else Assets).attach(holder, id, SIZES[id])
		x += SIZES[id].x + 0.04
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(x / 2 - 0.03, 0.22, 1.5)
	cam.fov = 28
	await create_timer(0.6).timeout
	var out := "products_preview.png"
	for a in OS.get_cmdline_user_args(): out = a
	root.get_texture().get_image().save_png(out)
	quit()
