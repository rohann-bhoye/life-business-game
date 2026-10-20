extends "res://conversation_box.gd"

# Quick chat with a co-op friend (E on them): pick one of the set lines and it
# appears over your head on everyone else's screen (coop_world.gd).

var peer_id := 0

func open_for(id: int, friend_name: String) -> void:
	peer_id = id
	var coop = get_tree().current_scene.get_node("CoopWorld")
	present(friend_name, "Co-op partner  |  Pick a quick line", Color(0.5, 0.32, 0.68), "Haan, bolo!", coop.QUICK_LINES)

func _reply(index: int) -> void:
	if not visible: return
	var coop = get_tree().current_scene.get_node_or_null("CoopWorld")
	if coop != null: coop.send_quick_line(index)
	close_menu()
