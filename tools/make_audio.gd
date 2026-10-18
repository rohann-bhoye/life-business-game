extends SceneTree

# Composes the game's original music and ambience and saves them as WAV files in
# assets/audio/generated/ (no third-party audio, so no licence questions).
#  - music_indian.wav: calm Indian music for the whole game: a tanpura drone, a
#    bansuri playing raag Bhupali with glides, soft keherwa on the tabla, santoor
#    runs and a few distant birds; a seamless 96 s loop
#  - ambience_street.wav: breeze, birds, distant traffic, an auto-rickshaw and a
#    scooter horn and a far-off temple bell
#  - ambience_night.wav: crickets and a soft night breeze
#  - rain.wav: steady rain for rainy days
# Run once: Godot --headless --path . --script res://tools/make_audio.gd
const RATE := 22050
const SA := 196.0
const BEAT := 0.75
# Raag Bhupali (S R G P D) from lower Dha up to upper Pa, as ratios to Sa.
const BHUPALI := [5.0 / 6.0, 1.0, 9.0 / 8.0, 5.0 / 4.0, 3.0 / 2.0, 5.0 / 3.0, 2.0, 9.0 / 4.0, 5.0 / 2.0, 3.0]
# Bansuri phrases as [degree in BHUPALI, beats]; most come home to Sa or Pa.
const PHRASES := [
	[[3, 1], [2, 1], [1, 1.5], [0, 0.5], [1, 3]],
	[[1, 1], [2, 1], [3, 1], [4, 2], [3, 2]],
	[[3, 1], [4, 1], [5, 1], [6, 2], [5, 1], [4, 2]],
	[[4, 1.5], [3, 0.5], [2, 1], [3, 1], [2, 1], [1, 3]],
	[[5, 1], [6, 1], [7, 1], [6, 1.5], [5, 0.5], [4, 3]],
	[[3, 1], [2, 0.5], [3, 0.5], [4, 2], [3, 1], [2, 1], [1, 2]],
]
# Keherwa, eight beats a cycle (6 s at 80 bpm): Dha Ge Na Ti | Na Ka Dhi Na.
const KEHERWA := ["dha", "ge", "na", "ti", "na", "ka", "dhi", "na"]
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio/generated"))
	_save("music_indian", _indian_music(96.0))
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

func _indian_music(seconds: float) -> PackedFloat32Array:
	rng.seed = 2026
	var fade := 3.0
	var out := PackedFloat32Array()
	out.resize(int((seconds + fade) * RATE))
	_drone(out)
	_tanpura(out)
	_tabla(out)
	_bansuri(out, seconds)
	_santoor(out, seconds)
	_birds(out)
	# Drone, tanpura and tala repeat every 6 s and 96 s holds sixteen cycles, so the
	# tail lines up with the head and the crossfade loops without a seam.
	return _crossfade(out, fade)

## Soft sustained Sa and Pa underneath everything, breathing slowly.
func _drone(out: PackedFloat32Array) -> void:
	for index in range(out.size()):
		var t := index / float(RATE)
		var swell := 0.8 + 0.2 * sin(TAU * t / 12.0)
		var value := sin(TAU * SA * 0.5 * t) * 0.5 + sin(TAU * SA * 0.5 * 1.003 * t) * 0.3 + sin(TAU * SA * 0.75 * t) * 0.25 + sin(TAU * SA * t) * 0.15
		out[index] += value * swell * 0.05

## Tanpura: Pa, Sa, Sa and low Sa plucked round and round, each string ringing long.
func _tanpura(out: PackedFloat32Array) -> void:
	var strings := [SA * 0.75, SA, SA, SA * 0.5]
	for step in range(int(out.size() / float(RATE) / 0.375)):
		_pluck(out, int(step * 0.375 * RATE), strings[step % 4], 0.07 if step % 4 != 3 else 0.09, 0.9992, 3.5, 0.62, 0.35)

## Soft keherwa on the tabla, with a little "tirakita" fill every fourth cycle.
func _tabla(out: PackedFloat32Array) -> void:
	for beat in range(int(out.size() / float(RATE) / BEAT)):
		var cycle := beat / 8
		var position := beat % 8
		var time := beat * BEAT
		var gain := 0.2 if position == 0 else (0.11 if position == 4 else 0.15)
		if cycle % 4 == 3 and position >= 6:
			var fill: Array = ["ti", "ti", "ka", "na"] if position == 6 else ["ti", "ka", "dha", "ge"]
			for stroke in range(4):
				_bol(out, time + stroke * BEAT / 4.0, fill[stroke], gain * 0.8)
			continue
		_bol(out, time, KEHERWA[position], gain)

func _bol(out: PackedFloat32Array, time: float, bol: String, gain: float) -> void:
	var start := int(time * RATE)
	match bol:
		"dha":
			_bayan(out, start, gain)
			_dayan(out, start, gain, 0.3)
		"dhi":
			_bayan(out, start, gain)
			_dayan(out, start, gain * 0.8, 0.18)
		"ge": _bayan(out, start, gain)
		"na": _dayan(out, start, gain, 0.26)
		"ti": _dayan(out, start, gain * 0.7, 0.05)
		"ka": _slap(out, start, gain)

## Bayan (bass drum): a deep tone that rises as the palm presses the skin.
func _bayan(out: PackedFloat32Array, start: int, gain: float) -> void:
	var phase := 0.0
	for index in range(mini(int(0.9 * RATE), out.size() - start)):
		var t := index / float(RATE)
		phase += TAU * (76.0 + 30.0 * (1.0 - exp(-t / 0.12))) / RATE
		out[start + index] += sin(phase) * exp(-t / 0.28) * minf(1.0, t / 0.004) * gain * 1.4

## Dayan (treble drum) tuned to Sa: a ringing tone with harmonic overtones.
func _dayan(out: PackedFloat32Array, start: int, gain: float, ring: float) -> void:
	var frequency := SA * 2.0
	for index in range(mini(int((ring * 4.0 + 0.05) * RATE), out.size() - start)):
		var t := index / float(RATE)
		var value := sin(TAU * frequency * t) * exp(-t / ring) + sin(TAU * frequency * 2.0 * t) * 0.45 * exp(-t / (ring * 0.6))
		value += sin(TAU * frequency * 3.0 * t) * 0.3 * exp(-t / (ring * 0.4)) + sin(TAU * frequency * 4.02 * t) * 0.18 * exp(-t / (ring * 0.3))
		if t < 0.004: value += rng.randf_range(-1.0, 1.0) * 0.5
		out[start + index] += value * gain * 0.5

## "Ka": a flat slap on the bayan, a short thud of noise.
func _slap(out: PackedFloat32Array, start: int, gain: float) -> void:
	var low := 0.0
	for index in range(mini(int(0.08 * RATE), out.size() - start)):
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.25
		out[start + index] += low * exp(-index / (0.018 * RATE)) * gain * 1.6

## Bansuri: Bhupali phrases on the beat, sliding between notes (meend), with a quick
## grace note now and then (kan), slow vibrato on long notes and a breathy tone.
func _bansuri(out: PackedFloat32Array, seconds: float) -> void:
	var time := 8 * BEAT
	var breath := 0.0
	while true:
		var phrase: Array = PHRASES[rng.randi_range(0, PHRASES.size() - 1)]
		var starts: Array[float] = []
		var frequencies: Array[float] = []
		var total := 0.0
		for note in phrase:
			starts.append(total)
			frequencies.append(SA * 2.0 * BHUPALI[note[0]])
			total += note[1] * BEAT
		if time + total > seconds - 4.0: break
		var first := int(time * RATE)
		var phase := 0.0
		var pointer := 0
		var current := frequencies[0]
		var glide_from := current
		var kan := rng.randf() < 0.4
		for index in range(int(total * RATE)):
			var t := index / float(RATE)
			if pointer + 1 < starts.size() and t >= starts[pointer + 1]:
				pointer += 1
				glide_from = current
				kan = rng.randf() < 0.3
			var since := t - starts[pointer]
			var target := frequencies[pointer]
			current = target
			if pointer > 0 and since < 0.16:
				current = lerpf(glide_from, target, smoothstep(0.0, 1.0, since / 0.16))
			elif kan and since < 0.06:
				current = target * 9.0 / 8.0
			var vibrato := 0.006 * sin(TAU * 5.0 * t) * clampf((since - 0.45) / 0.5, 0.0, 1.0)
			phase += TAU * current * (1.0 + vibrato) / RATE
			breath += (rng.randf_range(-1.0, 1.0) - breath) * 0.25
			var envelope := minf(1.0, t / 0.3) * minf(1.0, (total - t) / 0.8)
			var articulation := 0.85 + 0.15 * minf(1.0, since / 0.08)
			out[first + index] += (sin(phase) + 0.12 * sin(2.0 * phase) + 0.04 * sin(3.0 * phase) + breath * 0.14) * envelope * articulation * 0.2
		time += total + rng.randi_range(2, 4) * BEAT

## Santoor: a shimmering run of double-struck high notes every twelve seconds.
func _santoor(out: PackedFloat32Array, seconds: float) -> void:
	var time := 4.5
	while time < seconds - 5.0:
		var degree := rng.randi_range(5, 9)
		var falling := rng.randf() < 0.6
		for note in range(6):
			var frequency: float = SA * 2.0 * BHUPALI[clampi(degree, 1, BHUPALI.size() - 1)]
			for strike in range(2):
				_pluck(out, int((time + note * BEAT / 4.0 + strike * 0.05) * RATE), frequency, 0.05 if strike == 0 else 0.03, 0.9975, 1.4, 0.6)
			degree += -1 if falling else 1
		time += 12.0

## A few distant bird calls.
func _birds(out: PackedFloat32Array) -> void:
	var time := 3.0
	while time < out.size() / float(RATE) - 1.0:
		var base := rng.randf_range(2200.0, 3200.0)
		for chirp in range(rng.randi_range(2, 3)):
			var start := int((time + chirp * 0.18) * RATE)
			for index in range(mini(int(0.12 * RATE), out.size() - start)):
				var t := index / float(RATE)
				out[start + index] += sin(TAU * (base + 4000.0 * t) * t) * sin(PI * t / 0.12) * 0.025
		time += rng.randf_range(7.0, 13.0)

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
