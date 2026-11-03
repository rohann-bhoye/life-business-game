shader_type spatial;
render_mode cull_disabled;

// Car body paint with a livery (drivable_car.gd _livery). The pattern is drawn in the body
// mesh's own space (box_pos/box_size are its bounds), so it fits every car of the pack:
//   0 plain   1 twin racing stripes over bonnet, roof and boot   2 two-tone (roof colour)
//   3 a band along both sides
uniform vec4 base : source_color = vec4(0.8, 0.1, 0.1, 1.0);
uniform vec4 second : source_color = vec4(1.0);
uniform int pattern = 0;
uniform vec3 box_pos;
uniform vec3 box_size = vec3(1.0);
varying vec3 local;

void vertex() {
	local = (VERTEX - box_pos) / box_size;
}

void fragment() {
	float side = abs(local.x - 0.5) * 2.0;
	float mark = 0.0;
	if (pattern == 1) mark = step(0.07, side) * step(side, 0.2);
	else if (pattern == 2) mark = step(0.6, local.y);
	else if (pattern == 3) mark = step(0.8, side) * step(0.36, local.y) * step(local.y, 0.46);
	ALBEDO = mix(base.rgb, second.rgb, mark);
	METALLIC = 0.35;
	ROUGHNESS = 0.25;
	SPECULAR = 0.65;
	RIM = 0.2;
	RIM_TINT = 0.5;
}
