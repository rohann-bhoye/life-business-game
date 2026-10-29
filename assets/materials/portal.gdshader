shader_type spatial;
// The Darwaza gate's swirl: a slow spiral of light inside the stone ring, fading at
// its rim. `open` fades it in (1) and out (0).
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 inner : source_color = vec4(0.55, 0.9, 1.0, 1.0);
uniform vec4 outer : source_color = vec4(0.3, 0.2, 0.85, 1.0);
uniform float open : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 5.0 + r * 11.0 - TIME * 2.2) * 0.5 + 0.5;
	float edge = 1.0 - smoothstep(0.82, 1.0, r);
	vec3 colour = mix(outer.rgb, inner.rgb, clamp(swirl * (1.0 - r) + 0.3 * (1.0 - r), 0.0, 1.0));
	ALBEDO = colour * (0.5 + 0.7 * swirl) * edge * open;
}
