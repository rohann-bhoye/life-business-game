extends RefCounted

# Draw distances for everything the scripts built, so the GPU only draws what can
# be seen: the GL Compatibility renderer draws every object in front of the camera
# (thousands of small boxes and props in the town), which made a low-end GPU slow.
# Run once after the town is built (environment_details.gd, after the grass). Each
# mesh, multimesh or 3D label gets a draw distance from its size, and small things
# stop casting shadows. Things that already have a draw distance keep it.
const RANGES := [[0.6, 30.0], [1.5, 50.0], [4.0, 90.0], [10.0, 160.0]]
const NO_SHADOW_BELOW := 1.0

static func apply(world: Node) -> int:
	var changed := 0
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		var item := node as GeometryInstance3D
		if item.visibility_range_end > 0.0 or not item.is_inside_tree(): continue
		var size := item.global_transform.basis.get_scale() * item.get_aabb().size
		var longest := maxf(absf(size.x), maxf(absf(size.y), absf(size.z)))
		if longest <= 0.0: continue
		if longest < NO_SHADOW_BELOW: item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for step in RANGES:
			if longest < step[0]:
				item.visibility_range_end = step[1]
				item.visibility_range_end_margin = step[1] * 0.1
				changed += 1
				break
	return changed
