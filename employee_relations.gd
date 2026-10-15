extends RefCounted

const ROLES := ["cashier", "stock", "warehouse"]
const OVERTIME_RATE := 50
var records := {"cashier": fresh_record(), "stock": fresh_record(), "warehouse": fresh_record()}
var overtime_hours := 0
var retired_hiring := 0
var retired_wage_days := 0

static func fresh_record() -> Dictionary:
	return {"happiness": 70, "request_day": 0, "last_talk_day": 0, "quit_day": 0, "overtime_day": 0, "overtime_end": 0, "unpaid": 0, "state": "none", "message": "", "work_enabled": true}

func name_for(role: String) -> String:
	return {"cashier": "Ramesh", "stock": "Sunil", "warehouse": "Anil"}.get(role, "Employee")

func hired(business, role: String) -> bool:
	return business.worker_hired if role == "cashier" else (business.stock_worker_hired if role == "stock" else business.warehouse_worker_hired)

func active(business, role: String) -> bool:
	return hired(business, role) and records[role].quit_day == 0

func on_shift(business, role: String) -> bool:
	if not active(business, role) or business.wages_due > 0: return false
	var record: Dictionary = records[role]
	return (business.minutes_of_day >= business.get(role + "_shift_start") and business.minutes_of_day < business.get(role + "_shift_end") and not (record.request_day == business.day and record.state == "done")) or (record.overtime_day == business.day and business.minutes_of_day < record.overtime_end)

func pending_role() -> String:
	for role in ROLES:
		if records[role].state in ["leave", "pay"]: return role
	return ""

func _return_box(business, role: String) -> void:
	if role == "stock" and business.worker_carried_stock > 0:
		business.boxed_stock = business.worker_carried_stock
		business.worker_carried_stock = 0
		business.stock_collection_assigned = records.stock.quit_day == 0
	if role == "stock" and records.stock.quit_day > 0: business.stock_collection_assigned = false

func _mood(business, role: String, change: int) -> void:
	var record: Dictionary = records[role]
	record.happiness = clampi(record.happiness + change, 0, 100)
	if record.happiness <= 20 and record.quit_day == 0:
		record.quit_day = business.day
		record.state = "done"
		record.overtime_end = 0
		record.message = "I don't feel respected here. I'm leaving this job."
		business.wages_due += business.DAILY_WORKER_WAGE
		business._settle_bills()
		_return_box(business, role)

func tick(business) -> void:
	var changed := false
	for role in ROLES:
		if not active(business, role): continue
		var record: Dictionary = records[role]
		if record.request_day > 0 and record.request_day < business.day:
			if record.state in ["leave", "pay"] or record.unpaid > 0: _mood(business, role, -10)
			if record.quit_day == 0: record.state = "pay" if record.unpaid > 0 else "none"
			record.request_day = business.day if record.unpaid > 0 else 0
			record.overtime_end = 0
			if record.unpaid > 0 and record.quit_day == 0: record.message = "Could you pay the overtime you owe me?"
			changed = true
		if not active(business, role): continue
		if record.overtime_end > 0 and (record.overtime_day < business.day or business.minutes_of_day >= record.overtime_end):
			record.overtime_end = 0
			record.state = "pay"
			record.request_day = business.day
			record.message = "I've finished the extra hour. Could you pay my overtime?"
			changed = true
		elif record.request_day != business.day and business.minutes_of_day >= business.get(role + "_shift_end"):
			record.request_day = business.day
			record.state = "pay" if record.unpaid > 0 else "leave"
			record.message = "Could you pay the overtime you owe me?" if record.unpaid > 0 else "My shift is finished. May I go home?"
			changed = true
	if changed: business._commit()

func reply(business, role: String, choice: String) -> bool:
	if role not in ROLES or (not active(business, role) and not (choice == "pay" and hired(business, role))): return false
	var record: Dictionary = records[role]
	if choice in ["kind", "rude"]:
		if record.last_talk_day == business.day: return false
		record.last_talk_day = business.day
		_mood(business, role, 5 if choice == "kind" else -15)
		if record.quit_day == 0: record.message = "Thank you. I appreciate that." if choice == "kind" else "Please don't speak to me like that."
	elif choice == "home" and record.state == "leave":
		record.state = "done"
		record.message = "Thank you. See you next shift."
		_mood(business, role, 5)
		_return_box(business, role)
	elif choice in ["overtime", "insist"] and record.state == "leave":
		if record.unpaid > 0 or business.minutes_of_day > 1260: return false
		if record.happiness <= 35:
			record.state = "done"
			record.message = "I'm exhausted. I can't stay today."
		else:
			record.state = "done"
			record.overtime_day = business.day
			record.overtime_end = floori(business.minutes_of_day) + 60
			record.unpaid = OVERTIME_RATE
			overtime_hours += 1
			record.message = "I can stay one hour. Please pay me afterwards."
		_mood(business, role, -15 if choice == "insist" else -2)
	elif choice == "pay" and record.unpaid > 0:
		if record.overtime_end > 0 or business.money < record.unpaid: return false
		business.money -= record.unpaid
		business.overtime_expenses += record.unpaid
		record.unpaid = 0
		record.state = "done"
		record.message = "Thank you for paying my overtime."
		_mood(business, role, 5)
		_return_box(business, role)
	elif choice == "refuse" and record.state == "pay":
		record.state = "done"
		record.message = "I worked that hour. You still owe me my pay."
		_mood(business, role, -30)
		_return_box(business, role)
	else: return false
	business._commit()
	return true

func rehire(business, role: String) -> bool:
	var record: Dictionary = records[role]
	if record.quit_day == 0: return not hired(business, role)
	if record.unpaid > 0: return false
	retired_hiring += business.CASHIER_COSTS[business.cashier_level - 1] if role == "cashier" else business.HIRING_COST
	retired_wage_days += record.quit_day - (business.worker_hired_day if role == "cashier" else business.get(role + "_worker_hired_day")) + 1
	records[role] = fresh_record()
	return true

func snapshot() -> Dictionary:
	return {"records": records.duplicate(true), "overtime_hours": overtime_hours, "retired_hiring": retired_hiring, "retired_wage_days": retired_wage_days}

func restore(data: Dictionary) -> void:
	records = data.records.duplicate(true)
	for role in ROLES:
		if not records.has(role): records[role] = fresh_record()
		# Older saves predate the optional work switch; keep their staff working.
		records[role]["work_enabled"] = records[role].get("work_enabled", true)
		for field in ["happiness", "request_day", "last_talk_day", "quit_day", "overtime_day", "overtime_end", "unpaid"]:
			records[role][field] = int(records[role][field])
	overtime_hours = int(data.overtime_hours)
	retired_hiring = int(data.retired_hiring)
	retired_wage_days = int(data.retired_wage_days)

static func valid(data, day: int) -> bool:
	if not data is Dictionary or not data.get("records") is Dictionary: return false
	for field in ["overtime_hours", "retired_hiring", "retired_wage_days"]:
		if not whole(data.get(field), 1000000000): return false
	if int(data.retired_hiring) % 1000 != 0: return false
	for role in ROLES:
		var record = data.records.get(role, fresh_record() if role == "warehouse" else null)
		if not record is Dictionary: return false
		if not record.get("work_enabled", true) is bool: return false
		for field in ["happiness", "request_day", "last_talk_day", "quit_day", "overtime_day", "overtime_end", "unpaid"]:
			if not whole(record.get(field), 1000000000): return false
		if record.happiness > 100 or record.overtime_end > 1320 or (record.unpaid != 0 and record.unpaid != 50): return false
		for field in ["request_day", "last_talk_day", "quit_day", "overtime_day"]:
			if record[field] > day: return false
		if record.get("state") not in ["none", "leave", "pay", "done"]: return false
		if not record.get("message") is String or record.message.length() > 160: return false
		if record.overtime_end > 0 and (record.overtime_day != day or record.unpaid != 50 or record.state != "done"): return false
		if record.state == "pay" and record.unpaid == 0: return false
	return true

static func whole(value, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= maximum and value == int(value)
