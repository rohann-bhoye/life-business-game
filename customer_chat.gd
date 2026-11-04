extends "res://conversation_box.gd"

# Talking to a shopper (E on them in the aisles or the queue). They stop while you
# talk. Each kind of reply works once per shopper:
# - help (while shopping) or sorry-for-the-wait (in the queue): they wait 30 s
#   longer in the queue and remember the friendly service in their review;
# - suggest one more product that is on the shelves: some add it to their basket;
# - ask about prices: they compare with Sharma's shop next door.

const Catalog = preload("res://product_catalog.gd")
## Chance a shopper of each kind takes a suggested product.
const SUGGEST_CHANCE := {"quick": 0.15, "regular": 0.45, "family": 0.65, "bulk": 0.1, "": 0.35}
const COLOURS := [Color(0.62, 0.3, 0.42), Color(0.25, 0.45, 0.62), Color(0.55, 0.42, 0.2)]
var customer: Node3D
var actions: Array[String] = []
var suggestion := ""

func open_for(shopper: Node3D) -> void:
	customer = shopper
	customer.chatting = true
	var player: Node3D = get_tree().current_scene.get_node("Player")
	var facing := Vector3(player.global_position.x, customer.global_position.y, player.global_position.z)
	if customer.global_position.distance_squared_to(facing) > 0.01: customer.look_at(facing, Vector3.UP)
	var kind: String = "%s shopper" % customer.shopper_type.capitalize() if not customer.shopper_type.is_empty() else customer.customer_name.get_slice(" - ", 1)
	var greeting: String = ["Bhaiya, kuch discount milega?", "Namaste bhaiya!", "Jaldi karna, der ho rahi hai!"][clampi(customer.personality, 0, 2)]
	if not customer.shopper_type.is_empty(): greeting = customer.SHOPPER_TYPES[customer.shopper_type].say.pick_random()
	if customer.state == customer.State.QUEUING: greeting = "Line kitni lambi hai..." if customer.queue_is_impatient() else "Bas mera number aane wala hai."
	look_at_person(customer)
	present(customer.customer_name.get_slice(" - ", 0), "%s  |  Basket: %s" % [kind, _basket()], COLOURS[clampi(customer.personality, 0, 2)], greeting, [], [])
	_offer()

func _basket() -> String:
	var parts: Array[String] = ["%d %s" % [maxi(customer.basket_count, customer.shopping_quantity), Catalog.NAMES[customer.product_id]]]
	for line in customer.extra_lines: parts.append("%d %s" % [line.count, Catalog.NAMES[line.product]])
	return ", ".join(parts)

func _offer() -> void:
	var queuing: bool = customer.state == customer.State.QUEUING
	suggestion = _suggestion()
	actions.assign(["sorry" if queuing else "help", "suggest", "prices", "close"])
	var texts := ["Sorry for the wait!" if queuing else "Namaste! Need help?",
		"Try our %s!" % Catalog.NAMES[suggestion] if not suggestion.is_empty() else "Nothing to suggest",
		"How are my prices?", "Bye"]
	var done: Dictionary = customer.chat_done
	var disabled := [done.has("help"), done.has("suggest") or suggestion.is_empty(), done.has("prices"), false]
	say(get_node("MessageLabel").text.trim_prefix("\"").trim_suffix("\""), texts, disabled)

## One more product the shopper could still pick up: on a shelf, in budget, not
## already in the basket, and only while they are still shopping.
func _suggestion() -> String:
	if customer.state not in [customer.State.ARRIVING, customer.State.TAKING, customer.State.SHOPPING_MORE]: return ""
	var operations = customer.operations
	if not is_instance_valid(operations) or not is_instance_valid(operations.furnishing): return ""
	var basket: Array = [customer.product_id]
	for line in customer.extra_lines: basket.append(line.product)
	var best := ""
	for id in Catalog.IDS:
		if id in basket or business.product_price(id) > customer.spending_budget: continue
		var rack: int = operations.furnishing.choose_rack(id)
		if rack < 0 or operations.furnishing.available(rack, id) <= 0: continue
		if best.is_empty() or business.product_price(id) > business.product_price(best): best = id
	return best

func _reply(index: int) -> void:
	if not visible or index >= actions.size() or not is_instance_valid(customer): return
	var action := actions[index]
	if action == "close":
		close_menu()
		return
	var line := ""
	match action:
		"help", "sorry":
			customer.chat_done["help"] = true
			customer.chat_patience += 30.0
			line = "Achha, theek hai. Shukriya bhaiya!" if action == "sorry" else "Haan, %s kahan hai? ... Mil gaya, shukriya!" % Catalog.NAMES[customer.product_id]
		"suggest":
			customer.chat_done["suggest"] = true
			var chance: float = SUGGEST_CHANCE.get(customer.shopper_type, 0.35) - (0.15 if customer.personality == 0 else 0.0)
			if not suggestion.is_empty() and randf() < chance:
				customer.extra_lines.append({"product": suggestion, "rack": -1, "count": 1, "taken": false})
				customer.wants_discount = false
				line = "Achha, ek %s bhi le leta hoon!" % Catalog.NAMES[suggestion]
				ui.show_feedback("%s added 1 %s to the basket." % [customer.customer_name.get_slice(" - ", 0), Catalog.NAMES[suggestion]])
			else: line = "Nahi bhaiya, aaj nahi."
		"prices":
			customer.chat_done["prices"] = true
			line = _price_opinion()
	get_node("HappinessLabel").text = "%s  |  Basket: %s" % [get_node("HappinessLabel").text.get_slice("  |  ", 0), _basket()]
	get_node("MessageLabel").text = line
	_offer()

func _price_opinion() -> String:
	var id: String = customer.product_id
	var price: int = business.product_price(id)
	var rupee := String.chr(8377)
	if not business.rival_open(): return "%s %s%d? Theek daam hai." % [Catalog.NAMES[id], rupee, price]
	var rival: int = business.rival_price_today(id)
	if price > rival: return "%s yahan %s%d, Sharma ji ke yahan %s%d. Thoda mehenga hai!" % [Catalog.NAMES[id], rupee, price, rupee, rival]
	if price < rival: return "%s Sharma ji se sasta hai (%s%d vs %s%d). Badhiya!" % [Catalog.NAMES[id], rupee, price, rupee, rival]
	return "Sharma ji ke barabar hai, %s%d. Theek hai." % [rupee, price]

func close_menu() -> void:
	if is_instance_valid(customer): customer.chatting = false
	customer = null
	super()
