# Builds the Dholkar Nadi road bridge north of Dholkarpur Gaon: a 40 m concrete arch
# bridge for cars (two lanes, raised footpaths with black-yellow kerbs, white railings,
# four street lamps, name plates on the end pillars) over four 8.4 m arches on piers.
# The deck top (road level) is the origin, the road runs along Godot z (Blender y),
# the arch crowns sit 1 m under the road and the piers reach 6.5 m down into the river.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_bridge.py -- <project dir> [--render out.png]
# Writes assets/props/bridge/road_bridge.glb, road_bridge_print.png, source/road_bridge.blend.
import bpy, os, sys, math
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

HALF_L, HALF_W = 20.0, 4.8     # deck half length (y) and half width (x)
WALL = 4.5                     # spandrel walls (x) under the deck
SLAB = 0.7                     # deck thickness
SPANS = [(-15.0, 4.2), (-5.0, 4.2), (5.0, 4.2), (15.0, 4.2)]   # arch centre (y), radius
CROWN = -1.0                   # arch crown height
BOTTOM = -6.5                  # piers end here, under the river bed
SWATCHES = {
	"concrete": "B9B6AE", "concrete_dark": "8E8B84", "stone": "9A8F80", "asphalt": "34373B",
	"paving": "A9A49A", "kerb_yellow": "F2C230", "kerb_black": "222222", "rail": "ECEAE4",
	"line_white": "F2F2EE", "line_yellow": "E8B84A", "pole": "5E646B", "lamp": "FFF2C4",
}
PLATE = (16, 16, 480, 120)

def draw_print(s):
	x, y, w, h = PLATE
	s.rect(x, y, w, h, "1F5E3B")
	s.rect(x + 8, y + 8, w - 16, h - 16, "F2F2EE", 0.01)
	s.rect(x + 14, y + 14, w - 28, h - 28, "1F5E3B", 0.02)
	s.text("DHOLKAR NADI PUL", x + w / 2, y + 52, 34, "FFFFFF", 0.03, "ariblk.ttf", w - 50)
	s.text("Dholkarpur Gaon", x + w / 2, y + 90, 22, "F2C230", 0.03, "arialbd.ttf", w - 60)

def arch_side(b, x, centre, radius, outward):
	"""The wall over one arch on side `x`: from the arch curve up to the deck."""
	steps = 12
	top = -SLAB
	for k in range(steps):
		pts = []
		for t in (k, k + 1):
			a = math.pi * t / steps
			pts.append((centre + radius * math.cos(a), CROWN - radius + radius * math.sin(a)))
		(y0, z0), (y1, z1) = pts
		quad = [b.vert((x, y0, z0)), b.vert((x, y1, z1)), b.vert((x, y1, top)), b.vert((x, y0, top))]
		if outward > 0: quad.reverse()
		b.swatch_face(quad, "concrete")
		# The underside of the arch (barrel vault) between the two walls.
		if outward > 0:
			under = [b.vert((-WALL, y0, z0)), b.vert((-WALL, y1, z1)), b.vert((WALL, y1, z1)), b.vert((WALL, y0, z0))]
			under.reverse()
			b.swatch_face(under, "concrete_dark")

def build(mat):
	b = Builder(SHEET)
	b.box((0, 0, -SLAB / 2), (HALF_W * 2, HALF_L * 2, SLAB), {"+z": "asphalt", "rest": "concrete"})
	for centre, radius in SPANS:
		for side in (-1, 1): arch_side(b, side * WALL, centre, radius, side)
	# Piers between the arches and the abutments at both ends.
	for y in (-10.0, 0.0, 10.0):
		b.box((0, y, (BOTTOM + CROWN - 4.2) / 2), (WALL * 2 + 0.4, 1.6, CROWN - 4.2 - BOTTOM), "stone")
		b.box((0, y, (CROWN - 4.2 - SLAB) / 2), (WALL * 2, 1.6, -SLAB - CROWN + 4.2), "concrete")
		for side in (-1, 1): b.box((0, y + side * 0.9, -4.6), (WALL * 2 + 0.6, 0.3, 0.3), "concrete_dark")
	for side in (-1, 1):
		b.box((0, side * (HALF_L + 0.6), (BOTTOM - SLAB) / 2), (HALF_W * 2 + 0.6, 2.8, -BOTTOM - SLAB), "stone")
	# Footpaths, kerbs, road lines.
	for side in (-1, 1):
		b.box((side * 3.85, 0, 0.1), (1.5, HALF_L * 2, 0.2), {"+z": "paving", "rest": "concrete"})
		for k in range(40):
			b.box((side * 3.08, -HALF_L + 0.5 + k, 0.11), (0.06, 1.0, 0.22), "kerb_yellow" if k % 2 == 0 else "kerb_black")
		b.box((side * 2.9, 0, 0.006), (0.1, HALF_L * 2, 0.012), "line_white")
		# Railing: posts every 2 m and two rails.
		for k in range(21):
			b.box((side * 4.62, -HALF_L + k * 2.0, 0.7), (0.18, 0.18, 1.0), "rail")
		for z in (0.62, 1.12): b.box((side * 4.62, 0, z), (0.1, HALF_L * 2, 0.1), "rail")
		b.box((side * HALF_W, 0, -SLAB - 0.1), (0.2, HALF_L * 2, 0.25), "concrete_dark")
		# End pillars with the name plates (facing along the road).
		for end in (-1, 1):
			px, py = side * 5.0, end * (HALF_L + 0.4)
			b.box((px, py, 0.8), (0.8, 0.8, 1.6), "stone")
			b.box((px, py, 1.66), (0.95, 0.95, 0.12), "concrete")
			if side < 0:
				x0, y0, z0 = px - 0.9, py + end * 0.41, 1.0
				idx = [b.vert((x0 + 1.8, y0, z0 - 0.22)), b.vert((x0, y0, z0 - 0.22)), b.vert((x0, y0, z0 + 0.22)), b.vert((x0 + 1.8, y0, z0 + 0.22))]
				if end < 0: idx = [idx[1], idx[0], idx[3], idx[2]]
				b.region_face(idx, PLATE)
				b.box((px, py + end * 0.37, z0), (1.9, 0.08, 0.52), "kerb_black")
	for k in range(9):
		b.box((0, -HALF_L + 2.0 + k * 4.5, 0.006), (0.14, 2.0, 0.012), "line_yellow")
	# Street lamps, two each side, staggered.
	for side, y in ((-1, -10.0), (1, -2.0), (-1, 6.0), (1, 14.0)):
		x = side * 4.62
		b.box((x, y, 3.2), (0.16, 0.16, 5.0), "pole")
		b.box((x - side * 0.6, y, 5.65), (1.3, 0.1, 0.1), "pole")
		b.box((x - side * 1.2, y, 5.55), (0.5, 0.26, 0.14), {"-z": "lamp", "rest": "pole"})
	return b.to_object("RoadBridge", mat)

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "bridge")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(512, SWATCHES, 160)
draw_print(SHEET)
png = os.path.join(out_dir, "road_bridge_print.png")
SHEET.render(png)
bridge = build(material("RoadBridge", png))
export_glb(bridge, os.path.join(out_dir, "road_bridge.glb"))
if render: preview(render, (26, -30, 8), (0, 0, -2), lens=40)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "road_bridge.blend"))
print("SAVED", os.path.join(source, "road_bridge.blend"))
