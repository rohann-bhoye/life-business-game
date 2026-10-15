extends RefCounted

# Shared helpers for placing licensed Kenney GLB models (see assets/*/kenney/README.md).
const Bounds = preload("res://product_assets.gd")
static var scenes: Dictionary = {}
static var model_bounds: Dictionary = {}
static var meshes: Dictionary = {}

static func scene(path: String) -> PackedScene:
	if not scenes.has(path):
		scenes[path] = load(path) as PackedScene
		var sample: Node3D = scenes[path].instantiate()
		model_bounds[path] = Bounds._bounds(sample, Transform3D.IDENTITY)
		sample.free()
	return scenes[path]

## Instances a model scaled uniformly to fit inside `size`, resting on `position`.
static func fit(parent: Node3D, node_name: String, path: String, size: Vector3, position: Vector3, yaw := 0.0) -> Node3D:
	var model: Node3D = scene(path).instantiate()
	var box: AABB = model_bounds[path]
	var factor := minf(size.x / box.size.x, minf(size.y / box.size.y, size.z / box.size.z))
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = position
	holder.rotation.y = yaw
	holder.scale = Vector3.ONE * factor
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	holder.add_child(model)
	parent.add_child(holder)
	return holder

## Scales a model so its height is `height` metres and returns that factor.
static func height_factor(path: String, height: float) -> float:
	scene(path)
	return height / maxf(model_bounds[path].size.y, 0.001)

## The model's single mesh with its local offset baked in, for MultiMesh batching.
static func batch_mesh(path: String) -> Dictionary:
	if not meshes.has(path):
		var root: Node3D = scene(path).instantiate()
		var found := root.find_children("*", "MeshInstance3D", true, false)
		var instance: MeshInstance3D = found[0]
		var offset := Transform3D.IDENTITY
		var node: Node = instance
		while node != root and node is Node3D:
			offset = (node as Node3D).transform * offset
			node = node.get_parent()
		var box: AABB = model_bounds[path]
		offset = Transform3D(Basis.IDENTITY, -Vector3(box.get_center().x, box.position.y, box.get_center().z)) * offset
		meshes[path] = {"mesh": instance.mesh, "offset": offset}
		root.free()
	return meshes[path]

## Draws many copies of one model in a single draw call.
static func batch(parent: Node3D, node_name: String, path: String, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var info := batch_mesh(path)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = info.mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index] * info.offset)
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	parent.add_child(instance)
	return instance
