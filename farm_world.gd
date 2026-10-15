extends Node3D

var beds: Array[Node3D] = []
var labels: Array[Label3D] = []
var crop_models: Array[Node3D] = []
var farm_title: Label3D
var roadmap: Panel
var suggestion: TextEdit
var feedback: Label
var form: VBoxContainer
var suggestions_path := "user://player_suggestions.json"
@onready var world = get_parent()
@onready var business = world.get_node("Shop/ShopArea").business
@onready var player = world.get_node("Player")
@onready var ui = world.get_node("Ui")
@onready var builder = world.get_node("Neighbourhood")

func _ready() -> void:
	for index in range(24):
		var bed := Node3D.new()
		bed.name = "FarmBed%d" % index
		bed.position = Vector3(-28 + (index % 4) * 2.6, 0.13, -3 - (index / 4) * 1.6)
		add_child(bed)
		beds.append(bed)
		builder._box("Soil", bed, Vector3(1.6, 0.08, 0.9), Vector3.ZERO, Color(0.24, 0.16, 0.09))
		for side in [-1, 1]: builder._box("Timber%d" % side, bed, Vector3(1.75, 0.14, 0.08), Vector3(0, 0.04, side * 0.5), Color(0.48, 0.34, 0.19))
		var crop := Node3D.new()
		crop.name = "Crop"
		bed.add_child(crop)
		crop_models.append(crop)
		for x in [-0.5, 0, 0.5]:
			builder._box("Stem%s" % x, crop, Vector3(0.05, 0.6, 0.05), Vector3(x, 0.3, 0), Color(0.2, 0.43, 0.08))
			builder._box("Leaves%s" % x, crop, Vector3(0.35, 0.08, 0.24), Vector3(x, 0.35, 0), Color(0.17, 0.44, 0.11))
			var fruit = world.get_node("ShopOperations").make_product(crop, "Fruit%s" % x, Vector3(x, 0.38, 0), "tomato")
			fruit.scale = Vector3.ONE * 1.1
		var label: Label3D = world.get_node("ShopOperations")._sign(bed, "CropStatus", "", Vector3(0, 0.9, 0))
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.003
		labels.append(label)
	builder._box("FarmPath", self, Vector3(11, 0.015, 1.1), Vector3(-24, 0.125, -1.5), Color(0.52, 0.49, 0.4))
	farm_title = world.get_node("ShopOperations")._sign(self, "FarmTitle", "APNA FARM", Vector3(-24, 1.6, -1.8))
	farm_title.pixel_size = 0.005
	_build_entrance()
	builder._box("SeedTable", self, Vector3(1.6, 0.9, 0.75), Vector3(-18, 0.55, -4), Color(0.32, 0.45, 0.35), true)
	builder._box("SeedRoof", self, Vector3(2.2, 0.12, 1.7), Vector3(-18, 2.7, -4), Color(0.18, 0.38, 0.2))
	for x in [-19, -17]: builder._box("SeedPost%s" % x, self, Vector3(0.09, 2.5, 0.09), Vector3(x, 1.35, -4.4), Color(0.37, 0.29, 0.2))
	for index in range(5):
		var packet = builder._box("SeedPacket%d" % index, self, Vector3(0.17, 0.22, 0.055), Vector3(-18.55 + index * 0.27, 1.12, -3.9), Color(0.91, 0.88, 0.65))
		builder._box("TomatoMark", packet, Vector3(0.08, 0.08, 0.01), Vector3(0, 0, 0.034), Color(0.84, 0.12, 0.07))
	builder._box("ProduceDisplay", self, Vector3(1.7, 0.82, 0.6), Vector3(-18, 0.51, -5.55), Color(0.46, 0.34, 0.2))
	var produce := ["tomato", "carrot", "apple", "cabbage", "corn"]
	for index in range(produce.size()):
		var display := preload("res://produce_assets.gd").attach(self, produce[index], Vector3(0.25, 0.27, 0.25), "Display" + produce[index])
		display.position = Vector3(-18.62 + index * 0.31, 0.93, -5.55)
	var sign: Label3D = world.get_node("ShopOperations")._sign(self, "SeedSign", "APNA SEEDS\nTOMATO FARM", Vector3(-18, 2.2, -3.4))
	builder._box("SeedSignBoard", self, Vector3(1.5, 0.42, 0.08), Vector3(-18, 2.2, -3.45), Color(0.08, 0.29, 0.2))
	sign.font_size = 28
	sign.pixel_size = 0.003
	builder._box("RoadmapBoard", self, Vector3(2.0, 1.5, 0.12), Vector3(29, 1.8, 1.3), Color(0.06, 0.17, 0.2))
	var notice: Label3D = world.get_node("ShopOperations")._sign(self, "RoadmapSign", "COMING NEXT\nAPNA MART DEMO\nPLAYER SUGGESTIONS", Vector3(29, 1.8, 1.4))
	notice.pixel_size = 0.005
	_build_roadmap()
	business.changed.connect(refresh)
	business.clock_changed.connect(refresh)
	refresh()
	var fixed_geometry: Array = []
	for bed in beds:
		for child in bed.get_children():
			if child is MeshInstance3D: fixed_geometry.append(child)
	preload("res://scenery_batch.gd").build(self, fixed_geometry, "FarmStaticBatch")

func _build_entrance() -> void:
	var paving: Material = world.get_node("ShopPresentation").surface(Vector2(0.5, 0.5), 1.6)
	var path = builder._box("RoadToFarmPath", self, Vector3(2.0, 0.025, 5.45), Vector3(-24, 0.131, 0.975), Color(0.65, 0.69, 0.67))
	path.material_override = paving
	get_node("FarmPath").material_override = paving
	for x in [-25.05, -22.95]:
		builder._box("PathKerb%s" % x, self, Vector3(0.09, 0.1, 4.0), Vector3(x, 0.17, 1.4), Color(0.66, 0.69, 0.68))
	_fence_segment("FarmBackFence", Vector3(-29.5, 0.1, -12), Vector3(-16.8, 0.1, -12))
	_fence_segment("FarmLeftFence", Vector3(-29.5, 0.1, -12), Vector3(-29.5, 0.1, -0.65))
	_fence_segment("FarmRightFence", Vector3(-16.8, 0.1, -12), Vector3(-16.8, 0.1, -0.65))
	_fence_segment("FarmFrontLeft", Vector3(-29.5, 0.1, -0.65), Vector3(-25.2, 0.1, -0.65))
	_fence_segment("FarmFrontRight", Vector3(-22.8, 0.1, -0.65), Vector3(-16.8, 0.1, -0.65))
	for x in [-25.2, -22.8]: builder._box("GatePost%s" % x, self, Vector3(0.18, 2.65, 0.18), Vector3(x, 1.425, -0.65), Color(0.38, 0.29, 0.2), true)
	builder._box("FarmEntranceSign", self, Vector3(2.6, 0.72, 0.14), Vector3(-24, 2.72, -0.65), Color(0.08, 0.29, 0.2))
	farm_title.position = Vector3(-24, 2.72, -0.555)
	farm_title.font_size = 36
	farm_title.pixel_size = 0.004

func _fence_segment(node_name: String, start: Vector3, end: Vector3) -> void:
	var fence := Node3D.new()
	fence.name = node_name
	fence.position = start
	var offset := end - start
	var length := offset.length()
	fence.rotation.y = -atan2(offset.z, offset.x)
	add_child(fence)
	for height in [0.45, 0.85]: builder._box("Rail%s" % height, fence, Vector3(length, 0.1, 0.1), Vector3(length / 2, height, 0), Color(0.66, 0.57, 0.43), true)
	var count := ceili(length / 1.2)
	var sources: Array = []
	for index in range(count + 1):
		var post = builder._box("Post%d" % index, fence, Vector3(0.12, 1.05, 0.12), Vector3(index * length / count, 0.525, 0), Color(0.39, 0.3, 0.21))
		sources.append(post)
	preload("res://scenery_batch.gd").build(fence, sources, "FencePosts")

func refresh() -> void:
	farm_title.text = "APNA FARM | LEVEL %d\n%d OPEN BEDS" % [business.farm.level, business.farm.PLOTS[business.farm.level - 1]]
	for index in range(24):
		var plot: Dictionary = business.farm.plots[index]
		var unlocked: bool = index < business.farm.PLOTS[business.farm.level - 1]
		var ready: bool = business.farm.ready(index, business.farm_time())
		crop_models[index].visible = unlocked and plot.planted
		var progress: float = clampf(float(business.farm_time() - plot.watered_at) / plot.grow_minutes, 0, 1) if plot.watered_at >= 0 else 0
		crop_models[index].scale.y = lerpf(0.2, 1.0, progress)
		for part in crop_models[index].get_children():
			if part.name.begins_with("Fruit"): part.visible = ready
		labels[index].text = "LOCKED" if not unlocked else ("EMPTY" if not plot.planted else ("HARVEST" if ready else ("NEEDS WATER" if plot.watered_at < 0 else "%dm remaining" % maxi(0, plot.watered_at + plot.grow_minutes - business.farm_time()))))

func near(point: Vector3, distance := 1.8) -> bool:
	var offset: Vector3 = player.global_position - point
	offset.y = 0
	return offset.length() < distance

func plot_target() -> int:
	var selected := -1
	var alignment := 0.75
	for index in range(beds.size()):
		if not near(beds[index].global_position, 1.3): continue
		var direction: Vector3 = player.camera.global_position.direction_to(beds[index].global_position + Vector3(0, 0.3, 0))
		var dot: float = (-player.camera.global_basis.z).dot(direction)
		if dot > alignment:
			alignment = dot
			selected = index
	return selected

func _process(_delta: float) -> void:
	if player._menu_is_open(): return
	if near(Vector3(-18, 0.1, -4)): ui.interaction_label.text = "Seed store"
	elif near(Vector3(29, 0.1, 1.3), 2.5): ui.interaction_label.text = "Coming next / Suggestions"
	else:
		var index := plot_target()
		if index >= 0: ui.interaction_label.text = labels[index].text

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E or player._menu_is_open(): return
	if near(Vector3(-18, 0.1, -4)):
		ui.shop_menu.show()
		ui.select_tab(5)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif near(Vector3(29, 0.1, 1.3), 2.5):
		roadmap.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		var index := plot_target()
		if index < 0: return
		if business.carried_stock > 0:
			ui.show_feedback("Put down or store the carried box before farm work.", true)
			get_viewport().set_input_as_handled()
			return
		var plot: Dictionary = business.farm.plots[index]
		var success: bool
		var text: String
		if not plot.planted:
			success = business.plant_crop(index)
			text = "Seed planted. Water the bed." if success else "Buy seeds or unlock this farm bed first."
		elif plot.watered_at < 0:
			success = business.water_crop(index)
			text = "Watered. Growth has started." if success else "Could not water/save this bed."
		else:
			success = business.harvest_crop(index)
			text = "Harvested 10 tomatoes. Carry the box to storage or an assigned shelf." if success else "Crop is growing, hands are occupied, or delivery capacity is full."
		ui.show_feedback(text, not success)
		if success:
			player.player_mesh.play_work_animation()
			world.get_node("ShopOperations").play_sound("stock")
	get_viewport().set_input_as_handled()

func _build_roadmap() -> void:
	roadmap = Panel.new()
	roadmap.name = "RoadmapMenu"
	roadmap.theme = ui.shop_menu.theme
	ui.add_child(roadmap)
	form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	roadmap.add_child(form)
	var title := Label.new()
	title.text = "COMING NEXT"
	form.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 180
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	form.add_child(scroll)
	var plans := Label.new()
	plans.text = "PLANNED FEATURES\nMore crops and seed varieties\nFarm tools and irrigation\nFarm workers and weather\nMixed-product customer baskets\nPlayer skills and staff training\nMore product and rack designs\nNew shop rooms and business locations\nSupplier relationships and discounts\nBank loans and competitor shops\nHome furniture and upgrades\nStreet traffic and richer sound\nMore save slots and control settings\nDemo tutorial and objectives\nFurther performance and character improvements\nWindows demo release"
	plans.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(plans)
	suggestion = TextEdit.new()
	suggestion.placeholder_text = "Your suggestion"
	suggestion.custom_minimum_size.y = 90
	form.add_child(suggestion)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(feedback)
	var submit := Button.new()
	submit.text = "Save suggestion"
	submit.pressed.connect(save_suggestion)
	form.add_child(submit)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_roadmap)
	form.add_child(close)
	roadmap.hide()
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	roadmap.size = Vector2(minf(560, size.x - 40), minf(500, size.y - 40))
	roadmap.position = (size - roadmap.size) / 2
	form.position = Vector2(20, 20)
	form.size = roadmap.size - Vector2(40, 40)

func save_suggestion() -> void:
	var text := suggestion.text.strip_edges()
	if text.length() < 5 or text.length() > 1000:
		feedback.text = "Enter 5 to 1,000 characters."
		return
	var path := suggestions_path
	var entries: Array = []
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Array:
			feedback.text = "Could not read existing suggestions."
			return
		entries = data
	if entries.size() >= 100:
		feedback.text = "Local suggestion storage is full."
		return
	entries.append({"text": text, "created": Time.get_datetime_string_from_system()})
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		feedback.text = "Could not save suggestion."
		return
	file.store_string(JSON.stringify(entries))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		feedback.text = "Could not save suggestion."
		return
	suggestion.text = ""
	feedback.text = "Saved on this PC. No online submission."

func close_roadmap() -> void:
	roadmap.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if roadmap.visible and event.is_action_pressed("ui_cancel"):
		close_roadmap()
		get_viewport().set_input_as_handled()
