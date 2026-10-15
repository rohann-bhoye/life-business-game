extends RefCounted

const PLOTS := [4, 12, 24]
const GROW_MINUTES := [360, 300, 240]
const UPGRADE_COSTS := [2000, 5000]
const SEED_COST := 100
var level := 1
var seeds := 0
var bought := 0
var planted := 0
var harvested := 0
var plots: Array = []

func _init() -> void:
	for index in range(24): plots.append(empty_plot())

static func empty_plot() -> Dictionary:
	return {"planted": false, "watered_at": -1, "grow_minutes": 360}

func snapshot() -> Dictionary:
	return {"level": level, "seeds": seeds, "bought": bought, "planted": planted, "harvested": harvested, "plots": plots.duplicate(true)}

func restore(data: Dictionary) -> void:
	for field in ["level", "seeds", "bought", "planted", "harvested"]: set(field, int(data[field]))
	plots = data.plots.duplicate(true)
	for plot in plots:
		plot.watered_at = int(plot.watered_at)
		plot.grow_minutes = int(plot.grow_minutes)

func expenses() -> int:
	var total := bought * SEED_COST
	for index in range(level - 1): total += UPGRADE_COSTS[index]
	return total

func ready(index: int, now: int) -> bool:
	if index < 0 or index >= PLOTS[level - 1]: return false
	var plot: Dictionary = plots[index]
	return plot.planted and plot.watered_at >= 0 and now >= plot.watered_at + plot.grow_minutes

static func whole(value, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and value >= minimum and value <= maximum

static func valid(data, now: int) -> bool:
	if not data is Dictionary: return false
	if not whole(data.get("level"), 1, 3): return false
	for field in ["seeds", "bought", "planted", "harvested"]:
		if not whole(data.get(field), 0, 10000000): return false
	if data.seeds + data.planted != data.bought or int(data.harvested) % 10 != 0: return false
	if not data.get("plots") is Array or data.plots.size() != 24: return false
	var occupied := 0
	for index in range(24):
		var plot = data.plots[index]
		if not plot is Dictionary or not plot.get("planted") is bool: return false
		if not whole(plot.get("watered_at"), -1, now): return false
		if not whole(plot.get("grow_minutes"), 240, 360) or int(plot.grow_minutes) not in GROW_MINUTES: return false
		if plot.planted:
			if index >= PLOTS[int(data.level) - 1]: return false
			occupied += 1
		elif plot.watered_at != -1: return false
	return data.planted == occupied + int(data.harvested) / 10
