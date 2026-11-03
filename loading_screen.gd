extends CanvasLayer

# Full-screen loading screen between the lobby and the game. It lives under the
# root (not the scene), so it stays up while the scene changes:
#   loading  - the game scene loads on a background thread (real progress)
#   building - the town is built (_ready of every node; the window can't redraw)
#   warming  - the first frames render behind it (shaders, physics)
#   ready    - the game waits paused: "Press any key to start"
# Then it fades out and the game greets the player.
signal failed

const GAME_SCENE := "res://main.tscn.tscn"
const KenneyTheme := preload("res://kenney_theme.gd")
const TIPS := [
	"Customers show Cash, Card or UPI at the counter. Pick the same method to get paid.",
	"Customers tell their list at the counter. Find each item by its rack code (R1, R2...) and fill a carry bag.",
	"Order 5 or more boxes of one product on the shop PC and get 10% off that line.",
	"Hire Sunil to carry delivery boxes and fill the shelves for you.",
	"Sharma's store opens on day 3. Use Match on the shop PC to win customers back.",
	"Short on money? APNA Bank lends ₹20,000, paid back a little each morning.",
	"Sleep in your bed at home to end the day and see your profit report.",
	"Empty shelves mean missed sales. Check Shelf Stock on the PC desktop.",
	"Happy staff stay longer. Thank them, and pay any overtime you owe.",
	"Haggling customers may accept a fair counter offer. Too high and they walk out.",
]


## The look: the town picture drifting slowly (a Ken Burns zoom) under a dark wash from the
## left and the bottom; the game's mark top left; "NOW ENTERING" Dholkarpur Gaon with the save
## as small chips; a "Did you know?" card whose tips fade from one to the next; and along the
## bottom edge a thin gold bar with a moving shine, the stage, the percent and a turning ring.
const GOLD := Color("f28c28")
const BEIGE := Color("efe2c4")
const MUTED := Color(1, 1, 1, 0.6)

var stage := "idle"
var launch: Callable
var welcome := ""
var intro := false
var scene_resource: Resource
var shown := 0.0
var target := 0.0
var wait_frames := 0
var warm_seconds := 0.0
var smooth_frames := 0
var tip_index := 0
var tip_seconds := 0.0
var spin := 0.0
var pulse := 0.0
var drift := 0.0
var screen: Control
var background: TextureRect
var shade: TextureRect
var floor_shade: TextureRect
var logo: Label
var logo_rule: ColorRect
var entering: Label
var title: Label
var tagline: Label
var info: Label
var chips: HBoxContainer
var stage_label: Label
var percent_label: Label
var track: ColorRect
var fill: Panel
var shine: ColorRect
var spinner: Control
var tip_card: PanelContainer
var tip_count: Label
var tip_label: Label
var ready_label: Label
var credits: Label

func _init() -> void:
	name = "LoadingScreen"
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

## launch_call changes to the game scene and returns an Error. summary is the save
## line ("Slot 1 | Day 3 | ...") and greeting the message shown once in the game.
func begin(launch_call: Callable, summary: String, greeting: String, play_intro := false) -> void:
	intro = play_intro
	launch = launch_call
	welcome = greeting
	_build()
	info.text = summary
	# The save line as chips: "Continue | Slot 2 | Day 1 | ₹10,000".
	for part in summary.split("|", false):
		var chip := PanelContainer.new()
		var style := _flat(Color(1, 0.98, 0.94, 0.95), 8)
		style.border_color = Color("3a2a1e")
		style.set_border_width_all(2)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		chip.add_theme_stylebox_override("panel", style)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips.add_child(chip)
		var text := _label(part.strip_edges(), 15, Color("3a2a1e"))
		text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		text.reparent(chip)
	tip_index = randi() % TIPS.size()
	_show_tip()
	stage = "loading"
	target = 0.05
	_set_stage("Opening your shop...")

func _flat(colour: Color, radius := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	return style

func _label(text: String, font_size: int, colour: Color, heading := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	if heading: label.add_theme_font_override("font", KenneyTheme.heading_font())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(label)
	return label

## A full-screen dark wash: from `from` (dark) to `to` (clear), as uv points.
func _wash(from: Vector2, to: Vector2, dark: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.01, 0.02, 0.04, dark))
	gradient.set_color(1, Color(0.01, 0.02, 0.04, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = from
	texture.fill_to = to
	var wash := TextureRect.new()
	wash.texture = texture
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return wash

func _build() -> void:
	screen = Control.new()
	screen.name = "Screen"
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color(0.02, 0.03, 0.05)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background = TextureRect.new()
	background.texture = load("res://assets/ui/main_menu_shop_v2.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade = _wash(Vector2(0, 0.5), Vector2(0.72, 0.5), 0.9)
	floor_shade = _wash(Vector2(0.5, 1), Vector2(0.5, 0.45), 0.95)
	logo = _label("LIFE BUSINESS GAME", 22, Color.WHITE, true)
	logo_rule = ColorRect.new()
	logo_rule.color = GOLD
	logo_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(logo_rule)
	entering = _label("NOW ENTERING", 14, GOLD)
	title = _label("DHOLKARPUR GAON", 54, Color.WHITE, true)
	tagline = _label("Run your shop. Build your life.", 19, BEIGE)
	info = _label("", 15, BEIGE)
	info.hide()
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(chips)
	# Did you know? card: a gold edge on the left, the tip number on the right.
	tip_card = PanelContainer.new()
	tip_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := _flat(Color(1, 0.97, 0.9, 0.95), 12)
	card.border_color = GOLD
	card.set_border_width_all(2)
	card.border_width_left = 6
	card.content_margin_left = 18
	card.content_margin_right = 18
	card.content_margin_top = 12
	card.content_margin_bottom = 14
	tip_card.add_theme_stylebox_override("panel", card)
	screen.add_child(tip_card)
	var tip_column := VBoxContainer.new()
	tip_column.add_theme_constant_override("separation", 6)
	tip_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_card.add_child(tip_column)
	var tip_head := HBoxContainer.new()
	tip_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_column.add_child(tip_head)
	var tip_title := _label("DID YOU KNOW?", 14, GOLD, true)
	tip_title.reparent(tip_head)
	tip_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_count = _label("", 13, Color("8a7560"))
	tip_count.reparent(tip_head)
	tip_label = _label("", 17, Color("3a2a1e"))
	tip_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	tip_label.reparent(tip_column)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size.x = 200
	# Bottom edge: the stage and percent over a thin gold bar with a shine running along it.
	stage_label = _label("", 17, Color.WHITE)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent_label = _label("0%", 28, Color.WHITE)
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	track = ColorRect.new()
	track.color = Color(1, 1, 1, 0.12)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(track)
	fill = Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.clip_contents = true
	var glow := _flat(GOLD, 0)
	glow.shadow_color = Color(1.0, 0.72, 0.2, 0.55)
	glow.shadow_size = 10
	fill.add_theme_stylebox_override("panel", glow)
	track.add_child(fill)
	shine = ColorRect.new()
	shine.color = Color(1, 1, 0.9, 0.7)
	shine.size = Vector2(90, 6)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(shine)
	spinner = Control.new()
	spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spinner.draw.connect(func():
		var centre := spinner.size * 0.5
		var r := centre.x - 3
		spinner.draw_arc(centre, r, 0, TAU, 40, Color(1, 1, 1, 0.12), 3, true)
		for arm in 3: spinner.draw_arc(centre, r, spin + arm * TAU / 3.0, spin + arm * TAU / 3.0 + 1.1, 16, GOLD, 3, true)
		var d := r * 0.38
		spinner.draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -d).rotated(-spin * 0.5), centre + Vector2(d, 0).rotated(-spin * 0.5), centre + Vector2(0, d).rotated(-spin * 0.5), centre + Vector2(-d, 0).rotated(-spin * 0.5)]), Color(GOLD, 0.85)))
	screen.add_child(spinner)
	ready_label = _label("PRESS ANY KEY TO START", 26, Color.WHITE, true)
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ready_label.hide()
	credits = _label("Made by Bucketstudy team", 13, Color(1, 1, 1, 0.45))
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	if not is_instance_valid(screen): return
	var view := get_viewport().get_visible_rect().size
	var left := maxf(24.0, view.x * 0.06)
	var width := view.x - left * 2
	var compact := view.x < 760
	background.pivot_offset = view * 0.5
	logo.position = Vector2(left, 26)
	logo.size = Vector2(width, 30)
	logo_rule.position = Vector2(left, 60)
	logo_rule.size = Vector2(56, 3)
	var middle := view.y * (0.3 if compact else 0.34)
	entering.position = Vector2(left + 2, middle)
	entering.size = Vector2(width, 20)
	title.add_theme_font_size_override("font_size", 34 if compact else 54)
	title.position = Vector2(left, middle + 20)
	title.size = Vector2(width, 70)
	tagline.position = Vector2(left + 2, title.position.y + (46 if compact else 70))
	tagline.size = Vector2(width, 28)
	chips.position = Vector2(left + 2, tagline.position.y + 38)
	# Bottom: the tip card on the left, the stage, percent and ring on the right.
	var bar_y := view.y - 6
	track.position = Vector2(0, bar_y)
	track.size = Vector2(view.x, 6)
	_draw_fill()
	var card_width := minf(width * (1.0 if compact else 0.56), 620.0)
	tip_card.custom_minimum_size = Vector2(card_width, 0)
	tip_card.size = Vector2(card_width, 0)
	tip_card.position = Vector2(left, bar_y - 40 - 108)
	credits.position = Vector2(left, bar_y - 30)
	credits.size = Vector2(width, 20)
	var right := view.x - left
	spinner.size = Vector2(44, 44)
	spinner.position = Vector2(right - 44, bar_y - 74)
	percent_label.position = Vector2(right - 170, bar_y - 74)
	percent_label.size = Vector2(112, 44)
	stage_label.position = Vector2(right - 420, bar_y - 30)
	stage_label.size = Vector2(420, 24)
	ready_label.add_theme_font_size_override("font_size", 18 if compact else 26)
	ready_label.position = Vector2(right - 600, bar_y - 74)
	ready_label.size = Vector2(600, 44)
	if compact:
		tip_card.position.y = bar_y - 230
		stage_label.position.y = bar_y - 100

func _draw_fill() -> void:
	fill.position = Vector2.ZERO
	fill.size = Vector2(maxf(6.0, track.size.x * shown), track.size.y)
	percent_label.text = "%d%%" % int(round(shown * 100))

func _set_stage(text: String) -> void:
	stage_label.text = text

## The next tip fades in, numbered "3 / 10".
func _show_tip() -> void:
	tip_label.text = TIPS[tip_index]
	tip_count.text = "%d / %d" % [tip_index + 1, TIPS.size()]
	tip_card.modulate.a = 0.0
	create_tween().tween_property(tip_card, "modulate:a", 1.0, 0.5)

func _process(delta: float) -> void:
	if stage == "idle" or not is_instance_valid(screen): return
	spin = fmod(spin + delta * 4.0, TAU * 2.0)
	spinner.queue_redraw()
	# The picture drifts in slowly and back, like a camera on a slider.
	drift += delta
	background.scale = Vector2.ONE * (1.04 + 0.04 * sin(drift * 0.12))
	background.position.x = sin(drift * 0.09) * 14.0
	shine.position = Vector2(fmod(drift * 420.0, maxf(fill.size.x + 180.0, 200.0)) - 120.0, 0)
	tip_seconds += delta
	if tip_seconds > 6.0 and stage != "done":
		tip_seconds = 0.0
		tip_index = (tip_index + 1) % TIPS.size()
		_show_tip()
	# The bar eases toward the real progress and never jumps backwards.
	shown = minf(target, shown + maxf(0.25, (target - shown) * 4.0) * delta)
	_draw_fill()
	match stage:
		"loading": _poll_loading()
		"building":
			# Two drawn frames so "Building the town" is on screen before the freeze.
			wait_frames -= 1
			if wait_frames <= 0 and shown >= target - 0.01: _change_scene()
		"warming": _warm_up(delta)
		"ready":
			pulse += delta * 3.0
			ready_label.modulate.a = 0.55 + 0.45 * sin(pulse)

func _poll_loading() -> void:
	if ResourceLoader.has_cached(GAME_SCENE):
		_loaded()
		return
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS: target = 0.05 + 0.55 * float(progress[0])
		ResourceLoader.THREAD_LOAD_LOADED: _loaded()
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: ResourceLoader.load_threaded_request(GAME_SCENE, "", true)
		_: _loaded()

func _loaded() -> void:
	# Keep the loaded scene referenced, or it is freed and loaded again on launch.
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE)
	if status == ResourceLoader.THREAD_LOAD_LOADED: scene_resource = ResourceLoader.load_threaded_get(GAME_SCENE)
	elif ResourceLoader.has_cached(GAME_SCENE): scene_resource = load(GAME_SCENE)
	stage = "building"
	target = 0.7
	wait_frames = 2
	_set_stage("Building the town...")

func _change_scene() -> void:
	stage = "changing"
	get_tree().scene_changed.connect(_on_scene_changed, CONNECT_ONE_SHOT)
	var error: int = launch.call()
	if error != OK:
		get_tree().scene_changed.disconnect(_on_scene_changed)
		failed.emit()
		queue_free()

func _on_scene_changed() -> void:
	scene_resource = null
	# The new scene was added after this layer; take input before it again.
	get_tree().root.move_child(self, -1)
	stage = "warming"
	target = 0.9
	warm_seconds = 0.0
	smooth_frames = 0
	_set_stage("Opening the shutters...")

func _warm_up(delta: float) -> void:
	warm_seconds += delta
	smooth_frames = smooth_frames + 1 if delta < 0.08 else 0
	if warm_seconds > 0.4: target = 1.0
	if (smooth_frames >= 5 and warm_seconds > 0.6) or warm_seconds > 6.0: _ready_to_start()

func _ready_to_start() -> void:
	stage = "ready"
	target = 1.0
	shown = 1.0
	_draw_fill()
	get_tree().paused = true
	for node in [stage_label, percent_label, spinner]: node.hide()
	ready_label.show()
	pulse = 0.0

## Dismisses the screen and starts the game (any key or click when ready).
func start() -> void:
	if stage == "done": return
	stage = "done"
	# A new game opens with the story; it takes over (the game stays paused) and starts play.
	if intro:
		preload("res://intro_cinematic.gd").play(get_tree(), welcome)
		queue_free()
		return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var scene := get_tree().current_scene
	var ui = scene.get_node_or_null("Ui") if scene != null else null
	if ui != null and ui.has_method("show_feedback") and not welcome.is_empty(): ui.show_feedback(welcome)
	var fade := create_tween()
	fade.tween_property(screen, "modulate:a", 0.0, 0.45)
	fade.tween_callback(queue_free)

func _input(event: InputEvent) -> void:
	if stage in ["idle", "done"]: return
	# Nothing reaches the game (camera, pause menu) while loading.
	get_viewport().set_input_as_handled()
	if stage != "ready": return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed
	var pad: bool = event is InputEventJoypadButton and event.pressed
	if key or click or pad: start()
