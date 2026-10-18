@tool
extends Node3D

# Editor-only preview of the town the game builds from scripts at runtime (Indian
# houses, shop interior, home and yard, street props, farm, grass, signs). In the
# Godot editor it shows the baked res://editor_preview/town_preview.scn so the scene
# view looks like the game; the preview is never saved into main.tscn (no owner).
# In the game this node removes itself at once: the scripts build the real town.
# Re-bake after visual changes: Godot --path . --script res://tools/bake_editor_preview.gd
const PREVIEW := "res://editor_preview/town_preview.scn"

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	if not ResourceLoader.exists(PREVIEW): return
	var preview: Node = load(PREVIEW).instantiate()
	add_child(preview)
	_hide_replaced.call_deferred(preview.get_meta("replaced_originals", []))

## Original parts the game hides, empties or replaces at runtime (old house walls,
## the placeholder shop box, the white ground...): only their render instances are
## hidden, so the nodes and the saved scene stay exactly as they are.
func _hide_replaced(paths: Array) -> void:
	var root := owner if owner != null else get_parent()
	for path in paths:
		var node := root.get_node_or_null(NodePath(path)) as VisualInstance3D
		if node != null: RenderingServer.instance_set_visible(node.get_instance(), false)
