extends CanvasLayer

# The opening story of a new game (about a minute, any key skips it):
#   1 night flight - you sit at the window of a plane, thinking about why your parents sent
#     you away; Dada-ji's letter names the town (Dholkarpur Gaon)
#   2 dawn         - the plane drops through the clouds, the pilot announces the landing
#   3 touchdown    - the window opens out, a flash, then the title card
# It is drawn in code (no assets), plays while the game is paused behind it, then puts the
# player at the airport on Airport Road, facing the town, and fades out.
signal finished

const KenneyTheme := preload("res://kenney_theme.gd")
const Voice := preload("res://intro_voice.gd")
const AIRPORT_SPOT := Vector3(31.5, 1.1, 45.5)
const AIRPORT_YAW := -PI / 2
const TOTAL := 65.0
const SKIP_FADE := 0.7
const CABIN := Color(0.035, 0.04, 0.06)
const BEZEL := Color(0.16, 0.17, 0.2)
const Rupee := 8377

# Caption lines: [start, end, speaker, colour, text, voice id]. Typed out at TYPE_SPEED
# letters/second; the voice line (intro_voice.gd) plays with it when it has been made. Each
# span is a little longer than its recorded line, so no voice cuts off the next.
const TYPE_SPEED := 32.0
const LINES := [
	[2.2, 9.2, "YOU", Color("e2e8f0"), "Seat 14A. Somewhere over India. Nobody on this plane knows me.", "you_seat"],
	[9.6, 15.2, "PAPA", Color("fbbf24"), "\"Beta, bahut ho gaya. Ghar baithke kuch nahi milta. Jaa, apna kaam dhoondh.\"", "papa"],
	[15.6, 20.4, "MUMMY", Color("f9a8d4"), "\"Tiffin rakh diya hai. Aur ye %s... sambhaal ke kharch karna.\"", "mummy_money"],
	[20.8, 27.2, "YOU", Color("e2e8f0"), "Why me? Why now? I don't even know what I'm good at.", "you_why"],
	[38.0, 45.6, "YOU", Color("e2e8f0"), "A town I have never seen. A letter. %s. That is all I have.", "you_town_money"],
	[46.4, 57.4, "PILOT", Color("86efac"), "Ladies and gentlemen, we are now landing at Dholkarpur. Local time is 8 AM, weather sunny. Thank you for flying Apna Air.", "pilot"],
]
const LETTER_START := 27.6
const LETTER_END := 37.6
const LETTER := "Beta,\n\nJab bhi kho jao,\nDholkarpur Gaon chale jaana.\nWahin se sab kuch shuru hota hai.\n\n- Dada-ji"
const CHIME_AT := 45.8
const DESCENT_START := 42.0
const CLOUD_PASS := 51.0
const ZOOM_START := 54.0
const TOUCHDOWN := 59.0
const TITLE_START := 60.5

var clock := 0.0
var skipping := false
var skip_time := 0.0
var done := false
var welcome := ""
var stage_view: Control
var caption_card: Panel
var caption_accent: ColorRect
var caption_name: Label
var caption_text: Label
var letter_card: Panel
var letter_label: Label
var title_label: Label
var sub_label: Label
var skip_label: Label
var stars: Array[Vector3] = []
var clouds: Array[Dictionary] = []
var hum: AudioStreamPlayer
var chime: AudioStreamPlayer
var thump: AudioStreamPlayer
var chime_played := false
var thump_played := false
## The characters' voices (intro_voice.gd), one line at a time.
var voice: AudioStreamPlayer
var letter_spoken := false
var teleported := false
var last_line := -1

## Starts the intro over the paused game. greeting is shown in the game once it ends.
static func play(tree: SceneTree, greeting: String) -> void:
	var cinematic = load("res://intro_cinematic.gd").new()
	cinematic.welcome = greeting
	tree.root.add_child(cinematic)

func _init() -> void:
	name = "IntroCinematic"
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1947
	for index in range(110): stars.append(Vector3(rng.randf(), rng.randf() * 0.8, rng.randf() * TAU))
	for index in range(22):
		clouds.append({"x": rng.randf(), "y": rng.randf(), "scale": rng.randf_range(0.6, 1.5), "speed": rng.randf_range(0.5, 1.3), "seed": rng.randf()})
	stage_view = Control.new()
	stage_view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(stage_view)
	stage_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_view.draw.connect(_draw_stage)
	_build_caption()
	_build_letter()
	_build_title()
	_build_audio()
	get_viewport().size_changed.connect(_layout)
	_layout()

# ---------------------------------------------------------------- UI pieces

func _text(parent: Node, size: int, colour: Color, heading := false) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	if heading: label.add_theme_font_override("font", KenneyTheme.heading_font())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _card(colour: Color, border: Color, radius := 14) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 14
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_view.add_child(panel)
	return panel

func _build_caption() -> void:
	caption_card = _card(Color(0.03, 0.05, 0.09, 0.86), Color(1, 1, 1, 0.14))
	# A bar in the speaker's colour beside the words.
	caption_accent = ColorRect.new()
	caption_accent.position = Vector2(18, 18)
	caption_accent.size.x = 3
	caption_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_card.add_child(caption_accent)
	caption_name = _text(caption_card, 21, Color.WHITE, true)
	caption_name.position = Vector2(36, 14)
	caption_text = _text(caption_card, 22, Color("f1f5f9"))
	caption_text.position = Vector2(36, 48)
	caption_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_card.modulate.a = 0.0

## Sizes the caption card to its words, so two lines never touch the edge.
func _fit_caption() -> void:
	var view := get_viewport().get_visible_rect().size
	var width := minf(view.x - 48, 900.0)
	var words_width := width - 66
	var font := caption_text.get_theme_font("font")
	var tall := font.get_multiline_string_size(caption_text.text, HORIZONTAL_ALIGNMENT_LEFT, words_width, 22).y
	caption_text.size = Vector2(words_width, tall)
	caption_card.size = Vector2(width, 48 + tall + 22)
	caption_card.position = Vector2((view.x - width) * 0.5, view.y - caption_card.size.y - 30)
	caption_accent.size.y = caption_card.size.y - 36

func _build_letter() -> void:
	letter_card = _card(Color(0.93, 0.87, 0.72), Color(0.55, 0.4, 0.2), 6)
	letter_label = _text(letter_card, 25, Color(0.2, 0.12, 0.06))
	letter_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	letter_label.position = Vector2(34, 28)
	letter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	letter_card.modulate.a = 0.0

func _build_title() -> void:
	title_label = _text(stage_view, 64, Color("fde68a"), true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = "DHOLKARPUR GAON"
	sub_label = _text(stage_view, 24, Color("e2e8f0"))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.text = "Day 1  -  Find work. Build a life."
	skip_label = _text(stage_view, 15, Color(1, 1, 1, 0.55))
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.text = "Press any key to skip"
	title_label.modulate.a = 0.0
	sub_label.modulate.a = 0.0
	skip_label.modulate.a = 0.0

func _layout() -> void:
	if not is_instance_valid(stage_view): return
	var view := get_viewport().get_visible_rect().size
	_fit_caption()
	var compact := view.x < 760
	var paper := Vector2(minf(view.x - 60, 560.0), 330.0)
	letter_card.size = paper
	letter_card.position = (view - paper) * 0.5 - Vector2(0, 26)
	# Held a little crooked, like a real letter.
	letter_card.pivot_offset = paper * 0.5
	letter_card.rotation = -0.025
	letter_label.size = paper - Vector2(68, 56)
	title_label.add_theme_font_size_override("font_size", 38 if compact else 64)
	title_label.size = Vector2(view.x, 90)
	title_label.position = Vector2(0, view.y * 0.38)
	sub_label.size = Vector2(view.x, 36)
	sub_label.position = Vector2(0, view.y * 0.38 + (60 if compact else 96))
	skip_label.size = Vector2(300, 22)
	skip_label.position = Vector2(view.x - 320, 16)

func _build_audio() -> void:
	hum = AudioStreamPlayer.new()
	hum.stream = _engine_hum()
	hum.volume_db = -80.0
	add_child(hum)
	hum.play()
	chime = AudioStreamPlayer.new()
	chime.stream = _chime()
	chime.volume_db = -6.0
	add_child(chime)
	thump = AudioStreamPlayer.new()
	thump.stream = _thump()
	thump.volume_db = -2.0
	add_child(thump)
	voice = AudioStreamPlayer.new()
	voice.name = "Voice"
	add_child(voice)

## Plays the voice line `id`, if it has been made.
func _say(id: String) -> void:
	var stream := Voice.stream(id)
	if stream == null: return
	voice.stream = stream
	voice.play()

## A looping low rumble: a 70 Hz drone with filtered noise on top.
func _engine_hum() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var count := stream.mix_rate * 2
	stream.loop_end = count
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	for index in range(count):
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.08
		var drone := sin(TAU * 70.0 * index / stream.mix_rate) * 0.5 + sin(TAU * 140.0 * index / stream.mix_rate) * 0.18
		pcm.encode_s16(index * 2, int((drone * 0.6 + low * 0.9) * 5200))
	stream.data = pcm
	return stream

## The cabin "ding-dong" before an announcement.
func _chime() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(stream.mix_rate * 1.6)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for index in range(count):
		var seconds := float(index) / stream.mix_rate
		var note := 1046.5 if seconds < 0.55 else 783.99
		var local := seconds if seconds < 0.55 else seconds - 0.55
		var envelope := exp(-local * 3.2) * clampf(local * 80.0, 0.0, 1.0)
		var sample := (sin(TAU * note * seconds) + sin(TAU * note * 2.0 * seconds) * 0.25) * envelope
		pcm.encode_s16(index * 2, int(sample * 9000))
	stream.data = pcm
	return stream

## The wheels hitting the runway: a short low thud.
func _thump() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(stream.mix_rate * 0.9)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for index in range(count):
		var seconds := float(index) / stream.mix_rate
		var envelope := exp(-seconds * 7.0)
		var sample := (sin(TAU * 55.0 * seconds) * 0.8 + rng.randf_range(-1.0, 1.0) * 0.35) * envelope
		pcm.encode_s16(index * 2, int(sample * 14000))
	stream.data = pcm
	return stream

# ---------------------------------------------------------------- timeline

func _process(delta: float) -> void:
	if done: return
	clock += delta
	if skipping:
		skip_time += delta
		if skip_time >= SKIP_FADE: _finish()
	_update_audio()
	_update_captions()
	_update_title()
	skip_label.modulate.a = clampf((clock - 1.5) * 0.5, 0.0, 1.0) * (0.0 if clock > TITLE_START else 1.0)
	if clock >= TOTAL: _finish()
	stage_view.queue_redraw()

func _update_audio() -> void:
	var volume := -80.0
	if clock > 0.2: volume = lerpf(-80.0, -17.0, clampf((clock - 0.2) / 3.0, 0.0, 1.0))
	if clock > TOUCHDOWN - 3.0: volume = lerpf(-17.0, -80.0, clampf((clock - TOUCHDOWN + 3.0) / 4.0, 0.0, 1.0))
	# The engine hum steps back while someone speaks.
	if voice.playing: volume -= 6.0
	if skipping: volume -= 60.0 * clampf(skip_time / SKIP_FADE, 0.0, 1.0)
	hum.volume_db = volume
	voice.volume_db = linear_to_db(maxf(0.001, 1.0 - skip_time / SKIP_FADE)) if skipping else 0.0
	if not letter_spoken and clock >= LETTER_START + 0.6:
		letter_spoken = true
		_say("dadaji_letter")
	if not chime_played and clock >= CHIME_AT:
		chime_played = true
		chime.play()
	if not thump_played and clock >= TOUCHDOWN:
		thump_played = true
		thump.play()

func _update_captions() -> void:
	var active := -1
	for index in range(LINES.size()):
		if clock >= LINES[index][0] and clock < LINES[index][1]: active = index
	var letter_on := clock >= LETTER_START and clock < LETTER_END
	letter_card.modulate.a = _fade(clock, LETTER_START, LETTER_END, 0.8)
	if letter_on:
		letter_label.visible_characters = int((clock - LETTER_START - 0.6) * 26.0)
		letter_label.text = LETTER
	if active == -1:
		caption_card.modulate.a = move_toward(caption_card.modulate.a, 0.0, get_process_delta_time() * 4.0)
		return
	var line: Array = LINES[active]
	if active != last_line:
		last_line = active
		caption_name.text = line[2]
		caption_name.add_theme_color_override("font_color", line[3])
		caption_text.text = line[4] % _money_text() if "%s" in line[4] else line[4]
		caption_text.visible_characters = 0
		caption_accent.color = line[3]
		_fit_caption()
		_say(line[5])
	caption_text.visible_characters = int((clock - line[0]) * TYPE_SPEED)
	caption_card.modulate.a = _fade(clock, line[0], line[1], 0.5)

func _update_title() -> void:
	var alpha := 0.0
	if clock >= TITLE_START: alpha = _fade(clock, TITLE_START, TOTAL - 0.2, 1.0)
	title_label.modulate.a = alpha
	sub_label.modulate.a = clampf(alpha * 2.0 - 0.6, 0.0, 1.0)

## The money you really start with (it depends on the difficulty).
func _money_amount() -> int:
	var scene := get_tree().current_scene
	var area = scene.get_node_or_null("Shop/ShopArea") if scene != null else null
	return int(area.business.money) if area != null else 10000

## The starting money as "₹10,000".
func _money_text() -> String:
	var digits := str(_money_amount())
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return String.chr(Rupee) + digits + grouped

## 0 -> 1 over the first `ramp` seconds of a span and back to 0 over the last `ramp`.
func _fade(now: float, start: float, end: float, ramp: float) -> float:
	return clampf(minf((now - start) / ramp, (end - now) / ramp), 0.0, 1.0)

func _input(event: InputEvent) -> void:
	if done: return
	get_viewport().set_input_as_handled()
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed
	var pad: bool = event is InputEventJoypadButton and event.pressed
	if (key or click or pad) and clock > 0.8: skipping = true

func _finish() -> void:
	if done: return
	done = true
	hum.stop()
	voice.stop()
	_place_player()
	var tree := get_tree()
	tree.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var scene := tree.current_scene
	var ui = scene.get_node_or_null("Ui") if scene != null else null
	if ui != null and ui.has_method("show_feedback"):
		ui.show_feedback("Welcome to Dholkarpur! Follow the gold marker to Apna Mart and talk to the shop owner, Seth Ramlal.")
	var fade := create_tween()
	fade.tween_property(stage_view, "modulate:a", 0.0, 0.9)
	fade.tween_callback(queue_free)
	finished.emit()

## The airport: the end of Airport Road, facing the town.
func _place_player() -> void:
	if teleported: return
	teleported = true
	var scene := get_tree().current_scene
	var player = scene.get_node_or_null("Player") if scene != null else null
	if player == null: return
	player.global_position = AIRPORT_SPOT
	player.velocity = Vector3.ZERO
	player.rotation.y = AIRPORT_YAW
	var pivot = player.get_node_or_null("CameraPivot")
	if pivot != null: pivot.rotation.x = 0.0

# ---------------------------------------------------------------- drawing

## Sky colours over the story: night, dawn, morning.
func _sky_colours() -> Array:
	var night := [Color(0.015, 0.025, 0.08), Color(0.07, 0.09, 0.2)]
	var dawn := [Color(0.18, 0.26, 0.55), Color(1.0, 0.58, 0.3)]
	var day := [Color(0.3, 0.58, 0.92), Color(0.82, 0.92, 1.0)]
	var first := clampf((clock - DESCENT_START) / 9.0, 0.0, 1.0)
	var second := clampf((clock - CLOUD_PASS) / 7.0, 0.0, 1.0)
	var top: Color = night[0].lerp(dawn[0], first).lerp(day[0], second)
	var bottom: Color = night[1].lerp(dawn[1], first).lerp(day[1], second)
	return [top, bottom]

func _night_amount() -> float:
	return 1.0 - clampf((clock - DESCENT_START) / 7.0, 0.0, 1.0)

## How far the window has opened out to the whole screen (1 at touchdown).
func _zoom() -> float:
	return smoothstep(0.0, 1.0, clampf((clock - ZOOM_START) / (TOUCHDOWN - ZOOM_START), 0.0, 1.0))

func _window_rect(view: Vector2) -> Rect2:
	var zoom := _zoom()
	var base := Vector2(minf(view.x * 0.7, view.y * 1.05), view.y * 0.66)
	var size := base.lerp(view * 1.3, zoom)
	var centre := Vector2(view.x * 0.5, view.y * 0.42).lerp(view * 0.5, zoom)
	return Rect2(centre - size * 0.5, size)

func _rounded(rect: Rect2, radius: float, steps := 14) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [
		[rect.position + Vector2(rect.size.x - radius, radius), -PI / 2],
		[rect.position + rect.size - Vector2(radius, radius), 0.0],
		[rect.position + Vector2(radius, rect.size.y - radius), PI / 2],
		[rect.position + Vector2(radius, radius), PI],
	]
	for corner in corners:
		for step in range(steps + 1):
			var angle: float = corner[1] + (PI / 2) * step / steps
			points.append(corner[0] + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _draw_stage() -> void:
	var view := stage_view.size
	if view.x < 2.0: return
	# Cabin wall behind the window.
	stage_view.draw_rect(Rect2(Vector2.ZERO, view), CABIN)
	var window := _window_rect(view)
	var zoom := _zoom()
	var radius := lerpf(minf(window.size.x, window.size.y) * 0.34, 40.0, zoom)
	var outline := _rounded(window, radius)
	_draw_cabin(view, window, zoom)
	_draw_world(view, window, outline, zoom)
	_draw_frame(window, outline, radius, zoom)
	_draw_shade(window, outline)
	_draw_overlays(view)

func _draw_cabin(view: Vector2, window: Rect2, zoom: float) -> void:
	if zoom > 0.98: return
	# Soft cabin light falling from the reading lamp, and the dark seat backs.
	var lamp := Color(0.6, 0.5, 0.35, 0.07 * (1.0 - zoom))
	stage_view.draw_circle(Vector2(view.x * 0.18, view.y * 0.1), view.y * 0.55, lamp)
	stage_view.draw_circle(Vector2(view.x * 0.18, view.y * 0.1), view.y * 0.32, lamp)

func _draw_world(view: Vector2, window: Rect2, outline: PackedVector2Array, zoom: float) -> void:
	var colours := _sky_colours()
	var top: Color = colours[0]
	var bottom: Color = colours[1]
	# Everything in the window is drawn as fans/strips clipped to the outline by drawing the
	# sky first (the outline polygon), then the layers inside a clip rect through the frame.
	var colour_list := PackedColorArray()
	for point in outline:
		var t := clampf((point.y - window.position.y) / window.size.y, 0.0, 1.0)
		colour_list.append(top.lerp(bottom, t))
	stage_view.draw_polygon(outline, colour_list)
	var sway := Vector2(sin(clock * 0.9) * 3.0, sin(clock * 1.7) * 2.0) * (1.0 - zoom * 0.7)
	# Stars and the moon.
	var night := _night_amount()
	if night > 0.01:
		for star in stars:
			var at := window.position + Vector2(star.x, star.y) * window.size + sway * 0.3
			if not Geometry2D.is_point_in_polygon(at, outline): continue
			var twinkle := 0.55 + 0.45 * sin(clock * 2.0 + star.z * 3.0)
			stage_view.draw_circle(at, 1.2 + star.z * 0.12, Color(1, 1, 1, night * twinkle))
		var moon := window.position + window.size * Vector2(0.78, 0.2) + sway * 0.4
		_draw_clipped_circle(moon, window.size.y * 0.075, Color(0.95, 0.95, 0.85, night * 0.95), outline)
		_draw_clipped_circle(moon + Vector2(window.size.y * 0.03, -window.size.y * 0.01), window.size.y * 0.066, top.lerp(bottom, 0.2), outline)
	# The sun comes up over the horizon in the dawn.
	var descent := clampf((clock - DESCENT_START) / (TOUCHDOWN - DESCENT_START), 0.0, 1.0)
	var horizon := window.position.y + window.size.y * lerpf(1.25, 0.76, smoothstep(0.0, 1.0, descent))
	var sun_rise := clampf((clock - DESCENT_START + 2.0) / 10.0, 0.0, 1.0)
	if sun_rise > 0.0:
		var sun := Vector2(window.position.x + window.size.x * 0.32, lerpf(horizon + 40.0, horizon - window.size.y * 0.26, smoothstep(0.0, 1.0, sun_rise)))
		var glow := Color(1.0, 0.82, 0.5)
		for ring in range(5):
			_draw_clipped_circle(sun, window.size.y * (0.09 + ring * 0.07), Color(glow.r, glow.g, glow.b, 0.12 - ring * 0.02), outline)
		_draw_clipped_circle(sun, window.size.y * 0.07, Color(1.0, 0.95, 0.75), outline)
	_draw_ground(window, outline, horizon, descent)
	_draw_clouds(window, outline, sway)
	# Whiteout as the plane passes through the cloud deck.
	var pass_amount := _fade(clock, CLOUD_PASS - 2.5, CLOUD_PASS + 2.5, 2.5)
	if pass_amount > 0.0:
		stage_view.draw_polygon(outline, PackedColorArray([Color(1, 1, 1, pass_amount * 0.85)]))
	_draw_wing(window, outline, sway, zoom)

func _draw_ground(window: Rect2, outline: PackedVector2Array, horizon: float, descent: float) -> void:
	if horizon > window.end.y + 4.0: return
	var tilt := sin(clock * 0.35) * 0.04 * (1.0 - descent * 0.6)
	var left := window.position.x - 40.0
	var right := window.end.x + 40.0
	var layers := [
		[0.0, Color(0.36, 0.52, 0.34), 0.05, 0.9],
		[0.22, Color(0.28, 0.46, 0.27), 0.08, 1.4],
		[0.55, Color(0.2, 0.38, 0.2), 0.12, 2.1],
	]
	var shade_fraction := clampf((clock - DESCENT_START) / 14.0, 0.0, 1.0)
	for band in layers:
		var poly := PackedVector2Array()
		var base: float = horizon + window.size.y * band[0] * 0.5
		for step in range(0, 41):
			var x := lerpf(left, right, step / 40.0)
			var wave: float = sin(x * 0.012 * band[3] + band[0] * 9.0) * window.size.y * band[2] * 0.4
			wave += sin(x * 0.031 * band[3]) * window.size.y * band[2] * 0.15
			poly.append(Vector2(x, base + wave + (x - window.get_center().x) * tilt))
		poly.append(Vector2(right, window.end.y + 60))
		poly.append(Vector2(left, window.end.y + 60))
		var colour: Color = band[1]
		# Dark blue in the night, green in the day.
		colour = Color(0.05, 0.08, 0.12).lerp(colour, shade_fraction)
		_draw_clipped(poly, colour, outline)
	# Fields and a river between the hills as the town gets close.
	if descent > 0.45:
		var amount := clampf((descent - 0.45) * 2.0, 0.0, 1.0)
		for patch in range(9):
			var px := window.position.x + window.size.x * (0.1 + patch * 0.1)
			var py := horizon + window.size.y * (0.1 + (patch % 3) * 0.07)
			var rect := PackedVector2Array([Vector2(px, py), Vector2(px + 54, py + 2), Vector2(px + 62, py + 16), Vector2(px - 6, py + 14)])
			_draw_clipped(rect, Color(0.78, 0.72, 0.3, amount * 0.55) if patch % 2 == 0 else Color(0.45, 0.62, 0.28, amount * 0.55), outline)
		var river := PackedVector2Array()
		for step in range(0, 21):
			river.append(Vector2(lerpf(left, right, step / 20.0), horizon + window.size.y * 0.2 + sin(step * 0.5) * 10.0))
		for step in range(20, -1, -1):
			river.append(Vector2(lerpf(left, right, step / 20.0), horizon + window.size.y * 0.24 + sin(step * 0.5) * 10.0))
		_draw_clipped(river, Color(0.45, 0.7, 0.9, amount * 0.7), outline)

func _draw_clouds(window: Rect2, outline: PackedVector2Array, sway: Vector2) -> void:
	var night := _night_amount()
	var bottom: Color = _sky_colours()[1]
	var lit := Color(0.32, 0.36, 0.52).lerp(Color(1, 0.93, 0.85), clampf((clock - DESCENT_START) / 8.0, 0.0, 1.0))
	var base := Color(0.12, 0.15, 0.27).lerp(bottom.lightened(0.15), 1.0 - night)
	# Dropping through the clouds: they stream upward faster and faster.
	var descent_speed := clampf((clock - DESCENT_START) / 6.0, 0.0, 1.0)
	for cloud in clouds:
		var depth: float = cloud.speed
		var x: float = fposmod(cloud.x - clock * 0.012 * depth, 1.2) - 0.1
		var y: float = fposmod(cloud.y * 1.0 + clock * 0.02 * depth * descent_speed * 2.5, 1.25) - 0.1
		var centre := window.position + Vector2(x, y) * window.size + sway * depth * 0.6
		var radius: float = window.size.y * 0.075 * cloud.scale
		var colour := base.lerp(lit, 0.55 + 0.35 * cloud.seed)
		colour.a = 0.9
		for blob in range(4):
			var shift := Vector2((blob - 1.5) * radius * 0.95, -sin(blob * 1.3 + cloud.seed * 6.0) * radius * 0.28)
			var puff: float = radius * (0.8 + 0.2 * sin(blob * 2.1 + cloud.seed * 5.0))
			_draw_clipped_circle(centre + shift, puff, colour, outline)

func _draw_wing(window: Rect2, outline: PackedVector2Array, sway: Vector2, zoom: float) -> void:
	# The wing sticks out below the window frame, flexing slightly.
	var flex := sin(clock * 1.3) * 5.0 + sin(clock * 4.1) * 1.2
	var fade := 1.0 - clampf(zoom * 1.5, 0.0, 1.0)
	if fade <= 0.0: return
	var origin := window.position + Vector2(window.size.x * 0.02, window.size.y * 0.97)
	var wing := PackedVector2Array([
		origin + Vector2(0, 0),
		origin + Vector2(window.size.x * 0.55, -window.size.y * 0.1 + flex),
		origin + Vector2(window.size.x * 0.92, -window.size.y * 0.22 + flex * 2.2),
		origin + Vector2(window.size.x * 0.95, -window.size.y * 0.205 + flex * 2.2),
		origin + Vector2(window.size.x * 0.6, -window.size.y * 0.02 + flex),
		origin + Vector2(window.size.x * 0.3, window.size.y * 0.1),
		origin + Vector2(0, window.size.y * 0.12),
	])
	var daylight := 1.0 - _night_amount()
	var metal := Color(0.22, 0.25, 0.3).lerp(Color(0.62, 0.66, 0.72), daylight)
	_draw_clipped(wing, Color(metal.r, metal.g, metal.b, fade), outline)
	var edge := PackedVector2Array([wing[1], wing[2], wing[3], wing[4]])
	_draw_clipped(edge, Color(metal.lightened(0.18).r, metal.lightened(0.18).g, metal.lightened(0.18).b, fade), outline)
	# Navigation light (red) and strobe (white) at the wing tip.
	var tip: Vector2 = wing[2] + Vector2(-4, -2)
	if Geometry2D.is_point_in_polygon(tip, outline):
		var blink := 1.0 if fmod(clock, 1.5) < 0.12 else 0.0
		var steady := 0.75 + 0.25 * sin(clock * 3.0)
		stage_view.draw_circle(tip, 11.0, Color(1, 0.1, 0.1, 0.18 * steady * fade))
		stage_view.draw_circle(tip, 4.5, Color(1, 0.2, 0.2, steady * fade))
		if blink > 0.0:
			stage_view.draw_circle(tip + Vector2(-16, 6), 18.0, Color(1, 1, 1, 0.3 * fade))
			stage_view.draw_circle(tip + Vector2(-16, 6), 5.0, Color(1, 1, 1, fade))

func _draw_frame(window: Rect2, outline: PackedVector2Array, radius: float, zoom: float) -> void:
	# Plastic bezel with a light edge, plus a thin inner shadow on the glass.
	var bezel := _rounded(window.grow(-2.0), maxf(radius - 2.0, 8.0))
	var closed := outline.duplicate()
	closed.append(outline[0])
	var width := lerpf(10.0, 2.0, zoom)
	stage_view.draw_polyline(closed, BEZEL, width * 2.0, true)
	stage_view.draw_polyline(closed, Color(0.34, 0.36, 0.42, 0.9), 2.0, true)
	var inner_closed := bezel.duplicate()
	inner_closed.append(bezel[0])
	stage_view.draw_polyline(inner_closed, Color(0, 0, 0, 0.45), 6.0, true)

func _draw_shade(window: Rect2, outline: PackedVector2Array) -> void:
	# The window shade slides up when the story begins.
	var open := smoothstep(0.0, 1.0, clampf((clock - 0.9) / 2.2, 0.0, 1.0))
	if open >= 1.0: return
	var shade := Rect2(window.position - Vector2(20, 20), Vector2(window.size.x + 40, (window.size.y + 40) * (1.0 - open)))
	var rect := PackedVector2Array([shade.position, Vector2(shade.end.x, shade.position.y), shade.end, Vector2(shade.position.x, shade.end.y)])
	_draw_clipped(rect, Color(0.78, 0.76, 0.7), outline)
	var grip := Vector2(window.get_center().x, shade.end.y - 12.0)
	if Geometry2D.is_point_in_polygon(grip, outline):
		stage_view.draw_rect(Rect2(grip - Vector2(34, 5), Vector2(68, 10)), Color(0.55, 0.53, 0.48))

func _draw_overlays(view: Vector2) -> void:
	# Fade in from black at the start, vignette throughout, white flash and fade at the end.
	var vignette := 0.0 if clock > TOUCHDOWN else 1.0
	if vignette > 0.0:
		var edge := Color(0, 0, 0, 0.35)
		stage_view.draw_rect(Rect2(0, 0, view.x, view.y * 0.06), edge)
		stage_view.draw_rect(Rect2(0, view.y * 0.94, view.x, view.y * 0.06), edge)
	var black := 1.0 - clampf(clock / 1.6, 0.0, 1.0)
	if clock >= TOUCHDOWN:
		var flash := clampf(1.0 - (clock - TOUCHDOWN) / 0.5, 0.0, 1.0)
		var to_black := smoothstep(0.0, 1.0, clampf((clock - TOUCHDOWN) / 1.2, 0.0, 1.0))
		stage_view.draw_rect(Rect2(Vector2.ZERO, view), Color(0.02, 0.02, 0.03, to_black))
		if flash > 0.0: stage_view.draw_rect(Rect2(Vector2.ZERO, view), Color(1, 1, 1, flash))
	if black > 0.0: stage_view.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, black))
	if skipping: stage_view.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, clampf(skip_time / SKIP_FADE, 0.0, 1.0)))
	# A small camera shake at touchdown is done by nudging the whole control.
	var shake := clampf(1.0 - (clock - TOUCHDOWN) / 0.8, 0.0, 1.0) if clock >= TOUCHDOWN else 0.0
	stage_view.position = Vector2(sin(clock * 90.0), cos(clock * 77.0)) * 7.0 * shake

# -- clipping helpers: shapes are intersected with the window outline so nothing leaks out

func _draw_clipped(polygon: PackedVector2Array, colour: Color, outline: PackedVector2Array) -> void:
	for piece in Geometry2D.intersect_polygons(polygon, outline):
		if piece.size() < 3: continue
		var colours := PackedColorArray()
		colours.append(colour)
		stage_view.draw_polygon(piece, colours)

func _draw_clipped_circle(centre: Vector2, radius: float, colour: Color, outline: PackedVector2Array) -> void:
	var circle := PackedVector2Array()
	var sides := 28 if radius > 40.0 else 14
	for step in range(sides): circle.append(centre + Vector2(cos(TAU * step / sides), sin(TAU * step / sides)) * radius)
	_draw_clipped(circle, colour, outline)
