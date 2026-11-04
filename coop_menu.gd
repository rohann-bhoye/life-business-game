extends Panel

# Lobby panel for co-op (coop.gd): your name and character, "Host this shop" for
# the selected save slot with your join code to copy and share, or a friend's code
# (or IP) and "Join". Friends need the same Wi-Fi
# or LAN, a free virtual LAN (Radmin VPN, ZeroTier) or an open port 7777. The
# choices are remembered in lobby.cfg. main_menu.gd launches the game.
signal closed
const Coop := preload("res://coop.gd")
const Bazaar := preload("res://ui_bazaar.gd")
const JOIN_TIMEOUT := 10.0
var lobby: Control
var name_edit: LineEdit
var character: OptionButton
var host_button: Button
var address_edit: LineEdit
var code_label: Label
var copy_button: Button
var join_button: Button
var status: Label
var form: VBoxContainer
var connecting := 0.0

func _ready() -> void:
	hide()
	# The pause menu's look (ui_bazaar.gd), like every other menu.
	theme = Bazaar.make_theme()
	add_theme_stylebox_override("panel", Bazaar.card())
	form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	add_child(form)
	var title := _label("CO-OP", 26)
	title.add_theme_font_override("font", preload("res://kenney_theme.gd").heading_font())
	_label("Run one shop together with up to 3 friends.", 15).add_theme_color_override("font_color", Bazaar.MUTED)
	name_edit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.placeholder_text = "Your name"
	name_edit.max_length = 16
	_row("Your name", name_edit)
	character = OptionButton.new()
	character.name = "CharacterOption"
	for entry in Coop.CHARACTERS: character.add_item(entry[0])
	_row("Character", character)
	host_button = Button.new()
	host_button.name = "HostButton"
	host_button.custom_minimum_size.y = 42
	host_button.theme_type_variation = "PrimaryButton"
	host_button.pressed.connect(_host)
	form.add_child(host_button)
	var code_row := HBoxContainer.new()
	form.add_child(code_row)
	code_label = Label.new()
	code_label.name = "CodeLabel"
	code_label.add_theme_font_size_override("font_size", 16)
	code_label.add_theme_color_override("font_color", Bazaar.SAFFRON_DEEP)
	code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code_row.add_child(code_label)
	copy_button = Button.new()
	copy_button.name = "CopyCodeButton"
	copy_button.text = "Copy"
	copy_button.custom_minimum_size = Vector2(80, 34)
	copy_button.pressed.connect(_copy_code)
	code_row.add_child(copy_button)
	_label("Share your code. Friends in other homes use a free virtual LAN like Radmin VPN or ZeroTier; on the same Wi-Fi it just works.", 13).add_theme_color_override("font_color", Bazaar.MUTED)
	var line := ColorRect.new()
	line.color = Bazaar.LINE
	line.custom_minimum_size.y = 1
	form.add_child(line)
	address_edit = LineEdit.new()
	address_edit.name = "AddressEdit"
	address_edit.placeholder_text = "e.g. K7Q2-M9XA-3PZ"
	_row("Friend's code", address_edit)
	join_button = Button.new()
	join_button.name = "JoinButton"
	join_button.text = "Join friend's shop"
	join_button.custom_minimum_size.y = 42
	join_button.theme_type_variation = "InfoButton"
	join_button.pressed.connect(_join)
	form.add_child(join_button)
	status = _label("", 14)
	status.name = "Status"
	status.add_theme_color_override("font_color", Bazaar.SAFFRON_DEEP)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size.y = 40
	back.pressed.connect(close_menu)
	form.add_child(back)
	# Long button words clip rather than push the panel wider.
	for button in [host_button, join_button]: button.clip_text = true
	get_viewport().size_changed.connect(_layout)
	# Wrapped text settles its height later; fit the panel whenever it does.
	form.minimum_size_changed.connect(_layout)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(label)
	return label

func _row(title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	form.add_child(row)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	control.custom_minimum_size = Vector2(190, 34)
	control.add_theme_font_size_override("font_size", 15)
	row.add_child(control)

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(560, viewport_size.x - 32)
	form.position = Vector2(22, 20)
	form.size = Vector2(width - 44, 0)
	size = Vector2(width, minf(viewport_size.y - 32, form.get_combined_minimum_size().y + 40))
	position = (viewport_size - size) / 2

func open_menu() -> void:
	var config := ConfigFile.new()
	config.load(lobby._lobby_config_path())
	name_edit.text = str(config.get_value("coop", "name", ""))
	var model := Coop.clean_model(str(config.get_value("coop", "character", Coop.CHARACTERS[0][1])))
	for index in range(Coop.CHARACTERS.size()):
		if Coop.CHARACTERS[index][1] == model: character.select(index)
	address_edit.text = str(config.get_value("coop", "address", ""))
	host_button.text = "Host this shop (Slot %d)" % lobby.slot
	var codes := Coop.host_codes()
	code_label.text = "Your code: %s (%s)" % [codes[0][1], codes[0][0]] if not codes.is_empty() else "Your code: no network found"
	copy_button.disabled = codes.is_empty()
	status.text = ""
	_set_busy(false)
	show()
	_layout()
	# Wrapped labels settle their height a frame later.
	_layout.call_deferred()

func _remember() -> void:
	var config := ConfigFile.new()
	config.load(lobby._lobby_config_path())
	config.set_value("coop", "name", name_edit.text.strip_edges())
	config.set_value("coop", "character", Coop.CHARACTERS[character.selected][1])
	config.set_value("coop", "address", address_edit.text.strip_edges())
	config.save(lobby._lobby_config_path())

func _copy_code() -> void:
	var codes := Coop.host_codes()
	if codes.is_empty(): return
	DisplayServer.clipboard_set(codes[0][1])
	status.text = "Code copied. Send it to your friends!"

func _host() -> void:
	_remember()
	var error := Coop.host(get_tree(), name_edit.text, Coop.CHARACTERS[character.selected][1])
	if error != OK:
		status.text = "Could not host on port %d. Is another game already hosting?" % Coop.port
		return
	hide()
	lobby.start_coop_host()

func _join() -> void:
	var target := Coop.read_join(address_edit.text)
	if target.is_empty():
		status.text = "That code doesn't look right. Check it with your friend (e.g. K7Q2-M9XA-3PZ)."
		return
	_remember()
	if Coop.join(get_tree(), target.address, name_edit.text, Coop.CHARACTERS[character.selected][1], target.port) != OK:
		status.text = "Could not start connecting."
		return
	status.text = "Connecting to your friend's shop..."
	_set_busy(true)
	connecting = JOIN_TIMEOUT
	multiplayer.connected_to_server.connect(_on_connected, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_failed, CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	if connecting <= 0.0: return
	connecting -= delta
	if connecting <= 0.0: _on_failed()

func _on_connected() -> void:
	connecting = 0.0
	_disconnect_signals()
	status.text = "Connected! Loading the shop..."
	lobby.start_coop_client(address_edit.text.strip_edges().to_upper())

func _on_failed() -> void:
	connecting = 0.0
	_disconnect_signals()
	Coop.leave(get_tree())
	_set_busy(false)
	status.text = "Could not connect. Check the code, that you are on the same Wi-Fi or VPN, and that the host allowed the game through the Windows firewall."

func _disconnect_signals() -> void:
	if multiplayer.connected_to_server.is_connected(_on_connected): multiplayer.connected_to_server.disconnect(_on_connected)
	if multiplayer.connection_failed.is_connected(_on_failed): multiplayer.connection_failed.disconnect(_on_failed)

func _set_busy(busy: bool) -> void:
	host_button.disabled = busy
	join_button.disabled = busy

func close_menu() -> void:
	if connecting > 0.0: _on_failed()
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
