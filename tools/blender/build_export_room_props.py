# Builds the extra APNA EXPORT packing-room props, sharing one printed atlas
# (export_room_print.png):
#   pallet_stack.glb     wooden pallet with three layers of printed kraft cartons (floor centre)
#   hand_trolley.glb     two-wheel sack truck with a steel frame and a loaded carton
#   floor_scale.glb      platform scale with a lit digital display on a post
#   extinguisher.glb     red fire extinguisher on a wall bracket (back at y = 0, hangs on a wall)
#   wall_shelf.glb       two wall shelves with cartons, tape rolls and a label gun
#   export_lamp.glb      industrial caged wall lamp for the street front
# Blender axes: x as in the game, -y = the game's +z (front), z up.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_export_room_props.py -- <project dir> [--render out.png]
# Writes assets/props/export/*.glb, export_room_print.png and source/export_room_props.blend.
import bpy, os, sys, math
from mathutils import Vector
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

ATLAS = 1024
SWATCHES = {
	"kraft": "CFA56B", "kraft_dark": "B08850", "tape": "E8D5A2", "wood": "A8773F", "wood_dark": "7A5128",
	"steel": "3A3F45", "steel_light": "C5CAD0", "red": "C7352D", "red_dark": "8E1F1A", "black": "1E1F22",
	"rubber": "17181A", "screen": "37E08A", "screen_dark": "0E2A1C", "white": "F4F3EE", "yellow": "F4C443",
	"blue": "1F6FD1", "lamp_glass": "FFF2C4",
}
CARTON_FRONT = (0, 0, 256, 256)
CARTON_SIDE = (272, 0, 256, 256)
CARTON_TOP = (544, 0, 256, 256)
SCALE_TOP = (816, 0, 160, 160)

def draw_print(s):
	# Carton front: kraft with a vertical tape strip, shipping label and handling marks.
	x, y, w, h = CARTON_FRONT
	s.rect(x, y, w, h, "CFA56B", 0.0)
	s.rect(x, y, w, 18, "B08850", 0.01)
	s.rect(x + w / 2 - 20, y, 40, h, "E8D5A2", 0.02)
	s.rect(x + 12, y + 70, 118, 84, "F4F3EE", 0.03)
	s.rect(x + 12, y + 70, 118, 20, "C7352D", 0.04)
	s.text("AIR CARGO", x + 71, y + 80, 11, "F4F3EE", 0.05, "arialbd.ttf", 100)
	s.text("APNA EXPORT", x + 71, y + 110, 12, "1E1F22", 0.05, "ariblk.ttf", 100)
	s.rects([(x + 20 + k * 6, y + 128, 2 + k % 3, 18) for k in range(15)], "1E1F22", 0.05)
	s.text("FRAGILE", x + 192, y + 100, 15, "C7352D", 0.05, "ariblk.ttf", 70)
	s.polygon([(x + 192, y + 150), (x + 214, y + 190), (x + 202, y + 190), (x + 202, y + 218), (x + 182, y + 218), (x + 182, y + 190), (x + 170, y + 190)], "1E1F22", 0.05)
	# Carton side: tape and a small stamp.
	x, y, w, h = CARTON_SIDE
	s.rect(x, y, w, h, "C29A5F", 0.0)
	s.rect(x, y, w, 18, "B08850", 0.01)
	s.rect(x + w / 2 - 20, y, 40, h, "E8D5A2", 0.02)
	s.text("THIS WAY UP", x + 64, y + 200, 12, "5A3E1C", 0.05, "arialbd.ttf", 100)
	s.text("MADE IN INDIA", x + 190, y + 150, 11, "5A3E1C", 0.05, "arialbd.ttf", 96)
	# Carton top: tape cross.
	x, y, w, h = CARTON_TOP
	s.rect(x, y, w, h, "D4AB70", 0.0)
	s.rect(x + w / 2 - 20, y, 40, h, "E8D5A2", 0.02)
	s.rect(x, y + h / 2 - 1, w, 2, "A9803F", 0.02)
	# Scale top: a rubber mat with a yellow safety border.
	x, y, w, h = SCALE_TOP
	s.rect(x, y, w, h, "17181A", 0.0)
	s.rect(x + 6, y + 6, w - 12, 10, "F4C443", 0.01)
	s.rect(x + 6, y + h - 16, w - 12, 10, "F4C443", 0.01)
	s.rect(x + 6, y + 6, 10, h - 12, "F4C443", 0.01)
	s.rect(x + w - 16, y + 6, 10, h - 12, "F4C443", 0.01)
	s.rects([(x + 24 + k * 14, y + 30, 6, h - 60) for k in range(8)], "232427", 0.02)

def carton(b, centre, size, rot_z=0.0):
	b.box(centre, size, {"-y": CARTON_FRONT, "+y": CARTON_FRONT, "+x": CARTON_SIDE, "-x": CARTON_SIDE, "+z": CARTON_TOP, "-z": "kraft_dark"}, rot_z)

def rotate_x_axis(b, start):
	"""Turn a body built standing (axis z) so its axis runs along x: a wheel's axle."""
	for i in range(start, len(b.verts)):
		v = b.verts[i]
		b.verts[i] = Vector((v.z, v.y, -v.x))

def revolve(b, base, profile, bands, seg=12):
	"""Round body from (radius, height) rings (all radius > 0), closed with flat caps."""
	base = Vector(base)
	rings = [[b.vert(base + Vector((r * math.cos(2 * math.pi * k / seg), r * math.sin(2 * math.pi * k / seg), z))) for k in range(seg)] for r, z in profile]
	for k in range(len(rings) - 1): b.quad_strip(rings[k], rings[k + 1], bands[k])
	b.swatch_face(rings[0][::-1], bands[0])
	b.swatch_face(rings[-1], bands[-1])

def disc(b, centre, radius, thick, swatch, seg=14):
	"""A wheel or lid: a short cylinder with its axis along x, centred on `centre`."""
	start = len(b.verts)
	revolve(b, (0, 0, 0), [(radius, 0.0), (radius, thick)], [swatch], seg)
	for i in range(start, len(b.verts)):
		v = b.verts[i]
		b.verts[i] = Vector((v.z - thick / 2, v.y, -v.x)) + Vector(centre)


def make_pallet_stack(mat):
	b = Builder(SHEET)
	for y in (-0.26, 0.0, 0.26):  # bottom boards and the blocks between
		b.box((0, y, 0.01), (0.8, 0.1, 0.02), "wood")
	for x in (-0.34, 0.0, 0.34):
		for y in (-0.26, 0.0, 0.26): b.box((x, y, 0.06), (0.1, 0.1, 0.08), "wood_dark")
	for k in range(5): b.box((-0.32 + k * 0.16, 0, 0.11), (0.1, 0.62, 0.02), "wood")
	h = 0.28
	for layer in range(3):
		z = 0.12 + h / 2 + layer * h
		if layer < 2:
			for ix in (-0.19, 0.19):
				for iy in (-0.15, 0.15): carton(b, (ix, iy, z), (0.37, 0.29, h - 0.004), (layer * 2.0) * (1 if ix > 0 else -1))
		else:
			carton(b, (-0.19, 0.0, z), (0.37, 0.5, h - 0.004), 1.0)
			carton(b, (0.19, 0.0, z), (0.37, 0.5, h - 0.004), -1.5)
	# Stretch wrap shine: two thin translucent-looking bands.
	return b.to_object("PalletStack", mat, bevel=0.004)

def make_hand_trolley(mat):
	b = Builder(SHEET)
	for x in (-0.17, 0.17):
		b.box((x, 0.1, 0.55), (0.03, 0.03, 1.1), "steel_light")
	for z in (0.35, 0.65, 0.95): b.box((0, 0.1, z), (0.36, 0.025, 0.025), "steel_light")
	b.box((0, 0.1, 1.1), (0.4, 0.035, 0.035), "steel")
	b.box((0, -0.0, 0.04), (0.38, 0.28, 0.015), "steel")  # toe plate
	b.box((0, 0.14, 0.08), (0.04, 0.04, 0.04), "steel")
	for x in (-0.22, 0.22): disc(b, (x, 0.18, 0.1), 0.1, 0.04, "rubber")
	b.box((0, 0.18, 0.1), (0.46, 0.02, 0.02), "steel")
	carton(b, (0, 0.0, 0.2), (0.34, 0.26, 0.26))
	return b.to_object("HandTrolley", mat, bevel=0.003)

def make_floor_scale(mat):
	b = Builder(SHEET)
	b.box((0, 0, 0.04), (0.6, 0.6, 0.06), {"+z": SCALE_TOP, "rest": "steel"})
	for x in (-0.26, 0.26):
		for y in (-0.26, 0.26): b.box((x, y, 0.008), (0.06, 0.06, 0.016), "rubber")
	b.box((0.26, 0.31, 0.5), (0.04, 0.04, 0.95), "steel")  # post at the back right
	b.box((0.26, 0.28, 0.98), (0.3, 0.1, 0.18), "black")
	b.box((0.26, 0.226, 0.98), (0.26, 0.012, 0.13), "screen")
	b.box((0.26, 0.22, 0.98), (0.02, 0.01, 0.1), "screen_dark")
	return b.to_object("FloorScale", mat, bevel=0.003)

def make_extinguisher(mat):
	b = Builder(SHEET)
	b.box((0, 0.0, 0.34), (0.2, 0.012, 0.5), "steel")  # wall plate at the back
	revolve(b, (0, -0.08, 0.06), [(0.075, 0.0), (0.085, 0.04), (0.085, 0.33), (0.07, 0.4), (0.03, 0.43)],
		["red_dark", "red", "red", "red"], 14)
	b.box((0, -0.08, 0.55), (0.04, 0.05, 0.05), "black")
	b.box((0.04, -0.08, 0.57), (0.1, 0.02, 0.02), "black")
	b.box((0, -0.08, 0.3), (0.12, 0.002, 0.14), "white")
	b.box((0, -0.14, 0.4), (0.24, 0.012, 0.03), "steel")
	return b.to_object("Extinguisher", mat, bevel=0.002)

def make_wall_shelf(mat):
	b = Builder(SHEET)
	for z in (0.0, 0.5):
		b.box((0, -0.14, z), (1.4, 0.3, 0.03), "wood")
		for x in (-0.55, 0.55): b.box((x, -0.02, z - 0.1), (0.04, 0.04, 0.2), "steel")
	carton(b, (-0.42, -0.14, 0.2), (0.34, 0.26, 0.26))
	carton(b, (-0.06, -0.14, 0.17), (0.3, 0.24, 0.2), 4)
	b.box((0.4, -0.14, 0.05), (0.4, 0.22, 0.08), "tape")  # flat cartons stack
	b.box((0.4, -0.14, 0.12), (0.4, 0.22, 0.06), "kraft")
	for x in (-0.5, -0.28, -0.06):
		revolve(b, (x, -0.14, 0.515), [(0.05, 0.0), (0.05, 0.05)], ["tape"], 12)
	revolve(b, (0.3, -0.14, 0.515), [(0.07, 0.0), (0.07, 0.12)], ["white"], 12)
	b.box((0.1, -0.14, 0.545), (0.14, 0.05, 0.05), "red")
	return b.to_object("WallShelf", mat, bevel=0.003)

def make_lamp(mat):
	b = Builder(SHEET)
	b.box((0, 0.0, 0.0), (0.16, 0.02, 0.2), "steel")
	b.box((0, -0.08, -0.02), (0.06, 0.1, 0.05), "steel")
	revolve(b, (0, -0.16, -0.14), [(0.07, 0.0), (0.07, 0.16), (0.04, 0.2)], ["lamp_glass", "lamp_glass"], 12)
	for k in range(5): b.box((0, -0.16, -0.14 + 0.03 + k * 0.03), (0.15, 0.15, 0.008), "steel")
	return b.to_object("ExportLamp", mat, bevel=0)

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "export")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
clear_scene()
SHEET = Sheet(ATLAS, SWATCHES, 300)
draw_print(SHEET)
png = os.path.join(out_dir, "export_room_print.png")
SHEET.render(png)
mat = material("ExportRoom", png, roughness=0.6)
BUILDERS = {"pallet_stack": make_pallet_stack, "hand_trolley": make_hand_trolley, "floor_scale": make_floor_scale,
	"extinguisher": make_extinguisher, "wall_shelf": make_wall_shelf, "export_lamp": make_lamp}
objects = []
for pid, fn in BUILDERS.items():
	ob = fn(mat)
	export_glb(ob, os.path.join(out_dir, pid + ".glb"))
	objects.append(ob)
for i, ob in enumerate(objects): ob.location.x = (i - len(objects) / 2 + 0.5) * 1.3
if render: preview(render, (0, -4.6, 1.5), (0, 0, 0.5), size=(1600, 560), lens=50)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "export_room_props.blend"))
print("SAVED")
