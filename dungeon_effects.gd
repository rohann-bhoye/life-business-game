extends RefCounted

# One-shot particle effects for the dungeon, removed by themselves when they finish:
# a puff of smoke (a monster vanishing, a rock breaking) and flying stone chunks.
static func smoke(parent: Node3D, at: Vector3, size := 1.0, count := 22, tint := Color(0.78, 0.82, 0.9)) -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = 0.85
	puff.amount = count
	puff.lifetime = 1.3
	puff.direction = Vector3.UP
	puff.spread = 70.0
	puff.gravity = Vector3(0, 0.5, 0)
	puff.initial_velocity_min = 0.4 * size
	puff.initial_velocity_max = 1.4 * size
	puff.scale_amount_min = 0.7 * size
	puff.scale_amount_max = 1.6 * size
	puff.damping_min = 0.6
	puff.damping_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(tint, 0.65))
	fade.set_color(1, Color(tint, 0.0))
	puff.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	# A soft round puff: white in the middle fading to clear at the edge.
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	var round := GradientTexture2D.new()
	round.gradient = soft
	round.fill = GradientTexture2D.FILL_RADIAL
	round.fill_from = Vector2(0.5, 0.5)
	round.fill_to = Vector2(1.0, 0.5)
	round.width = 64
	round.height = 64
	material.albedo_texture = round
	quad.material = material
	puff.mesh = quad
	_play(parent, puff, at, 1.5)

static func chunks(parent: Node3D, at: Vector3, colour: Color, count := 14) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = count
	burst.lifetime = 1.0
	burst.direction = Vector3.UP
	burst.spread = 80.0
	burst.gravity = Vector3(0, -12.0, 0)
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 5.0
	burst.angular_velocity_min = -400.0
	burst.angular_velocity_max = 400.0
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.6
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.1, 0.12)
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	box.material = material
	burst.mesh = box
	_play(parent, burst, at, 1.2)

static func _play(parent: Node3D, particles: CPUParticles3D, at: Vector3, life: float) -> void:
	particles.position = at
	particles.emitting = true
	parent.add_child(particles)
	particles.get_tree().create_timer(life + 0.3).timeout.connect(particles.queue_free)
