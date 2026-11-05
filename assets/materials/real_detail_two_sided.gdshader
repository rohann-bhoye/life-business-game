shader_type spatial;
// real_detail.gdshaderinc for thin kit pieces seen from both sides (palm fronds, flags).
render_mode cull_disabled;
#include "res://assets/materials/real_detail.gdshaderinc"

void fragment() {
	vec3 albedo; float metallic; float roughness; float ao; vec3 normal_map;
	shade(UV, albedo, metallic, roughness, ao, normal_map);
	ALBEDO = albedo;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	NORMAL_MAP = normal_map;
	NORMAL_MAP_DEPTH = normal_strength * detail_strength;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
