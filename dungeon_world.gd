extends Node3D

# Gufa Darwaza, the dungeon of Dholkarpur Gaon. Its cave mouth (Blender,
# tools/blender/build_cave_entrance.py) sits on the west hill, facing the town, on
# ground land_shape.gd levels for it. Inside the mouth is the Darwaza: a stone ring
# whose swirl (portal.gdshader) glows while the gate is open. The gate opens by the
# clock (FLOORS); press E at it to go down. The floors are built far off the land
# (UNDER, dungeon_floor.gd) and only while the player is down there: the town is
# hidden, the camera sees only the cave and day_night.gd swaps the sky for the floor's
# cave light. Treasure found on a trip is banked on the way out (business_backend.gd
# bring_up_treasure) and sold at the Darwaza Guild. Press E at the entry stone to come
# back up; if the gate shuts meanwhile, the player is sent up with their finds.
# Co-op games keep the gate shut for now. On the way up to the cave stands the
# Darwaza Guild office (tools/blender/build_guild_office.py): its clerk buys all the
# treasure held (business_backend.gd sell_treasure) and its notice board lists the
# gate times. Created by shop_operations.gd, which passes E and the hint through.
const LandShape := preload("res://land_shape.gd")
const CAVE_YAW := PI / 2.0
const UNDER := Vector3(1000.0, 0.0, 0.0)
const PORTAL := Vector3(0.0, 2.15, -2.98)
const REACH := 2.8
const UNDERGROUND_FAR := 150.0
## Floor, rank, open window in minutes of the day (end may pass midnight), the cave
## light, and on which days (every 7th for Agni Mandir).
const FLOORS := [
	{"name": "Jugnu Gufa", "rank": "E", "open": 360, "close": 1320, "every": 1, "treasure": "jar",
		"background": Color(0.06, 0.09, 0.12), "ambient": Color(0.5, 0.68, 0.85), "ambient_energy": 1.0, "fog_density": 0.018},
	{"name": "Neelam Mahal", "rank": "C", "open": 1080, "close": 120, "every": 1, "treasure": "shard",
		"background": Color(0.05, 0.04, 0.11), "ambient": Color(0.55, 0.5, 0.9), "ambient_energy": 0.95, "fog_density": 0.016},
	{"name": "Agni Mandir", "rank": "A", "open": 1200, "close": 240, "every": 7, "treasure": "coin",
		"background": Color(0.1, 0.04, 0.03), "ambient": Color(0.9, 0.55, 0.45), "ambient_energy": 0.95, "fog_density": 0.016},
]

var ops: Node
var business
var player: CharacterBody3D
var cave: Node3D
var portal_material: ShaderMaterial
var portal_light: OmniLight3D
var board_label: Label3D
var flames: Array[MeshInstance3D] = []
var fade: ColorRect
var underground_floor := -1
var floor_root: Node3D
var hidden: Array[Node3D] = []
var town_far := 4000.0
var exit_point := Vector3.ZERO
var busy := false
## Treasure found on this trip, by kind (dungeon_store.gd).
var finds := {}
var monsters: Array[Node3D] = []
var hud: Label
var guild: Node3D
const GUILD_COUNTER := Vector3(0.0, 1.4, -0.5)

func _ready() -> void:
	name = "DungeonWorld"
	business = get_tree().current_scene.get_node("Shop/ShopArea").business
	player = get_tree().current_scene.get_node("Player")
	_build_cave()
	_build_guild()
	_build_fade()
	business.clock_changed.connect(_update_gate)
	_update_gate()

## Which floors are open now (indices into FLOORS), shallowest first.
func open_floors() -> Array[int]:
	var result: Array[int] = []
	var minute := int(business.minutes_of_day)
	for index in range(FLOORS.size()):
		var entry: Dictionary = FLOORS[index]
		var wraps: bool = entry.close < entry.open
		var day: int = business.day
		var open := false
		if not wraps:
			open = minute >= entry.open and minute < entry.close and day % entry.every == 0
		elif minute >= entry.open:
			open = day % entry.every == 0
		elif minute < entry.close:
			open = (day - 1) % entry.every == 0
		if open: result.append(index)
	return result

func gate_open() -> bool:
	return not open_floors().is_empty() and get_tree().current_scene.get_node_or_null("CoopWorld") == null

func _build_cave() -> void:
	cave = (load("res://assets/props/dungeon/cave_mouth.glb") as PackedScene).instantiate() as Node3D
	cave.name = "CaveMouth"
	cave.position = Vector3(LandShape.CAVE_X, LandShape.CAVE_FLOOR, LandShape.CAVE_Z)
	cave.rotation.y = CAVE_YAW
	add_child(cave)
	var ring := (load("res://assets/props/dungeon/gate_ring.glb") as PackedScene).instantiate() as Node3D
	ring.name = "GateRing"
	ring.position = PORTAL + Vector3(0, 0, -0.02)
	cave.add_child(ring)
	var swirl := MeshInstance3D.new()
	swirl.name = "Swirl"
	var quad := QuadMesh.new()
	quad.size = Vector2(3.2, 3.2)
	swirl.mesh = quad
	portal_material = ShaderMaterial.new()
	portal_material.shader = preload("res://assets/materials/portal.gdshader")
	swirl.material_override = portal_material
	swirl.position = PORTAL
	swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cave.add_child(swirl)
	portal_light = OmniLight3D.new()
	portal_light.name = "GateGlow"
	portal_light.light_color = Color(0.45, 0.8, 1.0)
	portal_light.omni_range = 7.0
	portal_light.position = PORTAL + Vector3(0, 0, 1.2)
	cave.add_child(portal_light)
	# Solid rock: the tunnel floor and walls, the flanks and the gate plane.
	for part in [[Vector3(4.4, 0.2, 3.6), Vector3(0, -0.1, -1.6)], [Vector3(1.2, 6.0, 3.6), Vector3(-2.6, 3.0, -1.6)], [Vector3(1.2, 6.0, 3.6), Vector3(2.6, 3.0, -1.6)],
			[Vector3(3.8, 4.6, 0.3), Vector3(0, 2.3, -2.75)], [Vector3(3.2, 6.0, 4.0), Vector3(-4.6, 3.0, -1.2)], [Vector3(3.2, 6.0, 4.0), Vector3(4.6, 3.0, -1.2)],
			[Vector3(0.3, 1.8, 0.3), Vector3(3.6, 0.9, 1.74)]]:
		_body("CaveRock", cave, part[0], part[1])
	# Torch flames either side of the mouth, and the rank on the warning board.
	for side in [-1, 1]:
		var flame := MeshInstance3D.new()
		flame.name = "TorchFlame"
		var sprite := QuadMesh.new()
		sprite.size = Vector2(0.28, 0.42)
		flame.mesh = sprite
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		glow.albedo_color = Color(1.0, 0.66, 0.22)
		flame.material_override = glow
		flame.position = Vector3(side * 2.75, 3.08, 0.6)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cave.add_child(flame)
		flames.append(flame)
	board_label = Label3D.new()
	board_label.name = "GateRank"
	board_label.position = Vector3(3.95, 1.52, 1.63)
	board_label.font_size = 64
	board_label.pixel_size = 0.004
	board_label.outline_size = 0
	board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	board_label.width = 300
	cave.add_child(board_label)

func _build_guild() -> void:
	guild = (load("res://assets/props/dungeon/guild_office.glb") as PackedScene).instantiate() as Node3D
	guild.name = "DarwazaGuild"
	guild.position = Vector3(LandShape.GUILD_X, LandShape.GUILD_FLOOR, LandShape.GUILD_Z)
	add_child(guild)
	_body("GuildWalls", guild, Vector3(9.6, 7.0, 7.0), Vector3(0, 3.5, -3.7))
	_body("GuildPlinth", guild, Vector3(9.6, 0.5, 0.6), Vector3(0, 0.25, -0.1))
	_body("NoticeBoard", guild, Vector3(1.9, 1.8, 0.2), Vector3(-4.0, 0.9, 1.6))
	_body("Crates", guild, Vector3(1.6, 1.2, 0.9), Vector3(3.7, 0.6, 1.2))
	var clerk := Node3D.new()
	clerk.name = "GuildClerk"
	clerk.position = Vector3(0.0, 0.85, -1.5)
	var visual := Node3D.new()
	visual.name = "CharacterVisual"
	visual.set_script(preload("res://character_visual.gd"))
	visual.model = "female-c"
	clerk.add_child(visual)
	guild.add_child(clerk)
	var notice := Label3D.new()
	notice.name = "GateTimes"
	notice.text = "DARWAZA TIMES
Rank E  Jugnu Gufa  06:00-22:00
Rank C  Neelam Mahal  18:00-02:00
Rank A  Agni Mandir  every 7th night
           20:00-04:00"
	notice.position = Vector3(-4.0, 1.45, 1.61)
	notice.font_size = 22
	notice.pixel_size = 0.0034
	notice.outline_size = 0
	notice.modulate = Color(0.18, 0.1, 0.05)
	guild.add_child(notice)

func _near_guild() -> bool:
	return is_instance_valid(guild) and player.global_position.distance_to(guild.to_global(GUILD_COUNTER)) < REACH

func _body(node_name: String, parent: Node3D, size: Vector3, offset: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = offset
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)

func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	fade = ColorRect.new()
	fade.name = "DungeonFade"
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)
	hud = Label.new()
	hud.name = "DungeonHud"
	hud.position = Vector2(16, 44)
	hud.add_theme_font_size_override("font_size", 16)
	hud.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.visible = false
	layer.add_child(hud)

func _update_gate() -> void:
	var floors := open_floors()
	if underground_floor >= 0:
		_update_hud()
		if not busy and not underground_floor in floors:
			_feedback("The Darwaza is closing! You are pulled back up with your treasure.")
			_leave()
	var open := gate_open()
	portal_material.set_shader_parameter("open", 1.0 if open else 0.0)
	portal_light.visible = open
	if get_tree().current_scene.get_node_or_null("CoopWorld") != null:
		board_label.text = "co-op later"
		board_label.modulate = Color(0.2, 0.2, 0.2)
	elif open:
		board_label.text = "%s  OPEN" % FLOORS[floors[floors.size() - 1]].rank
		board_label.modulate = Color(0.1, 0.5, 0.15)
	else:
		board_label.text = "closed - 06:00"
		board_label.modulate = Color(0.7, 0.12, 0.1)

func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0
	for index in range(flames.size()):
		flames[index].scale = Vector3(1.0, 1.0 + sin(time * 9.0 + index * 2.0) * 0.12, 1.0)

func _portal_point() -> Vector3:
	return cave.to_global(PORTAL + Vector3(0, -2.05, 0.6))

## The interaction line shown under the crosshair (shop_operations.gd asks).
func hint() -> String:
	if busy: return ""
	if underground_floor >= 0:
		if player.global_position.distance_to(exit_point) < REACH: return "E - climb back up to the town"
		var found: String = floor_root.hint_at(floor_root.to_local(player.global_position))
		if not found.is_empty(): return found
		if _near_stairs(): return "The stairs down to Neelam Mahal (Rank C) open in a later update"
		return ""
	if _near_guild():
		var worth: int = business.treasure.value()
		return "E - sell your treasure to the Darwaza Guild (%s%d)" % [String.chr(8377), worth] if worth > 0 else "Darwaza Guild: bring treasure from the Darwaza to sell here"
	if not is_instance_valid(cave) or player.global_position.distance_to(_portal_point()) > REACH: return ""
	if get_tree().current_scene.get_node_or_null("CoopWorld") != null: return "The Darwaza stays shut in co-op for now"
	if not gate_open(): return "The Darwaza is shut - it opens at 06:00"
	if _hands_full(): return "Put things down before going into the Darwaza"
	var floor: Dictionary = FLOORS[open_floors()[0]]
	return "E - enter the Darwaza (%s, Rank %s)" % [floor.name, floor.rank]

func try_interact() -> bool:
	if busy: return false
	if underground_floor >= 0:
		if player.global_position.distance_to(exit_point) < REACH:
			_leave()
			return true
		var count: int = floor_root.interact_at(floor_root.to_local(player.global_position))
		if count > 0:
			var kind: String = FLOORS[underground_floor].treasure
			finds[kind] = int(finds.get(kind, 0)) + count
			_feedback("+%d %s (%d this trip)" % [count, preload("res://dungeon_store.gd").ITEMS[kind].name.to_lower(), finds[kind]])
			_update_hud()
			return true
		return _near_stairs()
	if _near_guild():
		var paid: int = business.sell_treasure()
		_feedback("The Darwaza Guild paid %s%d for your treasure." % [String.chr(8377), paid] if paid > 0 else "Bring treasure from the Darwaza to sell here.")
		return true
	if not is_instance_valid(cave) or player.global_position.distance_to(_portal_point()) > REACH: return false
	if not gate_open() or _hands_full(): return true
	_enter(open_floors()[0])
	return true

func _hands_full() -> bool:
	if is_instance_valid(ops) and (ops.holding_bag or ops.shop.business.carried_stock > 0): return true
	if is_instance_valid(ops) and is_instance_valid(ops.export_world) and ops.export_world.holding(): return true
	return false

func _enter(index: int) -> void:
	busy = true
	await _fade_to(1.0)
	underground_floor = index
	for child in get_tree().current_scene.get_children():
		if child is Node3D and child != player and child != self and child.visible:
			child.visible = false
			hidden.append(child)
	cave.visible = false
	var camera: Camera3D = player.camera
	town_far = camera.far
	camera.far = UNDERGROUND_FAR
	var day_night = get_tree().current_scene.get_node_or_null("DayNight")
	if day_night != null and day_night.has_method("set_underground"): day_night.set_underground(FLOORS[index])
	floor_root = preload("res://dungeon_floor.gd").create(index, UNDER)
	add_child(floor_root)
	finds = {}
	exit_point = UNDER + floor_root.get_meta("exit", Vector3.ZERO)
	player.global_position = UNDER + floor_root.get_meta("entry", Vector3(0, 1, 0))
	player.velocity = Vector3.ZERO
	player.rotation.y = floor_root.get_meta("facing", 0.0)
	_spawn_monsters(index)
	_feedback("%s - Rank %s. Find the treasure and keep away from the monsters!" % [FLOORS[index].name, FLOORS[index].rank])
	hud.visible = true
	_update_hud()
	await _fade_to(0.0)
	busy = false

func _leave() -> void:
	busy = true
	await _fade_to(1.0)
	if is_instance_valid(floor_root): floor_root.queue_free()
	business.bring_up_treasure(finds, underground_floor + 1)
	var total := 0
	for kind in finds: total += int(finds[kind])
	if total > 0: _feedback("You brought up %d treasure. Sell it at the Darwaza Guild." % total)
	finds = {}
	hud.visible = false
	underground_floor = -1
	for node in hidden:
		if is_instance_valid(node): node.visible = true
	hidden.clear()
	cave.visible = true
	player.camera.far = town_far
	var day_night = get_tree().current_scene.get_node_or_null("DayNight")
	if day_night != null and day_night.has_method("set_underground"): day_night.set_underground({})
	player.global_position = cave.to_global(Vector3(0, 1.0, 3.2))
	player.velocity = Vector3.ZERO
	player.rotation.y = CAVE_YAW
	await _fade_to(0.0)
	busy = false

## Floor monsters (no weapon yet: they only chase): slimes, bats and mushrooms on the
## S cells, Raja Jelly in the boss chamber, each at a level in its kind's range.
func _spawn_monsters(_index: int) -> void:
	monsters.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var kinds := ["slime", "bat", "mushroom"]
	var spawns: Array[Vector3] = floor_root.spawns
	for number in range(spawns.size()):
		var type: String = kinds[number % kinds.size()]
		var levels: Array = preload("res://monster.gd").KINDS[type].levels
		var monster := preload("res://monster.gd").create(type, rng.randi_range(levels[0], levels[1]), spawns[number], rng.randf() < 0.15, self, player)
		floor_root.add_child(monster)
		monsters.append(monster)
	if floor_root.boss_spot != Vector3.ZERO:
		var boss := preload("res://monster.gd").create("boss", 5, floor_root.boss_spot, false, self, player)
		floor_root.add_child(boss)
		monsters.append(boss)

## A monster caught the player: back to the entry stone, this trip's finds lost.
func caught(monster: Node3D) -> void:
	if busy: return
	busy = true
	await _fade_to(1.0)
	var dropped := 0
	for kind in finds: dropped += int(finds[kind])
	finds = {}
	for other in monsters:
		if is_instance_valid(other): other.reset()
	for jar in floor_root.loot: jar.visible = true
	player.global_position = floor_root.to_global(floor_root.get_meta("entry"))
	player.velocity = Vector3.ZERO
	_feedback("%s caught you!%s" % [monster.data.name, " You dropped %d treasure." % dropped if dropped > 0 else ""])
	_update_hud()
	await _fade_to(0.0)
	busy = false

func _near_stairs() -> bool:
	var stairs: Vector3 = floor_root.get_meta("stairs", Vector3.ZERO)
	return stairs != Vector3.ZERO and floor_root.to_local(player.global_position).distance_to(stairs + Vector3(0, 1, 0)) < REACH

func _update_hud() -> void:
	if underground_floor < 0: return
	var entry: Dictionary = FLOORS[underground_floor]
	var kind: String = entry.treasure
	hud.text = "%s  -  Rank %s
Treasure this trip: %d %s
Gate shuts at %02d:%02d" % [entry.name, entry.rank, int(finds.get(kind, 0)), preload("res://dungeon_store.gd").ITEMS[kind].name.to_lower(), int(entry.close) / 60, int(entry.close) % 60]

func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", alpha, 0.35)
	await tween.finished

func _feedback(text: String) -> void:
	var ui := get_tree().current_scene.get_node_or_null("Ui")
	if ui != null and ui.has_method("show_feedback"): ui.show_feedback(text)
