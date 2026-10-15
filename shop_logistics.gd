extends RefCounted

const Catalog = preload("res://product_catalog.gd")
const STORAGE_RACKS := 16
const SLOTS_PER_RACK := 16
const STORAGE_CAPACITY := STORAGE_RACKS * SLOTS_PER_RACK
var rack_incoming: Array = []
var rack_delivered: Array = []
var storage: Array = []
var warehouse_carry: Dictionary = {}
var ground_boxes: Array = []

func snapshot() -> Dictionary:
	return {"rack_incoming": rack_incoming.duplicate(), "rack_delivered": rack_delivered.duplicate(), "storage": storage.duplicate(true), "warehouse_carry": warehouse_carry.duplicate(true), "ground_boxes": ground_boxes.duplicate(true)}

func restore(data: Dictionary) -> void:
	rack_incoming = data.get("rack_incoming", []).duplicate()
	rack_delivered = data.get("rack_delivered", []).duplicate()
	storage = data.get("storage", []).duplicate(true)
	warehouse_carry = data.get("warehouse_carry", {}).duplicate(true)
	ground_boxes = data.get("ground_boxes", []).duplicate(true)
	for box in ground_boxes: box.amount = int(box.amount)
	if not warehouse_carry.is_empty():
		warehouse_carry.slot = int(warehouse_carry.slot)
		warehouse_carry.amount = int(warehouse_carry.amount)
	for box in storage:
		box.slot = int(box.slot)
		box.amount = int(box.amount)

func rack_count() -> int:
	return rack_incoming.size() + rack_delivered.size()

func free_slot(rack: int) -> int:
	if rack < 0 or rack >= STORAGE_RACKS: return -1
	for slot in range(rack * SLOTS_PER_RACK, (rack + 1) * SLOTS_PER_RACK):
		if at_slot(slot).is_empty() and warehouse_carry.get("slot", -1) != slot: return slot
	return -1

func at_slot(slot: int) -> Dictionary:
	for box in storage:
		if box.slot == slot: return box
	return {}

func stored_units(product: String) -> int:
	var amount := 0
	for box in storage:
		if box.product == product: amount += int(box.amount)
	return amount

static func valid(data, maximum_racks: int) -> bool:
	if not data is Dictionary: return false
	var ground = data.get("ground_boxes", [])
	if not ground is Array or ground.size() > 20: return false
	for box in ground:
		if not box is Dictionary or box.get("product") not in Catalog.IDS: return false
		var amount = box.get("amount")
		if not (amount is int or amount is float) or not is_finite(float(amount)) or amount != int(amount) or amount < 1 or amount > 10: return false
		var position = box.get("position")
		if not position is Array or position.size() != 3: return false
		for value in position:
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > 64: return false
		if position[1] < 0 or position[1] > 10: return false
	var total := 0
	for field in ["rack_incoming", "rack_delivered"]:
		var entries = data.get(field, [])
		if not entries is Array: return false
		total += entries.size()
		for product in entries:
			if product not in Catalog.IDS: return false
	if total > maximum_racks: return false
	var boxes = data.get("storage", [])
	if not boxes is Array or boxes.size() > STORAGE_CAPACITY: return false
	var slots := {}
	var carry = data.get("warehouse_carry", {})
	if not carry is Dictionary: return false
	var all: Array = boxes.duplicate()
	if not carry.is_empty(): all.append(carry)
	for box in all:
		if not box is Dictionary or box.get("product") not in Catalog.IDS: return false
		for field in ["slot", "amount"]:
			var value = box.get(field)
			if not value is int and not value is float: return false
			if not is_finite(float(value)) or value != int(value): return false
		if box.slot < 0 or box.slot >= STORAGE_CAPACITY or box.amount < 1 or box.amount > 10 or slots.has(int(box.slot)): return false
		slots[int(box.slot)] = true
	return true
