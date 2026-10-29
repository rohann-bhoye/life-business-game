# Builds the Volterra S7, the player's own sports car: a low, wide supercar with a lofted
# body (smooth cross-sections), a black carbon roof, splitter, side intakes and rear wing,
# LED headlight strips, a full-width red tail bar, four exhaust tips, mirrors, 5-spoke black
# alloy wheels with red brake calipers, a passenger seat and a dashboard screen.
# Parts (one .glb): Body (paint, light grey so the game can repaint it: red, blue, black, white,
# orange, purple), Trim (carbon, intakes, seat, wing), Glass, Lamps (LED strips, tail bar,
# screen: lit by the game), Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR (origin at the centre).
# The car faces +Y here (-Z in Godot), origin on the ground between the axles.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_volterra.py -- <project dir> [--render out.png]
# Writes assets/props/cars/volterra.glb, volterra_print.png and source/volterra.blend.
import bpy, os, sys, math
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, preview, project_args

SWATCHES = {
	"paint": "F2F2F2", "paint_shade": "C8C8C8", "carbon": "16181B", "carbon_light": "2C3036", "glass": "3C5A78",
	"led": "BFEFFF", "tail": "FF2A20", "tyre": "141416", "alloy": "23262B", "alloy_light": "5B626B", "caliper": "C8201A",
	"seat_black": "17181A", "seat_red": "A31E22", "screen": "49C8FF", "metal": "A9AEB4", "amber": "FFA21A",
}
L = 4.7
WHEEL_R, WHEEL_W = 0.36, 0.3
AXLE_Y = 1.45          # front axle y (rear is -1.45 + a little)
WHEEL_X = 0.84

def sgn(v): return 1.0 if v >= 0 else -1.0

def loft(b, sections, swatch, n=16, expo=2.7, cap_swatch=None, x0=0.0):
	"""A smooth body from cross-sections (y, half width, bottom z, top z): each a rounded box ring."""
	rings = []
	for y, a, zb, zt in sections:
		zc, hb = (zb + zt) / 2, (zt - zb) / 2
		ring = []
		for k in range(n):
			t = 2 * math.pi * k / n
			c, s = math.cos(t), math.sin(t)
			ring.append(b.vert((x0 + a * sgn(c) * abs(c) ** (2 / expo), y, zc + hb * sgn(s) * abs(s) ** (2 / expo))))
		rings.append(ring)
	for r in range(len(rings) - 1):
		for k in range(n):
			j = (k + 1) % n
			name = swatch(k, r) if callable(swatch) else swatch
			b.swatch_face((rings[r][k], rings[r][j], rings[r + 1][j], rings[r + 1][k]), name)
	cap = cap_swatch or (swatch(0, 0) if callable(swatch) else swatch)
	b.swatch_face(list(reversed(rings[0])), cap)
	b.swatch_face(rings[-1], cap)

def wheel(mat, name):
	b = Builder(SHEET)
	r, w = WHEEL_R, WHEEL_W
	rings = []
	for x, radius in ((-w / 2, r * 0.7), (-w / 2, r), (w / 2, r), (w / 2, r * 0.7)):
		rings.append([b.vert((x, radius * math.cos(2 * math.pi * k / 20), radius * math.sin(2 * math.pi * k / 20))) for k in range(20)])
	for i in range(3): b.quad_strip(rings[i], rings[i + 1], "tyre")
	# The alloy face (outer side, +x for the right wheels) with five spokes and a hub.
	side = 1.0 if name.endswith("R") or name.endswith("RR") else -1.0
	face_x = side * (w / 2 + 0.005)
	b.swatch_face([b.vert((face_x, r * 0.7 * math.cos(2 * math.pi * k / 20), r * 0.7 * math.sin(2 * math.pi * k / 20))) for k in range(20)], "alloy")
	for k in range(5):
		a = 2 * math.pi * k / 5
		pts = []
		for rad, half in ((0.07, 0.034), (r * 0.7, 0.05)):
			for off in (-half, half):
				pts.append((rad * math.cos(a) - off * math.sin(a), rad * math.sin(a) + off * math.cos(a)))
		quad = [b.vert((face_x + side * 0.004, pts[0][0], pts[0][1])), b.vert((face_x + side * 0.004, pts[1][0], pts[1][1])), b.vert((face_x + side * 0.004, pts[3][0], pts[3][1])), b.vert((face_x + side * 0.004, pts[2][0], pts[2][1]))]
		b.swatch_face(quad, "alloy_light")
	b.swatch_face([b.vert((face_x + side * 0.006, 0.05 * math.cos(2 * math.pi * k / 10), 0.05 * math.sin(2 * math.pi * k / 10))) for k in range(10)], "metal")
	ob = b.to_object(name, mat)
	return ob

def build(mat):
	body, trim, glass, lamps = Builder(SHEET), Builder(SHEET), Builder(SHEET), Builder(SHEET)
	# Lower body: low nose, long hood, wide haunches, a high tail deck.
	sections = [(2.35, 0.55, 0.28, 0.5), (2.12, 0.8, 0.22, 0.6), (1.65, 0.95, 0.2, 0.7), (1.0, 0.98, 0.18, 0.76),
		(0.35, 0.98, 0.18, 0.84), (-0.5, 1.0, 0.18, 0.88), (-1.4, 1.0, 0.22, 0.94), (-2.0, 0.93, 0.28, 0.99), (-2.35, 0.8, 0.36, 0.9)]
	# Open cockpit: the nose (to y 0.5) and the tail (from y -1.6) are closed shells; between them
	# only two door sills are left, so the cabin is hollow and you sit inside.
	paint = lambda k, r: "paint" if k < 12 or k > 14 else "paint_shade"
	loft(body, [s for s in sections if s[0] >= 0.5], paint, cap_swatch="carbon")
	loft(body, [(-1.6, 1.0, 0.22, 0.94)] + [s for s in sections if s[0] < -1.6], paint, cap_swatch="carbon")
	for side in (-1, 1):
		loft(body, [(0.5, 0.2, 0.18, 0.84), (-0.5, 0.2, 0.18, 0.86), (-1.6, 0.2, 0.2, 0.9)], paint, n=12, cap_swatch="carbon", x0=side * 0.8)
	trim.box((0, -0.55, 0.3), (1.3, 2.2, 0.04), "carbon")
	# Cabin: glass sides with a black carbon roof (the top few segments).
	cabin = [(0.5, 0.6, 0.84, 0.9), (0.2, 0.66, 0.84, 1.06), (-0.4, 0.7, 0.84, 1.2), (-1.0, 0.68, 0.84, 1.18), (-1.6, 0.58, 0.84, 0.97)]
	loft(glass, cabin, lambda k, r: "carbon" if k in (3, 4, 5, 6) else "glass", n=16, expo=2.4, cap_swatch="glass")
	# Splitter, diffuser and side skirts in carbon.
	trim.box((0, 2.28, 0.21), (1.55, 0.3, 0.035), "carbon")
	trim.box((0, -2.3, 0.28), (1.6, 0.4, 0.05), "carbon")
	for s in (-1, 1):
		trim.box((s * 0.93, 0.0, 0.26), (0.05, 2.4, 0.08), "carbon")
		# Side intakes behind the doors and front brake ducts.
		trim.box((s * 1.0, -0.65, 0.58), (0.06, 0.8, 0.26), "carbon")
		trim.box((s * 0.78, 2.06, 0.34), (0.3, 0.05, 0.16), "carbon")
		# Mirrors on short stalks.
		trim.box((s * 0.68, 0.46, 0.86), (0.14, 0.06, 0.05), "carbon")
		trim.box((s * 0.8, 0.44, 0.92), (0.16, 0.1, 0.08), "paint")
		# Rear wing: end plates, two uprights and a long carbon blade.
		trim.box((s * 0.88, -2.28, 1.12), (0.04, 0.34, 0.2), "carbon")
		trim.box((s * 0.45, -2.2, 1.0), (0.05, 0.1, 0.22), "carbon")
		# Brake calipers behind the wheels' spokes.
		for ay in (AXLE_Y + 0.0, -AXLE_Y - 0.05):
			trim.box((s * (WHEEL_X - 0.12), ay, WHEEL_R + 0.12), (0.06, 0.14, 0.1), "caliper")
	trim.box((0, -2.28, 1.2), (1.8, 0.4, 0.035), "carbon")
	trim.box((0, 1.3, 0.76), (0.44, 0.45, 0.02), "carbon_light")
	# Exhaust: four round-ish tips low in the diffuser, each a dark box inside a metal ring.
	for x in (-0.5, -0.28, 0.28, 0.5):
		trim.box((x, -2.37, 0.4), (0.15, 0.03, 0.15), "metal")
		trim.box((x, -2.385, 0.4), (0.1, 0.03, 0.1), "carbon")
	# Passenger seat and the centre console (the driver's seat is left out: the player sits there).
	trim.box((-0.45, -0.2, 0.48), (0.5, 0.55, 0.14), "seat_black")
	trim.box((-0.45, -0.5, 0.78), (0.5, 0.12, 0.6), "seat_red")
	trim.box((0, -0.1, 0.52), (0.22, 1.1, 0.16), "carbon_light")
	trim.box((0, 0.58, 0.72), (1.5, 0.3, 0.1), "carbon_light")
	# Lamps: LED headlight strips sweeping back from the nose, amber side lights, the tail bar.
	for s in (-1, 1):
		lamps.box((s * 0.62, 2.0, 0.54), (0.42, 0.12, 0.035), "led", rot_z=s * 28)
		lamps.box((s * 0.36, 2.2, 0.5), (0.18, 0.06, 0.03), "led")
		lamps.box((s * 0.9, 1.6, 0.6), (0.05, 0.2, 0.04), "amber")
		lamps.box((s * 0.62, -2.36, 0.84), (0.5, 0.03, 0.06), "tail")
	lamps.box((0, -2.37, 0.84), (0.74, 0.03, 0.045), "tail")
	lamps.box((0.0, 0.62, 0.77), (0.4, 0.04, 0.2), "screen")
	objects = [body.to_object("Body", mat), trim.to_object("Trim", mat), glass.to_object("Glass", mat), lamps.to_object("Lamps", mat)]
	for name, sx, y in (("FL", -1, AXLE_Y), ("FR", 1, AXLE_Y), ("RL", -1, -AXLE_Y - 0.05), ("RR", 1, -AXLE_Y - 0.05)):
		w = wheel(mat, "Wheel_" + name)
		w.location = (sx * WHEEL_X, y, WHEEL_R)
		objects.append(w)
	return objects

def export(objects, path):
	for other in bpy.context.scene.objects: other.select_set(False)
	for ob in objects: ob.select_set(True)
	bpy.context.view_layer.objects.active = objects[0]
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_cameras=False,
		export_lights=False, export_animations=False, export_keep_originals=True)
	print("EXPORTED", path, sum(len(ob.data.polygons) for ob in objects), "faces")

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "cars")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)

clear_scene()
SHEET = Sheet(512, SWATCHES, 16, 72)
png = os.path.join(out_dir, "volterra_print.png")
SHEET.render(png)
mat = material("Volterra", png)
objects = build(mat)
export(objects, os.path.join(out_dir, "volterra.glb"))
if render: preview(render, (6.5, 6.2, 2.2), (0, 0, 0.55), lens=45)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "volterra.blend"))
print("SAVED", os.path.join(source, "volterra.blend"))
