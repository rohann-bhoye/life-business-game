extends Node3D

# Edge of the open town (the solid walls are in neighbourhood.gd).
# A see-through blue barrier marks it (always faintly visible) and brightens as the
# player comes close. Pushing against it starts a 3-2-1 countdown, then the player
# is sent home: the land beyond opens with later updates. Stepping back from the
# edge cancels the countdown.
## The whole flat land round the old 64 m town is open now: the market street and
## houses (town_expansion.gd) and the airport south of the warehouse (export_world.gd).
const MIN_X := -72.0
const MAX_X := 72.0
const MIN_Z := -52.0
const MAX_Z := 68.0
const HEIGHT := 4.0
const WARN_DISTANCE := 2.0
const FADE_DISTANCE := 14.0
const COUNTDOWN := 3.0

var player: Node3D
var walls: Array[MeshInstance3D] = []
var material: StandardMaterial3D
var notice: Label
var remaining := -1.0

func build(neighbourhood: Node3D) -> void:
	name = "TownBoundary"
	player = neighbourhood.get_parent().get_node_or_null("Player")
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.0))
	gradient.set_color(1, Color(1, 1, 1, 1.0))
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2(0, 0)
	fade.fill_to = Vector2(0, 1)
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = fade
	material.albedo_color = Color(0.35, 0.75, 1.0, 0.12)
	var centre := Vector2((MIN_X + MAX_X) / 2.0, (MIN_Z + MAX_Z) / 2.0)
	var width := MAX_X - MIN_X
	var depth := MAX_Z - MIN_Z
	for side in [[Vector3(MIN_X, 0, centre.y), depth, PI / 2], [Vector3(MAX_X, 0, centre.y), depth, PI / 2], [Vector3(centre.x, 0, MIN_Z), width, 0.0], [Vector3(centre.x, 0, MAX_Z), width, 0.0]]:
		var wall := MeshInstance3D.new()
		wall.name = "BarrierWall%d" % walls.size()
		var quad := QuadMesh.new()
		quad.size = Vector2(side[1], HEIGHT)
		wall.mesh = quad
		wall.material_override = material
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wall.position = side[0] + Vector3(0, 0.1 + HEIGHT / 2.0, 0)
		wall.rotation.y = side[2]
		add_child(wall)
		walls.append(wall)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	notice = Label.new()
	notice.name = "BoundaryNotice"
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.offset_top = 120
	notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	notice.add_theme_font_size_override("font_size", 26)
	notice.add_theme_color_override("font_color", Color.WHITE)
	notice.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.2))
	notice.add_theme_constant_override("outline_size", 8)
	notice.hide()
	layer.add_child(notice)

func distance_to_edge(point: Vector3) -> float:
	return minf(minf(point.x - MIN_X, MAX_X - point.x), minf(point.z - MIN_Z, MAX_Z - point.z))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	var distance := distance_to_edge(player.global_position)
	material.albedo_color.a = maxf(0.12, clampf(1.0 - distance / FADE_DISTANCE, 0.0, 1.0) * 0.6)
	if distance > WARN_DISTANCE:
		if remaining >= 0.0:
			remaining = -1.0
			notice.hide()
		return
	if remaining < 0.0: remaining = COUNTDOWN
	remaining -= delta
	notice.text = "This area opens in a future update\nReturning home in %d..." % maxi(1, ceili(remaining))
	notice.show()
	if remaining <= 0.0: send_home()

func send_home() -> void:
	remaining = -1.0
	notice.hide()
	var house = get_tree().current_scene.get_node_or_null("House/HouseArea")
	if house != null: house.spawn_player()
	var ui = get_tree().current_scene.get_node_or_null("Ui")
	if ui != null and ui.has_method("show_feedback"): ui.show_feedback("You're back home. New areas open in later updates.")
