shader_type spatial;
render_mode cull_disabled;
varying vec2 water_uv;
void vertex() {
 water_uv = VERTEX.xz;
 VERTEX.y += sin(VERTEX.x * 3.2 + TIME * 1.4) * 0.018 + cos(VERTEX.z * 4.0 + TIME * 1.1) * 0.015;
}
void fragment() {
 float ripple = sin(water_uv.x * 6.0 + water_uv.y * 4.0 - TIME * 2.0) * 0.65 + sin(water_uv.x * 2.8 - water_uv.y * 7.0 + TIME * 1.3) * 0.35;
 ALBEDO = mix(vec3(0.07,0.28,0.32), vec3(0.14,0.38,0.42), ripple * 0.5 + 0.5);
 ROUGHNESS = 0.24;
 METALLIC = 0.25;
 NORMAL = normalize(vec3(ripple * 0.12, 0.0, 1.0));
}
