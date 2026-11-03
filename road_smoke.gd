extends RefCounted

# A wall of thick drifting smoke across the end of a road, with an invisible wall inside it,
# so testers cannot see or walk to the unfinished land beyond. Admin mode builds none.
const WIDTH := 80.0
const HEIGHT := 40.0
const LAYERS := 8
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(0.62, 0.64, 0.67, 1.0);
uniform float seed = 0.0;
void fragment() {
	vec2 uv = UV * vec2(3.0, 1.4) + vec2(TIME * 0.018 + seed, seed * 0.37);
	float a = texture(noise, uv).r;
	float b = texture(noise, uv * 0.55 + vec2(-TIME * 0.011, seed)).r;
	float density = smoothstep(0.12, 0.45, a * 0.6 + b * 0.4);
	float sides = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float height = smoothstep(0.0, 0.5, UV.y);
	float near = smoothstep(1.5, 6.0, length(VERTEX));
	ALBEDO = tint.rgb * (0.82 + 0.18 * a);
	ALPHA = density * sides * height * near;
}
"""

static var shader: Shader
static var noise_texture: NoiseTexture2D

## point is where the smoke stands, direction the way it faces away from the town.
static func build(expansion: Node3D, parent: Node3D, point: Vector3, direction: Vector3, label: String) -> void:
	if preload("res://admin_mode.gd").enabled(): return
	var root := Node3D.new()
	root.name = "RoadSmoke%s" % label
	root.position = point
	root.rotation.y = atan2(direction.x, direction.z)
	parent.add_child(root)
	if shader == null:
		shader = Shader.new()
		shader.code = SHADER
		var noise := FastNoiseLite.new()
		noise.frequency = 0.012
		noise.fractal_octaves = 4
		noise_texture = NoiseTexture2D.new()
		noise_texture.noise = noise
		noise_texture.seamless = true
		noise_texture.width = 256
		noise_texture.height = 256
	for layer in range(LAYERS):
		var quad := QuadMesh.new()
		quad.size = Vector2(WIDTH, HEIGHT)
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("noise", noise_texture)
		material.set_shader_parameter("seed", layer * 0.31)
		var sheet := MeshInstance3D.new()
		sheet.name = "Smoke%d" % layer
		sheet.mesh = quad
		sheet.material_override = material
		sheet.position = Vector3(0, HEIGHT * 0.5 - 1.0, (layer - 3.5) * 1.1)
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sheet)
	# The invisible wall, a little in front of the thickest smoke.
	expansion.town._collider("RoadSmokeWall%s" % label, root, Vector3(WIDTH, 16.0, 1.0), Vector3(0, 7.0, -3.0))
