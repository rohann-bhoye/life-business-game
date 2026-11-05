# Builds the side wings' fittings (shop_operations.gd _build_wing places them):
#   cooler.glb   a two-door glass cooler: white cabinet, steel door frames with handles, a lit
#                header, four wire shelves of drink bottles and milk and curd packs behind
#                the glass. 1.5 x 0.7 x 2.05 m, origin at the floor centre, doors toward -Y
#                in Blender (+Z in Godot).
#   freezer.glb  a chest freezer island: white body with a blue band, steel bumper rail,
#                sliding glass lids over rows of ice-cream tubs and bars. 1.8 x 0.85 x 0.9 m.
#   trolleys.glb three nested shopping trolleys (steel wire baskets, red handles, wheels) in a
#                corral rail. 2.0 x 0.75 x 1.05 m.
# Writes assets/props/wing/*.glb and source/wing_props.blend.
# Run: blender --background --factory-startup --python tools/blender/build_wing_props.py -- <project dir>
import bpy, os, sys, math, random
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
root = args[0]
out_dir = os.path.join(root, "assets/props/wing")
os.makedirs(os.path.join(out_dir, "source"), exist_ok=True)
random.seed(2026)

for o in list(bpy.data.objects): bpy.data.objects.remove(o)
for block in (bpy.data.meshes, bpy.data.materials):
	for item in list(block): block.remove(item)

def lin(hexcol):
	c = [int(hexcol[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]

def mat(name, hexcol, rough=0.55, metal=0.0, alpha=1.0, emit=0.0):
	m = bpy.data.materials.new(name)
	b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	b.inputs["Base Color"].default_value = (*lin(hexcol), 1)
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metal
	if alpha < 1.0:
		b.inputs["Alpha"].default_value = alpha
		for attr, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
			try: setattr(m, attr, value)
			except (AttributeError, TypeError): pass
	if emit > 0.0:
		b.inputs["Emission Color"].default_value = (*lin(hexcol), 1)
		b.inputs["Emission Strength"].default_value = emit
	return m

M = {
	"white": mat("CabinetWhite", "F2F4F3", 0.45),
	"steel": mat("Steel", "B9C0C4", 0.3, 0.85),
	"dark": mat("DarkTrim", "2B3036", 0.6),
	"glass": mat("Glass", "CFE8F0", 0.05, 0.0, 0.28),
	"light": mat("HeaderLight", "EAF6FF", 0.3, 0.0, 1.0, 1.1),
	"blue": mat("FreezerBlue", "1F5FA8", 0.5),
	"frost": mat("Frost", "DDEFF7", 0.8),
	"red": mat("HandleRed", "D93A2B", 0.5),
	"rubber": mat("Rubber", "1C1D20", 0.8),
	"wire": mat("Wire", "C7CDD1", 0.35, 0.8),
	"yellow": mat("RailYellow", "F2B705", 0.5),
}
PACK = [mat("Pack%d" % i, c, 0.5) for i, c in enumerate(["E84A8A", "1FB5AD", "F6C445", "3CB44B", "8E5BD8", "F28C28", "FFFFFF", "D93A2B"])]
parts = []

def box(size, loc, m, rot_z=0.0):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
	o = bpy.context.object
	o.scale = size
	o.rotation_euler[2] = rot_z
	bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
	o.data.materials.append(m)
	parts.append(o)
	return o

def cylinder(radius, depth, loc, m, axis="Z", vertices=12):
	bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, vertices=vertices)
	o = bpy.context.object
	if axis == "X": o.rotation_euler[1] = math.pi / 2
	elif axis == "Y": o.rotation_euler[0] = math.pi / 2
	bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
	o.data.materials.append(m)
	parts.append(o)
	return o

def finish(name):
	global parts
	for o in bpy.context.selected_objects: o.select_set(False)
	for o in parts: o.select_set(True)
	bpy.context.view_layer.objects.active = parts[0]
	bpy.ops.object.join()
	ob = bpy.context.object
	ob.name = name
	parts = []
	return ob

def export(ob, name):
	for o in bpy.context.selected_objects: o.select_set(False)
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), export_format="GLB", use_selection=True, export_cameras=False, export_lights=False, export_animations=False)
	print("EXPORTED %s %d faces" % (name, len(ob.data.polygons)))

# ---------- the two-door cooler (doors toward -Y)
def cooler():
	W, D, H = 1.5, 0.7, 2.05
	box((W, D, 0.12), (0, 0, 0.06), M["dark"])                       # plinth
	box((W, D - 0.04, 0.05), (0, 0.02, 0.145), M["white"])           # floor of the cabinet
	box((0.05, D, H - 0.12), (-W / 2 + 0.025, 0, 0.12 + (H - 0.12) / 2), M["white"])  # sides
	box((0.05, D, H - 0.12), (W / 2 - 0.025, 0, 0.12 + (H - 0.12) / 2), M["white"])
	box((W, 0.05, H - 0.12), (0, D / 2 - 0.025, 0.12 + (H - 0.12) / 2), M["white"])   # back
	box((W, D, 0.06), (0, 0, H - 0.03), M["white"])                  # top
	box((W - 0.04, 0.03, 0.22), (0, -D / 2 + 0.015, H - 0.17), M["light"])  # lit header
	# Four shelves with stock: bottles on the top two, milk and curd packs below.
	for s, z in enumerate((0.32, 0.72, 1.12, 1.52)):
		box((W - 0.1, D - 0.12, 0.015), (0, 0.02, z), M["wire"])
		x = -W / 2 + 0.12
		while x < W / 2 - 0.1:
			for row in range(2):
				y = -0.12 + row * 0.2
				m = PACK[(int(x * 13) + s * 3 + row) % len(PACK)]
				if s >= 2:
					cylinder(0.035, 0.26, (x, y, z + 0.14), m, vertices=10)
					cylinder(0.014, 0.04, (x, y, z + 0.29), M["dark"], vertices=8)
				else:
					box((0.07, 0.07, 0.16 if s == 1 else 0.11), (x, y, z + (0.09 if s == 1 else 0.065)), m)
			x += 0.11
	# Two glass doors: steel frame, glass, a long handle each.
	for side in (-1, 1):
		cx = side * W / 4
		box((W / 2 - 0.03, 0.03, 0.045), (cx, -D / 2 - 0.015, 0.2), M["steel"])
		box((W / 2 - 0.03, 0.03, 0.045), (cx, -D / 2 - 0.015, H - 0.31), M["steel"])
		for edge in (-1, 1): box((0.04, 0.03, H - 0.52), (cx + edge * (W / 4 - 0.035), -D / 2 - 0.015, (H - 0.1) / 2), M["steel"])
		box((W / 2 - 0.1, 0.012, H - 0.56), (cx, -D / 2 - 0.012, (H - 0.1) / 2), M["glass"])
		box((0.025, 0.04, 0.6), (side * 0.06, -D / 2 - 0.05, 1.1), M["steel"])
	return finish("Cooler")

# ---------- the chest freezer island (long side along X)
def freezer():
	W, D, H = 1.8, 0.85, 0.9
	box((W, D, 0.08), (0, 0, 0.04), M["dark"])
	box((W, D, H - 0.18), (0, 0, 0.08 + (H - 0.18) / 2), M["white"])
	box((W + 0.01, D + 0.01, 0.12), (0, 0, 0.45), M["blue"])             # blue band
	for side in (-1, 1): box((W + 0.04, 0.03, 0.05), (0, side * (D / 2 + 0.02), 0.32), M["steel"])  # bumper
	box((W, D, 0.1), (0, 0, H - 0.05), M["white"])                       # top rim
	box((W - 0.12, D - 0.12, 0.02), (0, 0, H - 0.12), M["frost"])        # frosted floor inside
	# Rows of tubs and bars under the glass.
	for i in range(14):
		x = -W / 2 + 0.12 + i * 0.12
		for j in range(5):
			y = -D / 2 + 0.13 + j * 0.14
			m = PACK[(i * 3 + j) % len(PACK)]
			if j % 2 == 0: cylinder(0.045, 0.08, (x, y, H - 0.07), m, vertices=10)
			else: box((0.1, 0.06, 0.04), (x, y, H - 0.09), m)
	# Two sliding glass lids, one a little higher, with a steel middle bar.
	box((W / 2 - 0.02, D - 0.06, 0.012), (-W / 4, 0, H + 0.006), M["glass"])
	box((W / 2 - 0.02, D - 0.06, 0.012), (W / 4 - 0.05, 0, H + 0.02), M["glass"])
	box((0.04, D - 0.04, 0.03), (0, 0, H + 0.01), M["steel"])
	return finish("Freezer")

# ---------- three nested trolleys in a corral rail (pushing toward -X)
def trolley(x):
	L, Wd, top = 0.8, 0.52, 0.95
	# Wire basket: frame bars and sparse wires, wider at the back.
	for z in (0.55, top):
		box((L, 0.02, 0.02), (x, -Wd / 2, z), M["wire"])
		box((L, 0.02, 0.02), (x, Wd / 2, z), M["wire"])
		box((0.02, Wd, 0.02), (x - L / 2, 0, z), M["wire"])
		box((0.02, Wd, 0.02), (x + L / 2, 0, z), M["wire"])
	for k in range(1, 6):
		box((0.012, 0.012, top - 0.55), (x - L / 2 + k * L / 6, -Wd / 2, (top + 0.55) / 2), M["wire"])
		box((0.012, 0.012, top - 0.55), (x - L / 2 + k * L / 6, Wd / 2, (top + 0.55) / 2), M["wire"])
	for k in range(1, 4): box((0.012, Wd, 0.012), (x - L / 2 + k * L / 4, 0, 0.56), M["wire"])
	# Chassis, legs, wheels and the red handle at the back.
	box((L - 0.1, 0.04, 0.03), (x, -0.16, 0.14), M["steel"])
	box((L - 0.1, 0.04, 0.03), (x, 0.16, 0.14), M["steel"])
	for sx in (-1, 1):
		for sy in (-1, 1):
			box((0.03, 0.03, 0.42), (x + sx * (L / 2 - 0.06), sy * 0.18, 0.34), M["steel"])
			cylinder(0.05, 0.035, (x + sx * (L / 2 - 0.06), sy * 0.18, 0.05), M["rubber"], axis="Y", vertices=12)
	box((0.04, Wd + 0.06, 0.04), (x + L / 2 + 0.06, 0, top + 0.06), M["red"])
	for sy in (-1, 1): box((0.03, 0.03, 0.12), (x + L / 2 + 0.04, sy * (Wd / 2), top + 0.02), M["steel"])

def trolleys():
	for k in range(3): trolley(-0.45 + k * 0.32)
	# Corral: two low rails on posts along the line.
	for sy in (-1, 1):
		box((2.0, 0.04, 0.04), (0.0, sy * 0.36, 0.75), M["yellow"])
		for px in (-0.95, 0.0, 0.95): box((0.05, 0.05, 0.75), (px, sy * 0.36, 0.375), M["yellow"])
	box((2.0, 0.76, 0.02), (0.0, 0.0, 0.01), M["dark"])
	return finish("Trolleys")

objects = {"cooler": cooler(), "freezer": freezer(), "trolleys": trolleys()}
# Lay them out side by side in the .blend so they can be looked at together.
objects["freezer"].location = (2.4, 0, 0)
objects["trolleys"].location = (5.0, 0, 0)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "source/wing_props.blend"))
for name, ob in objects.items():
	saved = ob.location.copy()
	ob.location = (0, 0, 0)
	export(ob, name)
	ob.location = saved
print("DONE wing props")
