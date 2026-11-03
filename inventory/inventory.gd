class_name Inventory
extends Resource
## Pure data: slots, stacking, moving, splitting, sorting.
## It's a Resource, so you can save it: ResourceSaver.save(inv, "user://inventory.tres")

signal slot_changed(index: int)

@export var size: int = 30
@export var items: Array[ItemData] = []
@export var counts: Array[int] = []


func _init() -> void:
	_ensure_size()


func _ensure_size() -> void:
	if items.size() != size:
		items.resize(size)
	if counts.size() != size:
		counts.resize(size)


func _valid(i: int) -> bool:
	return i >= 0 and i < size


static func _same(a: ItemData, b: ItemData) -> bool:
	if a == null or b == null:
		return false
	return a == b or (a.id != &"" and a.id == b.id)


func get_item(i: int) -> ItemData:
	_ensure_size()
	return items[i] if _valid(i) else null


func get_count(i: int) -> int:
	_ensure_size()
	return counts[i] if _valid(i) and items[i] != null else 0


func set_slot(i: int, item: ItemData, amount: int) -> void:
	_ensure_size()
	if not _valid(i):
		return
	if item == null or amount <= 0:
		item = null
		amount = 0
	items[i] = item
	counts[i] = amount
	slot_changed.emit(i)


## Adds items, filling existing stacks first. Returns how many did NOT fit.
func add_item(item: ItemData, amount: int = 1) -> int:
	_ensure_size()
	if item == null or amount <= 0:
		return amount
	var left := amount
	if item.max_stack > 1:
		for i in size:
			if left <= 0:
				break
			if _same(items[i], item) and counts[i] < item.max_stack:
				var add := mini(left, item.max_stack - counts[i])
				counts[i] += add
				left -= add
				slot_changed.emit(i)
	for i in size:
		if left <= 0:
			break
		if items[i] == null:
			var add := mini(left, item.max_stack)
			items[i] = item
			counts[i] = add
			left -= add
			slot_changed.emit(i)
	return left


## Removes up to `amount` from one slot. Returns how many were removed.
func remove_at(i: int, amount: int = 1) -> int:
	_ensure_size()
	if not _valid(i) or items[i] == null:
		return 0
	var removed := mini(amount, counts[i])
	counts[i] -= removed
	if counts[i] <= 0:
		items[i] = null
		counts[i] = 0
	slot_changed.emit(i)
	return removed


## Removes `amount` of an item from anywhere (last slots first). Returns removed count.
func remove_item(item: ItemData, amount: int = 1) -> int:
	_ensure_size()
	var left := amount
	for i in range(size - 1, -1, -1):
		if left <= 0:
			break
		if _same(items[i], item):
			left -= remove_at(i, left)
	return amount - left


func count_of(item: ItemData) -> int:
	_ensure_size()
	var total := 0
	for i in size:
		if _same(items[i], item):
			total += counts[i]
	return total


func has_item(item: ItemData, amount: int = 1) -> bool:
	return count_of(item) >= amount


func first_empty() -> int:
	_ensure_size()
	for i in size:
		if items[i] == null:
			return i
	return -1


func used_slots() -> int:
	_ensure_size()
	var n := 0
	for it in items:
		if it != null:
			n += 1
	return n


func total_weight() -> float:
	_ensure_size()
	var w := 0.0
	for i in size:
		if items[i] != null:
			w += items[i].weight * counts[i]
	return w


## Drag & drop: merges same items, otherwise swaps.
func move(from: int, to: int) -> void:
	_ensure_size()
	if from == to or not _valid(from) or not _valid(to) or items[from] == null:
		return
	var a := items[from]
	var b := items[to]
	if _same(a, b) and a.max_stack > 1:
		var moved := mini(b.max_stack - counts[to], counts[from])
		if moved > 0:
			counts[to] += moved
			counts[from] -= moved
			if counts[from] <= 0:
				items[from] = null
				counts[from] = 0
			slot_changed.emit(from)
			slot_changed.emit(to)
			return
	items[from] = b
	items[to] = a
	var c := counts[from]
	counts[from] = counts[to]
	counts[to] = c
	slot_changed.emit(from)
	slot_changed.emit(to)


## Shift + drag: moves half the stack.
func split_stack(from: int, to: int) -> void:
	_ensure_size()
	if from == to or not _valid(from) or not _valid(to) or items[from] == null:
		return
	var half := counts[from] >> 1
	if half < 1:
		move(from, to)
		return
	if items[to] == null:
		items[to] = items[from]
		counts[to] = half
		counts[from] -= half
	elif _same(items[to], items[from]):
		var moved := mini(half, items[to].max_stack - counts[to])
		counts[to] += moved
		counts[from] -= moved
	else:
		move(from, to)
		return
	slot_changed.emit(from)
	slot_changed.emit(to)


## Sorts by rarity (best first), then category, then name. Merges stacks too.
func sort_items() -> void:
	_ensure_size()
	var entries: Array = []
	for i in size:
		if items[i] != null:
			entries.append([items[i], counts[i]])
	entries.sort_custom(_compare_entries)
	for i in size:
		items[i] = null
		counts[i] = 0
	for e in entries:
		add_item(e[0], e[1])
	for i in size:
		slot_changed.emit(i)


static func _compare_entries(a: Array, b: Array) -> bool:
	var ia: ItemData = a[0]
	var ib: ItemData = b[0]
	if ia.rarity != ib.rarity:
		return ia.rarity > ib.rarity
	if ia.category != ib.category:
		return ia.category < ib.category
	return ia.display_name < ib.display_name
