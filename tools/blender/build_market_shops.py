# Builds the eight market-street shops of Dholkarpur Gaon (town_expansion.gd SHOPS):
# two-storey Indian shop-houses, 5 m wide and 5 m deep. The ground floor is an open
# shop (rolled-up shutter, side pillars, a painted name board, a striped tarp awning,
# a counter, wall shelves stocked for the trade and packets hanging at the front);
# above is the family's floor with a grilled window and a sunshade, a coloured
# parapet and a black water tank on the roof. One shared atlas; each shop is its own
# model, front facing -Y here (+Z in Godot), front edge at y 0, foot at the origin.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_market_shops.py -- <project dir> [--render out.png]
# Writes assets/props/market/market_shop_<0-7>.glb, market_print.png, source/market.blend.
import bpy, os, sys, random
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

W, D = 5.0, 5.0                # width (x) and depth (y)
GROUND, TOP = 3.4, 6.3         # first-floor slab and roof heights
# name, subtitle, wall, accent, goods colours
SHOPS = [
	("CHAI POINT", "Chai  -  Nashta  -  Biscuit", "EBC99A", "D9731F", ["8A4B22", "D9A441", "F2E2C0", "C2412D"]),
	("GUPTA MEDICAL", "Medicines 24x7", "BFE3D2", "1E8C6E", ["FFFFFF", "3FA34D", "2E86C1", "E74C3C"]),
	("MITHAI HOUSE", "Sweets & Namkeen", "F2B8CB", "D6336C", ["F5B041", "F8C9D4", "E67E22", "FFF3C4"]),
	("MOBILE REPAIR", "Repair  -  Recharge  -  Covers", "B5C9EB", "2F5DBF", ["1B1B1B", "3D7BD9", "E5E5E5", "F2C230"]),
	("PANI PURI", "Chaat Corner", "F7DC85", "E0A800", ["F4D03F", "A0522D", "58D68D", "F5F5DC"]),
	("TAILOR", "Ladies & Gents", "D3BEEA", "7D4FA0", ["C0392B", "2471A3", "F1C40F", "27AE60"]),
	("HARDWARE", "Paint  -  Pipes  -  Tools", "BCC4CB", "5D6D7E", ["C0392B", "7F8C8D", "F39C12", "2C3E50"]),
	("BAKERY", "Cakes  -  Rusk  -  Bread", "E9C9A0", "A0632B", ["D4A15A", "8B5A2B", "F7E9D0", "E8B4B8"]),
]
SWATCHES = {"floor": "C9C3B6", "slab": "B8B3AA", "shutter": "8E969C", "glass": "2C3E50", "grill": "2B2B2B",
	"frame": "F2F2EE", "tank": "1C1C1C", "light": "FFFFF0", "shelf": "9C7B55", "counter_top": "EDE8DC", "white": "F7F5F0"}
for i, shop in enumerate(SHOPS):
	SWATCHES["wall%d" % i], SWATCHES["accent%d" % i] = shop[2], shop[3]
	for k, c in enumerate(shop[4]): SWATCHES["goods%d_%d" % (i, k)] = c

def board(i):
	return (16 + (i % 2) * 500, 16 + (i // 2) * 116, 488, 104)

def draw_print(s):
	for i, shop in enumerate(SHOPS):
		x, y, w, h = board(i)
		s.rect(x, y, w, h, shop[3])
		s.rect(x + 6, y + 6, w - 12, h - 12, "F7F5F0", 0.01)
		s.rect(x + 11, y + 11, w - 22, h - 22, shop[3], 0.02)
		s.text(shop[0], x + w / 2, y + 50, 38, "FFFFFF", 0.03, "ariblk.ttf", w - 40)
		s.text(shop[1], x + w / 2, y + 84, 18, "FFF4C2", 0.03, "arialbd.ttf", w - 60)

def build(i, mat):
	rng = random.Random(40 + i)
	wall, accent = "wall%d" % i, "accent%d" % i
	b = Builder(SHEET)
	half = W / 2
	b.box((0, D / 2, 0.06), (W, D, 0.12), "floor")
	for x in (-half + 0.1, half - 0.1): b.box((x, D / 2, TOP / 2), (0.2, D, TOP), wall)
	b.box((0, D - 0.1, TOP / 2), (W, 0.2, TOP), wall)
	b.box((0, D / 2, GROUND), (W, D, 0.25), {"-y": accent, "rest": "slab"})
	b.box((0, D / 2, TOP), (W + 0.1, D + 0.1, 0.2), "slab")
	# Upper floor front: wall, grilled window with a sunshade, a small balcony ledge.
	b.box((0, 0.1, (GROUND + TOP) / 2 + 0.06), (W, 0.2, TOP - GROUND - 0.12), wall)
	b.box((0, -0.02, 4.75), (2.0, 0.06, 1.3), "frame")
	b.box((0, -0.05, 4.75), (1.8, 0.04, 1.1), "glass")
	for x in (-0.6, -0.3, 0.0, 0.3, 0.6): b.box((x, -0.08, 4.75), (0.04, 0.03, 1.1), "grill")
	b.box((0, -0.3, 5.5), (2.4, 0.6, 0.08), accent)
	b.box((0, -0.25, GROUND + 0.18), (W, 0.5, 0.1), "slab")
	# Roof: parapet in the accent colour and a black water tank.
	for x, y, sx, sy in ((0, -0.02, W + 0.1, 0.15), (0, D + 0.02, W + 0.1, 0.15), (-half, D / 2, 0.15, D), (half, D / 2, 0.15, D)):
		b.box((x, y, TOP + 0.3), (sx, sy, 0.4), accent)
	b.lathe((1.2, D - 1.0, 0), [(0.45, TOP + 0.1), (0.45, TOP + 0.95), (0.2, TOP + 1.05)], ["tank", "tank"], 10)
	# Ground floor front: pillars, rolled-up shutter, name board, tube light.
	for x in (-half + 0.15, half - 0.15): b.box((x, 0.15, GROUND / 2), (0.3, 0.3, GROUND), accent)
	b.box((0, 0.1, 2.45), (W - 0.6, 0.3, 0.3), "shutter")
	x, y, w, h = board(i)
	idx = [b.vert((-2.35, -0.09, 2.62)), b.vert((2.35, -0.09, 2.62)), b.vert((2.35, -0.09, 3.28)), b.vert((-2.35, -0.09, 3.28))]
	b.region_face(idx, (x, y, w, h))
	b.box((0, -0.03, 2.95), (4.74, 0.1, 0.7), accent)
	b.box((0, 1.0, 2.2), (1.2, 0.05, 0.05), "light")
	# Striped tarp awning sloping out over the pavement.
	for k in range(8):
		x0 = -half + k * W / 8
		x1 = x0 + W / 8
		quad = [b.vert((x0, -0.1, 2.5)), b.vert((x1, -0.1, 2.5)), b.vert((x1, -1.1, 2.15)), b.vert((x0, -1.1, 2.15))]
		b.swatch_face(quad, accent if k % 2 == 0 else "white")
		b.swatch_face(list(reversed([b.vert(b.verts[q]) for q in quad])), accent if k % 2 == 0 else "white")
	# Counter at the front and shelves of goods on the back and side walls.
	b.box((0, 0.75, 0.5), (3.4, 0.55, 0.9), {"+z": "counter_top", "rest": accent})
	for z in (0.75, 1.45, 2.15):
		b.box((0, D - 0.42, z), (W - 0.5, 0.45, 0.05), "shelf")
		gx = -half + 0.4
		while gx < half - 0.5:
			gw = rng.uniform(0.2, 0.45)
			gh = rng.uniform(0.18, 0.5)
			b.box((gx + gw / 2, D - 0.42, z + 0.025 + gh / 2), (gw * 0.9, 0.35, gh), "goods%d_%d" % (i, rng.randrange(4)))
			gx += gw
		for side in (-1, 1):
			b.box((side * (half - 0.45), D / 2 + 0.5, z), (0.45, 2.6, 0.05), "shelf")
			for k in range(5):
				b.box((side * (half - 0.45), D / 2 - 0.5 + k * 0.5, z + 0.18), (0.35, 0.4, 0.3), "goods%d_%d" % (i, rng.randrange(4)))
	# Packets hanging on strings along the front.
	for k in range(10):
		px = -1.9 + k * 0.42
		b.box((px, 0.35, 2.25), (0.01, 0.01, 0.3), "grill")
		b.box((px, 0.35, 1.98), (0.24, 0.03, 0.3), "goods%d_%d" % (i, k % 4))
	return b.to_object("MarketShop%d" % i, mat)

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "market")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(1024, SWATCHES, 500, 72)
draw_print(SHEET)
png = os.path.join(out_dir, "market_print.png")
SHEET.render(png)
mat = material("Market", png)
shops = [build(i, mat) for i in range(len(SHOPS))]
for i, shop in enumerate(shops): export_glb(shop, os.path.join(out_dir, "market_shop_%d.glb" % i))
for i, shop in enumerate(shops[:3]): shop.location.x = (i - 1) * 5.6
for shop in shops[3:]: shop.hide_render = True
if render: preview(render, (6, -14, 4.5), (0, 2, 3), lens=40)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "market.blend"))
print("SAVED", os.path.join(source, "market.blend"))
