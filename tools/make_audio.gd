extends SceneTree

# Composes the game's original music and ambience and saves them as WAV files in
# assets/audio/generated/ (no third-party audio, so no licence questions).
#  - music_nature.wav: calm, smooth nature music for the whole game (soft warm pads,
#    a gentle flute melody, kalimba notes, a little stream and birds); seamless loop
#  - ambience_street.wav: breeze, birds, distant traffic and an occasional horn
#  - ambience_night.wav: crickets and a soft night breeze
#  - rain.wav: steady rain for rainy days
# Run once: Godot --headless --path . --script res://tools/make_audio.gd
const RATE := 22050
const KEY := 196.0
# Major pentatonic (G A B D E) over two octaves for the melody.
const PENTATONIC := [1.0, 9.0 / 8.0, 5.0 / 4.0, 3.0 / 2.0, 5.0 / 3.0, 2.0, 9.0 / 4.0, 5.0 / 2.0, 3.0, 10.0 / 3.0]
# G - Em - C - D, eight seconds each (ratios to KEY).
const CHORDS := [[1.0, 5.0 / 4.0, 3.0 / 2.0], [5.0 / 6.0, 1.0, 5.0 / 4.0], [2.0 / 3.0, 5.0 / 6.0, 1.0], [9.0 / 16.0, 45.0 / 64.0, 27.0 / 32.0]]
const CHORD_SECONDS := 8.0
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio/generated"))
	_save("music_nature", _nature_music(96.0))
	_save("ambience_street", _street(24.0))
	_save("ambience_night", _night(16.0))
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

func _nature_music(seconds: float) -> PackedFloat32Array:
	rng.seed = 2026
	var fade := 3.0
	var out := PackedFloat32Array()
	out.resize(int((seconds + fade) * RATE))
	_pads(out)
	_flute(out, seconds + fade)
	# Kalimba: a soft chord tone now and then, two octaves up.
	var time := 2.0
	while time < seconds + fade - 3.0:
		var chord: Array = CHORDS[int(time / CHORD_SECONDS) % CHORDS.size()]
		_pluck(out, int(time * RATE), KEY * 4.0 * chord[rng.randi_range(0, 2)], 0.07, 0.993, 2.5)
		time += rng.randf_range(2.5, 5.5)
	_stream_and_birds(out)
	# The chords keep cycling past the end, so the tail blends into the start seamlessly.
	return _crossfade(out, fade)

## Warm evolving pads: each chord swells in and out, overlapping the next one.
func _pads(out: PackedFloat32Array) -> void:
	var overlap := 3.0
	var segments := int(ceil(out.size() / float(RATE) / CHORD_SECONDS)) + 1
	for segment in range(-1, segments):
		var chord: Array = CHORDS[posmod(segment, CHORDS.size())]
		var start := segment * CHORD_SECONDS - overlap / 2.0
		var length := CHORD_SECONDS + overlap
		var first := maxi(0, int(start * RATE))
		var last := mini(out.size(), int((start + length) * RATE))
		for index in range(first, last):
			var t := index / float(RATE)
			var local := t - start
			var envelope := minf(1.0, minf(local / overlap, (length - local) / overlap))
			envelope = envelope * envelope * (3.0 - 2.0 * envelope)
			var value := sin(TAU * KEY * chord[0] * 0.5 * t) * 0.5
			for ratio in chord:
				var frequency: float = KEY * ratio
				value += sin(TAU * frequency * t) * 0.32 + sin(TAU * frequency * 1.004 * t) * 0.22 + sin(TAU * frequency * 2.0 * t) * 0.06
			out[index] += value * envelope * 0.16

## A breathy, gently vibrating flute playing a slow pentatonic line with rests.
func _flute(out: PackedFloat32Array, seconds: float) -> void:
	var degree := 5
	var time := 4.0
	var breath := 0.0
	while time < seconds - 4.0:
		if rng.randf() < 0.3:
			time += rng.randf_range(1.5, 3.0)
			continue
		degree = clampi(degree + [-2, -1, -1, 0, 1, 1, 2][rng.randi_range(0, 6)], 0, PENTATONIC.size() - 1)
		var frequency: float = KEY * 2.0 * PENTATONIC[degree]
		var length := [1.5, 2.0, 2.0, 3.0][rng.randi_range(0, 3)] as float
		var first := int(time * RATE)
		var count := mini(int(length * RATE), out.size() - first)
		var phase := 0.0
		for index in range(count):
			var t := index / float(RATE)
			var envelope := minf(1.0, t / 0.35) * minf(1.0, (length - t) / 0.6)
			phase += TAU * frequency * (1.0 + 0.004 * sin(TAU * 5.0 * t) * minf(1.0, t)) / RATE
			breath += (rng.randf_range(-1.0, 1.0) - breath) * 0.1
			out[first + index] += (sin(phase) + 0.18 * sin(2.0 * phase) + 0.05 * sin(3.0 * phase) + breath * 0.06) * envelope * 0.15
		time += length * rng.randf_range(0.85, 1.0)

## A quiet babbling stream and a few distant bird calls.
func _stream_and_birds(out: PackedFloat32Array) -> void:
	var water := 0.0
	var ripple := 0.0
	for index in range(out.size()):
		var t := index / float(RATE)
		var noise := rng.randf_range(-1.0, 1.0)
		water += (noise - water) * 0.08
		ripple += (water - ripple) * 0.3
		out[index] += (water - ripple) * (0.6 + 0.4 * sin(TAU * t / 7.0)) * 0.05
	var time := 3.0
	while time < out.size() / float(RATE) - 1.0:
		var base := rng.randf_range(2200.0, 3200.0)
		for chirp in range(rng.randi_range(2, 3)):
			var start := int((time + chirp * 0.18) * RATE)
			for index in range(mini(int(0.12 * RATE), out.size() - start)):
				var t := index / float(RATE)
				out[start + index] += sin(TAU * (base + 4000.0 * t) * t) * sin(PI * t / 0.12) * 0.035
		time += rng.randf_range(5.0, 10.0)

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

## Crickets (pulsed high tones in little trills) over a soft night breeze.
func _night(seconds: float) -> PackedFloat32Array:
	rng.seed = 5
	var out := PackedFloat32Array()
	out.resize(int((seconds + 2.0) * RATE))
	var wind := 0.0
	for index in range(out.size()):
		wind += (rng.randf_range(-1.0, 1.0) - wind) * 0.015
		out[index] = wind * 0.5
	for cricket in range(3):
		var tone := rng.randf_range(4300.0, 5200.0)
		var gain := [0.08, 0.05, 0.03][cricket] as float
		var time := rng.randf_range(0.0, 0.8)
		while time < seconds + 1.5:
			for pulse in range(3):
				var start := int((time + pulse * 0.05) * RATE)
				for index in range(mini(int(0.03 * RATE), out.size() - start)):
					var t := index / float(RATE)
					out[start + index] += sin(TAU * tone * t) * sin(PI * t / 0.03) * gain
			time += rng.randf_range(0.55, 0.95)
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
