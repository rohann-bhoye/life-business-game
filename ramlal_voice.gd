extends RefCounted

# Seth Ramlal's spoken lines at the shop door (shop_sale_dialog.gd), in Hindi like the
# intro's family voices, made by tools/make_voice.gd (-- set=ramlal) into
# assets/audio/voice/ramlal_<id>.wav with the intro's voice model. The talk box plays a line
# only when its file exists. The words are in Devanagari so they are said properly; the
# captions are the same lines in romanised Hindi (LINES[id][2]). Lines with the shop's
# price leave the amount to the caption (it depends on the difficulty).
const ROOT := "res://assets/audio/voice/"
const PREFIX := "ramlal_"

## Gemini voice, acting note (an instruction, never spoken) and a short "Say ...:" form.
const SPEAKERS := {
	"RAMLAL": ["Charon", "Speak in Hindi as Seth Ramlal, a warm, kind old Indian shopkeeper in his seventies, Dada-ji's oldest friend, a little slow and full of feeling.", "Say in Hindi, warmly, like a kind old Indian uncle"],
}

## id: [speaker, words to say (Devanagari), caption (romanised; %s is the price)].
const LINES := {
	"hello": ["RAMLAL", "अरे! सुनो बेटा, रुको रुको! वही आँखें, वही ज़िद्दी चाल... तुम दादाजी के अपने हो ना?",
		"Arre! Suno beta, ruko ruko! Wohi aankhein, wohi ziddi chaal... Tum Dada-ji ke apne ho na?"],
	"who": ["RAMLAL", "मैं रामलाल हूँ। तुम्हारे दादाजी और मैं चालीस साल उस बेंच पर बैठे, चाय पीते और हर बात पर बहस करते। जब से वो बीमार पड़े, अपना मार्ट मैं ही संभाल रहा हूँ।",
		"Main Ramlal hoon. Tumhare Dada-ji aur main chaalis saal us bench par baithe, chai peete aur har baat par behes karte. Jab se woh beemar pade, Apna Mart main hi sambhaal raha hoon."],
	"letter": ["RAMLAL", "तो उन्होंने अपना वादा निभाया। दादाजी कहते थे: जब मेरे घर का बच्चा ढोलकरपुर आए, खोया हुआ और खाली हाथ, उसे दुकान दे देना। बड़े भावुक आदमी थे।",
		"To unhone apna vaada nibhaya. Dada-ji kehte the: jab mere ghar ka bachcha Dholkarpur aaye, khoya hua aur khaali haath, use dukaan de dena. Bade bhavuk aadmi the."],
	"offer": ["RAMLAL", "लगभग, बेटा। दुकान पर पुराना कर्ज़ा है और पूरा गाँव देख रहा है। मुफ़्त में नहीं दे सकता, पर घर वाला दाम लगा दूँगा। शेल्फ़, फ्रिज, पीसी, शटर की चाबी, सब कुछ।",
		"Lagbhag, beta. Dukaan par purana karza hai aur poora gaon dekh raha hai. Muft mein nahi de sakta, par ghar wala daam laga doonga: %s. Shelf, fridge, PC, shutter ki chaabi, sab kuch."],
	"again": ["RAMLAL", "फिर आ गए, बेटा? अपना मार्ट तुम्हारा इंतज़ार कर रहा है, और चाबी तुम्हारी।",
		"Phir aa gaye, beta? Apna Mart tumhara intezaar kar raha hai: %s, aur chaabi tumhari."],
	"about": ["RAMLAL", "छोटा सा किराना है, पर अच्छा है। पहली शेल्फ़ तुम्हारे दादाजी ने ख़ुद बनाई थी। दुकान के पीसी पर माल ऑर्डर करो, सामने अपना स्टोरेज से डिब्बे अंदर लाओ और लाइन संभालो। पैसे माल के लिए बचाके रखना, काम आएँगे।",
		"Chhota sa kirana hai, par accha hai. Pehli shelf tumhare Dada-ji ne khud banayi thi. Dukaan ke PC par maal order karo, saamne Apna Storage se dibbe andar laao aur line sambhalo. Paise maal ke liye bachaake rakhna, kaam aayenge."],
	"short": ["RAMLAL", "अभी पैसे कम हैं, बेटा। जब पूरे पैसे हो जाएँ, तब आना।",
		"Abhi paise kam hain, beta. Jab %s ho jaayein, tab aana."],
	"sold": ["RAMLAL", "मुबारक हो! अब दुकान तुम्हारी है। शटर ऊपर! डेस्क वाले पीसी पर माल ऑर्डर करो, रैक भरो, और हर ग्राहक से प्यार से बात करना। दादाजी को तुम पर गर्व होता।",
		"Mubarak ho! Ab dukaan tumhari hai. Shutter upar! Desk wale PC par maal order karo, racks bharo, aur har grahak se pyaar se baat karna. Dada-ji ko tum par garv hota."],
}

## Every file to make: [file id, speaker, words].
static func jobs() -> Array:
	var result := []
	for id in LINES: result.append([PREFIX + id, LINES[id][0], LINES[id][1]])
	return result

## The caption for line `id`, with `price` (e.g. "₹5,000") where the line names it.
static func caption(id: String, price := "") -> String:
	var words: String = LINES[id][2]
	return words % price if "%s" in words else words

## The recorded line `id` (without the prefix), or null when it has not been made.
static func stream(id: String) -> AudioStream:
	var path := ROOT + PREFIX + id + ".wav"
	return load(path) if ResourceLoader.exists(path) else null
