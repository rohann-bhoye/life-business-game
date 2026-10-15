extends Area3D

var next_sleep_msec := 0

@onready var player = get_tree().current_scene.get_node("Player")
@onready var business = get_tree().current_scene.get_node("Shop/ShopArea").business
@onready var sleep_sign: Label3D = $SleepSign

func _process(_delta: float) -> void:
	sleep_sign.text = "Sleep until morning" if business.sleep_time_allowed() else "Sleep after 20:00"
	sleep_sign.visible = business.house_owned and player.indoors and overlaps_body(player) and not player._menu_is_open()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if try_sleep():
			get_viewport().set_input_as_handled()

func try_sleep() -> bool:
	if not player.indoors or not overlaps_body(player) or player._menu_is_open():
		return false
	if Time.get_ticks_msec() < next_sleep_msec:
		return false
	if not business.house_owned:
		return false
	if not business.sleep_time_allowed():
		next_sleep_msec = Time.get_ticks_msec() + 1000
		get_tree().current_scene.get_node("Ui").show_feedback("It's too early to sleep. You can sleep after 20:00.", true)
		return true
	if not business.sleep_until_morning():
		get_tree().current_scene.get_node("Ui").show_feedback("Unable to advance to morning.", true)
		return false
	next_sleep_msec = Time.get_ticks_msec() + 1000
	get_tree().current_scene.get_node("Ui").show_feedback("Day %d. Rested until morning." % business.day)
	return true
