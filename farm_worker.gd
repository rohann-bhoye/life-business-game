extends Node3D

# Kiran, the farm worker. Once hired he walks between farm beds during the day
# (06:00-20:00) and plants, waters and harvests using the backend's
# farm_worker_next_bed()/farm_worker_work(). Harvests go to warehouse storage.
const SPEED := 1.6
const IDLE_POINT := Vector3(-18.6, 0.1, -5.0)
const WORK_SECONDS := 1.2

var route: Array[Vector3] = []
var route_index := 0
var target_bed := -1
var work_remaining := 0.0
@onready var world = get_tree().current_scene
@onready var business = world.get_node("Shop/ShopArea").business
@onready var farm = get_parent()

func _ready() -> void:
	name = "FarmWorker"
	position = IDLE_POINT
	var visual := Node3D.new()
	visual.name = "CharacterVisual"
	visual.set_script(preload("res://character_visual.gd"))
	visual.model = "female-b"
	visual.shirt_color = Color(0.3, 0.55, 0.25)
	add_child(visual)
	var label: Label3D = world.get_node("ShopOperations")._sign(self, "EmployeeName", "Kiran - Farm", Vector3(0, 1.85, 0))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.005
	visible = business.farm.worker_hired
	business.changed.connect(func(): visible = business.farm.worker_hired)

# Walk along the path between bed rows, then along the row to the bed.
func _route_to(point: Vector3) -> void:
	route.clear()
	if absf(position.z - point.z) > 0.05: route.append(Vector3(position.x, 0.1, point.z))
	route.append(point)
	route_index = 0

func _physics_process(delta: float) -> void:
	if not business.farm.worker_hired: return
	if work_remaining > 0.0:
		work_remaining -= delta
		return
	if route.is_empty():
		if target_bed >= 0:
			if business.farm_worker_work(target_bed): $CharacterVisual.play_work_animation()
			target_bed = -1
			work_remaining = WORK_SECONDS
			return
		var bed: int = business.farm_worker_next_bed()
		if bed >= 0:
			target_bed = bed
			_route_to(farm.beds[bed].position + Vector3(0, -0.03, 0.8))
		elif position.distance_to(IDLE_POINT) > 0.2:
			_route_to(IDLE_POINT)
		return
	var remaining := maxf(0, delta) * SPEED
	while route_index < route.size():
		var point := route[route_index]
		var distance := position.distance_to(point)
		if distance > 0.01: look_at(farm.to_global(point), Vector3.UP)
		position = position.move_toward(point, remaining)
		if distance > remaining: return
		remaining -= distance
		route_index += 1
	route.clear()
