shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 base_color : source_color = vec4(0.18, 0.42, 0.22, 1.0);
uniform float wind_strength = 0.08;
uniform float wind_speed = 1.2;

void vertex() {
	vec3 world_origin = MODEL_MATRIX[3].xyz;
	float height_weight = clamp(VERTEX.y, 0.0, 1.8) / 1.8;
	float wave = sin(TIME * wind_speed + world_origin.x * 0.31 + world_origin.z * 0.23 + VERTEX.y * 1.7);
	VERTEX.x += wave * wind_strength * height_weight;
	VERTEX.z += cos(TIME * wind_speed * 0.73 + world_origin.z * 0.27) * wind_strength * 0.45 * height_weight;
}

void fragment() {
	ALBEDO = base_color.rgb * COLOR.rgb;
	ROUGHNESS = 0.9;
}
