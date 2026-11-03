extends Panel

# One hotbar slot. While the inventory screen is open it takes items dragged from the grid
# (inventory/inventory_slot.gd drag data) or from another hotbar slot, and can itself be
# dragged back onto the grid. Right-click empties it.

signal assigned(slot: int, from_index: int)
signal clicked(slot: int, button: int)

var index := 0
var accepting := false
var filled := false
var picture: TextureRect

func _get_drag_data(_at: Vector2) -> Variant:
	if not accepting or not filled: return null
	var preview := TextureRect.new()
	preview.texture = picture.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(56, 56)
	preview.position = Vector2(-28, -28)
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	# A negative number marks "from the hotbar": -1 is slot 1.
	return {"inv_from": -(index + 1), "split": false}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return accepting and data is Dictionary and (data as Dictionary).has("inv_from")

func _drop_data(_at: Vector2, data: Variant) -> void:
	assigned.emit(index, int(data["inv_from"]))

func _gui_input(event: InputEvent) -> void:
	if accepting and event is InputEventMouseButton and event.pressed:
		clicked.emit(index, event.button_index)
