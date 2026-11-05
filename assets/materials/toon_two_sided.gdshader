shader_type spatial;
// toon.gdshader for thin things seen from both sides (Surya Nagri palm fronds and temple
// flags): no back-face culling, and the back side lights as if it faced the camera.
render_mode specular_disabled, cull_disabled;

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
	ROUGHNESS = 1.0;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}

void light() {
	float facing = dot(NORMAL, LIGHT);
	float band = smoothstep(0.0, 0.06, facing) * 0.55 + smoothstep(0.45, 0.51, facing) * 0.45;
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
