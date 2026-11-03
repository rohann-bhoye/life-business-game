extends Node3D

var active := false
var screen_viewport: SubViewport
var screen_mesh: MeshInstance3D
var screen_menu: Panel
var pairs: Array = []
var syncing := false
var source
var focus_camera: Camera3D
var previous_camera: Camera3D
var transition: Tween
var saved_input: Array = []
var clock: Label
var desktop_theme: Theme
var store: Panel
var bank: Panel
var builders: Panel
var export_page: Panel
var licence_page: Panel
var business_page: Panel
var staff: Panel
var desktop: Control
## Which desktop app fills the screen: home, store, staff, manager or bank.
var app := "home"
var greeting: Label
var today_values := {}
var low_rows: Array = []
var task_buttons := {}
var toast: Label
var widget_seconds := 0.0
# Full-screen view: once the camera reaches the monitor, a sharp 2D copy of the
# screen covers the window exactly where the monitor is drawn.
var overlay: CanvasLayer
var overlay_image: TextureRect
var overlay_back: ColorRect
var fitted_size := Vector2.ZERO
const Catalog := preload("res://product_catalog.gd")
const KenneyTheme := preload("res://kenney_theme.gd")
const UiStyle := preload("res://ui_style.gd")
const SCREEN := Vector2(960, 540)
const RENDER_SCALE := 2
const HALF_SCREEN := Vector2(0.39, 0.22)
# Staff and People live in the Staff app (and Space has nothing to do), so the
# Shop Manager window hides those tabs.
const STAFF_TABS := [1, 2, 3]
const MANAGER_BRAND := Color("b45309")
@onready var world = get_tree().current_scene
@onready var player = world.get_node("Player")
@onready var ui = world.get_node("Ui")

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = Color(0.78, 0.82, 0.85)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style

func _ready() -> void:
	call_deferred("_configure")

func _configure() -> void:
	source = ui.supplier_menu
	screen_viewport = SubViewport.new()
	screen_viewport.name = "DesktopViewport"
	# Drawn at 2x and shown at SCREEN size so the full-screen view stays sharp.
	screen_viewport.size = Vector2i(SCREEN) * RENDER_SCALE
	screen_viewport.size_2d_override = Vector2i(SCREEN)
	screen_viewport.size_2d_override_stretch = true
	screen_viewport.disable_3d = true
	screen_viewport.gui_embed_subwindows = true
	screen_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(screen_viewport)
	desktop_theme = Theme.new()
	desktop_theme.default_font_size = 18
	UiStyle.apply(desktop_theme, true)
	KenneyTheme.apply(desktop_theme)
	_build_desktop()
	screen_menu = source.duplicate(0) as Panel
	screen_menu.name = "OperationsWindow"
	screen_menu.modulate = Color.WHITE
	screen_menu.theme = desktop_theme
	screen_viewport.add_child(screen_menu)
	_bind(source, screen_menu)
	var copy_tabs: TabBar = screen_menu.get_node("ManagementTabs")
	for index in STAFF_TABS: copy_tabs.set_tab_hidden(index, true)
	screen_menu.draw.connect(_draw_manager)
	var title: Label = screen_menu.get_node("TitleLabel")
	title.add_theme_font_override("font", KenneyTheme.heading_font())
	screen_menu.hide()
	_build_store(desktop)
	toast = Label.new()
	toast.name = "Toast"
	toast.position = Vector2(230, 452)
	toast.size = Vector2(500, 36)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 15)
	toast.add_theme_color_override("font_color", Color.WHITE)
	toast.add_theme_stylebox_override("normal", _round(Color(0.06, 0.09, 0.16, 0.92), 18))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.hide()
	screen_viewport.add_child(toast)
	_build_overlay()
	screen_mesh = MeshInstance3D.new()
	screen_mesh.name = "LiveScreen"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.78, 0.44)
	screen_mesh.mesh = quad
	screen_mesh.position = Vector3(0, 0.43, 0.125)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = screen_viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	screen_mesh.material_override = material
	screen_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen_mesh)
	var bezel := MeshInstance3D.new()
	bezel.name = "ScreenBezel"
	var bezel_mesh := QuadMesh.new()
	bezel_mesh.size = Vector2(0.84, 0.50)
	bezel.mesh = bezel_mesh
	bezel.position = Vector3(0, 0.43, 0.121)
	var bezel_material := StandardMaterial3D.new()
	bezel_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bezel_material.albedo_color = Color(0.025, 0.035, 0.04)
	bezel.material_override = bezel_material
	bezel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bezel)
	var power_light := MeshInstance3D.new()
	power_light.name = "PowerLight"
	var light_mesh := SphereMesh.new()
	light_mesh.radius = 0.013
	light_mesh.height = 0.026
	power_light.mesh = light_mesh
	power_light.position = Vector3(0.34, 0.165, 0.128)
	var light_material := StandardMaterial3D.new()
	light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light_material.albedo_color = Color(0.25, 0.95, 0.62)
	power_light.material_override = light_material
	power_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(power_light)
	focus_camera = Camera3D.new()
	focus_camera.name = "FocusCamera"
	focus_camera.fov = 45
	focus_camera.near = 0.02
	add_child(focus_camera)
	source.visibility_changed.connect(func():
		if active and not source.visible: close())
	show_home()
	_sync()

func _round(colour: Color, radius := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style

func _text(parent: Control, text: String, position: Vector2, width: float, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = Vector2(width, font_size + 10)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label

func _picture(parent: Control, path: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

# APNA OS home screen: wallpaper, app tiles, a "Today" summary, shelf stock and a
# taskbar. Each app (store, staff, shop manager, bank) opens over it.
func _build_desktop() -> void:
	desktop = Control.new()
	desktop.name = "Desktop"
	desktop.size = SCREEN
	desktop.theme = desktop_theme
	screen_viewport.add_child(desktop)
	var gradient := Gradient.new()
	gradient.set_color(0, Color("0f172a"))
	gradient.set_color(1, Color("0f766e"))
	var wallpaper_texture := GradientTexture2D.new()
	wallpaper_texture.gradient = gradient
	wallpaper_texture.fill_from = Vector2(0, 0)
	wallpaper_texture.fill_to = Vector2(1, 1)
	var wallpaper := TextureRect.new()
	wallpaper.name = "Wallpaper"
	wallpaper.texture = wallpaper_texture
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.size = SCREEN
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desktop.add_child(wallpaper)
	for circle in [Rect2(620, -160, 460, 460), Rect2(-180, 330, 420, 420)]:
		var glow := Panel.new()
		glow.position = circle.position
		glow.size = circle.size
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.add_theme_stylebox_override("panel", _round(Color(1, 1, 1, 0.05), 230))
		desktop.add_child(glow)
	greeting = _text(desktop, "", Vector2(40, 26), 520, 30, Color.WHITE)
	_text(desktop, "APNA OS | Apna Kirana Store", Vector2(42, 68), 520, 14, Color("99f6e4"))
	var apps := [
		["store", "Wholesale", Color("16a34a"), ""],
		["staff", "Staff", Color("7c3aed"), "res://assets/ui/staff/cashier.png"],
		["manager", "Orders", Color("d97706"), ""],
		["bank", "Bank", Color("2563eb"), ""],
		["builders", "Builders", Color("c2410c"), ""],
		["export", "Export", Color("1e3a8a"), ""],
		["licences", "Licences", Color("7c3aed"), ""],
		["business", "Business", Color("c2410c"), ""],
	]
	for index in range(apps.size()):
		var entry: Array = apps[index]
		var tile := Button.new()
		tile.name = "App_" + entry[0]
		# Eight tiles fit beside the Today card at 58% size.
		tile.position = Vector2(40 + index * 69, 112)
		tile.size = Vector2(116, 116)
		tile.scale = Vector2.ONE * 0.58
		tile.focus_mode = Control.FOCUS_NONE
		tile.clip_contents = true
		tile.tooltip_text = "Open " + entry[1]
		for state in [["normal", entry[2]], ["hover", entry[2].lightened(0.15)], ["pressed", entry[2].darkened(0.15)], ["hover_pressed", entry[2].darkened(0.15)]]:
			var style := _round(state[1], 26)
			style.shadow_color = Color(0, 0, 0, 0.25)
			style.shadow_size = 6
			style.shadow_offset = Vector2(0, 3)
			tile.add_theme_stylebox_override(state[0], style)
		tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		desktop.add_child(tile)
		if entry[3] != "": _picture(tile, entry[3], Rect2(18, 14, 80, 80))
		elif entry[0] == "store":
			# A few products from the catalogue, grouped like a shop window.
			for item in [["milk", Rect2(-2, 6, 76, 96)], ["bottle", Rect2(44, 4, 76, 96)], ["snack", Rect2(16, 26, 84, 90)]]:
				_picture(tile, "res://assets/ui/products/%s.png" % item[0], item[1])
		elif entry[0] == "bank": _text(tile, String.chr(8377), Vector2(0, 14), 116, 56, Color.WHITE).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		elif entry[0] == "business":
			# A little bar chart.
			for bar in range(4):
				var column := ColorRect.new()
				column.color = Color.WHITE
				column.mouse_filter = Control.MOUSE_FILTER_IGNORE
				column.size = Vector2(14, 22 + bar * 16)
				column.position = Vector2(24 + bar * 22, 90 - column.size.y)
				tile.add_child(column)
		elif entry[0] == "licences":
			# A white certificate with text lines and an orange seal.
			var paper := Panel.new()
			paper.position = Vector2(20, 22)
			paper.size = Vector2(76, 64)
			paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
			paper.add_theme_stylebox_override("panel", _round(Color.WHITE, 8))
			tile.add_child(paper)
			for line in range(3):
				var stroke := ColorRect.new()
				stroke.color = Color("c4b5fd")
				stroke.position = Vector2(30, 34 + line * 12)
				stroke.size = Vector2(44 - line * 10, 5)
				stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tile.add_child(stroke)
			var seal := Panel.new()
			seal.position = Vector2(70, 66)
			seal.size = Vector2(28, 28)
			seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
			seal.add_theme_stylebox_override("panel", _round(Color("f97316"), 14))
			tile.add_child(seal)
		elif entry[0] == "export":
			# A white globe with a little orange plane over it.
			var globe := Panel.new()
			globe.position = Vector2(22, 20)
			globe.size = Vector2(72, 72)
			globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
			globe.add_theme_stylebox_override("panel", _round(Color("bfdbfe"), 36))
			tile.add_child(globe)
			for part in [Rect2(52, 34, 12, 40), Rect2(36, 48, 44, 9), Rect2(48, 70, 20, 6)]:
				var piece := ColorRect.new()
				piece.color = Color("f97316")
				piece.position = part.position
				piece.size = part.size
				piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tile.add_child(piece)
		elif entry[0] == "builders":
			# The shop front from the site, framed like a photo.
			var photo_frame := Panel.new()
			photo_frame.position = Vector2(12, 22)
			photo_frame.size = Vector2(92, 72)
			photo_frame.clip_contents = true
			photo_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			photo_frame.add_theme_stylebox_override("panel", _round(Color.WHITE, 8))
			tile.add_child(photo_frame)
			var photo := _picture(photo_frame, "res://assets/ui/pc/look_2.jpg", Rect2(3, 3, 86, 66))
			photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		else:
			# A little shelf with boxes for the Shop Manager.
			for row in range(3):
				var shelf := ColorRect.new()
				shelf.color = Color.WHITE
				shelf.position = Vector2(24, 40 + row * 24)
				shelf.size = Vector2(68, 5)
				shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tile.add_child(shelf)
				for item in range(3 - row % 2):
					var box := ColorRect.new()
					box.color = [Color("fde68a"), Color("fecaca"), Color("bbf7d0")][(row + item) % 3]
					box.position = Vector2(28 + item * 22, 26 + row * 24)
					box.size = Vector2(16, 14)
					box.mouse_filter = Control.MOUSE_FILTER_IGNORE
					tile.add_child(box)
		var label := _text(desktop, entry[1], Vector2(tile.position.x - 8, 186), 90, 13, Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.pressed.connect(show_app.bind(entry[0]))
	# Shelf stock card: the products on the racks with the fewest items left.
	var shelf_card := Panel.new()
	shelf_card.name = "ShelfCard"
	shelf_card.position = Vector2(40, 272)
	shelf_card.size = Vector2(518, 210)
	shelf_card.add_theme_stylebox_override("panel", _round(Color(1, 1, 1, 0.95), 16))
	desktop.add_child(shelf_card)
	var shelf_title := _text(shelf_card, "SHELF STOCK", Vector2(18, 12), 300, 16, Color("0f766e"))
	shelf_title.add_theme_font_override("font", KenneyTheme.heading_font())
	var restock := Button.new()
	restock.name = "RestockButton"
	restock.text = "Restock"
	restock.theme_type_variation = "PrimaryButton"
	restock.position = Vector2(384, 10)
	restock.size = Vector2(120, 32)
	restock.focus_mode = Control.FOCUS_NONE
	restock.add_theme_font_size_override("font_size", 14)
	restock.pressed.connect(open_store)
	shelf_card.add_child(restock)
	for index in range(4):
		var row := Control.new()
		row.position = Vector2(18, 50 + index * 38)
		row.size = Vector2(482, 36)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shelf_card.add_child(row)
		var icon := _picture(row, "res://assets/ui/products/bottle.png", Rect2(0, 0, 34, 34))
		var name_label := _text(row, "", Vector2(44, 6), 190, 15, KenneyTheme.TEXT)
		var count := _text(row, "", Vector2(240, 6), 240, 14, KenneyTheme.MUTED)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		low_rows.append({"row": row, "icon": icon, "name": name_label, "count": count})
	# Today card.
	var today := Panel.new()
	today.name = "TodayCard"
	today.position = Vector2(590, 26)
	today.size = Vector2(330, 456)
	today.add_theme_stylebox_override("panel", _round(Color(1, 1, 1, 0.95), 16))
	desktop.add_child(today)
	var today_title := _text(today, "TODAY", Vector2(20, 14), 290, 16, Color("0f766e"))
	today_title.add_theme_font_override("font", KenneyTheme.heading_font())
	today_values["money"] = _text(today, "", Vector2(20, 44), 290, 30, KenneyTheme.GREEN)
	_text(today, "Money", Vector2(22, 84), 290, 12, KenneyTheme.MUTED)
	var rows := [["day", "Day"], ["shop", "Shop"], ["staff", "Staff on duty"], ["sold", "Items sold"], ["delivery", "Deliveries"], ["loan", "Loan"], ["rival", "Sharma's store"]]
	for index in range(rows.size()):
		var y := 116 + index * 46
		var divider := ColorRect.new()
		divider.color = Color("e5e7eb")
		divider.position = Vector2(20, y)
		divider.size = Vector2(290, 1)
		today.add_child(divider)
		_text(today, rows[index][1], Vector2(20, y + 10), 140, 14, KenneyTheme.MUTED)
		var value := _text(today, "", Vector2(140, y + 10), 170, 15, KenneyTheme.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		today_values[rows[index][0]] = value
	# Taskbar.
	var taskbar := ColorRect.new()
	taskbar.name = "Taskbar"
	taskbar.color = Color(0.03, 0.05, 0.09, 0.96)
	taskbar.position = Vector2(0, 500)
	taskbar.size = Vector2(SCREEN.x, 40)
	desktop.add_child(taskbar)
	var buttons := [["home", "APNA", 60], ["store", "Wholesale", 108], ["staff", "Staff", 66], ["manager", "Shop", 62], ["bank", "Bank", 62], ["builders", "Build", 66], ["export", "Export", 74], ["licences", "Licences", 90], ["business", "Business", 84]]
	var x := 8.0
	for entry in buttons:
		var button := Button.new()
		button.name = "Task_" + entry[0]
		button.text = entry[1]
		button.position = Vector2(x, 504)
		button.size = Vector2(entry[2], 32)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(show_app.bind(entry[0]))
		desktop.add_child(button)
		task_buttons[entry[0]] = button
		x += entry[2] + 6
	var exit := Button.new()
	exit.name = "ExitButton"
	exit.text = "Exit PC"
	exit.theme_type_variation = "DangerButton"
	exit.position = Vector2(x + 18, 504)
	exit.size = Vector2(104, 32)
	exit.focus_mode = Control.FOCUS_NONE
	exit.add_theme_font_size_override("font_size", 12)
	exit.tooltip_text = "Leave the computer (E / Esc)"
	exit.pressed.connect(close)
	desktop.add_child(exit)
	clock = Label.new()
	clock.position = Vector2(780, 508)
	clock.size = Vector2(168, 24)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.add_theme_font_size_override("font_size", 15)
	clock.add_theme_color_override("font_color", Color("e2e8f0"))
	desktop.add_child(clock)

# APNA Wholesale (pc_store.gd), APNA Bank (bank_page.gd) and APNA Jobs
# (staff_page.gd) are full pages over the desktop; Back returns home.
func _build_store(_desktop: Control) -> void:
	store = Panel.new()
	store.set_script(preload("res://pc_store.gd"))
	store.position = Vector2(24, 12)
	screen_viewport.add_child(store)
	store.setup(ui.shop.business, ui.shop._format_money)
	store.hide()
	store.back_requested.connect(show_home)
	store.licence_requested.connect(show_app.bind("licences"))
	var shop_online := Button.new()
	shop_online.name = "ShopOnlineButton"
	shop_online.text = "Shop online"
	shop_online.theme_type_variation = "PrimaryButton"
	shop_online.position = Vector2(590, 12)
	shop_online.size = Vector2(150, 36)
	shop_online.add_theme_font_size_override("font_size", 15)
	shop_online.focus_mode = Control.FOCUS_NONE
	screen_menu.add_child(shop_online)
	shop_online.pressed.connect(open_store)
	bank = Panel.new()
	bank.set_script(preload("res://bank_page.gd"))
	bank.position = Vector2(24, 12)
	screen_viewport.add_child(bank)
	bank.setup(ui.shop.business, ui.shop._format_money)
	bank.hide()
	bank.back_requested.connect(show_home)
	builders = Panel.new()
	builders.set_script(preload("res://builders_page.gd"))
	builders.position = Vector2(24, 12)
	screen_viewport.add_child(builders)
	builders.setup(ui.shop.business, ui.shop._format_money)
	builders.hide()
	builders.back_requested.connect(show_home)
	export_page = Panel.new()
	export_page.set_script(preload("res://export_page.gd"))
	export_page.position = Vector2(24, 12)
	screen_viewport.add_child(export_page)
	export_page.setup(ui.shop.business, ui.shop._format_money)
	export_page.hide()
	export_page.back_requested.connect(show_home)
	licence_page = Panel.new()
	licence_page.set_script(preload("res://licence_page.gd"))
	licence_page.position = Vector2(24, 12)
	screen_viewport.add_child(licence_page)
	licence_page.setup(ui.shop.business, ui.shop._format_money)
	licence_page.hide()
	licence_page.back_requested.connect(show_home)
	business_page = Panel.new()
	business_page.set_script(preload("res://business_page.gd"))
	business_page.position = Vector2(24, 12)
	screen_viewport.add_child(business_page)
	business_page.setup(ui.shop.business, ui.shop._format_money, ui.shop, ui)
	business_page.hide()
	business_page.back_requested.connect(show_home)
	staff = Panel.new()
	staff.set_script(preload("res://staff_page.gd"))
	staff.position = Vector2(24, 12)
	screen_viewport.add_child(staff)
	staff.setup(ui.shop.business, ui.shop._format_money, world.get_node_or_null("ShopOperations"))
	staff.hide()
	staff.back_requested.connect(show_home)
	# Talking happens in person: the staff dialog closes the computer.
	staff.talk_requested.connect(func(role): ui.staff_dialog.open_for(role))

func show_home() -> void:
	show_app("home")

func show_app(target: String) -> void:
	app = target
	if target == "manager" and source.tabs.current_tab in STAFF_TABS: source.tabs.current_tab = 0
	for pair in pairs:
		if pair[1] is OptionButton: pair[1].get_popup().hide()
	if is_instance_valid(store):
		store.visible = target == "store"
		if store.visible: store.refresh()
	if is_instance_valid(bank):
		bank.visible = target == "bank"
		if bank.visible: bank.refresh()
	if is_instance_valid(builders):
		builders.visible = target == "builders"
		if builders.visible: builders.refresh()
	if is_instance_valid(business_page):
		business_page.visible = target == "business"
		if business_page.visible: business_page.refresh()
	if is_instance_valid(licence_page):
		licence_page.visible = target == "licences"
		if licence_page.visible: licence_page.refresh()
	if is_instance_valid(export_page):
		export_page.visible = target == "export"
		if export_page.visible: export_page.open()
	if is_instance_valid(staff):
		staff.visible = target == "staff"
		if staff.visible: staff.select_role(staff.selected)
	for key in task_buttons: task_buttons[key].theme_type_variation = "PrimaryButton" if key == target else ""
	for card_name in ["ShelfCard", "TodayCard"]: desktop.get_node(card_name).visible = target == "home"
	_refresh_desktop()
	if active: _sync()

func open_bank() -> void:
	show_app("bank")

func open_builders() -> void:
	show_app("builders")

func open_store() -> void:
	show_app("store")

func open_staff(role := "") -> void:
	if is_instance_valid(staff) and role != "": staff.selected = role
	show_app("staff")

func _refresh_desktop() -> void:
	if not is_instance_valid(desktop): return
	var business = ui.shop.business
	var minutes := int(business.minutes_of_day)
	greeting.text = "Namaste, Seth ji!" if minutes < 1020 else "Shubh sandhya, Seth ji!"
	today_values.money.text = String.chr(8377) + ui.shop._format_money(business.money)
	today_values.day.text = "Day %d  %02d:%02d" % [business.day, minutes / 60, minutes % 60]
	today_values.shop.text = "Open" if business.shop_is_open() else "Closed"
	today_values.shop.add_theme_color_override("font_color", KenneyTheme.GREEN if business.shop_is_open() else Color("b91c1c"))
	var hired := 0
	var working := 0
	for role in business.staff.ROLES:
		if business.staff.active(business, role): hired += 1
	working = int(business.cashier_on_shift()) + int(business.stock_worker_on_shift()) + int(business.warehouse_worker_on_shift())
	today_values.staff.text = "%d of %d hired" % [working, hired] if hired > 0 else "Nobody hired"
	today_values.sold.text = str(business.items_sold)
	var outside: int = business.queued_boxes.size() + (1 if business.boxed_stock > 0 else 0)
	today_values.delivery.text = "%d on way | %d outside" % [business.incoming_boxes.size(), outside]
	today_values.loan.text = String.chr(8377) + ui.shop._format_money(business.loan_left()) + " left" if business.loan_left() > 0 else "None"
	today_values.rival.text = "Open" if business.rival_open() else "Opens day %d" % business.RIVAL_OPEN_DAY
	var products: Array = []
	for record in business.racks.records:
		for slot in record.slots:
			if slot.product != "" and slot.product not in products: products.append(slot.product)
	if products.is_empty(): products = ["bottle"]
	products.sort_custom(func(a, b): return business.product_stock(a) < business.product_stock(b))
	for index in range(low_rows.size()):
		var row: Dictionary = low_rows[index]
		row.row.visible = index < products.size()
		if not row.row.visible: continue
		var id: String = products[index]
		var left: int = business.product_stock(id)
		row.icon.texture = load("res://assets/ui/products/%s.png" % id)
		row.name.text = Catalog.NAMES[id]
		row.count.text = "Shelf %d | Warehouse %d" % [left, business.logistics.stored_units(id)]
		row.count.add_theme_color_override("font_color", Color("b91c1c") if left <= 3 else KenneyTheme.MUTED)

func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.name = "FullScreen"
	overlay.layer = 2
	overlay.visible = false
	add_child(overlay)
	overlay_back = ColorRect.new()
	overlay_back.name = "Back"
	overlay_back.color = Color(0.02, 0.025, 0.035)
	overlay_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(overlay_back)
	overlay_image = TextureRect.new()
	overlay_image.name = "Screen"
	overlay_image.texture = screen_viewport.get_texture()
	overlay_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay_image.stretch_mode = TextureRect.STRETCH_SCALE
	overlay_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(overlay_image)

## Camera pose where the monitor fills the window (letterboxed when the window
## is not 16:9), looking straight at the screen.
func _fit_transform() -> Transform3D:
	var view := get_viewport().get_visible_rect().size
	var centre := screen_mesh.global_position
	var half_width := (screen_mesh.to_global(Vector3(HALF_SCREEN.x, 0, 0)) - centre).length()
	var half_height := (screen_mesh.to_global(Vector3(0, HALF_SCREEN.y, 0)) - centre).length()
	var needed := maxf(half_height, half_width * view.y / maxf(1.0, view.x))
	var basis := screen_mesh.global_basis.orthonormalized()
	return Transform3D(basis, centre + basis.z * needed / tan(deg_to_rad(focus_camera.fov * 0.5)))

func _fit_overlay() -> void:
	fitted_size = get_viewport().get_visible_rect().size
	focus_camera.global_transform = _fit_transform()
	var top_left := focus_camera.unproject_position(screen_mesh.to_global(Vector3(-HALF_SCREEN.x, HALF_SCREEN.y, 0)))
	var bottom_right := focus_camera.unproject_position(screen_mesh.to_global(Vector3(HALF_SCREEN.x, -HALF_SCREEN.y, 0)))
	overlay_image.position = top_left
	overlay_image.size = bottom_right - top_left

func _show_full_screen() -> void:
	if not active: return
	_fit_overlay()
	# The zoom ends with the monitor exactly where the flat screen goes, so the screen
	# shows at once (a fade from black flashed); only the dark border fades in.
	overlay.visible = true
	overlay_image.modulate.a = 1.0
	overlay_back.modulate.a = 0.0
	create_tween().tween_property(overlay_back, "modulate:a", 1.0, 0.15)

func _bind(original: Control, copy: Control) -> void:
	pairs.append([original, copy])
	if copy is OptionButton:
		copy.item_selected.connect(func(index): original.select(index); original.item_selected.emit(index))
	elif copy is ItemList:
		copy.item_selected.connect(func(index): original.select(index); original.item_selected.emit(index))
	elif copy is Button and original.name == "CloseButton" and original.get_parent() == source:
		copy.pressed.connect(show_home)
	elif copy is Button:
		copy.pressed.connect(func(): original.pressed.emit())
		if copy.toggle_mode: copy.toggled.connect(func(value):
			if not syncing: original.button_pressed = value)
	elif copy is SpinBox:
		copy.value_changed.connect(func(value):
			if not syncing: original.value = value)
	elif copy is TabBar:
		copy.tab_changed.connect(func(index):
			if not syncing: original.current_tab = index)
	for child in original.get_children():
		if child is Control:
			var other := copy.get_node_or_null(NodePath(str(child.name))) as Control
			if other != null: _bind(child, other)

func _sync() -> void:
	syncing = true
	clock.text = "Day %d  %02d:%02d" % [ui.shop.business.day, int(ui.shop.business.minutes_of_day) / 60, int(ui.shop.business.minutes_of_day) % 60]
	for pair in pairs:
		var original: Control = pair[0]
		var copy: Control = pair[1]
		copy.visible = original.visible if original != source else (active and app == "manager")
		copy.position = original.position
		copy.size = original.size
		if original is Label: copy.text = original.text
		elif original is OptionButton:
			if copy.item_count != original.item_count:
				copy.clear()
				for index in range(original.item_count): copy.add_item(original.get_item_text(index), original.get_item_id(index))
			for index in range(original.item_count):
				copy.set_item_text(index, original.get_item_text(index))
				copy.set_item_disabled(index, original.is_item_disabled(index))
			copy.select(original.selected)
		elif original is ItemList:
			var selected: PackedInt32Array = original.get_selected_items()
			if not selected.is_empty(): copy.select(selected[0])
		elif original is Button:
			copy.text = original.text
			copy.disabled = original.disabled
			if original.toggle_mode: copy.set_pressed_no_signal(original.button_pressed)
		elif original is SpinBox:
			if not copy.get_line_edit().has_focus(): copy.set_value_no_signal(original.value)
		elif original is TabBar:
			if not copy.is_tab_hidden(original.current_tab): copy.current_tab = original.current_tab
		elif original is ProgressBar: copy.value = original.value
		if original.get_parent() == source and is_equal_approx(original.position.x + original.size.x, source.size.x - 16): copy.size.x += 912 - source.size.x
		if copy is Button and not copy is OptionButton:
			# Restyle only when the primary/secondary role changes (button text can change).
			var primary := UiStyle.is_primary(copy)
			if not copy.has_meta("ui_primary") or copy.get_meta("ui_primary") != primary:
				copy.set_meta("ui_primary", primary)
				copy.theme_type_variation = "PrimaryButton" if primary else ""
		if copy is Label or copy is Button or copy is TabBar:
			copy.add_theme_constant_override("outline_size", 0)
		if copy is Label:
			copy.add_theme_color_override("font_color", UiStyle.TEXT)
		if copy is Label:
			copy.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
			copy.add_theme_constant_override("shadow_offset_x", 0)
			copy.add_theme_constant_override("shadow_offset_y", 0)
			copy.add_theme_font_size_override("font_size", 18)
	screen_menu.position = Vector2(24, 12)
	screen_menu.size = Vector2(912, 468)
	screen_menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_style_manager()
	var close_button: Button = screen_menu.get_node("CloseButton")
	close_button.position = Vector2(748, 12)
	close_button.text = "Back"
	close_button.custom_minimum_size = Vector2.ZERO
	close_button.icon = null
	close_button.size = Vector2(146, 36)
	close_button.tooltip_text = "Back to desktop"
	# Game messages (orders, hours saved) would be hidden behind the full screen.
	toast.visible = active and ui.feedback_seconds > 0 and not ui.feedback_label.text.is_empty()
	if toast.visible: toast.text = ui.feedback_label.text
	screen_menu.get_node("ShiftLabel").size.x = 108
	screen_menu.get_node("ShiftStartHour").position.x = 130
	var hour_width := (912.0 - 178) / 2
	screen_menu.get_node("ShiftStartHour").size.x = hour_width
	screen_menu.get_node("ShiftEndHour").position.x = 162 + hour_width
	screen_menu.get_node("ShiftEndHour").size.x = hour_width
	screen_menu.get_node("ShiftToLabel").position.x = 134 + hour_width
	syncing = false

## Shop Manager window in the style of the other PC apps: amber header with the
## title, money, Shop online and Back; tabs under it; content on a white card.
func _style_manager() -> void:
	var title: Label = screen_menu.get_node("TitleLabel")
	title.text = "WAREHOUSE ORDERS" if str(source.get_node("TitleLabel").text).begins_with("WAREHOUSE") else "APNA SHOP MANAGER"
	title.position = Vector2(18, 8)
	title.size = Vector2(400, 34)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	var money: Label = screen_menu.get_node("MoneyLabel")
	money.position = Vector2(400, 18)
	money.size = Vector2(176, 26)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money.add_theme_font_size_override("font_size", 16)
	money.add_theme_color_override("font_color", Color.WHITE)
	var tabs_copy: Control = screen_menu.get_node("ManagementTabs")
	tabs_copy.position = Vector2(16, 70)
	screen_menu.queue_redraw()

func _draw_manager() -> void:
	var size := screen_menu.size
	screen_menu.draw_style_box(_round(Color("fff7ed"), 12), Rect2(Vector2.ZERO, size))
	var header := _round(MANAGER_BRAND, 12)
	screen_menu.draw_style_box(header, Rect2(0, 0, size.x, 60))
	screen_menu.draw_string(screen_menu.get_theme_default_font(), Vector2(20, 52), "Prices, racks and shelves for your shop", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fde68a"))
	var card := _round(Color.WHITE, 12)
	card.border_color = Color("fed7aa")
	card.set_border_width_all(1)
	screen_menu.draw_style_box(card, Rect2(8, 114, size.x - 16, size.y - 122))
	# Orders: a picture of the selected product under the company list.
	var column: Control = screen_menu.get_node("CompanyColumn")
	if source.selected_tab == 0 and column.visible:
		var id: String = Catalog.IDS[source.product_input.selected]
		var picture: Texture2D = load("res://assets/ui/products/%s.png" % id)
		var frame := Rect2(column.position.x, 316, column.size.x, 136)
		screen_menu.draw_style_box(_round(Color("fff7ed"), 10), frame)
		screen_menu.draw_texture_rect(picture, Rect2(frame.position + Vector2((frame.size.x - 124) / 2, 6), Vector2(124, 124)), false)

func open(warehouse_context := false) -> void:
	if active or player._menu_is_open(): return
	previous_camera = get_viewport().get_camera_3d()
	source.modulate = Color(1, 1, 1, 0)
	source.open_menu(warehouse_context)
	active = true
	source.active_terminal = self
	saved_input.clear()
	for pair in pairs:
		saved_input.append([pair[0], pair[0].mouse_filter, pair[0].focus_mode])
		pair[0].mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair[0].focus_mode = Control.FOCUS_NONE
	focus_camera.global_transform = previous_camera.global_transform
	focus_camera.current = true
	var landscape = world.get_node_or_null("Landscape")
	if landscape != null: landscape.set_camera(focus_camera)
	# The shop PC starts on the desktop; the warehouse PC is an orders terminal.
	show_app("manager" if warehouse_context else "home")
	transition = create_tween()
	transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	transition.tween_property(focus_camera, "global_transform", _fit_transform(), 0.3)
	transition.tween_callback(_show_full_screen)
	screen_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sync()

func close() -> void:
	if not active: return
	active = false
	if is_instance_valid(transition): transition.kill()
	for entry in saved_input:
		if is_instance_valid(entry[0]): entry[0].mouse_filter = entry[1]; entry[0].focus_mode = entry[2]
	for pair in pairs:
		if pair[1] is OptionButton: pair[1].get_popup().hide()
	source.active_terminal = null
	source.modulate = Color.WHITE
	source.close_menu()
	if is_instance_valid(previous_camera):
		previous_camera.current = true
		var landscape = world.get_node_or_null("Landscape")
		if landscape != null: landscape.set_camera(previous_camera)
	screen_menu.hide()
	overlay.visible = false
	toast.hide()
	# The monitor in the shop keeps showing the desktop.
	show_home()
	screen_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func screen_point(pixel: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	var normal := screen_mesh.global_basis.z
	var plane := Plane(normal, normal.dot(screen_mesh.global_position))
	var point = plane.intersects_ray(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel))
	if point == null: return Vector2(-1, -1)
	var local: Vector3 = screen_mesh.to_local(point)
	var uv := Vector2(local.x / 0.78 + 0.5, 0.5 - local.y / 0.44)
	return uv * SCREEN if Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv) else Vector2(-1, -1)

func _input(event: InputEvent) -> void:
	if not active: return
	# Right mouse button leaves the PC (like E or Esc).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ESCAPE]: close()
		else:
			var option: OptionButton
			for pair in pairs:
				if pair[1] is OptionButton and pair[1].get_popup().visible: option = pair[1]; break
			if option != null:
				var popup := option.get_popup()
				if event.pressed and event.keycode in [KEY_HOME, KEY_END, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER]:
					var index := popup.get_focused_item()
					if event.keycode == KEY_HOME: index = 0
					elif event.keycode == KEY_END: index = option.item_count - 1
					elif event.keycode == KEY_DOWN: index = mini(index + 1, option.item_count - 1)
					elif event.keycode == KEY_UP: index = maxi(index - 1, 0)
					elif index >= 0 and not option.is_item_disabled(index):
						option.select(index)
						option.item_selected.emit(index)
						popup.hide()
					if index >= 0: popup.set_focused_item(index)
				else: popup.push_input(event, true)
			else: screen_viewport.push_input(event, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouse:
		var point := screen_point(event.position)
		if point.x >= 0:
			var copy = event.duplicate()
			copy.position = point
			copy.global_position = point
			screen_viewport.push_input(copy, true)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active: return
	_sync()
	if overlay.visible and get_viewport().get_visible_rect().size != fitted_size: _fit_overlay()
	widget_seconds -= delta
	if app == "home" and widget_seconds <= 0.0:
		widget_seconds = 0.25
		_refresh_desktop()

func _exit_tree() -> void:
	if active and is_instance_valid(source): source.modulate = Color.WHITE; source.active_terminal = null
	pairs.clear()
	saved_input.clear()
