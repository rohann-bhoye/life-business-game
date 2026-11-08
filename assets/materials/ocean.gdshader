// The sea round the island (sagar_point.gd builds the mesh and feeds the sky and sun
// uniforms each half second). Anime look, made for GL Compatibility (no screen or depth
// textures): four Gerstner swells rolling in from the open sea, two scrolling ripple
// normal maps, a toon-banded body colour from turquoise shallows to deep blue, the sky
// reflected by Fresnel, a crisp sun glint with sparkles, white caps on the crests, and
// foam lines that roll in to the beach. The sea-bed depth (metres below the water) is
// baked into each vertex's UV2.x from the land.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 sky_top : source_color = vec3(0.3, 0.52, 0.75);
uniform vec3 sky_horizon : source_color = vec3(0.77, 0.86, 0.9);
uniform vec3 sun_dir = vec3(0.3, 0.6, 0.5);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.87);
uniform float daylight = 1.0;
uniform vec3 deep_color : source_color = vec3(0.02, 0.17, 0.38);
uniform vec3 mid_color : source_color = vec3(0.03, 0.4, 0.6);
uniform vec3 shallow_color : source_color = vec3(0.16, 0.78, 0.74);
uniform vec3 sand_color : source_color = vec3(0.86, 0.8, 0.6);
uniform vec3 foam_color : source_color = vec3(0.96, 0.99, 1.0);
uniform float wave_scale = 1.0;
uniform sampler2D ripples : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;

varying vec3 world;
varying vec2 rest;
varying float depth;
varying float shore_calm;

// One Gerstner swell: moves the vertex (sideways and up) toward its crest.
vec3 gerstner(vec2 p, vec2 dir, float length_m, float steep, float t) {
	float k = 6.2831853 / length_m;
	vec2 d = normalize(dir);
	float f = k * (dot(d, p) - sqrt(9.8 / k) * t);
	float a = steep / k;
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}

// The same swell as a height field for the pixel's normal and crest, faded out when it
// is smaller than a few pixels (no streaks or shimmer far off).
void swell(vec2 p, vec2 dir, float length_m, float steep, float t, float footprint, inout vec2 slope, inout float height) {
	float k = 6.2831853 / length_m;
	vec2 d = normalize(dir);
	float f = k * (dot(d, p) - sqrt(9.8 / k) * t);
	float a = steep / k * (1.0 - smoothstep(0.35, 1.4, k * footprint));
	height += a * sin(f);
	slope += d * a * k * cos(f);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth = UV2.x;
	shore_calm = smoothstep(0.2, 6.0, depth);
	// Vertices only move where the grid is fine enough for the swell (UV2.y: spacing).
	float amp = wave_scale * shore_calm * (1.0 - smoothstep(3.5, 9.0, UV2.y));
	vec3 move = vec3(0.0);
	float t = TIME;
	move += gerstner(w.xz, vec2(0.2, -1.0), 24.0, 0.15 * amp, t);
	move += gerstner(w.xz, vec2(-0.45, -1.0), 13.0, 0.15 * amp, t * 0.9);
	move += gerstner(w.xz, vec2(0.8, -0.55), 7.5, 0.12 * amp, t * 1.1);
	move += gerstner(w.xz, vec2(-0.9, -0.35), 4.2, 0.08 * amp, t);
	VERTEX += move;
	rest = w.xz;
	world = w + move;
}

void fragment() {
	vec3 to_eye = CAMERA_POSITION_WORLD - world;
	float dist = length(to_eye);
	vec3 v = to_eye / dist;
	float near = 1.0 - smoothstep(40.0, 420.0, dist);
	float footprint = length(fwidth(rest)) + 0.02;
	vec2 slope = vec2(0.0);
	float height = 0.0;
	// Patchy swell strength and two extra cross swells break up long even bands.
	float amp = wave_scale * shore_calm * mix(0.3, 1.45, texture(foam_noise, rest * 0.0045 + TIME * 0.002).r);
	swell(rest, vec2(0.2, -1.0), 24.0, 0.15 * amp, TIME, footprint, slope, height);
	swell(rest, vec2(-0.45, -1.0), 13.0, 0.15 * amp, TIME * 0.9, footprint, slope, height);
	swell(rest, vec2(0.8, -0.55), 7.5, 0.12 * amp, TIME * 1.1, footprint, slope, height);
	swell(rest, vec2(-0.9, -0.35), 4.2, 0.08 * amp, TIME, footprint, slope, height);
	swell(rest, vec2(1.0, -0.25), 17.0, 0.1 * amp, TIME * 0.95, footprint, slope, height);
	swell(rest, vec2(-1.0, -0.7), 9.5, 0.1 * amp, TIME * 1.05, footprint, slope, height);
	float crest = height / max(0.05, 1.05 * wave_scale);
	// Ripples: two normal maps drifting different ways, calmer far off (no shimmer).
	vec2 uv_a = world.xz * 0.045 + TIME * vec2(0.011, 0.032);
	vec2 uv_b = world.xz * 0.12 + TIME * vec2(-0.027, 0.017);
	vec2 ripple = (texture(ripples, uv_a).xy - 0.5) + (texture(ripples, uv_b).xy - 0.5) * 0.7;
	ripple *= mix(0.05, 0.55, near * near);
	slope *= mix(0.3, 1.0, near);
	vec3 n = normalize(vec3(-slope.x + ripple.x, 1.0, -slope.y + ripple.y));
	// Light: the sun by day, a dim moon-blue at night.
	vec3 l = normalize(sun_dir);
	float ndl = dot(n, l);
	float lit = mix(0.62, 1.0, smoothstep(0.15, 0.32, ndl));
	// Body colour by depth, banded like a cel-shaded painting.
	float d = depth + crest * 0.6;
	vec3 body = mix(shallow_color, mid_color, smoothstep(0.6, 4.5, d));
	body = mix(body, deep_color, smoothstep(5.0, 26.0, d));
	body = mix(sand_color, body, smoothstep(0.0, 1.1, d));
	// Light through the wave crests (turquoise glow) when looking toward the sun.
	float through = max(dot(-v, l) * 0.5 + 0.5, 0.0);
	body += shallow_color * smoothstep(0.25, 0.85, crest) * through * 0.45;
	body *= (sun_color * lit * 0.85 + sky_top * 0.35) * mix(0.25, 1.0, daylight);
	// Sky reflection by Fresnel, with a soft horizon band.
	vec3 r = reflect(-v, n);
	vec3 sky = mix(sky_horizon, sky_top, smoothstep(0.0, 0.45, r.y));
	float fresnel = 0.03 + 0.97 * pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 5.0);
	fresnel = smoothstep(0.0, 0.85, fresnel);
	vec3 colour = mix(body, sky, fresnel * mix(0.6, 0.85, near));
	// Sun glint: a crisp anime highlight plus scattered sparkles on the ripples.
	float facing = max(dot(r, l), 0.0);
	float glint = smoothstep(0.9965, 0.9985, facing) * 1.6 + pow(facing, 90.0) * 0.5;
	float sparkle_mask = texture(foam_noise, world.xz * 0.35 + TIME * vec2(0.05, -0.04)).r;
	glint += step(0.82, sparkle_mask) * pow(facing, 24.0) * 2.2 * near;
	colour += sun_color * glint * daylight * step(0.0, l.y);
	// White caps on the swell crests, broken up by noise.
	float noise = texture(foam_noise, world.xz * 0.06 + TIME * vec2(0.01, 0.03)).r;
	float caps = smoothstep(0.7, 0.78, crest + noise * 0.45 - 0.2) * near * near;
	// Shore foam: lines rolling in to the beach, and a solid white rim at the waterline.
	float fine = texture(foam_noise, world.xz * 0.2 - TIME * vec2(0.02, 0.05)).r;
	float roll = sin(depth * 2.2 + TIME * 1.7 + noise * 3.0);
	float lines = smoothstep(0.78, 0.9, roll) * (1.0 - smoothstep(0.4, 3.2, depth)) * step(0.35, fine);
	float rim = 1.0 - smoothstep(0.12, 0.45, depth + (fine - 0.5) * 0.35 + sin(TIME * 1.3 + world.x * 0.15) * 0.08);
	float foam = clamp(max(max(caps, lines), rim), 0.0, 1.0);
	colour = mix(colour, foam_color * (sun_color * lit * 0.8 + sky_top * 0.45) * mix(0.3, 1.0, daylight), foam);
	// Distance haze into the sky's horizon colour, so the sea meets the sky softly.
	colour = mix(colour, sky_horizon, smoothstep(250.0, 2600.0, dist) * 0.9);
	ALBEDO = colour;
}
