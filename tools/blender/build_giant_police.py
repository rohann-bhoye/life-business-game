# Builds the giant policeman who watches Dholkarpur Gaon from behind the north hills:
# an Indian police constable in khaki (half-sleeve shirt, belt, trousers, brown shoes),
# a peaked cap with a red band, a thick moustache and a bamboo lathi. Two models share
# one swatch atlas so the head can turn on its own in the game (giant_police.gd):
#   giant_police_body.glb  feet at the origin, neck at z 1.52 (about 1.86 m tall in all)
#   giant_police_head.glb  neck base at the origin
# Front faces -Y here (+Z in Godot).
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_giant_police.py -- <project dir> [--render out.png]
# Writes assets/props/police/*.glb, giant_police_print.png and source/giant_police.blend.
import bpy, os, sys
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

SWATCHES = {
	"khaki": "C4A46A", "khaki_dark": "9E804C", "belt": "4A3220", "brass": "D9B24A",
	"shoe": "2E2018", "skin": "B57A55", "skin_dark": "8F5A3C", "black": "1B1B1B",
	"white": "F2F2EE", "red": "B8262B", "lips": "7A3B33", "bamboo": "C9A35E",
}

def oval_lathe(b, base, profile, bands, depth=1.0, seg=12):
	"""A lathe squashed front to back (`depth` of its width)."""
	first = len(b.verts)
	b.lathe(base, profile, bands, seg)
	for i in range(first, len(b.verts)): b.verts[i].y = base[1] + (b.verts[i].y - base[1]) * depth

def build_body(mat):
	b = Builder(SHEET)
	for x in (-0.11, 0.11):
		b.box((x, -0.035, 0.045), (0.12, 0.29, 0.09), "shoe")
		b.lathe((x, 0, 0.09), [(0.07, 0.0), (0.08, 0.35), (0.095, 0.62), (0.1, 0.86)], ["khaki", "khaki", "khaki"], 10)
	oval_lathe(b, (0, 0, 0), [(0.19, 0.88), (0.19, 0.97), (0.19, 1.04), (0.2, 1.2), (0.22, 1.36), (0.21, 1.45), (0.12, 1.5), (0.0, 1.52)],
		["khaki", "belt", "khaki", "khaki", "khaki", "khaki", "khaki"], 0.62, 16)
	b.box((0, -0.122, 1.005), (0.07, 0.02, 0.05), "brass")
	for z in (1.1, 1.18, 1.26, 1.34, 1.42): b.box((0, -0.128 - (z - 1.1) * 0.03, z), (0.016, 0.01, 0.016), "brass")
	for x in (-0.09, 0.09):
		b.box((x, -0.132, 1.3), (0.085, 0.016, 0.09), "khaki_dark")
		b.box((x, -0.137, 1.345), (0.09, 0.016, 0.025), "khaki")
		b.box((x * 1.9, 0, 1.475), (0.12, 0.08, 0.02), "khaki_dark")
		b.box((x * 1.9, -0.02, 1.488), (0.1, 0.014, 0.008), "red")
	b.box((-0.09, -0.142, 1.37), (0.05, 0.008, 0.016), "black")
	b.box((0.09, -0.142, 1.375), (0.024, 0.008, 0.024), "brass")
	for x in (-0.25, 0.25):
		b.lathe((x, 0, 0), [(0.035, 0.74), (0.05, 0.78), (0.048, 0.86), (0.05, 1.05), (0.066, 1.08), (0.07, 1.3), (0.075, 1.45)],
			["skin", "skin", "skin", "khaki_dark", "khaki", "khaki"], 10)
	b.lathe((0.25, -0.01, 0), [(0.02, 0.12), (0.02, 0.2), (0.02, 1.08), (0.02, 1.18)], ["black", "bamboo", "black"], 8)
	return b.to_object("GiantPoliceBody", mat)

def build_head(mat):
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(0.058, -0.03), (0.058, 0.07)], ["skin"], 12)
	oval_lathe(b, (0, 0, 0), [(0.06, 0.05), (0.095, 0.09), (0.106, 0.16), (0.1, 0.23), (0.085, 0.28), (0.0, 0.3)],
		["skin", "skin", "skin", "skin", "skin"], 0.94, 14)
	for x in (-0.105, 0.105): b.box((x, 0, 0.17), (0.025, 0.045, 0.06), "skin_dark")
	b.box((0, -0.104, 0.17), (0.03, 0.03, 0.05), "skin_dark")
	for x in (-0.04, 0.04):
		b.box((x, -0.093, 0.205), (0.036, 0.008, 0.022), "white")
		b.box((x, -0.098, 0.205), (0.018, 0.006, 0.018), "black")
		b.box((x, -0.098, 0.229), (0.044, 0.01, 0.011), "black")
	b.box((0, -0.11, 0.142), (0.1, 0.02, 0.024), "black")
	for x in (-0.055, 0.055): b.box((x, -0.106, 0.128), (0.024, 0.016, 0.03), "black")
	b.box((0, -0.098, 0.115), (0.038, 0.008, 0.008), "lips")
	b.lathe((0, 0, 0), [(0.11, 0.235), (0.11, 0.258), (0.11, 0.28), (0.136, 0.32), (0.128, 0.345), (0.0, 0.352)],
		["khaki_dark", "red", "khaki", "khaki", "khaki"], 16)
	b.box((0, -0.115, 0.24), (0.18, 0.075, 0.012), "black")
	b.box((0, -0.122, 0.3), (0.045, 0.01, 0.045), "brass")
	return b.to_object("GiantPoliceHead", mat)

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "police")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(512, SWATCHES, 16)
png = os.path.join(out_dir, "giant_police_print.png")
SHEET.render(png)
mat = material("GiantPolice", png)
body = build_body(mat)
head = build_head(mat)
export_glb(body, os.path.join(out_dir, "giant_police_body.glb"))
export_glb(head, os.path.join(out_dir, "giant_police_head.glb"))
head.location.z = 1.52
if render: preview(render, (1.5, -4.2, 1.3), (0, 0, 0.98), lens=50)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "giant_police.blend"))
print("SAVED", os.path.join(source, "giant_police.blend"))
