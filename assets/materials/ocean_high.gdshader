// The sea round the island: see ocean_core.gdshaderinc.
// High: clear shallows over the sand and rocks and sun caustics (alpha blended,
// still writing depth so the land behind sorts right).
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_always;
#define OCEAN_HIGH
#include "res://assets/materials/ocean_core.gdshaderinc"
