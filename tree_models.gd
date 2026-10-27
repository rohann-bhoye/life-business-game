extends RefCounted

# The Blender trees (tools/blender/build_trees.py) as plain meshes, for MultiMeshes:
# pine_tree (the hill forest) and neem_tree (the town's shade trees).
static func mesh(model: String) -> Mesh:
	var scene := (load("res://assets/props/trees/%s.glb" % model) as PackedScene).instantiate()
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	var result: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	scene.free()
	return result
