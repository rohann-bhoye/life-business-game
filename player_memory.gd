extends Node

# Remembers where the player stood (a small file beside the save) so the next session starts
# on the same spot, and lets U (or the controller's Back button) pull a stuck player out to
# the nearest free ground.

const SAVE_EVERY := 3.0
const RING_STEPS := 16
const Edge := preload("res://town_boundary.gd")

var player: CharacterBody3D
var ui: Node
var since_save := 0.0
var restored := false
var last_free: Vector3
## Where the game started you (in the city): the way back when you are outside the map.
var spawn_point: Vector3

func _ready() -> void:
	ui = get_parent()
	player = ui.player
	last_free = player.global_position
	spawn_point = player.global_position
	# One frame later, so the world is built and the save path is known.
	await get_tree().process_frame
	await get_tree().process_frame
	_restore()

func _pos_path() -> String:
	var path: String = ui.shop.business.save_path
	return "" if path.is_empty() else path + ".pos"

func _restore() -> void:
	restored = true
	var path := _pos_path()
	if path.is_empty() or not FileAccess.file_exists(path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.has("x") or not data.has("y") or not data.has("z"): return
	var spot := Vector3(float(data.x), float(data.y), float(data.z))
	if not spot.is_finite() or _outside_map(spot) or spot.y > 200.0: return
	player.global_position = spot + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.rotation.y = float(data.get("yaw", player.rotation.y))
	last_free = player.global_position

func _save() -> void:
	var path := _pos_path()
	# Not while underground (the cave sits far below the town) or while a menu is open.
	if not restored or path.is_empty() or ui.has_meta("underground") or player.flying: return
	var spot: Vector3 = player.global_position
	# Never remember a spot outside the map: the next start would trap you there.
	if _outside_map(spot): return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"x": spot.x, "y": spot.y, "z": spot.z, "yaw": player.rotation.y}))

func _process(delta: float) -> void:
	since_save += delta
	if since_save >= SAVE_EVERY:
		since_save = 0.0
		_save()
		if not ui.has_meta("underground") and not _outside_map(player.global_position) and _is_free(player.global_position): last_free = player.global_position

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE: _save()

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U
	pressed = pressed or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK)
	if pressed and not player._menu_is_open():
		unstuck()
		get_viewport().set_input_as_handled()

func _shape() -> Shape3D:
	for child in player.get_children():
		if child is CollisionShape3D and child.shape != null: return child.shape
	return null

## How far the player's origin is above their feet (half the body).
func _stand_height() -> float:
	var shape := _shape()
	if shape is CapsuleShape3D: return (shape as CapsuleShape3D).height * 0.5
	if shape is BoxShape3D: return (shape as BoxShape3D).size.y * 0.5
	return 1.0

## True when the player's body fits at `at` without touching anything.
func _is_free(at: Vector3) -> bool:
	var shape := _shape()
	if shape == null: return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.05, 0))
	query.collision_mask = player.collision_mask if not player.flying else player.fly_layers.y
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

## Moves the player to the nearest free standing spot: rings of growing radius, dropping to
## the ground on each; falls back to the last spot known to be free.
## True beyond the land (town, hills, the North Road) or when fallen below the ground.
func _outside_map(spot: Vector3) -> bool:
	return spot.y < -3.0 or spot.x < Edge.LAND_MIN_X or spot.x > Edge.LAND_MAX_X or spot.z < Edge.LAND_MIN_Z or spot.z > Edge.LAND_MAX_Z

func unstuck() -> void:
	if _outside_map(player.global_position) and not ui.has_meta("underground"):
		last_free = spawn_point
		_move_to(spawn_point + Vector3(0, 0.3, 0), "You were outside the map: back in the city.")
		return
	if ui.has_meta("underground"):
		ui.show_feedback("Use the stairs or E at the exit to leave the cave.")
		return
	var origin: Vector3 = player.global_position
	var space := player.get_world_3d().direct_space_state
	# Flying turns the player's own collision off: test against the walking layers.
	var mask: int = player.fly_layers.y if player.flying else player.collision_mask
	for radius in [1.0, 2.0, 3.5, 5.0, 8.0, 12.0]:
		for step in RING_STEPS:
			var angle := TAU * step / RING_STEPS
			var probe: Vector3 = origin + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
			# Down from chest height, under any ceiling: from higher up the ray landed on the
			# roof of the shop or warehouse and "unstuck" put you on top of the building.
			var ray := PhysicsRayQueryParameters3D.create(probe + Vector3(0, 1.4, 0), probe + Vector3(0, -8.0, 0), mask, [player.get_rid()])
			var hit := space.intersect_ray(ray)
			if hit.is_empty(): continue
			# The body is centred on the player's origin: stand it on the ground, not in it.
			var spot: Vector3 = hit.position + Vector3(0, _stand_height() + 0.05, 0)
			if _is_free(spot): return _move_to(spot, "Unstuck: moved you nearby.")
	_move_to(last_free + Vector3(0, 0.3, 0), "Unstuck: back to your last free spot.")

func _move_to(spot: Vector3, message: String) -> void:
	player.global_position = spot
	player.velocity = Vector3.ZERO
	ui.show_feedback(message)
