# Builds the APNA MART shop fixtures, all sharing one printed atlas (shop_fixtures_print.png):
#   counter.glb     wooden kirana billing counter: printed front, black granite top, drawers
#                   and cupboards on the cashier's side, a UPI QR stand (floor centre origin)
#   rack.glb        steel gondola: pegboard back, printed end panels, slotted posts, three
#                   shelves with price strips at the game's shelf heights (front +x)
#   fridge.glb      cold-drink cooler body: THANDA sides, vent grille, wire shelves, door
#                   frames and handles; the glass and the lit header stay in the game
#   carton.glb      0.8 m delivery carton: kraft, tape, shipping label, handling marks (centre origin)
#   bag_box.glb     carry-bag dispenser, open toward the cashier (bottom centre origin)
#   folded_bag.glb  one folded carry bag for the pile in the dispenser
# Blender axes: x as in the game, -y = the game's +z (customer side / front), z up.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_shop_fixtures.py -- <project dir> [--render out.png]
# Writes assets/props/shop/*.glb, shop_fixtures_print.png and source/shop_fixtures.blend.
import bpy, os, sys, math, random
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

ATLAS = 1024
WHITE, ORANGE, YELLOW, GREEN, GREEN_DARK = "F4F3EE", "F0892A", "F4C443", "2F9A5C", "21774A"
BLUE, INK, KRAFT = "1F6FD1", "4A3420", "C49A63"
SWATCHES = {
	"wood": "8E5A2E", "wood_dark": "5E3A1C", "kick": "2A2421", "granite_edge": "2B2C30", "steel": "3A3F45",
	"steel_light": "C5CAD0", "shelf": "D3D7DB", "lip": "B8BEC4", "price": WHITE, "fridge": "EEF1F3",
	"fridge_inner": "DCE3E8", "chrome": "B9C0C6", "gasket": "202326", "kraft": KRAFT, "acrylic": "E8ECEE",
	"green": GREEN, "white": WHITE, "base": "1E2124",
}

# Atlas regions (x, y, w, h) in pixels.
COUNTER_FRONT = (0, 0, 1008, 252)     # 2.8 x 0.7 m cabinet front
GRANITE = (0, 268, 400, 110)
QR = (416, 268, 96, 140)
CARTON_FRONT = (528, 268, 230, 230)
CARTON_SIDE = (774, 268, 230, 230)
CARTON_TOP = (0, 394, 230, 230)
RACK_END = (246, 394, 100, 318)       # 0.585 x 1.84 m
PEGBOARD = (362, 424, 150, 120)
FRIDGE_SIDE = (528, 514, 110, 284)    # 0.72 x 1.86 m
BAG_BOX_FRONT = (654, 514, 170, 100)
BAG_BOX_TOP = (654, 630, 136, 104)
FOLDED_BAG = (654, 750, 140, 100)
COUNTER_END = (840, 514, 140, 140)
POST = (0, 640, 16, 210)
GRILLE = (32, 640, 200, 16)
WIRE = (32, 672, 200, 60)

# ---------- print
def wood(s, region, grooves_px, seed):
	x, y, w, h = region
	s.rect(x - 6, y - 6, w + 12, h + 12, "8E5A2E")
	s.speckle(region, 80, ("9C6838", "7F4F27"), ((30, 150), (1, 2)), 0.005, seed)
	s.rects([(x + k * grooves_px - 2, y, 4, h) for k in range(1, int(w / grooves_px) + 1) if k * grooves_px < w - 4], "5E3A1C", 0.01)
	s.rect(x - 6, y + 8, w + 12, 8, ORANGE, 0.02)
	s.rect(x - 6, y + h - 8, w + 12, 14, "2A2421", 0.02)

def kraft(s, region, seed):
	x, y, w, h = region
	s.rect(x - 6, y - 6, w + 12, h + 12, KRAFT)
	s.speckle(region, 240, ("B58A55", "CFA673"), ((1, 2), (2, 6)), 0.005, seed)
	s.rects([(x, y, w, 3), (x, y + h - 3, w, 3), (x, y, 3, h), (x + w - 3, y, 3, h)], "A87F4C", 0.01)

def arrow_up(s, cx, top, colour, z):
	s.polygon([(cx, top), (cx + 9, top + 11), (cx - 9, top + 11)], colour, z)
	s.rect(cx - 3, top + 10, 6, 14, colour, z)

def draw_print(s):
	# Counter front: wood laminate with grooves, an orange trim, the logo panel and a UPI sticker.
	x, y, w, h = COUNTER_FRONT
	wood(s, COUNTER_FRONT, 72, 1)
	cx, cy = x + w / 2, y + 112
	s.rect(cx - 202, cy - 83, 404, 166, ORANGE, 0.03, r=14)
	s.rect(cx - 198, cy - 79, 396, 158, "1E2226", 0.04, r=11)
	s.text("APNA MART", cx, cy - 24, 46, WHITE, 0.05, "ariblk.ttf", 360)
	s.rect(cx - 120, cy + 10, 240, 4, ORANGE, 0.05)
	s.text("BILLING  •  CHECKOUT", cx, cy + 34, 15, ORANGE, 0.05, "segoeuib.ttf", 340)
	s.text("Dhanyavaad! Phir aana", cx, cy + 58, 15, WHITE, 0.05, "seguibli.ttf", 340)
	ux, uy = x + 820, y + 62
	s.rect(ux, uy, 110, 92, WHITE, 0.03, r=10)
	s.rect(ux, uy, 110, 24, ORANGE, 0.04, r=10)
	s.rect(ux, uy + 12, 110, 12, ORANGE, 0.04)
	s.text("PAY HERE", ux + 55, uy + 12, 10, WHITE, 0.05, "segoeuib.ttf", 100)
	s.text("UPI", ux + 55, uy + 52, 26, BLUE, 0.05, "ariblk.ttf", 96)
	s.text("CASH  •  CARD", ux + 55, uy + 78, 8, "2A2421", 0.05, "segoeuib.ttf", 100)
	wood(s, COUNTER_END, 40, 2)
	# Black granite top.
	x, y, w, h = GRANITE
	s.rect(x - 6, y - 6, w + 12, h + 12, "1B1C1F")
	s.speckle(GRANITE, 900, ("3A3B40", "55565C", "8A8478", "2C2D31"), ((1, 3), (1, 3)), 0.01, 3)
	# UPI QR card.
	x, y, w, h = QR
	s.rect(x - 6, y - 6, w + 12, h + 12, "E8ECEE")
	s.rect(x, y, w, h, WHITE, 0.01, r=8)
	s.rect(x, y, w, 26, ORANGE, 0.02, r=8)
	s.rect(x, y + 14, w, 12, ORANGE, 0.02)
	s.text("SCAN & PAY", x + w / 2, y + 13, 9, WHITE, 0.03, "segoeuib.ttf", 86)
	qx, qy, m = x + 16, y + 34, 3
	rng = random.Random(5)
	finder = lambda c, r: any(c0 <= c < c0 + 7 and r0 <= r < r0 + 7 for c0, r0 in ((0, 0), (14, 0), (0, 14)))
	s.rects([(qx + c * m, qy + r * m, m, m) for r in range(21) for c in range(21) if not finder(c, r) and rng.random() < 0.48], "111111", 0.03)
	for c0, r0 in ((0, 0), (14, 0), (0, 14)):
		s.rect(qx + c0 * m, qy + r0 * m, 21, 21, "111111", 0.03)
		s.rect(qx + c0 * m + 3, qy + r0 * m + 3, 15, 15, WHITE, 0.04)
		s.rect(qx + c0 * m + 6, qy + r0 * m + 6, 9, 9, "111111", 0.05)
	s.text("UPI", x + w / 2, y + 112, 14, BLUE, 0.03, "ariblk.ttf", 80)
	s.text("APNA MART", x + w / 2, y + 128, 7, "2A2421", 0.03, "segoeuib.ttf", 80)
	# Delivery carton: front (label + tape), sides (handling marks + wholesaler print), top.
	x, y, w, h = CARTON_FRONT
	kraft(s, CARTON_FRONT, 4)
	s.rect(x + w / 2 - 20, y - 6, 40, 41, "E2C27E", 0.02)
	s.rect(x + w / 2 - 20, y + 33, 40, 2, "C9A964", 0.025)
	s.rect(x + 11.5, y + 69, 207, 121, "F7F7F3", 0.03, r=3)
	s.rect(x + 14, y + 75.5, 202, 10, "268C75", 0.04)
	rng = random.Random(6)
	bars, bx = [], x + 30
	while bx < x + 90:
		bw = rng.choice((1, 1, 2, 3))
		bars.append((bx, y + 174, bw, 12))
		bx += bw + rng.choice((1, 2, 2, 3))
	s.rects(bars, "1A1A1A", 0.04)
	s.text("APNA WHOLESALE  •  SHIP TO: APNA MART", x + 150, y + 180, 5, "2A2421", 0.04, "segoeuib.ttf", 120)
	x, y, w, h = CARTON_SIDE
	kraft(s, CARTON_SIDE, 7)
	for dx in (-11, 11): arrow_up(s, x + 38 + dx, y + 22, INK, 0.02)
	s.text("THIS SIDE UP", x + 38, y + 60, 8, INK, 0.02, "segoeuib.ttf", 70)
	gx, gy = x + 190, y + 22
	s.polygon([(gx - 11, gy), (gx + 11, gy), (gx + 8, gy + 14), (gx + 2, gy + 18), (gx - 2, gy + 18), (gx - 8, gy + 14)], INK, 0.02)
	s.rect(gx - 1.5, gy + 18, 3, 12, INK, 0.02)
	s.rect(gx - 8, gy + 29, 16, 3, INK, 0.02)
	s.text("FRAGILE", gx, gy + 40, 8, INK, 0.02, "segoeuib.ttf", 70)
	s.rects([(x + 30, y + 92, 170, 3), (x + 30, y + 168, 170, 3), (x + 30, y + 92, 3, 79), (x + 197, y + 92, 3, 79)], INK, 0.02)
	s.text("APNA", x + w / 2, y + 116, 26, INK, 0.02, "ariblk.ttf", 150)
	s.text("WHOLESALE", x + w / 2, y + 148, 15, INK, 0.02, "ariblk.ttf", 150)
	s.text("Keep dry  •  Made in India", x + w / 2, y + 206, 8, INK, 0.02, "segoeuib.ttf", 180)
	x, y, w, h = CARTON_TOP
	kraft(s, CARTON_TOP, 8)
	s.rect(x + w / 2 - 1, y, 2, h, "8E6A3C", 0.015)
	s.rect(x + w / 2 - 20, y - 6, 40, h + 12, "E2C27E", 0.02)
	s.rects([(x + w / 2 - 20, y, 2, h), (x + w / 2 + 18, y, 2, h)], "C9A964", 0.025)
	# Gondola rack: printed end panels, pegboard back, slotted posts.
	x, y, w, h = RACK_END
	s.rect(x - 6, y - 6, w + 12, h + 12, "D9DDE0")
	s.rect(x - 6, y - 6, w + 12, 44, GREEN_DARK, 0.01)
	s.rect(x - 6, y + 38, w + 12, 4, ORANGE, 0.01)
	s.text("APNA MART", x + w / 2, y + 19, 10, WHITE, 0.02, "ariblk.ttf", 86)
	s.rect(x - 6, y + h - 24, w + 12, 30, "2A2E33", 0.01)
	s.rect(x + w - 8, y + 42, 3, h - 66, "E8EBED", 0.01)
	x, y, w, h = PEGBOARD
	s.rect(x - 6, y - 6, w + 12, h + 12, "C9CED2")
	s.rects([(x + 2 + i * 6, y + 2 + j * 6, 2, 2) for i in range(25) for j in range(20)], "A5ABB1", 0.01)
	x, y, w, h = POST
	s.rect(x - 6, y - 6, w + 12, h + 12, "4A5058")
	s.rects([(x + 5, y + 4 + k * 10, 6, 5) for k in range(21)], "15171A", 0.01)
	# Cold-drink cooler: branded sides, vent grille, wire shelves.
	x, y, w, h = FRIDGE_SIDE
	s.rect(x - 6, y - 6, w + 12, h + 12, "EEF1F3")
	s.rect(x + 8, y + 18, w - 16, h - 36, BLUE, 0.01, r=10)
	s.text("THANDA", x + w / 2, y + 48, 15, WHITE, 0.02, "ariblk.ttf", 84)
	s.text("COLD DRINKS", x + w / 2, y + 68, 7, YELLOW, 0.02, "segoeuib.ttf", 84)
	bx = x + w / 2
	s.rect(bx - 11, y + 120, 22, 78, WHITE, 0.02, r=5)
	s.polygon([(bx - 11, y + 122), (bx + 11, y + 122), (bx + 5, y + 104), (bx - 5, y + 104)], WHITE, 0.02)
	s.rect(bx - 5, y + 92, 10, 14, WHITE, 0.02)
	s.rect(bx - 6, y + 86, 12, 7, ORANGE, 0.03)
	s.rect(bx - 11, y + 140, 22, 18, "C7352D", 0.03)
	s.rects([(x + 16, y + 206, 18, 18), (x + 76, y + 200, 18, 18), (x + 30, y + 226, 14, 14)], "BFE3FF", 0.02)
	s.text("CHILLED • FRESH", x + w / 2, y + 252, 6, WHITE, 0.02, "segoeuib.ttf", 84)
	x, y, w, h = GRILLE
	s.rect(x - 6, y - 6, w + 12, h + 12, "1E2124")
	s.rects([(x + 3 + k * 6, y + 3, 3, 10) for k in range(33)], "3A3F45", 0.01)
	x, y, w, h = WIRE
	s.rect(x - 6, y - 6, w + 12, h + 12, "7E878F")
	s.rects([(x - 6, y + 1 + k * 6, w + 12, 2) for k in range(10)], "D5DADF", 0.01)
	s.rects([(x + 2 + k * 25, y - 6, 3, h + 12) for k in range(8)], "E6EAED", 0.02)
	# Carry-bag dispenser and a folded bag.
	x, y, w, h = BAG_BOX_FRONT
	s.rect(x - 6, y - 6, w + 12, h + 12, WHITE)
	s.rect(x - 6, y + 70, w + 12, 36, GREEN, 0.01)
	s.text("CARRY BAGS", x + w / 2, y + 28, 16, GREEN_DARK, 0.02, "ariblk.ttf", 150)
	s.text("APNA MART", x + w / 2, y + 52, 10, ORANGE, 0.02, "segoeuib.ttf", 150)
	s.text("Le jao, phir laao!", x + w / 2, y + 85, 9, WHITE, 0.02, "seguibli.ttf", 150)
	x, y, w, h = BAG_BOX_TOP
	s.rect(x - 6, y - 6, w + 12, h + 12, WHITE)
	s.rect(x + 10, y + 16, w - 20, h - 32, YELLOW, 0.01, r=8)
	s.text("APNA MART", x + w / 2, y + h / 2, 12, GREEN_DARK, 0.02, "ariblk.ttf", 104)
	x, y, w, h = FOLDED_BAG
	s.rect(x - 6, y - 6, w + 12, h + 12, GREEN)
	s.rect(x - 6, y - 6, 24, h + 12, WHITE, 0.01)
	s.rects([(x + 13, y + 4 + k * 10, 2, 6) for k in range(10)], "C5CBC2", 0.02)
	s.rect(x + w - 12, y - 6, 3, h + 12, GREEN_DARK, 0.01)
	cx, cy = x + 76, y + h / 2
	s.rect(cx - 38, cy - 25, 76, 50, WHITE, 0.02, r=9)
	s.rect(cx - 35, cy - 22, 70, 44, ORANGE, 0.03, r=7)
	s.text("APNA", cx, cy - 9, 10, WHITE, 0.04, "ariblk.ttf", 60)
	s.text("MART", cx, cy + 9, 10, WHITE, 0.04, "ariblk.ttf", 60)

# ---------- models
def counter(b):
	# Kick plinth recessed 3 cm; cabinet with the printed front to the customer (-y).
	b.box((0, 0, 0.05), (2.74, 0.64, 0.1), {"+z": None, "-z": None, "rest": "kick"})
	b.box((0, 0, 0.45), (2.8, 0.7, 0.7), {"-y": COUNTER_FRONT, "+x": COUNTER_END, "-x": COUNTER_END, "+y": "wood_dark", "+z": None, "-z": None})
	# Black granite top, 5 cm overhang, top at 0.88 m.
	b.box((0, 0, 0.84), (2.9, 0.8, 0.08), {"+z": GRANITE, "rest": "granite_edge"})
	# Cashier side (+y): a drawer row (locked cash drawer in the middle) over four cupboards.
	for x in (-0.93, 0.0, 0.93):
		b.box((x, 0.36, 0.7), (0.86, 0.02, 0.14), "wood")
		b.box((x, 0.38, 0.7), (0.16, 0.02, 0.022), "chrome")
	b.box((0, 0.375, 0.748), (0.03, 0.012, 0.03), "chrome")
	for k, x in enumerate((-1.05, -0.35, 0.35, 1.05)):
		b.box((x, 0.36, 0.36), (0.68, 0.02, 0.46), "wood")
		b.box((x + (0.29 if k % 2 == 0 else -0.29), 0.38, 0.42), (0.022, 0.02, 0.09), "chrome")
	# UPI QR card on the customer's corner of the top.
	b.box((1.32, -0.22, 0.886), (0.12, 0.07, 0.012), "kick")
	b.box((1.32, -0.2, 0.97), (0.11, 0.012, 0.16), {"-y": QR, "rest": "acrylic"})

def rack(b):
	# Base deck with a light kick plate, pegboard back, end frames printed outside.
	b.box((0, 0, 0.07), (0.58, 2.04, 0.14), {"+x": "lip", "+z": "shelf", "-z": None, "rest": "steel"})
	b.box((-0.285, 0, 0.98), (0.03, 2.04, 1.68), {"+x": PEGBOARD, "-x": PEGBOARD, "rest": "steel"})
	for sy in (-1, 1):
		outside = "+y" if sy > 0 else "-y"
		b.box((-0.005, sy * 1.0375, 0.92), (0.585, 0.035, 1.84), {outside: RACK_END, "-z": None, "rest": "steel_light"})
		b.box((0.29, sy * 1.0275, 0.92), (0.04, 0.055, 1.84), {"+x": POST, "-z": None, "rest": "steel"})
	# Shelves at the game's heights (items stand at 0.26 + level * 0.55), each with a price strip.
	for level in range(3):
		z = 0.22 + level * 0.55
		b.box((-0.005, 0, z), (0.555, 2.0, 0.035), {"+z": "shelf", "rest": "lip"})
		b.box((0.285, 0, z - 0.012), (0.03, 2.0, 0.065), {"+x": "price", "rest": "lip"})
	b.box((0, 0, 1.82), (0.62, 2.12, 0.04), "steel")

def fridge(b):
	b.box((0.005, 0, 0.07), (0.72, 2.16, 0.14), {"+x": GRILLE, "-z": None, "rest": "base"})
	b.box((-0.32, 0, 1.07), (0.06, 2.16, 1.86), {"+x": "fridge_inner", "rest": "fridge"})
	for sy in (-1, 1):
		outside, inside = ("+y", "-y") if sy > 0 else ("-y", "+y")
		b.box((0, sy * 1.05, 1.07), (0.72, 0.06, 1.86), {outside: FRIDGE_SIDE, inside: "fridge_inner", "rest": "fridge"})
	b.box((0, 0, 2.05), (0.72, 2.16, 0.1), "fridge")
	b.box((0, 0, 0.15), (0.6, 2.04, 0.02), "fridge_inner")
	for level in range(3):
		z = 0.22 + level * 0.55
		b.box((-0.01, 0, z), (0.58, 2.02, 0.012), {"+z": WIRE, "rest": "chrome"})
		b.box((0.275, 0, z + 0.012), (0.012, 2.02, 0.012), "chrome")
	# Two door frames round the game's glass, a gasket between them, handles at the middle.
	for sy in (-1, 1):
		yc = sy * 0.52
		for z in (0.175, 1.765): b.box((0.355, yc, z), (0.045, 1.0, 0.05), "chrome")
		for dy in (-0.48, 0.48): b.box((0.355, yc + dy, 0.97), (0.045, 0.04, 1.54), "chrome")
		b.box((0.4, sy * 0.08, 1.0), (0.02, 0.025, 0.5), "chrome")
		for z in (0.78, 1.22): b.box((0.385, sy * 0.08, z), (0.03, 0.02, 0.02), "chrome")
	b.box((0.355, 0, 0.97), (0.05, 0.03, 1.64), "gasket")

def carton(b):
	b.box((0, 0, 0), (0.8, 0.8, 0.8), {"-y": CARTON_FRONT, "+y": CARTON_FRONT, "+x": CARTON_SIDE, "-x": CARTON_SIDE, "+z": CARTON_TOP, "-z": CARTON_TOP})

def bag_box(b):
	b.box((0, 0, 0.01), (0.32, 0.24, 0.02), "white")
	for sx in (-1, 1): b.box((sx * 0.16, 0, 0.1), (0.02, 0.24, 0.2), "white")
	b.box((0, -0.12, 0.1), (0.34, 0.02, 0.2), {"-y": BAG_BOX_FRONT, "rest": "white"})
	b.box((0, 0, 0.2), (0.34, 0.26, 0.02), {"+z": BAG_BOX_TOP, "rest": "white"})

def folded_bag(b):
	b.box((0, 0, 0.007), (0.28, 0.2, 0.014), {"+z": FOLDED_BAG, "-z": None, "rest": "green"})

MODELS = {"counter": counter, "rack": rack, "fridge": fridge, "carton": carton, "bag_box": bag_box, "folded_bag": folded_bag}

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "shop")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
sheet = Sheet(ATLAS, SWATCHES, 912, cell=48)
draw_print(sheet)
png = os.path.join(out_dir, "shop_fixtures_print.png")
sheet.render(png)
mat = material("ShopFixtures", png)
objects = {}
for name, build in MODELS.items():
	b = Builder(sheet)
	build(b)
	objects[name] = b.to_object(name.title().replace("_", ""), mat)
	export_glb(objects[name], os.path.join(out_dir, name + ".glb"))
# A lineup for viewing: counter with its bag stand, a rack and the fridge facing the camera, a carton.
objects["rack"].location, objects["rack"].rotation_euler.z = (2.4, 0.6, 0), -math.pi / 2
objects["fridge"].location, objects["fridge"].rotation_euler.z = (4.9, 0.6, 0), -math.pi / 2
objects["carton"].location = (-2.1, -0.3, 0.4)
objects["bag_box"].location = (-1.22, 0.22, 0.88)
objects["folded_bag"].location = (-1.22, 0.22, 0.9)
if render: preview(render, (1.2, -6.2, 2.6), (1.4, 0.3, 0.8), size=(1400, 700), lens=40)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "shop_fixtures.blend"))
print("SAVED", os.path.join(source, "shop_fixtures.blend"))
