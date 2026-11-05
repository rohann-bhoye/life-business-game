shader_type spatial;
// real_detail.gdshaderinc, light version for the Low preset: one projection, plain mipmaps,
// no roughness map (the full version ran Surya Nagri at 20 FPS on an MX110).
#define LIGHT_VERSION
#include "res://assets/materials/real_detail.gdshaderinc"

void fragment() {
	vec3 albedo; float metallic; float roughness; float ao; vec3 normal_map;
	shade(UV, albedo, metallic, roughness, ao, normal_map);
	ALBEDO = albedo;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	NORMAL_MAP = normal_map;
	NORMAL_MAP_DEPTH = normal_strength * detail_strength;
}
