extends Control

# The hotbar (five slots, bottom middle) and the inventory screen (B or I). The screen is the
# 3D inventory kit in res://inventory/ (drag and drop, rotating 3D preview, weight bar); this
# script fills it from what the game already holds (business.treasure, the dungeon trip, carry
# bags, boxes). Items are put into hotbar slots by dragging them there or with Equip; keys
# 1-5 then hold that item in front of the camera. The hotbar layout is saved beside the save
# file (save.json.hotbar); the items themselves are still the game's own data, so treasure is
# sold at the Darwaza Guild.

const HotbarSlot := preload("res://hotbar_slot.gd")
const DungeonStore := preload("res://dungeon_store.gd")
const SLOT := 56.0
const GAP := 6.0
const KINDS := ["jar", "shard", "coin", "jelly", "wing", "cap"]
## Kilograms per piece, and what the backpack takes before you slow down.
const WEIGHT := {"jar": 1.5, "shard": 1.0, "coin": 0.5, "jelly": 0.6, "wing": 0.3, "cap": 0.5}
const MAX_WEIGHT := 40.0
const WEAPON_MODEL := "res://assets/props/dungeon/weapons/%s.glb"
const BAG_MODEL := "res://assets/props/carry_bag/carry_bag.glb"
const BOX_MODEL := "res://assets/props/shop/carton.glb"
const JAR_MODEL := "res://assets/props/dungeon/floor1/jar.glb"
const WEAPON_NOTE := {"lathi": "A bamboo stick. 1 damage, fast.", "talwar": "A curved sword. 2 damage, long reach.", "gada": "A heavy mace. 3 damage, slow."}
const WEAPON_RARITY := {"lathi": 0, "talwar": 1, "gada": 2}
const GOLD := Color("e9b44c")

var ui: Node
var layer: CanvasLayer
var slots := []
var counts: Array[Label] = []
var pictures: Array[TextureRect] = []
var plain_style: StyleBoxFlat
var picked_style: StyleBoxFlat
var name_label: Label
var screen: InventoryUI
var stock := Inventory.new()
var made := {}
var signature := ""
## Item ids in the five hotbar slots ("" = empty), the slot held now (-1 = none), and the ids
## already offered a free slot (so one you emptied on purpose does not come back).
var hotbar: Array[String] = ["", "", "", "", ""]
var selected := -1
var seen := {}
var loaded := false
var held: Node3D
var held_id := ""
## Pictures: each model is drawn once into a small transparent viewport and kept.
var icons := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = get_parent()
	stock.size = 24
	screen = InventoryUI.new()
	screen.inventory = stock
	screen.columns = 6
	screen.max_weight = MAX_WEIGHT
	# B / I open it from here (Tab is the tablet); the screen itself closes on Esc.
	screen.toggle_keys = []
	screen.item_used.connect(_equip)
	screen.item_dropped.connect(_not_a_drop)
	screen.hotbar_returned.connect(_returned)
	add_child(screen)
	_build_bar()
	get_viewport().size_changed.connect(_layout)
	_layout()

func is_open() -> bool:
	return is_instance_valid(screen) and screen.is_open

func _box(fill: Color, border: Color, width := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	return style

func _label(parent: Node, size: int, at: Vector2, area: Vector2) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at
	label.size = area
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _build_bar() -> void:
	# Above the inventory screen (layer 10) so the hotbar stays bright and takes drops.
	layer = CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	plain_style = _box(Color(0.035, 0.05, 0.06, 0.62), Color(1, 1, 1, 0.25))
	picked_style = _box(Color(0.1, 0.09, 0.04, 0.8), GOLD, 3)
	name_label = _label(root, 15, Vector2.ZERO, Vector2(400, 22))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 5)
	for index in 5:
		var slot = HotbarSlot.new()
		slot.index = index
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.size = Vector2(SLOT, SLOT)
		slot.assigned.connect(_dropped_on)
		slot.clicked.connect(_slot_clicked)
		root.add_child(slot)
		slots.append(slot)
		var picture := TextureRect.new()
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position = Vector2(4, 4)
		picture.size = Vector2(SLOT - 8, SLOT - 8)
		slot.add_child(picture)
		slot.picture = picture
		pictures.append(picture)
		var key := _label(slot, 11, Vector2(5, 1), Vector2(20, 14))
		key.text = str(index + 1)
		key.modulate = Color(1, 1, 1, 0.75)
		var count := _label(slot, 13, Vector2(0, SLOT - 21), Vector2(SLOT - 5, 18))
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 4)
		counts.append(count)

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var total := 5 * SLOT + 4 * GAP
	for index in 5: slots[index].position = Vector2((view.x - total) / 2.0 + index * (SLOT + GAP), view.y - SLOT - 14)
	name_label.position = Vector2((view.x - 400) / 2.0, view.y - SLOT - 42)

# --- Hotbar rules ---

func _path() -> String:
	var base: String = ui.shop.business.save_path
	return "" if base.is_empty() else base + ".hotbar"

func _load() -> void:
	var path := _path()
	if path.is_empty() or not FileAccess.file_exists(path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return
	for index in 5:
		var id = data.get("slots", [])[index] if data.get("slots", []).size() > index else ""
		hotbar[index] = str(id)
	for id in data.get("seen", []): seen[str(id)] = true

func _save() -> void:
	var path := _path()
	if path.is_empty(): return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"slots": hotbar, "seen": seen.keys()}))

## Puts item `id` in `slot` (taking it out of any other slot) and holds it.
func _assign(slot: int, id: String) -> void:
	for index in 5:
		if hotbar[index] == id: hotbar[index] = ""
	hotbar[slot] = id
	selected = slot
	_save()

func _dropped_on(slot: int, from_index: int) -> void:
	if from_index < 0:
		# From another hotbar slot: the two swap.
		var other := -from_index - 1
		if other == slot: return
		var kept := hotbar[slot]
		hotbar[slot] = hotbar[other]
		hotbar[other] = kept
		if selected == slot: selected = other
		elif selected == other: selected = slot
		_save()
		return
	var item := stock.get_item(from_index)
	if item != null: _assign(slot, str(item.id))

func _returned(slot: int) -> void:
	hotbar[slot] = ""
	if selected == slot: selected = -1
	_save()

func _slot_clicked(slot: int, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		hotbar[slot] = ""
		if selected == slot: selected = -1
		_save()
	elif hotbar[slot] != "":
		selected = slot

## The screen's Equip button (or a double click): the item goes to the first free slot.
func _equip(item: ItemData, _from: int) -> void:
	var slot := hotbar.find("")
	if str(item.id) in hotbar: slot = hotbar.find(str(item.id))
	if slot < 0: slot = maxi(selected, 0)
	_assign(slot, str(item.id))
	ui.show_feedback("%s is on key %d." % [item.display_name, slot + 1])

func _not_a_drop(item: ItemData, _amount: int, _from: int) -> void:
	# Dropping changes nothing in the game: the screen is filled again from the real data.
	signature = ""
	ui.show_feedback("%s: sell treasure at the Darwaza Guild." % item.display_name)

func _trip() -> Dictionary:
	var world = ui.shop.get("dungeon_world")
	if world != null and is_instance_valid(world) and world.underground_floor >= 0: return world.finds
	return {}

# --- Pictures ---

func _metal(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.6
	material.roughness = 0.35
	return material

func _mesh_for(key: String) -> Mesh:
	if key == "coin":
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 0.12
		disc.material = _metal(Color(1.0, 0.72, 0.15))
		return disc
	if key == "jelly":
		var blob := SphereMesh.new()
		blob.radius = 0.4
		blob.height = 0.7
		blob.material = _metal(Color(0.4, 0.9, 0.5))
		return blob
	if key == "wing":
		var wing := PrismMesh.new()
		wing.size = Vector3(1.0, 0.6, 0.05)
		wing.material = _metal(Color(0.35, 0.2, 0.5))
		return wing
	if key == "cap":
		var cap := SphereMesh.new()
		cap.radius = 0.45
		cap.height = 0.6
		cap.material = _metal(Color(0.9, 0.45, 0.2))
		return cap
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.0
	crystal.bottom_radius = 0.35
	crystal.height = 1.0
	crystal.radial_segments = 5
	crystal.material = _metal(Color(0.35, 0.85, 1.0))
	return crystal

func _icon(item: ItemData) -> Texture2D:
	var key := str(item.id)
	if icons.has(key): return icons[key]
	var port := SubViewport.new()
	port.size = Vector2i(128, 128)
	port.transparent_bg = true
	port.own_world_3d = true
	port.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(port)
	var pivot := PreviewStage.build(port, 2.4, false)
	pivot.add_child(PreviewStage.make_model(item))
	if item.category == "Weapon": pivot.rotation.z = deg_to_rad(40)
	pivot.rotation.y = 0.6
	icons[key] = port.get_texture()
	return icons[key]

# --- Filling the screen ---

func _item(id: String, name: String, note: String, category: String, rarity: int, value: int, weight: float, path: String) -> ItemData:
	if made.has(id): return made[id]
	var item := ItemData.new()
	item.id = StringName(id)
	item.display_name = name
	item.description = note
	item.category = category
	item.rarity = rarity
	item.max_stack = 9999
	item.value = value
	item.weight = weight
	if path != "": item.model_scene = load(path) as PackedScene
	else: item.mesh = _mesh_for(id)
	made[id] = item
	return item

## What is carried, as [ItemData, count] pairs.
func _entries() -> Array:
	var business = ui.shop.business
	var trip := _trip()
	var list := []
	var weapon: String = business.treasure.weapon
	if weapon != "": list.append([_item(weapon, weapon.capitalize(), WEAPON_NOTE.get(weapon, ""), "Weapon", WEAPON_RARITY.get(weapon, 0), 0, 2.0, WEAPON_MODEL % weapon), 1])
	var rarity := {"jar": 1, "shard": 2, "coin": 3, "jelly": 0, "wing": 0, "cap": 0}
	for kind in KINDS:
		var amount: int = int(business.treasure.held[kind]) + int(trip.get(kind, 0))
		if amount <= 0: continue
		var info: Dictionary = DungeonStore.ITEMS[kind]
		var note := "Dropped by a monster. Sell it at the Darwaza Guild." if kind in ["jelly", "wing", "cap"] else "Brought up from the Darwaza. Sell it at the Darwaza Guild."
		list.append([_item(kind, info.name, note, "Treasure", rarity[kind], info.price, WEIGHT[kind], JAR_MODEL if kind == "jar" else ""), amount])
	list.append([_item("bags", "Carry bags", "Used to carry shopping out for customers.", "Supplies", 0, 0, 0.2, BAG_MODEL), business.carry_bags])
	if int(business.carried_stock) > 0: list.append([_item("box", "Box in hands", "Items in the box you are carrying.", "Supplies", 0, 0, 0.2, BOX_MODEL), int(business.carried_stock)])
	var waiting: int = int(business.supply_box_count())
	if waiting > 0: list.append([_item("boxes", "Boxes waiting", "Delivered stock waiting at the storage.", "Supplies", 0, 0, 0.0, BOX_MODEL), waiting])
	return list

func _sync(entries: Array) -> void:
	# The grid holds only what is not in a hotbar slot: an item lives in one place. The weight
	# bar counts both.
	screen.extra_weight = 0.0
	for entry in entries:
		if str(entry[0].id) in hotbar: screen.extra_weight += entry[0].weight * entry[1]
	# Only slots that really change are touched, so the other items keep their place and their
	# picture (no flicker), and what you dragged around in the grid stays where you put it.
	var wanted := {}
	for entry in entries:
		if not str(entry[0].id) in hotbar: wanted[str(entry[0].id)] = entry
	var placed := {}
	for index in stock.size:
		var item := stock.get_item(index)
		if item == null: continue
		var id := str(item.id)
		if wanted.has(id) and not placed.has(id):
			placed[id] = true
			if stock.get_count(index) != int(wanted[id][1]): stock.set_slot(index, item, wanted[id][1])
		else:
			stock.set_slot(index, null, 0)
	for id in wanted:
		if placed.has(id): continue
		var free := -1
		for index in stock.size:
			if stock.get_item(index) == null:
				free = index
				break
		if free >= 0: stock.set_slot(free, wanted[id][0], wanted[id][1])
	if screen.selected_index < 0 or stock.get_item(screen.selected_index) == null:
		var first := -1
		for index in stock.size:
			if stock.get_item(index) != null:
				first = index
				break
		screen.select_slot(first)

# --- Every frame ---

func _process(_delta: float) -> void:
	if not loaded:
		loaded = true
		_load()
	var open := is_open()
	layer.visible = open or not ui.player._menu_is_open()
	var entries := _entries()
	var have := {}
	var text := ""
	for entry in entries:
		have[str(entry[0].id)] = entry
		text += "%s:%d," % [entry[0].id, entry[1]]
	# Items you choose go into hotbar slots yourself; this only remembers what was seen.
	var changed := false
	for entry in entries:
		var id := str(entry[0].id)
		if seen.has(id): continue
		seen[id] = true
		changed = true
	if changed: _save()
	# Over the weight limit you walk slower (never below 40%).
	var total := 0.0
	for entry in entries: total += entry[0].weight * entry[1]
	ui.player.load_factor = clampf(1.0 - maxf(0.0, total - MAX_WEIGHT) / MAX_WEIGHT, 0.4, 1.0)
	text += "|" + ",".join(hotbar)
	if text != signature:
		signature = text
		_sync(entries)
	if selected >= 0 and not have.has(hotbar[selected]): selected = -1
	for index in 5:
		var id := hotbar[index]
		slots[index].accepting = open
		slots[index].filled = have.has(id)
		slots[index].mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
		slots[index].add_theme_stylebox_override("panel", picked_style if index == selected else plain_style)
		if have.has(id):
			var entry: Array = have[id]
			pictures[index].texture = _icon(entry[0])
			counts[index].text = str(entry[1]) if int(entry[1]) > 1 else ""
		else:
			pictures[index].texture = null
			counts[index].text = ""
	# While the screen is open the name is in its details panel, so it must not overlap it.
	name_label.visible = not open
	name_label.text = "" if selected < 0 else str(have[hotbar[selected]][0].display_name)
	_update_held(have)

# --- The item held in front of the camera ---

func _update_held(have: Dictionary) -> void:
	var id := hotbar[selected] if selected >= 0 else ""
	var camera: Camera3D = ui.player.camera
	if id != held_id or (held != null and not is_instance_valid(held)):
		held_id = id
		if is_instance_valid(held): held.queue_free()
		held = null
		if id != "" and have.has(id):
			var item: ItemData = have[id][0]
			held = Node3D.new()
			held.name = "HeldItem"
			var model := PreviewStage.make_model(item)
			var weapon := item.category == "Weapon"
			model.scale = Vector3.ONE * (0.95 if weapon else 0.32)
			held.add_child(model)
			held.position = Vector3(0.34, -0.3, -0.55)
			held.rotation = Vector3(deg_to_rad(-62), deg_to_rad(8), deg_to_rad(-6)) if weapon else Vector3(0, deg_to_rad(-25), 0)
			camera.add_child(held)
	if held == null: return
	var carrying: bool = int(ui.shop.business.carried_stock) > 0 or ui.shop.get("holding_bag") == true
	# Underground the cave's own weapon model is already in hand.
	var cave_weapon: bool = ui.has_meta("underground") and have.has(id) and have[id][0].category == "Weapon"
	held.visible = not ui.player._menu_is_open() and not carrying and not cave_weapon

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.keycode
	if key == KEY_B or key == KEY_I:
		if is_open():
			screen.close()
			get_viewport().set_input_as_handled()
		elif not ui.player._menu_is_open():
			screen.open()
			get_viewport().set_input_as_handled()
	elif (key >= KEY_1 and key <= KEY_5) and (is_open() or not ui.player._menu_is_open()):
		var slot := key - KEY_1
		# The same key again puts it away; an empty slot means empty hands.
		selected = -1 if slot == selected or hotbar[slot] == "" else slot
		get_viewport().set_input_as_handled()
