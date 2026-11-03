extends CanvasLayer

# The world map (M): the land baked from above (tools/bake_world_map.gd) painted like an
# old map, with the places of Dholkarpur Gaon, the quest you follow and you on it. Drag to
# move, wheel to zoom, Space to find yourself; the legend on the left hides or shows a kind
# of place. It is one picture and one draw call, and the 3D world stops drawing while it is
# open, so it costs less than playing.
## The land the picture covers (x, z) and its size in pixels (same metres per pixel both ways).
const BOUNDS := Rect2(-140.0, -257.0, 280.0, 385.0)
const PICTURE_SIZE := Vector2(744, 1024)
const PICTURE := "res://assets/ui/world_map.png"
const GOLD := Color("f28c28")
const BEIGE := Color("3a2a1e")
const GREY := Color("8a7560")
const EDGE := Color("e3c99c")
const KINDS := {
	"shop": {"label": "Your business", "colour": Color("f2c14e")},
	"town": {"label": "Town places", "colour": Color("7fd18b")},
	"darwaza": {"label": "Dungeons", "colour": Color("b78cff")},
	"home": {"label": "Homes", "colour": Color("8ec5ff")},
	"travel": {"label": "Roads and travel", "colour": Color("ff9f6e")},
}
## [name, kind, world x/z, quest id that points here]
const PLACES := [
	["Apna Mart", "shop", Vector2(-3, 0), "first_day"],
	["Apna Storage", "shop", Vector2(-6, 18), ""],
	["Your Home", "home", Vector2(6, -7), ""],
	["Car Lot", "town", Vector2(14, -1), ""],
	["Bus Stop", "travel", Vector2(-24, 12), ""],
	["School", "town", Vector2(-24, -44), ""],
	["Bazaar", "town", Vector2(50, 6), ""],
	["West Colony", "home", Vector2(-52, -12), ""],
	["East Colony", "home", Vector2(62.5, -12), ""],
	["Darwaza Guild", "darwaza", Vector2(-80, -18), ""],
	["Gufa Darwaza", "darwaza", Vector2(-94, -32), "darwaza"],
	["Export Terminal", "travel", Vector2(16, 42), ""],
	["Airport", "travel", Vector2(30, 58), ""],
	["Dholkar Bridge", "travel", Vector2(50, -146), ""],
	["Village", "home", Vector2(42, -190), ""],
	["Farm", "town", Vector2(100, -190), ""],
	["Giant Police", "town", Vector2(-20, -185), ""],
	["Cricket Ground", "town", Vector2(25, -40), ""],
	# The five dungeons, from the Gufa Darwaza by the town out to the far corners of the land,
	# the further the harder (DUNGEONS has their ranks).
	["Sheesh Gufa", "darwaza", Vector2(-95, -232), ""],
	["Van Mandir", "darwaza", Vector2(105, -95), ""],
	["Kaala Qila", "darwaza", Vector2(102, 105), ""],
	["Naag Lok", "darwaza", Vector2(-102, 105), ""],
]
const DUNGEONS := {"Gufa Darwaza": "E", "Sheesh Gufa": "D", "Van Mandir": "C", "Kaala Qila": "B", "Naag Lok": "A"}
const PAINT := """
shader_type canvas_item;
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 col = mix(c, vec3(l * 1.08, l * 0.96, l * 0.74), 0.35) * 1.12;
	float grain = fract(sin(dot(floor(UV * 700.0), vec2(12.9898, 78.233))) * 43758.5453);
	col *= 0.94 + grain * 0.08;
	vec2 e = min(UV, 1.0 - UV);
	col = mix(col * 0.3, col, smoothstep(0.0, 0.07, min(e.x, e.y)));
	COLOR = vec4(col, 1.0);
}
"""

var ui: Node
var view: Control
var picture: TextureRect
var marks: Control
var legend: VBoxContainer
var tracked_label: Label
var hidden_kinds := {}
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false
var open_map := false
var pulse := 0.0

func _init() -> void:
	name = "WorldMap"
	layer = 9
	visible = false

## Shut places: every dungeon and the Darwaza Guild come in the next update (for admin too,
## like dungeon_world.gd sealed).
func _locked(place: String) -> bool:
	return DUNGEONS.has(place) or place in ["Darwaza Guild", "Dholkar Bridge", "Village", "Farm", "Giant Police"]

func _ready() -> void:
	ui = get_parent()
	var back := ColorRect.new()
	back.color = Color("fff4e0")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	view = Control.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.offset_top = 58
	view.offset_bottom = -40
	view.clip_contents = true
	view.gui_input.connect(_on_view_input)
	add_child(view)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(PICTURE): picture.texture = load(PICTURE)
	var paint := ShaderMaterial.new()
	paint.shader = Shader.new()
	paint.shader.code = PAINT
	picture.material = paint
	view.add_child(picture)
	marks = Control.new()
	marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(_draw_marks)
	view.add_child(marks)
	_build_frame()

# ---------------------------------------------------------------- frame and panels

func _box(fill: Color, border: Color, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _text(parent: Node, px: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _build_frame() -> void:
	# Top bar with the gold WORLD MAP tab, bottom bar with the keys.
	var top := Panel.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 58
	top.add_theme_stylebox_override("panel", _box(GOLD, GOLD))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var tab := PanelContainer.new()
	tab.add_theme_stylebox_override("panel", _box(Color.WHITE, BEIGE, 2))
	tab.anchor_left = 0.5
	tab.anchor_right = 0.5
	tab.offset_left = -84
	tab.offset_right = 84
	tab.offset_top = 6
	tab.offset_bottom = 52
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tab)
	var tab_text := _text(tab, 18, BEIGE)
	tab_text.text = "WORLD MAP"
	tab_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bottom := Panel.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -40
	bottom.add_theme_stylebox_override("panel", _box(Color("fde7c4"), EDGE))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var keys := HBoxContainer.new()
	keys.set_anchors_preset(Control.PRESET_CENTER)
	keys.grow_horizontal = Control.GROW_DIRECTION_BOTH
	keys.grow_vertical = Control.GROW_DIRECTION_BOTH
	keys.add_theme_constant_override("separation", 8)
	bottom.add_child(keys)
	for pair in [["Drag", "Move"], ["Wheel", "Zoom"], ["Space", "Find me"], ["M / Esc", "Close"]]:
		var cap := PanelContainer.new()
		var cap_style := _box(Color.WHITE, GREY)
		cap_style.content_margin_left = 7
		cap_style.content_margin_right = 7
		cap_style.content_margin_top = 1
		cap_style.content_margin_bottom = 1
		cap.add_theme_stylebox_override("panel", cap_style)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keys.add_child(cap)
		_text(cap, 12, BEIGE).text = pair[0]
		_text(keys, 13, GREY).text = pair[1] + "      "
	# Region name, top left over the map.
	var region := PanelContainer.new()
	region.position = Vector2(18, 72)
	region.add_theme_stylebox_override("panel", _box(Color(1, 0.98, 0.94, 0.95), EDGE))
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(region)
	_text(region, 17, BEIGE).text = "DHOLKARPUR GAON"
	# The quest you follow, top right.
	var quest := PanelContainer.new()
	quest.anchor_left = 1.0
	quest.anchor_right = 1.0
	quest.offset_left = -300
	quest.offset_right = -18
	quest.offset_top = 72
	quest.add_theme_stylebox_override("panel", _box(Color(1, 0.98, 0.94, 0.95), EDGE))
	quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quest)
	tracked_label = _text(quest, 14, BEIGE)
	tracked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Legend, bottom left: click a row to hide or show that kind of place.
	var legend_box := PanelContainer.new()
	legend_box.anchor_top = 1.0
	legend_box.anchor_bottom = 1.0
	legend_box.offset_left = 18
	legend_box.offset_bottom = -58
	legend_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	legend_box.add_theme_stylebox_override("panel", _box(Color(1, 0.98, 0.94, 0.95), EDGE))
	add_child(legend_box)
	legend = VBoxContainer.new()
	legend.add_theme_constant_override("separation", 2)
	legend_box.add_child(legend)

func _refresh_legend() -> void:
	for child in legend.get_children(): child.queue_free()
	for kind in KINDS:
		var count := 0
		for place in PLACES:
			if place[1] == kind: count += 1
		var shown: bool = not hidden_kinds.get(kind, false)
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "        %d    %s" % [count, KINDS[kind].label]
		row.add_theme_font_size_override("font_size", 14)
		row.add_theme_color_override("font_color", BEIGE if shown else Color(GREY, 0.6))
		row.add_theme_color_override("font_hover_color", Color.WHITE)
		row.custom_minimum_size = Vector2(220, 26)
		var dot := Control.new()
		dot.position = Vector2(14, 13)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var colour: Color = KINDS[kind].colour if shown else Color(GREY, 0.5)
		var shape: String = kind
		dot.draw.connect(func() -> void: _icon(dot, Vector2.ZERO, shape, colour, 0.8))
		row.add_child(dot)
		row.pressed.connect(func() -> void:
			hidden_kinds[kind] = shown
			_refresh_legend()
			marks.queue_redraw())
		legend.add_child(row)

# ---------------------------------------------------------------- open, close, move

func is_open() -> bool:
	return open_map

func open() -> void:
	if open_map: return
	open_map = true
	visible = true
	# The world is hidden behind the map: stop drawing it.
	get_viewport().disable_3d = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_legend()
	var journal = ui.get_node_or_null("QuestJournal")
	var title := ""
	if journal != null:
		for quest in journal.QUESTS:
			if quest.id == journal.tracked: title = quest.title
	tracked_label.text = "Following:  %s" % title if title != "" else "No quest followed"
	await get_tree().process_frame
	zoom = _fit_zoom() * 2.2
	_centre_on(_player_point())

func close() -> void:
	if not open_map: return
	open_map = false
	visible = false
	get_viewport().disable_3d = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## The zoom that shows the whole land at once.
func _fit_zoom() -> float:
	return minf(view.size.x / PICTURE_SIZE.x, view.size.y / PICTURE_SIZE.y)

## World x/z to a point on the picture (pixels).
func _to_picture(at: Vector2) -> Vector2:
	return (at - BOUNDS.position) / BOUNDS.size * PICTURE_SIZE

func _player_point() -> Vector2:
	var body: Node3D = ui.player
	return _to_picture(Vector2(body.global_position.x, body.global_position.z))

func _centre_on(point: Vector2) -> void:
	pan = view.size * 0.5 - point * zoom
	_apply()

func _apply() -> void:
	# Smaller than the view: keep it centred; bigger: never drag an edge into the view.
	var span := PICTURE_SIZE * zoom
	for axis in 2:
		var room: float = view.size[axis] - span[axis]
		pan[axis] = room * 0.5 if room > 0.0 else clampf(pan[axis], room, 0.0)
	picture.position = pan
	picture.size = span
	marks.queue_redraw()

func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var before: Vector2 = (event.position - pan) / zoom
		zoom = clampf(zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), _fit_zoom(), 4.0)
		pan = event.position - before * zoom
		_apply()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		pan += event.relative
		_apply()

func _process(delta: float) -> void:
	if not open_map: return
	pulse += delta
	marks.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if open_map and event.keycode in [KEY_M, KEY_ESCAPE]:
		close()
		get_viewport().set_input_as_handled()
	elif open_map and event.keycode == KEY_SPACE:
		_centre_on(_player_point())
		get_viewport().set_input_as_handled()
	elif not open_map and event.keycode == KEY_M and not ui.player._menu_is_open():
		if ui.has_meta("underground"):
			ui.show_feedback("The map does not reach down here. Climb back up first.")
		else:
			open()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- drawing

## A dungeon gate, alive: a stone ring with six blocks round a purple swirl that turns, and a
## glow that breathes (pulse runs while the map is open).
func _gate(canvas: CanvasItem, at: Vector2, colour: Color, scale := 1.0) -> void:
	var r := 13.0 * scale
	var breath := 0.5 + 0.5 * sin(pulse * 3.0)
	canvas.draw_circle(at, r + 7.0 * scale, Color(colour, 0.14 + 0.14 * breath))
	canvas.draw_circle(at, r + 2.0, Color(0, 0, 0, 0.55))
	canvas.draw_circle(at, r, Color(0.17, 0.06, 0.3))
	for arm in 3:
		var start := pulse * 2.4 + arm * TAU / 3.0
		canvas.draw_arc(at, r * 0.64, start, start + 1.9, 12, colour.lightened(0.25), 2.4 * scale, true)
		canvas.draw_arc(at, r * 0.32, start + 1.0, start + 2.6, 10, Color(1, 0.85, 1, 0.9), 1.6 * scale, true)
	canvas.draw_circle(at, r * 0.15, Color(1, 0.92, 1))
	canvas.draw_arc(at, r, 0, TAU, 32, Color(0.56, 0.51, 0.46), 3.2 * scale, true)
	for block in 6:
		var spot := at + Vector2.from_angle(block * TAU / 6.0 - PI / 2.0) * r
		canvas.draw_rect(Rect2(spot - Vector2(2.5, 2.5) * scale, Vector2(5, 5) * scale), Color(0.4, 0.36, 0.32))

## A place icon: a dark disc ringed in the kind's colour, with the kind's shape inside.
func _icon(canvas: CanvasItem, at: Vector2, kind: String, colour: Color, scale := 1.0) -> void:
	if kind == "darwaza":
		_gate(canvas, at, colour, scale)
		return
	var r := 10.0 * scale
	canvas.draw_circle(at, r + 2.0, Color(0, 0, 0, 0.55))
	canvas.draw_circle(at, r, Color(0.08, 0.07, 0.05))
	canvas.draw_arc(at, r, 0, TAU, 24, colour, 2.0 * scale, true)
	var s := r * 0.5
	match kind:
		"shop":
			canvas.draw_rect(Rect2(at - Vector2(s, s * 0.6), Vector2(s * 2, s * 1.5)), colour)
			canvas.draw_rect(Rect2(at - Vector2(s * 1.2, s * 0.95), Vector2(s * 2.4, s * 0.45)), colour)
		"home":
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 1.2), at + Vector2(s * 1.2, 0), at + Vector2(-s * 1.2, 0)]), colour)
			canvas.draw_rect(Rect2(at + Vector2(-s * 0.75, 0), Vector2(s * 1.5, s)), colour)
		"guild":
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 1.2), at + Vector2(s * 0.9, 0), at + Vector2(0, s * 1.2), at + Vector2(-s * 0.9, 0)]), colour)
		"travel":
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(s * 1.2, 0), at + Vector2(-s * 0.6, -s), at + Vector2(-s * 0.2, 0), at + Vector2(-s * 0.6, s)]), colour)
		_:
			canvas.draw_circle(at, s * 0.8, colour)

func _draw_marks() -> void:
	var font := ThemeDB.fallback_font
	# The river's name along its water.
	var river := pan + _to_picture(Vector2(-60, -150)) * zoom
	marks.draw_string_outline(font, river, "Dholkar River", HORIZONTAL_ALIGNMENT_CENTER, -1, 15, 4, Color(0.05, 0.12, 0.18, 0.8))
	marks.draw_string(font, river, "Dholkar River", HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color(0.72, 0.88, 1.0))
	var journal = ui.get_node_or_null("QuestJournal")
	var tracked: String = journal.tracked if journal != null else ""
	# Names in PLACES order; one that would cover an earlier name waits for a closer zoom.
	var taken: Array[Rect2] = []
	for place in PLACES:
		if hidden_kinds.get(place[1], false): continue
		var at: Vector2 = pan + _to_picture(place[2]) * zoom
		if not Rect2(Vector2(-80, -40), marks.size + Vector2(160, 80)).has_point(at): continue
		var colour: Color = KINDS[place[1]].colour
		var spot_box := Rect2(at - Vector2(13, 13), Vector2(26, 26))
		var crowded := false
		for other in taken:
			if other.intersects(spot_box): crowded = true
		if crowded and place[3] != tracked: continue
		taken.append(spot_box)
		if place[3] != "" and place[3] == tracked:
			# The quest you follow: a pulsing gold ring and a "!".
			var grow := 1.0 + 0.15 * sin(pulse * 4.0)
			marks.draw_arc(at, 20.0 * grow, 0, TAU, 32, Color(GOLD, 0.9), 3.0, true)
			marks.draw_string_outline(font, at + Vector2(-5, -26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 5, Color.BLACK)
			marks.draw_string(font, at + Vector2(-5, -26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, GOLD)
		var locked := _locked(place[0])
		# Dungeon gates stay bright and alive even while shut; the Guild is its own diamond.
		var shape: String = "guild" if place[0] == "Darwaza Guild" else place[1]
		_icon(marks, at, shape, colour if DUNGEONS.has(place[0]) or not locked else colour.darkened(0.4))
		if locked:
			# A small padlock on the icon's corner.
			var lock := at + Vector2(9, 8)
			marks.draw_arc(lock + Vector2(0, -4), 3.5, PI, TAU, 8, Color("f2c879"), 1.5, true)
			marks.draw_rect(Rect2(lock + Vector2(-4.5, -4), Vector2(9, 7)), Color("f2c879"))
		var width := font.get_string_size(place[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var spot := at + Vector2(-width * 0.5, 28)
		var room := Rect2(spot + Vector2(-4, -14), Vector2(width + 8, 18))
		var free := true
		for other in taken:
			if other.intersects(room): free = false
		if not free: continue
		taken.append(room)
		marks.draw_string_outline(font, spot, place[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color(0, 0, 0, 0.85))
		marks.draw_string(font, spot, place[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.97, 0.94, 0.86))
		# Dungeons: their rank, and "next update" while they are shut.
		var note := ""
		if DUNGEONS.has(place[0]): note = "Rank %s" % DUNGEONS[place[0]]
		if locked: note += ("  -  " if note != "" else "") + "next update"
		if note != "":
			var note_width := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var below := at + Vector2(-note_width * 0.5, 43)
			taken.append(Rect2(below + Vector2(-4, -12), Vector2(note_width + 8, 15)))
			marks.draw_string_outline(font, below, note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.85))
			marks.draw_string(font, below, note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2c879"))
	# You: a white arrow pointing the way you face.
	var body: Node3D = ui.player
	var you := pan + _player_point() * zoom
	var facing := -body.global_transform.basis.z
	var ahead := Vector2(facing.x, facing.z).normalized()
	if ahead == Vector2.ZERO: ahead = Vector2.UP
	var side := Vector2(-ahead.y, ahead.x)
	var arrow := PackedVector2Array([you + ahead * 14.0, you - ahead * 9.0 + side * 9.0, you - ahead * 4.0, you - ahead * 9.0 - side * 9.0])
	marks.draw_circle(you, 22.0 + 3.0 * sin(pulse * 3.0), Color(1, 1, 1, 0.12))
	marks.draw_colored_polygon(arrow, Color.WHITE)
	var outline := arrow.duplicate()
	outline.append(arrow[0])
	marks.draw_polyline(outline, Color(0.1, 0.1, 0.1), 2.0, true)
