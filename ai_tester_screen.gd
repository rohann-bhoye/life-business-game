extends Control

# "AI Test" screen (main menu, top-right button). The AI Tester (ai_tester.gd) plays
# three short test games on a throw-away shop and this screen shows its report.
# Real saves are never touched. The report is also saved to user://ai_test_report.md.
# Esc or Close leaves. "Run again" plays new games (next seed).
signal closed

const AiTester := preload("res://ai_tester.gd")
const Bazaar := preload("res://ui_bazaar.gd")
const REPORT_PATH := "user://ai_test_report.md"
const DAYS := 10

var card: Panel
var text_box: TextEdit
var status: Label
var run_button: Button
var copy_button: Button
var close_button: Button
var seed_value := 1
var running := false
var report := ""

func _ready() -> void:
	name = "AiTesterScreen"
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	card = Panel.new()
	card.name = "Card"
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	var heading := Label.new()
	heading.text = "AI TESTER  -  a bot plays your game and reports problems"
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)
	text_box = TextEdit.new()
	text_box.name = "Report"
	text_box.editable = false
	text_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.add_theme_font_size_override("font_size", 14)
	# Read-only text is greyed out by default: dark ink on a white card instead.
	text_box.add_theme_color_override("font_readonly_color", Bazaar.INK)
	var paper := Bazaar.box(Bazaar.CARD, 2, 8, Bazaar.LINE)
	paper.content_margin_left = 10
	paper.content_margin_right = 10
	paper.content_margin_top = 8
	paper.content_margin_bottom = 8
	text_box.add_theme_stylebox_override("read_only", paper)
	text_box.add_theme_stylebox_override("normal", paper)
	box.add_child(text_box)
	status = Label.new()
	status.name = "Status"
	status.add_theme_font_size_override("font_size", 13)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	run_button = _button(buttons, "Run again", _run_again)
	run_button.name = "RunButton"
	run_button.theme_type_variation = "PrimaryButton"
	copy_button = _button(buttons, "Copy report", _copy)
	copy_button.name = "CopyButton"
	close_button = _button(buttons, "Close", close)
	close_button.name = "CloseButton"
	get_viewport().size_changed.connect(_layout)
	_layout()

func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(120, 36)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var size_now := Vector2(minf(940.0, view.x - 24.0), minf(640.0, view.y - 24.0))
	card.size = size_now
	card.position = ((view - size_now) / 2.0).floor()

func open() -> void:
	show()
	_layout()
	if report.is_empty(): _run()

func close() -> void:
	hide()
	closed.emit()

func _run_again() -> void:
	seed_value += 1
	_run()

func _run() -> void:
	if running: return
	running = true
	run_button.disabled = true
	copy_button.disabled = true
	status.text = ""
	text_box.text = "The AI tester is playing %d days in %d test games (%s)...\nThis takes a few seconds." % [DAYS, AiTester.STYLE_ORDER.size(), ", ".join(AiTester.STYLE_ORDER)]
	# Let the "playing" text appear before the (blocking) test games start.
	await get_tree().process_frame
	await get_tree().process_frame
	var bot = AiTester.new()
	var results: Array = bot.run_suite(DAYS, seed_value)
	report = bot.report_text(results)
	text_box.text = report
	text_box.scroll_vertical = 0.0
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(report)
		file.close()
		status.text = "Saved to %s" % ProjectSettings.globalize_path(REPORT_PATH)
	else:
		status.text = "The report could not be saved to a file, but it is shown above."
	running = false
	run_button.disabled = false
	copy_button.disabled = false

func _copy() -> void:
	DisplayServer.clipboard_set(report)
	status.text = "Report copied. Paste it wherever you like."

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
