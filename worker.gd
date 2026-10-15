extends Node3D

const RESTOCK_THRESHOLD := 2

@export var shop_area_path: NodePath

var hired := false

@onready var shop_area: Area3D = get_node(shop_area_path)

func _ready() -> void:
	visible = false
	$RestockTimer.timeout.connect(_on_restock_timer_timeout)

func hire() -> void:
	hired = true
	visible = true
	$RestockTimer.start()

func _on_restock_timer_timeout() -> void:
	var operations = get_tree().current_scene.get_node("ShopOperations")
	if operations.enabled:
		return
	if hired and shop_area.business.worker_on_duty() and shop_area.stock <= RESTOCK_THRESHOLD:
		if shop_area.purchase_stock():
			$CharacterVisual.play_work_animation()

func update_duty() -> void:
	if shop_area.business.worker_on_duty():
		if $RestockTimer.is_stopped():
			$RestockTimer.start()
	else:
		$RestockTimer.stop()
