shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// A soft dark pool on the floor around a fixture's footprint (a cheap stand-in for
// ambient occlusion on the Compatibility renderer). The quad is footprint + 2 * margin.
uniform vec2 half_size = vec2(0.5, 0.5);
uniform float margin = 0.3;
uniform float strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 p = (UV - 0.5) * (half_size * 2.0 + vec2(margin * 2.0));
	vec2 q = abs(p) - half_size;
	float d = length(max(q, vec2(0.0)));
	ALBEDO = vec3(0.03, 0.04, 0.06);
	ALPHA = strength * (1.0 - smoothstep(0.0, margin, d));
}
