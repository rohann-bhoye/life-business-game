extends SceneTree

# Makes spoken lines with Gemini text-to-speech: the intro's (intro_voice.gd, into
# assets/audio/intro/) or another set such as Seth Ramlal's (ramlal_voice.gd, set=ramlal).
# Leading/trailing silence is trimmed and peaks evened out.
# The key comes from the GEMINI_API_KEY environment variable only (never stored in the
# project). From PowerShell, with the key saved for your Windows user (setx):
#   $env:GEMINI_API_KEY = [Environment]::GetEnvironmentVariable("GEMINI_API_KEY","User")
#   & $godot --headless --path . --script res://tools/make_voice.gd
# Options after "--": set=<name> (<name>_voice.gd, default intro), only=<id prefix> (remake
# some lines), force (remake existing files).
# GEMINI_TTS_MODEL picks the model; otherwise the newest Flash TTS model is used. Free keys
# get 10 requests a day per model.
var Voice: Script = preload("res://intro_voice.gd")
const API := "https://generativelanguage.googleapis.com/v1beta/"
const FALLBACK_MODEL := "gemini-2.5-flash-preview-tts"
const PEAK := 0.89  # about -1 dB
var key := ""
var http: HTTPRequest
var quota_hit := false
## The model refused an instruction; acting notes go in the short "Say ...:" form.
var no_instructions := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	key = OS.get_environment("GEMINI_API_KEY").strip_edges()
	if key.is_empty():
		print("NO KEY: set GEMINI_API_KEY first (see the top of tools/make_voice.gd).")
		quit(1)
		return
	http = HTTPRequest.new()
	http.timeout = 120.0
	root.add_child(http)
	var args := OS.get_cmdline_user_args()
	var only := ""
	for arg in args:
		if arg.begins_with("only="): only = arg.trim_prefix("only=")
		if arg.begins_with("set="): Voice = load("res://%s_voice.gd" % arg.trim_prefix("set="))
	var force := "force" in args
	var model := OS.get_environment("GEMINI_TTS_MODEL")
	if model.is_empty(): model = await _pick_model()
	print("MODEL ", model)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Voice.ROOT))
	var made := 0
	var failed := 0
	for job in Voice.jobs():
		var id: String = job[0]
		if only != "" and not id.begins_with(only): continue
		var path: String = Voice.ROOT + id + ".wav"
		if FileAccess.file_exists(path) and not force:
			print("SKIP ", id, " (exists)")
			continue
		var speaker: Array = Voice.SPEAKERS[job[1]]
		var pcm := await _speak(model, speaker[0], speaker[1], speaker[2], job[2])
		if quota_hit:
			print("STOP: Gemini's daily limit is reached. Run again tomorrow; made files are kept.")
			failed += 1
			break
		if pcm.is_empty():
			failed += 1
			continue
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = pcm[1]
		stream.stereo = false
		stream.data = _clean(pcm[0], pcm[1])
		var error := stream.save_to_wav(ProjectSettings.globalize_path(path))
		if error != OK:
			print("FAIL ", id, ": could not save (", error, ")")
			failed += 1
			continue
		made += 1
		print("MADE %s  %.1f s" % [id, stream.data.size() / 2.0 / stream.mix_rate])
	print("DONE made=%d failed=%d" % [made, failed])
	quit(0 if failed == 0 else 1)

## The newest Flash text-to-speech model the key can use (Pro if there is no Flash).
func _pick_model() -> String:
	var reply := await _call(API + "models?pageSize=200", HTTPClient.METHOD_GET, "")
	if reply.is_empty(): return FALLBACK_MODEL
	var names := []
	for entry in reply.get("models", []):
		var name := str(entry.get("name", "")).trim_prefix("models/")
		if "tts" in name and "generateContent" in entry.get("supportedGenerationMethods", []): names.append(name)
	if names.is_empty(): return FALLBACK_MODEL
	names.sort()
	var flash := names.filter(func(name): return "flash" in name)
	return (flash if not flash.is_empty() else names).back()

## [PCM bytes, sample rate] of `text` spoken by `voice`, or [] after a failure. The acting
## `note` goes in as an instruction, not as words (sent with the line, the model read it out
## loud); models without instructions get the `short` form instead, "Say ...: words".
## Busy or rate-limited replies are retried with a growing wait.
func _speak(model: String, voice: String, note: String, short: String, text: String) -> Array:
	for attempt in range(6):
		var request := {
			"contents": [{"parts": [{"text": ("%s: %s" % [short, text]) if no_instructions else text}]}],
			"generationConfig": {
				"responseModalities": ["AUDIO"],
				"speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voice}}},
			},
		}
		if not no_instructions: request["systemInstruction"] = {"parts": [{"text": note + " Speak only the words you are given, nothing else."}]}
		var reply := await _call(API + "models/%s:generateContent" % model, HTTPClient.METHOD_POST, JSON.stringify(request))
		if reply.has("quota"):
			quota_hit = true
			return []
		if reply.has("no_instructions"):
			print("  this model takes no instructions: using the short \"Say ...:\" form")
			no_instructions = true
			continue
		if reply.has("retry"):
			var wait := 15.0 * (attempt + 1)
			print("  busy, waiting %d s" % wait)
			await create_timer(wait).timeout
			continue
		if reply.is_empty(): return []
		for candidate in reply.get("candidates", []):
			for part in candidate.get("content", {}).get("parts", []):
				var data: Dictionary = part.get("inlineData", {})
				if data.is_empty(): continue
				var rate := 24000
				for piece in str(data.get("mimeType", "")).split(";"):
					if piece.strip_edges().begins_with("rate="): rate = int(piece.strip_edges().trim_prefix("rate="))
				return [Marshalls.base64_to_raw(str(data.get("data", ""))), rate]
		print("  no audio in the reply: ", JSON.stringify(reply).left(300))
		return []
	print("  gave up after retries")
	return []

## The JSON reply, {"retry": true} when busy or rate-limited, or {} on an error. The key
## goes in a header, never in the address, so it is not printed with errors.
func _call(url: String, method: int, body: String) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json", "x-goog-api-key: " + key])
	var error := http.request(url, headers, method, body)
	if error != OK:
		print("  request failed to start (", error, ")")
		return {}
	var result: Array = await http.request_completed
	var code: int = result[1]
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	if code == 429 or code == 500 or code == 503:
		# A daily quota will not come back by waiting: say so and stop.
		if code == 429 and ("PerDay" in text or "per day" in text):
			print("  DAILY QUOTA used up: ", text.left(500))
			return {"quota": true}
		if code == 429: print("  rate limit: ", text.left(240).replace("\n", " "))
		return {"retry": true}
	if code == 400 and "instruction is not enabled" in text: return {"no_instructions": true}
	if result[0] != HTTPRequest.RESULT_SUCCESS or code != 200:
		print("  HTTP %d: %s" % [code, text.left(400)])
		return {}
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

## Trims silence from both ends (keeping a short breath) and scales the loudest peak to
## PEAK, so every voice plays at the same level.
func _clean(pcm: PackedByteArray, rate: int) -> PackedByteArray:
	var count := pcm.size() / 2
	if count == 0: return pcm
	var threshold := 400
	var first := 0
	while first < count and absi(pcm.decode_s16(first * 2)) < threshold: first += 1
	var last := count - 1
	while last > first and absi(pcm.decode_s16(last * 2)) < threshold: last -= 1
	var pad := int(rate * 0.08)
	first = maxi(0, first - pad)
	last = mini(count - 1, last + pad * 2)
	var peak := 1
	for index in range(first, last + 1): peak = maxi(peak, absi(pcm.decode_s16(index * 2)))
	var gain := PEAK * 32767.0 / peak
	var out := PackedByteArray()
	out.resize((last - first + 1) * 2)
	for index in range(first, last + 1):
		out.encode_s16((index - first) * 2, clampi(roundi(pcm.decode_s16(index * 2) * gain), -32768, 32767))
	return out
