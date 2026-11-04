extends SceneTree

# Composes the game's original music and ambience and saves them as WAV files in
# assets/audio/generated/ (no third-party audio, so no licence questions).
#  - music_indian.wav: calm, smooth music for the whole game (it plays for hours, so
#    nothing in it may nag): warm pad chords that change every 8 s (Cmaj7, Bm7, Am7,
#    Gadd9), a soft low bansuri on the G major pentatonic (raag Bhupali's notes) with long
#    rests, mellow santoor plucks, a faint tanpura and no drums; room reverb and softened
#    highs. A 128 s loop that starts and ends quietly, so the repeat is not heard.
#  - ambience_street.wav: breeze, birds, distant traffic, an auto-rickshaw and a
#    scooter horn and a far-off temple bell
#  - ambience_night.wav: crickets and a soft night breeze
#  - rain.wav: steady rain for rainy days
# Run: Godot --headless --path . --script res://tools/make_audio.gd [-- only=music]
const RATE := 22050
const CHORD_SECONDS := 8.0
const LOOP_SECONDS := 128.0
## Pad chords (Hz, low to high, a soft bass note first), one per 8 s, round and round:
## Cmaj7, Bm7, Am7, Gadd9.
const CHORDS := [
	[65.41, 130.81, 196.0, 246.94, 329.63],
	[61.74, 123.47, 185.0, 220.0, 293.66],
	[55.0, 110.0, 164.81, 196.0, 261.63],
	[49.0, 98.0, 146.83, 220.0, 246.94],
]
## The bansuri's notes, low and warm: G major pentatonic from D4 to D5.
const FLUTE := [293.66, 329.63, 392.0, 440.0, 493.88, 587.33]
## Phrases as [index in FLUTE, beats of 0.9 s]; most come to rest on G or D.
const PHRASES := [
	[[2, 2], [3, 1], [4, 3]],
	[[4, 2], [3, 1], [2, 1], [1, 3]],
	[[1, 1], [2, 1], [3, 2], [2, 3]],
	[[3, 2], [4, 1], [5, 2], [4, 1], [3, 3]],
	[[2, 1.5], [1, 0.5], [0, 1], [1, 1], [2, 4]],
	[[5, 2], [4, 1], [3, 1], [2, 4]],
]
## Santoor arpeggio notes for each chord (mid register, mellow).
const ARPEGGIOS := [
	[261.63, 329.63, 392.0, 493.88],
	[246.94, 293.66, 369.99, 440.0],
	[220.0, 261.63, 329.63, 392.0],
	[196.0, 246.94, 293.66, 440.0],
]
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio/generated"))
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="): only = arg.trim_prefix("only=")
	if only == "" or only == "music": _save("music_indian", _calm_music())
	if only == "" or only == "ambience":
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

## Karplus-Strong plucked string added into `out` starting at `start`. A higher
## `brightness` keeps the overtones ringing; `buzz` adds the tanpura's jawari edge.
func _pluck(out: PackedFloat32Array, start: int, frequency: float, gain: float, decay := 0.996, length := 2.5, brightness := 0.5, buzz := 0.0) -> void:
	var period := maxi(2, int(RATE / frequency))
	var buffer := PackedFloat32Array()
	buffer.resize(period)
	for index in range(period): buffer[index] = rng.randf_range(-1.0, 1.0)
	var count := mini(int(length * RATE), out.size() - start)
	for index in range(count):
		var slot := index % period
		var value := buffer[slot]
		buffer[slot] = (value * brightness + buffer[(slot + 1) % period] * (1.0 - brightness)) * decay
		out[start + index] += (value + buzz * value * absf(value)) * gain


# --- Calm music ---

func _calm_music() -> PackedFloat32Array:
	rng.seed = 2026
	var fade := 4.0
	var out := PackedFloat32Array()
	out.resize(int((LOOP_SECONDS + fade) * RATE))
	_pads(out)
	_tanpura_soft(out)
	_santoor_soft(out)
	_flute(out)
	out = _reverb(out, 0.32)
	_soften(out, 5000.0)
	return _crossfade(out, fade)

## 0 -> 1 over `ramp` seconds after `start` and back to 0 over the last `ramp` seconds
## before `end`, along a smooth curve.
static func _window(t: float, start: float, end: float, ramp: float) -> float:
	return smoothstep(start, start + ramp, t) * (1.0 - smoothstep(end - ramp, end, t))

## Warm pads: each chord swells in over 3 s and lets go over 3 s into the next. Every
## voice is a soft sine with a quiet octave and a slightly detuned twin (a gentle chorus).
func _pads(out: PackedFloat32Array) -> void:
	var count := out.size()
	var chords := int(ceil(count / float(RATE) / CHORD_SECONDS)) + 1
	for index in range(chords):
		var notes: Array = CHORDS[index % CHORDS.size()]
		var start := index * CHORD_SECONDS - 1.5
		var end := start + CHORD_SECONDS + 3.0
		var first := maxi(0, int(start * RATE))
		var last := mini(count, int(end * RATE))
		for voice in range(notes.size()):
			var frequency: float = notes[voice]
			var gain := 0.05 if voice == 0 else 0.032
			var step := TAU * frequency / RATE
			var twin := TAU * frequency * 1.0025 / RATE
			for sample in range(first, last):
				var t := sample / float(RATE)
				var level := _window(t, start, end, 3.0) * (0.92 + 0.08 * sin(TAU * t / 9.0 + voice))
				var value := sin(step * sample) + sin(twin * sample) * 0.6 + sin(step * sample * 2.0) * 0.12
				out[sample] += value * level * gain

## A faint tanpura (D, G, G, low G) without the jawari buzz, slowly round and round.
func _tanpura_soft(out: PackedFloat32Array) -> void:
	var strings := [146.83, 196.0, 196.0, 98.0]
	for step in range(int(out.size() / float(RATE) / 0.9)):
		_pluck(out, int(step * 0.9 * RATE), strings[step % 4], 0.018, 0.9994, 4.0, 0.35, 0.0)

## Mellow santoor: a slow arpeggio on the chord's notes, one note a second with some left
## out, quieter near the start and end of the loop so it begins and ends softly.
func _santoor_soft(out: PackedFloat32Array) -> void:
	var seconds := out.size() / float(RATE)
	var beat := 0
	while beat < seconds - 3.0:
		var time := float(beat)
		var notes: Array = ARPEGGIOS[int(time / CHORD_SECONDS) % ARPEGGIOS.size()]
		var edge := minf(time, LOOP_SECONDS - time)
		var gain := 0.05 * clampf(edge / 24.0, 0.35, 1.0)
		if rng.randf() > 0.28:
			_pluck(out, int((time + rng.randf_range(-0.02, 0.02)) * RATE), notes[beat % notes.size()], gain, 0.9975, 3.0, 0.3)
		beat += 1

## A soft low bansuri: short phrases with long rests, gliding between notes, a breathy
## tone and a slow vibrato on long notes. It rests through the first and last 26 s.
func _flute(out: PackedFloat32Array) -> void:
	var time := 26.0
	while time < LOOP_SECONDS - 26.0:
		var phrase: Array = PHRASES[rng.randi_range(0, PHRASES.size() - 1)]
		var notes := []
		var at := time
		for note in phrase:
			notes.append([at, FLUTE[note[0]], note[1] * 0.9])
			at += note[1] * 0.9
		_flute_phrase(out, notes)
		time = at + rng.randf_range(4.0, 8.0)

## One phrase: `notes` are [start, frequency, seconds].
func _flute_phrase(out: PackedFloat32Array, notes: Array) -> void:
	var start: float = notes[0][0]
	var last: Array = notes[notes.size() - 1]
	var end: float = last[0] + last[2] + 0.6
	var phase := 0.0
	var breath := 0.0
	for sample in range(int(start * RATE), mini(out.size(), int(end * RATE))):
		var t := sample / float(RATE)
		# The note sounding now, gliding over 0.12 s from the one before.
		var index := 0
		while index + 1 < notes.size() and t >= notes[index + 1][0]: index += 1
		var frequency: float = notes[index][1]
		var into: float = t - notes[index][0]
		if index > 0 and into < 0.12: frequency = lerpf(notes[index - 1][1], frequency, into / 0.12)
		frequency *= 1.0 + 0.004 * sin(TAU * 4.8 * t) * smoothstep(0.4, 1.0, into)
		phase += TAU * frequency / RATE
		var level := smoothstep(start, start + 0.25, t) * (1.0 - smoothstep(end - 0.8, end, t))
		breath += (rng.randf_range(-1.0, 1.0) - breath) * 0.08
		var value := sin(phase) + 0.18 * sin(phase * 2.0) + 0.05 * sin(phase * 3.0) + breath * 0.25
		out[sample] += value * level * 0.07

## Room reverb (Schroeder: four damped combs into two all-passes), `wet` of it mixed in.
func _reverb(dry: PackedFloat32Array, wet: float) -> PackedFloat32Array:
	var count := dry.size()
	var sum := PackedFloat32Array()
	sum.resize(count)
	for delay in [1116, 1188, 1277, 1356]:
		var line := PackedFloat32Array()
		line.resize(delay)
		var store := 0.0
		var at := 0
		for index in range(count):
			var held := line[at]
			store = held * 0.75 + store * 0.25
			line[at] = dry[index] + store * 0.8
			sum[index] += held
			at = (at + 1) % delay
	for delay in [278, 113]:
		var line := PackedFloat32Array()
		line.resize(delay)
		var at := 0
		for index in range(count):
			var held := line[at]
			var value := sum[index] + held * 0.5
			line[at] = value
			sum[index] = held - value * 0.5
			at = (at + 1) % delay
	var out := PackedFloat32Array()
	out.resize(count)
	for index in range(count): out[index] = dry[index] + sum[index] * wet * 0.25
	return out

## Takes the edge off the highs: a gentle low-pass at `cutoff` Hz.
func _soften(samples: PackedFloat32Array, cutoff: float) -> void:
	var amount := 1.0 - exp(-TAU * cutoff / RATE)
	var low := 0.0
	for index in range(samples.size()):
		low += (samples[index] - low) * amount
		samples[index] = low

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
	# An auto-rickshaw's nasal double "peep-peep", later a scooter's two-note horn.
	for blip in [5.0, 5.2]:
		var start := int(blip * RATE)
		for index in range(int(0.12 * RATE)):
			var t := index / float(RATE)
			out[start + index] += tanh(sin(TAU * 680.0 * t) * 3.0) * 0.035 * sin(PI * t / 0.12)
	var scooter := int(13.0 * RATE)
	for index in range(int(0.35 * RATE)):
		var t := index / float(RATE)
		out[scooter + index] += (signf(sin(TAU * 410.0 * t)) + signf(sin(TAU * 520.0 * t))) * 0.015 * sin(PI * t / 0.35)
	# A far-off temple bell (ghanti): inharmonic partials ringing out.
	var bell := int(17.0 * RATE)
	for index in range(int(3.0 * RATE)):
		var t := index / float(RATE)
		var ring := 0.0
		for partial in [[1.0, 1.0, 1.6], [2.0, 0.5, 1.1], [3.01, 0.35, 0.7], [4.2, 0.25, 0.45], [5.43, 0.15, 0.3]]:
			ring += sin(TAU * 620.0 * partial[0] * t) * partial[1] * exp(-t / partial[2])
		out[bell + index] += ring * minf(1.0, t / 0.003) * 0.03
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
