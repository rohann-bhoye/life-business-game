# Builds the shelf products with printed labels, all sharing one atlas (products_print.png):
#   bottle.glb (cold drink PET bottle), snack.glb (namkeen pouch), soap.glb (neem soap pack),
#   oil.glb (mustard oil bottle), milk.glb (milk pouch), bread.glb (bagged pav loaf),
#   chocolate.glb (chocolate box), honey.glb (glass jar with wrap label)
# Bottom centre at the origin, label facing -Y (the game's +Z). Sizes are natural; the game
# fits each model into its shelf box (product_assets.gd).
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_products.py -- <project dir> [--render out.png]
# Writes assets/products/custom/*.glb, products_print.png and source/products.blend.
import bpy, os, sys, math
from mathutils import Vector
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

ATLAS = 2048
BLACK_INK, WHITE, CREAM = "1E1B1A", "F6F4EE", "FFF1CC"
SWATCHES = {
	"cola": "3A2012", "white": WHITE, "pet": "C9DEE0", "foil": "CFCFCF", "red_cap": "D12B2B",
	"honey": "E39A18", "lid_gold": "D8A32A", "oil_amber": "D9A21B", "oil_cap": "E0332B",
	"choc_box": "5B2A86", "choc_gold": "D9B24A", "soap_green": "2E9A52", "pouch_red": "B72E22",
	"pouch_blue": "245AB0", "bread_bag": "E9D3A0", "bread_tie": "2B5FAF", "black": "222222",
}

# Atlas regions in pixels (x, y from the top-left, w, h)
BOTTLE_LABEL = (0, 0, 768, 306)
HONEY_LABEL = (0, 322, 768, 163)
SNACK_FRONT = (800, 0, 260, 341)
SNACK_BACK = (1076, 0, 260, 341)
MILK_FRONT = (1352, 0, 240, 340)
MILK_BACK = (1608, 0, 240, 340)
OIL_FRONT = (0, 500, 230, 431)
OIL_BACK = (246, 500, 230, 431)
BREAD_FRONT = (500, 500, 400, 220)
CHOC_FRONT = (920, 500, 230, 322)
SOAP_FRONT = (1170, 500, 300, 195)
SWATCH_Y = 1200

# ---------- print
def lines(s, x, y, w, count, colour, gap=14, h=5, z=0.05):
	s.rects([(x, y + k * gap, w - (k % 3) * 18, h) for k in range(count)], colour, z)

def barcode(s, x, y, w, h):
	s.rect(x, y, w, h, WHITE, 0.05)
	bars, cx, k = [], x + 8, 0
	while cx < x + w - 10:
		bw = 2 + (k * 7 % 4)
		bars.append((cx, y + 6, bw, h - 18))
		cx += bw + 2 + (k * 5 % 3)
		k += 1
	s.rects(bars, BLACK_INK, 0.06)

def crimp(s, x, y, w, h, colour):
	s.rect(x, y, w, h, colour, 0.02)
	s.rects([(x + 4, y + 4 + k * 5, w - 8, 2) for k in range(max(1, int(h / 5) - 1))], "00000040"[:6], 0.03)

def draw_print(s):
	# --- cold drink wrap label
	x, y, w, h = BOTTLE_LABEL
	s.rect(x, y, w, h, "D12B2B", 0.0)
	s.rect(x, y + 14, w, 12, "F4C443", 0.01)
	s.rect(x, y + h - 26, w, 12, "F4C443", 0.01)
	for cx in (384,):
		s.polygon([(cx - 150, y + 150), (cx - 60, y + 100), (cx + 40, y + 190), (cx + 150, y + 120), (cx + 150, y + 160),
			(cx + 40, y + 235), (cx - 60, y + 150), (cx - 150, y + 200)], "9E1B1B", 0.02)
	s.text("ZING", 384, y + 100, 84, WHITE, 0.05, "ariblk.ttf", 210)
	s.text("COLA", 384, y + 190, 54, "F4C443", 0.05, "ariblk.ttf", 170)
	s.text("600 ml", 384, y + 255, 26, WHITE, 0.05, "arialbd.ttf", 110)
	s.text("ZING", 80, y + 150, 40, WHITE, 0.05, "ariblk.ttf", 110)
	s.text("ZING", 690, y + 150, 40, WHITE, 0.05, "ariblk.ttf", 110)

	# --- honey jar wrap label
	x, y, w, h = HONEY_LABEL
	s.rect(x, y, w, h, CREAM, 0.0)
	s.rect(x, y, w, 12, "B77A12", 0.01)
	s.rect(x, y + h - 12, w, 12, "B77A12", 0.01)
	s.text("PURE HONEY", 384, y + 62, 46, "7A4A0C", 0.05, "ariblk.ttf", 250)
	s.text("SHAHAD - 500 g", 384, y + 120, 22, "7A4A0C", 0.05, "arialbd.ttf", 190)
	for hx in (90, 678):
		s.polygon([(hx, y + 40), (hx + 26, y + 58), (hx + 26, y + 98), (hx, y + 116), (hx - 26, y + 98), (hx - 26, y + 58)], "E39A18", 0.03)

	# --- namkeen pouch front and back (crimped top and bottom 12 %)
	x, y, w, h = SNACK_FRONT
	s.rect(x, y, w, h, "D9382B", 0.0)
	crimp(s, x, y, w, 36, "A92A20")
	crimp(s, x, y + h - 36, w, 36, "A92A20")
	s.polygon([(x + 130 + 96 * math.cos(math.radians(a * 15)), y + 170 + 96 * math.sin(math.radians(a * 15)) * (1 if a % 2 else 0.86))
		for a in range(24)], "F4C443", 0.02)
	s.text("MASALA", x + 130, y + 148, 36, "B72E22", 0.05, "ariblk.ttf", 170)
	s.text("CRUNCH", x + 130, y + 190, 36, "B72E22", 0.05, "ariblk.ttf", 170)
	s.text("NAMKEEN", x + 130, y + 262, 26, WHITE, 0.05, "arialbd.ttf", 180)
	s.text("NET WT 100 g", x + 130, y + 300, 15, WHITE, 0.05, "arialbd.ttf", 130)
	x, y, w, h = SNACK_BACK
	s.rect(x, y, w, h, "A92A20", 0.0)
	crimp(s, x, y, w, 36, "7E1F18")
	crimp(s, x, y + h - 36, w, 36, "7E1F18")
	s.text("INGREDIENTS", x + 130, y + 70, 14, WHITE, 0.05, "arialbd.ttf", 150)
	lines(s, x + 24, y + 90, w - 48, 8, "F2C9C5")
	barcode(s, x + 70, y + 226, 120, 60)

	# --- milk pouch front and back
	x, y, w, h = MILK_FRONT
	s.rect(x, y, w, h, "2F6FD0", 0.0)
	crimp(s, x, y, w, 36, "1F4F9A")
	crimp(s, x, y + h - 36, w, 36, "1F4F9A")
	s.polygon([(x, y + 215), (x + 60, y + 190), (x + 120, y + 215), (x + 180, y + 240), (x + w, y + 215), (x + w, y + h - 36), (x, y + h - 36)], WHITE, 0.02)
	s.polygon([(x + 120, y + 62), (x + 150, y + 110), (x + 144, y + 140), (x + 120, y + 152), (x + 96, y + 140), (x + 90, y + 110)], WHITE, 0.03)
	s.text("APNA DAIRY", x + 120, y + 175, 18, WHITE, 0.05, "arialbd.ttf", 170)
	s.text("FRESH MILK", x + 120, y + 244, 30, "1F4F9A", 0.05, "ariblk.ttf", 200)
	s.text("TONED - 500 ml", x + 120, y + 284, 16, "2F6FD0", 0.05, "arialbd.ttf", 160)
	x, y, w, h = MILK_BACK
	s.rect(x, y, w, h, "1F4F9A", 0.0)
	crimp(s, x, y, w, 36, "163A72")
	crimp(s, x, y + h - 36, w, 36, "163A72")
	s.text("TONED MILK", x + 120, y + 70, 16, WHITE, 0.05, "arialbd.ttf", 150)
	lines(s, x + 24, y + 90, w - 48, 8, "C5D6F0")
	barcode(s, x + 60, y + 226, 120, 60)

	# --- mustard oil bottle label (the amber oil shows above it)
	x, y, w, h = OIL_FRONT
	s.rect(x, y, w, h, "D9A21B", 0.0)
	s.rect(x, y + 80, w, h - 80, "F2B91D", 0.01)
	s.rect(x, y + 80, w, 44, "C8231B", 0.02)
	s.text("KACHI GHANI", x + 115, y + 102, 20, WHITE, 0.05, "arialbd.ttf", 190)
	s.text("SARSON", x + 115, y + 190, 42, "9A1B15", 0.05, "ariblk.ttf", 200)
	s.text("MUSTARD OIL", x + 115, y + 240, 22, "1E1B1A", 0.05, "arialbd.ttf", 200)
	s.rect(x + 50, y + 290, 130, 70, WHITE, 0.03, r=14)
	s.text("1 LITRE", x + 115, y + 325, 22, "C8231B", 0.05, "ariblk.ttf", 110)
	x, y, w, h = OIL_BACK
	s.rect(x, y, w, h, "F2B91D", 0.0)
	s.rect(x, y + 80, w, 44, "C8231B", 0.02)
	lines(s, x + 24, y + 150, w - 48, 8, "6B4A08")
	barcode(s, x + 55, y + 300, 120, 60)

	# --- bread bag (clear bag, blue label band)
	x, y, w, h = BREAD_FRONT
	s.rect(x, y, w, h, "E5C27C", 0.0)
	s.rect(x, y, w, 20, "F2E7C8", 0.01)
	s.rect(x, y + 64, w, 96, "2B5FAF", 0.02)
	s.text("PAV BREAD", x + 200, y + 100, 36, WHITE, 0.05, "ariblk.ttf", 300)
	s.text("FRESH BAKED DAILY", x + 200, y + 140, 14, "F4C443", 0.05, "arialbd.ttf", 260)
	s.rects([(x + 30 + k * 70, y + 176, 40, 4) for k in range(5)], "C99A4A", 0.03)

	# --- chocolate box
	x, y, w, h = CHOC_FRONT
	s.rect(x, y, w, h, "5B2A86", 0.0)
	s.rect(x, y + 20, w, 8, "D9B24A", 0.01)
	s.rect(x, y + h - 28, w, 8, "D9B24A", 0.01)
	s.text("CHOCO", x + 115, y + 90, 46, "D9B24A", 0.05, "ariblk.ttf", 200)
	s.text("MILK CHOCOLATE", x + 115, y + 135, 15, WHITE, 0.05, "arialbd.ttf", 190)
	for r in range(3):
		for c in range(4):
			s.rect(x + 46 + c * 36, y + 170 + r * 30, 32, 26, "6B3A1C" if (r + c) % 2 else "7E4A26", 0.03, r=4)
	s.text("100 g", x + 115, y + 288, 18, WHITE, 0.05, "arialbd.ttf", 80)

	# --- neem soap pack
	x, y, w, h = SOAP_FRONT
	s.rect(x, y, w, h, "2E9A52", 0.0)
	s.polygon([(x, y + 130), (x + 80, y + 108), (x + 170, y + 140), (x + 240, y + 112), (x + w, y + 128), (x + w, y + h), (x, y + h)], "1F7A3E", 0.01)
	s.polygon([(x + 230, y + 30), (x + 276, y + 62), (x + 262, y + 112), (x + 218, y + 100), (x + 200, y + 56)], "7BCB6A", 0.02)
	s.text("NEEM", x + 105, y + 62, 54, WHITE, 0.05, "ariblk.ttf", 190)
	s.text("SOAP", x + 105, y + 122, 38, "F4C443", 0.05, "ariblk.ttf", 140)
	s.text("75 g  -  Herbal", x + 105, y + 170, 16, WHITE, 0.05, "arialbd.ttf", 150)

# ---------- shape helpers
def wrap_lathe(b, rings, label_region, label_ring, seg=24):
	"""Round body from (radius, height) rings with plain swatch bands, except the band after
	rings[label_ring] which prints `label_region` once around, centred on the front (-Y)."""
	rows = []
	for r, z in rings:
		rows.append([b.vert(Vector((r * math.cos(math.radians(-270 + 360 * k / seg)), r * math.sin(math.radians(-270 + 360 * k / seg)), z)))
			for k in range(seg)] if r > 0 else [b.vert(Vector((0, 0, z)))])
	return rows

def lathe_bands(b, rows, bands, label_region=None, label_band=-1, seg=24):
	for k in range(len(rows) - 1):
		a, c = rows[k], rows[k + 1]
		if len(a) == 1 or len(c) == 1:
			for i in range(seg):
				j = (i + 1) % seg
				if len(a) == 1: b.swatch_face((a[0], c[j], c[i]), bands[k])
				else: b.swatch_face((a[i], a[j], c[0]), bands[k])
			continue
		for i in range(seg):
			j = (i + 1) % seg
			idx = (a[i], a[j], c[j], c[i])
			if k == label_band:
				x, y, w, h = label_region
				u0, u1 = x + w * i / seg, x + w * (i + 1) / seg
				b.face(idx, [b.sheet.uv(u0, y + h), b.sheet.uv(u1, y + h), b.sheet.uv(u1, y), b.sheet.uv(u0, y)])
			else:
				b.swatch_face(idx, bands[k])

def pouch(b, w, d, h, rings, front, back, side, top_swatch):
	"""Pillow pouch: rings of (z, half width, half depth) from bottom to top. Front/back print
	maps across the whole height; the ends are closed with one swatch."""
	verts = []
	for z, hw, hd in rings:
		verts.append([b.vert((sx * hw, sy * hd, z)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
	def uv(region, x, z):
		rx, ry, rw, rh = region
		return b.sheet.uv(rx + rw * (0.5 + x / w), ry + rh * (1 - z / h))
	for k in range(len(rings) - 1):
		(za, hwa, hda), (zb, hwb, hdb) = rings[k], rings[k + 1]
		a, c = verts[k], verts[k + 1]
		b.face((a[0], a[1], c[1], c[0]), [uv(front, -hwa, za), uv(front, hwa, za), uv(front, hwb, zb), uv(front, -hwb, zb)])
		b.face((a[2], a[3], c[3], c[2]), [uv(back, hwa, za), uv(back, -hwa, za), uv(back, -hwb, zb), uv(back, hwb, zb)])
		b.swatch_face((a[1], a[2], c[2], c[1]), side)
		b.swatch_face((a[3], a[0], c[0], c[3]), side)
	b.swatch_face(verts[0][::-1], top_swatch)
	b.swatch_face(verts[-1], top_swatch)

# ---------- products
def make_bottle(mat):
	b = Builder(SHEET)
	rings = [(0, 0), (0.030, 0), (0.040, 0.010), (0.040, 0.030), (0.040, 0.140), (0.040, 0.168), (0.017, 0.207), (0.015, 0.224), (0.0, 0.224)]
	rows = wrap_lathe(b, rings, BOTTLE_LABEL, 3)
	lathe_bands(b, rows, ["cola", "pet", "cola", "label", "cola", "pet", "pet", "pet"], BOTTLE_LABEL, 3)
	return b.to_object("Bottle", mat, bevel=0)

def make_honey(mat):
	b = Builder(SHEET)
	rings = [(0, 0), (0.036, 0), (0.040, 0.006), (0.040, 0.022), (0.040, 0.078), (0.040, 0.088), (0.030, 0.098), (0.030, 0.101),
		(0.034, 0.101), (0.034, 0.118), (0.0, 0.118)]
	rows = wrap_lathe(b, rings, HONEY_LABEL, 3)
	lathe_bands(b, rows, ["pet", "pet", "honey", "label", "honey", "honey", "lid_gold", "lid_gold", "lid_gold", "lid_gold"], HONEY_LABEL, 3)
	return b.to_object("Honey", mat, bevel=0)

def make_snack(mat):
	w, d, h = 0.16, 0.05, 0.26
	b = Builder(SHEET)
	rings = [(0, 0.080, 0.003), (0.030, 0.080, 0.004), (0.060, 0.078, 0.022), (0.130, 0.080, 0.027), (0.200, 0.078, 0.022),
		(0.230, 0.080, 0.004), (0.260, 0.080, 0.003)]
	pouch(b, w, d, h, rings, SNACK_FRONT, SNACK_BACK, "pouch_red", "pouch_red")
	return b.to_object("Snack", mat, bevel=0)

def make_milk(mat):
	w, d, h = 0.12, 0.05, 0.19
	b = Builder(SHEET)
	rings = [(0, 0.060, 0.003), (0.022, 0.060, 0.004), (0.050, 0.058, 0.022), (0.095, 0.060, 0.027), (0.140, 0.058, 0.022),
		(0.168, 0.060, 0.004), (0.19, 0.060, 0.003)]
	pouch(b, w, d, h, rings, MILK_FRONT, MILK_BACK, "pouch_blue", "pouch_blue")
	return b.to_object("Milk", mat, bevel=0)

def make_bread(mat):
	w, d, h = 0.20, 0.10, 0.11
	b = Builder(SHEET)
	rings = [(0, 0.098, 0.04), (0.012, 0.100, 0.046), (0.060, 0.100, 0.050), (0.085, 0.096, 0.047), (0.102, 0.080, 0.038), (0.110, 0.055, 0.024)]
	pouch(b, w, d, h, rings, BREAD_FRONT, BREAD_FRONT, "bread_bag", "bread_bag")
	# gathered bag tail with a blue clip at the right-hand end
	b.box((0.108, 0, 0.055), (0.026, 0.026, 0.05), "bread_bag")
	b.box((0.118, 0, 0.055), (0.012, 0.034, 0.05), "bread_tie")
	return b.to_object("Bread", mat, bevel=0.002)

def make_soap(mat):
	b = Builder(SHEET)
	b.box((0, 0, 0.0325), (0.10, 0.04, 0.065), {"-y": SOAP_FRONT, "+y": SOAP_FRONT, "rest": "soap_green"})
	return b.to_object("Soap", mat, bevel=0.0025)

def make_chocolate(mat):
	b = Builder(SHEET)
	b.box((0, 0, 0.07), (0.10, 0.03, 0.14), {"-y": CHOC_FRONT, "+y": CHOC_FRONT, "rest": "choc_box"})
	return b.to_object("Chocolate", mat, bevel=0.0025)

def make_oil(mat):
	b = Builder(SHEET)
	b.box((0, 0, 0.075), (0.08, 0.056, 0.15), {"-y": OIL_FRONT, "+y": OIL_BACK, "rest": "oil_amber"})
	b.box((0, 0, 0.16), (0.058, 0.042, 0.02), "oil_amber")
	rows = []
	for r, z in ((0.014, 0.17), (0.014, 0.205), (0.0, 0.205)):
		rows.append([b.vert((r * math.cos(2 * math.pi * k / 12), r * math.sin(2 * math.pi * k / 12), z)) for k in range(12)] if r > 0 else [b.vert((0, 0, z))])
	b.quad_strip(rows[0], rows[1], "oil_amber")
	cap_rows = []
	for r, z in ((0.0175, 0.203), (0.0175, 0.222), (0.0, 0.222)):
		cap_rows.append([b.vert((r * math.cos(2 * math.pi * k / 12), r * math.sin(2 * math.pi * k / 12), z)) for k in range(12)] if r > 0 else [b.vert((0, 0, z))])
	b.quad_strip(cap_rows[0], cap_rows[1], "oil_cap")
	for i in range(12): b.swatch_face((cap_rows[1][i], cap_rows[1][(i + 1) % 12], cap_rows[2][0]), "oil_cap")
	return b.to_object("Oil", mat, bevel=0.003)

project, render = project_args()
out_dir = os.path.join(project, "assets", "products", "custom")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(ATLAS, SWATCHES, SWATCH_Y)
draw_print(SHEET)
png = os.path.join(out_dir, "products_print.png")
SHEET.render(png)
mat = material("Products", png, roughness=0.4)

# "label" in a band list means the printed span; lathe_bands swaps it for the region.
BUILDERS = {"bottle": make_bottle, "snack": make_snack, "soap": make_soap, "oil": make_oil, "milk": make_milk,
	"bread": make_bread, "chocolate": make_chocolate, "honey": make_honey}
objects = []
for pid, fn in BUILDERS.items():
	ob = fn(mat)
	export_glb(ob, os.path.join(out_dir, pid + ".glb"))
	objects.append(ob)
for i, ob in enumerate(objects):
	ob.location.x = (i - len(objects) / 2) * 0.17
if render: preview(render, (0, -2.1, 0.5), (0, 0, 0.1), size=(1600, 560), lens=70)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "products.blend"))
print("SAVED", os.path.join(source, "products.blend"))
