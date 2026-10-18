extends RefCounted

# Cement-block paths: rows of square concrete blocks with thin gaps, each block a
# slightly different grey. One straight segment is one merged mesh (one draw call)
# in the "no_grass" group, so environment_details.gd keeps the grass off it.
const IndianHouse := preload("res://indian_house.gd")
const GAP := 0.04
const HEIGHT := 0.06

## Lays a straight path from `start` to `end` (x/z on the ground, along x or along z)
## that is `across` blocks wide, under `parent` as a node named `node_name`. `y` is
## the blocks' centre height in the parent's space (0.12 sits on the town ground).
static func lay(parent: Node3D, node_name: String, start: Vector2, end: Vector2, across := 3, block := 0.38, y := 0.12) -> MeshInstance3D:
	var along_x := absf(end.x - start.x) > absf(end.y - start.y)
	var length := absf(end.x - start.x) if along_x else absf(end.y - start.y)
	var step := block + GAP
	var count := maxi(1, int(round(length / step)))
	var direction := (end - start).normalized()
	var side := Vector2(-direction.y, direction.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(node_name)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(count):
		for lane in range(across):
			var spot := start + direction * (step / 2.0 + index * length / count) + side * (lane - (across - 1) / 2.0) * step
			var shade := rng.randf_range(-0.05, 0.04)
			IndianHouse.box(st, Vector3(spot.x, y, spot.y), Vector3(block, HEIGHT, block), Color(0.67 + shade, 0.66 + shade, 0.62 + shade))
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = st.commit()
	mesh.material_override = IndianHouse._material()
	mesh.add_to_group("no_grass")
	parent.add_child(mesh)
	return mesh
