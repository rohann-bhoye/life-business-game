# Builds the weapons of Gufa Darwaza and the weapon table in front of the cave:
#   weapon_table.glb  a wooden table with a red cloth runner, a HATHIYAR board and a
#                     small rack behind (the weapons themselves are separate models)
#   lathi.glb         bamboo stick with dark bands
#   talwar.glb        curved steel sword with a round guard and a wrapped hilt
#   gada.glb          the hero's mace: a spiked iron head on a golden-banded shaft
# Weapons point along +Z (Godot +Y), the grip near the origin. The table faces -Y here
# (+Z in Godot), its top at 0.95 m, origin at the middle of the floor edge.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_weapons.py -- <project dir> [--render out.png]
# Writes assets/props/dungeon/weapons/*.glb, weapons_print.png and source/weapons.blend.
import bpy, os, sys, math
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

SWATCHES = {
	"bamboo": "C79A4A", "bamboo_dark": "5A3A1A", "steel": "C9D2DA", "steel_dark": "8E9AA6", "gold": "E8B84A",
	"gold_dark": "B8862A", "leather": "6B3A22", "iron": "4A4F57", "iron_light": "6E757F", "wood": "8A5A32",
	"wood_dark": "5E3A1C", "cloth": "B8262B", "cloth_trim": "E8B84A", "gem": "D6336C", "board": "2B1D14",
}
BOARD = (16, 16, 400, 90)

def draw_print(s):
	x, y, w, h = BOARD
	s.rect(x, y, w, h, "E8B84A")
	s.rect(x + 6, y + 6, w - 12, h - 12, "2B1D14", 0.01)
	s.text("HATHIYAR", x + w / 2, y + 40, 40, "F2D27A", 0.02, "ariblk.ttf", w - 40)
	s.text("Take one - E", x + w / 2, y + 72, 18, "FFFFFF", 0.02, "arialbd.ttf", w - 60)

def lathi(mat):
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(0.03, -0.18), (0.032, 0.0), (0.028, 0.5), (0.025, 0.8)], ["bamboo", "bamboo", "bamboo"], 8)
	for z in (-0.1, 0.25, 0.55): b.lathe((0, 0, 0), [(0.037, z), (0.037, z + 0.03)], ["bamboo_dark"], 8)
	return b.to_object("Lathi", mat)

def talwar(mat):
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(0.026, -0.16), (0.03, -0.1), (0.03, 0.0)], ["leather", "leather"], 8)
	b.lathe((0, 0, 0), [(0.045, -0.2), (0.05, -0.17)], ["gold"], 8)
	b.lathe((0, 0, 0), [(0.085, 0.0), (0.085, 0.025)], ["gold_dark"], 14)
	b.box((0, 0, 0.012), (0.2, 0.025, 0.025), "gold")
	# The blade: ten short pieces curving to one side, tapering to a point.
	x, z, angle = 0.0, 0.03, 0.0
	for k in range(10):
		w = 0.065 * (1.0 - k * 0.06)
		length = 0.095
		angle += 0.035
		cx, cz = x + math.sin(angle) * length / 2, z + math.cos(angle) * length / 2
		b.box((cx, 0, cz), (0.014, w, length * 1.6), "steel", rot_z=0)
		b.box((cx + 0.007, 0, cz), (0.006, w * 0.9, length * 1.6), "steel_dark")
		x += math.sin(angle) * length
		z += math.cos(angle) * length
	return b.to_object("Talwar", mat)

def gada(mat):
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(0.04, -0.2), (0.042, 0.0), (0.04, 0.6)], ["wood", "wood"], 8)
	for z in (-0.12, 0.2, 0.45): b.lathe((0, 0, 0), [(0.05, z), (0.05, z + 0.04)], ["gold"], 8)
	b.lathe((0, 0, 0), [(0.06, 0.6), (0.17, 0.66), (0.22, 0.8), (0.17, 0.95), (0.05, 1.0), (0.02, 1.02)], ["iron", "iron_light", "iron_light", "iron", "iron"], 12)
	for k in range(8):
		a = 2 * math.pi * k / 8
		b.lathe((0.2 * math.cos(a), 0.2 * math.sin(a), 0), [(0.045, 0.78), (0.015, 0.78)], ["gold_dark"], 5)
	for z in (0.7, 0.88):
		for k in range(6):
			a = 2 * math.pi * (k + 0.5) / 6
			b.lathe((0.19 * math.cos(a), 0.19 * math.sin(a), 0), [(0.035, z), (0.01, z)], ["gold_dark"], 5)
	b.lathe((0, 0, 0), [(0.03, 1.0), (0.015, 1.12)], ["gold"], 6)
	return b.to_object("Gada", mat)

def table(mat):
	b = Builder(SHEET)
	top = 0.95
	b.box((0, 0.55, top - 0.04), (2.9, 1.15, 0.08), "wood")
	b.box((0, 0.55, top - 0.1), (2.7, 0.95, 0.06), "wood_dark")
	for x in (-1.25, 1.25):
		for y in (0.2, 0.9): b.box((x, y, (top - 0.1) / 2), (0.12, 0.12, top - 0.1), "wood_dark")
	# Stretchers between the legs, and a slab under the whole table so it stands flat on the ground.
	for y in (0.2, 0.9): b.box((0, y, 0.25), (2.4, 0.06, 0.06), "wood_dark")
	for x in (-1.25, 1.25): b.box((x, 0.55, 0.25), (0.06, 0.7, 0.06), "wood_dark")
	b.box((0, 0.55, -0.06), (3.3, 1.5, 0.12), "iron_light")
	b.box((0, 0.55, top + 0.003), (2.6, 0.72, 0.006), "cloth")
	for y in (0.2, 0.9): b.box((0, y, top + 0.004), (2.6, 0.03, 0.006), "cloth_trim")
	# Board at the back on two posts, and a small rack of dummy hilts behind the cloth.
	for x in (-1.2, 1.2): b.box((x, 1.05, top + 0.45), (0.08, 0.08, 0.9), "wood_dark")
	b.box((0, 1.0, top + 0.9), (2.6, 0.08, 0.5), "board")
	idx = [b.vert((-1.2, 0.95, top + 0.68)), b.vert((1.2, 0.95, top + 0.68)), b.vert((1.2, 0.95, top + 1.12)), b.vert((-1.2, 0.95, top + 1.12))]
	b.region_face(idx, BOARD)
	return b.to_object("WeaponTable", mat)

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "dungeon", "weapons")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(512, SWATCHES, 120, 72)
draw_print(SHEET)
png = os.path.join(out_dir, "weapons_print.png")
SHEET.render(png)
mat = material("Weapons", png)
objects = {"weapon_table": table(mat), "lathi": lathi(mat), "talwar": talwar(mat), "gada": gada(mat)}
for name, ob in objects.items(): export_glb(ob, os.path.join(out_dir, name + ".glb"))
for k, name in enumerate(("lathi", "talwar", "gada")):
	ob = objects[name]
	ob.location = (-0.8 + k * 0.8, 0.2, 1.0)
	ob.rotation_euler = (math.radians(-90), 0, 0)
if render: preview(render, (2.8, -3.2, 2.0), (0, 0.5, 1.0), lens=38)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "weapons.blend"))
print("SAVED", os.path.join(source, "weapons.blend"))
