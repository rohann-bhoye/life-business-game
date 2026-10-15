extends Panel

var role := ""
var choices: Array[Button] = []
var actions: Array[String] = []
var mood: ProgressBar
@onready var ui = get_parent()
@onready var business = get_tree().current_scene.get_node("Shop/ShopArea").business

func _ready() -> void:
	hide()
	ui._label("SpeakerLabel", self)
	ui._label("MessageLabel", self).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui._label("HappinessLabel", self)
	mood = ProgressBar.new()
	mood.name = "HappinessBar"
	mood.show_percentage = false
	add_child(mood)
	for index in range(3):
		var button := Button.new()
		button.name = "Reply%d" % index
		add_child(button)
		button.pressed.connect(func(): _reply(index))
		choices.append(button)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "Close"
	add_child(close)
	close.pressed.connect(close_menu)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var width := minf(400, get_viewport().get_visible_rect().size.x - 32)
	ui._place(self, 16, 56, width, 328)
	ui._place(get_node("SpeakerLabel"), 16, 12, width - 110, 28)
	ui._place(get_node("CloseButton"), width - 78, 12, 62, 28)
	ui._place(get_node("MessageLabel"), 16, 50, width - 32, 78)
	ui._place(get_node("HappinessLabel"), 16, 134, width - 32, 24)
	ui._place(mood, 16, 166, width - 32, 14)
	for index in range(3): ui._place(choices[index], 16, 194 + index * 40, width - 32, 32)

func open_for(employee_role: String) -> void:
	role = employee_role
	var staff = business.staff
	var record: Dictionary = staff.records[role]
	ui.shop_menu.hide()
	ui.house_menu.hide()
	ui.supplier_menu.hide()
	ui.checkout_menu.hide()
	ui.bargain_menu.hide()
	get_node("SpeakerLabel").text = staff.name_for(role)
	get_node("HappinessLabel").text = "Happiness: %d / 100" % record.happiness
	mood.value = record.happiness
	get_node("MessageLabel").text = record.message if not record.message.is_empty() else "Hello. How is your day going?"
	actions = ["kind", "rude"]
	var texts := ["Thank you for your work.", "You're not doing enough."]
	if record.state == "leave":
		actions = ["home", "overtime", "insist"]
		texts = ["Yes, go home. Thank you.", "Could you stay 1 hour? +%s50" % String.chr(8377), "No, stay another hour."]
	elif record.state == "pay" or record.unpaid > 0 and record.overtime_end == 0:
		actions = ["pay", "refuse"]
		texts = ["Yes, here's your %s50." % String.chr(8377), "I won't pay you today."]
	for index in range(3):
		choices[index].visible = index < actions.size()
		choices[index].disabled = false
		if index < actions.size():
			choices[index].text = texts[index]
			choices[index].disabled = actions[index] == "pay" and business.money < record.unpaid
			if actions[index] in ["kind", "rude"]: choices[index].disabled = record.last_talk_day == business.day or not staff.active(business, role)
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _reply(index: int) -> void:
	if not visible or index >= actions.size(): return
	if actions[index] == "close": close_menu(); return
	if business.staff.reply(business, role, actions[index]):
		get_node("MessageLabel").text = business.staff.records[role].message
		mood.value = business.staff.records[role].happiness
		get_node("HappinessLabel").text = "Happiness: %d / 100" % mood.value
		actions = ["close"]
		for button in choices: button.hide()
		choices[0].text = "Okay"
		choices[0].show()

func close_menu() -> void:
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

