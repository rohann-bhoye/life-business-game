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
		"background": Color(0.04, 0.06, 0.09), "ambient": Color(0.45, 0.58, 0.72), "ambient_energy": 0.6, "fog_density": 0.018},
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
var audio: Node
var lathi: Node3D
var table: Node3D
var displays: Array[Node3D] = []
var swing_ready := true
var monsters: Array[Node3D] = []
var hud: PanelContainer
var hud_title: Label
var hud_rank: Label
var hud_gate: Label
var hud_treasure_name: Label
var hud_treasure: Label
var hud_drops: Label
var hud_monsters: Label
var guild: Node3D
var reader: CanvasLayer
## The weapons on the table outside the cave: damage per hit, seconds per swing, reach in
## metres. Taking one is saved; you need one to fight below.
const WEAPON_IDS := ["lathi", "talwar", "gada"]
const TABLE_SLOTS := [-0.8, 0.0, 0.8]
const TABLE_AT := Vector3(-3.6, 0.0, 2.4)
const WEAPONS := {
	"lathi": {"name": "Lathi", "damage": 1, "rate": 0.5, "reach": 2.6, "note": "1 damage, fast"},
	"talwar": {"name": "Talwar", "damage": 2, "rate": 0.62, "reach": 2.9, "note": "2 damage, long reach"},
	"gada": {"name": "Gada", "damage": 3, "rate": 1.0, "reach": 2.5, "note": "3 damage, slow and heavy"},
}
const GUILD_COUNTER := Vector3(0.0, 1.4, -0.5)

func _ready() -> void:
	name = "DungeonWorld"
	business = get_tree().current_scene.get_node("Shop/ShopArea").business
	player = get_tree().current_scene.get_node("Player")
	_build_cave()
	_build_guild()
	_build_table()
	_build_fade()
	_build_area_notice()
	reader = preload("res://dungeon_books.gd").new()
	add_child(reader)
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

## The Darwaza (gate, weapon table, Guild counter) waits for the next update for everyone,
## admin too. Set ADMIN_CAN_ENTER to true to let admin mode (admin_mode.gd) open it again
## while that update is being built.
const ADMIN_CAN_ENTER := false

func sealed() -> bool:
	return not (ADMIN_CAN_ENTER and preload("res://admin_mode.gd").enabled())

func gate_open() -> bool:
	if sealed(): return false
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
		# A real warm light with each flame, so the rock, the sign and the ground in front of
		# the cave are lit at night (the flame picture alone gave no light).
		var torch_light := OmniLight3D.new()
		torch_light.name = "TorchLight"
		torch_light.light_color = Color(1.0, 0.7, 0.35)
		torch_light.light_energy = 1.6
		torch_light.omni_range = 7.0
		torch_light.shadow_enabled = false
		torch_light.position = flame.position + Vector3(0, -0.2, 0.7)
		cave.add_child(torch_light)
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
	# The trip card (top left, where the money sits in town): floor and rank, when the gate
	# shuts, and what this trip has found so far.
	hud = PanelContainer.new()
	hud.name = "DungeonHud"
	hud.position = Vector2(16, 14)
	hud.custom_minimum_size.x = 240
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.03, 0.04, 0.06, 0.72)
	card.border_color = Color(0.85, 0.7, 0.37)
	card.border_width_left = 3
	card.set_corner_radius_all(8)
	card.content_margin_left = 14
	card.content_margin_right = 14
	card.content_margin_top = 10
	card.content_margin_bottom = 10
	hud.add_theme_stylebox_override("panel", card)
	hud.visible = false
	layer.add_child(hud)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	hud.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	hud_title = _text(top, 18, Vector2.ZERO, 0)
	hud_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.85, 0.7, 0.37)
	badge_style.set_corner_radius_all(4)
	badge_style.content_margin_left = 7
	badge_style.content_margin_right = 7
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(badge)
	hud_rank = _text(badge, 12, Vector2.ZERO, 0)
	hud_rank.add_theme_color_override("font_color", Color(0.1, 0.08, 0.04))
	hud_rank.add_theme_constant_override("outline_size", 0)
	hud_gate = _text(column, 13, Vector2.ZERO, 0)
	hud_gate.modulate = Color(0.7, 0.76, 0.86)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.12)
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	var treasure_row := _stat_row(column)
	hud_treasure_name = treasure_row[0]
	hud_treasure = treasure_row[1]
	var drops_row := _stat_row(column)
	drops_row[0].text = "Monster drops"
	hud_drops = drops_row[1]
	var monster_row := _stat_row(column)
	monster_row[0].text = "Monsters left"
	hud_monsters = monster_row[1]
	_build_combat_hud(layer)

## A line of the trip card: [name, value] labels, the value gold on the right.
func _stat_row(column: VBoxContainer) -> Array:
	var row := HBoxContainer.new()
	column.add_child(row)
	var name_label := _text(row, 14, Vector2.ZERO, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.modulate = Color(0.85, 0.89, 0.95)
	var value := _text(row, 14, Vector2.ZERO, 0)
	value.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	return [name_label, value]

## Fights: the health bar of the monster you are fighting (top middle, with its name and
## level) and your own health (bottom left). Monsters now wear you down instead of ending
## the trip at the first touch; at 0 health they still throw you back to the entry stone.
const PLAYER_MAX_HP := 100
const MONSTER_DAMAGE := {"slime": 10, "bat": 8, "mushroom": 14, "boss": 25}
var player_hp := PLAYER_MAX_HP
var hit_cooldown := 0.0
var target: Node3D
var target_time := 0.0
var monster_ratio := 1.0
var player_ratio := 1.0
var monster_root: Control
var monster_name: Label
var monster_fill: ColorRect
var player_root: Control
var player_text: Label
var player_fill: ColorRect
var hurt_flash: ColorRect

func _bar(parent: Control, at: Vector2, width: float, height: float, fill_color: Color) -> ColorRect:
	var frame := ColorRect.new()
	frame.color = Color(0.86, 0.84, 0.78, 0.9)
	frame.position = at - Vector2(2, 2)
	frame.size = Vector2(width + 4, height + 4)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var back := ColorRect.new()
	back.color = Color(0.07, 0.06, 0.06, 0.9)
	back.position = at
	back.size = Vector2(width, height)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.position = at
	fill.size = Vector2(width, height)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	return fill

func _text(parent: Control, size: int, at: Vector2, width: float) -> Label:
	var label := Label.new()
	label.position = at
	label.size = Vector2(width, size + 8)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _build_combat_hud(layer: CanvasLayer) -> void:
	hurt_flash = ColorRect.new()
	hurt_flash.color = Color(0.8, 0.05, 0.05, 0.0)
	hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hurt_flash)
	monster_root = Control.new()
	monster_root.anchor_left = 0.5
	monster_root.anchor_right = 0.5
	monster_root.offset_left = -190
	monster_root.offset_right = 190
	monster_root.offset_top = 40
	monster_root.offset_bottom = 96
	monster_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monster_root.visible = false
	layer.add_child(monster_root)
	monster_name = _text(monster_root, 18, Vector2(0, 0), 380)
	monster_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	monster_fill = _bar(monster_root, Vector2(2, 32), 376, 9, Color(0.95, 0.55, 0.15))
	player_root = Control.new()
	player_root.anchor_top = 1.0
	player_root.anchor_bottom = 1.0
	player_root.offset_left = 24
	player_root.offset_right = 320
	player_root.offset_top = -140
	player_root.offset_bottom = -88
	player_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_root.visible = false
	layer.add_child(player_root)
	var caption := _text(player_root, 13, Vector2(0, 0), 120)
	caption.text = "HEALTH"
	caption.modulate = Color(1, 1, 1, 0.8)
	player_text = _text(player_root, 13, Vector2(176, 0), 120)
	player_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_fill = _bar(player_root, Vector2(2, 28), 292, 12, Color(0.82, 0.16, 0.16))

func _update_combat(delta: float) -> void:
	var down := underground_floor >= 0
	player_root.visible = down
	if not down:
		monster_root.visible = false
		hurt_flash.color.a = 0.0
		return
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	target_time -= delta
	var shown: Node3D = null
	if is_instance_valid(target) and target_time > 0.0:
		shown = target
	else:
		var nearest := 12.0
		for monster in monsters:
			if not is_instance_valid(monster) or monster.dying or monster.state != "chase": continue
			var distance: float = monster.global_position.distance_to(player.global_position)
			if distance < nearest:
				nearest = distance
				shown = monster
	monster_root.visible = shown != null
	if shown != null:
		monster_name.text = "Lv %d  %s%s" % [shown.level, "Elite " if shown.elite else "", shown.data.name]
		monster_ratio = move_toward(monster_ratio, clampf(float(maxi(shown.hp, 0)) / float(shown.max_hp), 0.0, 1.0), delta * 2.5)
		monster_fill.size.x = 376.0 * monster_ratio
	player_ratio = move_toward(player_ratio, float(player_hp) / PLAYER_MAX_HP, delta * 1.5)
	player_fill.size.x = 292.0 * player_ratio
	player_text.text = "%d / %d" % [player_hp, PLAYER_MAX_HP]
	hurt_flash.color.a = move_toward(hurt_flash.color.a, 0.0, delta * 0.9)

## A hit on a monster: it becomes the one the top bar shows (starting from its old health).
func target_hit(monster: Node3D, ratio_before: float) -> void:
	if monster != target: monster_ratio = ratio_before
	target = monster
	target_time = 6.0

## A monster touched you: it hurts (once a second at most) and is pushed back. At 0 health
## the trip ends as before (caught).
func monster_touch(monster: Node3D) -> void:
	if busy or hit_cooldown > 0.0: return
	hit_cooldown = 1.0
	var damage: int = int(MONSTER_DAMAGE.get(monster.kind, 10) * (1.5 if monster.elite else 1.0))
	player_hp = maxi(0, player_hp - damage)
	hurt_flash.color.a = 0.4
	sound("hit")
	var away: Vector3 = monster.global_position - player.global_position
	away.y = 0.0
	monster.knock = away.normalized() * 7.0
	_feedback("%s hits you! -%d health" % [monster.data.name, damage])
	if player_hp <= 0: caught(monster)

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
	elif sealed():
		board_label.text = "SEALED"
		board_label.modulate = Color(0.7, 0.12, 0.1)
	elif open:
		board_label.text = "%s  OPEN" % FLOORS[floors[floors.size() - 1]].rank
		board_label.modulate = Color(0.1, 0.5, 0.15)
	else:
		board_label.text = "CLOSED"
		board_label.modulate = Color(0.7, 0.12, 0.1)

func _process(delta: float) -> void:
	_update_combat(delta)
	_update_area_notice(delta)
	if underground_floor >= 0 and is_instance_valid(audio): audio.tension = _tension()
	var time := Time.get_ticks_msec() / 1000.0
	for index in range(flames.size()):
		flames[index].scale = Vector3(1.0, 1.0 + sin(time * 9.0 + index * 2.0) * 0.12, 1.0)

## Testers walking up to the west hill see why everything here is shut: a banner that the
## Gufa Darwaza (cave, weapon table, Guild) comes in the next update.
var area_notice: PanelContainer

func _build_area_notice() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	area_notice = PanelContainer.new()
	var card := StyleBoxFlat.new()
	card.bg_color = Color(1, 0.97, 0.9, 0.96)
	card.border_color = Color("f28c28")
	card.set_border_width_all(3)
	card.border_width_top = 8
	card.set_corner_radius_all(6)
	card.content_margin_left = 28
	card.content_margin_right = 28
	card.content_margin_top = 12
	card.content_margin_bottom = 14
	area_notice.add_theme_stylebox_override("panel", card)
	area_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area_notice.anchor_left = 0.5
	area_notice.anchor_right = 0.5
	area_notice.offset_top = 96
	area_notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	area_notice.modulate.a = 0.0
	layer.add_child(area_notice)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	area_notice.add_child(column)
	for line in [["COMING IN THE NEXT UPDATE", 13, Color("c8611a")], ["GUFA DARWAZA", 30, Color("3a2a1e")], ["The cave, the weapon table and the Darwaza Guild open soon.", 14, Color("8a7560")]]:
		var label := Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		if line[1] == 30: label.add_theme_font_override("font", preload("res://kenney_theme.gd").heading_font())
		column.add_child(label)

func _update_area_notice(delta: float) -> void:
	var near: bool = sealed() and underground_floor < 0 and is_instance_valid(cave) and player.global_position.distance_to(cave.global_position) < 30.0 and not player._menu_is_open()
	area_notice.modulate.a = move_toward(area_notice.modulate.a, 1.0 if near else 0.0, delta * 2.5)
	area_notice.visible = area_notice.modulate.a > 0.01

func _portal_point() -> Vector3:
	return cave.to_global(PORTAL + Vector3(0, -2.05, 0.6))

## The interaction line shown under the crosshair (shop_operations.gd asks).
func hint() -> String:
	if busy: return ""
	if underground_floor < 0 and _table_slot() >= 0:
		if sealed(): return "Weapon table - opens in the next update"
		var id: String = WEAPON_IDS[_table_slot()]
		var info: Dictionary = WEAPONS[id]
		if business.treasure.weapon == id: return "You are holding the %s (%s)" % [info.name, info.note]
		return "E - take the %s (%s)" % [info.name, info.note]
	if underground_floor >= 0:
		if player.global_position.distance_to(exit_point) < REACH: return "E - climb back up to the town"
		var found: String = floor_root.hint_at(floor_root.to_local(player.global_position))
		if not found.is_empty(): return found
		if _near_stairs(): return "The stairs down to Neelam Mahal (Rank C) open in a later update"
		return ""
	if _near_guild():
		if sealed(): return "Darwaza Guild: the counter opens in a later update"
		var worth: int = business.treasure.value()
		return "E - sell your treasure to the Darwaza Guild (%s%d)" % [String.chr(8377), worth] if worth > 0 else "Darwaza Guild: bring treasure from the Darwaza to sell here"
	if not is_instance_valid(cave) or player.global_position.distance_to(_portal_point()) > REACH: return ""
	if get_tree().current_scene.get_node_or_null("CoopWorld") != null: return "The Darwaza stays shut in co-op for now"
	if sealed(): return "The Darwaza is sealed - it opens in a later update"
	if not gate_open(): return "The Darwaza is shut - it opens at 06:00"
	if _hands_full(): return "Put things down before going into the Darwaza"
	var floor: Dictionary = FLOORS[open_floors()[0]]
	return "E - enter the Darwaza (%s, Rank %s)" % [floor.name, floor.rank]

func try_interact() -> bool:
	if is_instance_valid(reader) and reader.visible:
		close_book()
		return true
	if busy: return false
	if underground_floor < 0 and _table_slot() >= 0:
		if sealed():
			_feedback("The weapons are locked away until the next update.")
			return true
		_take(_table_slot())
		return true
	if underground_floor >= 0:
		if player.global_position.distance_to(exit_point) < REACH:
			_leave()
			return true
		var page: int = floor_root.book_at(floor_root.to_local(player.global_position))
		if page >= 0:
			_read(page)
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
		# Testers: the Guild counter stays shut with the Darwaza (admin_mode.gd).
		if sealed():
			_feedback("The Darwaza Guild counter opens in a later update.")
			return true
		var paid: int = business.sell_treasure()
		_feedback("The Darwaza Guild paid %s%d for your treasure." % [String.chr(8377), paid] if paid > 0 else "Bring treasure from the Darwaza to sell here.")
		return true
	if not is_instance_valid(cave) or player.global_position.distance_to(_portal_point()) > REACH: return false
	if not gate_open() or _hands_full(): return true
	_enter(open_floors()[0])
	return true

## A page of Dada-ji's diary: the cave holds still (busy) while it is open. The first read
## of each page is saved.
func _read(page: int) -> void:
	var kind: String = reader.ORDER[page]
	var pages: Array = business.treasure.books
	if not kind in pages:
		pages.append(kind)
		business.save_progress()
		_feedback("You found page %d of Dada-ji's diary (%d / %d)." % [page + 1, pages.size(), reader.ORDER.size()])
	floor_root.mark_read(page)
	sound("pick")
	busy = true
	reader.open_page(kind, int(MONSTER_DAMAGE.get(kind, 10)), pages.size())

func close_book() -> void:
	if not reader.visible: return
	reader.close()
	busy = false

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
	audio = preload("res://dungeon_audio.gd").new()
	add_child(audio)
	if business.treasure.weapon != "":
		lathi = _make_held(business.treasure.weapon)
		player.camera.add_child(lathi)
	floor_root = preload("res://dungeon_floor.gd").create(index, UNDER)
	add_child(floor_root)
	finds = {}
	player_hp = PLAYER_MAX_HP
	player_ratio = 1.0
	target = null
	exit_point = UNDER + floor_root.get_meta("exit", Vector3.ZERO)
	player.global_position = UNDER + floor_root.get_meta("entry", Vector3(0, 1, 0))
	player.velocity = Vector3.ZERO
	player.rotation.y = floor_root.get_meta("facing", 0.0)
	_spawn_monsters(index)
	_feedback("%s - Rank %s. Find the treasure and keep away from the monsters!" % [FLOORS[index].name, FLOORS[index].rank])
	hud.visible = true
	get_tree().current_scene.get_node("Ui").set_meta("underground", true)
	get_tree().current_scene.get_node("Ui").hud_money.visible = false
	_update_hud()
	await _fade_to(0.0)
	busy = false

func _leave() -> void:
	busy = true
	await _fade_to(1.0)
	if is_instance_valid(floor_root): floor_root.queue_free()
	if is_instance_valid(audio): audio.queue_free()
	if is_instance_valid(lathi): lathi.queue_free()
	monsters.clear()
	business.bring_up_treasure(finds, underground_floor + 1)
	var total := 0
	for kind in finds: total += int(finds[kind])
	if total > 0: _feedback("You brought up %d treasure. Sell it at the Darwaza Guild." % total)
	finds = {}
	hud.visible = false
	get_tree().current_scene.get_node("Ui").remove_meta("underground")
	get_tree().current_scene.get_node("Ui").hud_money.visible = true
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
	player_hp = PLAYER_MAX_HP
	player_ratio = 1.0
	for other in monsters:
		if is_instance_valid(other) and not other.dying: other.reset()
	for jar in floor_root.loot: jar.visible = true
	player.global_position = floor_root.to_global(floor_root.get_meta("entry"))
	player.velocity = Vector3.ZERO
	_feedback("%s caught you!%s" % [monster.data.name, " You dropped %d treasure." % dropped if dropped > 0 else ""])
	_update_hud()
	await _fade_to(0.0)
	busy = false

func sound(kind: String) -> void:
	if is_instance_valid(audio): audio.play(kind)

## A weapon held low on the right in first person (the Blender model of `id`).
func _make_held(id: String) -> Node3D:
	var held := Node3D.new()
	held.name = "Weapon"
	held.position = Vector3(0.34, -0.3, -0.55)
	held.rotation = Vector3(deg_to_rad(-62), deg_to_rad(8), deg_to_rad(-6))
	var model := (load("res://assets/props/dungeon/weapons/%s.glb" % id) as PackedScene).instantiate() as Node3D
	held.add_child(model)
	return held

## The weapon table in front of the cave: lathi, talwar and gada lie on a red cloth, each
## on a soft glow. E takes (or swaps to) the one you stand beside.
func _build_table() -> void:
	table = (load("res://assets/props/dungeon/weapons/weapon_table.glb") as PackedScene).instantiate() as Node3D
	table.name = "WeaponTable"
	table.position = TABLE_AT
	cave.add_child(table)
	# A lantern light over the weapons, so they can be seen at night.
	var lantern := OmniLight3D.new()
	lantern.name = "TableLantern"
	lantern.light_color = Color(1.0, 0.82, 0.55)
	lantern.light_energy = 1.4
	lantern.omni_range = 5.0
	lantern.position = Vector3(0, 2.4, -0.4)
	table.add_child(lantern)
	_body("TableTop", table, Vector3(2.9, 0.95, 1.2), Vector3(0, 0.475, -0.55))
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.85, 0.45, 0.14)
	for index in range(WEAPON_IDS.size()):
		var shown := (load("res://assets/props/dungeon/weapons/%s.glb" % WEAPON_IDS[index]) as PackedScene).instantiate() as Node3D
		shown.name = WEAPON_IDS[index]
		shown.rotation.x = -PI / 2.0
		shown.position = Vector3(TABLE_SLOTS[index], 0.98, 0.05)
		table.add_child(shown)
		displays.append(shown)
		var halo := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.26
		disc.bottom_radius = 0.26
		disc.height = 0.004
		disc.material = glow
		halo.mesh = disc
		halo.position = Vector3(TABLE_SLOTS[index], 0.958, -0.5)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		table.add_child(halo)
	_refresh_table()

func _refresh_table() -> void:
	var holding: String = business.treasure.weapon
	for index in range(displays.size()): displays[index].visible = WEAPON_IDS[index] != holding

## Which weapon the player stands beside (index), or -1 if they are not at the table.
func _table_slot() -> int:
	if not is_instance_valid(table): return -1
	var at: Vector3 = table.to_local(player.global_position)
	if absf(at.x) > 1.9 or at.z < -0.4 or at.z > 2.4: return -1
	var best := 0
	for index in range(TABLE_SLOTS.size()):
		if absf(at.x - TABLE_SLOTS[index]) < absf(at.x - TABLE_SLOTS[best]): best = index
	return best

func _take(index: int) -> void:
	var id: String = WEAPON_IDS[index]
	if business.treasure.weapon == id:
		_feedback("You are already holding the %s." % WEAPONS[id].name)
		return
	business.treasure.weapon = id
	business.save_progress()
	sound("pick")
	_refresh_table()
	_feedback("You took the %s: %s. Left click swings it underground." % [WEAPONS[id].name, WEAPONS[id].note])

func _unhandled_input(event: InputEvent) -> void:
	if underground_floor < 0 or busy or not swing_ready: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if not is_instance_valid(lathi):
			_feedback("You have no weapon! Take one from the table outside the cave.")
			return
		_swing()

## A lathi swing: 0.5 s apart, hits at the middle of the arc the nearest monster in front
## (within 2.6 m) or else a rock to break.
func _swing() -> void:
	swing_ready = false
	sound("swing")
	var slow: float = WEAPONS[business.treasure.weapon].rate / 0.5
	var home := lathi.rotation
	var arc := create_tween()
	arc.tween_property(lathi, "rotation", Vector3(deg_to_rad(-20), deg_to_rad(-34), deg_to_rad(18)), 0.11 * slow).set_ease(Tween.EASE_OUT)
	arc.tween_property(lathi, "rotation", Vector3(deg_to_rad(-100), deg_to_rad(30), deg_to_rad(-20)), 0.14 * slow)
	arc.tween_property(lathi, "rotation", home, 0.2 * slow)
	await get_tree().create_timer(0.14 * slow).timeout
	if underground_floor >= 0 and not busy: _strike()
	await get_tree().create_timer(0.36 * slow).timeout
	swing_ready = true

func _strike() -> void:
	var forward: Vector3 = -player.camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: Node3D = null
	var stats: Dictionary = WEAPONS[business.treasure.weapon]
	var best_distance: float = stats.reach
	for monster in monsters:
		if not is_instance_valid(monster) or monster.dying: continue
		var to: Vector3 = monster.global_position - player.global_position
		to.y = 0.0
		var reach: float = to.length() - monster.data.radius
		if reach < best_distance and to.normalized().dot(forward) > 0.3:
			best = monster
			best_distance = reach
	if best != null:
		best.hurt(stats.damage, player.global_position)
		return
	var local_at: Vector3 = floor_root.to_local(player.global_position)
	var local_forward: Vector3 = (floor_root.global_transform.basis.inverse() * forward).normalized()
	var got: int = floor_root.strike(local_at, local_forward, stats.damage)
	if got == 0: sound("hit")
	elif got > 0:
		sound("break")
		var kind: String = FLOORS[underground_floor].treasure
		finds[kind] = int(finds.get(kind, 0)) + got
		_feedback("The rock breaks! +%d %s" % [got, preload("res://dungeon_store.gd").ITEMS[kind].name.to_lower()])
		_update_hud()

## Called by a monster that has just been beaten.
func monster_died(monster: Node3D) -> void:
	monsters.erase(monster)
	target_time = minf(target_time, 1.2)
	var drops := {"slime": "jelly", "bat": "wing", "mushroom": "cap"}
	if drops.has(monster.kind):
		var drop: String = drops[monster.kind]
		var amount: int = 2 if monster.elite else 1
		finds[drop] = int(finds.get(drop, 0)) + amount
		_feedback("%s dropped +%d %s" % [monster.data.name, amount, preload("res://dungeon_store.gd").ITEMS[drop].name.to_lower()])
		_update_hud()
	if monster.kind == "boss":
		var kind: String = FLOORS[underground_floor].treasure
		finds[kind] = int(finds.get(kind, 0)) + 3
		_feedback("Raja Jelly vanishes in smoke! +3 %s" % preload("res://dungeon_store.gd").ITEMS[kind].name.to_lower())
		_update_hud()

## How tense the cave sounds: 1 while something chases you, rising as one nears.
func _tension() -> float:
	var worst := 0.0
	for monster in monsters:
		if not is_instance_valid(monster) or monster.dying: continue
		var d: float = monster.global_position.distance_to(player.global_position)
		var near := clampf(1.0 - d / 16.0, 0.0, 1.0) * 0.55
		worst = maxf(worst, 1.0 if monster.state == "chase" else near)
	return worst

func _near_stairs() -> bool:
	var stairs: Vector3 = floor_root.get_meta("stairs", Vector3.ZERO)
	return stairs != Vector3.ZERO and floor_root.to_local(player.global_position).distance_to(stairs + Vector3(0, 1, 0)) < REACH

func _update_hud() -> void:
	if underground_floor < 0: return
	var entry: Dictionary = FLOORS[underground_floor]
	var kind: String = entry.treasure
	var alive := 0
	var strongest := 0
	for monster in monsters:
		if is_instance_valid(monster) and not monster.dying:
			alive += 1
			strongest = maxi(strongest, int(monster.level))
	var drops := 0
	for drop in ["jelly", "wing", "cap"]: drops += int(finds.get(drop, 0))
	hud_title.text = entry.name
	hud_rank.text = "RANK %s" % entry.rank
	hud_gate.text = "Gate shuts at %02d:%02d" % [int(entry.close) / 60, int(entry.close) % 60]
	hud_treasure_name.text = "%ss" % preload("res://dungeon_store.gd").ITEMS[kind].name
	hud_treasure.text = str(int(finds.get(kind, 0)))
	hud_drops.text = str(drops)
	hud_monsters.text = "%d  (top Lv %d)" % [alive, strongest] if alive > 0 else "none - cave cleared!"

func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade, "color:a", alpha, 0.35)
	await tween.finished

func _feedback(text: String) -> void:
	var ui := get_tree().current_scene.get_node_or_null("Ui")
	if ui != null and ui.has_method("show_feedback"): ui.show_feedback(text)
