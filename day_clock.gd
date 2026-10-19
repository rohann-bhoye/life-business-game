extends Node

# Runs the in-game clock. Its speed comes from Settings > Gameplay > Day length
# (game_settings.gd DAY_SPEEDS): Relaxed by default, a 12-minute shop day.
const Settings := preload("res://game_settings.gd")
var minutes_per_second: float = Settings.DAY_SPEEDS[2]

@onready var business = get_tree().current_scene.get_node("Shop/ShopArea").business
@onready var clock_label: Label = get_tree().current_scene.get_node("Ui/ClockLabel")

func _ready() -> void:
	var settings = Settings.new()
	settings.load_file(get_tree().current_scene.get_meta("session_settings_path", "user://settings.cfg"))
	minutes_per_second = Settings.DAY_SPEEDS[settings.day_length]
	business.clock_changed.connect(_update_clock)
	_update_clock()

func _process(delta: float) -> void:
	var dialog := get_tree().current_scene.get_node_or_null("Ui/StaffDialog")
	if is_instance_valid(dialog) and dialog.visible: return
	business.advance_clock(delta * minutes_per_second)

func _update_clock() -> void:
	var minute := floori(business.minutes_of_day)
	clock_label.text = "Day %d | %02d:%02d | %s" % [business.day, minute / 60, minute % 60, "Rain" if business.is_raining() else "Sunny"]
