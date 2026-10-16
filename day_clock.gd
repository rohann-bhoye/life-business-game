extends Node

const GAME_MINUTES_PER_SECOND := 2.0

@onready var business = get_tree().current_scene.get_node("Shop/ShopArea").business
@onready var clock_label: Label = get_tree().current_scene.get_node("Ui/ClockLabel")

func _ready() -> void:
	business.clock_changed.connect(_update_clock)
	_update_clock()

func _process(delta: float) -> void:
	var dialog := get_tree().current_scene.get_node_or_null("Ui/StaffDialog")
	if is_instance_valid(dialog) and dialog.visible: return
	business.advance_clock(delta * GAME_MINUTES_PER_SECOND)

func _update_clock() -> void:
	var minute := floori(business.minutes_of_day)
	clock_label.text = "Day %d | %02d:%02d | %s" % [business.day, minute / 60, minute % 60, "Rain" if business.is_raining() else "Sunny"]
