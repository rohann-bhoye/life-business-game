extends SceneTree

# Exports the whole game layout (every building, road, prop, tree and the hills) to one .glb so it
# can be opened in Blender: Godot --headless --path . --script res://tools/export_layout.gd
# Then: blender --background --factory-startup --python tools/blender/import_layout.gd.py
const OUT := "res://assets/layout/game_layout.glb"
const TERRAIN_STEP := 2

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://main.tscn.tscn").instantiate()
	main.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("export_layout_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(main) == OK)
	main.free()
	change_scene_to_packed(packed)
	await scene_changed
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	var landscape = current_scene.get_node("Landscape")
	landscape.set_camera(camera)
	for i in range(30): await process_frame
	var layout := Node3D.new()
	layout.name = "GameLayout"
	_copy(current_scene, layout)
	print("NODES ", layout.find_children("*", "", true, false).size())
	layout.add_child(_terrain(landscape.data))
	layout = _merge(layout)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/layout"))
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(layout, state)
	if err == OK: err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT))
	print("EXPORT ", error_string(err), " ", OUT)
	quit()

## A visible-meshes-only copy of the scene's tree (transforms kept): no UI, lights, scripts or colliders.
func _copy(source: Node, parent: Node3D) -> void:
	for child in source.get_children():
		if child is Node3D:
			if not child.visible or child is Camera3D or child is Light3D or child.name == "Landscape": continue
			var copy: Node3D
			if child is MeshInstance3D and child.mesh != null:
				copy = MeshInstance3D.new()
				copy.mesh = child.mesh
				copy.material_override = child.material_override
				if copy.material_override is ShaderMaterial: copy.material_override = null
			elif child is MultiMeshInstance3D:
				copy = MultiMeshInstance3D.new()
				copy.multimesh = child.multimesh
			elif child is Label3D or child is CollisionObject3D or child is GPUParticles3D:
				continue
			else:
				copy = Node3D.new()
			copy.name = child.name
			copy.transform = child.transform
			parent.add_child(copy)
			_copy(child, copy)

## Blender has no multimesh: lay every instance out as its own mesh node.
func _unfold_multimeshes(root_node: Node) -> void:
	for node in root_node.find_children("*", "MultiMeshInstance3D", true, false):
		var multimesh: MultiMesh = node.multimesh
		if multimesh == null or multimesh.mesh == null or multimesh.instance_count > 800: continue  # grass and the like stay out
		for i in range(multimesh.instance_count):
			var item := MeshInstance3D.new()
			item.name = "%s_%d" % [node.name, i]
			item.mesh = multimesh.mesh
			item.transform = multimesh.get_instance_transform(i)
			node.add_child(item)
		node.multimesh = null

## The baked Terrain3D hills as one coloured mesh, a point every TERRAIN_STEP metres.
func _terrain(data) -> MeshInstance3D:
	var x0 := -128
	var x1 := 127
	var z0 := -256
	var z1 := 127
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := (x1 - x0) / TERRAIN_STEP
	var rows := (z1 - z0) / TERRAIN_STEP
	var points := []
	for r in range(rows + 1):
		for c in range(cols + 1):
			var p := Vector3(x0 + c * TERRAIN_STEP, 0, z0 + r * TERRAIN_STEP)
			var h: float = data.get_height(p)
			if is_nan(h): h = 0.0
			var colour: Color = data.get_color(p)
			if colour.a == 0.0 and colour.r == 0.0: colour = Color(0.25, 0.4, 0.15)
			colour.a = 1.0
			points.append([Vector3(p.x, h, p.z), colour])
	for r in range(rows):
		for c in range(cols):
			var a: Array = points[r * (cols + 1) + c]
			var b: Array = points[r * (cols + 1) + c + 1]
			var d: Array = points[(r + 1) * (cols + 1) + c]
			var e: Array = points[(r + 1) * (cols + 1) + c + 1]
			for tri in [[a, b, d], [b, e, d]]:
				for v in tri:
					st.set_color(v[1])
					st.add_vertex(v[0])
	st.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Terrain"
	mesh_instance.mesh = st.commit()
	mesh_instance.material_override = material
	return mesh_instance

## One mesh per material for the whole layout (a Blender-friendly object count): every mesh
## and every multimesh instance is baked at its place in the world.
func _merge(layout: Node3D) -> Node3D:
	var builders := {}
	var materials := {}
	_collect(layout, Transform3D.IDENTITY, builders, materials)
	var merged := Node3D.new()
	merged.name = "GameLayout"
	var index := 0
	for key in builders:
		var st: SurfaceTool = builders[key]
		var item := MeshInstance3D.new()
		item.name = "Layout_%d" % index
		index += 1
		item.mesh = st.commit()
		item.material_override = materials[key]
		merged.add_child(item)
	return merged

func _collect(node: Node, parent_xf: Transform3D, builders: Dictionary, materials: Dictionary) -> void:
	for child in node.get_children():
		var xf: Transform3D = parent_xf
		if child is Node3D: xf = parent_xf * child.transform
		if child is MeshInstance3D and child.mesh != null:
			_add_mesh(child.mesh, xf, child.material_override, builders, materials)
		elif child is MultiMeshInstance3D and child.multimesh != null and child.multimesh.mesh != null and child.multimesh.instance_count <= 800:
			for i in range(child.multimesh.instance_count):
				_add_mesh(child.multimesh.mesh, xf * child.multimesh.get_instance_transform(i), null, builders, materials)
		_collect(child, xf, builders, materials)

func _add_mesh(mesh: Mesh, xf: Transform3D, override: Material, builders: Dictionary, materials: Dictionary) -> void:
	for s in range(mesh.get_surface_count()):
		var material: Material = override if override != null else mesh.surface_get_material(s)
		if material is ShaderMaterial: material = null
		var key: int = material.get_instance_id() if material != null else 0
		if not builders.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			builders[key] = st
			materials[key] = material
		var single := ArrayMesh.new()
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES: continue
		single.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s))
		if single.get_surface_count() > 0: builders[key].append_from(single, 0, xf)
