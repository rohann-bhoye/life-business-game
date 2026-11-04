extends "res://conversation_box.gd"

# Seth Ramlal at the shop door (shop_sale.gd): Dada-ji's old friend. The first talk is a short
# story (who he is, Dada-ji's letter, why the shop is for sale) that ends in the offer to sell
# Apna Mart for business.shop_price(); later talks go straight to the offer. The view turns to
# his face while you talk and he speaks his lines (ramlal_voice.gd) when they have been made.

const OWNER := "Seth Ramlal"
const TAG := "Apna Mart's owner  |  Dada-ji's friend"
const COLOUR := Color(0.55, 0.36, 0.2)
const Voice := preload("res://ramlal_voice.gd")
var actions: Array[String] = []
var sale: Node
var met := false

func open_for(shop_sale: Node) -> void:
	sale = shop_sale
	look_at_person(shop_sale.owner_npc)
	if met: _offer(_line("again"), "again")
	else: _story("hello")

func _price() -> String:
	return _money(business.shop_price())

## Seth's line `id` in romanised Hindi, as he says it (ramlal_voice.gd), with the price.
func _line(id: String) -> String:
	return Voice.caption(id, String.chr(8377) + _price())

func _money(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0: result += ","
		result += digits[index]
	return result

## One step of the first talk: each has Seth's line and the replies that lead on.
func _story(step: String) -> void:
	if step != "why": speak(Voice.stream(step))
	match step:
		"hello":
			actions.assign(["letter", "who"])
			present(OWNER, TAG, COLOUR, _line("hello"), ["Yes, I have his letter", "Who are you?"])
		"who":
			actions.assign(["letter"])
			say(_line("who"), ["I have his letter"])
		"letter":
			actions.assign(["why"])
			say(_line("letter"), ["So the shop is mine?"])
		"why":
			met = true
			_offer(_line("offer"), "offer")

## The offer to buy, with `line` (and its recording `voice_id`) above the choices.
func _offer(line: String, voice_id := "") -> void:
	actions.assign(["buy", "about", "later"])
	var poor: bool = business.money < business.shop_price()
	var buy_text := "Buy Apna Mart (%s%s)" % [String.chr(8377), _price()]
	if poor: buy_text += "  - you need %s%s more" % [String.chr(8377), _money(business.shop_price() - business.money)]
	if visible: say(line, [buy_text, "Tell me about the shop", "Not yet"], [poor, false, false])
	else: present(OWNER, TAG, COLOUR, line, [buy_text, "Tell me about the shop", "Not yet"], [poor, false, false])
	if voice_id != "": speak(Voice.stream(voice_id))

func _reply(index: int) -> void:
	if not visible or index >= actions.size(): return
	match actions[index]:
		"hello", "who", "letter", "why":
			_story(actions[index])
		"buy":
			if business.buy_shop():
				actions.assign(["close"])
				say(_line("sold"), ["Thank you, Seth ji"])
				speak(Voice.stream("sold"))
				if is_instance_valid(sale): sale.sold()
			else:
				_offer(_line("short"), "short")
		"about":
			actions.assign(["buy", "later"])
			var poor: bool = business.money < business.shop_price()
			speak(Voice.stream("about"))
			say(_line("about"), ["Buy Apna Mart (%s%s)" % [String.chr(8377), _price()], "Not yet"], [poor, false])
		_:
			close_menu()
