extends Node

const SURFACE_SHADER = preload("res://assets/materials/shop_surface.gdshader")
const ATLAS = preload("res://assets/materials/shop_surfaces.png")
const Catalog = preload("res://product_catalog.gd")
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
		shop.get_node(name).material_override = surface(Vector2.ZERO, 2.5)
	shop.get_node("Floor").material_override = surface(Vector2(0.5, 0), 2.0)
	_exterior(shop)
	_interior(shop)
	_shelves()
	business.changed.connect(_refresh_prices)
	_refresh_prices()

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
	for x in [-1.03, 1.03]:
		builder._box("EntranceTrim%s" % x, shop, Vector3(0.06, 2.3, 0.08), Vector3(x, -0.25, 2.57), Color(0.15, 0.19, 0.2))
	for x in [-2.0, 2.0]:
		builder._box("WindowSill%s" % x, shop, Vector3(1.64, 0.08, 0.13), Vector3(x, -0.78, 2.61), Color(0.16, 0.25, 0.28))
	for x in [-2.0, 2.0]:
		builder._box("WindowDecal%s" % x, shop, Vector3(1.12, 0.45, 0.008), Vector3(x, -0.05, 2.636), Color(0.08, 0.17, 0.2))
	_label(shop, "WindowHours", "OPEN\n08:00 - 20:00", Vector3(2, -0.05, 2.65), 28, 0.0035)
	_label(shop, "WindowPayments", "CASH  /  CARD\nUPI ACCEPTED", Vector3(-2, -0.05, 2.65), 24, 0.0035)

func _interior(shop: Node3D) -> void:
	for x in [-2.92, 2.92]:
		builder._box("WallSkirting%s" % x, shop, Vector3(0.03, 0.16, 9.75), Vector3(x, -1.25, -2.5), Color(0.26, 0.32, 0.34))
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
	_label(shop, "InteriorCategory", "EVERYDAY ESSENTIALS", Vector3(0, 1.5, -7.42), 40, 0.003)

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
