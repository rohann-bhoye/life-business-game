extends Node3D

# The story start: a new game opens with Apna Mart's shutter down, a FOR SALE board and
# Seth Ramlal, Dada-ji's friend, outside. E on him or the shutter opens the sale talk
# (shop_sale_dialog.gd); paying (business.buy_shop) rolls the shutter up. Games that already
# own the shop (old saves, co-op) build nothing. Created by shop_operations.gd.
const BrickWorks := preload("res://brick_works.gd")
const DOOR := Vector3(-3.0, 0.0, 2.9)
const OWNER_AT := Vector3(-0.9, 0.1, 3.7)
const REACH := 3.6

var ops: Node
var business
var player: CharacterBody3D
var ui: Node
var shutter: Node3D
var wall: StaticBody3D
var board: Label3D
var owner_npc: Node3D
var gone := false

func _ready() -> void:
	name = "ShopSale"
	var scene := get_tree().current_scene
	business = scene.get_node("Shop/ShopArea").business
	player = scene.get_node("Player")
	ui = scene.get_node("Ui")
	if business.shop_owned: return
	_build()

func _build() -> void:
	BrickWorks.shutter(self, "SaleShutter", DOOR, 0.0, 3.4, 2.5)
	shutter = get_node("SaleShutter")
	wall = StaticBody3D.new()
	wall.name = "SaleShutterBody"
	wall.position = DOOR + Vector3(0, 1.4, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.2, 2.8, 0.5)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	board = Label3D.new()
	board.name = "ForSale"
	board.text = "FOR SALE\nAPNA MART\n%s%d" % [String.chr(8377), business.shop_price()]
	board.font_size = 72
	board.pixel_size = 0.0045
	board.modulate = Color(1, 0.95, 0.75)
	board.outline_modulate = Color(0.45, 0.05, 0.05)
	board.outline_size = 22
	board.position = DOOR + Vector3(0, 1.35, 0.08)
	add_child(board)
	owner_npc = Node3D.new()
	owner_npc.name = "SethRamlal"
	owner_npc.set_script(preload("res://character_visual.gd"))
	owner_npc.set("model", "uncle")
	owner_npc.position = OWNER_AT
	owner_npc.rotation.y = PI + 0.5
	add_child(owner_npc)

func _near() -> bool:
	if gone or not is_instance_valid(owner_npc): return false
	var spot := player.global_position
	return Vector2(spot.x - OWNER_AT.x, spot.z - OWNER_AT.z).length() < REACH or Vector2(spot.x - DOOR.x, spot.z - DOOR.z).length() < REACH

func hint() -> String:
	if not _near(): return ""
	return "E - talk to Seth Ramlal (buy Apna Mart, %s%d)" % [String.chr(8377), business.shop_price()]

func try_interact() -> bool:
	if not _near(): return false
	ui.shop_sale_dialog.open_for(self)
	return true

## Called by the dialog once the shop is paid for: the shutter rolls up and Seth Ramlal leaves.
func sold() -> void:
	if gone: return
	gone = true
	ui.show_feedback("Apna Mart is yours! Order products on the shop PC to begin.")
	if is_instance_valid(wall): wall.queue_free()
	if is_instance_valid(board): board.queue_free()
	var tween := create_tween()
	if is_instance_valid(shutter): tween.tween_property(shutter, "position:y", 3.2, 1.4)
	tween.tween_callback(func():
		if is_instance_valid(shutter): shutter.queue_free())
	if is_instance_valid(owner_npc):
		var walk := create_tween()
		walk.tween_interval(1.0)
		walk.tween_property(owner_npc, "position:x", OWNER_AT.x + 9.0, 6.0)
		walk.tween_callback(owner_npc.queue_free)

## Seth Ramlal turns to face you whenever you are near, so he looks at you while you talk.
func _process(delta: float) -> void:
	if gone or not is_instance_valid(owner_npc) or not is_instance_valid(player): return
	var spot := player.global_position
	var to_player := Vector2(spot.x - owner_npc.global_position.x, spot.z - owner_npc.global_position.z)
	if to_player.length() > 14.0 or to_player.length() < 0.1: return
	var want := atan2(to_player.x, to_player.y) + PI
	owner_npc.rotation.y = lerp_angle(owner_npc.rotation.y, want, clampf(delta * 6.0, 0.0, 1.0))
