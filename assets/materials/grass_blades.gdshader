shader_type spatial;
render_mode cull_disabled, diffuse_burley, world_vertex_coords;

// Thin grass blades: dark at the root, sunlit yellow-green at the tip. Each clump
// gets its own shade from INSTANCE_CUSTOM.r (a few are dry and straw-coloured), the
// tips sway in gusts of wind, and normals point up so the blades light like the
// ground they grow from (no dark back faces).
uniform vec4 root_color : source_color = vec4(0.16, 0.26, 0.08, 1.0);
uniform vec4 tip_color : source_color = vec4(0.52, 0.64, 0.25, 1.0);
uniform vec4 dry_color : source_color = vec4(0.7, 0.64, 0.36, 1.0);
uniform float wind_strength = 0.05;

varying float tip;
varying float shade;

void vertex() {
	tip = UV.y;
	shade = INSTANCE_CUSTOM.r;
	float gust = sin(TIME * 1.3 + VERTEX.x * 0.35 + VERTEX.z * 0.2) * 0.65 + sin(TIME * 2.9 + VERTEX.x * 1.3 - VERTEX.z * 1.1) * 0.35;
	float bend = tip * tip * wind_strength;
	VERTEX.x += gust * bend;
	VERTEX.z += gust * bend * 0.4;
}

void fragment() {
	vec3 colour = mix(root_color.rgb, tip_color.rgb, smoothstep(0.0, 1.0, tip));
	colour = mix(colour, dry_color.rgb * mix(0.55, 1.0, tip), smoothstep(0.82, 1.0, shade) * 0.8);
	ALBEDO = colour * (0.82 + 0.3 * fract(shade * 7.31));
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 0.88;
	SPECULAR = 0.2;
}
