extends Node3D

# The shop's look for each business level (tablet: Upgrade). Each upgrade gives
# the shop a new name, fascia, floor, wall paint and fittings:
# 1 Apna Mart (kirana): dark fascia, painted walls, patterned floor.
# 2 Apna Super Mart: blue fascia with a lit LED frame, blade sign, ice-cream
#   freezer by the door, light grey tiles, sky-blue walls, LED ceiling panels and
#   hanging offer banners.
# 3 Apna Mega Mart: maroon and gold fascia, stone pillars, pennant bunting, an AC
#   unit, cream marble floor, a lit offer screen and CCTV cameras.
# Everything sits on the walls, the ceiling or outside the door, so the floor rules
# for racks and moved furniture (rack_store.gd) stay the same.

const NAMES := ["APNA MART", "APNA SUPER MART", "APNA MEGA MART"]
const CATEGORIES := ["DAILY ESSENTIALS  /  SNACKS  /  HOME CARE", "SUPER STORE  /  FRESH  /  DAILY NEEDS", "MEGA MART  /  BEST PRICES  /  EVERYTHING"]
const TITLES := ["Kirana", "Super Store", "Mega Mart"]
const FASCIA := [Color(0.06, 0.12, 0.15), Color(0.05, 0.2, 0.45), Color(0.42, 0.06, 0.08)]
const ACCENT := [Color(0.88, 0.3, 0.3), Color(1.0, 0.8, 0.15), Color(0.95, 0.72, 0.22)]
const PAINT := [Color(0.93, 0.74, 0.38), Color(0.7, 0.85, 0.93), Color(0.97, 0.9, 0.74)]
const STRIPE := [Color(0.12, 0.3, 0.26), Color(0.1, 0.3, 0.6), Color(0.5, 0.08, 0.1)]
const GLOW := [Color.WHITE, Color(0.85, 0.95, 1.0), Color(1.0, 0.82, 0.4)]
const SAFFRON := Color(1.0, 0.55, 0.1)
var level := 0
## The shop expansions the look was last built for (the CCTV sits on the back wall).
var expansion := -1
var extras: Node3D
var original_floor: Material
var materials := {}
@onready var world = get_parent().get_parent()
@onready var shop: Node3D = world.get_node("Shop")
@onready var business = world.get_node("Shop/ShopArea").business

func _ready() -> void:
	name = "ShopStyle"
	original_floor = shop.get_node("Floor").material_override
	business.changed.connect(_refresh)
	_refresh.call_deferred()

func _refresh() -> void:
	if business.shop_level != level or business.shop_expansion != expansion: apply(business.shop_level)

func apply(new_level: int) -> void:
	level = clampi(new_level, 1, 3)
	expansion = business.shop_expansion
	var tier := level - 1
	if is_instance_valid(extras):
		remove_child(extras)
		extras.queue_free()
	extras = Node3D.new()
	extras.name = "Level%dLook" % level
	add_child(extras)
	shop.get_node("StoreFascia").material_override = _plain(FASCIA[tier])
	shop.get_node("FasciaAccent").material_override = _plain(ACCENT[tier])
	shop.get_node("StoreName").text = NAMES[tier]
	shop.get_node("StoreCategories").text = CATEGORIES[tier]
	var decor := world.get_node_or_null("ShopOperations/ShopDecor")
	if decor != null:
		for child in decor.find_children("WallPaint*", "MeshInstance3D", true, false): child.material_override = _plain(PAINT[tier])
		for child in decor.find_children("WallStripe*", "MeshInstance3D", true, false): child.material_override = _plain(STRIPE[tier])
	shop.get_node("Floor").material_override = original_floor if level == 1 else _tiles(level)
	var light := world.get_node_or_null("ShopOperations/ShopLight") as OmniLight3D
	if light != null: light.light_energy = [0.8, 0.86, 0.92][tier]
	if level >= 2:
		_led_frame(GLOW[tier])
		_blade_sign(["", "SUPER\nSTORE", "MEGA\nMART"][tier], FASCIA[tier], GLOW[tier])
		_freezer()
		_led_panels()
		for x in [-1.2, -4.8]: _banner(Vector3(x, 3.2, -2.2), ["", "SUPER SAVINGS", "MEGA OFFERS"][tier], ACCENT[tier], FASCIA[tier])
	if level >= 3:
		_pillars()
		_bunting()
		_ac_unit()
		_offer_screen()
		var back: float = world.get_node("ShopOperations").back_z()
		for spot in [Vector3(-5.75, 3.86, 2.25), Vector3(-0.25, 3.86, back + 0.2)]: _cctv(spot)

func _plain(colour: Color, glow := 0.0) -> StandardMaterial3D:
	var key := [colour, glow]
	if not materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.75
		if glow > 0.0:
			material.emission_enabled = true
			material.emission = colour
			material.emission_energy_multiplier = glow
		materials[key] = material
	return materials[key]

## Big floor tiles (0.6 m) with grout lines: light grey, or cream marble.
func _tiles(tier_level: int) -> StandardMaterial3D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var light := Color(0.88, 0.9, 0.92) if tier_level == 2 else Color(0.96, 0.92, 0.85)
	var dark := Color(0.8, 0.83, 0.86) if tier_level == 2 else Color(0.84, 0.76, 0.64)
	var rng := RandomNumberGenerator.new()
	rng.seed = tier_level
	for y in range(64):
		for x in range(64):
			var colour := light if (x / 32 + y / 32) % 2 == 0 else dark
			if tier_level == 3 and absi((x + y * 2) % 37 - 18) < 1: colour = colour.darkened(0.08)
			colour = colour.darkened(rng.randf_range(0.0, 0.025))
			if x % 32 == 0 or y % 32 == 0: colour = Color(0.62, 0.62, 0.6)
			image.set_pixel(x, y, colour)
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / 1.2
	material.roughness = 0.35 if tier_level == 3 else 0.45
	material.metallic_specular = 0.6
	return material

func _part(node_name: String, mesh: Mesh, at: Vector3, material: Material, parent: Node3D = extras) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance, true)
	return instance

func _box(node_name: String, size: Vector3, at: Vector3, material: Material, parent: Node3D = extras) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := _part(node_name, mesh, at, material, parent)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if size.y < 0.05 or size.x < 0.05 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return part

func _text(parent: Node3D, value: String, at: Vector3, font_size: int, colour: Color, yaw := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.rotation.y = yaw
	label.font_size = font_size
	label.pixel_size = 0.004
	label.modulate = colour
	label.outline_size = 0
	parent.add_child(label)
	return label

func _solid(node_name: String, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	extras.add_child(body)

## Lit strips round the fascia (world: shop at x -3, y 1.5).
func _led_frame(glow: Color) -> void:
	var lit := _plain(glow, 1.6)
	for y in [3.71, 2.88]: _box("LedStrip", Vector3(5.8, 0.03, 0.03), Vector3(-3.0, y, 2.76), lit)
	for x in [-5.89, -0.11]: _box("LedStrip", Vector3(0.03, 0.83, 0.03), Vector3(x, 3.3, 2.76), lit)

## A double-sided sign sticking out of the right front corner.
func _blade_sign(value: String, colour: Color, glow: Color) -> void:
	var sign := Node3D.new()
	sign.name = "BladeSign"
	sign.position = Vector3(-0.15, 2.75, 3.1)
	extras.add_child(sign)
	_box("Arm", Vector3(0.05, 0.05, 0.4), Vector3(0, 0.55, -0.15), _plain(Color(0.2, 0.22, 0.24)), sign)
	_box("Panel", Vector3(0.07, 1.05, 0.6), Vector3.ZERO, _plain(colour), sign)
	for z in [-0.31, 0.31]: _box("Edge", Vector3(0.08, 1.07, 0.02), Vector3(0, 0, z), _plain(glow, 1.4), sign)
	for side in [-1, 1]: _text(sign, value, Vector3(0.04 * side, 0, 0), 46, Color.WHITE, PI / 2 * side)

## Ice-cream freezer chest left of the door, with a solid body.
func _freezer() -> void:
	var chest := Node3D.new()
	chest.name = "IceCreamFreezer"
	chest.position = Vector3(-5.3, 0.1, 2.97)
	extras.add_child(chest)
	_box("Body", Vector3(0.95, 0.72, 0.6), Vector3(0, 0.38, 0), _plain(Color(0.95, 0.96, 0.97)), chest)
	_box("Base", Vector3(0.97, 0.06, 0.62), Vector3(0, 0.03, 0), _plain(Color(0.3, 0.32, 0.34)), chest)
	_box("Lid", Vector3(0.95, 0.06, 0.6), Vector3(0, 0.77, 0), _plain(Color(0.2, 0.45, 0.85)), chest)
	_box("Glass", Vector3(0.8, 0.012, 0.46), Vector3(0, 0.805, 0), _plain(Color(0.65, 0.85, 0.95), 0.3), chest)
	_box("Stripe", Vector3(0.96, 0.12, 0.01), Vector3(0, 0.55, 0.302), _plain(Color(0.9, 0.15, 0.2)), chest)
	_text(chest, "ICE CREAM", Vector3(0, 0.55, 0.31), 30, Color.WHITE)
	_text(chest, "Thanda thanda!", Vector3(0, 0.3, 0.305), 22, Color(0.2, 0.45, 0.85))
	_solid("FreezerBody", Vector3(0.97, 0.85, 0.62), Vector3(-5.3, 0.52, 2.97))

## Square LED panels on the ceiling beside the tube lights.
func _led_panels() -> void:
	var lit := _plain(Color(0.95, 0.98, 1.0), 0.9)
	for z in [-1.3, -5.2]:
		for x in [-1.5, -4.5]:
			_box("LedPanel", Vector3(0.6, 0.03, 0.6), Vector3(x, 3.875, z), lit)

## A double-sided banner hanging from the ceiling on two cords.
func _banner(at: Vector3, value: String, colour: Color, text_colour: Color) -> void:
	var banner := Node3D.new()
	banner.name = "CeilingBanner"
	banner.position = at
	extras.add_child(banner, true)
	_box("Cloth", Vector3(0.95, 0.42, 0.015), Vector3.ZERO, _plain(colour), banner)
	for x in [-0.4, 0.4]: _box("Cord", Vector3(0.01, 0.48, 0.01), Vector3(x, 0.45, 0), _plain(Color(0.15, 0.15, 0.15)), banner)
	for side in [0.0, PI]:
		var label := _text(banner, value, Vector3(0, 0, 0.012 if side == 0.0 else -0.012), 30, text_colour, side)
		label.pixel_size = 0.0035

## Stone-clad pillars at both front corners.
func _pillars() -> void:
	for x in [-5.93, -0.07]:
		_box("StonePillar", Vector3(0.24, 3.45, 0.16), Vector3(x, 1.75, 2.62), _plain(Color(0.74, 0.66, 0.55)))
		_box("PillarCap", Vector3(0.3, 0.08, 0.2), Vector3(x, 3.5, 2.62), _plain(Color(0.95, 0.72, 0.22)))

## Saffron, white and green pennants along the top of the fascia.
func _bunting() -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.2, 0.24, 0.01)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = 20
	for index in range(20):
		multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.FORWARD, PI), Vector3(-5.75 + index * 0.29, 3.64, 2.83)))
		multimesh.set_instance_color(index, [SAFFRON, Color.WHITE, Color(0.1, 0.55, 0.2)][index % 3])
	var flags := MultiMeshInstance3D.new()
	flags.name = "Bunting"
	flags.multimesh = multimesh
	flags.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extras.add_child(flags)
	_box("BuntingCord", Vector3(5.8, 0.012, 0.012), Vector3(-3.0, 3.76, 2.83), _plain(Color(0.2, 0.2, 0.2)))

## Outdoor AC unit on the left wall.
func _ac_unit() -> void:
	var unit := Node3D.new()
	unit.name = "AcUnit"
	unit.position = Vector3(-6.22, 2.5, 0.6)
	extras.add_child(unit)
	_box("Case", Vector3(0.3, 0.55, 0.8), Vector3.ZERO, _plain(Color(0.86, 0.87, 0.86)), unit)
	var grill := CylinderMesh.new()
	grill.top_radius = 0.2
	grill.bottom_radius = 0.2
	grill.height = 0.02
	var fan := _part("Grill", grill, Vector3(-0.155, 0, 0.12), _plain(Color(0.2, 0.22, 0.24)), unit)
	fan.rotation.z = PI / 2
	for z in [-0.25, 0.25]: _box("Bracket", Vector3(0.34, 0.03, 0.03), Vector3(0.0, -0.3, z), _plain(Color(0.4, 0.4, 0.4)), unit)

## A lit offer screen on the left wall above the racks.
func _offer_screen() -> void:
	var screen := Node3D.new()
	screen.name = "OfferScreen"
	screen.position = Vector3(-5.9, 2.85, -3.3)
	screen.rotation.y = PI / 2
	extras.add_child(screen)
	_box("Bezel", Vector3(1.4, 0.82, 0.05), Vector3.ZERO, _plain(Color(0.05, 0.05, 0.06)), screen)
	_box("Screen", Vector3(1.3, 0.72, 0.01), Vector3(0, 0, 0.03), _plain(Color(0.08, 0.2, 0.45), 0.8), screen)
	var label := _text(screen, "APNA MEGA MART\nFresh  -  Sasta  -  Fast", Vector3(0, 0.02, 0.04), 34, Color(1, 0.9, 0.5))
	label.pixel_size = 0.0028

func _cctv(at: Vector3) -> void:
	var dome := SphereMesh.new()
	dome.radius = 0.08
	dome.height = 0.08
	dome.is_hemisphere = true
	var camera := _part("Cctv", dome, at, _plain(Color(0.12, 0.12, 0.14)))
	camera.rotation.x = PI
	_box("CctvMount", Vector3(0.14, 0.02, 0.14), at + Vector3(0, 0.02, 0), _plain(Color(0.9, 0.9, 0.9)))
