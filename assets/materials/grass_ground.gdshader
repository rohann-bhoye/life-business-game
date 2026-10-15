shader_type spatial;
varying vec2 ground_uv;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
void vertex() { ground_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
 float patch = noise(ground_uv * 0.25);
 float blade = noise(ground_uv * vec2(65.0, 13.0));
 ALBEDO = mix(vec3(0.19,0.29,0.11), vec3(0.32,0.45,0.2), patch) * (0.8 + blade * 0.35);
 ROUGHNESS = 0.98;
}
