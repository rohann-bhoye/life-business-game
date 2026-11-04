extends Node3D

enum State { WAITING, ARRIVING, BUYING, LEAVING, NEGOTIATING, TAKING, TO_COUNTER, QUEUING, CHECKOUT, SCANNING, PAYING, SHOPPING_MORE, ORDERING }

@export var walk_speed := 1.5
@export var spawn_delay := 3.0
@export var purchase_delay := 1.0
@export var shop_area_path: NodePath
@export var purchase_point_path: NodePath
@export var exit_point_path: NodePath

var state := State.WAITING
var wait_remaining := 0.0
var spending_budget := 100
var personality := 0
var wants_discount := false
var customer_name := ""
var quoted_price := 100
var offer_price := 80
var acceptable_price := 90
var bargain_seconds_left := 20.0
var deal_result := ""
var deal_sold := false
var has_product := false
var product_id := "bottle"
var rack_id := -1
var shopping_quantity := 1
var basket_count := 0
## Extra products in a mixed basket: {product, rack, count, taken}. The first
## product stays in product_id/rack_id/basket_count.
var extra_lines: Array = []
var line_index := -1
const MIXED_CHANCE := 0.5
## Real games ("town_customers" scene meta): each customer is a kind of shopper
## with their own basket size and budget, walks in along the shop-side pavement
## from the edge of town and walks away down the street after shopping.
## budget is per item in tens of rupees; items is the main product's count.
const SHOPPER_TYPES := {
	"quick": {"weight": 35, "items": [1, 1], "extras": [0, 0], "budget": [8, 15], "say": ["Bhaiya, bas ek cheez chahiye.", "Jaldi karna bhaiya!"]},
	"regular": {"weight": 40, "items": [1, 3], "extras": [0, 1], "budget": [10, 20], "say": ["Namaste bhaiya!", "Thoda saaman lena hai."]},
	"family": {"weight": 20, "items": [2, 4], "extras": [1, 2], "budget": [14, 25], "say": ["Mahine ka ration lena hai!", "Ghar ka poora saaman!"]},
	"bulk": {"weight": 5, "items": [5, 7], "extras": [0, 0], "budget": [12, 20], "say": ["Chai stall ke liye maal chahiye!"]},
}
const PAVEMENT_Z := 3.9
const STREET_END_X := 32.0
var shopper_type := ""
var pavement_lane := PAVEMENT_Z
## +1 / -1: the end of the street the customer walked in from (0 = not walking in).
var arrival_side := 0.0
var scanned_count := 0
var scanned_items: Array[int] = []
var agreed_unit_price := 100
var payment_method := "Cash"
var cash_tendered := 0
var auto_checkout_seconds := 1.0
var cashier_active := false
var held_bottle: Node3D
var operations: Node3D
var route: Array[Vector3] = []
var route_index := 0
var service_wait_seconds := 0.0
var review_outcome := ""
var review_recorded := false
## Price rules (business_backend.gd): switched once to a fairer product; bought a bargain.
var price_switched := false
var cheap_buy := false
var queue_wait_seconds := 0.0
var patience_label: Label3D
var speech_label: Label3D
var speech_seconds := 0.0
## Co-op: on a friend's screen this customer mirrors one in the host's game
## (coop_world.gd moves it and fills in its basket and checkout). Its own behaviour
## is off, and checkout actions (scan, bargain, pay) also go to the host's customer
## through coop_forward.call(method, args).
var coop_mirror := false
var coop_forward := Callable()
## Talking with the player (customer_chat.gd): they stand still meanwhile. Each
## kind of reply works once (chat_done); a friendly one adds queue patience.
var chatting := false
## Asks to pay later (udhaar) at the checkout; the player decides (checkout_menu.gd).
var wants_udhaar := false
var chat_done := {}
var chat_patience := 0.0
## Counter orders (kirana style, real solo games): every town customer walks straight
## to the till and tells the shopkeeper a list; nobody takes things off the racks
## themselves. The player takes a carry bag from the box, fills it at the racks and
## hands it over (shop_operations.gd), then takes payment as usual. A hired cashier
## fills the order when the player is away. (Test scenes and co-op still self-serve.)
const COUNTER_ORDER_CHANCE := 1.0
const ORDER_PATIENCE := 150.0
const ORDER_AUTO_SECONDS := 4.0
var counter_order := false
## The list: {product, count} lines, at most three products of up to three each.
var order_lines: Array = []
var order_told := false
## What is in the carry bag so far: {product, rack, count}; reserved on those racks.
var bag_lines: Array = []
var order_seconds := 0.0

@onready var shop_area: Area3D = get_node(shop_area_path)
@onready var purchase_point: Marker3D = get_node(purchase_point_path)
@onready var exit_point: Marker3D = get_node(exit_point_path)

func _ready() -> void:
	operations = get_tree().current_scene.get_node_or_null("ShopOperations")
	spending_budget = randi_range(10, 20) * 10
	personality = randi_range(0, 2)
	var first_names: Array = [["Ravi", "Sunita", "Prakash", "Lata", "Mohan"], ["Meena", "Arjun", "Kavita", "Rahul", "Pooja"], ["Aman", "Neha", "Vikram", "Divya", "Sanjay"]][personality]
	customer_name = "%s - %s" % [first_names.pick_random(), ["Bargain hunter", "Regular", "In a hurry"][personality]]
	wants_discount = randf() < [0.75, 0.35, 0.0][personality]
	shopping_quantity = randi_range(1, 3)
	payment_method = ["Cash", "Card", "UPI"][randi_range(0, 2)]
	if town_customers(): _pick_shopper_type()
	visible = false
	wait_remaining = spawn_delay
	patience_label = Label3D.new()
	patience_label.name = "PatienceLabel"
	patience_label.position = Vector3(0, 1.9, 0)
	patience_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	patience_label.font_size = 24
	patience_label.pixel_size = 0.0045
	patience_label.outline_size = 6
	patience_label.hide()
	add_child(patience_label)
	speech_label = Label3D.new()
	speech_label.name = "SpeechLabel"
	speech_label.position = Vector3(0, 2.3, 0)
	speech_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech_label.font_size = 26
	speech_label.pixel_size = 0.0045
	speech_label.outline_size = 8
	speech_label.modulate = Color(1, 0.9, 0.55)
	speech_label.hide()
	add_child(speech_label)

func town_customers() -> bool:
	return is_inside_tree() and get_tree().current_scene != null and get_tree().current_scene.get_meta("town_customers", false)

func _pick_shopper_type() -> void:
	var roll := randi_range(1, 100)
	for kind in SHOPPER_TYPES:
		roll -= int(SHOPPER_TYPES[kind].weight)
		if roll <= 0 or kind == "bulk":
			shopper_type = kind
			break
	var kind: Dictionary = SHOPPER_TYPES[shopper_type]
	shopping_quantity = randi_range(kind.items[0], kind.items[1])
	spending_budget = randi_range(kind.budget[0], kind.budget[1]) * 10
	# People doing big shopping don't haggle over every rupee.
	if shopper_type in ["family", "bulk"]: wants_discount = false
	pavement_lane = PAVEMENT_Z + randf_range(-0.3, 0.3)

## A short remark above the customer's head (e.g. comparing with Sharma's price).
func say(text: String, seconds := 4.0) -> void:
	speech_label.text = text
	speech_label.show()
	speech_seconds = seconds

func _physics_process(delta: float) -> void:
	if coop_mirror or chatting: return
	if speech_seconds > 0.0:
		speech_seconds -= delta
		if speech_seconds <= 0.0: speech_label.hide()
	if state in [State.QUEUING, State.BUYING, State.SCANNING, State.NEGOTIATING, State.PAYING, State.CHECKOUT, State.ORDERING]:
		service_wait_seconds += delta
	if not shop_area.business.shop_is_open():
		if state == State.WAITING:
			return
		if state != State.LEAVING:
			leave_shop()
			deal_result = "Shop closed."
	if _update_queue_patience(delta): return
	match state:
		State.WAITING:
			wait_remaining -= delta
			if wait_remaining <= 0.0:
				visible = true
				state = State.ARRIVING
				if physical_shop():
					var town := town_customers()
					if town and shopper_type.is_empty():
						_pick_shopper_type()
						# Difficulty: richer shoppers on Aasaan, tighter budgets on Mushkil.
						spending_budget = maxi(50, roundi(spending_budget * shop_area.business.budget_factor() / 10.0) * 10)
					var choices: Array[String] = []
					for id in operations.Catalog.IDS:
						if operations.available_stock(id) > 0: choices.append(id)
					# Shoppers go for something they can afford when there is a choice.
					var affordable := choices.filter(func(id): return shop_area.business.product_price(id) <= spending_budget)
					# A stocked fridge draws people in for a thanda, most of all in the afternoon.
					if town and "bottle" in affordable and operations.cold_drinks_chilled():
						for extra in range(3 if shop_area.business.minutes_of_day >= 720 and shop_area.business.minutes_of_day < 1020 else 1): affordable.append("bottle")
					if town and not affordable.is_empty(): product_id = affordable.pick_random()
					elif not choices.is_empty(): product_id = choices.pick_random()
					if is_instance_valid(operations.furnishing): rack_id = operations.furnishing.choose_rack(product_id)
					_plan_extra_products(choices)
					var points: Array[Vector3] = operations.customer_entry_route(product_id, rack_id)
					if town and not choices.is_empty() and _wants_counter_order():
						_plan_counter_order()
						points = [Vector3(-3, 0.1, 3.3), Vector3(-3, 0.1, 1.65)]
						points.append_array(shop_area.business.racks.route(points[-1], operations.queue_entry()))
					if town:
						# Start at one end of the street and walk along the pavement to the door.
						arrival_side = 1.0 if randf() < 0.5 else -1.0
						global_position = Vector3(arrival_side * randf_range(22.0, 28.0), StreetKit.PAVE_TOP, pavement_lane)
						points.push_front(Vector3(points[0].x, StreetKit.PAVE_TOP, pavement_lane))
					_set_route(points)
					if counter_order: state = State.TO_COUNTER
		State.ARRIVING:
			if physical_shop():
				if _walk_route(delta):
					state = State.TAKING
					wait_remaining = 0.35
			elif _walk_to(purchase_point.global_position, delta):
				wait_remaining = purchase_delay
				state = State.BUYING
		State.TAKING:
			wait_remaining -= delta
			if wait_remaining <= 0:
				if not shopper_type.is_empty() and not has_product: say(SHOPPER_TYPES[shopper_type].say.pick_random(), 3.0)
				var available: int = operations.furnishing.available(rack_id, product_id) if rack_id >= 0 and is_instance_valid(operations.furnishing) else operations.available_stock(product_id)
				if available <= 0:
					review_outcome = "stock"
					shop_area.business.record_stock_shortage()
					leave_shop()
				elif randf() > shop_area.business.buy_chance(product_id):
					# The shelf tag is too dear for them (business_backend.gd price rules).
					_price_refused()
				else:
					_price_remark()
					has_product = true
					basket_count = mini(shopping_quantity, available)
					held_bottle = operations.make_product(self, "HeldBottle", Vector3(0.32, 0.9, -0.2), product_id)
					operations.update_rack()
					_next_stop()
		State.SHOPPING_MORE:
			if _walk_route(delta):
				var line: Dictionary = extra_lines[line_index]
				var available: int = operations.furnishing.available(line.rack, line.product) if is_instance_valid(operations.furnishing) else operations.available_stock(line.product)
				# Too dear an extra stays on the shelf; the rest of the basket goes on.
				if available > 0 and randf() > shop_area.business.buy_chance(line.product):
					say("Ye bhi mehenga hai... rehne do.", 2.5)
					available = 0
				if available > 0:
					line.count = mini(line.count, available)
					line.taken = true
					operations.update_rack()
				_next_stop()
		State.TO_COUNTER:
			if _walk_route(delta):
				operations.enqueue(self)
				state = State.QUEUING
		State.QUEUING:
			if _walk_to(operations.queue_position(self), delta):
				look_at(operations.cashier_point, Vector3.UP)
				if operations.checkout_customer() == self:
					state = State.BUYING
					wait_remaining = purchase_delay
		State.BUYING:
			wait_remaining -= delta
			if wait_remaining <= 0.0:
				if physical_shop():
					if operations.checkout_customer() != self:
						state = State.QUEUING
					elif counter_order:
						_start_order()
					else:
						quoted_price = shop_area.business.product_price(product_id)
						var sharma: int = shop_area.business.rival_price_today(product_id)
						if shop_area.business.rival_open() and quoted_price > sharma:
							say("Sharma ji ke yahan %s%d mein milta hai!" % [String.chr(8377), sharma])
						agreed_unit_price = quoted_price
						state = State.SCANNING
						auto_checkout_seconds = shop_area.business.cashier_scan_seconds()
						bargain_seconds_left = 60.0
						held_bottle.hide()
						operations.show_basket(self)
				elif wants_discount and shop_area.stock > 0 and shop_area.selling_price > 50 and player_is_near():
					_begin_bargaining()
				else:
					deal_sold = shop_area.business.sell_one_stock(spending_budget)
					review_outcome = "sold" if deal_sold else ("stock" if shop_area.stock <= 0 else "price")
					leave_shop()
		State.NEGOTIATING, State.CHECKOUT, State.SCANNING, State.PAYING:
			if physical_shop() and shop_area.business.cashier_on_shift() and not operations.someone_at_counter():
				if not cashier_active:
					auto_checkout_seconds = shop_area.business.cashier_scan_seconds() if state == State.SCANNING else 1.0
				cashier_active = true
				auto_checkout_seconds -= delta
				if auto_checkout_seconds <= 0:
					if state == State.SCANNING:
						scan_next()
						shop_area.worker.get_node("CharacterVisual").play_work_animation()
					elif state == State.NEGOTIATING: prepare_payment(offer_price)
					elif state == State.PAYING: complete_checkout()
					auto_checkout_seconds = shop_area.business.cashier_scan_seconds() if state == State.SCANNING else 1.0
			elif physical_shop():
				cashier_active = false
				auto_checkout_seconds = shop_area.business.cashier_scan_seconds() if state == State.SCANNING else 1.0
			bargain_seconds_left = maxf(0, bargain_seconds_left - delta)
			if bargain_seconds_left <= 0.0:
				review_outcome = "timeout"
				leave_shop()
				deal_result = "Customer left without buying."
				shop_area.business.record_bargain_refusal(true)
		State.ORDERING:
			_update_order(delta)
		State.LEAVING:
			if (_walk_route(delta) if physical_shop() else _walk_to(exit_point.global_position, delta)):
				queue_free()

## At the shelf the price is too dear: once, they look for something fairly priced that they
## can afford instead; otherwise they say so and walk out (a "price" review).
func _price_refused() -> void:
	var business = shop_area.business
	if not price_switched and is_instance_valid(operations.furnishing):
		price_switched = true
		var others: Array = operations.Catalog.IDS.filter(func(id): return id != product_id and operations.available_stock(id) > 0 and business.product_price(id) <= spending_budget and business.price_feel(id) <= 1)
		if not others.is_empty():
			var other: String = others.pick_random()
			var rack: int = operations.furnishing.choose_rack(other)
			var record: Dictionary = business.racks.find(rack)
			if not record.is_empty():
				var points: Array[Vector3] = business.racks.route(global_position, business.RackStore.approach(record))
				if not points.is_empty():
					say("Ye mehenga hai... kuch aur le leta hoon.", 2.5)
					product_id = other
					rack_id = rack
					_set_route(points)
					state = State.ARRIVING
					return
	var sharma: int = business.rival_price_today(product_id)
	if business.rival_open() and business.product_price(product_id) > sharma:
		say("Sharma ji ke yahan %s%d mein milta hai!" % [String.chr(8377), sharma], 3.0)
	else:
		say(["Bahut mehenga hai!", "Itna mehenga? Rehne do.", "MRP se zyada? Nahi chahiye."].pick_random(), 3.0)
	review_outcome = "price"
	business.record_price_walkout()
	leave_shop()

## What they say about a price they did pay: pleased by a bargain, grumbling at a dear one.
func _price_remark() -> void:
	match shop_area.business.price_feel(product_id):
		0:
			cheap_buy = true
			if randf() < 0.5: say(["Arre wah, sasta hai!", "Accha daam hai!"].pick_random(), 2.5)
		2:
			if randf() < 0.4: say(["Thoda mehenga hai...", "Daam badh gaya kya?"].pick_random(), 2.5)
		3:
			say("Mehenga hai, par chalo.", 2.5)

## Half of customers also want one or two other products they can afford.
func _plan_extra_products(choices: Array) -> void:
	extra_lines.clear()
	line_index = -1
	# Real games (started from the menu) enable this; fixed test scenes stay single-product.
	if not get_tree().current_scene.get_meta("mixed_baskets", false): return
	var wanted := randi_range(1, 2) if randf() < MIXED_CHANCE else 0
	if not shopper_type.is_empty():
		var kind: Dictionary = SHOPPER_TYPES[shopper_type]
		wanted = randi_range(kind.extras[0], kind.extras[1])
	if wanted == 0: return
	var others: Array = choices.filter(func(id): return id != product_id and shop_area.business.product_price(id) <= spending_budget)
	if others.is_empty(): return
	others.shuffle()
	for id in others.slice(0, mini(wanted, others.size())):
		# Family shoppers take one or two of each extra product.
		extra_lines.append({"product": id, "rack": -1, "count": randi_range(1, 2) if shopper_type == "family" else 1, "taken": false})
	# Bargaining stays a single-product conversation.
	wants_discount = false

## Walk to the next rack on the shopping list, or to the counter when done.
func _next_stop() -> void:
	line_index += 1
	while line_index < extra_lines.size():
		var line: Dictionary = extra_lines[line_index]
		var rack: int = operations.furnishing.choose_rack(line.product) if is_instance_valid(operations.furnishing) else -1
		var record: Dictionary = shop_area.business.racks.find(rack)
		if not record.is_empty() and operations.furnishing.available(rack, line.product) > 0:
			var points: Array[Vector3] = shop_area.business.racks.route(global_position, shop_area.business.RackStore.approach(record))
			if not points.is_empty():
				line.rack = rack
				_set_route(points)
				state = State.SHOPPING_MORE
				return
		line_index += 1
	_set_route(shop_area.business.racks.route(global_position, operations.queue_entry()))
	state = State.TO_COUNTER

## Extra products actually in the basket, priced at retail.
func taken_lines() -> Array:
	var result: Array = []
	for line in extra_lines:
		if line.taken: result.append({"product": line.product, "count": line.count, "rack": line.rack, "price": shop_area.business.product_price(line.product)})
	return result

func total_items() -> int:
	var total := basket_count
	for line in extra_lines:
		if line.taken: total += int(line.count)
	return total

## Product id of every item in the basket, in scanning order.
func basket_products() -> Array[String]:
	var result: Array[String] = []
	for index in range(basket_count): result.append(product_id)
	for line in extra_lines:
		if line.taken:
			for index in range(int(line.count)): result.append(line.product)
	return result

## Running total of the items scanned so far (first product at the agreed price).
func scanned_total() -> int:
	var products := basket_products()
	var total := 0
	for index in scanned_items:
		if index < products.size(): total += agreed_unit_price if index < basket_count else shop_area.business.product_price(products[index])
	return total

func physical_shop() -> bool:
	return is_instance_valid(operations) and operations.enabled

func queue_patience_limit() -> float:
	return [90.0, 120.0, 60.0][clampi(personality, 0, 2)] * shop_area.business.patience_factor() + chat_patience

func queue_is_impatient() -> bool:
	return physical_shop() and state == State.QUEUING and queue_wait_seconds >= queue_patience_limit() * 0.75

func _update_queue_patience(delta: float) -> bool:
	if not physical_shop() or state != State.QUEUING:
		patience_label.hide()
		return false
	queue_wait_seconds += maxf(0, delta)
	var remaining := maxf(0, queue_patience_limit() - queue_wait_seconds)
	patience_label.text = "%s\nWaiting: %ds" % [customer_name.get_slice(" - ", 0), ceili(remaining)]
	patience_label.modulate = Color(1, 0.7, 0.25) if queue_is_impatient() else Color(0.8, 1, 0.85)
	# Neighbours in the queue stand 0.85 m apart: stagger their labels so they never overlap.
	patience_label.position.y = 1.9 + (0.32 if operations.queue.find(self) % 2 == 1 else 0.0)
	patience_label.show()
	if remaining > 0: return false
	review_outcome = "timeout"
	deal_result = "%s left: queue too slow." % customer_name.get_slice(" - ", 0)
	shop_area.business.record_bargain_refusal(true)
	leave_shop()
	get_tree().current_scene.get_node("Ui").show_feedback(deal_result, true)
	return true

func _set_route(points: Array[Vector3]) -> void:
	route = points
	route_index = 0

func _walk_route(delta: float) -> bool:
	var remaining := walk_speed * delta
	while route_index < route.size():
		var distance := global_position.distance_to(route[route_index])
		if not _walk_to(route[route_index], remaining / walk_speed):
			return false
		remaining = maxf(0, remaining - distance)
		route_index += 1
	return true

func leave_shop() -> void:
	patience_label.hide()
	# Anything still in a carry bag goes back to its rack.
	bag_lines.clear()
	if not review_recorded and (deal_sold or not review_outcome.is_empty()):
		review_recorded = true
		# Friendly service (a chat) makes the wait feel 10 s shorter.
		var felt_wait := maxf(0.0, service_wait_seconds - (10.0 if chat_done.has("help") else 0.0))
		# A bargain on the shelf tag pleases them like a discount does.
		shop_area.business.record_customer_review("sold" if deal_sold else review_outcome, felt_wait, agreed_unit_price < quoted_price or cheap_buy)
	state = State.LEAVING
	if not physical_shop():
		return
	if not deal_sold:
		has_product = false
		if is_instance_valid(held_bottle): held_bottle.hide()
	elif is_instance_valid(held_bottle):
		held_bottle.show()
	operations.clear_basket(self)
	operations.remove_customer(self)
	var points: Array[Vector3] = []
	if global_position.z <= 2.6:
		points = shop_area.business.racks.route(global_position, operations.queue_entry())
		points.append_array(operations.customer_exit_route())
	if town_customers():
		# Out of the door, onto the pavement and on down the street (most keep going
		# the way they came from, some turn back), out of town.
		if not points.is_empty(): points.pop_back()
		var start_x: float = points[-1].x if not points.is_empty() else global_position.x
		var came := arrival_side if arrival_side != 0.0 else (1.0 if randf() < 0.5 else -1.0)
		var side := -came if randf() < 0.7 else came
		points.append(Vector3(start_x, StreetKit.PAVE_TOP, pavement_lane))
		points.append(Vector3(side * STREET_END_X, StreetKit.PAVE_TOP, pavement_lane))
	elif points.is_empty(): points = [exit_point.global_position]
	_set_route(points)

func complete_checkout(udhaar := false) -> void:
	if not has_product:
		return
	_coop_send("complete_checkout", [udhaar])
	if physical_shop() and (operations.checkout_customer() != self or state != State.PAYING or scanned_count != total_items()):
		return
	if not shop_area.business.shop_is_open():
		leave_shop()
		return
	state = State.LEAVING
	var lines := taken_lines()
	if lines.is_empty(): deal_sold = shop_area.business.sell_basket(basket_count, spending_budget, agreed_unit_price, product_id, rack_id)
	else:
		lines.push_front({"product": product_id, "count": basket_count, "rack": rack_id, "price": agreed_unit_price})
		deal_sold = shop_area.business.sell_mixed_basket(lines, spending_budget)
	review_outcome = "sold" if deal_sold else "stock"
	if deal_sold: operations.play_sound("payment")
	# Co-op team report: who served this sale (coop_world.gd, host only).
	if deal_sold and not coop_mirror: get_tree().call_group("coop_team", "record_sale", payment_total(), cashier_active)
	deal_result = "Receipt: %s | %s%d" % [payment_method, String.chr(8377), payment_total()] if deal_sold else "Customer left without buying."
	if deal_sold and udhaar and not coop_mirror and shop_area.business.give_udhaar(customer_name.get_slice(" - ", 0), payment_total()):
		deal_result = "Written in khata: %s owes %s%d." % [customer_name.get_slice(" - ", 0), String.chr(8377), payment_total()]
	leave_shop()
	get_tree().current_scene.get_node("Ui").show_feedback(deal_result, not deal_sold)

func payment_total() -> int:
	var total := agreed_unit_price * basket_count
	for line in taken_lines(): total += line.price * line.count
	return total

func change_due() -> int:
	return maxi(0, cash_tendered - payment_total()) if payment_method == "Cash" else 0

func scan_next() -> bool:
	for index in range(total_items()):
		if index not in scanned_items: return scan_item(index)
	return false

func scan_item(index: int) -> bool:
	if state != State.SCANNING or operations.checkout_customer() != self or not shop_area.business.shop_is_open(): return false
	if index < 0 or index >= total_items() or index in scanned_items or scanned_count >= total_items(): return false
	_coop_send("scan_item", [index])
	scanned_items.append(index)
	scanned_count += 1
	operations.play_sound("scan")
	operations.mark_scanned(self, index)
	if scanned_count == total_items():
		if wants_discount and quoted_price > 50: _begin_bargaining()
		else: prepare_payment(quoted_price)
	return true

func prepare_payment(price: int) -> void:
	auto_checkout_seconds = 1.0
	agreed_unit_price = price
	if price > spending_budget:
		review_outcome = "price"
		shop_area.business.record_bargain_refusal()
		deal_result = "Price too high. Customer left."
		leave_shop()
		return
	cash_tendered = ceili(payment_total() / 100.0) * 100
	state = State.PAYING
	# Regulars sometimes ask for udhaar; only the player at the till can say yes.
	var regular := shopper_type in ["regular", "family"] or shopper_type.is_empty() and personality == 1
	wants_udhaar = town_customers() and regular and randf() < 0.18 and shop_area.business.can_give_udhaar(payment_total())
	if wants_udhaar: say("Bhaiya, udhaar likh do, kal de dunga!", 5.0)
	bargain_seconds_left = 45.0
	operations.show_payment(self)

## Co-op mirror: also send this checkout action to the host's real customer. The
## mirror runs it too, so the friend's menus react at once; the host's result
## then comes back with the next customer update.
func _coop_send(method: String, args: Array) -> void:
	if coop_mirror and coop_forward.is_valid(): coop_forward.call(method, args)

func player_is_near() -> bool:
	# A friend serving at the counter (the host runs their action with this meta).
	if has_meta("coop_cashier"): return true
	if physical_shop():
		return operations.player_at_counter() and operations.checkout_customer() == self
	var player: Node3D = get_tree().current_scene.get_node("Player")
	var offset := player.global_position - purchase_point.global_position
	offset.y = 0.0
	return shop_area.player_inside and offset.length_squared() <= 9.0

func _begin_bargaining() -> void:
	if not physical_shop(): quoted_price = shop_area.selling_price
	var discount := 20 if personality == 0 else 10
	offer_price = maxi(50, mini(quoted_price - discount, spending_budget))
	acceptable_price = mini(spending_budget, quoted_price - (10 if personality == 0 else 0))
	bargain_seconds_left = 20.0
	state = State.NEGOTIATING

func resolve_bargain(choice: String, counter_price := 0) -> bool:
	if state != State.NEGOTIATING or not player_is_near():
		return false
	_coop_send("resolve_bargain", [choice, counter_price])
	if physical_shop() and not has_product:
		return false
	var price: int
	match choice:
		"accept":
			price = offer_price
		"counter":
			if counter_price <= offer_price or counter_price > quoted_price or counter_price % 10 != 0:
				return false
			price = counter_price
		"keep":
			price = quoted_price
		_:
			return false
	if physical_shop():
		if not shop_area.business.shop_is_open():
			leave_shop()
		elif price > acceptable_price:
			review_outcome = "price"
			shop_area.business.record_bargain_refusal()
			deal_result = "Offer refused. Customer left."
			leave_shop()
		else:
			prepare_payment(price)
			deal_result = "Agreed: %s%d per item" % [String.chr(8377), price]
		return true
	# Resolve before committing, so repeated clicks cannot sell twice.
	state = State.LEAVING
	if not shop_area.business.shop_is_open():
		deal_result = "Shop closed."
		leave_shop()
		return true
	if price > shop_area.selling_price:
		review_outcome = "price"
		deal_result = "Price changed. Customer left."
		shop_area.business.record_bargain_refusal()
	elif price > acceptable_price:
		review_outcome = "price"
		deal_result = "Offer refused. Customer left."
		shop_area.business.record_bargain_refusal()
	else:
		deal_sold = shop_area.business.sell_one_stock(spending_budget, price)
		agreed_unit_price = price
		review_outcome = "sold" if deal_sold else "stock"
		deal_result = "Sold for %s%d." % [String.chr(8377), price] if deal_sold else "Out of stock. Customer left."
	leave_shop()
	return true

func _walk_to(destination: Vector3, delta: float) -> bool:
	var direction := destination - global_position
	if direction.length_squared() > 0.0001:
		look_at(destination, Vector3.UP)
	global_position = global_position.move_toward(destination, walk_speed * delta)
	return global_position.distance_squared_to(destination) < 0.0001

func _wants_counter_order() -> bool:
	return physical_shop() and is_instance_valid(operations.furnishing) and not preload("res://coop.gd").active and randf() < COUNTER_ORDER_CHANCE

## The list a counter-order customer tells: the main product and the extra products
## already planned (at most three products, up to three of each, no haggling).
func _plan_counter_order() -> void:
	counter_order = true
	wants_discount = false
	order_lines = [{"product": product_id, "count": clampi(shopping_quantity, 1, 3)}]
	for line in extra_lines:
		if order_lines.size() < 3: order_lines.append({"product": line.product, "count": clampi(int(line.count), 1, 3)})
	extra_lines.clear()
	rack_id = -1

## At the front of the queue: wait at the till for the shopkeeper to take the order.
func _start_order() -> void:
	state = State.ORDERING
	order_seconds = ORDER_PATIENCE * shop_area.business.patience_factor() + chat_patience
	quoted_price = shop_area.business.product_price(product_id)
	agreed_unit_price = quoted_price
	auto_checkout_seconds = ORDER_AUTO_SECONDS + order_items() * shop_area.business.cashier_scan_seconds()
	operations.show_bag(self)
	# Sharma's cheaper price still comes up, as at the till before.
	var sharma: int = shop_area.business.rival_price_today(product_id)
	if shop_area.business.rival_open() and quoted_price > sharma: say("Sharma ji ke yahan %s%d mein milta hai!" % [String.chr(8377), sharma])
	else: say("Bhaiya, saaman dena! List hai.", 4.0)

func _update_order(delta: float) -> void:
	order_seconds -= delta
	patience_label.text = "%s\nOrder: %ds" % [customer_name.get_slice(" - ", 0), ceili(maxf(0.0, order_seconds))]
	patience_label.modulate = Color(1, 0.7, 0.25) if order_seconds < 40.0 else Color(0.8, 1, 0.85)
	patience_label.position.y = 1.9
	patience_label.show()
	# The hired cashier serves alone while nobody is at the till and the order is not taken.
	if not order_told and shop_area.business.cashier_on_shift() and not operations.someone_at_counter():
		auto_checkout_seconds -= delta
		if auto_checkout_seconds <= 0.0:
			_cashier_fills_order()
			return
	if order_seconds > 0.0: return
	review_outcome = "timeout"
	deal_result = "%s left: the order took too long." % customer_name.get_slice(" - ", 0)
	shop_area.business.record_bargain_refusal(true)
	leave_shop()
	get_tree().current_scene.get_node("Ui").show_feedback(deal_result, true)

func _cashier_fills_order() -> void:
	for line in order_lines:
		while still_needed(line.product) > 0:
			var rack: int = operations.furnishing.choose_rack(line.product)
			if operations.furnishing.available(rack, line.product) <= 0: break
			add_to_bag(line.product, rack)
	if bag_total() == 0:
		review_outcome = "stock"
		shop_area.business.record_stock_shortage()
		leave_shop()
		return
	shop_area.business.use_carry_bag()
	hand_over_bag()

## The customer says what they want (the player talked to them at the till); the
## full list shows on the right of the screen (order_panel.gd).
func tell_order() -> void:
	order_told = true
	var first: Dictionary = order_lines[0]
	var more := "" if order_lines.size() == 1 else "\naur %d cheez" % (order_lines.size() - 1)
	say("%d %s%s dena!" % [first.count, operations.Catalog.NAMES[first.product], more], 6.0)

func order_items() -> int:
	var total := 0
	for line in order_lines: total += int(line.count)
	return total

func bag_total() -> int:
	var total := 0
	for line in bag_lines: total += int(line.count)
	return total

func in_bag(product: String) -> int:
	var total := 0
	for line in bag_lines:
		if line.product == product: total += int(line.count)
	return total

func still_needed(product: String) -> int:
	for line in order_lines:
		if line.product == product: return maxi(0, int(line.count) - in_bag(product))
	return 0

## One item from `rack` into the carry bag (it stays reserved on that rack).
func add_to_bag(product: String, rack: int) -> bool:
	if state != State.ORDERING or still_needed(product) <= 0: return false
	var line: Dictionary = {}
	for item in bag_lines:
		if item.product == product and int(item.rack) == rack: line = item
	if line.is_empty():
		line = {"product": product, "rack": rack, "count": 0}
		bag_lines.append(line)
	line.count += 1
	operations.update_rack()
	return true

## Q: the last item put in the bag goes back to its rack; returns its product or "".
func take_from_bag() -> String:
	if bag_lines.is_empty(): return ""
	var line: Dictionary = bag_lines[-1]
	line.count -= 1
	if int(line.count) <= 0: bag_lines.pop_back()
	operations.update_rack()
	return line.product

## The filled bag goes to the customer: its contents become the basket (already
## counted, so nothing to scan) and the customer pays as usual.
func hand_over_bag() -> bool:
	if state != State.ORDERING or bag_total() == 0: return false
	# One line per product (a product taken from two racks sells from any rack).
	var lines: Array = []
	for line in bag_lines:
		var same: Array = lines.filter(func(item): return item.product == line.product)
		if same.is_empty(): lines.append(line.duplicate())
		else:
			same[0].count += int(line.count)
			same[0].rack = -1
	var missing := bag_total() < order_items()
	bag_lines.clear()
	product_id = lines[0].product
	rack_id = int(lines[0].rack)
	basket_count = int(lines[0].count)
	has_product = true
	extra_lines.clear()
	for line in lines.slice(1): extra_lines.append({"product": line.product, "rack": int(line.rack), "count": int(line.count), "taken": true})
	quoted_price = shop_area.business.product_price(product_id)
	agreed_unit_price = quoted_price
	scanned_items.clear()
	for index in range(total_items()): scanned_items.append(index)
	scanned_count = total_items()
	if missing: shop_area.business.record_stock_shortage()
	say("Baaki nahi hai? Chalo, theek hai." if missing else "Shukriya bhaiya!", 3.0)
	held_bottle = operations.make_carry_bag(self, "HeldBag", Vector3(0.3, 0.5, -0.12))
	held_bottle.hide()
	operations.place_counter_bag(true)
	prepare_payment(quoted_price)
	return true
