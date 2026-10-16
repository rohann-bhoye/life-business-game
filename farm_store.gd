extends RefCounted

const PLOTS := [4, 12, 24]
const GROW_MINUTES := [360, 300, 240]
const UPGRADE_COSTS := [2000, 5000]
const SEED_COST := 100
## Farm crops; each is also a sellable catalog SKU of the same id.
const CROPS := ["tomato", "carrot", "cabbage", "corn", "apple"]
const SEED_COSTS := {"tomato": 100, "carrot": 80, "cabbage": 120, "corn": 100, "apple": 150}
const CROP_NAMES := {"tomato": "Tomato", "carrot": "Carrot", "cabbage": "Cabbage", "corn": "Corn", "apple": "Apple"}
var level := 1
## Totals across all crops (kept for older saves and validation).
var seeds := 0
var bought := 0
var planted := 0
var harvested := 0
## Crop chosen at the seed stall for buying and planting.
var crop := "tomato"
var crop_seeds := {}
var crop_bought := {}
var crop_harvested := {}
var plots: Array = []

func _init() -> void:
	for index in range(24): plots.append(empty_plot())
	for id in CROPS:
		crop_seeds[id] = 0
		crop_bought[id] = 0
		crop_harvested[id] = 0

static func empty_plot() -> Dictionary:
	return {"planted": false, "watered_at": -1, "grow_minutes": 360}

static func plot_crop(plot: Dictionary) -> String:
	return plot.get("crop", "tomato")

func snapshot() -> Dictionary:
	return {"level": level, "seeds": seeds, "bought": bought, "planted": planted, "harvested": harvested, "plots": plots.duplicate(true), "crop": crop, "crop_seeds": crop_seeds.duplicate(), "crop_bought": crop_bought.duplicate(), "crop_harvested": crop_harvested.duplicate()}

func restore(data: Dictionary) -> void:
	for field in ["level", "seeds", "bought", "planted", "harvested"]: set(field, int(data[field]))
	plots = data.plots.duplicate(true)
	for plot in plots:
		plot.watered_at = int(plot.watered_at)
		plot.grow_minutes = int(plot.grow_minutes)
	crop = data.get("crop", "tomato")
	# Older saves only had tomatoes: their totals belong to the tomato crop.
	var legacy := {"crop_seeds": seeds, "crop_bought": bought, "crop_harvested": harvested}
	for field in legacy:
		var source: Dictionary = data.get(field, {"tomato": legacy[field]})
		var target := {}
		for id in CROPS: target[id] = int(source.get(id, 0))
		set(field, target)

func expenses() -> int:
	var total := 0
	for id in CROPS: total += int(crop_bought[id]) * SEED_COSTS[id]
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
	if data.get("crop", "tomato") not in CROPS: return false
	# Per-crop counters (optional for older saves) must add up to the totals.
	for pair in [["crop_seeds", "seeds"], ["crop_bought", "bought"], ["crop_harvested", "harvested"]]:
		if not data.has(pair[0]): continue
		var counts = data[pair[0]]
		if not counts is Dictionary: return false
		var sum := 0
		for id in counts:
			if id not in CROPS or not whole(counts[id], 0, 10000000): return false
			sum += int(counts[id])
		if sum != int(data[pair[1]]): return false
	if data.has("crop_harvested"):
		for id in data.crop_harvested:
			if int(data.crop_harvested[id]) % 10 != 0: return false
	if not data.get("plots") is Array or data.plots.size() != 24: return false
	var occupied := 0
	for index in range(24):
		var plot = data.plots[index]
		if not plot is Dictionary or not plot.get("planted") is bool: return false
		if not whole(plot.get("watered_at"), -1, now): return false
		if not whole(plot.get("grow_minutes"), 240, 360) or int(plot.grow_minutes) not in GROW_MINUTES: return false
		if plot.get("crop", "tomato") not in CROPS: return false
		if plot.planted:
			if index >= PLOTS[int(data.level) - 1]: return false
			occupied += 1
		elif plot.watered_at != -1: return false
	return data.planted == occupied + int(data.harvested) / 10
