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
	"Aim at each product on the counter and press E to scan it.",
	"Order 5 or more boxes of one product on the shop PC and get 10% off that line.",
	"Hire Sunil to carry delivery boxes and fill the shelves for you.",
	"Sharma's store opens on day 3. Use Match on the shop PC to win customers back.",
	"Short on money? APNA Bank lends ₹20,000, paid back a little each morning.",
	"Sleep in your bed at home to end the day and see your profit report.",
	"Empty shelves mean missed sales. Check Shelf Stock on the PC desktop.",
	"Happy staff stay longer. Thank them, and pay any overtime you owe.",
	"Haggling customers may accept a fair counter offer. Too high and they walk out.",
]

var stage := "idle"
var launch: Callable
var welcome := ""
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
var screen: Control
var background: TextureRect
var shade: TextureRect
var title: Label
var tagline: Label
var info: Label
var stage_label: Label
var percent_label: Label
var track: Panel
var fill: Panel
var spinner: Control
var tip_card: Panel
var tip_label: Label
var ready_label: Label
var credits: Label

func _init() -> void:
	name = "LoadingScreen"
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

## launch_call changes to the game scene and returns an Error. summary is the save
## line ("Slot 1 | Day 3 | ...") and greeting the message shown once in the game.
func begin(launch_call: Callable, summary: String, greeting: String) -> void:
	launch = launch_call
	welcome = greeting
	_build()
	info.text = summary
	tip_index = randi() % TIPS.size()
	tip_label.text = TIPS[tip_index]
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

func _build() -> void:
	screen = Control.new()
	screen.name = "Screen"
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color(0.02, 0.04, 0.08)
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
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.04, 0.08, 0.55))
	gradient.set_color(1, Color(0.02, 0.04, 0.08, 0.96))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0.5, 0)
	shade_texture.fill_to = Vector2(0.5, 1)
	shade = TextureRect.new()
	shade.texture = shade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title = _label("LIFE BUSINESS GAME", 46, Color.WHITE, true)
	tagline = _label("Run your shop. Build your life.", 18, Color("4ade80"))
	info = _label("", 17, Color("fde68a"))
	stage_label = _label("", 20, Color.WHITE)
	percent_label = _label("0%", 18, Color("cbd5e1"))
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	track = Panel.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.14), 7))
	screen.add_child(track)
	fill = Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel", _flat(Color("22c55e"), 7))
	track.add_child(fill)
	spinner = Control.new()
	spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spinner.draw.connect(func():
		var centre := spinner.size * 0.5
		spinner.draw_arc(centre, centre.x - 3, 0, TAU, 40, Color(1, 1, 1, 0.15), 4, true)
		spinner.draw_arc(centre, centre.x - 3, spin, spin + 1.9, 24, Color("4ade80"), 4, true))
	screen.add_child(spinner)
	tip_card = Panel.new()
	tip_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := _flat(Color(0.03, 0.06, 0.12, 0.78), 12)
	card.border_color = Color(1, 1, 1, 0.12)
	card.set_border_width_all(1)
	tip_card.add_theme_stylebox_override("panel", card)
	screen.add_child(tip_card)
	var tip_title := Label.new()
	tip_title.name = "TipTitle"
	tip_title.text = "TIP"
	tip_title.position = Vector2(18, 12)
	tip_title.add_theme_font_override("font", KenneyTheme.heading_font())
	tip_title.add_theme_font_size_override("font_size", 16)
	tip_title.add_theme_color_override("font_color", Color("fbbf24"))
	tip_card.add_child(tip_title)
	tip_label = Label.new()
	tip_label.name = "TipText"
	tip_label.position = Vector2(70, 10)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip_label.add_theme_font_size_override("font_size", 16)
	tip_label.add_theme_color_override("font_color", Color("e2e8f0"))
	tip_card.add_child(tip_label)
	ready_label = _label("PRESS ANY KEY TO START", 28, Color.WHITE, true)
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.hide()
	credits = _label("Made by Bucketstudy team", 13, Color(1, 1, 1, 0.55))
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	if not is_instance_valid(screen): return
	var view := get_viewport().get_visible_rect().size
	var left := maxf(24.0, view.x * 0.07)
	var width := view.x - left * 2
	var compact := view.x < 700
	title.add_theme_font_size_override("font_size", 30 if compact else 46)
	title.position = Vector2(left, view.y * 0.12)
	title.size = Vector2(width, 60)
	tagline.position = Vector2(left + 2, title.position.y + (44 if compact else 62))
	tagline.size = Vector2(width, 28)
	info.position = Vector2(left + 2, tagline.position.y + 32)
	info.size = Vector2(width, 26)
	var bottom := view.y - 36
	tip_card.position = Vector2(left, bottom - 76)
	tip_card.size = Vector2(width, 76)
	tip_label.size = Vector2(width - 88, 56)
	track.position = Vector2(left, tip_card.position.y - 34)
	track.size = Vector2(width, 14)
	_draw_fill()
	stage_label.position = Vector2(left + 44, track.position.y - 42)
	stage_label.size = Vector2(width - 140, 30)
	spinner.position = Vector2(left, track.position.y - 46)
	spinner.size = Vector2(32, 32)
	percent_label.position = Vector2(left + width - 90, track.position.y - 40)
	percent_label.size = Vector2(90, 28)
	ready_label.add_theme_font_size_override("font_size", 20 if compact else 28)
	ready_label.position = Vector2(left, track.position.y - 44)
	ready_label.size = Vector2(width, 48)
	credits.position = Vector2(left, view.y - 30)
	credits.size = Vector2(width, 22)

func _draw_fill() -> void:
	fill.position = Vector2.ZERO
	fill.size = Vector2(maxf(14.0, track.size.x * shown), track.size.y)
	percent_label.text = "%d%%" % int(round(shown * 100))

func _set_stage(text: String) -> void:
	stage_label.text = text

func _process(delta: float) -> void:
	if stage == "idle" or not is_instance_valid(screen): return
	spin = fmod(spin + delta * 5.0, TAU)
	spinner.queue_redraw()
	tip_seconds += delta
	if tip_seconds > 5.0 and stage != "done":
		tip_seconds = 0.0
		tip_index = (tip_index + 1) % TIPS.size()
		tip_label.text = TIPS[tip_index]
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
