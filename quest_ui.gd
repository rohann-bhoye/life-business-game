extends Control

# Quests for the player: a tracker under the clock (the quest you follow and its next step), a
# banner when a step is done, and the Journal (J): quests on the left, their steps in the
# middle, the story on the right. Nothing is saved: every step is read from what the game
# already keeps (the first-day goals, the Darwaza weapon, the treasure the guild has seen).

const Rupee := 8377
const C_ACCENT := Color("f28c28")
const C_TEXT := Color("3a2a1e")
const C_MUTED := Color("8a7560")
const J_BG := Color("fff4e0")
const J_EDGE := Color("ecd9b8")
const J_GOLD := Color("f28c28")
const J_BEIGE := Color("3a2a1e")
const J_BRIGHT := Color("2a1c12")
const J_INK := Color("4a3a2c")
const J_GREY := Color("8a7560")
const J_DONE := Color("3cb44b")
const WINDOW := Vector2(1000, 576)

const QUESTS := [
	{
		"id": "first_day", "title": "Pehla Din", "kind": "Main", "place": "Apna Mart, Dholkarpur Gaon", "level": 1,
		"steps": ["Talk to the shop owner and buy Apna Mart", "Order products on the shop PC", "Stock 10 items from a delivery box", "Serve 10 customers at checkout", "Let Sunil stock a box on his shift", "Reach %s2,000 in sales"],
		"story": "You came off the plane with a letter from Dada-ji and a little money. At the shop door an old man in a white kurta is waiting: Seth Ramlal, Dada-ji's oldest friend. Apna Mart is for sale, and he will let it go to you for a fair price.\n\nApna Mart is a small kirana in Dholkarpur Gaon, and once you pay, it is yours. The shelves are bare. Order stock on the PC at your shop desk, carry the boxes in from Apna Storage across the road and fill the racks with your own hands.\n\nThen the queue starts. Serve it kindly, and let Sunil learn the shelves while he is on shift.\n\nBy evening the village should know that Apna Mart is open, and that it is worth the walk.",
	},
	{
		"id": "darwaza", "title": "Gufa Darwaza (next update)", "kind": "Main", "place": "Locked for now - opens in the next update", "level": 3,
		"steps": ["Take a weapon from the table outside the cave", "Go into the Darwaza while its gate is open", "Bring treasure or monster drops back up", "Sell your finds at the Darwaza Guild"],
		"story": "Behind the west hill a cave breathes blue light. The villagers call it the Gufa Darwaza: a door in the rock that stands open only from six in the morning until ten at night.\n\nInside lie firefly jars, crystal shards and gold idol coins, and with them the slimes, bats and mushrooms that guard the dark. None of them are friendly, and the Raja Jelly on the deepest floor is the least friendly of all.\n\nThe Darwaza Guild buys whatever you carry out, at a fair price, so long as you carry it out. Take a lathi, a talwar or a gada from the table, watch your health bar, and be on the stairs before the gate shuts.",
	},
]

var ui: Node
var tracker: PanelContainer
var tracker_title: Label
var tracker_step: Label
var tracker_detail: Label
## What to do right now (demo_progress.gd next_step), under the first-day goal.
var tracker_hint: Label
var banner: VBoxContainer
var banner_title: Label
var banner_text: Label
var banner_time := 0.0
var shown_flags := {}
var tracked := ""
var selected := ""
var layer: CanvasLayer
var stage: Control
var window: Panel
var quest_list: VBoxContainer
var step_list: VBoxContainer
var title_label: Label
var meta_label: Label
var story_label: Label
var track_button: Button
var open_window := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = get_parent()
	_build_tracker()
	_build_banner()
	_build_waypoint()
	_build_journal()

func is_open() -> bool:
	return open_window

# --- What the game says about each quest ---

## One {done: bool, text: String, detail: String} per step of `quest`.
func _steps(quest: Dictionary) -> Array:
	var business = ui.shop.business
	var result := []
	var treasure = business.treasure
	var held := 0
	var sold := 0
	for kind in treasure.held:
		held += int(treasure.held[kind])
		sold += int(treasure.sold.get(kind, 0))
	var flags: Array = []
	var details: Array = []
	if quest.id == "first_day":
		flags = [business.shop_owned] + business.demo.done_flags()
		details = [""] + business.demo.goal_lines()
	else:
		flags = [treasure.weapon != "", treasure.deepest >= 1, held + sold > 0, sold > 0]
		details = ["", "", "", ""]
	for index in quest.steps.size():
		var text: String = quest.steps[index]
		if "%s" in text: text = text % String.chr(Rupee)
		result.append({"done": bool(flags[index]), "text": text, "detail": str(details[index])})
	return result

func _finished(steps: Array) -> bool:
	for step in steps:
		if not step.done: return false
	return true

func _next_step(steps: Array) -> Dictionary:
	for step in steps:
		if not step.done: return step
	return {}

# --- Tracker (under the clock) ---

func _flat(fill: Color, border: Color, radius := 8, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

func _label(parent: Node, size: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 10
	parent.add_child(label)
	return label

func _build_tracker() -> void:
	tracker = PanelContainer.new()
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _flat(Color(1, 0.98, 0.94, 0.94), Color(1, 1, 1, 0.14), 8, 1)
	style.border_width_left = 3
	style.border_color = C_ACCENT
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	tracker.add_theme_stylebox_override("panel", style)
	tracker.anchor_left = 1.0
	tracker.anchor_right = 1.0
	tracker.offset_left = -316
	tracker.offset_right = -16
	tracker.offset_top = 52
	tracker.grow_vertical = Control.GROW_DIRECTION_END
	add_child(tracker)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.custom_minimum_size.x = 268
	tracker.add_child(column)
	tracker_title = _label(column, 12, C_ACCENT)
	tracker_step = _label(column, 15, C_TEXT, true)
	tracker_detail = _label(column, 12, C_MUTED, true)
	tracker_hint = _label(column, 12, Color("c8611a"), true)
	var hint := _label(column, 11, Color(C_MUTED, 0.8))
	hint.text = "J   Journal"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_banner() -> void:
	banner = VBoxContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -300
	banner.offset_right = 300
	banner.offset_top = 96
	banner.modulate.a = 0.0
	add_child(banner)
	banner_title = _label(banner, 13, C_ACCENT)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_text = _label(banner, 22, Color.WHITE)
	# Over the world, not on a card: white text with a dark outline.
	for floating in [banner_title, banner_text]: floating.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# --- Waypoint: a gold marker on the place the quest you follow wants you at next ---

## [name, world position, arrival radius in metres] of each place a quest can send you.
## Inside the radius (walking or in a car) the marker closes by itself; the shop's covers
## its forecourt and the road in front, the storage's only its door (it is 10 m from the shop).
const SPOTS := {
	"shop": ["Apna Mart", Vector3(-3, 1.8, 3.5), 8.0],
	"storage": ["Apna Storage", Vector3(-3, 1.8, 13.5), 4.5],
	"cave": ["Gufa Darwaza", Vector3(-94, 3.0, -32), 8.0],
	"guild": ["Darwaza Guild", Vector3(-80, 2.0, -18), 6.0],
}
## A marker you reached stays closed until you go this far from it again.
const LEAVE_RADIUS := 30.0
var waypoint: Control
var waypoint_spot := ""
## The place whose marker you just reached (set again only after you walk away).
var arrived := ""

func _build_waypoint() -> void:
	waypoint = Control.new()
	waypoint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	waypoint.draw.connect(_draw_waypoint)
	add_child(waypoint)
	waypoint.set_anchors_preset(Control.PRESET_FULL_RECT)

## Where `quest` sends you now ("" once you are inside that place).
func _waypoint_target(quest: Dictionary) -> String:
	var business = ui.shop.business
	var player = ui.player
	if quest.id == "first_day":
		var flags: Array = business.demo.done_flags()
		var box_waiting: bool = business.boxed_stock > 0 or not business.queued_boxes.is_empty() or not business.logistics.storage.is_empty()
		if flags[0] and not flags[1] and business.carried_stock <= 0 and box_waiting:
			return "" if player.warehouse_indoors else "storage"
		return "" if player.shop_indoors else "shop"
	var steps := _steps(quest)
	return "guild" if steps[2].done and not steps[3].done else "cave"

## A world point on the ground plane (marker heights never count towards arriving).
static func _ground(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)

func _draw_waypoint() -> void:
	var camera := get_viewport().get_camera_3d()
	if waypoint_spot == "" or camera == null: return
	var spot: Array = SPOTS[waypoint_spot]
	var target: Vector3 = spot[1]
	var view := waypoint.size
	var margin := 56.0
	if view.x < margin * 4.0 or view.y < margin * 4.0: return
	var behind := camera.is_position_behind(target)
	var at := camera.unproject_position(target)
	var on_screen := not behind and Rect2(Vector2.ONE * margin, view - Vector2.ONE * margin * 2.0).has_point(at)
	var gold := Color("f2c14e")
	if not on_screen:
		# Off screen: pinned to the edge, with an arrow pointing the way.
		var centre := view * 0.5
		var way := (at - centre) * (-1.0 if behind else 1.0)
		way = way.normalized() if way.length() > 1.0 else Vector2.DOWN
		var half := centre - Vector2.ONE * margin
		at = centre + way * minf(half.x / maxf(absf(way.x), 0.001), half.y / maxf(absf(way.y), 0.001))
		var side := way.orthogonal()
		waypoint.draw_colored_polygon(PackedVector2Array([at + way * 30.0, at + way * 16.0 + side * 9.0, at + way * 16.0 - side * 9.0]), gold)
	var grow := 1.0 + 0.08 * sin(Time.get_ticks_msec() / 250.0)
	var r := 11.0 * grow
	var diamond := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	waypoint.draw_colored_polygon(diamond, Color(0.05, 0.05, 0.06, 0.8))
	var ring := diamond.duplicate()
	ring.append(diamond[0])
	waypoint.draw_polyline(ring, gold, 2.5, true)
	waypoint.draw_circle(at, 3.5, gold)
	var font := ThemeDB.fallback_font
	var metres := int(ui.player.global_position.distance_to(target))
	for line in [[spot[0], 15, 22.0, Color(1, 0.97, 0.9)], ["%d m" % metres, 13, 38.0, gold]]:
		var width: float = font.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[1]).x
		var place: Vector2 = at + Vector2(-width * 0.5, line[2])
		waypoint.draw_string_outline(font, place, line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[1], 5, Color(0, 0, 0, 0.8))
		waypoint.draw_string(font, place, line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[1], line[3])

func _announce(title: String, text: String) -> void:
	banner_title.text = title
	banner_text.text = text
	banner_time = 4.2

# --- Journal ---
# Dark and gold: quest sections on the left (each one folds), the chosen quest's header and
# steps in the middle, its story on a scrolling page on the right, key hints along the bottom.

var collapsed := {"Completed": true}

func _text(parent: Node, px: int, color: Color, wrap := false) -> Label:
	var label := _label(parent, px, color, wrap)
	label.add_theme_constant_override("outline_size", 0)
	return label

## A gold ring with a dot: the step to do next, and the quest being followed.
func _ring(parent: Node, at: Vector2, side: float) -> void:
	var ring := Panel.new()
	ring.position = at
	ring.size = Vector2(side, side)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0), J_GOLD, int(side / 2), 2))
	parent.add_child(ring)
	var dot := Panel.new()
	dot.position = Vector2(side * 0.5 - 3, side * 0.5 - 3)
	dot.size = Vector2(6, 6)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_theme_stylebox_override("panel", _flat(J_GOLD, J_GOLD, 3, 0))
	ring.add_child(dot)

func _scroll(at: Vector2, area: Vector2, parent: Node = null) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.position = at
	scroll.size = area
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bar := scroll.get_v_scroll_bar()
	var track := _flat(Color(0, 0, 0, 0.06), Color(0, 0, 0, 0), 3, 0)
	track.content_margin_left = 3
	track.content_margin_right = 3
	bar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grab := _flat(Color("e0c9a0") if state == "grabber" else J_GOLD, Color(0, 0, 0, 0), 3, 0)
		grab.content_margin_left = 3
		grab.content_margin_right = 3
		bar.add_theme_stylebox_override(state, grab)
	(parent if parent != null else window).add_child(scroll)
	return scroll

func _gold_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var look := _flat(Color.WHITE, J_GOLD, 2, 1)
		if state == "hover": look.bg_color = Color("fff0c2")
		if state == "pressed": look.bg_color = Color("ffd9a8")
		if state == "disabled":
			look.bg_color = Color("efe6d6")
			look.border_color = J_EDGE
		button.add_theme_stylebox_override(state, look)
	button.add_theme_color_override("font_color", J_BEIGE)
	button.add_theme_color_override("font_hover_color", J_BRIGHT)
	button.add_theme_color_override("font_pressed_color", J_BRIGHT)
	button.add_theme_color_override("font_disabled_color", J_GREY)

func _build_journal() -> void:
	layer = CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: close())
	root.add_child(dim)
	# A plain frame (not a container), so the window's scale is never reset.
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)
	layer.visible = false
	window = Panel.new()
	window.size = WINDOW
	var frame := _flat(J_BG, J_EDGE, 4, 1)
	frame.shadow_color = Color(0, 0, 0, 0.35)
	frame.shadow_size = 30
	window.add_theme_stylebox_override("panel", frame)
	stage.add_child(window)
	# Header: the page name over a gold tab line.
	var heading := _text(window, 24, J_BEIGE)
	heading.text = "JOURNAL"
	heading.position = Vector2(26, 18)
	var rule := ColorRect.new()
	rule.color = J_EDGE
	rule.position = Vector2(24, 62)
	rule.size = Vector2(WINDOW.x - 48, 1)
	window.add_child(rule)
	var tab := ColorRect.new()
	tab.color = J_GOLD
	tab.position = Vector2(24, 61)
	tab.size = Vector2(132, 3)
	window.add_child(tab)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.position = Vector2(WINDOW.x - 62, 16)
	close_button.size = Vector2(38, 34)
	close_button.focus_mode = Control.FOCUS_NONE
	_gold_button(close_button)
	close_button.pressed.connect(close)
	window.add_child(close_button)
	# Left: the quest sections.
	quest_list = VBoxContainer.new()
	quest_list.custom_minimum_size.x = 288
	quest_list.add_theme_constant_override("separation", 4)
	_scroll(Vector2(24, 80), Vector2(300, 436)).add_child(quest_list)
	# Middle: the quest's header box, then its steps.
	var head := Panel.new()
	head.position = Vector2(340, 80)
	head.size = Vector2(330, 92)
	head.add_theme_stylebox_override("panel", _flat(Color("fff0c2"), J_GOLD, 2, 1))
	window.add_child(head)
	title_label = _text(head, 20, J_BRIGHT)
	title_label.position = Vector2(16, 12)
	meta_label = _text(head, 12, Color("8a6a40"))
	meta_label.position = Vector2(16, 46)
	step_list = VBoxContainer.new()
	step_list.custom_minimum_size.x = 318
	step_list.add_theme_constant_override("separation", 14)
	_scroll(Vector2(340, 190), Vector2(330, 280)).add_child(step_list)
	track_button = Button.new()
	track_button.position = Vector2(340, 482)
	track_button.size = Vector2(330, 34)
	track_button.focus_mode = Control.FOCUS_NONE
	track_button.add_theme_font_size_override("font_size", 14)
	_gold_button(track_button)
	track_button.pressed.connect(func() -> void:
		tracked = selected
		_refresh())
	window.add_child(track_button)
	# Right: the story, on its own scrolling page.
	var page := Panel.new()
	page.position = Vector2(686, 80)
	page.size = Vector2(290, 436)
	page.add_theme_stylebox_override("panel", _flat(Color.WHITE, J_EDGE, 2, 1))
	window.add_child(page)
	var story := _scroll(Vector2(16, 14), Vector2(266, 408), page)
	story_label = _text(story, 15, J_INK, true)
	story_label.custom_minimum_size.x = 248
	story_label.add_theme_constant_override("line_spacing", 4)
	# Bottom: key hints.
	var hints := HBoxContainer.new()
	hints.position = Vector2(26, 534)
	hints.add_theme_constant_override("separation", 8)
	window.add_child(hints)
	for pair in [["Click", "Read a quest"], ["Wheel", "Scroll the story"], ["J / Esc", "Back"]]:
		var cap := PanelContainer.new()
		var cap_style := _flat(Color.WHITE, J_GREY, 4, 1)
		cap_style.content_margin_left = 7
		cap_style.content_margin_right = 7
		cap_style.content_margin_top = 1
		cap_style.content_margin_bottom = 1
		cap.add_theme_stylebox_override("panel", cap_style)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hints.add_child(cap)
		_text(cap, 12, J_BEIGE).text = pair[0]
		_text(hints, 13, J_GREY).text = pair[1] + "      "

func open() -> void:
	if open_window: return
	open_window = true
	layer.visible = true
	if selected == "": selected = tracked if tracked != "" else QUESTS[0].id
	_refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	if not open_window: return
	open_window = false
	layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _place_window() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(1.0, minf((view.x - 40.0) / WINDOW.x, (view.y - 60.0) / WINDOW.y))
	window.pivot_offset = WINDOW * 0.5
	window.scale = Vector2.ONE * fit
	window.position = ((view - WINDOW) * 0.5).floor()

## A folding section bar: coloured edge on the left, an arrow on the right.
func _section(title: String, count: int, stripe: Color) -> void:
	var open: bool = not collapsed.get(title, false)
	var bar := Button.new()
	bar.custom_minimum_size = Vector2(288, 40)
	bar.focus_mode = Control.FOCUS_NONE
	bar.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bar.text = "%s   (%d)" % [title.to_upper(), count]
	bar.add_theme_font_size_override("font_size", 15)
	bar.add_theme_color_override("font_color", J_BEIGE)
	bar.add_theme_color_override("font_hover_color", J_BRIGHT)
	bar.add_theme_color_override("font_pressed_color", J_BRIGHT)
	for state in ["normal", "hover", "pressed"]:
		var style := _flat(Color("fff0c2") if state == "hover" else Color("fde7c4"), stripe, 2, 0)
		style.border_width_left = 4
		style.content_margin_left = 16
		bar.add_theme_stylebox_override(state, style)
	var arrow := Polygon2D.new()
	arrow.color = J_GREY
	var tip := -4.0 if open else 4.0
	arrow.polygon = PackedVector2Array([Vector2(-6, -tip * 0.75), Vector2(6, -tip * 0.75), Vector2(0, tip)])
	arrow.position = Vector2(266, 20)
	bar.add_child(arrow)
	bar.pressed.connect(func() -> void:
		collapsed[title] = open
		_refresh())
	quest_list.add_child(bar)

func _quest_row(quest: Dictionary, done: bool) -> void:
	var picked: bool = quest.id == selected
	var row := Button.new()
	row.custom_minimum_size = Vector2(288, 62)
	row.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		var fill := Color("fff0c2") if picked else (Color("fffaf0") if state == "hover" else Color.WHITE)
		row.add_theme_stylebox_override(state, _flat(fill, J_BRIGHT if picked else J_EDGE, 2, 2 if picked else 1))
	var stripe := ColorRect.new()
	stripe.color = J_GREY if done else J_GOLD
	stripe.position = Vector2(2, 2) if picked else Vector2(1, 1)
	stripe.size = Vector2(4, 58) if picked else Vector2(4, 60)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)
	var level := _text(row, 20, J_GREY if done else J_BEIGE)
	level.text = str(quest.level)
	level.position = Vector2(18, 17)
	var title := _text(row, 16, J_GREY if done else (J_BRIGHT if picked else J_BEIGE))
	title.text = quest.title
	title.position = Vector2(50, 10)
	var place := _text(row, 13, J_GREY)
	place.text = str(quest.place).get_slice(",", 0)
	place.position = Vector2(50, 34)
	if quest.id == tracked and not done: _ring(row, Vector2(258, 22), 18)
	row.pressed.connect(func() -> void:
		selected = quest.id
		_refresh())
	quest_list.add_child(row)

func _refresh() -> void:
	for child in quest_list.get_children(): child.queue_free()
	# Unfinished quests by kind, then everything finished under Completed.
	var groups := {}
	var order := []
	for quest in QUESTS:
		var key: String = "Completed" if _finished(_steps(quest)) else "%s quests" % quest.kind
		if not groups.has(key):
			groups[key] = []
			if key != "Completed": order.append(key)
		groups[key].append(quest)
	order.append("Completed")
	for key in order:
		var list: Array = groups.get(key, [])
		var done: bool = key == "Completed"
		_section(key, list.size(), J_GREY if done else J_GOLD)
		if not collapsed.get(key, false):
			for quest in list: _quest_row(quest, done)
	var quest: Dictionary = QUESTS[0]
	for candidate in QUESTS:
		if candidate.id == selected: quest = candidate
	var steps := _steps(quest)
	title_label.text = str(quest.title).to_upper()
	meta_label.text = "%s\nSUGGESTED LEVEL %d" % [str(quest.place).to_upper(), quest.level]
	story_label.text = quest.story
	for child in step_list.get_children(): child.queue_free()
	# Steps still to do first (the next one gets the gold ring), finished ones below.
	var ordered := []
	for step in steps:
		if not step.done: ordered.append(step)
	for step in steps:
		if step.done: ordered.append(step)
	var ringed := false
	for step in ordered:
		var active: bool = not step.done and not ringed
		if active: ringed = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		step_list.add_child(row)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(20, 22)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(holder)
		if active:
			_ring(holder, Vector2(0, 1), 19)
		else:
			var box := Panel.new()
			box.position = Vector2(1, 3)
			box.size = Vector2(17, 17)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_theme_stylebox_override("panel", _flat(Color("dff3dc") if step.done else Color(0, 0, 0, 0), J_DONE if step.done else Color("b8a588"), 2, 2))
			holder.add_child(box)
			if step.done:
				var tick := Line2D.new()
				tick.points = PackedVector2Array([Vector2(4, 8.5), Vector2(7.5, 12), Vector2(13, 5)])
				tick.width = 2.0
				tick.default_color = J_DONE
				tick.antialiased = true
				box.add_child(tick)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 2)
		row.add_child(column)
		var text := _text(column, 15, J_GREY if step.done else (J_BRIGHT if active else J_INK), true)
		text.custom_minimum_size.x = 280
		text.text = step.text
		if step.detail != "" and not step.done:
			_text(column, 12, Color("c8611a")).text = step.detail
	var finished := _finished(steps)
	track_button.text = "Quest completed" if finished else ("Following this quest" if tracked == selected else "Follow this quest")
	track_button.disabled = finished or tracked == selected

# --- Every frame ---

func _process(delta: float) -> void:
	# Under a CanvasLayer this frame has no size of its own: give it the screen's, so the
	# tracker and banner anchor to the real edges.
	size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	var business = ui.shop.business
	var open_menu: bool = ui.player._menu_is_open() and not open_window
	# Steps done since the last look: a banner for each.
	var current := {}
	for quest in QUESTS:
		var steps := _steps(quest)
		var flags := []
		for step in steps: flags.append(step.done)
		current[quest.id] = flags
		if shown_flags.has(quest.id):
			var before: Array = shown_flags[quest.id]
			for index in steps.size():
				if steps[index].done and not before[index]:
					if _finished(steps): _announce("QUEST COMPLETED", quest.title)
					else: _announce("QUEST UPDATED  -  %s" % quest.title, "Done: %s" % steps[index].text)
	var changed := shown_flags != current
	shown_flags = current
	# Follow the first quest that is not finished, until the player picks another.
	var tracked_quest: Dictionary = {}
	for quest in QUESTS:
		if quest.id == tracked and not _finished(_steps(quest)): tracked_quest = quest
	if tracked_quest.is_empty():
		tracked = ""
		for quest in QUESTS:
			if not _finished(_steps(quest)):
				tracked_quest = quest
				tracked = quest.id
				break
	tracker.visible = not tracked_quest.is_empty() and not open_menu and not open_window and not ui.has_meta("underground")
	if tracker.visible:
		var steps := _steps(tracked_quest)
		var next := _next_step(steps)
		tracker_title.text = str(tracked_quest.title).to_upper()
		tracker_step.text = str(next.get("text", ""))
		tracker_detail.text = str(next.get("detail", ""))
		tracker_detail.visible = tracker_detail.text != ""
		var hint: String = business.demo.next_step(business) if tracked_quest.id == "first_day" else ""
		tracker_hint.text = "> " + hint
		tracker_hint.visible = hint != ""
	waypoint_spot = _waypoint_target(tracked_quest) if tracker.visible else ""
	var here := Vector2(ui.player.global_position.x, ui.player.global_position.z)
	if arrived != "" and here.distance_to(_ground(SPOTS[arrived][1])) > LEAVE_RADIUS: arrived = ""
	if waypoint_spot != "" and arrived != waypoint_spot and here.distance_to(_ground(SPOTS[waypoint_spot][1])) < SPOTS[waypoint_spot][2]:
		# The marker closes on arrival with a short message, and stays closed while you
		# are around the place (walking about in front of the shop, parking the car).
		arrived = waypoint_spot
		ui.show_feedback("You arrived at %s." % SPOTS[waypoint_spot][0])
	if waypoint_spot == arrived: waypoint_spot = ""
	waypoint.visible = not open_menu
	waypoint.queue_redraw()
	banner_time = maxf(0.0, banner_time - delta)
	banner.visible = not open_menu and not open_window
	banner.modulate.a = clampf(banner_time / 0.6, 0.0, 1.0) if banner_time < 0.6 else minf(1.0, (4.2 - banner_time) / 0.25)
	if open_window:
		_place_window()
		if changed: _refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_J:
		if open_window:
			close()
			get_viewport().set_input_as_handled()
		elif not ui.player._menu_is_open():
			open()
			get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and open_window:
		close()
		get_viewport().set_input_as_handled()
