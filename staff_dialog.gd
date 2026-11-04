extends "res://conversation_box.gd"

# Talking to an employee (E on them, the tablet's Talk button or a "wants to talk"
# notification): thanks or a telling-off once a day, end-of-shift and overtime
# pay questions, and a way to open their staff page.

const ROLE_COLOURS := {"cashier": Color(0.18, 0.5, 0.42), "stock": Color(0.75, 0.45, 0.18), "warehouse": Color(0.3, 0.38, 0.62)}
const ROLE_TITLES := {"cashier": "Cashier", "stock": "Stock helper", "warehouse": "Warehouse helper"}
var role := ""
var actions: Array[String] = []

func open_for(employee_role: String) -> void:
	role = employee_role
	var staff = business.staff
	var record: Dictionary = staff.records[role]
	actions.assign(["kind", "rude", "manage", "close"])
	var texts := ["Thank you for your work.", "You're not doing enough.", "Open staff page", "Bye"]
	if record.state == "leave":
		actions.assign(["home", "overtime", "insist"])
		texts = ["Yes, go home. Thank you.", "Could you stay 1 hour? +%s50" % String.chr(8377), "No, stay another hour."]
	elif record.state == "pay" or record.unpaid > 0 and record.overtime_end == 0:
		actions.assign(["pay", "refuse"])
		texts = ["Yes, here's your %s50." % String.chr(8377), "I won't pay you today."]
	var disabled: Array = []
	for action in actions:
		var off: bool = action == "pay" and business.money < record.unpaid
		if action in ["kind", "rude"]: off = record.last_talk_day == business.day or not staff.active(business, role)
		disabled.append(off)
	var line: String = record.message if not record.message.is_empty() else "Namaste! How is your day going?"
	# The view turns to them when they stand near (not from the PC across the shop).
	var worker_node: String = {"cashier": "Worker", "stock": "StockWorker"}.get(role, "")
	look_at_person(get_tree().current_scene.get_node_or_null(worker_node) if worker_node != "" else null)
	present(staff.name_for(role), "%s  |  Happiness %d / 100" % [ROLE_TITLES.get(role, "Staff"), record.happiness], ROLE_COLOURS.get(role, Color(0.3, 0.4, 0.45)), line, texts, disabled)
	mood.value = record.happiness
	mood.show()

func _reply(index: int) -> void:
	if not visible or index >= actions.size(): return
	match actions[index]:
		"close":
			close_menu()
			return
		"manage":
			close_menu()
			ui.open_employee(role)
			return
	if business.staff.reply(business, role, actions[index]):
		var record: Dictionary = business.staff.records[role]
		mood.value = record.happiness
		get_node("HappinessLabel").text = "%s  |  Happiness %d / 100" % [ROLE_TITLES.get(role, "Staff"), record.happiness]
		actions.assign(["close"])
		say(record.message, ["Okay"])
