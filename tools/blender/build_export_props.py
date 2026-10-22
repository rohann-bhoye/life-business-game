# Builds the APNA EXPORT props (international orders), all sharing one printed atlas
# (export_props_print.png):
#   cargo_plane.glb     APNA AIR CARGO turboprop: high wing, two engines, T-tail, gear
#                       (origin on the ground under the wings, nose toward +x)
#   propeller.glb       one cross propeller, spun by the game (origin = hub, disc in y-z)
#   export_terminal.glb cargo terminal: arched hangar, blue roller door toward the
#                       runway, office and APNA EXPORT sign toward the town
#   control_tower.glb   small airfield tower with a glass cab and a beacon
#   packing_table.glb   prepare-order table: tape, parcel scale, label printer, flat cartons
#   parcel.glb          sealed export parcel with the air cargo label (bottom centre)
#   carton_open.glb     open carton with its flaps up, filled at the racks (bottom centre)
#   world_poster.glb    "We ship worldwide" map board for the packing room (centre)
#   supply_shelf.glb    packing supplies: tape rolls, bubble wrap, flat cartons, labels
#                       (floor centre, front toward -y here = the game +z)
# Blender axes: x as in the game, -y = the game's +z, z up.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_export_props.py -- <project dir> [--render out.png]
# Writes assets/props/export/*.glb, export_props_print.png and source/export_props.blend.
import bpy, os, sys, math, random
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

ATLAS = 1024
WHITE, ORANGE, YELLOW, NAVY, BLUE = "F4F3EE", "F0892A", "F4C443", "16294A", "1F6FD1"
KRAFT, INK, SKY, LAND = "C49A63", "4A3420", "BFE3F2", "E7D9AE"
SWATCHES = {
	"white": WHITE, "orange": ORANGE, "blue": BLUE, "navy": NAVY, "steel": "3A3F45",
	"steel_light": "C5CAD0", "tyre": "1E1F22", "glass": "1D3550", "prop": "26282C",
	"roof": "56636F", "cladding": "D7DEE3", "concrete": "B5B3AC", "kraft": KRAFT, "tape": "E2C27E",
	"wood": "8E5A2E", "wood_dark": "5E3A1C", "red": "C7352D", "yellow": YELLOW, "green": "2F9A5C",
}

# Atlas regions (x, y, w, h) in pixels.
PLANE_TITLE = (0, 0, 640, 84)        # 7.0 x 0.62 m fuselage band
PLANE_TAIL = (656, 0, 200, 200)
TERMINAL_SIGN = (0, 100, 640, 112)   # 9.0 x 1.6 m
ROLLER = (656, 216, 200, 200)        # roller door
OFFICE = (0, 228, 640, 112)          # office front: windows and a door
CLADDING = (0, 356, 300, 180)        # ribbed wall
TOWER_GLASS = (316, 356, 300, 110)
PARCEL_LABEL = (632, 432, 230, 172)  # 0.6 x 0.45 parcel front
PARCEL_SIDE = (0, 552, 230, 172)
PARCEL_TOP = (246, 552, 230, 172)
TABLE_TOP = (492, 620, 300, 110)     # 1.8 x 0.8 m butcher block
WORLD = (0, 740, 300, 160)           # 0.9 x 0.6 m poster

# ---------- print
def kraft(s, region, seed):
	x, y, w, h = region
	s.rect(x - 6, y - 6, w + 12, h + 12, KRAFT)
	s.speckle(region, 220, ("B58A55", "CFA673"), ((1, 2), (2, 6)), 0.005, seed)

def plane_icon(s, cx, cy, size, colour, z):
	# A little airliner seen from above, nose up.
	s.rect(cx - size * 0.07, cy - size * 0.5, size * 0.14, size, colour, z, r=size * 0.07)
	s.polygon([(cx, cy - size * 0.1), (cx + size * 0.5, cy + size * 0.08), (cx + size * 0.5, cy + size * 0.16), (cx, cy + size * 0.06), (cx - size * 0.5, cy + size * 0.16), (cx - size * 0.5, cy + size * 0.08)], colour, z)
	s.polygon([(cx, cy + size * 0.3), (cx + size * 0.2, cy + size * 0.46), (cx - size * 0.2, cy + size * 0.46)], colour, z)

def draw_print(s):
	# Fuselage band: blue with the airline name and an orange swoosh.
	x, y, w, h = PLANE_TITLE
	s.rect(x - 6, y - 6, w + 12, h + 12, BLUE)
	s.rect(x - 6, y + h - 16, w + 12, 10, ORANGE, 0.01)
	s.text("APNA AIR CARGO", x + 250, y + 36, 40, WHITE, 0.02, "ariblk.ttf", 470)
	plane_icon(s, x + 560, y + 38, 56, WHITE, 0.02)
	# Tail: orange with a white circle and the plane mark.
	x, y, w, h = PLANE_TAIL
	s.rect(x - 6, y - 6, w + 12, h + 12, ORANGE)
	s.rect(x + 40, y + 50, 120, 120, WHITE, 0.01, r=60, seg=10)
	plane_icon(s, x + 100, y + 110, 84, BLUE, 0.02)
	s.rect(x - 6, y + h - 26, w + 12, 12, NAVY, 0.01)
	# Terminal sign.
	x, y, w, h = TERMINAL_SIGN
	s.rect(x - 6, y - 6, w + 12, h + 12, NAVY)
	s.rect(x + 8, y + 8, w - 16, h - 16, NAVY, 0.005, r=10)
	s.rect(x + 20, y + 18, 76, 76, ORANGE, 0.01, r=16)
	plane_icon(s, x + 58, y + 56, 56, WHITE, 0.02)
	s.text("APNA EXPORT", x + 360, y + 46, 44, WHITE, 0.02, "ariblk.ttf", 500)
	s.text("AIR CARGO TERMINAL  •  INDIA TO THE WORLD", x + 360, y + 88, 16, YELLOW, 0.02, "segoeuib.ttf", 500)
	# Roller door: blue slats, a yellow-black kick band.
	x, y, w, h = ROLLER
	s.rect(x - 6, y - 6, w + 12, h + 12, "2A5DA8")
	s.rects([(x - 6, y + k * 10, w + 12, 3) for k in range(int(h / 10))], "1F4888", 0.01)
	s.rect(x - 6, y + h - 18, w + 12, 24, YELLOW, 0.02)
	s.rects([(x + k * 24, y + h - 18, 12, 24) for k in range(-1, int(w / 24) + 1)], "1E1F22", 0.03)
	# Office front: white wall, a row of windows and a glass door with a step.
	x, y, w, h = OFFICE
	s.rect(x - 6, y - 6, w + 12, h + 12, WHITE)
	for k in range(5):
		s.rect(x + 20 + k * 92, y + 22, 76, 52, "6B7C8A", 0.01, r=3)
		s.rect(x + 24 + k * 92, y + 26, 68, 44, "1D3550", 0.02)
		s.rect(x + 57 + k * 92, y + 26, 2, 44, "6B7C8A", 0.03)
	s.rect(x + 500, y + 14, 90, h - 14, "6B7C8A", 0.01)
	s.rect(x + 506, y + 20, 78, h - 20, "1D3550", 0.02)
	s.rect(x + 544, y + 20, 2, h - 20, "6B7C8A", 0.03)
	s.text("CARGO OFFICE", x + 545, y + 8, 9, NAVY, 0.03, "segoeuib.ttf", 90)
	s.rect(x - 6, y + h - 8, w + 12, 14, ORANGE, 0.02)
	# Ribbed cladding.
	x, y, w, h = CLADDING
	s.rect(x - 6, y - 6, w + 12, h + 12, "D7DEE3")
	s.rects([(x + k * 10, y - 6, 4, h + 12) for k in range(int(w / 10) + 1)], "B9C3CA", 0.01)
	s.rect(x - 6, y + h - 10, w + 12, 16, "8F9AA3", 0.02)
	# Tower glass.
	x, y, w, h = TOWER_GLASS
	s.rect(x - 6, y - 6, w + 12, h + 12, "1D3550")
	s.rects([(x + k * 50, y - 6, 4, h + 12) for k in range(int(w / 50) + 1)], "C5CAD0", 0.01)
	s.rect(x - 6, y + 40, w + 12, 3, "4E7FA8", 0.01)
	# Parcel: label front, taped sides and top.
	x, y, w, h = PARCEL_LABEL
	kraft(s, PARCEL_LABEL, 11)
	s.rect(x + w / 2 - 18, y - 6, 36, h + 12, "E2C27E", 0.01)
	s.rect(x + 20, y + 26, 150, 110, "F7F7F3", 0.02, r=4)
	s.rect(x + 20, y + 26, 150, 26, BLUE, 0.03, r=4)
	s.rect(x + 20, y + 40, 150, 12, BLUE, 0.03)
	s.text("AIR CARGO", x + 95, y + 39, 13, WHITE, 0.04, "ariblk.ttf", 140)
	plane_icon(s, x + 46, y + 84, 34, BLUE, 0.04)
	s.text("APNA", x + 116, y + 72, 15, NAVY, 0.04, "ariblk.ttf", 90)
	s.text("EXPORT", x + 116, y + 92, 12, NAVY, 0.04, "ariblk.ttf", 90)
	rng = random.Random(12)
	bars, bx = [], x + 30
	while bx < x + 160:
		bw = rng.choice((1, 1, 2, 3))
		bars.append((bx, y + 112, bw, 16))
		bx += bw + rng.choice((1, 2, 2, 3))
	s.rects(bars, "1A1A1A", 0.04)
	s.rect(x + 176, y + 110, 46, 30, "C7352D", 0.03, r=3)
	s.text("FRAGILE", x + 199, y + 125, 7, WHITE, 0.04, "ariblk.ttf", 42)
	x, y, w, h = PARCEL_SIDE
	kraft(s, PARCEL_SIDE, 13)
	s.rect(x + w / 2 - 18, y - 6, 36, h + 12, "E2C27E", 0.01)
	s.text("THIS SIDE UP", x + 60, y + 30, 9, INK, 0.02, "segoeuib.ttf", 90)
	s.polygon([(x + 60, y + 44), (x + 72, y + 58), (x + 48, y + 58)], INK, 0.02)
	s.text("APNA EXPORT", x + 115, y + 120, 20, INK, 0.02, "ariblk.ttf", 200)
	s.text("Made in India  •  Air cargo", x + 115, y + 146, 9, INK, 0.02, "segoeuib.ttf", 200)
	x, y, w, h = PARCEL_TOP
	kraft(s, PARCEL_TOP, 14)
	s.rect(x - 6, y + h / 2 - 18, w + 12, 36, "E2C27E", 0.01)
	s.rect(x + w / 2 - 18, y - 6, 36, h + 12, "E2C27E", 0.015)
	# Packing table top: butcher block.
	x, y, w, h = TABLE_TOP
	s.rect(x - 6, y - 6, w + 12, h + 12, "A8743F")
	s.rects([(x - 6, y + k * 14, w + 12, 2) for k in range(1, int(h / 14) + 1)], "8E5A2E", 0.01)
	s.speckle(TABLE_TOP, 60, ("B98550", "96643A"), ((20, 80), (1, 2)), 0.015, 15)
	# World map poster: sea, rough continents, flight lines from India.
	x, y, w, h = WORLD
	s.rect(x - 6, y - 6, w + 12, h + 12, SKY)
	lands = [
		[(30, 40), (70, 30), (95, 45), (85, 75), (60, 85), (40, 70)],          # North America
		[(70, 90), (88, 92), (92, 120), (78, 150), (68, 120)],                  # South America
		[(130, 34), (160, 30), (168, 48), (150, 56), (132, 50)],                # Europe
		[(135, 62), (170, 60), (180, 90), (160, 140), (140, 110)],              # Africa
		[(170, 30), (250, 28), (270, 55), (235, 75), (200, 70), (180, 52)],     # Asia
		[(195, 70), (212, 72), (206, 96)],                                      # India
		[(240, 110), (275, 108), (280, 130), (250, 135)],                       # Australia
	]
	for land in lands: s.polygon([(x + px, y + py) for px, py in land], LAND, 0.01)
	s.polygon([(x + 195, y + 70), (x + 212, y + 72), (x + 206, y + 96)], ORANGE, 0.02)
	home = (x + 204, y + 80)
	for dest in [(150, 42), (60, 55), (230, 60), (258, 120), (175, 70)]:
		tx, ty = x + dest[0], y + dest[1]
		steps = 12
		s.rects([(home[0] + (tx - home[0]) * k / steps - 1.5, home[1] + (ty - home[1]) * k / steps - 1.5 - 14 * math.sin(math.pi * k / steps), 3, 3) for k in range(1, steps)], NAVY, 0.03)
		s.rect(tx - 3, ty - 3, 6, 6, "C7352D", 0.03, r=3, seg=4)
	s.rect(x, y + h - 30, w, 30, NAVY, 0.03)
	s.text("WE SHIP WORLDWIDE  •  APNA EXPORT", x + w / 2, y + h - 15, 12, WHITE, 0.04, "ariblk.ttf", 280)

# ---------- shapes
def prism_y(b, pts, y0, y1, face_paint, rest):
	"""A flat shape extruded along y: pts (x, z) counter-clockwise seen from -y.
	Four-point faces print `face_paint` upright from both sides."""
	front = [b.vert((px, y0, pz)) for px, pz in pts]
	back = [b.vert((px, y1, pz)) for px, pz in pts]
	n = len(pts)
	if n == 4:
		b.paint(front, face_paint)
		b.paint([back[1], back[0], back[3], back[2]], face_paint)
	else:
		b.paint(front, face_paint)
		b.paint(back[::-1], face_paint)
	for i in range(n):
		j = (i + 1) % n
		b.swatch_face((front[i], back[i], back[j], front[j]), rest)

def disc_pts(cx, cz, r, seg=10):
	return [(cx + r * math.cos(2 * math.pi * k / seg), cz + r * math.sin(2 * math.pi * k / seg)) for k in range(seg)]

def tube_x(b, rings, bands, seg=12):
	"""A round body along x from (x, radius y, radius z, centre z) rings, nose first
	(x decreasing); a zero radius makes a point."""
	verts = []
	for x, ry, rz, zc in rings:
		if ry <= 0: verts.append([b.vert((x, 0, zc))])
		else: verts.append([b.vert((x, ry * math.cos(2 * math.pi * k / seg), zc + rz * math.sin(2 * math.pi * k / seg))) for k in range(seg)])
	for k in range(len(verts) - 1):
		a, c = verts[k], verts[k + 1]
		if len(a) == 1:
			for i in range(seg): b.swatch_face((a[0], c[i], c[(i + 1) % seg]), bands[k])
		elif len(c) == 1:
			for i in range(seg): b.swatch_face((c[0], a[(i + 1) % seg], a[i]), bands[k])
		else:
			b.quad_strip(c, a, bands[k])

def wheel(b, x, y, z, r, width):
	prism_y(b, disc_pts(x, z, r), y - width / 2, y + width / 2, "tyre", "tyre")
	prism_y(b, disc_pts(x, z, r * 0.45, 8), y - width / 2 - 0.01, y + width / 2 + 0.01, "steel_light", "steel_light")

# ---------- models
def cargo_plane(b):
	tube_x(b, [(8.0, 0, 0, 2.3), (7.6, 0.55, 0.6, 2.28), (7.0, 1.0, 1.05, 2.28), (6.0, 1.3, 1.35, 2.3),
		(-3.0, 1.3, 1.4, 2.35), (-5.5, 1.0, 1.05, 2.8), (-7.6, 0.45, 0.5, 3.4), (-8.0, 0, 0, 3.55)],
		["white", "white", "white", "white", "white", "white", "white"])
	for side in (-1, 1):
		b.box((0.4, side * 1.31, 2.5), (7.0, 0.03, 0.62), {"-y" if side < 0 else "+y": PLANE_TITLE, "rest": "blue"})
		b.box((6.9, side * 0.52, 2.98), (0.42, 0.42, 0.26), "glass")
	b.box((1.5, 0, 0.98), (9.0, 1.7, 0.08), "blue")
	# High wing with orange tips, and the engines under it.
	b.box((-0.4, 0, 3.75), (2.4, 18.0, 0.26), "white")
	for side in (-1, 1):
		b.box((-0.4, side * 8.85, 3.75), (2.0, 0.3, 0.3), "orange")
		tube_x(b, [(2.0, 0, 0, 3.4), (1.7, 0.36, 0.36, 3.4), (0.6, 0.46, 0.46, 3.4), (-1.6, 0.3, 0.3, 3.5), (-2.0, 0, 0, 3.5)], ["steel", "white", "white", "white"], 10)
		for y in (side * 3.6,): b.box((0.2, y, 3.62), (1.2, 0.12, 0.3), "white")
	# T-tail: a swept fin with the logo and the tailplane on top.
	prism_y(b, [(-8.0, 3.4), (-5.6, 3.4), (-6.8, 6.4), (-7.9, 6.4)], -0.09, 0.09, PLANE_TAIL, "orange")
	b.box((-7.4, 0, 6.45), (1.4, 6.4, 0.16), "white")
	for side in (-1, 1): b.box((-7.4, side * 3.15, 6.45), (1.2, 0.14, 0.18), "orange")
	# Landing gear: nose wheel, main wheels under blue fairings, a rear cargo ramp.
	b.box((5.8, 0, 0.75), (0.12, 0.12, 0.7), "steel")
	wheel(b, 5.8, 0, 0.32, 0.32, 0.22)
	for side in (-1, 1):
		b.box((-0.3, side * 1.35, 1.0), (2.2, 0.6, 0.55), "blue")
		for x in (-0.8, 0.2): wheel(b, x, side * 1.45, 0.42, 0.42, 0.3)
	b.box((-5.4, 0, 1.78), (2.6, 1.5, 0.05), "steel")

def propeller(b):
	b.box((0, 0, 0), (0.06, 0.2, 2.1), "prop")
	b.box((0, 0, 0), (0.06, 2.1, 0.2), "prop")
	tube_x(b, [(0.35, 0, 0, 0), (0.1, 0.16, 0.16, 0), (-0.05, 0.16, 0.16, 0)], ["orange", "orange"], 8)

def export_terminal(b):
	# Walls: ribbed cladding, the roller door toward the runway (-y here = game +z).
	b.box((0, 0, 3.0), (16.0, 10.0, 6.0), {"+z": None, "-z": None, "rest": CLADDING})
	b.box((-2.0, -5.03, 2.6), (7.0, 0.06, 5.2), {"-y": ROLLER, "rest": "steel"})
	b.box((-2.0, -5.2, 5.45), (7.6, 0.4, 0.5), "steel")
	# Arched roof over the hangar, gable ends in cladding.
	arc = [(-5.3 + 10.6 * k / 10, 6.0 + 1.7 * math.sin(math.pi * k / 10)) for k in range(11)]
	for k in range(10):
		(y0, z0), (y1, z1) = arc[k], arc[k + 1]
		idx = [b.vert((-8.3, y0, z0)), b.vert((8.3, y0, z0)), b.vert((8.3, y1, z1)), b.vert((-8.3, y1, z1))]
		b.swatch_face(idx, "roof")
		under = [b.vert((-8.3, y1, z1 - 0.05)), b.vert((8.3, y1, z1 - 0.05)), b.vert((8.3, y0, z0 - 0.05)), b.vert((-8.3, y0, z0 - 0.05))]
		b.swatch_face(under, "roof")
	for x, sign in ((8.0, 1), (-8.0, -1)):
		pts = [(y, z) for y, z in arc[::-1]] if sign > 0 else [(y, z) for y, z in arc]
		idx = [b.vert((x, y, z)) for y, z in pts]
		b.swatch_face(idx, "cladding")
	# Office toward the town (+y here = game -z) with the big sign above it.
	b.box((3.0, 6.5, 1.6), (8.0, 3.0, 3.2), {"+y": OFFICE, "-z": None, "rest": "white"})
	b.box((3.0, 6.5, 3.3), (8.4, 3.4, 0.2), "navy")
	b.box((3.0, 8.05, 3.2), (8.4, 0.12, 0.25), "orange")
	b.box((-2.0, 5.06, 4.7), (9.0, 0.1, 1.6), {"+y": TERMINAL_SIGN, "rest": "navy"})
	# A loading canopy over the apron side.
	b.box((5.6, -6.2, 3.6), (4.6, 2.4, 0.16), "orange")
	for x in (3.6, 7.6): b.box((x, -7.25, 1.8), (0.14, 0.14, 3.6), "steel")

def control_tower(b):
	b.box((0, 0, 3.5), (3.0, 3.0, 7.0), "white")
	b.box((0, 0, 6.6), (3.06, 3.06, 0.5), "orange")
	b.box((0, 0, 7.15), (3.8, 3.8, 0.3), "navy")
	b.box((0, 0, 8.3), (3.6, 3.6, 2.0), {"+z": None, "-z": None, "rest": TOWER_GLASS})
	b.box((0, 0, 9.45), (4.0, 4.0, 0.3), "navy")
	b.box((0, 0, 10.3), (0.12, 0.12, 1.4), "steel")
	b.box((0, 0, 11.05), (0.25, 0.25, 0.2), "red")
	b.box((0, 1.52, 1.1), (1.0, 0.06, 2.2), "glass")

def packing_table(b):
	b.box((0, 0, 0.87), (1.8, 0.8, 0.06), {"+z": TABLE_TOP, "rest": "wood_dark"})
	for x in (-0.84, 0.84):
		for y in (-0.34, 0.34): b.box((x, y, 0.42), (0.07, 0.07, 0.84), "steel")
	b.box((0, 0, 0.22), (1.7, 0.7, 0.04), "wood")
	for k in range(4): b.box((0.05 * (k % 2), 0, 0.255 + k * 0.03), (1.2, 0.62, 0.028), "kraft", rot_z=3 * (k % 2))
	# Tape dispenser, parcel scale, label printer and a roll of kraft paper.
	b.box((0.62, 0.18, 0.93), (0.24, 0.09, 0.06), "red")
	b.lathe((0.62, 0.18, 0.96), [(0.06, 0.0), (0.06, 0.05), (0.0, 0.05)], ["tape", "tape"], seg=10)
	b.box((-0.5, -0.05, 0.92), (0.36, 0.36, 0.04), "steel_light")
	b.box((-0.5, -0.25, 0.95), (0.16, 0.05, 0.06), "glass")
	b.box((0.15, 0.25, 0.98), (0.22, 0.2, 0.16), "white")
	b.box((0.15, 0.14, 1.0), (0.14, 0.02, 0.02), "steel")
	b.box((0, 0.36, 1.06), (1.6, 0.22, 0.22), "kraft")
	for x in (-0.82, 0.82): b.box((x, 0.36, 1.0), (0.04, 0.08, 0.26), "steel")

def parcel(b):
	b.box((0, 0, 0.2), (0.6, 0.45, 0.4), {"-y": PARCEL_LABEL, "+y": PARCEL_SIDE, "+x": PARCEL_SIDE, "-x": PARCEL_SIDE, "+z": PARCEL_TOP, "-z": "kraft"})

def carton_open(b):
	b.box((0, 0, 0.005), (0.6, 0.45, 0.01), "kraft")
	b.box((0, -0.22, 0.2), (0.6, 0.01, 0.4), {"-y": PARCEL_SIDE, "rest": "kraft"})
	b.box((0, 0.22, 0.2), (0.6, 0.01, 0.4), {"+y": PARCEL_SIDE, "rest": "kraft"})
	for x in (-0.295, 0.295): b.box((x, 0, 0.2), (0.01, 0.43, 0.4), "kraft")
	# Flaps tilted outward on all four sides (both faces).
	for corners in [
		[(-0.3, -0.225, 0.4), (0.3, -0.225, 0.4), (0.3, -0.36, 0.58), (-0.3, -0.36, 0.58)],
		[(0.3, 0.225, 0.4), (-0.3, 0.225, 0.4), (-0.3, 0.36, 0.58), (0.3, 0.36, 0.58)],
		[(0.3, -0.225, 0.4), (0.3, 0.225, 0.4), (0.44, 0.225, 0.56), (0.44, -0.225, 0.56)],
		[(-0.3, 0.225, 0.4), (-0.3, -0.225, 0.4), (-0.44, -0.225, 0.56), (-0.44, 0.225, 0.56)],
	]:
		b.swatch_face([b.vert(c) for c in corners], "kraft")
		b.swatch_face([b.vert(c) for c in corners[::-1]], "kraft")

def supply_shelf(b):
	for x in (-0.48, 0.48):
		for y in (-0.2, 0.2): b.box((x, y, 0.9), (0.04, 0.04, 1.8), "steel")
	for z in (0.1, 0.6, 1.1, 1.6): b.box((0, 0, z), (1.0, 0.44, 0.03), "steel_light")
	# Bottom: flat cartons; then tape rolls and label rolls; then bubble wrap and a box of stickers.
	for k in range(5): b.box((0.02 * (k % 2), 0, 0.13 + k * 0.025), (0.9, 0.4, 0.022), "kraft")
	for k in range(4): b.lathe((-0.36 + k * 0.16, -0.05, 0.615), [(0.06, 0.0), (0.06, 0.05), (0.0, 0.05)], ["tape", "tape"], seg=10)
	for k in range(3): b.lathe((0.08 + k * 0.13, 0.08, 0.615), [(0.045, 0.0), (0.045, 0.08), (0.0, 0.08)], ["white", "white"], seg=8)
	b.lathe((-0.22, 0.0, 1.115), [(0.17, 0.0), (0.17, 0.42), (0.05, 0.42), (0.0, 0.42)], ["steel_light", "white", "white"], seg=12)
	b.box((0.25, 0.0, 1.2), (0.36, 0.3, 0.18), {"-y": PARCEL_SIDE, "rest": "kraft"})
	b.box((0.0, -0.02, 1.7), (0.7, 0.36, 0.17), {"-y": PARCEL_LABEL, "rest": "kraft"})

def world_poster(b):
	b.box((0, 0, 0), (0.94, 0.03, 0.64), {"-y": "white", "rest": "navy"})
	b.box((0, -0.017, 0), (0.9, 0.005, 0.6), {"-y": WORLD, "rest": "navy"})

MODELS = {"cargo_plane": cargo_plane, "propeller": propeller, "export_terminal": export_terminal, "control_tower": control_tower,
	"packing_table": packing_table, "parcel": parcel, "carton_open": carton_open, "world_poster": world_poster, "supply_shelf": supply_shelf}

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "export")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
sheet = Sheet(ATLAS, SWATCHES, 912, cell=48)
draw_print(sheet)
png = os.path.join(out_dir, "export_props_print.png")
sheet.render(png)
mat = material("ExportProps", png)
objects = {}
for name, build in MODELS.items():
	b = Builder(sheet)
	build(b)
	objects[name] = b.to_object(name.title().replace("_", ""), mat)
	export_glb(objects[name], os.path.join(out_dir, name + ".glb"))
# A lineup for viewing: the terminal and tower behind, the plane in front, the props by it.
objects["export_terminal"].location = (0, 14, 0)
objects["control_tower"].location = (13, 14, 0)
objects["propeller"].location = (2.1, -3.6, 3.4)
objects["packing_table"].location = (-9, -6, 0)
objects["parcel"].location = (-9.4, -6, 0.9)
objects["carton_open"].location = (-8.5, -6, 0.9)
objects["world_poster"].location = (-9, -6.5, 1.9)
if render: preview(render, (10, -28, 12), (0, 4, 3), size=(1400, 760), lens=35)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "export_props.blend"))
print("SAVED", os.path.join(source, "export_props.blend"))
