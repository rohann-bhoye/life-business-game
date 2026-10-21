# Builds the APNA MART carry bag props: a green non-woven shop bag with a sewn white
# hem, side gussets, two loop handles and a printed front and back. Two models share
# one texture atlas (rendered here from text and shapes):
#   carry_bag.glb       empty and open, in the shopkeeper's hand while filling an order
#   carry_bag_full.glb  packed (bread, chips, cold drink, dhaniya), on the counter and
#                       with customers on their way out
# Both keep the old in-game bag size: 0.26 x 0.11 x 0.30 m body, handles up to ~0.40 m,
# bottom centre at the origin, print facing +Z in Godot (-Y here).
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_carry_bag.py -- <project dir> [--render out.png]
# Writes assets/props/carry_bag/carry_bag.glb, carry_bag_full.glb, carry_bag_print.png
# (shared by both, kept outside the .glb files) and source/carry_bag.blend (editable).
import bpy, os, sys, math, random
from mathutils import Vector
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

W, D, H = 0.26, 0.11, 0.30   # body width (x), depth (y), height (z)
HEM = 0.035                   # white folded hem at the top
WALL = 0.004                  # fabric thickness
ATLAS = 1024

# ---------- palette (sRGB hex)
GREEN, GREEN_DARK, INSIDE = "2F9A5C", "21774A", "1C5E3A"
WHITE, ORANGE, YELLOW, STITCH = "F4F3EE", "F0892A", "F4C443", "C5CBC2"
SWATCHES = {
	"body": GREEN, "base": GREEN_DARK, "inside": INSIDE, "hem": WHITE, "handle": "268550",
	"bread": "E2B878", "bread_band": "3D7BD9", "chips": "E8642B", "chips_band": YELLOW,
	"drink": "C7352D", "cap": WHITE, "leaf": "4FA33A", "leaf_dark": "2E7D32",
}

# Atlas regions in pixels (x, y from the top-left, w, h); the bag front is 0.26 x 0.30 m.
FRONT = (0, 0, 440, 508)
BACK = (456, 0, 440, 508)
SIDE = (912, 0, 96, 508)

# ---------- print: front badge, back reuse note, plain gussets
def panel_base(s, region, seams=True):
	x, y, w, h = region
	hem_px = HEM / H * h
	s.rect(x - 8, y - 8, w + 16, h + 16, GREEN, 0.0)
	s.rect(x - 8, y - 8, w + 16, hem_px + 8, WHITE, 0.01)
	s.rect(x - 8, y + hem_px, w + 16, 7, ORANGE, 0.01)
	dashes = range(int((w - 12) / 22) + 1)
	s.rects([(x + 6 + k * 22, y + hem_px - 9, 12, 3) for k in dashes], STITCH, 0.02)  # stitch line along the hem fold
	s.rect(x - 8, y + h - 36, w + 16, 44, GREEN_DARK, 0.01)
	s.rects([(x + 6 + k * 22, y + h - 44, 12, 3) for k in dashes], GREEN_DARK, 0.02)
	if seams:
		s.rect(x - 8, y + hem_px + 7, 13, h - hem_px - 43, GREEN_DARK, 0.01)
		s.rect(x + w - 5, y + hem_px + 7, 13, h - hem_px - 43, GREEN_DARK, 0.01)

def draw_print(s):
	# Front: the APNA MART badge, the tagline and a thank-you.
	fx, fy, fw, fh = FRONT
	panel_base(s, FRONT)
	cx = fx + fw / 2
	s.rect(cx - 160, fy + 110, 320, 192, WHITE, 0.03, r=32)
	s.rect(cx - 152, fy + 118, 304, 176, ORANGE, 0.04, r=26)
	s.text("APNA", cx, fy + 172, 60, WHITE, 0.05, "ariblk.ttf", 270)
	s.text("MART", cx, fy + 246, 60, WHITE, 0.05, "ariblk.ttf", 270)
	s.text("DAILY NEEDS  \u2022  FRESH  \u2022  SASTA", cx, fy + 338, 17, WHITE, 0.05, "segoeuib.ttf", 390)
	s.rect(cx - 60, fy + 362, 120, 4, YELLOW, 0.05)
	s.text("Shukriya! Phir aana", cx, fy + 404, 30, WHITE, 0.05, "seguibli.ttf", 380)
	# Back: name, reuse note.
	bx, by, bw, bh = BACK
	panel_base(s, BACK)
	cx = bx + bw / 2
	s.text("APNA MART", cx, by + 150, 44, WHITE, 0.05, "ariblk.ttf", 380)
	s.rect(cx - 100, by + 186, 200, 8, ORANGE, 0.05)
	s.text("Your daily kirana", cx, by + 248, 26, WHITE, 0.05, "segoeuib.ttf", 380)
	s.text("REUSABLE BAG", cx, by + 312, 22, YELLOW, 0.05, "segoeuib.ttf", 380)
	s.text("Use me again!", cx, by + 352, 24, WHITE, 0.05, "seguibli.ttf", 380)
	# Side gusset: plain, with the fold crease down the middle.
	sx, sy, sw, sh = SIDE
	panel_base(s, SIDE, seams=False)
	s.rect(sx + sw / 2 - 2, sy + HEM / H * sh + 7, 4, sh - HEM / H * sh - 43, GREEN_DARK, 0.02)
# ---------- the bag body
FRONT_SEG = 8
LEVELS = [0.0, 0.035, 0.09, 0.15, 0.21, H - HEM - 0.002, H - HEM, H]

def perimeter(w, d):
	"""Front (x rising at -y), right gusset middle, back (x falling at +y), left middle."""
	pts = [(-w / 2 + w * k / FRONT_SEG, -d / 2, "front") for k in range(FRONT_SEG + 1)]
	pts.append((w / 2, 0.0, "right"))
	pts += [(w / 2 - w * k / FRONT_SEG, d / 2, "back") for k in range(FRONT_SEG + 1)]
	pts.append((-w / 2, 0.0, "left"))
	return pts

def shape(x0, y0, z0, full, hem_push):
	"""Undeformed rectangle point -> bag surface point (belly, gusset fold, open top)."""
	t = z0 / H
	sx, sy = x0 / (W / 2), y0 / (D / 2)
	belly = math.sin(math.pi * t) ** 0.8 if t > 0 else 0.0
	x, y = x0, y0
	if abs(sy) > 0.99:  # front / back panels bulge out
		y += math.copysign((0.02 if full else 0.007) * (1 - sx * sx) * belly, y0)
	elif abs(sy) < 0.01:  # gusset middle: folded in when empty, pushed out when packed
		x += math.copysign(0.006 * belly if full else -0.03 * t ** 0.7, x0)
	if full:
		x *= 1 - 0.035 * t * t
	else:
		y *= 1 - 0.16 * t ** 1.5
	if hem_push:
		x += math.copysign(0.0015, x) if abs(sx) > 0.99 else 0.0
		y += math.copysign(0.0015, y) if abs(y0) > 1e-6 else 0.0
	return Vector((x, y, z0))

def panel_uv(region, u, z):
	x, y, w, h = region
	return SHEET.uv(x + u * w, y + (1 - z / H) * h)

def build_body(b, full, rng):
	outer = perimeter(W, D)
	n = len(outer)
	rings = []
	for j, z in enumerate(LEVELS):
		hem = j >= len(LEVELS) - 2
		ring = []
		for x0, y0, _ in outer:
			p = shape(x0, y0, z, full, hem)
			if 0 < j < len(LEVELS) - 3:  # soft fabric wrinkles, rims kept clean
				p += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.5, 0.5))) * 0.0012
			ring.append(b.vert(p))
		rings.append(ring)
	# Outer walls, printed by panel.
	for j in range(len(LEVELS) - 1):
		for i in range(n):
			k = (i + 1) % n
			side = "front" if i < FRONT_SEG else "right" if i <= FRONT_SEG + 1 else "back" if i < 2 * FRONT_SEG + 2 else "left"
			uvs = []
			for idx, z in ((i, LEVELS[j]), (k, LEVELS[j]), (k, LEVELS[j + 1]), (i, LEVELS[j + 1])):
				x0, y0, _ = outer[idx]
				if side == "front": uvs.append(panel_uv(FRONT, (x0 + W / 2) / W, z))
				elif side == "back": uvs.append(panel_uv(BACK, (W / 2 - x0) / W, z))
				elif side == "right": uvs.append(panel_uv(SIDE, (y0 + D / 2) / D, z))
				else: uvs.append(panel_uv(SIDE, (D / 2 - y0) / D, z))
			b.face((rings[j][i], rings[j][k], rings[j + 1][k], rings[j + 1][i]), uvs)
	# Outer bottom: front row -> middle row -> back row.
	mid = [rings[0][2 * FRONT_SEG + 3]] + [b.vert(shape(-W / 2 + W * k / FRONT_SEG, 0.0, 0.0, full, False)) for k in range(1, FRONT_SEG)] + [rings[0][FRONT_SEG + 1]]
	front_row = [rings[0][k] for k in range(FRONT_SEG + 1)]
	back_row = [rings[0][2 * FRONT_SEG + 2 - k] for k in range(FRONT_SEG + 1)]
	for k in range(FRONT_SEG):
		b.swatch_face((front_row[k], mid[k], mid[k + 1], front_row[k + 1]), "base")
		b.swatch_face((mid[k], back_row[k], back_row[k + 1], mid[k + 1]), "base")
	# Inner shell: the same shape a wall thickness inside, floor raised by it.
	inner_rings = []
	inner = perimeter(W - 2 * WALL, D - 2 * WALL)
	for j, z in enumerate(LEVELS):
		zi = max(z, WALL)
		ring = []
		for (x0, y0, _), outer_idx in zip(inner, rings[j]):
			p = shape(x0, y0, zi, full, j >= len(LEVELS) - 2)
			if 0 < j < len(LEVELS) - 3: p += (b.verts[outer_idx] - shape(*outer[len(ring)][:2], z, full, False)) * 1.0
			ring.append(b.vert(p))
		inner_rings.append(ring)
	for j in range(len(LEVELS) - 1):
		b.quad_strip(inner_rings[j + 1], inner_rings[j], "inside")
	mid_i = [inner_rings[0][2 * FRONT_SEG + 3]] + [b.vert(shape(-(W - 2 * WALL) / 2 + (W - 2 * WALL) * k / FRONT_SEG, 0.0, WALL, full, False)) for k in range(1, FRONT_SEG)] + [inner_rings[0][FRONT_SEG + 1]]
	front_i = [inner_rings[0][k] for k in range(FRONT_SEG + 1)]
	back_i = [inner_rings[0][2 * FRONT_SEG + 2 - k] for k in range(FRONT_SEG + 1)]
	for k in range(FRONT_SEG):
		b.swatch_face((front_i[k], front_i[k + 1], mid_i[k + 1], mid_i[k]), "inside")
		b.swatch_face((mid_i[k], mid_i[k + 1], back_i[k + 1], back_i[k]), "inside")
	# Rim: the top edge of the hem.
	b.quad_strip(rings[-1], inner_rings[-1], "hem")
	return shape(0, -(D - 2 * WALL) / 2, H, full, True).y

# ---------- handles: flat straps sewn inside the hem, arching up and leaning together
def strap(b, y_base, lean, a=0.065, rise=0.1, width=0.02, thick=0.003, seg=14):
	path = [Vector((-a, y_base, H - 0.045)), Vector((-a, y_base, H - 0.02))]
	for k in range(seg + 1):
		th = math.pi * k / seg
		path.append(Vector((-a * math.cos(th), y_base * (1 - lean * math.sin(th)), H + rise * math.sin(th))))
	path += [Vector((a, y_base, H - 0.02)), Vector((a, y_base, H - 0.045))]
	rings = []
	for k, p in enumerate(path):
		t = (path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]).normalized()
		wd = t.cross(Vector((0, 1, 0))).normalized()
		td = wd.cross(t).normalized()
		rings.append([b.vert(p + wd * sw * width / 2 + td * st * thick / 2) for sw, st in ((-1, -1), (-1, 1), (1, 1), (1, -1))])
	for k in range(len(rings) - 1):
		b.quad_strip(rings[k], rings[k + 1], "handle")
	b.swatch_face(rings[0][::-1], "handle")
	b.swatch_face(rings[-1], "handle")

# ---------- groceries for the packed bag
ICO = None
def blob(b, centre, radius, squash, name, rng):
	global ICO
	if ICO is None:
		p = (1 + 5 ** 0.5) / 2
		verts = [(-1, p, 0), (1, p, 0), (-1, -p, 0), (1, -p, 0), (0, -1, p), (0, 1, p), (0, -1, -p), (0, 1, -p), (p, 0, -1), (p, 0, 1), (-p, 0, -1), (-p, 0, 1)]
		faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
			(3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
		ICO = ([Vector(v).normalized() for v in verts], faces)
	idx = [b.vert(Vector(centre) + Vector((v.x, v.y, v.z * squash)) * radius * rng.uniform(0.85, 1.1)) for v in ICO[0]]
	for f in ICO[1]: b.swatch_face([idx[i] for i in f], name)

def groceries(b, rng):
	# Sliced bread in its printed wrapper, standing at the left, blue band above the rim.
	b.box((-0.072, 0.004, 0.245), (0.092, 0.078, 0.21), "bread", 4)
	b.box((-0.072, 0.004, 0.318), (0.094, 0.08, 0.028), "bread_band", 4)
	# Chips packet with a crimped top.
	b.box((0.008, -0.022, 0.245), (0.074, 0.028, 0.15), "chips", -8)
	b.box((0.008, -0.022, 0.326), (0.08, 0.012, 0.014), "chips_band", -8)
	# Cold drink bottle, its neck and cap above the chips.
	b.lathe((0.042, 0.022, 0.18), [(0.022, 0), (0.026, 0.012), (0.026, 0.13), (0.013, 0.175), (0.011, 0.19), (0.0125, 0.19), (0.0125, 0.208), (0, 0.208)],
		["drink", "drink", "drink", "drink", "cap", "cap", "cap"])
	# A bunch of dhaniya at the right: stems with small leafy clusters on top.
	for x, y, turn in ((0.084, -0.012, 0), (0.096, 0.01, 40), (0.078, 0.014, -35), (0.102, -0.024, 20)):
		b.box((x, y, 0.3), (0.006, 0.006, 0.07), "leaf_dark", turn)
	for k in range(9):
		a = 2.4 * k
		r = 0.008 + 0.0035 * k ** 0.5
		blob(b, (0.09 + r * math.cos(a), -0.004 + r * math.sin(a) * 0.9, 0.335 + rng.uniform(-0.008, 0.012)),
			rng.uniform(0.013, 0.018), 0.7, "leaf" if k % 3 else "leaf_dark", rng)

def build_bag(name, full, mat):
	rng = random.Random(7 if full else 3)
	b = Builder(SHEET)
	y_front = build_body(b, full, rng)
	lean = 0.5 if full else 0.85
	strap(b, y_front + 0.002, lean)
	strap(b, -(y_front + 0.002), lean)
	if full: groceries(b, rng)
	return b.to_object(name, mat)

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "carry_bag")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(ATLAS, SWATCHES, 560)
draw_print(SHEET)
png = os.path.join(out_dir, "carry_bag_print.png")
SHEET.render(png)
mat = material("CarryBag", png)
empty_bag = build_bag("CarryBag", False, mat)
full_bag = build_bag("CarryBagFull", True, mat)
export_glb(empty_bag, os.path.join(out_dir, "carry_bag.glb"))
export_glb(full_bag, os.path.join(out_dir, "carry_bag_full.glb"))
empty_bag.location.x, full_bag.location.x = -0.2, 0.2
if render: preview(render, (0.55, -1.15, 0.62), (0, 0, 0.2))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "carry_bag.blend"))
print("SAVED", os.path.join(source, "carry_bag.blend"))
