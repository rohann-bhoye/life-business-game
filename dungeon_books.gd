extends CanvasLayer

# Dada-ji's diary: four pages left on stone stands in Gufa Darwaza (cells "1"-"4" in
# dungeon_layouts.gd, built by dungeon_floor.gd). Each page tells the story of the monster
# waiting further in, beside field notes read from monster.gd. E at a stand opens the page
# here (dungeon_world.gd), E, Esc or a click closes it. Pages read are kept in the save
# (dungeon_store.gd books). The player stands still while it is open (player.gd).
const Monster := preload("res://monster.gd")
const ORDER := ["slime", "bat", "mushroom", "boss"]
const BOOKS := {
	"slime": {"drop": "Slime jelly", "story": "My first night inside the Darwaza. The walls glow because of the jugnu, thousands of fireflies, and something in here eats them.\n\nThe Jugnu Slime: a soft green blob with fireflies trapped inside, so it shines as it hops. It looks harmless. It is not. Once it sees you it follows, and it does not tire.\n\nTwo good blows of a lathi and it pops into smoke, leaving a spoon of jelly the Guild will pay for. Keep your back to a wall."},
	"bat": {"drop": "Bat wing", "story": "In the long hall to the north, the ceiling moves.\n\nChamgadar. They hang in the dark and drop when they hear feet on the stone. A Chamgadar is faster than you and it flies, so running will not save you.\n\nBut it is thin. One solid hit brings it down. Stand still, let it come to you, and swing when it is right in front. Their wings sell at the Guild, though I never asked what for."},
	"mushroom": {"drop": "Khumbi cap", "story": "The glowing grove belongs to the Khumbi. They look like mushrooms until one stands up on two small feet.\n\nSlow walkers, but they hit the hardest of the small ones, so never let two of them corner you. Three blows to the cap and they fall over.\n\nIf one shines gold, it is an elite: twice the health, and it sees you from further away. Leave that one for last."},
	"boss": {"drop": "3 treasure, and the chest", "story": "Past the bridge is a hall where the floor shines. There sits the Raja Jelly, king of all the slimes, wearing a crown it took from someone braver than me.\n\nIt is huge and slow and it hits like a bullock cart. Hit it, step back, hit it again. Never stand still in front of it.\n\nBeside its throne is a chest. I never opened it. Beta, if you are reading this, open it for me."},
}
const PAPER := Color(0.93, 0.87, 0.72)
const INK := Color(0.22, 0.13, 0.06)
const FADED := Color(0.48, 0.36, 0.22)
const SIZE := Vector2(800, 500)

var card: Panel
var page_label: Label
var title_label: Label
var story_label: Label
var notes_label: Label
var found_label: Label

func _init() -> void:
	name = "BookReader"
	layer = 31
	visible = false
	add_to_group("dungeon_panel")

func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	card = Panel.new()
	card.size = SIZE
	card.pivot_offset = SIZE * 0.5
	card.rotation = -0.012
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color(0.5, 0.36, 0.18)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 24
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	page_label = _ink(card, 13, FADED, Vector2(34, 24), 480)
	title_label = _ink(card, 30, INK, Vector2(34, 44), 480)
	var rule := ColorRect.new()
	rule.color = Color(0.5, 0.36, 0.18, 0.5)
	rule.position = Vector2(34, 92)
	rule.size = Vector2(SIZE.x - 68, 1)
	card.add_child(rule)
	story_label = _ink(card, 15, INK, Vector2(34, 108), 470)
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.add_theme_constant_override("line_spacing", 3)
	# Field notes on a darker slip of paper on the right.
	var slip := Panel.new()
	slip.position = Vector2(534, 108)
	slip.size = Vector2(232, 222)
	var slip_style := StyleBoxFlat.new()
	slip_style.bg_color = Color(0.86, 0.78, 0.6)
	slip_style.border_color = Color(0.5, 0.36, 0.18, 0.6)
	slip_style.set_border_width_all(1)
	slip_style.set_corner_radius_all(3)
	slip.add_theme_stylebox_override("panel", slip_style)
	slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(slip)
	_ink(slip, 14, Color(0.55, 0.2, 0.1), Vector2(16, 12), 200).text = "FIELD NOTES"
	notes_label = _ink(slip, 14, INK, Vector2(16, 40), 204)
	notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes_label.add_theme_constant_override("line_spacing", 4)
	found_label = _ink(card, 13, FADED, Vector2(34, SIZE.y - 38), 300)
	var close_hint := _ink(card, 13, FADED, Vector2(SIZE.x - 334, SIZE.y - 38), 300)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_hint.text = "E / Esc / Click   close the diary"
	get_viewport().size_changed.connect(_place)
	_place()

func _ink(parent: Control, px: int, colour: Color, at: Vector2, width: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", colour)
	label.position = at
	label.size.x = width
	label.custom_minimum_size.x = width
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _place() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit := minf(1.0, minf((view.x - 32.0) / SIZE.x, (view.y - 40.0) / SIZE.y))
	card.scale = Vector2.ONE * fit
	card.position = ((view - SIZE) * 0.5).floor()

## Opens the page about `kind`; damage is what it does per touch (dungeon_world.gd).
func open_page(kind: String, damage: int, found: int) -> void:
	var info: Dictionary = Monster.KINDS[kind]
	var book: Dictionary = BOOKS[kind]
	page_label.text = "DADA-JI'S DIARY   -   PAGE %d" % (ORDER.find(kind) + 1)
	title_label.text = info.name
	story_label.text = book.story + "\n\n- Dada-ji"
	var levels: Array = info.levels
	var speed: float = info.speed
	var pace := "slower than you" if speed < 3.0 else "nearly as fast as you"
	notes_label.text = "Level   %s\nHealth   %d  (elite %d)\nHits you for   %d\nSpeed   %s\nSees you at   %d m%s\nDrops   %s" % [
		str(levels[0]) if levels[0] == levels[1] else "%d - %d" % [levels[0], levels[1]],
		int(info.hp), int(info.hp) * 2, damage, pace, int(info.notice),
		"\nFlies   yes" if info.has("flies") else "", book.drop]
	found_label.text = "Pages found   %d / %d" % [found, ORDER.size()]
	visible = true

func close() -> void:
	visible = false

func _input(event: InputEvent) -> void:
	if not visible: return
	var esc: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if esc or click:
		get_viewport().set_input_as_handled()
		get_parent().close_book()
