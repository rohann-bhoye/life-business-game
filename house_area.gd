extends Area3D

var player_inside := false

@onready var shop_area: Area3D = get_tree().current_scene.get_node("Shop/ShopArea")
@onready var house_menu: Control = get_tree().current_scene.get_node("Ui/HouseMenu")
@onready var house_money_label: Label = house_menu.get_node("HouseMoneyLabel")
@onready var ownership_label: Label = house_menu.get_node("OwnershipLabel")
@onready var buy_house_button: Button = house_menu.get_node("BuyHouseButton")
@onready var close_house_button: Button = house_menu.get_node("CloseHouseButton")
@onready var front_door: StaticBody3D = get_node("../FrontDoor")
@onready var house_sign: Label3D = get_node("../HouseSign")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	buy_house_button.pressed.connect(_on_buy_house_pressed)
	close_house_button.pressed.connect(_on_close_house_pressed)
	shop_area.business.changed.connect(_update_house_state)
	_update_house_state()
	var decor := Node3D.new()
	decor.set_script(HomeDecor)
	get_parent().add_child.call_deferred(decor)
	call_deferred("_start_at_home")

const HomeDecor := preload("res://home_decor.gd")

# The family home is owned from day one, and every New Game / Continue starts
# with the player inside it, beside the bed.
func _start_at_home() -> void:
	# Only real sessions started from the main menu (New Game / Continue).
	if not get_tree().current_scene.has_meta("session_save_path"): return
	# Story games rent the home until it is bought; every other game owns it from the start.
	if not shop_area.business.home_rented: shop_area.business.grant_home()
	spawn_player()

func spawn_player() -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as CharacterBody3D
	if player == null: return
	var house := get_parent() as Node3D
	player.global_position = house.to_global(HomeDecor.SPAWN)
	player.rotation.y = house.global_rotation.y + PI
	player.velocity = Vector3.ZERO
	player.indoors = true

func _unhandled_input(event: InputEvent) -> void:
	if player_inside and event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_E:
			shop_area.sale_price_input.apply()
			shop_area.shop_menu.hide()
			house_menu.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		player_inside = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_inside = false

func _on_buy_house_pressed() -> void:
	if shop_area.business.buy_house():
		_on_close_house_pressed()
		shop_area._feedback("Home purchased. -%s15,000" % String.chr(8377))
	else:
		shop_area._feedback("You already own this home." if shop_area.business.house_owned else "Not enough money to buy this home.", true)

func _on_close_house_pressed() -> void:
	house_menu.hide()
	if not shop_area.shop_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _update_house_state() -> void:
	var business = shop_area.business
	var owned: bool = business.house_owned
	var rented: bool = business.home_rented
	house_money_label.text = "Money: %s%s" % [String.chr(8377), shop_area._format_money(shop_area.money)]
	ownership_label.text = "Ownership: Yours" if owned else ("Renting: %s%d a day - buy it for %s%s" % [String.chr(8377), business.RENT_PER_DAY, String.chr(8377), shop_area._format_money(business.HOUSE_COST)] if rented else "Ownership: For sale")
	buy_house_button.disabled = owned or shop_area.money < business.HOUSE_COST
	buy_house_button.tooltip_text = "Home already owned" if owned else ("Not enough money. Requires %s15,000." % String.chr(8377) if buy_house_button.disabled else "Buy home (rent stops)")
	house_sign.text = "MY HOME" if owned else ("RENTED - BUY %s15,000" % String.chr(8377) if rented else "HOME - %s15,000" % String.chr(8377))
	# A rented home is lived in from day one, so only a home neither owned nor rented is locked.
	var open_door: bool = owned or rented
	front_door.visible = not open_door
	front_door.get_node("CollisionShape3D").set_deferred("disabled", open_door)
