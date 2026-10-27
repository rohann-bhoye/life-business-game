# Builds the low-poly trees of Dholkarpur Gaon, foot at the origin:
#   pine_tree.glb  ~4.4 m hill pine: a tapering trunk and four layered tiers with dark
#                  undersides, darker low and fresher green high (HillForest, scaled 1.3-2.5)
#   neem_tree.glb  ~5.2 m town shade tree: a thick trunk with two forks and a round,
#                  lumpy crown of six leaf puffs, shaded darker underneath (town trees)
# Both share one swatch atlas. Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_trees.py -- <project dir> [--render out.png]
# Writes assets/props/trees/*.glb, trees_print.png and source/trees.blend.
import bpy, os, sys, math
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

SWATCHES = {
	"bark": "6B4A2F", "bark_dark": "4E3622", "pine_under": "1D4A2A", "pine_low": "2C6E3B",
	"pine_mid": "38834A", "pine_high": "4C9C56", "leaf_under": "2B6332", "leaf_mid": "3D8A3E",
	"leaf_light": "52A347", "leaf_top": "68B851",
}

def pine(mat):
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(0.17, 0.0), (0.13, 1.2), (0.06, 2.8)], ["bark", "bark"], 7)
	tiers = [(0.85, 1.3, 1.5, "pine_low"), (1.65, 1.05, 1.4, "pine_mid"), (2.45, 0.8, 1.25, "pine_mid"), (3.2, 0.52, 1.2, "pine_high")]
	for z0, r, h, top in tiers:
		b.lathe((0, 0, 0), [(0.16, z0 + 0.3), (r, z0), (r * 0.9, z0 + 0.14), (0.0, z0 + h)], ["pine_under", top, top], 9)
	return b.to_object("PineTree", mat)

def puff(b, centre, r, seg=8):
	cx, cy, cz = centre
	profile = [(r * 0.15, cz - r * 0.98), (r * 0.7, cz - r * 0.72), (r, cz - r * 0.05), (r * 0.86, cz + r * 0.5), (r * 0.46, cz + r * 0.88), (0.0, cz + r)]
	b.lathe((cx, cy, 0), profile, ["leaf_under", "leaf_under", "leaf_mid", "leaf_light", "leaf_top"], seg)

def neem(mat):
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(0.24, 0.0), (0.19, 0.5), (0.16, 1.6), (0.12, 2.6)], ["bark_dark", "bark", "bark"], 8)
	for x, y in ((0.35, 0.1), (-0.3, -0.15)):
		b.lathe((x, y, 0), [(0.08, 2.0), (0.06, 3.0)], ["bark"], 6)
	for centre, r in (((0, 0, 3.55), 1.5), ((1.05, 0.25, 3.25), 1.05), ((-0.95, -0.35, 3.35), 1.1),
			((0.2, -1.0, 3.45), 1.0), ((-0.3, 0.95, 3.6), 1.0), ((0.25, 0.1, 4.4), 1.0)):
		puff(b, centre, r)
	return b.to_object("NeemTree", mat)

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "trees")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(512, SWATCHES, 16)
png = os.path.join(out_dir, "trees_print.png")
SHEET.render(png)
mat = material("Trees", png)
pine_tree, neem_tree = pine(mat), neem(mat)
export_glb(pine_tree, os.path.join(out_dir, "pine_tree.glb"))
export_glb(neem_tree, os.path.join(out_dir, "neem_tree.glb"))
pine_tree.location.x, neem_tree.location.x = -2.2, 2.2
if render: preview(render, (0, -13, 3.2), (0, 0, 2.4), lens=45)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "trees.blend"))
print("SAVED", os.path.join(source, "trees.blend"))
