# Builds the furniture of the player's home (home_decor.gd places it) as an Indian
# home: a wooden bed with a red bedsheet and pillows, a steel almirah, a diwan with
# bolsters, a TV unit, a dining table with chairs, a mandir (home shrine), a kitchen
# counter with a gas stove and a steel sink, a bedside table with a lamp, a matka (clay
# water pot) on a stand and a patterned rug. One shared atlas; every piece faces -Y here
# (+Z in Godot) with its back at +Y, feet on the ground at z 0, origin at the middle of the
# footprint. Sizes match home_decor.gd's fit sizes.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_home_furniture.py -- <project dir> [--render out.png]
# Writes assets/props/home/*.glb, home_print.png and source/home.blend.
import bpy, os, sys, math
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

SWATCHES = {
	"wood": "8A5530", "wood_dark": "5E3818", "wood_light": "B07A48", "mattress": "F2EBDD", "sheet": "B8262B",
	"sheet_trim": "E8B84A", "pillow": "FFF6E2", "pillow_blue": "2F5DBF", "steel": "9FB0BE", "steel_dark": "6E8091",
	"handle": "D8DDE2", "tv": "14161A", "tv_glow": "3A5A7A", "clay": "B5532A", "clay_dark": "8C3C1C", "gold": "E8B84A",
	"flame": "FFB02E", "white": "F2F0EA", "counter": "C9C4B8", "sink": "C5CDD3", "iron": "2E3238", "marigold": "F59E0B",
	"maroon": "7A1F1F", "green": "3E7D3A", "lamp": "FFE9A8", "cushion": "2F8A6E", "cushion_gold": "D49A2A",
}

def bed(mat):
	b = Builder(SHEET)
	W, D = 1.5, 2.0
	for x in (-W / 2 + 0.06, W / 2 - 0.06):
		for y in (-D / 2 + 0.06, D / 2 - 0.06): b.box((x, y, 0.15), (0.1, 0.1, 0.3), "wood_dark")
	b.box((0, 0, 0.34), (W, D, 0.1), "wood")
	b.box((0, 0, 0.5), (W - 0.08, D - 0.1, 0.22), "mattress")
	b.box((0, -0.12, 0.62), (W - 0.04, D - 0.4, 0.04), "sheet")
	b.box((0, -D / 2 + 0.28, 0.62), (W - 0.04, 0.05, 0.045), "sheet_trim")
	b.box((0, D / 2 - 0.05, 0.72), (W + 0.04, 0.1, 0.8), "wood")
	b.box((0, D / 2 - 0.05, 1.14), (W + 0.04, 0.12, 0.08), "wood_dark")
	for x in (-0.36, 0.36): b.box((x, D / 2 - 0.32, 0.7), (0.5, 0.34, 0.12), "pillow" if x < 0 else "pillow_blue")
	b.box((0, -D / 2 + 0.03, 0.4), (W, 0.06, 0.5), "wood_dark")
	return b.to_object("Bed", mat)

def almirah(mat):
	b = Builder(SHEET)
	W, D, H = 1.0, 0.5, 1.9
	b.box((0, 0, H / 2 + 0.06), (W, D, H - 0.06), "steel")
	for x in (-W / 2 + 0.05, W / 2 - 0.05): b.box((x, 0, 0.03), (0.08, D - 0.06, 0.06), "steel_dark")
	b.box((0, 0, H + 0.02), (W + 0.04, D + 0.04, 0.04), "steel_dark")
	for s in (-1, 1):
		b.box((s * W / 4, -D / 2 - 0.005, H / 2 + 0.06), (W / 2 - 0.04, 0.01, H - 0.2), "steel_dark")
		for z in (1.2, 1.35, 1.5, 1.65): b.box((s * W / 4, -D / 2 - 0.012, z), (W / 2 - 0.2, 0.01, 0.025), "steel")
		b.box((s * 0.06, -D / 2 - 0.03, 0.95), (0.03, 0.04, 0.2), "handle")
	return b.to_object("Almirah", mat)

def diwan(mat):
	b = Builder(SHEET)
	W, D = 1.8, 0.8
	b.box((0, 0, 0.2), (W, D, 0.3), "wood")
	for x in (-W / 2 + 0.07, W / 2 - 0.07):
		for y in (-D / 2 + 0.07, D / 2 - 0.07): b.box((x, y, 0.025), (0.09, 0.09, 0.05), "wood_dark")
	b.box((0, -0.02, 0.42), (W - 0.08, D - 0.1, 0.14), "cushion")
	b.box((0, D / 2 - 0.06, 0.64), (W, 0.12, 0.44), "wood")
	for x in (-0.55, 0.0, 0.55): b.box((x, D / 2 - 0.2, 0.62), (0.42, 0.14, 0.3), "cushion_gold" if x else "pillow_blue")
	for x in (-W / 2 + 0.1, W / 2 - 0.1): b.box((x, -0.05, 0.56), (0.16, 0.46, 0.18), "maroon")
	return b.to_object("Diwan", mat)

def tv_unit(mat):
	b = Builder(SHEET)
	W, D = 1.2, 0.45
	b.box((0, 0, 0.27), (W, D, 0.5), "wood")
	for x in (-0.3, 0.3):
		b.box((x, -D / 2 - 0.005, 0.27), (0.52, 0.01, 0.4), "wood_dark")
		b.box((x - 0.2 * (1 if x > 0 else -1) * -1, -D / 2 - 0.02, 0.27), (0.03, 0.03, 0.1), "handle")
	b.box((0, 0.05, 0.52), (W + 0.04, D, 0.04), "wood_dark")
	b.box((0, 0.1, 0.57), (0.14, 0.14, 0.06), "iron")
	b.box((0, 0.1, 0.84), (0.98, 0.07, 0.56), "tv")
	b.box((0, 0.06, 0.84), (0.9, 0.01, 0.5), "tv_glow")
	b.box((0, 0.06, 0.84), (0.93, 0.005, 0.54), "tv")
	return b.to_object("TvUnit", mat)

def dining_table(mat):
	b = Builder(SHEET)
	W, D, H = 1.0, 0.8, 0.75
	b.box((0, 0, H - 0.03), (W, D, 0.06), "wood_light")
	b.box((0, 0, H - 0.055), (W - 0.08, D - 0.08, 0.05), "wood")
	for x in (-W / 2 + 0.06, W / 2 - 0.06):
		for y in (-D / 2 + 0.06, D / 2 - 0.06): b.box((x, y, (H - 0.06) / 2), (0.07, 0.07, H - 0.06), "wood_dark")
	b.box((0, 0, H + 0.002), (0.5, 0.5, 0.004), "sheet_trim")
	return b.to_object("DiningTable", mat)

def chair(mat):
	b = Builder(SHEET)
	for x in (-0.19, 0.19):
		for y in (-0.19, 0.19): b.box((x, y, 0.22), (0.05, 0.05, 0.44), "wood_dark")
		b.box((x, 0.2, 0.67), (0.05, 0.05, 0.45), "wood_dark")
	b.box((0, 0, 0.46), (0.44, 0.44, 0.05), "wood")
	b.box((0, 0.2, 0.66), (0.4, 0.04, 0.22), "wood")
	b.box((0, 0, 0.495), (0.36, 0.36, 0.03), "sheet")
	return b.to_object("Chair", mat)

def mandir(mat):
	b = Builder(SHEET)
	W, D = 0.9, 0.4
	b.box((0, 0, 0.45), (W, D, 0.9), "wood_dark")
	b.box((0, -0.02, 0.92), (W + 0.06, D + 0.04, 0.05), "wood")
	b.box((0, 0.02, 1.2), (W - 0.1, D - 0.1, 0.5), "wood")
	b.box((0, -0.08, 1.2), (W - 0.24, 0.1, 0.4), "maroon")
	b.lathe((0, 0.04, 0), [(0.3, 1.45), (0.22, 1.5), (0.1, 1.62), (0.02, 1.7)], ["wood", "wood", "gold"], 4)
	b.box((0, -0.04, 1.08), (0.1, 0.06, 0.18), "gold")
	b.lathe((0, -0.05, 0), [(0.06, 1.0), (0.1, 1.0), (0.1, 1.04), (0.02, 1.04)], ["gold", "gold", "gold"], 8)
	b.lathe((0.26, -0.12, 0), [(0.05, 0.945), (0.07, 0.945), (0.07, 0.975), (0.04, 0.98)], ["clay", "clay", "clay"], 8)
	b.box((0.26, -0.12, 0.99), (0.012, 0.012, 0.025), "flame")
	for x in (-0.3, 0.3): b.box((x, -0.18, 0.95), (0.18, 0.05, 0.03), "marigold")
	b.box((0, -D / 2 - 0.01, 1.4), (0.5, 0.012, 0.05), "marigold")
	return b.to_object("Mandir", mat)

def kitchen_unit(mat):
	b = Builder(SHEET)
	W, D, H = 1.4, 0.6, 0.9
	b.box((0, 0, 0.42), (W, D - 0.04, 0.84), "wood")
	b.box((0, 0, H - 0.02), (W + 0.04, D, 0.05), "counter")
	for x in (-0.46, 0.0, 0.46): b.box((x, -D / 2 + 0.015, 0.42), (0.42, 0.01, 0.7), "wood_dark")
	for x in (-0.46, 0.0, 0.46): b.box((x + 0.15, -D / 2 - 0.005, 0.7), (0.03, 0.03, 0.08), "handle")
	# Gas stove on the left: a hob with two burners and a knob row.
	b.box((-0.36, 0.0, H + 0.03), (0.5, 0.42, 0.06), "iron")
	for y in (-0.1, 0.1): b.lathe((-0.36, y, 0), [(0.08, H + 0.065), (0.08, H + 0.08), (0.03, H + 0.085)], ["steel_dark", "steel_dark"], 10)
	for x in (-0.5, -0.36, -0.22): b.box((x, -0.22, H + 0.03), (0.04, 0.03, 0.04), "handle")
	# Steel sink on the right: a basin and a tap.
	b.box((0.38, 0.0, H - 0.01), (0.5, 0.38, 0.03), "sink")
	b.box((0.38, 0.0, H - 0.0), (0.42, 0.3, 0.02), "steel_dark")
	b.box((0.38, 0.2, H + 0.12), (0.04, 0.04, 0.2), "handle")
	b.box((0.38, 0.14, H + 0.2), (0.04, 0.14, 0.04), "handle")
	b.box((0, D / 2 - 0.01, H + 0.22), (W, 0.02, 0.4), "white")
	return b.to_object("KitchenUnit", mat)

def side_table(mat):
	b = Builder(SHEET)
	for x in (-0.16, 0.16):
		for y in (-0.14, 0.14): b.box((x, y, 0.22), (0.05, 0.05, 0.44), "wood_dark")
	b.box((0, 0, 0.45), (0.42, 0.38, 0.05), "wood")
	b.box((0, -0.19, 0.3), (0.34, 0.01, 0.1), "wood_dark")
	b.lathe((0, 0, 0), [(0.07, 0.475), (0.05, 0.5), (0.025, 0.7)], ["gold", "gold"], 8)
	b.lathe((0, 0, 0), [(0.1, 0.68), (0.16, 0.76), (0.17, 0.9), (0.08, 0.92)], ["lamp", "lamp", "lamp"], 10)
	return b.to_object("SideTable", mat)

def matka(mat):
	b = Builder(SHEET)
	for x in (-0.15, 0.15):
		for y in (-0.15, 0.15): b.box((x, y, 0.24), (0.04, 0.04, 0.48), "iron")
	b.box((0, 0, 0.47), (0.4, 0.4, 0.03), "iron")
	b.lathe((0, 0, 0), [(0.1, 0.49), (0.18, 0.57), (0.2, 0.7), (0.15, 0.82), (0.09, 0.87), (0.1, 0.9)], ["clay", "clay", "clay_dark", "clay", "clay_dark"], 12)
	b.lathe((0, 0, 0), [(0.11, 0.9), (0.09, 0.93), (0.02, 0.945)], ["steel", "steel"], 12)
	return b.to_object("Matka", mat)

def rug(mat):
	b = Builder(SHEET)
	W, D = 1.9, 1.5
	for k, (shrink, colour) in enumerate(((0.0, "maroon"), (0.1, "sheet_trim"), (0.16, "sheet"), (0.3, "cushion"), (0.38, "sheet_trim"), (0.5, "pillow_blue"))):
		b.box((0, 0, 0.005 + k * 0.002), (W - shrink * 2, D - shrink * 2, 0.01), colour)
	return b.to_object("Rug", mat)

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "home")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(512, SWATCHES, 16, 72)
png = os.path.join(out_dir, "home_print.png")
SHEET.render(png)
mat = material("Home", png)
pieces = {"bed": bed(mat), "almirah": almirah(mat), "diwan": diwan(mat), "tv_unit": tv_unit(mat), "dining_table": dining_table(mat),
	"chair": chair(mat), "mandir": mandir(mat), "kitchen_unit": kitchen_unit(mat), "side_table": side_table(mat), "matka": matka(mat), "rug": rug(mat)}
for name, ob in pieces.items(): export_glb(ob, os.path.join(out_dir, name + ".glb"))
spots = {"bed": (-2.4, 0), "almirah": (-0.8, 0.6), "diwan": (1.6, 0.4), "tv_unit": (-0.3, -1.6), "dining_table": (-2.2, -2.4), "chair": (-1.2, -2.4),
	"mandir": (2.2, -2.2), "kitchen_unit": (0.8, -2.5), "side_table": (-0.2, -2.7), "matka": (0.5, -2.8), "rug": (1.6, -1.0)}
for name, ob in pieces.items(): ob.location = (spots[name][0], spots[name][1], 0)
if render: preview(render, (3.5, -7.5, 3.6), (0, -0.8, 0.7), lens=38)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "home.blend"))
print("SAVED", os.path.join(source, "home.blend"))
