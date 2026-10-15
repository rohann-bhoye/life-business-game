extends Node

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0

func _ready() -> void:
	for index in range(4):
		var player := AudioStreamPlayer.new()
		player.name = "Effect%d" % index
		player.volume_db = -18
		add_child(player)
		players.append(player)
	streams["scan"] = _tone(1200, 0.08)
	streams["payment"] = _tone(740, 0.22)
	streams["door"] = _tone(240, 0.12)
	streams["delivery"] = _tone(440, 0.3)
	streams["stock"] = _tone(520, 0.07)

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
	player.play()
