extends SceneTree

# Bakes the editor-only town preview (editor_preview.gd shows it in the editor).
# The game builds its town from scripts at runtime, so the editor alone shows bare
# ground. This runs the world once on High graphics, copies every visible mesh,
# multimesh and 3D label the scripts made (with its world transform, no scripts or
# collisions) and saves them as res://editor_preview/town_preview.scn. Moving things
# (player, traffic, walkers, customers) and the UI are left out.
# Run after visual changes: Godot --path . --script res://tools/bake_editor_preview.gd
const OUT := "res://editor_preview/town_preview.scn"
const SKIP := ["Ui", "Player", "Traffic", "StreetLife", "CustomerSpawner"]

func _initialize() -> void:
	call_deferred("_bake")

func _bake() -> void:
	var save := OS.get_environment("TEMP").path_join("preview_bake_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = save
	var packed := PackedScene.new()
	packed.pack(fixture)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	var world := current_scene
	world.get_node("Shop/ShopArea").business.save_path = ""
	var settings = preload("res://game_settings.gd").new()
	settings.graphics = 2
	settings.apply_graphics(world)
	# Deferred builders (farm, grass) need a few frames.
	for frame in range(10): await process_frame
	var preview := Node3D.new()
	preview.name = "TownPreview"
	# The scene as saved (never added to the tree, so no scripts ran). Original parts
	# the game hides, empties, moves, repaints or relabels at runtime are listed so the
	# editor preview hides them; the ones still shown get a runtime copy like the rest.
	var saved: Node = load("res://main.tscn.tscn").instantiate()
	var replaced: Array[String] = []
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		var original := _original(node, world)
		if _skipped(node, world, original): continue
		if original:
			var twin := saved.get_node_or_null(world.get_path_to(node)) as GeometryInstance3D
			if twin == null or not _changed(twin, node): continue
			replaced.append(str(world.get_path_to(node)))
		if not node.is_visible_in_tree() or _uses_viewport(node): continue
		if not (node is MeshInstance3D or node is MultiMeshInstance3D or node is Label3D or node is Sprite3D): continue
		var copy: GeometryInstance3D = node.duplicate(0)
		for child in copy.get_children():
			copy.remove_child(child)
			child.free()
		if copy is MeshInstance3D:
			copy.skeleton = NodePath()
			copy.skin = null
		copy.name = "%s%d" % [node.name, preview.get_child_count()]
		copy.transform = node.global_transform
		preview.add_child(copy)
		copy.owner = preview
	preview.set_meta("replaced_originals", replaced)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var scene := PackedScene.new()
	assert(scene.pack(preview) == OK)
	assert(ResourceSaver.save(scene, OUT, ResourceSaver.FLAG_COMPRESS) == OK)
	print("BAKED %d nodes into %s; %d original parts replaced: %s" % [preview.get_child_count(), OUT, replaced.size(), ", ".join(replaced)])
	saved.free()
	preview.free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save + suffix): DirAccess.remove_absolute(save + suffix)
	quit()

## Saved in main.tscn (or a scene it instances), so the editor shows it already.
func _original(node: Node, world: Node) -> bool:
	var owner := node.owner
	while owner != null:
		if owner == world: return true
		owner = owner.owner
	return false

## Moving things and the UI. Original parts are only skipped under the player (its
## capsule marks the spawn in the editor) and the UI.
func _skipped(node: Node, world: Node, original: bool) -> bool:
	var parent := node
	while parent != null and parent != world:
		if parent.name in ["Ui", "Player"]: return true
		if not original and (parent.name in SKIP or str(parent.name).begins_with("Customer")): return true
		parent = parent.get_parent()
	return false

func _changed(saved: GeometryInstance3D, live: GeometryInstance3D) -> bool:
	if saved.visible != live.visible or not saved.transform.is_equal_approx(live.transform): return true
	if saved.material_override != live.material_override: return true
	if saved is MeshInstance3D and saved.mesh != live.mesh: return true
	return saved is Label3D and saved.text != live.text

## The shop PC screen draws a live SubViewport, which has no meaning in the editor.
func _uses_viewport(node: GeometryInstance3D) -> bool:
	var materials: Array = [node.material_override]
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			materials.append(node.get_surface_override_material(surface))
			materials.append(node.mesh.surface_get_material(surface))
	for material in materials:
		if material is BaseMaterial3D and (material.albedo_texture is ViewportTexture or material.emission_texture is ViewportTexture): return true
	return false
