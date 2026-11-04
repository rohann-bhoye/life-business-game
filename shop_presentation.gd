extends Node

const SURFACE_SHADER = preload("res://assets/materials/shop_surface.gdshader")
const ATLAS = preload("res://assets/materials/shop_surfaces.png")
const Catalog = preload("res://product_catalog.gd")
const Bricks = preload("res://brick_works.gd")
var price_labels: Dictionary = {}
var surfaces: Dictionary = {}

@onready var world = get_parent()
@onready var builder = world.get_node("Neighbourhood")
@onready var ops = world.get_node("ShopOperations")
@onready var business = world.get_node("Shop/ShopArea").business

func surface(tile: Vector2, scale: float) -> ShaderMaterial:
	var key := Vector3(tile.x, tile.y, scale)
	if not surfaces.has(key):
		var material := ShaderMaterial.new()
		material.shader = SURFACE_SHADER
		material.set_shader_parameter("surface_atlas", ATLAS)
		material.set_shader_parameter("atlas_origin", tile)
		material.set_shader_parameter("meters_per_tile", scale)
		if tile == Vector2(0, 0.5): material.set_shader_parameter("detail_strength", 0.3)
		if tile == Vector2(0, 0.5): material.set_shader_parameter("road_surface", true)
		# Glazed shop-floor tiles catch a little sheen from the tube lights.
		if tile == Vector2(0.5, 0):
			material.set_shader_parameter("surface_roughness", 0.5)
			material.set_shader_parameter("surface_specular", 0.45)
		surfaces[key] = material
	return surfaces[key]

func _ready() -> void:
	world.get_node("Road").material_override = surface(Vector2(0, 0.5), 3.0)
	for name in ["NorthPavement", "SouthPavement", "ShopForecourt", "HomePath"]:
		builder.get_node(name).material_override = surface(Vector2(0.5, 0.5), 1.6)
	if not ops.enabled: return
	var shop = world.get_node("Shop")
	var walls := ["BackWall", "DoorLintel"]
	for x in [-3.0, 3.0]: walls.append(("SideWall%s" % x).validate_node_name())
	for x in [-2.0, 2.0]: walls.append(("FrontWall%s" % x).validate_node_name())
	for name in walls:
		shop.get_node(name).material_override = Bricks.brick_material()
	shop.get_node("Floor").material_override = surface(Vector2(0.5, 0), 2.0)
	_exterior(shop)
	_interior(shop)
	_shelves()
	# The look of each business level (shop_style.gd).
	var style := Node3D.new()
	style.set_script(preload("res://shop_style.gd"))
	add_child(style)
	business.changed.connect(_refresh_prices)
	_refresh_prices()
	# The skirting and interior sign above follow an expanded back wall.
	ops.follow_back_wall()

func _label(parent: Node3D, name: String, text: String, point: Vector3, font_size: int, pixel_size: float, color := Color.WHITE) -> Label3D:
	var label := Label3D.new()
	label.name = name
	label.text = text
	label.position = point
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)
	return label

func _exterior(shop: Node3D) -> void:
	builder._box("StoreFascia", shop, Vector3(5.8, 0.82, 0.08), Vector3(0, 1.8, 2.7), Color(0.06, 0.12, 0.15))
	builder._box("FasciaAccent", shop, Vector3(5.8, 0.035, 0.04), Vector3(0, 1.39, 2.75), Color(0.88, 0.3, 0.3))
	_label(shop, "StoreName", "APNA MART", Vector3(0, 1.91, 2.76), 64, 0.007)
	_label(shop, "StoreCategories", "DAILY ESSENTIALS  /  SNACKS  /  HOME CARE", Vector3(0, 1.55, 2.76), 24, 0.003)
	var sign: Label3D = shop.get_node("ShopSign")
	sign.position = Vector3(-2.3, 1.92, 2.78)
	sign.font_size = 24
	sign.pixel_size = 0.003
	# Brick shop front (brick_works.gd): pink-framed glass windows and doorway, a
	# blue goods shutter on the left wall and steel I-beams under the ceiling.
	for x in [-1.03, 1.03]:
		builder._box("EntranceTrim%s" % x, shop, Vector3(0.14, 2.48, 0.12), Vector3(x, -0.18, 2.58), Bricks.FRAME)
	builder._box("EntranceTop", shop, Vector3(2.2, 0.14, 0.12), Vector3(0, 1.03, 2.58), Bricks.FRAME)
	# Clear glass in the real window openings (shop_operations.gd _window_wall).
	for x in [-2.0, 2.0]:
		Bricks.framed_window(shop, "ShopWindow%d" % int(x), Vector3(x, -0.85, 2.5), 0.0, 1.6, 1.7, Bricks.FRAME, 1, Color.TRANSPARENT)
	# On the packing room built onto the left wall (export_world.gd): its outer wall is
	# at world x -9.72, shop-local -6.72.
	Bricks.shutter(shop, "GoodsShutter", Vector3(-6.72, -1.4, -1.0), -PI / 2, 2.2, 2.4)
	Bricks.poster(shop, "SidePoster", Vector3(-6.74, 0.2, 1.3), -PI / 2, Vector2(0.9, 1.1), Color(0.12, 0.36, 0.62), "BETTER\nCHOICES\nEVERYDAY!")
	_cctv(shop, Vector3(-6.74, 2.1, 2.3))
	shop.get_node("RoofTrim").material_override = builder._material(Color(0.8, 0.8, 0.77))
	Bricks.i_beams(shop, "CeilingBeams", -2.94, 2.94, [1.9, -0.4, -4.2, -6.5], 2.41)
	_label(shop, "WindowHours", "OPEN  08:00 - 20:00", Vector3(2, -0.68, 2.57), 22, 0.003)
	_label(shop, "WindowPayments", "CASH / CARD / UPI", Vector3(-2, -0.68, 2.57), 22, 0.003)
	# Back wall: a store-room door and a clock inside; a back door, vent window and
	# downpipe outside (shop_operations.gd follow_back_wall keeps them on the wall).
	var inside := Node3D.new()
	inside.name = "BackWallInside"
	shop.add_child(inside)
	Bricks.door(inside, "StoreRoomDoor", Vector3(2.25, -1.4, 0.0), 0.0, 0.9, 2.0, Color(0.42, 0.5, 0.56), "STORE ROOM")
	Bricks.clock(inside, "WallClock", Vector3(-2.4, 2.0, 0.0), 0.0)
	var outside := Node3D.new()
	outside.name = "BackWallOutside"
	outside.rotation.y = PI
	shop.add_child(outside)
	Bricks.door(outside, "BackDoor", Vector3(-1.0, -1.4, 0.0), 0.0, 0.95, 2.1, Color(0.46, 0.5, 0.54))
	Bricks.vent(outside, "BackVent", Vector3(1.4, 0.9, 0.0), 0.0, 0.8)
	builder._box("BackDoorStep", outside, Vector3(1.3, 0.12, 0.45), Vector3(-1.0, -1.34, 0.22), Color(0.66, 0.66, 0.64))
	builder._box("Downpipe", outside, Vector3(0.1, 3.9, 0.1), Vector3(-2.85, 0.5, 0.07), Bricks.STEEL)

## A white bullet CCTV camera on a wall bracket at a front corner, looking out.
func _cctv(shop: Node3D, at: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "CornerCctv"
	holder.position = at
	holder.rotation.y = -PI / 2
	shop.add_child(holder)
	builder._box("Bracket", holder, Vector3(0.12, 0.12, 0.04), Vector3(0, 0, 0), Color(0.9, 0.9, 0.9))
	var body: MeshInstance3D = builder._box("Body", holder, Vector3(0.11, 0.11, 0.28), Vector3(0.08, -0.06, 0.14), Color(0.94, 0.94, 0.92))
	body.rotation = Vector3(0.35, 0.6, 0)
	builder._box("Lens", body, Vector3(0.07, 0.07, 0.02), Vector3(0, 0, 0.15), Color(0.05, 0.05, 0.06))

func _interior(shop: Node3D) -> void:
	for x in [-2.92, 2.92]:
		builder._box("WallSkirting%s" % x, shop, Vector3(0.03, 0.16, 9.75), Vector3(x, -1.25, -2.5), Color(0.26, 0.32, 0.34))
	# In front of the packing room doorway (shop_operations.gd SIDE_DOOR).
	builder._box("DoorSkirting", shop, Vector3(0.03, 0.16, 2.34 - 1.95), Vector3(-2.92, -1.25, (2.34 + 1.95) / 2.0), Color(0.26, 0.32, 0.34))
	var light = ops.get_node("ShopLight")
	light.light_color = Color(0.93, 0.97, 1.0)
	light.light_energy = 0.8
	for z in [-1.3, -5.2]:
		var fixture = builder._box("CeilingFixture%s" % z, shop, Vector3(1.7, 0.07, 0.24), Vector3(0, 2.32, z), Color(0.94, 0.98, 1))
		var material := builder._material(Color(0.94, 0.98, 1)).duplicate() as StandardMaterial3D
		material.emission_enabled = true
		material.emission = Color(0.9, 0.96, 1)
		material.emission_energy_multiplier = 0.6
		fixture.material_override = material
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp"
		lamp.position = Vector3(0, -0.15, 0)
		lamp.light_color = Color(0.96, 0.97, 1)
		lamp.light_energy = 0.7
		lamp.omni_range = 5.5
		lamp.shadow_enabled = false
		fixture.add_child(lamp)
	_label(shop, "InteriorCategory", "EVERYDAY ESSENTIALS", Vector3(0, 0.3, -7.42), 40, 0.003)
	# Green slogan posters high on the left wall, above the racks.
	Bricks.poster(shop, "SastaPoster", Vector3(-2.93, 1.45, 1.2), PI / 2, Vector2(0.7, 0.85), Color(0.1, 0.36, 0.22), "SASTA\nSAHI\nHAR DIN")
	Bricks.poster(shop, "GoodFoodPoster", Vector3(-2.93, 1.45, -1.4), PI / 2, Vector2(0.7, 0.85), Color(0.1, 0.36, 0.22), "GOOD\nFOOD\nHAPPY\nLIFE")

func _shelves() -> void:
	for product in Catalog.IDS:
		if product != "bottle" and not ops.product_racks.has(product): continue
		var rack = ops.rack if product == "bottle" else ops.product_racks[product]
		price_labels[product] = decorate_rack(rack, product)
		var count: Label3D = ops.rack_label if product == "bottle" else ops.product_labels[product]
		count.position.y = 2.18
		count.font_size = 22
		count.pixel_size = 0.0018

func decorate_rack(rack: Node3D, product: String) -> Label3D:
	for level in range(3):
		builder._box("ShelfPriceRail%d" % level, rack, Vector3(0.04, 0.09, 1.98), Vector3(0.35, 0.20 + level * 0.55, 0), Color(0.9, 0.94, 0.95))
	builder._box("CategoryBoard", rack, Vector3(0.035, 0.25, 1.95), Vector3(0.04, 1.92, 0), Color(0.1, 0.25, 0.29))
	var category := _label(rack, "CategoryName", Catalog.NAMES[product].to_upper(), Vector3(0.07, 1.92, 0), 28, 0.0025)
	category.rotation.y = PI / 2
	builder._box("PriceCard", rack, Vector3(0.015, 0.15, 0.54), Vector3(0.38, 0.23, 0), Color(0.98, 0.98, 0.94))
	var price := _label(rack, "ShelfPrice", "", Vector3(0.4, 0.23, 0), 34, 0.003, Color(0.08, 0.13, 0.15))
	price.rotation.y = PI / 2
	return price

func _refresh_prices() -> void:
	for product in price_labels:
		price_labels[product].text = "%s%d" % [String.chr(8377), business.product_price(product)]
