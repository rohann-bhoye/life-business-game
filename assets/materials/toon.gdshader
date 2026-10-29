shader_type spatial;
// Anime cel shading for the dungeon (Gufa Darwaza): light falls in three flat bands
// (lit, half, shadow) and the shadow side keeps the floor's ambient tint from the
// environment, never black. A soft rim on the edges facing away from the camera.
render_mode specular_disabled;

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 rim_color : source_color = vec4(0.75, 0.85, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
	ROUGHNESS = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color.rgb * rim * rim_strength * ALBEDO + glow.rgb;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float band = smoothstep(0.0, 0.06, facing) * 0.55 + smoothstep(0.45, 0.51, facing) * 0.45;
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
