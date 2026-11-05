// Realistic look for our Blender kit pieces (Surya Nagri, dungeon_floor.gd): the piece keeps
// its designed colour from the kit atlas (UV), and a scanned CC0 texture set (Poly Haven,
// albedo / normal / AO-roughness-metal) adds the stone's grain, cracks, bumps and
// roughness, projected from the world (triplanar), so the boxy UVs never stretch it.
// Swatches marked in the kit's metal mask (gold, bronze, iron, ore) are polished metal that
// reflects the sky.
// fragment() calls shade() with UV and copies the results (functions cannot touch built-ins).
// LIGHT_VERSION (real_detail_low.gdshader, the Low preset): one projection, plain mipmaps
// and no roughness map, because the full version ran Surya Nagri at 20 FPS on an MX110.
uniform sampler2D atlas : source_color, filter_linear_mipmap, hint_default_white;
uniform sampler2D metal_mask : filter_linear_mipmap, hint_default_black;
#ifdef LIGHT_VERSION
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
#else
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_arm : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
#endif
// The detail texture's average colour (dungeon_floor.gd measures it), so the detail only
// varies the atlas colour and never shifts it.
uniform vec3 detail_mean = vec3(0.3);
uniform float detail_scale = 0.5;
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform float normal_strength = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 triplanar(sampler2D map, vec3 weights) {
	vec3 p = world_pos * detail_scale;
#ifdef LIGHT_VERSION
	// Only the projection that faces the surface most.
	if (weights.x >= weights.y && weights.x >= weights.z) return texture(map, p.zy);
	if (weights.y >= weights.z) return texture(map, p.xz);
	return texture(map, p.xy);
#else
	return texture(map, p.zy) * weights.x + texture(map, p.xz) * weights.y + texture(map, p.xy) * weights.z;
#endif
}

void shade(vec2 uv, out vec3 albedo, out float metallic, out float roughness, out float ao, out vec3 normal_map) {
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	vec3 base = texture(atlas, uv).rgb;
	vec3 grain = triplanar(detail_albedo, weights).rgb / max(detail_mean, vec3(0.02));
#ifdef LIGHT_VERSION
	vec3 arm = vec3(1.0, 0.85, 0.0);
#else
	vec3 arm = triplanar(detail_arm, weights).rgb;
#endif
	float metal = texture(metal_mask, uv).r;
	albedo = base * mix(vec3(1.0), clamp(grain, vec3(0.45), vec3(1.35)), detail_strength * (1.0 - 0.7 * metal));
	metallic = metal;
	roughness = mix(clamp(arm.g, 0.35, 1.0), 0.28 + 0.12 * arm.g, metal);
	ao = mix(1.0, arm.r, detail_strength);
	normal_map = triplanar(detail_normal, weights).rgb;
}
