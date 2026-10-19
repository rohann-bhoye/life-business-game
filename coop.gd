extends RefCounted

# Co-op session: friends running one shop together, up to 4 players. This is the
# connection layer: hosting or joining over ENet (the same Wi-Fi/LAN, a free virtual
# LAN such as Radmin VPN or ZeroTier, or an open port), plus this player's name and
# character. State lives in static vars, so it lasts across scene changes; the
# in-game part is coop_world.gd and the lobby panel is coop_menu.gd.
const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4
## [label, character model] the player can pick.
const CHARACTERS := [["Shopkeeper", "shopkeeper"], ["Uncle", "uncle"], ["Aunty", "aunty"], ["Sardar ji", "sikh"], ["Student", "student"], ["Farmer", "farmer"]]
static var active := false
static var hosting := false
static var port := DEFAULT_PORT
static var player_name := "Player"
static var model := "shopkeeper"
## The lobby's save slot, so leaving a co-op game returns to the right slot.
static var menu_save_path := ""
## Shown once by the main menu (e.g. why a co-op game ended).
static var last_message := ""

static func host(tree: SceneTree, name: String, character: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK: return error
	_start(tree, peer, true, name, character)
	if DisplayServer.get_name() != "headless": open_internet_port()
	return OK

## Starts connecting; the result arrives as multiplayer.connected_to_server or
## connection_failed.
static func join(tree: SceneTree, address: String, name: String, character: String, join_port := -1) -> Error:
	if join_port > 0: port = join_port
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK: return error
	_start(tree, peer, false, name, character)
	return OK

static func _start(tree: SceneTree, peer: MultiplayerPeer, as_host: bool, name: String, character: String) -> void:
	tree.get_multiplayer().multiplayer_peer = peer
	active = true
	hosting = as_host
	player_name = clean_name(name)
	model = clean_model(character)

## A friend's game in a co-op session (the host's game runs the real shop).
static func is_friend() -> bool:
	return active and not hosting

static func leave(tree: SceneTree) -> void:
	if hosting: close_internet_port()
	var multiplayer := tree.get_multiplayer()
	if multiplayer.multiplayer_peer != null: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	hosting = false

static func clean_name(name: String) -> String:
	var cleaned := name.strip_edges().left(16)
	return cleaned if not cleaned.is_empty() else "Player"

static func clean_model(character: String) -> String:
	for entry in CHARACTERS:
		if entry[1] == character: return character
	return CHARACTERS[0][1]

# --- Join codes: the host's address and port in 11 easy letters, e.g. K7Q2-M9XA-3PZ ---
# Without a server the code carries the host's IPv4 address (Radmin VPN, ZeroTier
# or Wi-Fi) and port, so every host gets its own code; with a relay server later it
# can become a room code and the Join box stays the same. Crockford base 32: no I,
# L, O or U, and the last letter is a check so a typo is caught.
const CODE_LETTERS := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

static func make_code(address: String, code_port := DEFAULT_PORT) -> String:
	var parts := address.split(".")
	if parts.size() != 4: return ""
	var value := 0
	for part in parts: value = (value << 8) | (int(part) & 255)
	value = (value << 16) | (code_port & 65535)
	var letters := ""
	for index in range(10):
		letters = CODE_LETTERS[value & 31] + letters
		value >>= 5
	letters += CODE_LETTERS[_check(letters)]
	return "%s-%s-%s" % [letters.substr(0, 4), letters.substr(4, 4), letters.substr(8, 3)]

## {"address", "port"} for a valid code, else {}. Forgives dashes, spaces, lower
## case and the look-alikes O (0) and I or L (1).
static func read_code(code: String) -> Dictionary:
	var letters := code.to_upper().replace("-", "").replace(" ", "").replace("O", "0").replace("I", "1").replace("L", "1")
	if letters.length() != 11: return {}
	for letter in letters:
		if CODE_LETTERS.find(letter) == -1: return {}
	if CODE_LETTERS[_check(letters.left(10))] != letters[10]: return {}
	var value := 0
	for index in range(10): value = (value << 5) | CODE_LETTERS.find(letters[index])
	var code_port := value & 65535
	value >>= 16
	var octets: Array[String] = []
	for shift in [24, 16, 8, 0]: octets.append(str((value >> shift) & 255))
	return {"address": ".".join(octets), "port": code_port}

static func _check(letters: String) -> int:
	var total := 0
	for index in range(letters.length()): total += CODE_LETTERS.find(letters[index]) * (index + 3)
	return total % 32

## The host's codes to share: [label, code] for each usable network (the internet
## code first, once the router has opened the port).
static func host_codes() -> Array:
	var codes := []
	if not internet_code.is_empty(): codes.append(["Internet", internet_code])
	for address in local_addresses().slice(0, 3):
		var label := "Radmin VPN" if address.begins_with("26.") else ("Same Wi-Fi" if address.begins_with("192.168.") else "Other network")
		codes.append([label, make_code(address, port)])
	return codes

## A code or an IP typed into the Join box: {"address", "port"} or {}.
static func read_join(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	if trimmed.is_valid_ip_address(): return {"address": trimmed, "port": port}
	return read_code(trimmed)

# --- Internet without a VPN: ask the home router to open the port (UPnP) ---
# In the background when hosting (never in headless test runs). If the router
# opens the port and has a real public address, friends anywhere join with
# internet_code. Many Indian connections share one address between homes (CGNAT)
# or have UPnP off; then internet_note says so and Radmin VPN is the way.
static var internet_code := ""
static var internet_note := ""
static var _upnp: UPNP

static func open_internet_port() -> void:
	internet_code = ""
	internet_note = "Checking if friends can join over the internet..."
	WorkerThreadPool.add_task(_open_port.bind(port))

static func _open_port(game_port: int) -> void:
	var upnp := UPNP.new()
	var code := ""
	var note := "Your router does not open ports automatically. Friends in other homes can use Radmin VPN."
	if upnp.discover(2000, 2) == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway():
		if upnp.add_port_mapping(game_port, game_port, "Life Business Game", "UDP") == UPNP.UPNP_RESULT_SUCCESS:
			var external := upnp.query_external_address()
			if is_public_ipv4(external):
				code = make_code(external, game_port)
				note = ""
			else:
				upnp.delete_port_mapping(game_port, "UDP")
				note = "Your internet provider shares one address between homes, so friends in other homes need Radmin VPN."
	_port_result.call_deferred(upnp if not code.is_empty() else null, code, note)

static func _port_result(upnp: UPNP, code: String, note: String) -> void:
	if not active or not hosting:
		if upnp != null: WorkerThreadPool.add_task(func(): upnp.delete_port_mapping(port, "UDP"))
		return
	_upnp = upnp
	internet_code = code
	internet_note = note

static func close_internet_port() -> void:
	var mapped := _upnp
	if mapped != null: WorkerThreadPool.add_task(func(): mapped.delete_port_mapping(port, "UDP"))
	_upnp = null
	internet_code = ""
	internet_note = ""

## A public address reachable from other homes: not private, loopback, link-local,
## multicast or shared carrier NAT (100.64.0.0/10).
static func is_public_ipv4(address: String) -> bool:
	if not address.is_valid_ip_address() or address.count(".") != 3: return false
	var parts := address.split(".")
	var first := int(parts[0])
	var second := int(parts[1])
	if first in [0, 10, 127] or first >= 224: return false
	if first == 100 and second >= 64 and second <= 127: return false
	if first == 169 and second == 254: return false
	if first == 172 and second >= 16 and second <= 31: return false
	return not (first == 192 and second == 168)

## IPv4 addresses friends can join, for the host to share: Radmin VPN (26.x, for
## friends in other homes) first, then home Wi-Fi/LAN (192.168.x), then other
## networks (ZeroTier and virtual adapters use 10.x and 172.x).
static func local_addresses() -> PackedStringArray:
	var found: Array[String] = []
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."): found.append(address)
	var rank := func(address: String) -> int:
		for index in range(3):
			if address.begins_with(["26.", "192.168.", "10."][index]): return index
		return 3
	found.sort_custom(func(a, b): return rank.call(a) < rank.call(b))
	return PackedStringArray(found)
