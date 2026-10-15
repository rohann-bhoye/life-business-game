extends Node

# Shop sound effects using Kenney CC0 audio (assets/audio/kenney), with the old
# generated tones as a fallback if a file is missing. Also plays the player's
# footsteps and a click for every UI button in the scene.
const AUDIO := "res://assets/audio/kenney/%s.ogg"
const FILES := {"scan": "select_002", "payment": "handleCoins", "door": "bong_001", "delivery": "impactGeneric_light_002", "stock": "drop_002", "click": "click_002"}
const VOLUMES := {"scan": -10.0, "payment": -6.0, "door": -12.0, "delivery": -6.0, "stock": -8.0, "click": -14.0}
const STEP_INTERVAL := 0.42

var streams := {}
var footsteps: Array[AudioStream] = []
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var step_player: AudioStreamPlayer
var step_timer := 0.0
var player_body: CharacterBody3D

func _ready() -> void:
	for index in range(4):
		var player := AudioStreamPlayer.new()
		player.name = "Effect%d" % index
		player.volume_db = -18
		add_child(player)
		players.append(player)
	var fallback := {"scan": [1200, 0.08], "payment": [740, 0.22], "door": [240, 0.12], "delivery": [440, 0.3], "stock": [520, 0.07], "click": [900, 0.03]}
	for effect in FILES:
		var path: String = AUDIO % FILES[effect]
		streams[effect] = load(path) if ResourceLoader.exists(path) else _tone(fallback[effect][0], fallback[effect][1])
	for index in range(5):
		var path := AUDIO % ("footstep_concrete_%03d" % index)
		if ResourceLoader.exists(path): footsteps.append(load(path))
	step_player = AudioStreamPlayer.new()
	step_player.name = "Footsteps"
	step_player.volume_db = -16
	add_child(step_player)
	player_body = get_tree().current_scene.get_node_or_null("Player") as CharacterBody3D
	# Button clicks for menus, the tablet and the PC (including ones created later).
	for node in get_tree().current_scene.find_children("*", "BaseButton", true, false): _hook_button(node)
	get_tree().node_added.connect(_hook_button)

func _hook_button(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_on_button_pressed):
		node.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	play_effect("click")

func _tone(frequency: float, duration: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(duration * stream.mix_rate)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for index in range(count):
		var envelope := sin(PI * index / count)
		var sample := int(sin(TAU * frequency * index / stream.mix_rate) * envelope * 10000)
		pcm.encode_s16(index * 2, sample)
	stream.data = pcm
	return stream

func play_effect(effect: String) -> void:
	if not streams.has(effect): return
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stream = streams[effect]
	player.volume_db = VOLUMES.get(effect, -10.0) if not streams[effect] is AudioStreamWAV else -18.0
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()

func _process(delta: float) -> void:
	if footsteps.is_empty() or not is_instance_valid(player_body): return
	var moving := Vector2(player_body.velocity.x, player_body.velocity.z).length() > 0.5 and player_body.is_on_floor()
	if not moving:
		step_timer = 0.1
		return
	step_timer -= delta
	if step_timer <= 0.0:
		step_timer = STEP_INTERVAL
		step_player.stream = footsteps.pick_random()
		step_player.pitch_scale = randf_range(0.9, 1.1)
		step_player.play()
