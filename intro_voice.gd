extends RefCounted

# The spoken lines of the opening story (intro_cinematic.gd), one voice per character.
# tools/make_voice.gd makes them with Gemini text-to-speech into assets/audio/intro/<id>.wav;
# the intro plays a line only when its file exists, so it still works silently without.
# Hindi lines are written in Devanagari so the voice pronounces them properly; the captions
# keep the romanised Hindi. The money lines say "ye paise" / "a little money" rather than
# the amount (it depends on the difficulty), so one file serves every game (seven requests
# fit Gemini's free daily limit of ten).
const ROOT := "res://assets/audio/intro/"

## Gemini voice, acting note (sent as an instruction, never spoken) and a short version for
## models without instructions (sent as "Say ...: words", which they act but do not read).
const SPEAKERS := {
	"YOU": ["Umbriel", "Speak quietly, as the private thoughts of a young Indian man sitting alone at a plane window at night, a little lost and nervous, in natural Indian English.", "Say quietly and nervously, in an Indian accent"],
	"PAPA": ["Algenib", "Speak in Hindi as a strict but loving middle-aged Indian father, firm and tired, pushing his grown child to go out and make something of life.", "Say in Hindi, firmly, like a tired strict father"],
	"MUMMY": ["Sulafat", "Speak in Hindi as a warm, caring Indian mother, softly, trying not to cry while sending her child away.", "Say in Hindi, softly and warmly, like a loving mother"],
	"DADAJI": ["Charon", "Speak in Hindi, slowly and gently, as a kind old Indian grandfather reading his own letter aloud, full of warmth and wisdom.", "Say in Hindi, slowly and gently, like a kind old grandfather"],
	"PILOT": ["Iapetus", "Speak as a calm, friendly Indian airline pilot making a cabin announcement over the PA, in Indian English.", "Say calmly, like an Indian airline pilot on the PA"],
}

## id: [speaker, words].
const LINES := {
	"you_seat": ["YOU", "Seat fourteen A. Somewhere over India. Nobody on this plane knows me."],
	"papa": ["PAPA", "बेटा, बहुत हो गया। घर बैठके कुछ नहीं मिलता। जा, अपना काम ढूंढ।"],
	"mummy_money": ["MUMMY", "टिफ़िन रख दिया है। और ये पैसे... संभाल के खर्च करना।"],
	"you_why": ["YOU", "Why me? Why now? I don't even know what I'm good at."],
	"dadaji_letter": ["DADAJI", "बेटा, जब भी खो जाओ, ढोलकरपुर गाँव चले जाना। वहीं से सब कुछ शुरू होता है।"],
	"you_town_money": ["YOU", "A town I have never seen. A letter. A little money. That is all I have."],
	"pilot": ["PILOT", "Ladies and gentlemen, we are now landing at Dholkarpur. Local time is eight A M, weather sunny. Thank you for flying Apna Air."],
}

## Every file to make: [file id, speaker, words].
static func jobs() -> Array:
	var result := []
	for id in LINES: result.append([id, LINES[id][0], LINES[id][1]])
	return result

## The recorded line `id`, or null when it has not been made.
static func stream(id: String) -> AudioStream:
	var path := ROOT + id + ".wav"
	return load(path) if ResourceLoader.exists(path) else null
