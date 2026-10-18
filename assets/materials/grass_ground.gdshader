shader_type spatial;
render_mode diffuse_burley;

// Town lawn: large lush and sun-dried areas, mid-size patches, a few bare-earth
// spots and a fine isotropic grain (faded with distance so it never shimmers). The
// colours match the grass blades (grass_blades.gdshader) so they blend into it.
uniform vec4 lush_color : source_color = vec4(0.2, 0.31, 0.1, 1.0);
uniform vec4 fresh_color : source_color = vec4(0.32, 0.44, 0.15, 1.0);
uniform vec4 dry_color : source_color = vec4(0.5, 0.5, 0.26, 1.0);
uniform vec4 earth_color : source_color = vec4(0.42, 0.33, 0.22, 1.0);
// Off on Low Fast: skips the grain and bump (most of the per-pixel cost).
uniform bool fine_detail = true;
varying vec3 world_position;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += noise(p) * amplitude;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;
		amplitude *= 0.5;
	}
	return value / 0.9375;
}

void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = world_position.xz;
	float macro = fbm(p * 0.05);
	float patches = fbm(p * 0.3 + 17.0);
	float earth = smoothstep(0.66, 0.78, fbm(p * 0.16 + 40.0));
	vec3 colour = mix(lush_color.rgb, fresh_color.rgb, smoothstep(0.3, 0.72, patches));
	colour = mix(colour, dry_color.rgb, smoothstep(0.5, 0.8, macro) * 0.6);
	colour = mix(colour, earth_color.rgb, earth * 0.75);
	if (fine_detail) {
		float detail = 1.0 - smoothstep(12.0, 55.0, length(VERTEX));
		float grain = noise(p * 11.0) * 0.45 + noise(p * 29.0) * 0.35 + noise(p * 61.0) * 0.2;
		colour *= mix(1.0, 0.9 + grain * 0.2, detail);
		// A little bump from the grain so low sun picks out the lawn texture.
		float dx = noise((p + vec2(0.02, 0.0)) * 29.0) - noise(p * 29.0);
		float dz = noise((p + vec2(0.0, 0.02)) * 29.0) - noise(p * 29.0);
		NORMAL_MAP = normalize(vec3(-dx * 1.5 * detail, -dz * 1.5 * detail, 1.0)) * 0.5 + 0.5;
	}
	ALBEDO = colour;
	ROUGHNESS = 0.96;
}
