extends SceneTree

# Co-op with two real Godot processes: this one hosts the shop; a second process
# (coop_client_helper.gd) joins over ENet with the host's join code. Checks join
# codes, that the friend appears as their character with a name tag and the avatar
# follows their walk, that the friend's game gets the host's shop (a price) and the
# friend's action (soap price) changes the host's real shop and its save, the
# player list, that the pause menu neither freezes the co-op game nor stops working,
# and that the friend's avatar is removed when they leave.
const Coop := preload("res://coop.gd")
const Session := preload("res://game_session.gd")
const PORT := 17777

func _initialize() -> void:
	call_deferred("_run")

func _wait_for(condition: Callable, seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - start > seconds * 1000.0: return false
		await process_frame
	return true

func _run() -> void:
	# Join codes: round trip, forgiving typing, catching typos.
	var code := Coop.make_code("26.71.143.9", 7777)
	assert(code.length() == 13 and code[4] == "-" and code[9] == "-")
	assert(Coop.read_code(code) == {"address": "26.71.143.9", "port": 7777})
	assert(Coop.read_code(code.to_lower().replace("-", " ")) == {"address": "26.71.143.9", "port": 7777})
	var typo := code.substr(0, 2) + ("A" if code[2] != "A" else "B") + code.substr(3)
	assert(Coop.read_code(typo).is_empty(), "A mistyped code must be rejected")
	assert(Coop.read_join("192.168.1.5").address == "192.168.1.5")
	assert(Coop.make_code("10.0.0.1", 7777) != Coop.make_code("10.0.0.2", 7777))
	# Internet play: only real public addresses get an internet code.
	for address in ["49.36.12.7", "103.21.244.1"]: assert(Coop.is_public_ipv4(address), address)
	for address in ["192.168.1.5", "10.2.0.4", "172.20.1.1", "100.72.3.4", "127.0.0.1", "169.254.2.2", "26.71.143.9x"]: assert(not Coop.is_public_ipv4(address), address)
	Coop.internet_code = Coop.make_code("49.36.12.7", 7777)
	assert(Coop.host_codes()[0] == ["Internet", Coop.internet_code])
	Coop.internet_code = ""
	Coop.port = PORT
	assert(Coop.host(self, "Host", "shopkeeper") == OK)
	var save := OS.get_environment("TEMP").path_join("coop_host_%d.json" % Time.get_ticks_usec())
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = save
	Session.add_coop(fixture)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	assert(not business.has_method("_send"), "The host runs the real shop")
	assert(business.product_price("soap") != 190 and business.product_price("snack") != 180)
	assert(business.set_product_price("snack", 180))
	# The family home (and its bed) belongs to the shop, as in a game from the menu.
	assert(business.grant_home())
	# Two soap boxes arrive; the host picks up one and keeps holding it.
	assert(business.order_stock("soap", 2) and business.receive_delivery())
	assert(business.pick_up_box() and business.carried_stock == 10 and business.queued_boxes.size() == 1)
	var soap_on_shelves: int = business.inventory.soap.stock + business.inventory.soap.sold
	# A customer waits at the counter with 2 bottles, ready to scan, paying cash.
	var visitor = current_scene.get_node("Customer")
	visitor.set_physics_process(false)
	visitor.shopping_quantity = 2
	visitor.payment_method = "Cash"
	visitor.spending_budget = 200
	visitor.wants_discount = false
	for step in range(1600):
		if visitor.state == visitor.State.SCANNING: break
		visitor._physics_process(0.05)
	assert(visitor.state == visitor.State.SCANNING and visitor.total_items() == 2, "The customer never reached the counter")
	var money_before: int = business.money
	var coop = current_scene.get_node("CoopWorld")
	assert(current_scene.get_node("Player/MeshInstance3D").model == "shopkeeper")
	assert(coop.player_list.text.begins_with("CO-OP  |  1/4 players: Host (you, host)"))
	assert(coop.player_list.text.contains("Join code: "))
	var friend := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/coop_client_helper.gd", "--", Coop.make_code("127.0.0.1", PORT)])
	assert(friend > 0, "Could not start the friend's game")
	var joined: bool = await _wait_for(func(): return coop.peers.size() == 1 or not OS.is_process_running(friend), 90.0)
	assert(joined and coop.peers.size() == 1, "The friend never appeared in the host's game")
	var peer: Dictionary = coop.peers.values()[0]
	assert(peer.name == "Friend" and peer.visual.model == "aunty")
	assert(peer.avatar.get_node("NameTag").text == "Friend")
	assert(coop.player_list.text.contains("2/4 players") and coop.player_list.text.contains("Friend"))
	# The friend got the host's shop (snack at 180), then changed the soap price.
	var priced: bool = await _wait_for(func(): return business.product_price("soap") == 190 or not OS.is_process_running(friend), 60.0)
	assert(priced and business.product_price("soap") == 190, "The friend's action never reached the host's shop")
	# Night: once the friend has served the customer, both players get into bed; the
	# night passes only then, and both see the day report with the team's work.
	var served: bool = await _wait_for(func(): return visitor.deal_sold, 60.0)
	assert(served and visitor.state == visitor.State.LEAVING, "The friend's checkout did not sell in the host's shop")
	assert(business.money == money_before + visitor.payment_total(), "The sale's money is missing from the host's shop")
	# A second customer wants a discount: the friend accepts their offer at the counter.
	var bargainer = preload("res://customer.tscn").instantiate()
	bargainer.name = "Bargainer"
	bargainer.spawn_delay = 0.0
	bargainer.shop_area_path = current_scene.get_node("Shop/ShopArea").get_path()
	bargainer.purchase_point_path = current_scene.get_node("CustomerPurchasePoint").get_path()
	bargainer.exit_point_path = current_scene.get_node("CustomerExitPoint").get_path()
	current_scene.add_child(bargainer)
	bargainer.global_position = current_scene.get_node("CustomerSpawnPoint").global_position
	bargainer.set_physics_process(false)
	bargainer.shopping_quantity = 1
	bargainer.payment_method = "UPI"
	bargainer.spending_budget = 200
	bargainer.wants_discount = true
	bargainer.personality = 1
	for step in range(1600):
		if bargainer.state == bargainer.State.SCANNING: break
		bargainer._physics_process(0.05)
	assert(bargainer.state == bargainer.State.SCANNING, "The second customer never reached the counter")
	var bargained: bool = await _wait_for(func(): return bargainer.deal_sold, 60.0)
	assert(bargained and bargainer.agreed_unit_price == bargainer.offer_price and bargainer.offer_price < bargainer.quoted_price, "The friend's accepted offer did not sell at the offer price")
	business.minutes_of_day = 1210.0
	business.clock_changed.emit()
	var sleep_spot: Vector3 = current_scene.get_node("House/Bed/SleepArea/CollisionShape3D").global_position
	var host_player: CharacterBody3D = current_scene.get_node("Player")
	host_player.set_physics_process(false)
	host_player.global_position = sleep_spot
	for frame in range(3): await physics_frame
	coop.request_sleep()
	assert(business.day == 1 and coop.local_in_bed, "The night must wait for the friend")
	var morning: bool = await _wait_for(func(): return business.day == 2, 60.0)
	assert(morning and is_equal_approx(business.minutes_of_day, 480.0), "The night did not pass with everyone in bed")
	var report = current_scene.get_node("Ui/DayReportScreen")
	assert(report.visible and not paused and report.team_label.visible)
	assert(report.team_label.text.contains("Host: sold") and report.team_label.text.contains("Friend: sold"), report.team_label.text)
	assert(report.team_label.text.contains("to 2 customers, shelved 1 item"), report.team_label.text)
	report.close()
	# The friend carries the other box at the same time as the host (seen in their hands).
	var carrying: bool = await _wait_for(func(): return peer.box.visible, 30.0)
	assert(carrying, "The friend's avatar never showed their box")
	# While the friend holds it, the host's save stays valid and counts that box.
	var counted: bool = await _wait_for(func():
		var data = JSON.parse_string(FileAccess.get_file_as_string(save))
		return data is Dictionary and data.has("coop_carried") and int(data.coop_carried[0].amount) >= 9, 30.0)
	assert(counted, "The host's save did not count the friend's box")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(save))
	assert(saved is Dictionary and int(saved.inventory.snack.price) == 180 and int(saved.inventory.soap.price) == 190, "The host saves the co-op shop, friends' actions included")
	# The friend walks 4 m east; their avatar follows smoothly in the host's town.
	var seen: bool = await _wait_for(func(): return peer.has("seen"), 30.0)
	assert(seen, "No position updates arrived from the friend")
	var first: Vector3 = peer.avatar.position
	var walked: bool = await _wait_for(func(): return peer.avatar.position.x > first.x + 3.0, 30.0)
	assert(walked, "The friend's avatar did not follow their walk")
	# The pause menu keeps the shared game running and its buttons working.
	var pause = current_scene.get_node("Ui/PauseMenu")
	pause.open_menu()
	assert(not paused and pause.can_process())
	assert(pause.find_child("CopyCoopCode", true, false) != null)
	pause.close_menu()
	var left: bool = await _wait_for(func(): return coop.peers.is_empty(), 60.0)
	assert(left, "The friend's avatar stayed after they left")
	assert(coop.toast.text == "Friend left the shop")
	# The friend left holding their box: it went back to the bay. The host's own box
	# was never touched by the friend's carrying.
	assert(business.carried_stock == 10 and business.pending_product == "soap", "The host's own box changed")
	# (A customer may have bought it since, so count soap sold too.)
	assert(business.inventory.soap.stock + business.inventory.soap.sold == soap_on_shelves + 1, "The friend's shelved soap is missing from the host's shelves")
	assert(business.queued_boxes.size() == 1 and int(business.queued_boxes[0].amount) == 9 and business.queued_boxes[0].product == "soap", "The friend's box did not come back to the bay")
	assert(business.logistics.ground_boxes.is_empty() and business.coop_carries.is_empty())
	var final_save = JSON.parse_string(FileAccess.get_file_as_string(save))
	assert(final_save is Dictionary and not final_save.has("coop_carried") and final_save.queued_boxes.size() == 1, "The host's save holds the returned box")
	if OS.is_process_running(friend): OS.kill(friend)
	Coop.leave(self)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save + suffix): DirAccess.remove_absolute(save + suffix)
	print("PASS: co-op over two game processes: join codes, friend with character and name tag, shared shop both ways (host price to friend, friend price to host and its save), both players carrying their own box at once (pick up, put down, pick up from the ground, shelving, box shown in hands, returned to the bay on leaving), the host's customer mirrored on the friend's screen and served by the friend at the counter (scan, bargain, pay, sales in the host's shop), sleeping together (night passes only with everyone in bed) and the team day report on both screens, internet-code address checks, avatar follows the walk, player list, pause keeps running, removed on leave")
	quit()
