extends Node3D

enum State { WAITING, ARRIVING, BUYING, LEAVING, NEGOTIATING, TAKING, TO_COUNTER, QUEUING, CHECKOUT, SCANNING, PAYING }

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
var queue_wait_seconds := 0.0
var patience_label: Label3D

@onready var shop_area: Area3D = get_node(shop_area_path)
@onready var purchase_point: Marker3D = get_node(purchase_point_path)
@onready var exit_point: Marker3D = get_node(exit_point_path)

func _ready() -> void:
	operations = get_tree().current_scene.get_node_or_null("ShopOperations")
	spending_budget = randi_range(10, 20) * 10
	personality = randi_range(0, 2)
	customer_name = ["Ravi - Bargain hunter", "Meena - Regular", "Aman - In a hurry"][personality]
	wants_discount = randf() < [0.75, 0.35, 0.0][personality]
	shopping_quantity = randi_range(1, 3)
	payment_method = ["Cash", "Card", "UPI"][randi_range(0, 2)]
	visible = false
	wait_remaining = spawn_delay
	patience_label = Label3D.new()
	patience_label.name = "PatienceLabel"
	patience_label.position = Vector3(0, 1.9, 0)
	patience_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	patience_label.font_size = 28
	patience_label.pixel_size = 0.006
	patience_label.outline_size = 6
	patience_label.hide()
	add_child(patience_label)

func _physics_process(delta: float) -> void:
	if state in [State.QUEUING, State.BUYING, State.SCANNING, State.NEGOTIATING, State.PAYING, State.CHECKOUT]:
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
					var choices: Array[String] = []
					for id in operations.Catalog.IDS:
						if operations.available_stock(id) > 0: choices.append(id)
					if not choices.is_empty(): product_id = choices.pick_random()
					if is_instance_valid(operations.furnishing): rack_id = operations.furnishing.choose_rack(product_id)
					var points: Array[Vector3] = operations.customer_entry_route(product_id, rack_id)
					_set_route(points)
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
				var available: int = operations.furnishing.available(rack_id, product_id) if rack_id >= 0 and is_instance_valid(operations.furnishing) else operations.available_stock(product_id)
				if available <= 0:
					review_outcome = "stock"
					shop_area.business.record_stock_shortage()
					leave_shop()
				else:
					has_product = true
					basket_count = mini(shopping_quantity, available)
					held_bottle = operations.make_product(self, "HeldBottle", Vector3(0.32, 0.9, -0.2), product_id)
					operations.update_rack()
					_set_route(shop_area.business.racks.route(global_position, Vector3(-4.6, 0.1, 1.65)))
					state = State.TO_COUNTER
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
					else:
						quoted_price = shop_area.business.product_price(product_id)
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
			if physical_shop() and shop_area.business.cashier_on_shift() and not operations.player_at_counter():
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
		State.LEAVING:
			if (_walk_route(delta) if physical_shop() else _walk_to(exit_point.global_position, delta)):
				queue_free()

func physical_shop() -> bool:
	return is_instance_valid(operations) and operations.enabled

func queue_patience_limit() -> float:
	return [90.0, 120.0, 60.0][clampi(personality, 0, 2)]

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
	if not review_recorded and (deal_sold or not review_outcome.is_empty()):
		review_recorded = true
		shop_area.business.record_customer_review("sold" if deal_sold else review_outcome, service_wait_seconds, agreed_unit_price < quoted_price)
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
	if global_position.z > 2.6:
		_set_route([exit_point.global_position])
	else:
		var points: Array[Vector3] = shop_area.business.racks.route(global_position, Vector3(-4.6, 0.1, 1.65))
		points.append_array(operations.customer_exit_route())
		_set_route(points)

func complete_checkout() -> void:
	if not has_product:
		return
	if physical_shop() and (operations.checkout_customer() != self or state != State.PAYING or scanned_count != basket_count):
		return
	if not shop_area.business.shop_is_open():
		leave_shop()
		return
	state = State.LEAVING
	deal_sold = shop_area.business.sell_basket(basket_count, spending_budget, agreed_unit_price, product_id, rack_id)
	review_outcome = "sold" if deal_sold else "stock"
	if deal_sold: operations.play_sound("payment")
	deal_result = "Receipt: %s | %s%d" % [payment_method, String.chr(8377), payment_total()] if deal_sold else "Customer left without buying."
	leave_shop()
	get_tree().current_scene.get_node("Ui").show_feedback(deal_result, not deal_sold)

func payment_total() -> int:
	return agreed_unit_price * basket_count

func change_due() -> int:
	return maxi(0, cash_tendered - payment_total()) if payment_method == "Cash" else 0

func scan_next() -> bool:
	for index in range(basket_count):
		if index not in scanned_items: return scan_item(index)
	return false

func scan_item(index: int) -> bool:
	if state != State.SCANNING or operations.checkout_customer() != self or not shop_area.business.shop_is_open(): return false
	if index < 0 or index >= basket_count or index in scanned_items or scanned_count >= basket_count: return false
	scanned_items.append(index)
	scanned_count += 1
	operations.play_sound("scan")
	operations.mark_scanned(self, index)
	if scanned_count == basket_count:
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
	bargain_seconds_left = 45.0
	operations.show_payment(self)

func player_is_near() -> bool:
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
