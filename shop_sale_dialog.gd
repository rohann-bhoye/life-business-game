extends "res://conversation_box.gd"

# Seth Ramlal at the shop door (shop_sale.gd): Dada-ji's old friend. The first talk is a short
# story (who he is, Dada-ji's letter, why the shop is for sale) that ends in the offer to sell
# Apna Mart for business.shop_price(); later talks go straight to the offer.

const OWNER := "Seth Ramlal"
const TAG := "Apna Mart's owner  |  Dada-ji's friend"
const COLOUR := Color(0.55, 0.36, 0.2)
var actions: Array[String] = []
var sale: Node
var met := false

func open_for(shop_sale: Node) -> void:
	sale = shop_sale
	if met: _offer("Back again, beta? Apna Mart is waiting for you: %s%s, and the keys are yours." % [String.chr(8377), _price()])
	else: _story("hello")

func _price() -> String:
	return _money(business.shop_price())

func _money(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0: result += ","
		result += digits[index]
	return result

## One step of the first talk: each has Seth's line and the replies that lead on.
func _story(step: String) -> void:
	match step:
		"hello":
			actions.assign(["letter", "who"])
			present(OWNER, TAG, COLOUR, "Arre! Hey you, beta! Stop, stop. Those eyes, that stubborn walk... You are Dada-ji's grandchild, na?", ["Yes, I have his letter", "Who are you?"])
		"who":
			actions.assign(["letter"])
			say("I am Ramlal. Your Dada-ji and I sat on that bench over there for forty years, drinking chai and arguing about everything. I have looked after Apna Mart for him since he fell ill.", ["I have his letter"])
		"letter":
			actions.assign(["why"])
			say("Then he kept his word. Dada-ji said: \"When my grandchild comes to Dholkarpur, lost and with nothing, give them the shop.\" He was a sentimental old man.", ["So the shop is mine?"])
		"why":
			met = true
			_offer("Almost, beta. The shop has old debts and the village is watching. I cannot give it away, but I can sell it to you for a family price: %s%s. Shelves, fridge, PC, shutter key, everything." % [String.chr(8377), _price()])

func _offer(line: String) -> void:
	actions.assign(["buy", "about", "later"])
	var poor: bool = business.money < business.shop_price()
	var buy_text := "Buy Apna Mart (%s%s)" % [String.chr(8377), _price()]
	if poor: buy_text += "  - you need %s%s more" % [String.chr(8377), _money(business.shop_price() - business.money)]
	if visible: say(line, [buy_text, "Tell me about the shop", "Not yet"], [poor, false, false])
	else: present(OWNER, TAG, COLOUR, line, [buy_text, "Tell me about the shop", "Not yet"], [poor, false, false])

func _reply(index: int) -> void:
	if not visible or index >= actions.size(): return
	match actions[index]:
		"hello", "who", "letter", "why":
			_story(actions[index])
		"buy":
			if business.buy_shop():
				actions.assign(["close"])
				say("Mubarak ho! The shop is yours now. Up goes the shutter. Order stock on the PC at your desk, fill the racks, and be kind to every customer. Dada-ji would be proud.", ["Thank you, Seth ji"])
				if is_instance_valid(sale): sale.sold()
			else:
				_offer("You do not have enough yet, beta. Come back when you have %s%s." % [String.chr(8377), _price()])
		"about":
			actions.assign(["buy", "later"])
			var poor: bool = business.money < business.shop_price()
			say("A small kirana, but a good one. Your Dada-ji built the first shelves himself. Order stock on the shop PC, carry the boxes in from Apna Storage across the road and serve the queue. Keep your money for stock: you will need it.", ["Buy Apna Mart (%s%s)" % [String.chr(8377), _price()], "Not yet"], [poor, false])
		_:
			close_menu()
