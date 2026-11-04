extends Node

# The in-game side of co-op. Added to the game scene by game_session.gd only in co-op.
# Players: every player sees the others walking around town as their chosen
# character with a name tag. Each game sends its own player's position and facing
# 20 times a second; the others glide that friend's avatar toward it, and the
# character walks by itself. Joining or leaving pops up a notice; a player list and
# the host's join code sit at the top; if the host leaves, friends return to the menu.
# Shop: the host's game runs the real shop and saves it in the host's slot. It sends
# the whole shop (compressed snapshot) whenever it changes, at most 5 times a second,
# and the clock twice a second. A friend's game loads that, runs none of its own
# clock, customers, staff or saving, and sends its player actions to the host
# (remote_backend.gd), which checks each against an allowed list.
# Customers and staff: the host runs them; friends see mirrors and can serve at the
# counter. Night: everyone gets into bed, then the host skips to morning and every
# player sees the day report with a team section (who sold and shelved what).
const Coop := preload("res://coop.gd")
const Session := preload("res://game_session.gd")
const RemoteBackend := preload("res://remote_backend.gd")
const SEND_INTERVAL := 0.05
const SHOP_INTERVAL := 0.2
const CLOCK_INTERVAL := 0.5
## Simulations that change the shop by themselves run in the host's game only.
const HOST_ONLY_SCRIPTS := ["res://stock_worker.gd", "res://farm_worker.gd", "res://warehouse_receiver.gd", "res://customer.gd"]
## Workers friends still see, placed where the host's are.
const STAFF_SCRIPTS := ["res://stock_worker.gd", "res://farm_worker.gd", "res://warehouse_receiver.gd"]
const CUSTOMER_INTERVAL := 0.1
## Checkout actions a friend may ask the host's customer to do.
const CUSTOMER_ACTIONS := ["scan_item", "resolve_bargain", "complete_checkout"]
## Friends start on the home path, in front of the gate, side by side.
## Where a friend arrives: in the home yard, just inside the gate (house-local, so it follows the home).
const FRIEND_SPAWN_LOCAL := Vector3(-0.8, 1.0, 4.9)
## id -> {"name", "model", "avatar", "visual", "target", "yaw"}
var peers := {}
var send_wait := 0.0
var shop_wait := 0.0
var clock_wait := 0.0
var shop_dirty := true
## A friend's game: whether the host's shop has arrived yet.
var shop_received := false
var host_name := "the host"
var customer_wait := 0.0
var staff_lookup := 0.0
var staff_nodes: Array = []
## The host's game: the next id given to a customer, so friends can match mirrors.
var next_customer_id := 1
## A friend's game: host customer id -> mirror customer.
var mirrors := {}
var toast_time := 0.0
## Sleeping together. The host's game: who is in bed (1 = the host). Every game:
## whether this player is in bed and the "In bed: x/y" line.
var sleep_ready := {}
var local_in_bed := false
var beds_line := ""
var shown_internet := ""
## The host's game: today's team work, key (player id or "staff") -> {sold, sales, shelved},
## and who is acting right now (a friend during their action, else the host).
var team := {}
var team_day := 0
var actor = 1
var hud: CanvasLayer
var player_list: Label
var toast: Label
@onready var world := get_parent()
@onready var player: Node3D = world.get_node("Player")
@onready var player_visual: Node3D = player.get_node("MeshInstance3D")
@onready var business = world.get_node("Shop/ShopArea").business
@onready var operations = world.get_node("ShopOperations")
@onready var sleep_area: Area3D = world.get_node_or_null("House/Bed/SleepArea")

func friend_spawn() -> Vector3:
	return world.get_node("House").to_global(FRIEND_SPAWN_LOCAL)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_host_left)
	if Coop.hosting:
		business.changed.connect(func(): shop_dirty = true)
		business.shelved.connect(_on_shelved)
		add_to_group("coop_team")
		team_day = business.day
	else:
		player.global_position = friend_spawn() + Vector3((multiplayer.get_unique_id() % 3) * 0.9, 0, 0)
		_become_friend()
	_refresh_list()
	# Everyone already in the game answers with their own introduction.
	_introduce.rpc(Coop.player_name, Coop.model, Coop.hosting)

func _on_peer_connected(id: int) -> void:
	_introduce.rpc_id(id, Coop.player_name, Coop.model, Coop.hosting)

@rpc("any_peer", "call_remote", "reliable")
func _introduce(peer_name: String, peer_model: String, peer_hosting: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if peers.has(id): return
	var avatar := Node3D.new()
	avatar.name = "CoopPeer%d" % id
	avatar.position = friend_spawn()
	var visual := MeshInstance3D.new()
	visual.name = "CharacterVisual"
	visual.set_script(preload("res://character_visual.gd"))
	visual.model = Coop.clean_model(peer_model)
	visual.feet_offset = -1.0
	avatar.add_child(visual)
	var tag := Label3D.new()
	tag.name = "NameTag"
	tag.text = Coop.clean_name(peer_name) + ("  (host)" if peer_hosting and id == 1 else "")
	tag.position.y = 1.15
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.fixed_size = true
	tag.pixel_size = 0.0022
	tag.font_size = 30
	tag.outline_size = 8
	tag.modulate = Color("fde68a")
	tag.no_depth_test = true
	avatar.add_child(tag)
	# A cardboard box in their hands while they carry one (the arms take the carry pose).
	var box := MeshInstance3D.new()
	box.name = "CarriedBox"
	var cube := BoxMesh.new()
	cube.size = Vector3(0.46, 0.32, 0.36)
	var cardboard := StandardMaterial3D.new()
	cardboard.albedo_color = Color(0.72, 0.53, 0.32)
	cube.material = cardboard
	box.mesh = cube
	box.position = Vector3(0, 0.05, -0.55)
	box.visible = false
	visual.add_child(box)
	visual.carry_target = box
	add_child(avatar)
	peers[id] = {"name": Coop.clean_name(peer_name), "model": visual.model, "avatar": avatar, "visual": visual, "box": box, "target": friend_spawn(), "yaw": 0.0}
	if id == 1: host_name = peers[id].name
	_show_toast("%s joined the shop" % peers[id].name)
	_refresh_list()
	# A new friend gets the whole shop straight away.
	if Coop.hosting: _send_shop(id)
	# Make sure a friend who arrived late also learns about us.
	_introduce.rpc_id(id, Coop.player_name, Coop.model, Coop.hosting)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _player_state(position: Vector3, yaw: float, carrying: bool) -> void:
	var peer = peers.get(multiplayer.get_remote_sender_id())
	if peer == null or not position.is_finite(): return
	# The first update places the avatar at once; after that it glides.
	if not peer.has("seen"):
		peer.seen = true
		peer.avatar.position = position
	peer.target = position
	peer.yaw = yaw
	peer.box.visible = carrying

func _process(delta: float) -> void:
	_fade_speech(delta)
	send_wait -= delta
	if send_wait <= 0.0 and _connected():
		send_wait = SEND_INTERVAL
		_player_state.rpc(player.global_position, player_visual.global_rotation.y, business.carried_stock > 0)
	if Coop.hosting and not peers.is_empty():
		shop_wait -= delta
		clock_wait -= delta
		if shop_dirty and shop_wait <= 0.0:
			shop_wait = SHOP_INTERVAL
			shop_dirty = false
			_send_shop()
		if clock_wait <= 0.0:
			clock_wait = CLOCK_INTERVAL
			_clock.rpc(business.day, business.minutes_of_day)
		customer_wait -= delta
		if customer_wait <= 0.0:
			customer_wait = CUSTOMER_INTERVAL
			_customers.rpc(_host_customers(), operations.queue.map(func(customer): return int(customer.get_meta("coop_id", -1))))
			_staff.rpc(_host_staff())
		# A friend at the counter serves; the hired cashier waits.
		operations.coop_friend_at_counter = peers.values().any(func(peer):
			var offset: Vector3 = peer.avatar.global_position - operations.cashier_point
			return Vector2(offset.x, offset.z).length() <= 1.25)
	_move_mirrors(delta)
	for peer in peers.values():
		var avatar: Node3D = peer.avatar
		# A long jump (sleeping, entering a building) snaps instead of sliding.
		if avatar.position.distance_to(peer.target) > 6.0: avatar.position = peer.target
		else: avatar.position = avatar.position.lerp(peer.target, minf(1.0, delta * 12.0))
		var visual: Node3D = peer.visual
		visual.global_rotation.y = lerp_angle(visual.global_rotation.y, peer.yaw, minf(1.0, delta * 12.0))
	# The router's answer about internet play arrives a few seconds after hosting.
	if Coop.hosting and Coop.internet_code + Coop.internet_note != shown_internet: _refresh_list()
	# Walking away from the bed means not sleeping after all.
	if local_in_bed and sleep_area != null and not sleep_area.overlaps_body(player): _leave_bed()
	if Coop.hosting and business.day != team_day:
		team.clear()
		team_day = business.day
	if toast_time > 0.0:
		toast_time -= delta
		toast.modulate.a = clampf(toast_time, 0.0, 1.0)

# --- The shared shop ---

## A friend's game: the host runs the shop, so stop everything that changes it here,
## send player actions to the host and never save.
func _become_friend() -> void:
	business.save_path = ""
	business.forward = func(method: String, args: Array): _action.rpc_id(1, method, args)
	business.coop_blocked.connect(_show_toast)
	world.get_node("DayClock").set_process(false)
	var spawner := world.get_node_or_null("CustomerSpawner")
	if spawner != null:
		spawner.set_process(false)
		spawner.get_node("SpawnTimer").stop()
		spawner.get_node("SpawnTimer").autostart = false
	for node in world.find_children("*", "", true, false): _stop_host_only(node)
	get_tree().node_added.connect(_stop_host_only)

func _stop_host_only(node: Node) -> void:
	var script = node.get_script()
	if script == null or not script.resource_path in HOST_ONLY_SCRIPTS or node.get("coop_mirror") == true: return
	node.process_mode = Node.PROCESS_MODE_DISABLED
	# Staff stay in view and follow the host's (_staff); the friend's own customers go.
	if node is Node3D and not script.resource_path in STAFF_SCRIPTS: node.hide()

# --- Customers and staff: the host's game runs them; friends see mirrors ---

## Everything a friend's mirror needs about each of the host's customers.
func _host_customers() -> Array:
	var result := []
	for child in world.get_children():
		if not child.has_method("resolve_bargain") or child.is_queued_for_deletion(): continue
		if not child.has_meta("coop_id"):
			child.set_meta("coop_id", next_customer_id)
			next_customer_id += 1
		var visual = child.get_node_or_null("CharacterVisual")
		result.append({"id": child.get_meta("coop_id"), "position": child.global_position, "yaw": child.global_rotation.y, "shown": child.visible,
			"model": visual.model_id if visual != null else "", "state": child.state, "name": child.customer_name, "product": child.product_id,
			"count": child.basket_count, "has": child.has_product, "lines": child.extra_lines, "rack": child.rack_id, "scanned": child.scanned_items,
			"agreed": child.agreed_unit_price, "quoted": child.quoted_price, "offer": child.offer_price, "acceptable": child.acceptable_price,
			"budget": child.spending_budget, "discount": child.wants_discount, "personality": child.personality, "payment": child.payment_method,
			"cash": child.cash_tendered, "bargain": child.bargain_seconds_left, "cashier": child.cashier_active, "auto": child.auto_checkout_seconds,
			"speech": child.speech_label.text if child.speech_label.visible else "", "patience": child.patience_label.text if child.patience_label.visible else "",
			"result": child.deal_result})
	return result

## Positions of the stock, farm and warehouse workers in the host's game (the list
## of workers is looked up every 2 seconds, not every frame).
func _host_staff() -> Array:
	staff_lookup -= CUSTOMER_INTERVAL
	if staff_lookup <= 0.0:
		staff_lookup = 2.0
		staff_nodes = world.find_children("*", "Node3D", true, false).filter(func(node): return node.get_script() != null and node.get_script().resource_path in STAFF_SCRIPTS)
	var result := []
	for node in staff_nodes:
		if is_instance_valid(node): result.append([str(world.get_path_to(node)), node.global_position, node.global_rotation.y, node.visible])
	return result

@rpc("authority", "call_remote", "unreliable_ordered")
func _customers(list: Array, queue: Array) -> void:
	var seen := {}
	for data in list:
		var id := int(data.id)
		seen[id] = true
		if not mirrors.has(id) or not is_instance_valid(mirrors[id]): mirrors[id] = _make_mirror(id, data)
		_apply_mirror(mirrors[id], data)
	for id in mirrors.keys():
		if seen.has(id): continue
		var gone = mirrors[id]
		mirrors.erase(id)
		if is_instance_valid(gone):
			operations.clear_basket(gone)
			operations.remove_customer(gone)
			gone.queue_free()
	var ordered: Array[Node3D] = []
	for id in queue:
		if mirrors.has(int(id)): ordered.append(mirrors[int(id)])
	operations.queue = ordered
	_sync_counter()

func _make_mirror(id: int, data: Dictionary) -> Node3D:
	var mirror = preload("res://customer.tscn").instantiate()
	mirror.name = "CoopCustomer%d" % id
	mirror.coop_mirror = true
	mirror.coop_forward = func(method: String, args: Array): _customer_action.rpc_id(1, id, method, args)
	mirror.spawn_delay = 0.0
	mirror.shop_area_path = world.get_node("Shop/ShopArea").get_path()
	mirror.purchase_point_path = world.get_node("CustomerPurchasePoint").get_path()
	mirror.exit_point_path = world.get_node("CustomerExitPoint").get_path()
	mirror.get_node("CharacterVisual").model = str(data.model)
	world.add_child(mirror)
	mirror.global_position = data.position
	return mirror

func _apply_mirror(mirror: Node3D, data: Dictionary) -> void:
	mirror.set_meta("coop_target", data.position)
	mirror.set_meta("coop_yaw", data.yaw)
	mirror.visible = data.shown
	var was_paying: bool = mirror.state == mirror.State.PAYING
	mirror.state = int(data.state)
	for field in [["customer_name", "name"], ["product_id", "product"], ["basket_count", "count"], ["has_product", "has"], ["rack_id", "rack"], ["agreed_unit_price", "agreed"], ["quoted_price", "quoted"], ["offer_price", "offer"], ["acceptable_price", "acceptable"], ["spending_budget", "budget"], ["wants_discount", "discount"], ["personality", "personality"], ["payment_method", "payment"], ["cash_tendered", "cash"], ["bargain_seconds_left", "bargain"], ["cashier_active", "cashier"], ["auto_checkout_seconds", "auto"], ["deal_result", "result"]]:
		mirror.set(field[0], data[field[1]])
	mirror.extra_lines = data.lines
	var before: Array[int] = mirror.scanned_items.duplicate()
	var scanned: Array[int] = []
	for index in data.scanned: scanned.append(int(index))
	mirror.scanned_items = scanned
	mirror.scanned_count = scanned.size()
	# Scans and payments the friend did not just make themselves animate here.
	if operations.basket_customer == mirror:
		for index in scanned:
			if not index in before: operations.mark_scanned(mirror, index)
		if mirror.state == mirror.State.PAYING and not was_paying: operations.show_payment(mirror)
	for label in [[mirror.speech_label, data.speech], [mirror.patience_label, data.patience]]:
		label[0].text = label[1]
		label[0].visible = not str(label[1]).is_empty()

## The counter shows the basket of the customer being served (scan, pay) or nothing.
func _sync_counter() -> void:
	var checkout = operations.checkout_customer()
	var serving = checkout if is_instance_valid(checkout) and checkout.state in [checkout.State.SCANNING, checkout.State.NEGOTIATING, checkout.State.PAYING] else null
	if operations.basket_customer == serving: return
	if is_instance_valid(operations.basket_customer): operations.clear_basket(operations.basket_customer)
	if serving == null: return
	operations.show_basket(serving)
	for index in serving.scanned_items: operations.mark_scanned(serving, index)
	if serving.state == serving.State.PAYING: operations.show_payment(serving)

func _move_mirrors(delta: float) -> void:
	for mirror in mirrors.values():
		if not is_instance_valid(mirror) or not mirror.has_meta("coop_target"): continue
		var target: Vector3 = mirror.get_meta("coop_target")
		if mirror.global_position.distance_to(target) > 4.0: mirror.global_position = target
		else: mirror.global_position = mirror.global_position.lerp(target, minf(1.0, delta * 10.0))
		mirror.global_rotation.y = lerp_angle(mirror.global_rotation.y, float(mirror.get_meta("coop_yaw")), minf(1.0, delta * 10.0))

@rpc("authority", "call_remote", "unreliable_ordered")
func _staff(list: Array) -> void:
	for entry in list:
		var node := world.get_node_or_null(NodePath(entry[0])) as Node3D
		if node == null: continue
		node.global_position = node.global_position.lerp(entry[1], 0.5) if node.global_position.distance_to(entry[1]) < 4.0 else entry[1]
		node.global_rotation.y = entry[2]
		node.visible = entry[3]

## The host runs a friend's checkout action (scan, bargain, payment) on the real
## customer, as if someone stood at the counter.
@rpc("any_peer", "call_remote", "reliable")
func _customer_action(id: int, method: String, args: Array) -> void:
	if not Coop.hosting or not peers.has(multiplayer.get_remote_sender_id()) or not method in CUSTOMER_ACTIONS: return
	for child in world.get_children():
		if child.get_meta("coop_id", -1) != id or not child.has_method(method): continue
		child.set_meta("coop_cashier", true)
		actor = multiplayer.get_remote_sender_id()
		child.callv(method, args)
		actor = 1
		if is_instance_valid(child): child.remove_meta("coop_cashier")
		return

## Sends the shop to one friend (id) or all of them, each with their own box in hand.
func _send_shop(id := 0) -> void:
	var data: Dictionary = business.snapshot()
	for peer_id in ([id] if id != 0 else peers.keys()):
		var raw := JSON.stringify(business.coop_view(data, business.coop_carry(peer_id))).to_utf8_buffer()
		_shop_state.rpc_id(peer_id, raw.compress(FileAccess.COMPRESSION_ZSTD), raw.size())

@rpc("authority", "call_remote", "reliable")
func _shop_state(packed: PackedByteArray, size: int) -> void:
	if size <= 0 or size > 1048576: return
	var parser := JSON.new()
	if parser.parse(packed.decompress(size, FileAccess.COMPRESSION_ZSTD).get_string_from_utf8()) != OK or not parser.data is Dictionary: return
	business.restore(parser.data)
	if not shop_received:
		shop_received = true
		_refresh_list()
	business.changed.emit()
	business.clock_changed.emit()

@rpc("authority", "call_remote", "unreliable_ordered")
func _clock(day: int, minutes: float) -> void:
	if not is_finite(minutes): return
	business.day = day
	business.minutes_of_day = minutes
	business.clock_changed.emit()

## The host carries out a friend's action on the real shop, with the friend's own
## box in hand (business_backend.gd coop_begin), then sends the shop back.
@rpc("any_peer", "call_remote", "reliable")
func _action(method: String, args: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not Coop.hosting or not peers.has(sender) or not method in RemoteBackend.ACTIONS: return
	# Friends never act as the stock worker.
	if method in ["pick_up_box", "shelve_box"] and not args.is_empty() and args[0] == true: return
	actor = sender
	business.coop_begin(sender)
	business.callv(method, args)
	business.coop_end(sender)
	actor = 1
	# The action saved and refreshed with the friend's box in hand; do both again now
	# that the host's own box is back.
	business.save_progress()
	business.changed.emit()

## Friends' boxes go back to the delivery bay (a friend leaving, or the host closing).
func return_friend_boxes() -> void:
	business.coop_return_boxes()

func _connected() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _on_peer_disconnected(id: int) -> void:
	if not peers.has(id): return
	_show_toast("%s left the shop" % peers[id].name)
	peers[id].avatar.queue_free()
	peers.erase(id)
	if Coop.hosting:
		business.coop_return_boxes([id])
		if sleep_ready.has(id): _mark_in_bed(id, false)
		elif not sleep_ready.is_empty(): _mark_in_bed(1, sleep_ready.has(1))
	_refresh_list()

func _on_host_left() -> void:
	Coop.last_message = "The host closed the co-op shop."
	Coop.leave(get_tree())
	var tree := get_tree()
	tree.paused = false
	Session.launch_menu(tree, Coop.menu_save_path if not Coop.menu_save_path.is_empty() else "user://save.json", world.get_meta("session_settings_path", "user://settings.cfg"))

# --- HUD: player list at the top and a short notice when someone joins or leaves ---

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "CoopHud"
	hud.layer = 5
	add_child(hud)
	player_list = Label.new()
	player_list.name = "PlayerList"
	player_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_list.add_theme_font_size_override("font_size", 14)
	player_list.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98))
	player_list.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	player_list.add_theme_constant_override("outline_size", 4)
	player_list.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	player_list.offset_left = -320
	player_list.offset_right = 320
	player_list.offset_top = 8
	player_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(player_list)
	toast = Label.new()
	toast.name = "CoopToast"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 20)
	toast.add_theme_color_override("font_color", Color("fde68a"))
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	toast.add_theme_constant_override("outline_size", 6)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = -320
	toast.offset_right = 320
	toast.offset_top = 96
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(toast)

func _show_toast(text: String) -> void:
	toast.text = text
	toast_time = 3.0
	toast.modulate.a = 1.0

# --- Quick chat: E on a friend opens friend_chat.gd; the picked line shows over the
# sender's head on every other screen for a few seconds. ---
const QUICK_LINES := ["Namaste!", "Help me at the counter!", "I'll restock the shelves.", "Shabash, good job!"]
const SPEECH_SECONDS := 4.0

## The friend the crosshair is on within 3 m (their id), or 0.
func aimed_friend() -> int:
	var camera: Camera3D = player.camera
	var best := 0
	var alignment := 0.95
	for id in peers:
		var avatar: Node3D = peers[id].avatar
		if avatar.global_position.distance_to(player.global_position) > 3.0: continue
		var dot := (-camera.global_basis.z).dot(camera.global_position.direction_to(avatar.global_position + Vector3(0, 0.2, 0)))
		if dot > alignment:
			alignment = dot
			best = id
	return best

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if player._menu_is_open() or business.carried_stock > 0: return
	var id := aimed_friend()
	if id == 0: return
	world.get_node("Ui").friend_chat.open_for(id, peers[id].name)
	get_viewport().set_input_as_handled()

func send_quick_line(index: int) -> void:
	if index < 0 or index >= QUICK_LINES.size() or not _connected(): return
	_quick_line.rpc(index)
	_show_toast("You: %s" % QUICK_LINES[index])

@rpc("any_peer", "call_remote", "reliable")
func _quick_line(index: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id) or index < 0 or index >= QUICK_LINES.size(): return
	var avatar: Node3D = peers[id].avatar
	var bubble := avatar.get_node_or_null("Speech") as Label3D
	if bubble == null:
		bubble = Label3D.new()
		bubble.name = "Speech"
		bubble.position.y = 1.5
		bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bubble.fixed_size = true
		bubble.pixel_size = 0.0022
		bubble.font_size = 32
		bubble.outline_size = 8
		bubble.modulate = Color(1, 0.9, 0.55)
		bubble.no_depth_test = true
		avatar.add_child(bubble)
	bubble.text = QUICK_LINES[index]
	bubble.show()
	peers[id]["speech"] = SPEECH_SECONDS
	_show_toast("%s: %s" % [peers[id].name, QUICK_LINES[index]])

func _fade_speech(delta: float) -> void:
	for id in peers:
		if peers[id].get("speech", 0.0) <= 0.0: continue
		peers[id].speech -= delta
		if peers[id].speech <= 0.0: peers[id].avatar.get_node("Speech").hide()

# --- Sleeping together ---

## The bed (sleep_area.gd) calls this in co-op instead of skipping the night.
func request_sleep() -> void:
	if local_in_bed: return
	local_in_bed = true
	_show_toast("In bed. The night passes when everyone is in bed.")
	if Coop.hosting: _mark_in_bed(1, true)
	else: _set_in_bed.rpc_id(1, true)

func _leave_bed() -> void:
	local_in_bed = false
	if Coop.hosting: _mark_in_bed(1, false)
	else: _set_in_bed.rpc_id(1, false)

@rpc("any_peer", "call_remote", "reliable")
func _set_in_bed(in_bed: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if Coop.hosting and peers.has(sender): _mark_in_bed(sender, in_bed)

## The host counts who is in bed, tells everyone, and when all are in bed skips to
## morning: friends get the new morning first, then everyone sees the day report.
func _mark_in_bed(id: int, in_bed: bool) -> void:
	if in_bed: sleep_ready[id] = true
	else: sleep_ready.erase(id)
	var players := peers.size() + 1
	_beds.rpc(sleep_ready.size(), players)
	_beds(sleep_ready.size(), players)
	if sleep_ready.size() < players: return
	sleep_ready.clear()
	if not business.sleep_until_morning():
		_show_toast("Unable to advance to morning.")
		return
	var lines := _team_lines()
	team.clear()
	team_day = business.day
	_send_shop()
	_woke.rpc(business.day, lines)
	_woke(business.day, lines)

@rpc("authority", "call_remote", "reliable")
func _beds(in_bed: int, players: int) -> void:
	beds_line = "In bed: %d/%d" % [in_bed, players] if in_bed > 0 else ""
	_refresh_list()

@rpc("authority", "call_remote", "reliable")
func _woke(day: int, lines: Array) -> void:
	local_in_bed = false
	beds_line = ""
	_refresh_list()
	_show_toast("Good morning! Day %d" % day)
	var ui := world.get_node("Ui")
	ui.show_feedback("Day %d. Rested until morning." % day)
	ui.show_day_report(lines)

# --- Team report: who sold and shelved what today (the host's game counts) ---

## customer.gd calls this (group "coop_team") after every sale in the host's game.
func record_sale(amount: int, by_cashier: bool) -> void:
	var entry := _team_entry("staff" if by_cashier and actor == 1 else actor)
	entry.sold += amount
	entry.sales += 1

func _on_shelved(amount: int, by_worker: bool) -> void:
	_team_entry("staff" if by_worker else actor).shelved += amount

func _team_entry(key) -> Dictionary:
	if not team.has(key): team[key] = {"sold": 0, "sales": 0, "shelved": 0}
	return team[key]

## [name, sales money, customers served, items shelved]: host, friends, then staff.
func _team_lines() -> Array:
	var lines := []
	for key in [1] + peers.keys() + ["staff"]:
		if key is int and key != 1 and not peers.has(key): continue
		var entry: Dictionary = team.get(key, {"sold": 0, "sales": 0, "shelved": 0})
		if key is String and entry.sales + entry.shelved == 0: continue
		var label: String = Coop.player_name if key is int and key == 1 else (peers[key].name if key is int else "Staff")
		lines.append([label, entry.sold, entry.sales, entry.shelved])
	return lines

func _refresh_list() -> void:
	var names: Array[String] = ["%s (you%s)" % [Coop.player_name, ", host" if Coop.hosting else ""]]
	for peer in peers.values(): names.append(peer.name)
	var line := "CO-OP  |  %d/%d players: %s" % [names.size(), Coop.MAX_PLAYERS, ", ".join(names)]
	if Coop.hosting:
		var codes := Coop.host_codes()
		line += "\nJoin code: %s" % ("   ".join(codes.map(func(entry): return "%s (%s)" % [entry[1], entry[0]])) if not codes.is_empty() else "no network found")
		if Coop.internet_code.is_empty() and not Coop.internet_note.is_empty(): line += "\n" + Coop.internet_note
		shown_internet = Coop.internet_code + Coop.internet_note
	else:
		line += "\n%s" % ("Shared shop. Progress is saved in %s's game." % host_name if shop_received else "Waiting for the host's shop...")
	if not beds_line.is_empty(): line += "\n" + beds_line
	player_list.text = line
