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
	var owned: bool = shop_area.business.house_owned
	house_money_label.text = "Money: %s%s" % [String.chr(8377), shop_area._format_money(shop_area.money)]
	ownership_label.text = "Ownership: Yours" if owned else "Ownership: For sale"
	buy_house_button.disabled = owned or shop_area.money < shop_area.business.HOUSE_COST
	buy_house_button.tooltip_text = "Home already owned" if owned else ("Not enough money. Requires %s15,000." % String.chr(8377) if buy_house_button.disabled else "Buy home")
	house_sign.text = "MY HOME" if owned else "HOME - %s15,000" % String.chr(8377)
	front_door.visible = not owned
	front_door.get_node("CollisionShape3D").set_deferred("disabled", owned)
