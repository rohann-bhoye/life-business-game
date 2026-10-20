extends SceneTree

# Talk boxes: E on an employee opens a conversation (portrait, name, line, numbered
# replies, keys 1-4 and Esc), and E on a shopper starts a chat where help,
# a product suggestion and a price question each work once and the shopper waits.

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = code
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func _inside(box: Panel) -> void:
	var controls = box.get_children().filter(func(node): return node is Control and node.visible)
	for index in range(controls.size()):
		assert(Rect2(Vector2.ZERO, box.size).encloses(controls[index].get_rect()), str(controls[index].name))
		assert(controls[index].get_combined_minimum_size().x <= controls[index].size.x + 0.5, str(controls[index].name))
		for other in range(index + 1, controls.size()): assert(not controls[index].get_rect().intersects(controls[other].get_rect()), "%s / %s" % [controls[index].name, controls[other].name])
	assert(Rect2(Vector2.ZERO, box.get_viewport().get_visible_rect().size).encloses(box.get_rect()))

func _run() -> void:
	var scene = load("res://main.tscn.tscn").instantiate()
	scene.get_node("Shop/ShopArea").save_path = OS.get_environment("TEMP").path_join("talk_%d.json" % Time.get_ticks_usec())
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	scene.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	var world = current_scene
	world.get_node("DayClock").set_process(false)
	world.get_node("CustomerSpawner/SpawnTimer").stop()
	var player = world.get_node("Player")
	player.set_physics_process(false)
	var ops = world.get_node("ShopOperations")
	var ui = world.get_node("Ui")
	var business = world.get_node("Shop/ShopArea").business
	var staff_box = ui.staff_dialog
	var chat = ui.customer_chat
	player.shop_indoors = true
	# Sunil: E, a talk with four replies; 1 thanks him, then 1 is "Okay".
	assert(business.hire_stock_worker())
	var sunil = world.get_node("StockWorker")
	sunil.position = Vector3(-4.6, 0.1, -1.8)
	sunil.show()
	player.position = Vector3(-4.6, 1.1, -0.2)
	player.camera.look_at(sunil.global_position + Vector3(0, 1.5, 0))
	assert(ops.interaction_hint().begins_with("Talk to Sunil"))
	_key(KEY_E)
	assert(staff_box.visible and player._menu_is_open())
	assert(staff_box.get_node("SpeakerLabel").text == "Sunil" and staff_box.initial.text == "S")
	assert(staff_box.choices.filter(func(button): return button.visible).size() == 4)
	assert(staff_box.choices[0].text.begins_with("1"))
	var happiness: int = business.staff.records.stock.happiness
	_key(KEY_1)
	assert(business.staff.records.stock.happiness != happiness or business.staff.records.stock.last_talk_day == business.day)
	assert(staff_box.actions == ["close"] and staff_box.choices[0].visible and not staff_box.choices[1].visible)
	for size in [Vector2i(1152, 648), Vector2i(640, 480), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		staff_box._layout()
		_inside(staff_box)
	root.size = Vector2i(1152, 648)
	await process_frame
	_key(KEY_1)
	assert(not staff_box.visible and not player._menu_is_open())
	# Thanks work once a day.
	player.camera.look_at(sunil.global_position + Vector3(0, 1.5, 0))
	_key(KEY_E)

	assert(staff_box.visible and staff_box.choices[0].disabled and staff_box.choices[1].disabled)
	_key(KEY_ESCAPE)
	assert(not staff_box.visible and not player._menu_is_open())
	sunil.hide()
	# A shopper on the way to the shelves.
	var shopper = world.get_node("Customer")
	shopper.set_physics_process(false)
	shopper.show()
	shopper.product_id = "snack"
	shopper.spending_budget = 1000
	shopper.shopper_type = "family"
	shopper.state = shopper.State.ARRIVING
	shopper.global_position = Vector3(-3.0, 0.1, -1.0)
	shopper._set_route([Vector3(-3.0, 0.1, -3.0)] as Array[Vector3])
	player.position = Vector3(-3.0, 1.1, 0.6)
	player.camera.global_position = Vector3(-3.0, 1.6, 0.6)
	player.camera.look_at(shopper.global_position + Vector3(0, 1.1, 0))
	assert(ops.shopper_target() == shopper)
	assert(ops.interaction_hint() == "Talk to %s" % shopper.customer_name.get_slice(" - ", 0))
	_key(KEY_E)
	assert(chat.visible and chat.customer == shopper and shopper.chatting and player._menu_is_open())
	assert(chat.get_node("HappinessLabel").text.begins_with("Family shopper"))
	assert(chat.suggestion == "bottle" and chat.choices[1].text.contains("Cold drink") and not chat.choices[1].disabled)
	# Talking holds them in place.
	var spot: Vector3 = shopper.global_position
	shopper._physics_process(0.5)
	assert(shopper.global_position == spot)
	var patience: float = shopper.queue_patience_limit()
	_key(KEY_1)
	assert(shopper.chat_done.has("help") and shopper.queue_patience_limit() == patience + 30.0 and chat.choices[0].disabled)
	_key(KEY_1)
	assert(shopper.queue_patience_limit() == patience + 30.0)
	var lines: int = shopper.extra_lines.size()
	_key(KEY_2)
	assert(shopper.chat_done.has("suggest") and chat.choices[1].disabled)
	var message: String = chat.get_node("MessageLabel").text
	if shopper.extra_lines.size() == lines + 1:
		assert(shopper.extra_lines[-1].product == "bottle" and message.contains("Cold drink") and not shopper.wants_discount)
	else:
		assert(message.contains("aaj nahi"))
	_key(KEY_3)
	assert(shopper.chat_done.has("prices") and chat.get_node("MessageLabel").text.contains(String.chr(8377)))
	for size in [Vector2i(1152, 648), Vector2i(360, 640)]:
		root.size = size
		await process_frame
		chat._layout()
		_inside(chat)
	root.size = Vector2i(1152, 648)
	await process_frame
	_key(KEY_4)
	assert(not chat.visible and not shopper.chatting and not player._menu_is_open())
	shopper._physics_process(0.5)
	assert(shopper.global_position != spot)
	# In the queue: "sorry for the wait" instead of help, no suggestion.
	shopper.state = shopper.State.QUEUING
	shopper.chat_done.clear()
	ops.queue.append(world.get_node("Worker"))
	ops.queue.append(shopper)
	chat.open_for(shopper)
	assert(chat.choices[0].text.begins_with("1   Sorry") and chat.choices[1].disabled)
	chat.close_menu()
	ops.queue.clear()
	# Not at the till: the paying customer is the counter's, not a chat.
	ops.queue.append(shopper)
	assert(ops.shopper_target() == null)
	ops.queue.clear()
	print("PASS: staff and shopper talk boxes, portrait/name/replies, keys 1-4 and Esc, once-a-day thanks, help/sorry patience, suggestion, prices, shopper waits while talking, layouts")
	quit()
