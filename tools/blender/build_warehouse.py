# Builds APNA STORAGE, the warehouse across the road, as models placed exactly on the
# game's layout (warehouse.gd): the model origin is the game origin at floor level
# (y 0.1 in the game), so walls, doors and racks line up with the colliders and the
# gameplay points. Pieces (one atlas, warehouse_print.png):
#   warehouse_brick.glb     front facade and the brick plinth round the sides and back
#                           (the game gives it the world-mapped brick material)
#   warehouse_cladding.glb  ribbed steel walls above the plinth and the gable ends
#                           (the game gives it the ribbed cladding material)
#   warehouse_shell.glb     everything printed: pitched roof with skylights and gutters,
#                           the APNA STORAGE parapet sign, the entrance frame and canopy,
#                           the office door and window, two roller shutters with dock
#                           bumpers and bollards, lamps, downpipes, a side wall logo, and
#                           inside: steel columns and five roof trusses
#   storage_rack.glb        pallet rack: blue frames with bracing, orange beams, wire
#                           decks at the game's four shelf heights (front +z in the game)
# Blender axes: x as in the game, -y = the game's +z, z up.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_warehouse.py -- <project dir> [--render out.png]
# Writes assets/props/warehouse/*.glb, warehouse_print.png and source/warehouse.blend.
import bpy, os, sys, math, random
from mathutils import Vector
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

ATLAS = 1024
WHITE, ORANGE, YELLOW, NAVY, BLUE = "F4F3EE", "F0892A", "F4C443", "16294A", "2A5DA8"
SWATCHES = {
	"white": WHITE, "orange": ORANGE, "yellow": YELLOW, "navy": NAVY, "blue": BLUE, "steel": "3A3F45",
	"steel_light": "9AA3AB", "roof": "4E5A66", "roof_under": "8C969F", "sky": "D8ECF7", "glass": "1D3550",
	"rubber": "1E1F22", "concrete": "B5B3AC", "teal": "1F5F66", "lamp": "FFE9A8", "rack_blue": "2C5C9E",
	"deck": "B8BEC4", "red": "C7352D", "plain": "C8CDD2",
}
FRONT_Z = 14.5   # game z of the front wall (Blender y = -14.5)
BACK_Z = 30.5
LEFT_X, RIGHT_X = -16.5, 6.4
WALL_TOP = 5.2   # above the floor
RIDGE = 6.7
EAVE = 5.35
PLINTH = 1.4
# Atlas regions (x, y, w, h).
SIGN_BAND = (0, 0, 1008, 46)          # 23 x 0.9 m parapet
SIDE_LOGO = (0, 62, 520, 140)          # 6 x 1.6 m panel on the east wall
CANOPY_SIGN = (536, 62, 300, 40)       # 5.2 x 0.25 m canopy front
OFFICE_WINDOW = (0, 218, 500, 190)     # 6 x 2.3 m
ROLLER = (516, 218, 200, 260)          # 2.4 x 3.1 m
DOOR_SIGN = (732, 218, 260, 60)
WIRE = (732, 294, 200, 80)
OFFICE_DOOR = (732, 390, 80, 150)

def game(x, z, y):
	"""Blender point from game x, game z and height above the floor."""
	return (x, -z, y)

# ---------- print
def draw_print(s):
	x, y, w, h = SIGN_BAND
	s.rect(x - 6, y - 6, w + 12, h + 12, NAVY)
	s.rect(x - 6, y + h - 7, w + 12, 7, ORANGE, 0.01)
	s.text("APNA STORAGE", x + 330, y + 21, 26, WHITE, 0.02, "ariblk.ttf", 420)
	s.text("WAREHOUSE  •  WHOLESALE  •  LOGISTICS", x + 740, y + 21, 13, YELLOW, 0.02, "segoeuib.ttf", 420)
	for cx in (x + 40, x + 968):
		s.rect(cx - 16, y + 7, 32, 32, ORANGE, 0.02, r=6)
		s.text("A", cx, y + 23, 20, WHITE, 0.03, "ariblk.ttf", 30)
	x, y, w, h = SIDE_LOGO
	s.rect(x - 6, y - 6, w + 12, h + 12, NAVY)
	s.rect(x + 14, y + 14, 112, 112, ORANGE, 0.01, r=20)
	s.text("A", x + 70, y + 70, 70, WHITE, 0.02, "ariblk.ttf", 100)
	s.text("APNA STORAGE", x + 320, y + 54, 46, WHITE, 0.02, "ariblk.ttf", 370)
	s.text("Godown  •  Pick-up  •  Deliveries", x + 320, y + 100, 17, YELLOW, 0.02, "segoeuib.ttf", 370)
	x, y, w, h = CANOPY_SIGN
	s.rect(x - 6, y - 6, w + 12, h + 12, ORANGE)
	s.text("GOODS IN  •  ENTRANCE", x + w / 2, y + h / 2, 18, WHITE, 0.02, "ariblk.ttf", 280)
	x, y, w, h = OFFICE_WINDOW
	s.rect(x - 6, y - 6, w + 12, h + 12, "2B3640")
	for k in range(4):
		s.rect(x + 10 + k * 122, y + 10, 114, h - 20, "1D3550", 0.01)
		s.polygon([(x + 22 + k * 122, y + h - 30), (x + 70 + k * 122, y + 20), (x + 90 + k * 122, y + 20), (x + 42 + k * 122, y + h - 30)], "2C4A6B", 0.02)
	s.rect(x - 6, y + 92, w + 12, 6, "2B3640", 0.03)
	s.text("OFFICE", x + w / 2, y + 50, 16, "8FB3CF", 0.04, "segoeuib.ttf", 200)
	x, y, w, h = ROLLER
	s.rect(x - 6, y - 6, w + 12, h + 12, BLUE)
	s.rects([(x - 6, y + k * 9, w + 12, 3) for k in range(int(h / 9))], "1F4888", 0.01)
	s.rect(x + w / 2 - 22, y + h - 70, 44, 8, "1E1F22", 0.02, r=3)
	s.rect(x - 6, y + h - 16, w + 12, 22, YELLOW, 0.02)
	s.rects([(x + k * 22, y + h - 16, 11, 22) for k in range(-1, int(w / 22) + 1)], "1E1F22", 0.03)
	x, y, w, h = DOOR_SIGN
	s.rect(x - 6, y - 6, w + 12, h + 12, YELLOW)
	s.text("LOADING BAY  1  •  2", x + w / 2, y + 20, 16, "1E1F22", 0.02, "ariblk.ttf", 240)
	s.text("Keep clear", x + w / 2, y + 44, 11, "1E1F22", 0.02, "segoeuib.ttf", 240)
	x, y, w, h = WIRE
	s.rect(x - 6, y - 6, w + 12, h + 12, "8A929A")
	s.rects([(x + k * 8, y - 6, 2, h + 12) for k in range(int(w / 8) + 1)], "D9DEE2", 0.01)
	s.rects([(x - 6, y + k * 8, w + 12, 2) for k in range(int(h / 8) + 1)], "D9DEE2", 0.01)
	x, y, w, h = OFFICE_DOOR
	s.rect(x - 6, y - 6, w + 12, h + 12, "1F5F66")
	s.rect(x + 12, y + 14, w - 24, 62, "1D3550", 0.01)
	s.rect(x + w - 18, y + 82, 6, 20, "C5CAD0", 0.02)
	s.text("OFFICE", x + w / 2, y + 120, 9, WHITE, 0.02, "segoeuib.ttf", 70)

# ---------- shapes
def beam(b, p0, p1, size, paint):
	"""A box from p0 to p1 (any direction), `size` = (width, height) across it."""
	p0, p1 = Vector(p0), Vector(p1)
	d = (p1 - p0).normalized()
	up = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
	side = d.cross(up).normalized() * size[0] / 2
	top = side.cross(d).normalized() * size[1] / 2
	corners = [p + s1 * side + s2 * top for p in (p0, p1) for s1, s2 in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
	v = [b.vert(c) for c in corners]
	for face in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
		b.swatch_face([v[i] for i in reversed(face)], paint)

def quad(b, corners, paint, both=False):
	b.paint([b.vert(c) for c in corners], paint)
	if both: b.paint([b.vert(c) for c in corners[::-1]], paint)

def gbox(b, x0, x1, z0, z1, y0, y1, paint):
	"""Box from game ranges: x, game z and height above the floor."""
	b.box(((x0 + x1) / 2, -(z0 + z1) / 2, (y0 + y1) / 2), (abs(x1 - x0), abs(z1 - z0), abs(y1 - y0)), paint)

def roof_height(z):
	return RIDGE - (RIDGE - EAVE) * abs(z - (FRONT_Z + BACK_Z) / 2) / ((BACK_Z - FRONT_Z) / 2 + 0.3)

# ---------- models
def brick(b):
	t = 0.09
	# Front facade with the office door and the main entrance.
	gbox(b, LEFT_X - t, -14.825, FRONT_Z - t, FRONT_Z + t, 0, WALL_TOP, "plain")
	gbox(b, -14.825, -13.575, FRONT_Z - t, FRONT_Z + t, 2.35, WALL_TOP, "plain")
	gbox(b, -13.575, -5.0, FRONT_Z - t, FRONT_Z + t, 0, WALL_TOP, "plain")
	gbox(b, -5.0, -1.0, FRONT_Z - t, FRONT_Z + t, 3.7, WALL_TOP, "plain")
	gbox(b, -1.0, RIGHT_X + t, FRONT_Z - t, FRONT_Z + t, 0, WALL_TOP, "plain")
	# Plinth round the sides and back, a little proud of the cladding.
	gbox(b, LEFT_X - t - 0.03, LEFT_X + t, FRONT_Z, BACK_Z + t, 0, PLINTH, "plain")
	gbox(b, RIGHT_X - t, RIGHT_X + t + 0.03, FRONT_Z, BACK_Z + t, 0, PLINTH, "plain")
	gbox(b, LEFT_X - t, RIGHT_X + t, BACK_Z - t, BACK_Z + t + 0.03, 0, PLINTH, "plain")

def cladding(b):
	t = 0.09
	gbox(b, LEFT_X - t, LEFT_X + t, FRONT_Z + t, BACK_Z + t, PLINTH, WALL_TOP, "plain")
	gbox(b, RIGHT_X - t, RIGHT_X + t, FRONT_Z + t, BACK_Z + t, PLINTH, WALL_TOP, "plain")
	gbox(b, LEFT_X - t, RIGHT_X + t, BACK_Z - t, BACK_Z + t, PLINTH, WALL_TOP, "plain")
	# Gable ends up to the ridge (both sides of each).
	mid = (FRONT_Z + BACK_Z) / 2
	for x in (LEFT_X, RIGHT_X):
		for side in (-1, 1):
			pts = [game(x + side * t, FRONT_Z, WALL_TOP), game(x + side * t, BACK_Z, WALL_TOP), game(x + side * t, mid, RIDGE - 0.05)]
			if side > 0: pts = pts[::-1]
			b.swatch_face([b.vert(p) for p in pts], "plain")

def shell(b):
	mid = (FRONT_Z + BACK_Z) / 2
	# Pitched roof: two slopes with an overhang, gutters, skylight strips (glass on top,
	# daylight panels seen from inside).
	for z_eave in (FRONT_Z - 0.3, BACK_Z + 0.3):
		e0, e1 = game(LEFT_X - 0.35, z_eave, EAVE), game(RIGHT_X + 0.35, z_eave, EAVE)
		r0, r1 = game(LEFT_X - 0.35, mid, RIDGE), game(RIGHT_X + 0.35, mid, RIDGE)
		top = [e0, e1, r1, r0] if z_eave > mid else [e1, e0, r0, r1]
		quad(b, top, "roof")
		quad(b, [(c[0], c[1], c[2] - 0.08) for c in top[::-1]], "roof_under")
		gbox(b, LEFT_X - 0.35, RIGHT_X + 0.35, z_eave - 0.12, z_eave + 0.12, EAVE - 0.2, EAVE, "steel")
		for x0 in (-13.0, -5.5, 2.0):
			for k in (0.35, 0.65):
				za = z_eave + (mid - z_eave) * k
				zb = za + (0.8 if z_eave < mid else -0.8)
				ya, yb = roof_height(za) + 0.03, roof_height(zb) + 0.03
				pts = [game(x0, za, ya), game(x0 + 3.0, za, ya), game(x0 + 3.0, zb, yb), game(x0, zb, yb)]
				if z_eave < mid: pts = [pts[1], pts[0], pts[3], pts[2]]
				quad(b, pts, "glass")
				quad(b, [(c[0], c[1], c[2] - 0.13) for c in pts[::-1]], "sky")
	gbox(b, LEFT_X - 0.35, RIGHT_X + 0.35, mid - 0.12, mid + 0.12, RIDGE - 0.05, RIDGE + 0.08, "steel")
	# Parapet sign across the front, a fascia stripe, downpipes at the corners.
	b.box(game(-5.05, FRONT_Z - 0.14, 5.65), (23.2, 0.12, 0.9), {"+y": SIGN_BAND, "rest": "navy"})
	gbox(b, LEFT_X - 0.1, RIGHT_X + 0.1, FRONT_Z - 0.22, FRONT_Z - 0.08, 5.15, 5.22, "orange")
	for x in (LEFT_X + 0.15, RIGHT_X - 0.15):
		for z in (FRONT_Z - 0.16, BACK_Z + 0.16):
			gbox(b, x - 0.06, x + 0.06, z - 0.06, z + 0.06, 0, EAVE - 0.1, "steel")
	# Main entrance: orange steel frame, a header with a sign, a canopy on tie rods.
	for x in (-5.08, -0.92): gbox(b, x - 0.08, x + 0.08, FRONT_Z - 0.2, FRONT_Z - 0.05, 0, 3.8, "orange")
	gbox(b, -5.16, -0.84, FRONT_Z - 0.2, FRONT_Z - 0.05, 3.7, 3.9, "orange")
	gbox(b, -5.7, -0.3, FRONT_Z - 1.6, FRONT_Z - 0.09, 4.05, 4.2, "steel")
	b.box(game(-3.0, FRONT_Z - 1.62, 4.13), (5.4, 0.04, 0.26), {"+y": CANOPY_SIGN, "rest": "orange"})
	for x in (-5.4, -0.6): beam(b, game(x, FRONT_Z - 1.5, 4.18), game(x, FRONT_Z - 0.09, 5.0), (0.05, 0.05), "steel")
	# Office door: frame, a small canopy and a lamp.
	for x in (-14.9, -13.5): gbox(b, x - 0.06, x + 0.06, FRONT_Z - 0.16, FRONT_Z - 0.05, 0, 2.45, "teal")
	gbox(b, -14.96, -13.44, FRONT_Z - 0.16, FRONT_Z - 0.05, 2.35, 2.5, "teal")
	gbox(b, -15.2, -13.2, FRONT_Z - 1.0, FRONT_Z - 0.09, 2.7, 2.8, "teal")
	# Office window, sill and lintel.
	b.box(game(-9.3, FRONT_Z - 0.1, 2.15), (6.0, 0.04, 2.3), {"+y": OFFICE_WINDOW, "rest": "steel"})
	gbox(b, -12.45, -6.15, FRONT_Z - 0.26, FRONT_Z - 0.09, 0.88, 1.0, "concrete")
	gbox(b, -12.45, -6.15, FRONT_Z - 0.16, FRONT_Z - 0.09, 3.3, 3.45, "steel")
	# Loading bays 1 and 2: shutters, guide rails, roller boxes, dock bumpers, bollards.
	for x in (0.9, 3.7):
		b.box(game(x, FRONT_Z - 0.12, 1.55), (2.4, 0.04, 3.1), {"+y": ROLLER, "rest": "blue"})
		for side in (-1, 1):
			gbox(b, x + side * 1.26 - 0.06, x + side * 1.26 + 0.06, FRONT_Z - 0.22, FRONT_Z - 0.09, 0, 3.1, "steel")
			gbox(b, x + side * 1.1 - 0.12, x + side * 1.1 + 0.12, FRONT_Z - 0.32, FRONT_Z - 0.09, 0.15, 0.6, "rubber")
			b.lathe(game(x + side * 1.6, FRONT_Z - 0.7, 0), [(0.11, 0.0), (0.11, 0.85), (0.0, 0.9)], ["yellow", "yellow"], seg=10)
		gbox(b, x - 1.35, x + 1.35, FRONT_Z - 0.4, FRONT_Z - 0.09, 3.1, 3.45, "steel")
	b.box(game(2.3, FRONT_Z - 0.11, 3.85), (2.6, 0.04, 0.6), {"+y": DOOR_SIGN, "rest": "yellow"})
	# Wall lamps over the doors.
	for x in (-3.0, -14.2, 0.9, 3.7):
		y = 4.35 if x == -3.0 else (2.95 if x == -14.2 else 3.65)
		beam(b, game(x, FRONT_Z - 0.09, y), game(x, FRONT_Z - 0.5, y + 0.15), (0.05, 0.05), "steel")
		gbox(b, x - 0.16, x + 0.16, FRONT_Z - 0.62, FRONT_Z - 0.38, y + 0.06, y + 0.18, "steel")
		gbox(b, x - 0.13, x + 0.13, FRONT_Z - 0.6, FRONT_Z - 0.4, y + 0.02, y + 0.06, "lamp")
	# Big logo on the east wall (seen from the airport walk).
	b.box(game(RIGHT_X + 0.13, 22.5, 3.3), (0.06, 6.0, 1.6), {"+x": SIDE_LOGO, "rest": "navy"})
	# Inside: steel columns along the side walls and five trusses across the hall.
	for z in (16.5, 20.5, 24.5, 28.5):
		for x in (LEFT_X + 0.25, RIGHT_X - 0.25):
			gbox(b, x - 0.12, x + 0.12, z - 0.12, z + 0.12, 0, WALL_TOP, "steel_light")
	for x in (-14.0, -9.0, -4.0, 1.0, 5.0):
		chord = 5.2
		gbox(b, x - 0.07, x + 0.07, FRONT_Z + 0.1, BACK_Z - 0.1, chord - 0.06, chord + 0.06, "steel")
		for z0, z1 in ((FRONT_Z + 0.1, mid), (BACK_Z - 0.1, mid)):
			beam(b, game(x, z0, chord + 0.08), game(x, z1, RIDGE - 0.2), (0.12, 0.16), "steel")
			steps = 4
			for k in range(1, steps):
				zk = z0 + (z1 - z0) * k / steps
				yk = chord + 0.08 + (RIDGE - 0.2 - chord - 0.08) * k / steps
				beam(b, game(x, zk, chord), game(x, zk, yk), (0.06, 0.06), "steel_light")
				zn = z0 + (z1 - z0) * (k + 1) / steps
				yn = chord + 0.08 + (RIDGE - 0.2 - chord - 0.08) * (k + 1) / steps
				beam(b, game(x, zk, chord), game(x, zn, yn), (0.05, 0.05), "steel_light")
	# Purlins along the hall under the roof.
	for k in (0.25, 0.5, 0.75):
		for z0 in (FRONT_Z, BACK_Z):
			z = z0 + (mid - z0) * k
			y = roof_height(z) - 0.16
			gbox(b, LEFT_X + 0.1, RIGHT_X - 0.1, z - 0.06, z + 0.06, y - 0.05, y + 0.05, "steel")

def storage_rack(b):
	blue, beam_paint = "rack_blue", "orange"
	for x in (-1.3, 1.3):
		for z in (-0.5, 0.5):
			gbox(b, x - 0.045, x + 0.045, z - 0.045, z + 0.045, 0, 4.2, blue)
			gbox(b, x - 0.09, x + 0.09, z - 0.09, z + 0.09, 0, 0.012, "steel")
		for k in range(5):
			y0 = 0.15 + k * 0.8
			beam(b, (x, 0.45, y0), (x, -0.45, y0 + 0.8), (0.03, 0.03), "steel_light")
			gbox(b, x - 0.02, x + 0.02, -0.45, 0.45, y0 - 0.015, y0 + 0.015, "steel_light")
	for z in (-0.5,):
		for x in (-1.3, 1.3): gbox(b, x - 0.07, x + 0.07, z - 0.14, z - 0.05, 0, 0.45, "yellow")
	for level in range(4):
		y = 0.1 + level * 0.95
		for z in (-0.5, 0.5): gbox(b, -1.26, 1.26, z - 0.03, z + 0.03, y - 0.06, y + 0.06, beam_paint)
		if level > 0:
			b.box((0, 0, y + 0.075), (2.5, 0.98, 0.015), {"+z": WIRE, "-z": WIRE, "rest": "deck"})
	for z in (-0.5, 0.5): gbox(b, -1.26, 1.26, z - 0.03, z + 0.03, 4.05, 4.15, beam_paint)

MODELS = {"warehouse_brick": brick, "warehouse_cladding": cladding, "warehouse_shell": shell, "storage_rack": storage_rack}

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "warehouse")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
sheet = Sheet(ATLAS, SWATCHES, 912, cell=48)
draw_print(sheet)
png = os.path.join(out_dir, "warehouse_print.png")
sheet.render(png)
mat = material("WarehousePrint", png)
objects = {}
for name, build in MODELS.items():
	b = Builder(sheet)
	build(b)
	objects[name] = b.to_object(name.title().replace("_", ""), mat)
	export_glb(objects[name], os.path.join(out_dir, name + ".glb"))
# Racks in their bays for viewing.
for k, x in enumerate((-9.8, -5.8, -0.2, 3.8)):
	for row in range(4):
		rack = objects["storage_rack"].copy()
		bpy.context.scene.collection.objects.link(rack)
		rack.location = (x, -(16.5 + row * 4), 0)
objects["storage_rack"].location = (-9.8, -16.5, 0)
if render: preview(render, (12, 2, 12), (-5, -22, 2), size=(1400, 760), lens=30)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "warehouse.blend"))
print("SAVED", os.path.join(source, "warehouse.blend"))
