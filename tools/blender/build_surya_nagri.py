# Builds the kit for Gufa Darwaza Floor 2, Surya Nagri: a lost sun city at the bottom of a
# deep canyon (dungeon_floor.gd lays it out on a 4 m grid from dungeon_layouts.gd). Warm
# sandstone cliffs open to a hazy sky, carved pillars and temple fronts, palms, lanterns,
# stone water channels and, in the middle of the plaza, the golden Surya Chakra: a giant
# carved sun wheel that slowly turns. Our own design (owner's brief: an "ancient craft"
# canyon city), in the dungeon's toon look and kept light enough for Low.
#   floor / court / garden    one 4 x 4 m cell (top at 0): paving, the inlaid boss court, grass
#   cliff / cliff_vines / cliff_carved / cliff_lamp   the 18 m cliff on a cell's north edge
#   facade                    a temple front carved into the cliff (replaces a cliff piece)
#   corner                    a cliff buttress on a grid corner, hiding seams
#   channel / bridge          a stone water channel cell and an arched bridge over it
#   pillar / pillar_broken, palm_trunk / palm_leaves, lantern / lantern_glow, elephant, flag
#   chakra (the wheel, centred on its axle, axis -Y) / chakra_stand (plinth and posts)
#   tuft, rubble, ore_rock, entry_stone, stairs, chest_base / chest_lid, gem / gem_glow
# Front faces -Y here (+Z in Godot); a cell's centre is the origin.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_surya_nagri.py -- <project dir> [--render out.png]
# Writes assets/props/dungeon/floor2/*.glb, floor2_print.png and source/floor2.blend.
import bpy, os, sys, math, random
from mathutils import Matrix, Vector, noise
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

FLOOR = "floor2"
SWATCHES = {
	"sand": "B98D5F", "sand_mid": "9E744C", "sand_dark": "6F4F34", "strata": "C99C6B", "cliff_shadow": "4E3626",
	"paving": "A88661", "paving_dark": "866646", "joint": "5A4330", "carving": "9C7352", "carving_dark": "6E4C33",
	"grass": "7E9B45", "grass_dark": "5A7432", "vine": "4C7A34", "leaf": "6E9E3A", "leaf_dark": "4A7228",
	"trunk": "8E7050", "trunk_dark": "654C34", "gold": "E2AE45", "gold_light": "F6D27A", "gold_dark": "A87428",
	"bronze": "8F5E2E", "water_bed": "2F6F72", "hole": "140E0B", "doorway": "2A1C14",
	"stone": "B5ADA2", "stone_dark": "857D74", "rune": "FFC45C", "iron": "3A3633", "cloth": "E07A1F", "cloth_dark": "B5521A",
	"chest": "8B5A2B", "chest_dark": "5E3A1C", "gem": "FF9A2E", "gem_glow": "FFE07A", "glass": "F4E3B5",
	"lamp_glow": "FFC864", "flower": "E8506E", "flower_y": "F6C445", "ore": "F2C14E", "crack": "3A2A1E",
	"elephant": "9C958C", "elephant_dark": "726B63",
}

# ---------- helpers
def turn(b, first, matrix, pivot=(0, 0, 0)):
	"""Rotate every vertex added since `first` (Builder only boxes around Z)."""
	p = Vector(pivot)
	for i in range(first, len(b.verts)):
		b.verts[i] = matrix @ (b.verts[i] - p) + p

def rock(b, centre, size, rng, swatch="sand", seg=7, light="strata"):
	"""A rough lump: a lathe with jittered rings, squashed to `size` (x, y, z)."""
	sx, sy, sz = size
	first = len(b.verts)
	b.lathe((0, 0, 0), [(0.55, -0.5), (1.0, -0.12), (0.9, 0.28), (0.5, 0.5), (0.02, 0.56)], [swatch, swatch, swatch, light], seg)
	for i in range(first, len(b.verts)):
		v = b.verts[i]
		j = 1.0 + rng.uniform(-0.16, 0.16)
		b.verts[i] = Vector((centre[0] + v.x * sx * j, centre[1] + v.y * sy * j, centre[2] + v.z * sz * j))

def quad2(b, a, c, d, e, top, under):
	"""A double-sided quad (leaf, flag): two faces with their own vertices."""
	b.swatch_face([b.vert(a), b.vert(c), b.vert(d), b.vert(e)], top)
	lift = Vector((0, 0, -0.012))
	b.swatch_face([b.vert(Vector(e) + lift), b.vert(Vector(d) + lift), b.vert(Vector(c) + lift), b.vert(Vector(a) + lift)], under)

# ---------- ground
def floor_tile(mat, kind):
	rng = random.Random({"floor": 1, "court": 2, "garden": 3}[kind])
	b = Builder(SHEET)
	top = {"floor": "paving", "court": "carving", "garden": "grass"}[kind]
	b.box((0, 0, -0.15), (4.0, 4.0, 0.3), {"+z": top, "rest": "sand_dark"})
	if kind == "floor":
		# Big flagstones, some sunk or tilted, dark joints between them.
		for i in range(2):
			for j in range(2):
				h = rng.uniform(0.02, 0.06)
				b.box((-1.0 + i * 2.0 + rng.uniform(-0.05, 0.05), -1.0 + j * 2.0, h / 2), (1.9, 1.9, h), "paving", rot_z=rng.uniform(-2, 2))

	elif kind == "court":
		# The boss court: an inlaid sun (gold ring and rays) on dark carved stone.
		b.box((0, 0, 0.01), (3.9, 3.9, 0.02), "carving_dark")
		b.lathe((0, 0, 0.02), [(1.5, 0.0), (1.5, 0.02), (1.3, 0.02)], ["gold_dark", "gold"], 16)
		for k in range(8):
			b.box((1.0 * math.cos(k * math.pi / 4), 1.0 * math.sin(k * math.pi / 4), 0.035), (0.9, 0.12, 0.02), "gold", rot_z=k * 45)
		b.lathe((0, 0, 0.02), [(0.5, 0.0), (0.5, 0.03), (0.02, 0.04)], ["gold_light", "gold_light"], 12)
	else:
		for k in range(6):
			x, y = rng.uniform(-1.6, 1.6), rng.uniform(-1.6, 1.6)
			b.box((x, y, 0.1), (0.08, 0.08, 0.2), "grass_dark")
			b.box((x, y, 0.22), (0.16, 0.16, 0.08), "flower" if k % 2 else "flower_y")
	return b.to_object(kind.capitalize(), mat, bevel=0)

def tuft(mat):
	"""Grass blades scattered on the paving (many of them, one MultiMesh)."""
	b = Builder(SHEET)
	for k in range(5):
		a = k * 72
		b.box((0.12 * math.cos(math.radians(a)), 0.12 * math.sin(math.radians(a)), 0.16), (0.05, 0.03, 0.32), "grass" if k % 2 else "grass_dark", rot_z=a)
	return b.to_object("Tuft", mat, bevel=0)

# ---------- cliffs: rough rock with ledges
CLIFF_H = 18.0
# Ledge heights shared by every cliff piece, so the ledges run on unbroken along a wall.
LEDGES = [0.0, 2.3, 4.1, 6.6, 8.4, 10.9, 12.7, 15.2, 18.0]
BAND_PAINT = ["sand", "strata", "sand_mid", "strata", "sand", "sand_mid", "strata", "sand"]
# How far each layer is set back: hard layers stand out, soft ones are cut in under them.
BAND_BACK = [0.0, 0.45, 0.12, 0.6, 0.2, 0.5, 0.05, 0.4]

def _band(z):
	for i in range(len(LEDGES) - 1):
		if z <= LEDGES[i + 1] + 1e-6: return i, (z - LEDGES[i]) / (LEDGES[i + 1] - LEDGES[i])
	return len(LEDGES) - 2, 1.0

def _fbm(x, y, z):
	p = Vector((x, y, z))
	return noise.noise(p) + 0.5 * noise.noise(p * 2.03) + 0.25 * noise.noise(p * 4.1)

def rock_depth(x, z, seed, flat=None):
	"""How far the rock face stands back from the cell edge at (x, z): it leans back as it
	rises, each layer bulges out low and tucks in under the ledge above, plus rough noise.
	Near the piece's sides the noise depends on height only, so neighbours meet cleanly."""
	band, t = _band(z)
	# Near-vertical layer faces, rounded a little at their top and bottom edges.
	ledge = BAND_BACK[band % len(BAND_BACK)] - 0.12 * math.sin(math.pi * t)
	edge = max(0.0, min(1.0, (abs(x) - 1.5) / 0.7))
	rough = _fbm(x * 0.5 + seed * 7.1, z * 0.5, seed * 3.3) * (1.0 - edge) + _fbm(0.0, z * 0.5, 99.0) * edge
	depth = 0.035 * z + ledge + rough * 0.45
	if flat and flat(x, z): depth = 0.0
	return depth

def rock_sheet(b, seed, offset=0.0, flat=None, width=4.4):
	"""A displaced rock face for a cell's north edge (facing -y), CLIFF_H tall, with a lid on top."""
	xs = [-width / 2 + width * j / 8 for j in range(9)]
	zs = [-0.3]
	for i in range(len(LEDGES) - 1):
		for k in range(3): zs.append(LEDGES[i] + (LEDGES[i + 1] - LEDGES[i]) * k / 3)
	zs.append(CLIFF_H)
	rows = []
	for z in zs:
		rows.append([b.vert((x, 2.0 + offset + rock_depth(x, max(z, 0.0), seed, flat), z)) for x in xs])
	for i in range(len(zs) - 1):
		band, t = _band(max(zs[i], 0.0) + 0.01)
		paint = "sand_dark" if BAND_BACK[band % len(BAND_BACK)] > 0.4 else BAND_PAINT[band % len(BAND_PAINT)]
		for j in range(len(xs) - 1):
			b.swatch_face((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]), paint)
	top = [b.vert((x, 2.0 + offset + 3.5, CLIFF_H + 0.4)) for x in xs]
	for j in range(len(xs) - 1):
		b.swatch_face((rows[-1][j], rows[-1][j + 1], top[j + 1], top[j]), "sand_mid")

def surface_y(x, z, seed, offset=0.0, flat=None):
	return 2.0 + offset + rock_depth(x, z, seed, flat)

def cliff(mat, kind):
	"""The canyon wall on a cell's north edge: rough sandstone in layers with ledges."""
	seed = {"plain": 11, "vines": 12, "carved": 13, "lamp": 14}[kind]
	rng = random.Random(seed)
	b = Builder(SHEET)
	flat = None
	if kind == "carved": flat = lambda x, z: abs(x) < 1.5 and z < 4.6
	if kind == "lamp": flat = lambda x, z: abs(x) < 0.6 and 2.2 < z < 3.8
	rock_sheet(b, seed, 0.0, flat)
	for x in (-1.3, 0.2, 1.4):
		if kind == "carved" and abs(x) < 1.5: continue
		rock(b, (x + rng.uniform(-0.3, 0.3), surface_y(x, 0.3, seed) - 0.2, 0.3), (rng.uniform(0.8, 1.1), 0.55, 0.5), rng, "sand_mid", 6, "sand")
	if kind == "vines":
		for k in range(7):
			x = -1.8 + k * 0.6
			top = CLIFF_H * 0.62 + rng.uniform(-1, 2)
			length = rng.uniform(3.0, 8.0)
			z = top
			while z > top - length:
				b.box((x, surface_y(x, z, seed) - 0.06, z - 0.4), (0.12, 0.05, 0.85), "vine")
				z -= 0.8
			b.box((x, surface_y(x, z, seed) - 0.08, z), (0.32, 0.05, 0.3), "leaf")
		rock(b, (0.0, surface_y(0.0, 0.4, seed) - 0.2, 0.4), (1.6, 0.5, 0.45), rng, "grass", 6, "grass_dark")
	if kind == "carved":
		# A shrine niche on a smooth-cut face: dark recess, pilasters, lintel and frieze.
		b.box((0, 1.98, 1.6), (1.4, 0.04, 2.6), "doorway")
		for x in (-0.95, 0.95): b.box((x, 1.85, 1.5), (0.35, 0.35, 3.0), "carving")
		b.box((0, 1.82, 3.15), (2.4, 0.42, 0.35), "carving_dark")
		for x in range(-4, 5): b.box((x * 0.45, 1.93, 4.0), (0.3, 0.12, 0.3), "carving")
	if kind == "lamp":
		b.box((0, 1.75, 3.0), (0.12, 0.5, 0.1), "iron")
		b.lathe((0, 1.45, 0), [(0.16, 2.75), (0.22, 2.95), (0.12, 3.05)], ["bronze", "bronze"], 8)
	return b.to_object("Cliff" + kind.capitalize(), mat, bevel=0)

def facade(mat):
	"""A temple front carved into the cliff: plinth, four pillars, a dark doorway, a heavy
	lintel and a stepped tower relief topped by a gold kalash, on a smooth-cut face."""
	b = Builder(SHEET)
	rock_sheet(b, 15, 0.9, lambda x, z: z < 10.8)
	b.box((0, 1.55, 0.25), (4.2, 1.1, 0.5), {"+z": "carving", "rest": "carving_dark"})
	b.box((0, 2.08, 2.6), (1.7, 0.1, 4.2), "doorway")
	b.box((0, 2.85, 5.4), (4.4, 0.1, 10.8), "carving")
	for x in (-1.65, -0.95, 0.95, 1.65):
		b.lathe((x, 1.55, 0.5), [(0.26, 0.0), (0.2, 0.3), (0.2, 3.3), (0.3, 3.6), (0.3, 3.8)], ["carving", "carving", "carving_dark", "carving"], 8)
	b.box((0, 1.6, 4.55), (4.3, 1.0, 0.5), {"+z": "carving", "rest": "carving_dark"})
	for x in range(-6, 7): b.box((x * 0.32, 1.08, 4.55), (0.18, 0.06, 0.32), "gold_dark")
	for k, w in enumerate((3.4, 2.7, 2.0, 1.3)):
		b.box((0, 1.9 + k * 0.08, 5.3 + k * 1.0), (w, 0.9, 1.0), {"-y": "carving" if k % 2 else "sand_mid", "rest": "carving_dark"})
	b.lathe((0, 1.85, 9.3), [(0.35, 0.0), (0.45, 0.3), (0.2, 0.6), (0.25, 0.8), (0.02, 1.2)], ["gold", "gold_light", "gold", "gold_light"], 10)
	return b.to_object("Facade", mat, bevel=0)

def corner(mat):
	"""A rough rock buttress on a grid corner, hiding where two cliff faces meet."""
	b = Builder(SHEET)
	seg = 10
	zs = [-0.3]
	for i in range(len(LEDGES) - 1):
		for k in range(3): zs.append(LEDGES[i] + (LEDGES[i + 1] - LEDGES[i]) * k / 3)
	zs.append(CLIFF_H)
	rings = []
	for z in zs:
		band, t = _band(max(z, 0.0))
		ring = []
		for k in range(seg):
			a = 2 * math.pi * k / seg
			r = 1.35 + 0.04 * z - BAND_BACK[band % len(BAND_BACK)] * 0.6 + 0.12 * math.sin(math.pi * t) + _fbm(math.cos(a) * 1.3, max(z, 0.0) * 0.5, 16.0 + math.sin(a) * 1.3) * 0.3
			ring.append(b.vert((r * math.cos(a), r * math.sin(a), z)))
		rings.append(ring)
	for i in range(len(zs) - 1):
		band, t = _band(max(zs[i], 0.0) + 0.01)
		paint = "sand_dark" if BAND_BACK[band % len(BAND_BACK)] > 0.4 else BAND_PAINT[band % len(BAND_PAINT)]
		for k in range(seg):
			b.swatch_face((rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]), paint)
	centre = b.vert((0, 0, CLIFF_H + 0.3))
	for k in range(seg): b.swatch_face((rings[-1][k], rings[-1][(k + 1) % seg], centre), "sand_mid")
	return b.to_object("Corner", mat, bevel=0)

# ---------- water
def channel(mat):
	b = Builder(SHEET)
	b.box((0, 0, -1.0), (4.0, 4.0, 0.2), "water_bed")
	for side in (-1, 1):
		b.box((side * 1.8, 0, -0.45), (0.4, 4.0, 1.1), {"+z": "carving", "rest": "carving_dark"})
		b.box((side * 1.55, 0, -0.75), (0.2, 4.0, 0.5), "carving_dark")
	return b.to_object("Channel", mat, bevel=0)

def bridge(mat):
	"""A little stone arch across the channel (deck along x, parapets either side)."""
	b = Builder(SHEET)
	b.box((0, 0, 0.06), (4.2, 2.4, 0.18), {"+z": "paving", "rest": "carving_dark"})
	for k in range(7):
		a = math.pi * (k + 0.5) / 7
		b.box((1.4 * math.cos(a), 0, -0.05 - 0.5 * math.sin(a)), (0.6, 2.3, 0.22), "carving", rot_z=0)
	for side in (-1, 1):
		b.box((0, side * 1.12, 0.45), (4.2, 0.18, 0.6), {"+z": "carving", "rest": "carving_dark"})
		for x in (-2.0, 2.0): b.lathe((x, side * 1.12, 0.75), [(0.14, 0.0), (0.12, 0.2), (0.02, 0.3)], ["gold_dark", "gold"], 8)
	return b.to_object("Bridge", mat)

# ---------- props
def pillar(mat, broken):
	"""A carved stone pillar: square base, banded shaft, bracket capital (or a broken stump
	with two fallen drums beside it)."""
	rng = random.Random(17 if broken else 18)
	b = Builder(SHEET)
	b.box((0, 0, 0.3), (1.3, 1.3, 0.6), {"+z": "carving", "rest": "carving_dark"})
	b.box((0, 0, 0.75), (1.0, 1.0, 0.3), "carving")
	height = 2.0 if broken else 5.6
	b.lathe((0, 0, 0.9), [(0.38, 0.0), (0.34, height * 0.3), (0.42, height * 0.33), (0.34, height * 0.36), (0.32, height * 0.7), (0.4, height * 0.73), (0.32, height * 0.76), (0.3, height)],
		["sand", "carving", "carving", "sand", "carving", "carving", "sand"], 8)
	if broken:
		for k in range(5): rock(b, (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0.9 + height + rng.uniform(-0.1, 0.15)), (0.25, 0.25, 0.25), rng, "sand_mid", 5, "sand")
		for k, at in enumerate(((1.5, 0.4), (1.1, -1.3))):
			first = len(b.verts)
			b.lathe((0, 0, -0.55), [(0.36, 0.0), (0.36, 1.1), (0.02, 1.12)], ["sand", "carving"], 8)
			turn(b, first, Matrix.Rotation(math.pi / 2, 3, "Y") @ Matrix.Rotation(k * 0.9, 3, "Z"))
			for i in range(first, len(b.verts)): b.verts[i] += Vector((at[0], at[1], 0.36))
	else:
		b.box((0, 0, 0.9 + height + 0.2), (1.1, 1.1, 0.4), {"+z": "carving", "rest": "carving_dark"})
		b.box((0, 0, 0.9 + height + 0.55), (1.6, 0.6, 0.3), "carving_dark")
		b.box((0, 0, 0.9 + height + 0.55), (0.6, 1.6, 0.3), "carving_dark")
		for k in range(4): b.box((0.31 * math.cos(k * math.pi / 2), 0.31 * math.sin(k * math.pi / 2), 0.9 + height * 0.33), (0.08, 0.08, 0.12), "gold", rot_z=k * 90)
	return b.to_object("PillarBroken" if broken else "Pillar", mat)

def palm(mat, leaves):
	"""A leaning palm: ringed trunk segments, then nine drooping fronds (separate piece)."""
	b = Builder(SHEET)
	segs, height, lean = 9, 7.0, 0.9
	top = Vector((lean * ((segs - 1) / segs) ** 2, 0.25 * (segs - 1) / segs, height))
	if not leaves:
		for k in range(segs):
			z0, z1 = height * k / segs, height * (k + 1) / segs
			x = lean * (k / segs) ** 2
			r = 0.26 - 0.1 * k / segs
			b.lathe((x, 0.25 * k / segs, z0), [(r + 0.04, 0.0), (r, (z1 - z0) * 0.85), (r + 0.03, z1 - z0)], ["trunk" if k % 2 else "trunk_dark", "trunk_dark"], 7)
		for k in range(4): b.lathe((top.x + 0.2 * math.cos(k * 1.6), top.y + 0.2 * math.sin(k * 1.6), top.z - 0.35), [(0.13, 0.0), (0.13, 0.2), (0.02, 0.26)], ["bronze", "bronze"], 6)
		return b.to_object("PalmTrunk", mat, bevel=0)
	for k in range(9):
		yaw = k * 2 * math.pi / 9 + 0.2
		length = 3.0 + 0.5 * math.sin(k * 2.3)
		side = Vector((-math.sin(yaw), math.cos(yaw), 0))
		ahead = Vector((math.cos(yaw), math.sin(yaw), 0))
		prev = None
		for s in range(6):
			t = s / 5
			spine = top + ahead * length * t + Vector((0, 0, length * 0.32 * t - length * 0.75 * t * t))
			w = 0.55 * math.sin(math.pi * min(0.95, t * 0.9 + 0.08))
			left, right = spine + side * w + Vector((0, 0, -0.12 * w)), spine - side * w + Vector((0, 0, -0.12 * w))
			if prev: quad2(b, prev[0], prev[1], right, left, "leaf", "leaf_dark")
			prev = (left, right)
	return b.to_object("PalmLeaves", mat, bevel=0)

def lantern(mat, glow):
	"""A stone lamp post with a brass cage lantern; its glowing heart is a separate piece."""
	b = Builder(SHEET)
	if glow:
		b.lathe((0, 0, 2.62), [(0.05, 0.0), (0.16, 0.12), (0.16, 0.42), (0.02, 0.55)], ["lamp_glow", "lamp_glow", "lamp_glow"], 8)
		return b.to_object("LanternGlow", mat, bevel=0)
	b.box((0, 0, 0.2), (0.7, 0.7, 0.4), {"+z": "carving", "rest": "carving_dark"})
	b.lathe((0, 0, 0.4), [(0.2, 0.0), (0.16, 0.4), (0.18, 0.45), (0.14, 2.0), (0.24, 2.2), (0.24, 2.3)], ["sand", "carving", "sand", "carving", "carving_dark"], 8)
	for k in range(4):
		a = k * math.pi / 2 + math.pi / 4
		b.box((0.21 * math.cos(a), 0.21 * math.sin(a), 2.8), (0.05, 0.05, 0.62), "bronze")
	b.lathe((0, 0, 3.08), [(0.3, 0.0), (0.18, 0.2), (0.04, 0.42)], ["bronze", "gold_dark"], 8)
	b.lathe((0, 0, 2.48), [(0.28, 0.0), (0.28, 0.08)], ["bronze"], 8)
	return b.to_object("Lantern", mat)

def flag(mat):
	"""A saffron pennant on a pole (temple flags along the plaza)."""
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(0.07, 0.0), (0.05, 4.4), (0.08, 4.5), (0.02, 4.6)], ["bronze", "gold", "gold"], 6)
	quad2(b, Vector((0.05, 0, 4.4)), Vector((1.4, 0, 4.0)), Vector((1.4, 0, 3.95)), Vector((0.05, 0, 3.4)), "cloth", "cloth_dark")
	return b.to_object("Flag", mat, bevel=0)

def elephant(mat):
	"""A stone elephant on a plinth, trunk curled down, guarding a corner of the city."""
	rng = random.Random(19)
	b = Builder(SHEET)
	b.box((0, 0, 0.3), (2.0, 3.4, 0.6), {"+z": "carving", "rest": "carving_dark"})
	first = len(b.verts)
	b.lathe((0, 0, 0), [(0.02, -0.95), (0.7, -0.8), (0.95, -0.2), (0.95, 0.4), (0.7, 0.95), (0.02, 1.05)], ["elephant", "elephant", "elephant", "elephant", "elephant_dark"], 10)
	turn(b, first, Matrix.Rotation(math.pi / 2, 3, "X") @ Matrix.Diagonal((0.85, 1.0, 0.95)))
	for i in range(first, len(b.verts)): b.verts[i] += Vector((0, 0.2, 2.0))
	for x in (-0.5, 0.5):
		for y in (-0.55, 0.85): b.lathe((x, y, 0.6), [(0.3, 0.0), (0.26, 0.9), (0.24, 1.2)], ["elephant_dark", "elephant"], 7)
	b.lathe((0, -1.05, 2.25), [(0.02, -0.55), (0.5, -0.4), (0.55, 0.1), (0.4, 0.45), (0.02, 0.55)], ["elephant", "elephant", "elephant", "elephant"], 8)
	for side in (-1, 1):
		b.box((side * 0.62, -1.0, 2.3), (0.08, 0.75, 0.85), "elephant_dark", rot_z=side * 20)
		b.lathe((side * 0.22, -1.35, 1.9), [(0.07, 0.0), (0.05, 0.3), (0.01, 0.42)], ["glass", "glass"], 6)
	for k in range(5):
		r = 0.17 - k * 0.025
		b.lathe((0, -1.4 - 0.08 * k, 1.85 - k * 0.32), [(r, 0.0), (r, 0.34)], ["elephant"], 7)
	b.box((0, 0.25, 2.92), (1.3, 1.5, 0.1), "cloth")
	b.box((0, 0.25, 2.88), (1.35, 1.55, 0.06), "gold_dark")
	return b.to_object("Elephant", mat, bevel=0)

# ---------- the Surya Chakra
def chakra(mat):
	"""The sun wheel, built flat around Z, then stood up (axis along -Y, centre at origin):
	a beaded rim, eight wide spokes with medallions, eight thin spokes and a lotus hub."""
	b = Builder(SHEET)
	R = 4.0
	b.lathe((0, 0, 0), [(R - 0.5, -0.3), (R, -0.3), (R + 0.06, 0.0), (R, 0.3), (R - 0.5, 0.3), (R - 0.55, 0.0), (R - 0.5, -0.3)],
		["gold_dark", "gold", "gold_light", "gold", "gold_dark", "gold_dark"], 36)
	for k in range(24):
		a = k * 360 / 24
		for z in (-0.33, 0.33):
			b.box(((R - 0.25) * math.cos(math.radians(a)), (R - 0.25) * math.sin(math.radians(a)), z), (0.16, 0.22, 0.08), "gold_light", rot_z=a)
	for k in range(8):
		a = k * 45
		c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
		b.box((2.2 * c, 2.2 * s, 0), (2.7, 0.55, 0.42), {"+z": "gold", "-z": "gold", "rest": "gold_dark"}, rot_z=a)
		for z, sign in ((0.21, 1), (-0.21, -1)):
			first = len(b.verts)
			b.lathe((0, 0, 0), [(0.48, 0.0), (0.48, 0.08), (0.34, 0.16), (0.02, 0.2)], ["gold_dark", "gold", "gold_light"], 10)
			if sign < 0: turn(b, first, Matrix.Rotation(math.pi, 3, "X"))
			for i in range(first, len(b.verts)): b.verts[i] += Vector((2.3 * c, 2.3 * s, z))
		a2 = a + 22.5
		b.box((2.2 * math.cos(math.radians(a2)), 2.2 * math.sin(math.radians(a2)), 0), (2.7, 0.18, 0.24), "gold_dark", rot_z=a2)
	b.lathe((0, 0, 0), [(0.02, -0.62), (0.6, -0.55), (1.05, -0.4), (1.05, 0.3), (0.8, 0.45), (0.4, 0.6), (0.02, 0.66)], ["gold_light", "gold", "gold_dark", "gold", "gold_light", "gold_light"], 16)
	for k in range(8):
		a = k * 45 + 22.5
		b.box((0.95 * math.cos(math.radians(a)), 0.95 * math.sin(math.radians(a)), 0.38), (0.5, 0.26, 0.1), "gem", rot_z=a)
	turn(b, 0, Matrix.Rotation(math.pi / 2, 3, "X"))
	return b.to_object("Chakra", mat, bevel=0)

def chakra_stand(mat):
	"""The wheel's plinth: a stepped platform whose top the wheel's rim sinks into, a carved
	post behind the wheel and the bronze axle through the hub (wheel centre 5.2 m up)."""
	b = Builder(SHEET)
	for k, (w, d, h) in enumerate(((7.6, 4.0, 0.4), (6.8, 3.2, 0.4), (6.0, 2.6, 0.5))):
		b.box((0, 0, 0.2 + k * 0.4 + (0.05 if k == 2 else 0)), (w, d, h), {"+z": "carving" if k < 2 else "paving", "rest": "carving_dark"})
	b.box((0, 0.95, 3.3), (0.8, 0.5, 4.0), {"-y": "carving", "+y": "carving", "rest": "carving_dark"})
	b.box((0, 0.95, 5.55), (1.2, 0.6, 0.5), "carving_dark")
	b.lathe((0, 0.95, 5.8), [(0.3, 0.0), (0.36, 0.25), (0.02, 0.65)], ["gold_dark", "gold"], 8)
	first = len(b.verts)
	b.lathe((0, 0, -1.0), [(0.26, 0.0), (0.26, 1.5)], ["bronze"], 10)
	turn(b, first, Matrix.Rotation(math.pi / 2, 3, "X"))
	for i in range(first, len(b.verts)): b.verts[i] += Vector((0, 0, 5.2))
	for k in range(6): b.box((-2.4 + k * 0.96, -2.0, 0.2), (0.5, 0.06, 0.25), "gold_dark")
	return b.to_object("ChakraStand", mat)

# ---------- loot, entry, exits
def rubble(mat):
	rng = random.Random(21)
	b = Builder(SHEET)
	for k in range(8):
		a, d, size = rng.uniform(0, 2 * math.pi), rng.uniform(0.0, 0.9), rng.uniform(0.16, 0.42)
		rock(b, (d * math.cos(a), d * math.sin(a), size * 0.3), (size * 1.2, size, size * 0.8), rng, "sand_mid" if k % 3 else "carving", 5, "sand")
	b.box((1.0, -0.5, 0.08), (0.9, 0.5, 0.16), "carving", rot_z=24)
	return b.to_object("Rubble", mat, bevel=0)

def ore_rock(mat):
	rng = random.Random(22)
	b = Builder(SHEET)
	rock(b, (0, 0, 0.5), (0.95, 0.85, 1.0), rng, "sand_dark", 8, "sand_mid")
	rock(b, (0.35, 0.3, 0.3), (0.5, 0.45, 0.5), rng, "sand_mid", 6, "sand")
	for k in range(4):
		a = k * 1.7 + 0.4
		b.box((0.78 * math.cos(a), 0.78 * math.sin(a), 0.45 + 0.1 * k), (0.2, 0.2, 0.34), "ore", rot_z=math.degrees(a))
	b.box((0, -0.8, 0.55), (0.04, 0.03, 0.7), "crack")
	return b.to_object("OreRock", mat, bevel=0)

def entry_stone(mat):
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(1.5, 0.0), (1.4, 0.25), (1.2, 0.3), (0.02, 0.32)], ["stone_dark", "stone", "stone"], 16)
	for k in range(12):
		a = 2 * math.pi * k / 12
		b.box((1.05 * math.cos(a), 1.05 * math.sin(a), 0.33), (0.3, 0.08, 0.03), "rune", rot_z=math.degrees(a))
	return b.to_object("EntryStone", mat)

def stairs(mat):
	rng = random.Random(9)
	b = Builder(SHEET)
	b.box((0, 0.3, -0.6), (2.6, 3.0, 0.1), "hole")
	for k in range(4):
		b.box((0, -1.0 + k * 0.6, -0.15 - k * 0.3), (2.4, 0.6, 0.3), "carving" if k % 2 == 0 else "carving_dark")
	for side in (-1, 1):
		b.box((side * 1.45, 0.3, -0.3), (0.3, 3.0, 0.9), "carving_dark")
		b.lathe((side * 1.5, -1.3, 0), [(0.25, 0.0), (0.2, 1.4), (0.3, 1.5), (0.02, 1.7)], ["carving", "carving", "gold"], 8)
	b.box((0, 1.75, 1.2), (3.4, 0.5, 2.4), {"-y": "carving", "rest": "carving_dark"})
	b.box((0, 1.6, 2.5), (3.6, 0.7, 0.3), "carving_dark")
	return b.to_object("Stairs", mat)

def chest(mat, lid):
	b = Builder(SHEET)
	if not lid:
		b.box((0, 0, 0.3), (1.2, 0.75, 0.6), "chest")
		for x in (-0.45, 0.45): b.box((x, 0, 0.3), (0.08, 0.78, 0.62), "gold")
		b.box((0, -0.39, 0.42), (0.18, 0.04, 0.2), "gold")
	else:
		b.box((0, -0.375, 0.12), (1.22, 0.77, 0.24), "chest_dark")
		for x in (-0.45, 0.45): b.box((x, -0.375, 0.12), (0.08, 0.79, 0.26), "gold")
	return b.to_object("ChestLid" if lid else "ChestBase", mat)

def gem(mat, glow):
	"""A Surya gem on a little brass dish; the gem itself glows (separate, unshaded)."""
	b = Builder(SHEET)
	if glow:
		b.lathe((0, 0, 0.12), [(0.02, 0.0), (0.16, 0.12), (0.12, 0.26), (0.02, 0.34)], ["gem", "gem_glow", "gem_glow"], 6)
		return b.to_object("GemGlow", mat, bevel=0)
	b.lathe((0, 0, 0), [(0.12, 0.0), (0.24, 0.08), (0.26, 0.12), (0.02, 0.13)], ["bronze", "gold_dark", "gold"], 10)
	return b.to_object("Gem", mat)

# ---------- build
project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "dungeon", FLOOR)
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(512, SWATCHES, 16, 64)
png = os.path.join(out_dir, FLOOR + "_print.png")
SHEET.render(png)
# Which swatches are metal (white): the realistic shader (real_detail.gdshaderinc) makes them
# polished metal. Same layout as the print, so the same UVs read it.
METALS = ("gold", "gold_light", "gold_dark", "bronze", "ore", "iron")
Sheet(512, {name: ("FFFFFF" if name in METALS else "000000") for name in SWATCHES}, 16, 64).render(os.path.join(out_dir, FLOOR + "_metal.png"), "000000")
mat = material("Kit", png)
pieces = {
	"floor": floor_tile(mat, "floor"), "court": floor_tile(mat, "court"), "garden": floor_tile(mat, "garden"), "tuft": tuft(mat),
	"cliff": cliff(mat, "plain"), "cliff_vines": cliff(mat, "vines"), "cliff_carved": cliff(mat, "carved"), "cliff_lamp": cliff(mat, "lamp"),
	"facade": facade(mat), "corner": corner(mat), "channel": channel(mat), "bridge": bridge(mat),
	"pillar": pillar(mat, False), "pillar_broken": pillar(mat, True), "palm_trunk": palm(mat, False), "palm_leaves": palm(mat, True),
	"lantern": lantern(mat, False), "lantern_glow": lantern(mat, True), "flag": flag(mat), "elephant": elephant(mat),
	"chakra": chakra(mat), "chakra_stand": chakra_stand(mat),
	"rubble": rubble(mat), "ore_rock": ore_rock(mat), "entry_stone": entry_stone(mat), "stairs": stairs(mat),
	"chest_base": chest(mat, False), "chest_lid": chest(mat, True), "gem": gem(mat, False), "gem_glow": gem(mat, True),
}
for name, ob in pieces.items(): export_glb(ob, os.path.join(out_dir, name + ".glb"))
# Preview: the plaza with the wheel, a cliff row and its props.
layout = {"floor": (0, 0), "court": (4, 0), "garden": (-4, 0), "cliff": (-4, 4), "cliff_vines": (0, 4), "facade": (4, 4), "cliff_carved": (8, 4),
	"corner": (-6, 6), "chakra_stand": (0, -6), "pillar": (-5, -3), "pillar_broken": (6, -2), "palm_trunk": (-8, -4), "palm_leaves": (-8, -4),
	"lantern": (3.5, -3), "lantern_glow": (3.5, -3), "flag": (-3, -9), "elephant": (8, -6), "channel": (12, 0), "bridge": (12, 0),
	"gem": (1, -1), "gem_glow": (1, -1), "chest_base": (-1.5, -1.5), "ore_rock": (9, 0), "entry_stone": (-3, -12), "stairs": (12, 4)}
for name, ob in pieces.items():
	at = layout.get(name, (60, 60))
	ob.location = (at[0], at[1], 0)
pieces["chakra"].location = (0, -6, 5.2)
pieces["chest_lid"].location = (-1.5, -1.875, 0.6)
if render: preview(render, (10, -30, 9), (1, 0, 5), lens=30)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, FLOOR + ".blend"))
print("SAVED", os.path.join(source, FLOOR + ".blend"))
