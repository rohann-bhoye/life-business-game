# Builds the fresh produce: tomato, apple, carrot, cabbage and corn (bhutta), sharing one
# small atlas (produce_print.png): flat swatches for skins and leaves, plus a kernel grid for
# the corn cob. Slightly lumpy, with alternating rib shades, calyxes, stems and leaves, so the
# baskets read as real vegetables. Bottom at z = 0, centred on x/y. Carrot and corn lie along x.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_produce.py -- <project dir> [--render out.png]
# Writes assets/produce/custom/*.glb, produce_print.png and source/produce.blend.
import bpy, os, sys, math, random
from mathutils import Vector
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

SWATCHES = {
	"tomato": "D3281C", "tomato2": "DB2E20", "apple": "C42A25", "apple2": "D0382A", "apple_y": "E6B13A",
	"carrot": "EE7E1B", "carrot2": "D96A10", "cabbage": "7FB651", "cabbage2": "88BC58", "cabbage_d": "4F8F3A",
	"leaf": "3E9A3A", "leaf2": "2F7D2F", "husk": "8FBF4A", "husk2": "B7D86A", "stem": "5B4426", "silk": "D8C48A",
}
KERNEL = (0, 0, 576, 384)

def draw_print(s):
	x, y, w, h = KERNEL
	s.rect(x, y, w, h, "B8851A", 0.0)
	rng = random.Random(4)
	for r in range(16):
		for c in range(24):
			shade = rng.choice(["F5CC3D", "F0C233", "F8D44E", "EDB92A"])
			s.rect(x + c * 24 + 2, y + r * 24 + 2, 20, 20, shade, 0.01, r=7, seg=3)

def vert_noise(b, rng, amount, centre=(0, 0, 0)):
	c = Vector(centre)
	for i, v in enumerate(b.verts):
		d = v - c
		if d.length > 1e-6: b.verts[i] = v + d.normalized() * rng.uniform(-amount, amount)

def revolve(b, profile, bands, seg=16, label_bands=(), label_region=None, rng=None, axis_lift=0.0):
	"""Round body from (radius, height) rings. bands[k] is a swatch, or a pair of swatches that
	alternate around the body (ribs). The band `label_band` prints `label_region` once around."""
	rows = []
	for r, z in profile:
		if r <= 0: rows.append([b.vert((0, 0, z))])
		else: rows.append([b.vert((r * math.cos(2 * math.pi * k / seg), r * math.sin(2 * math.pi * k / seg), z)) for k in range(seg)])
	for k in range(len(rows) - 1):
		a, c = rows[k], rows[k + 1]
		band = bands[k]
		for i in range(seg):
			j = (i + 1) % seg
			swatch = band[i % 2] if isinstance(band, tuple) else band
			if len(a) == 1: b.swatch_face((a[0], c[j], c[i]), swatch)
			elif len(c) == 1: b.swatch_face((a[i], a[j], c[0]), swatch)
			elif k in label_bands:
				x, y, w, h = label_region
				u0, u1 = x + w * i / seg, x + w * (i + 1) / seg
				p, m = list(label_bands).index(k), len(label_bands)
				yt, yb = y + h * (m - 1 - p) / m, y + h * (m - p) / m
				b.face((a[i], a[j], c[j], c[i]), [b.sheet.uv(u0, yb), b.sheet.uv(u1, yb), b.sheet.uv(u1, yt), b.sheet.uv(u0, yt)])
			else: b.swatch_face((a[i], a[j], c[j], c[i]), swatch)

def blade(b, base, tip, width, swatch, lift=0.0, steps=3):
	"""A leaf: a bent strip from base to tip, drawn on both sides."""
	base, tip = Vector(base), Vector(tip)
	axis = tip - base
	side = axis.cross(Vector((0, 0, 1)))
	side = side.normalized() if side.length > 1e-6 else Vector((1, 0, 0))
	left, right = [], []
	for k in range(steps + 1):
		t = k / steps
		w = width * math.sin(math.pi * min(0.95, t * 0.9 + 0.1)) * (1 - 0.5 * t)
		mid = base + axis * t + Vector((0, 0, lift * math.sin(math.pi * t)))
		left.append(b.vert(mid - side * w))
		right.append(b.vert(mid + side * w))
	for k in range(steps):
		b.swatch_face((left[k], right[k], right[k + 1], left[k + 1]), swatch)
		b.swatch_face((left[k + 1], right[k + 1], right[k], left[k]), swatch)

def lay_along_x(b, start):
	"""Tip the finished body from standing to lying along x, resting on z = 0."""
	for i in range(start, len(b.verts)):
		v = b.verts[i]
		b.verts[i] = Vector((v.z, v.y, -v.x))

def settle(b, lowest=True):
	"""Centre on x/y and rest the lowest point on z = 0."""
	lo = Vector((min(v.x for v in b.verts), min(v.y for v in b.verts), min(v.z for v in b.verts)))
	hi = Vector((max(v.x for v in b.verts), max(v.y for v in b.verts), max(v.z for v in b.verts)))
	shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
	for i, v in enumerate(b.verts): b.verts[i] = v - shift

def sphere_profile(radius, height, squash_top=0.0, rings=9, bulge=1.0):
	pts = []
	for k in range(rings + 1):
		t = math.pi * k / rings
		r = radius * math.sin(t) ** 0.85 * (bulge if t < math.pi / 2 else 1.0)
		z = height / 2 * (1 - math.cos(t))
		if k > rings - 3: z -= squash_top * (1 - (rings - k) / 3)
		pts.append((max(r, 0.0), z))
	pts[0] = (0.0, pts[0][1] + height * 0.02)
	pts[-1] = (0.0, pts[-1][1] - squash_top)
	return pts

# ---------- produce
def make_tomato(mat):
	rng = random.Random(1)
	b = Builder(SHEET)
	revolve(b, sphere_profile(0.052, 0.078, squash_top=0.008, rings=12), [("tomato", "tomato2")] * 12, seg=24)
	vert_noise(b, rng, 0.0014)
	top = max(v.z for v in b.verts)
	for k in range(5):  # calyx star
		a = 2 * math.pi * k / 5
		blade(b, (0, 0, top - 0.003), (0.026 * math.cos(a), 0.026 * math.sin(a), top + 0.003), 0.007, "leaf", lift=0.004, steps=2)
	b.box((0, 0, top + 0.006), (0.005, 0.005, 0.014), "stem")
	return b.to_object("Tomato", mat, bevel=0)

def make_apple(mat):
	rng = random.Random(2)
	b = Builder(SHEET)
	revolve(b, sphere_profile(0.046, 0.074, squash_top=0.012, bulge=1.06, rings=12), [("apple", "apple2")] * 12, seg=24)
	vert_noise(b, rng, 0.0012)
	top = max(v.z for v in b.verts)
	b.box((0.001, 0, top + 0.004), (0.004, 0.004, 0.022), "stem")
	blade(b, (0.003, 0, top + 0.012), (0.036, 0.008, top + 0.02), 0.011, "leaf", lift=0.006, steps=3)
	return b.to_object("Apple", mat, bevel=0)

def make_carrot(mat):
	rng = random.Random(3)
	b = Builder(SHEET)
	n = 11
	profile = [(0, 0.0)] + [(0.0035 + 0.0215 * (k / n) ** 0.8, 0.012 + 0.172 * k / n) for k in range(n + 1)]
	profile = [(0.0, 0.0)] + profile[1:] + [(0.0, profile[-1][1] + 0.002)]
	revolve(b, profile, [("carrot", "carrot2")] * (len(profile) - 1), seg=12)
	vert_noise(b, rng, 0.0008)
	top = max(v.z for v in b.verts)
	for k in range(7):  # leafy top
		a = 2 * math.pi * k / 7 + 0.3
		blade(b, (0, 0, top - 0.004), (0.026 * math.cos(a), 0.026 * math.sin(a), top + 0.075 + 0.01 * (k % 2)), 0.007, "leaf" if k % 2 else "leaf2", lift=0.01, steps=3)
	lay_along_x(b, 0)
	settle(b)
	return b.to_object("Carrot", mat, bevel=0)

def make_cabbage(mat):
	rng = random.Random(4)
	b = Builder(SHEET)
	profile = sphere_profile(0.085, 0.15, squash_top=0.01, rings=12)
	revolve(b, profile, [("cabbage", "cabbage2")] * 12, seg=24)
	for i, v in enumerate(b.verts):  # leaf layers: lobes around the head
		ang = math.atan2(v.y, v.x)
		bump = 1 + 0.06 * math.sin(4 * ang + v.z * 50) + rng.uniform(-0.01, 0.01)
		b.verts[i] = Vector((v.x * bump, v.y * bump, v.z))
	for k in range(0):  # big outer leaves flaring from the base
		a = 2 * math.pi * k / 7
		blade(b, (0.05 * math.cos(a), 0.05 * math.sin(a), 0.02), (0.135 * math.cos(a), 0.135 * math.sin(a), 0.045 + 0.02 * (k % 2)),
			0.058, "cabbage2" if k % 2 else "cabbage", lift=0.05, steps=5)
	return b.to_object("Cabbage", mat, bevel=0)

def make_corn(mat):
	rng = random.Random(5)
	b = Builder(SHEET)
	profile = [(0.0, 0.0), (0.013, 0.0), (0.021, 0.02), (0.025, 0.07), (0.025, 0.13), (0.021, 0.17), (0.011, 0.19), (0.0, 0.192)]
	revolve(b, profile, ["silk", "silk", "kernel", "kernel", "kernel", "kernel", "silk"], seg=24, label_bands=(2, 3, 4), label_region=KERNEL)
	# Replace the placeholder kernel swatch faces by printing the grid on the three middle bands
	for k in range(0):
		pass
	for k in range(5):  # husk leaves wrapped up from the base
		a = 2 * math.pi * k / 5 + 0.4
		blade(b, (0.016 * math.cos(a), 0.016 * math.sin(a), 0.0), (0.03 * math.cos(a), 0.03 * math.sin(a), 0.15 + 0.02 * (k % 2)),
			0.022, "husk" if k % 2 else "husk2", lift=0.015, steps=4)
	b.box((0, 0, -0.012), (0.014, 0.014, 0.03), "stem")
	lay_along_x(b, 0)
	settle(b)
	return b.to_object("Corn", mat, bevel=0)

project, render = project_args()
out_dir = os.path.join(project, "assets", "produce", "custom")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(1024, dict(SWATCHES, kernel="F2C230"), 560)
draw_print(SHEET)
png = os.path.join(out_dir, "produce_print.png")
SHEET.render(png)
mat = material("Produce", png, roughness=0.38)

BUILDERS = {"tomato": make_tomato, "apple": make_apple, "carrot": make_carrot, "cabbage": make_cabbage, "corn": make_corn}
objects = []
for pid, fn in BUILDERS.items():
	ob = fn(mat)
	export_glb(ob, os.path.join(out_dir, pid + ".glb"))
	objects.append(ob)
for i, ob in enumerate(objects):
	ob.location.x = (i - len(objects) / 2 + 0.5) * 0.3
if render: preview(render, (0, -2.2, 0.5), (0, 0, 0.06), size=(1600, 460), lens=60)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "produce.blend"))
print("SAVED", os.path.join(source, "produce.blend"))
