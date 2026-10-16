extends SceneTree

# Composes the game's original music and ambience and saves them as WAV files in
# assets/audio/generated/ (no third-party audio, so no licence questions).
#  - music_lobby.wav: calm tanpura-style drone with slow plucks in Raag Bhupali
#  - music_day.wav:   the same raag, livelier, with soft tabla-like percussion
#  - ambience_street.wav: breeze, birds, distant traffic and an occasional horn
#  - rain.wav: steady rain for rainy days
# Run once: Godot --headless --path . --script res://tools/make_audio.gd
const RATE := 22050
const SA := 196.0
const BHUPALI := [1.0, 9.0 / 8.0, 5.0 / 4.0, 3.0 / 2.0, 5.0 / 3.0, 2.0, 9.0 / 4.0, 5.0 / 2.0]
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio/generated"))
	_save("music_lobby", _music(36.0, 1.5, false, 11))
	_save("music_day", _music(32.0, 0.5, true, 23))
	_save("ambience_street", _street(24.0))
	_save("rain", _rain(12.0))
	print("PASS: generated music and ambience")
	quit()

func _save(name: String, samples: PackedFloat32Array) -> void:
	var peak := 0.0001
	for value in samples: peak = maxf(peak, absf(value))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index in range(samples.size()):
		data.encode_s16(index * 2, int(clampf(samples[index] / peak * 0.7, -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	stream.save_to_wav(ProjectSettings.globalize_path("res://assets/audio/generated/%s.wav" % name))
	print("WROTE %s %.1fs" % [name, samples.size() / float(RATE)])

## Karplus-Strong plucked string added into `out` starting at `start`.
func _pluck(out: PackedFloat32Array, start: int, frequency: float, gain: float, decay := 0.996, length := 2.5) -> void:
	var period := maxi(2, int(RATE / frequency))
	var buffer := PackedFloat32Array()
	buffer.resize(period)
	for index in range(period): buffer[index] = rng.randf_range(-1.0, 1.0)
	var count := mini(int(length * RATE), out.size() - start)
	for index in range(count):
		var slot := index % period
		var value := buffer[slot]
		buffer[slot] = (value + buffer[(slot + 1) % period]) * 0.5 * decay
		out[start + index] += value * gain

func _drone(out: PackedFloat32Array) -> void:
	# Integer frequencies give whole cycles over the loop, so it repeats seamlessly.
	for index in range(out.size()):
		var t := index / float(RATE)
		var swell := 0.75 + 0.25 * sin(TAU * t / out.size() * RATE)
		out[index] += (sin(TAU * 98.0 * t) * 0.10 + sin(TAU * 147.0 * t) * 0.06 + sin(TAU * 196.0 * t) * 0.05) * swell

func _music(seconds: float, step: float, lively: bool, seed: int) -> PackedFloat32Array:
	rng.seed = seed
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	_drone(out)
	# Tanpura cycle: Pa, Sa', Sa', Sa (low), repeating.
	var tanpura := [1.5, 2.0, 2.0, 1.0]
	var time := 0.0
	var index := 0
	while time < seconds - 2.5:
		_pluck(out, int(time * RATE), SA * 0.5 * tanpura[index % 4], 0.22, 0.998, 2.4)
		time += 0.75
		index += 1
	# Melody: a gentle random walk over the raag, resting now and then.
	var degree := 0
	time = 1.0
	while time < seconds - 2.5:
		if rng.randf() > (0.25 if lively else 0.35):
			degree = clampi(degree + [-2, -1, -1, 1, 1, 2][rng.randi_range(0, 5)], 0, BHUPALI.size() - 1)
			_pluck(out, int(time * RATE), SA * BHUPALI[degree] * (2.0 if lively else 1.0), 0.32, 0.995, 2.0)
		time += step * (1.0 if not lively or rng.randf() > 0.2 else 0.5)
	if lively:
		# Soft tabla-like pattern: low "dha" on beats 1 and 5, light "na" ticks between.
		var beat := 0.5
		var count := int((seconds - 1.0) / beat)
		for hit in range(count):
			var start := int(hit * beat * RATE)
			if hit % 8 in [0, 4]: _thump(out, start, 0.5)
			elif hit % 2 == 1: _tick(out, start, 0.08)
	return out

func _thump(out: PackedFloat32Array, start: int, gain: float) -> void:
	for index in range(mini(int(0.35 * RATE), out.size() - start)):
		var t := index / float(RATE)
		out[start + index] += sin(TAU * (90.0 - 40.0 * t) * t) * exp(-t * 12.0) * gain

func _tick(out: PackedFloat32Array, start: int, gain: float) -> void:
	var previous := 0.0
	for index in range(mini(int(0.06 * RATE), out.size() - start)):
		var noise := rng.randf_range(-1.0, 1.0)
		var high := noise - previous
		previous = noise
		out[start + index] += high * exp(-index / float(RATE) * 70.0) * gain

func _crossfade(samples: PackedFloat32Array, fade_seconds: float) -> PackedFloat32Array:
	# Blend the tail into the head so noise-based loops repeat without a click.
	var fade := int(fade_seconds * RATE)
	var length := samples.size() - fade
	var out := samples.slice(0, length)
	for index in range(fade):
		var mix := index / float(fade)
		out[index] = samples[index] * mix + samples[length + index] * (1.0 - mix)
	return out

func _street(seconds: float) -> PackedFloat32Array:
	rng.seed = 7
	var out := PackedFloat32Array()
	out.resize(int((seconds + 2.0) * RATE))
	var wind := 0.0
	var rumble := 0.0
	for index in range(out.size()):
		var t := index / float(RATE)
		wind += (rng.randf_range(-1.0, 1.0) - wind) * 0.02
		rumble += (rng.randf_range(-1.0, 1.0) - rumble) * 0.004
		out[index] = wind * (0.5 + 0.4 * sin(TAU * t / 9.0)) * 0.6 + rumble * 2.2
	# Birds: short rising chirps in little groups.
	var time := 0.5
	while time < seconds:
		var base := rng.randf_range(2600.0, 3800.0)
		for chirp in range(rng.randi_range(2, 4)):
			var start := int((time + chirp * 0.13) * RATE)
			for index in range(mini(int(0.09 * RATE), out.size() - start)):
				var t := index / float(RATE)
				out[start + index] += sin(TAU * (base + 9000.0 * t) * t) * sin(PI * t / 0.09) * 0.12
		time += rng.randf_range(1.2, 3.5)
	# A distant two-tone horn once in the loop.
	var horn := int(13.0 * RATE)
	for index in range(int(0.45 * RATE)):
		var t := index / float(RATE)
		var tone := 420.0 if t < 0.2 else 520.0
		out[horn + index] += signf(sin(TAU * tone * t)) * 0.03 * sin(PI * t / 0.45)
	return _crossfade(out, 2.0)

func _rain(seconds: float) -> PackedFloat32Array:
	rng.seed = 3
	var out := PackedFloat32Array()
	out.resize(int((seconds + 1.5) * RATE))
	var low := 0.0
	for index in range(out.size()):
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.18
		out[index] = low * 0.5 + noise * 0.08
	for drop in range(int(seconds * 40)):
		var start := rng.randi_range(0, out.size() - 400)
		for index in range(300):
			out[start + index] += rng.randf_range(-1.0, 1.0) * exp(-index / 40.0) * 0.25
	return _crossfade(out, 1.5)
