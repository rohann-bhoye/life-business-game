extends Node

# Cave sound for Gufa Darwaza, made in code (no sound files), played through a
# "Cave" bus with a big reverb so everything echoes. Layers: a low rumble of moving
# air with slow gusts, water drips far off with their echoes, and a tension layer that
# grows as monsters come (set `tension` 0..1 each frame): a deep drone and a heartbeat
# that speeds up. One-shots: play("swing" | "hit" | "break" | "poof" | "alert" | "pick").
const RATE := 22050.0
const BUS := "Cave"

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var tension := 0.0
var _tension := 0.0
var clock := 0.0
var rumble := 0.0
var air := 0.0
var drip_wait := 1.5
var beat := 0.0
var voices: Array[Dictionary] = []
var held: Array[AudioStreamPlayer] = []

func _ready() -> void:
	_bus()
	player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = RATE
	stream.buffer_length = 0.25
	player.stream = stream
	player.bus = BUS
	player.volume_db = -1.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback()
	# The town's music and ambience are paused while down here.
	for node in _town_players():
		node.stream_paused = true
		held.append(node)

func _exit_tree() -> void:
	for node in held:
		if is_instance_valid(node): node.stream_paused = false

func _town_players() -> Array[AudioStreamPlayer]:
	var found: Array[AudioStreamPlayer] = []
	var scene := get_tree().current_scene
	var audio := scene.get_node_or_null("WorldAudio")
	if audio != null:
		for node in audio.find_children("*", "AudioStreamPlayer", true, false): found.append(node)
	var music := get_tree().root.get_node_or_null("BackgroundMusic")
	if music is AudioStreamPlayer: found.append(music)
	return found

func _bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0: return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.9
	reverb.damping = 0.45
	reverb.wet = 0.32
	reverb.dry = 0.85
	AudioServer.add_bus_effect(index, reverb)

func play(kind: String) -> void:
	var delay := 0.0
	if kind == "alert": delay = 0.0
	voices.append({"kind": kind, "t": -delay, "seed": randf()})

func _process(delta: float) -> void:
	_tension = move_toward(_tension, tension, delta * 0.8)
	var frames := playback.get_frames_available()
	for i in range(frames):
		clock += 1.0 / RATE
		var s := _ambience() + _tension_layer() + _voices()
		playback.push_frame(Vector2.ONE * clampf(s, -1.0, 1.0))
	voices = voices.filter(func(v): return v.t < 2.5)

func _ambience() -> float:
	rumble += (randf() * 2.0 - 1.0 - rumble) * 0.012
	air += (rumble - air) * 0.05
	var gust := 0.55 + 0.45 * sin(clock * 0.35) * sin(clock * 0.13 + 1.0)
	var s := air * 1.9 * gust * 0.5
	drip_wait -= 1.0 / RATE
	if drip_wait < 0.0:
		drip_wait = randf_range(1.2, 5.0)
		var pitch := randf_range(1100.0, 2300.0)
		for echo in range(3): voices.append({"kind": "drip", "t": -0.19 * echo, "seed": pitch, "gain": 1.0 / (1 + echo * 1.6)})
	return s

func _tension_layer() -> float:
	if _tension < 0.01: return 0.0
	var drone := (sin(TAU * 46.0 * clock) + 0.6 * sin(TAU * 69.0 * clock + sin(clock * 0.7))) * 0.07
	drone *= _tension * (0.7 + 0.3 * sin(clock * (2.0 + _tension * 5.0)))
	var bpm := lerpf(54.0, 150.0, _tension)
	beat = fmod(beat + bpm / 60.0 / RATE, 1.0)
	var thump := 0.0
	for offset in [0.0, 0.3]:
		var tt := fposmod(beat - offset, 1.0) / (bpm / 60.0)
		if tt < 0.25: thump += sin(TAU * 58.0 * tt) * exp(-tt * 26.0) * (0.55 if offset == 0.0 else 0.35)
	return drone + thump * _tension * 0.8

func _voices() -> float:
	var total := 0.0
	for v in voices:
		v.t += 1.0 / RATE
		var t: float = v.t
		if t < 0.0: continue
		match v.kind:
			"drip":
				total += sin(TAU * v.seed * (1.0 - t * 0.5) * t) * exp(-t * 22.0) * 0.16 * v.gain
			"swing":
				if t < 0.22: total += (randf() * 2.0 - 1.0) * sin(PI * t / 0.22) * 0.13 * (0.4 + t * 3.0)
			"hit":
				total += sin(TAU * 88.0 * t) * exp(-t * 16.0) * 0.55 + (randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.28
			"break":
				total += (randf() * 2.0 - 1.0) * exp(-t * 7.0) * 0.3 * (0.4 + 0.6 * float(fmod(t * 83.0, 1.0) < 0.5)) + sin(TAU * 60.0 * t) * exp(-t * 10.0) * 0.4
			"poof":
				if t < 1.0: total += (randf() * 2.0 - 1.0) * exp(-t * 3.5) * 0.16 * (1.0 - t) + sin(TAU * (520.0 - 380.0 * t) * t) * exp(-t * 4.0) * 0.12
			"alert":
				if t < 0.4: total += (sin(TAU * (880.0 if t < 0.15 else 622.0) * t) + 0.4 * sin(TAU * 1760.0 * t)) * exp(-t * 6.0) * 0.14
			"pick":
				if t < 0.4: total += sin(TAU * (900.0 + 1400.0 * minf(t * 6.0, 1.0)) * t) * exp(-t * 9.0) * 0.14
	return total
