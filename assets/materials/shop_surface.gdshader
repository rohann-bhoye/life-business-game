shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D surface_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 atlas_origin = vec2(0.0);
uniform float meters_per_tile = 2.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 base_color : source_color = vec4(0.12, 0.13, 0.14, 1.0);
uniform float detail_strength = 1.0;
uniform bool road_surface = false;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.88;
uniform float surface_specular : hint_range(0.0, 1.0) = 0.15;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 axis = abs(world_normal);
	vec2 coordinates = axis.y > max(axis.x, axis.z) ? world_position.xz :
		(axis.x > axis.z ? world_position.zy : world_position.xy);
	vec2 uv = atlas_origin + vec2(0.001) + fract(coordinates / meters_per_tile) * 0.498;
	vec3 sampled = texture(surface_atlas, uv).rgb;
	if (road_surface) {
		float grain = fract(sin(dot(floor(world_position.xz * 3.0), vec2(12.9898, 78.233))) * 43758.5453);
		float wear = smoothstep(0.35, 0.0, abs(fract(world_position.z * 0.42) - 0.5));
		sampled *= mix(0.82 + grain * 0.13, 0.9, wear * 0.18);
	}
	ALBEDO = mix(base_color.rgb, sampled, detail_strength) * tint.rgb;
	ROUGHNESS = surface_roughness;
	SPECULAR = surface_specular;
}
