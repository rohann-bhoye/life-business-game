# Builds the Gufa Darwaza cave mouth on the west hill (dungeon_world.gd places it):
#   cave_mouth.glb  a rocky arch and rock mound that sink into the hillside, a short dark
#                   tunnel, a wooden frame with a half-open iron gate, two wall torch
#                   brackets and a yellow KHATRA warning board (Godot writes the rank on it)
#   gate_ring.glb   the stone Darwaza ring with glowing runes at the tunnel's end (the
#                   swirl inside it is portal.gdshader in Godot)
# Front faces -Y here (+Z in Godot), origin at the middle of the mouth's floor edge.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_cave_entrance.py -- <project dir> [--render out.png]
# Writes assets/props/dungeon/cave_mouth.glb, gate_ring.glb, cave_print.png, source/cave.blend.
import bpy, os, sys, math, random
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

SWATCHES = {
	"rock": "6E6A60", "rock_dark": "57534B", "rock_light": "88837A", "moss": "5E8F4A",
	"tunnel": "1E1A24", "tunnel_floor": "2E2A30", "wood": "7A4E2D", "wood_dark": "5A3820",
	"iron": "3A3D42", "bolt": "9AA0A6", "board_post": "6B4A2F", "ring": "8E8A86",
	"ring_dark": "6C6864", "rune": "6FD3FF", "flame_cup": "2B2B2B",
}
BOARD = (16, 16, 480, 240)
MOUTH_W, MOUTH_H, DEPTH = 3.8, 4.4, 3.4

def draw_print(s):
	x, y, w, h = BOARD
	s.rect(x, y, w, h, "F2C230")
	s.rect(x + 10, y + 10, w - 20, h - 20, "1F1F1F", 0.01)
	s.rect(x + 16, y + 16, w - 32, h - 32, "F2C230", 0.02)
	s.text("KHATRA!", x + w / 2, y + 74, 64, "C0392B", 0.03, "ariblk.ttf", w - 60)
	s.text("GUFA DARWAZA", x + w / 2, y + 128, 34, "1F1F1F", 0.03, "ariblk.ttf", w - 60)
	s.text("Rank:", x + 120, y + 190, 30, "1F1F1F", 0.03, "arialbd.ttf", 200)

def rock(b, centre, size, rng, swatch="rock", seg=7):
	"""A rough boulder: a lathe whose rings are jittered, squashed to `size` (x, y, z)."""
	sx, sy, sz = size
	first = len(b.verts)
	b.lathe((0, 0, 0), [(0.55, -0.5), (1.0, -0.12), (0.9, 0.28), (0.5, 0.5), (0.0, 0.56)],
		[swatch, swatch, swatch, "rock_light" if swatch == "rock" else swatch], seg)
	for i in range(first, len(b.verts)):
		v = b.verts[i]
		j = 1.0 + rng.uniform(-0.16, 0.16)
		b.verts[i] = type(v)((centre[0] + v.x * sx * j, centre[1] + v.y * sy * j, centre[2] + v.z * sz * j))

def cave_mouth(mat):
	rng = random.Random(11)
	b = Builder(SHEET)
	half = MOUTH_W / 2
	# Tunnel: dark floor, walls, ceiling and back, so the mouth reads deep.
	b.box((0, DEPTH / 2, -0.05), (MOUTH_W + 0.6, DEPTH, 0.1), "tunnel_floor")
	for x in (-half - 0.15, half + 0.15): b.box((x, DEPTH / 2, MOUTH_H / 2), (0.3, DEPTH, MOUTH_H), "tunnel")
	b.box((0, DEPTH / 2, MOUTH_H + 0.15), (MOUTH_W + 0.6, DEPTH, 0.3), "tunnel")
	b.box((0, DEPTH + 0.15, MOUTH_H / 2), (MOUTH_W + 0.6, 0.3, MOUTH_H), "tunnel")
	# Rocks round the arch, then a mound over and behind it, and side rocks into the hill.
	for k in range(9):
		a = math.pi * k / 8
		rock(b, (2.8 * math.cos(a), 0.2 + rng.uniform(-0.1, 0.25), 0.3 + 4.6 * math.sin(a)), (1.0 + rng.uniform(0, 0.3), 0.9, 1.0 + rng.uniform(0, 0.25)), rng)
	rock(b, (0, 1.7, 5.2), (3.2, 2.2, 1.6), rng)
	rock(b, (0, 7.6, 3.0), (6.0, 4.4, 7.0), rng, "rock_dark", 9)
	for side in (-1, 1):
		rock(b, (side * 4.3, 1.2, 0.6), (2.2, 2.4, 2.0), rng)
		rock(b, (side * 4.4, 2.6, 1.6), (2.4, 2.8, 3.0), rng, "rock_dark")
	for k in range(5):
		rock(b, (rng.uniform(-2.4, 2.4), rng.uniform(0.6, 2.6), 5.6 + rng.uniform(0, 0.8)), (1.2, 1.0, 0.5), rng, "moss", 6)
	# Wooden frame with a half-open iron gate on the left post.
	for x in (-half + 0.1, half - 0.1):
		b.box((x, -0.15, 1.8), (0.28, 0.28, 3.6), "wood")
	b.box((0, -0.15, 3.7), (MOUTH_W + 0.2, 0.32, 0.3), "wood_dark")
	for x in (-1.1, 0.0, 1.1): b.box((x, -0.33, 3.7), (0.1, 0.04, 0.1), "bolt")
	hinge = (-half + 0.25, -0.2)
	turn = math.radians(62)
	for k in range(6):
		d = 0.15 + k * 0.3
		b.box((hinge[0] + d * math.cos(turn), hinge[1] - d * math.sin(turn), 1.55), (0.06, 0.06, 3.0), "iron")
	for z in (0.3, 1.6, 2.9):
		d = 0.9
		b.box((hinge[0] + d * math.cos(turn), hinge[1] - d * math.sin(turn), z), (1.75, 0.07, 0.08), "iron", rot_z=-62)
	# Torch brackets either side (Godot adds the flames).
	for side in (-1, 1):
		b.box((side * 2.75, -0.35, 2.55), (0.1, 0.5, 0.08), "iron")
		b.box((side * 2.75, -0.6, 2.45), (0.14, 0.14, 0.5), "wood_dark")
		b.lathe((side * 2.75, -0.6, 0), [(0.12, 2.7), (0.18, 2.92)], ["flame_cup"], 8)
	# Warning board on a post to the right of the mouth.
	bx, by = 3.6, -1.6
	b.box((bx, by + 0.14, 0.9), (0.14, 0.14, 1.8), "board_post")
	b.box((bx, by + 0.06, 1.75), (1.7, 0.06, 0.88), "wood_dark")
	idx = [b.vert((bx - 0.8, by - 0.0, 1.35)), b.vert((bx + 0.8, by - 0.0, 1.35)), b.vert((bx + 0.8, by - 0.0, 2.15)), b.vert((bx - 0.8, by - 0.0, 2.15))]
	b.region_face(idx, BOARD)
	return b.to_object("CaveMouth", mat)

def gate_ring(mat):
	"""A vertical stone ring (facing -Y) 3.6 m across, rune tiles on its face."""
	b = Builder(SHEET)
	seg, r_in, r_out, front, back = 24, 1.55, 1.95, -0.15, 0.15
	ring = []
	for k in range(seg):
		a = 2 * math.pi * k / seg
		c, s = math.cos(a), math.sin(a)
		ring.append([b.vert((r_in * c, front, r_in * s)), b.vert((r_out * c, front, r_out * s)), b.vert((r_out * c, back, r_out * s)), b.vert((r_in * c, back, r_in * s))])
	for k in range(seg):
		p, q = ring[k], ring[(k + 1) % seg]
		b.swatch_face((p[0], q[0], q[1], p[1]), "ring")
		b.swatch_face((p[1], q[1], q[2], p[2]), "ring_dark")
		b.swatch_face((p[2], q[2], q[3], p[3]), "ring")
		b.swatch_face((p[3], q[3], q[0], p[0]), "ring_dark")
	for k in range(8):
		a = 2 * math.pi * (k + 0.5) / 8
		b.box(((r_in + r_out) / 2 * math.cos(a), front - 0.02, (r_in + r_out) / 2 * math.sin(a)), (0.2, 0.04, 0.2), "rune")
	b.box((0, 0, -r_out - 0.1), (1.6, 0.6, 0.3), "ring_dark")
	return b.to_object("GateRing", mat)

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "dungeon")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(512, SWATCHES, 280, 72)
draw_print(SHEET)
png = os.path.join(out_dir, "cave_print.png")
SHEET.render(png)
mat = material("Cave", png)
mouth, ring = cave_mouth(mat), gate_ring(mat)
export_glb(mouth, os.path.join(out_dir, "cave_mouth.glb"))
export_glb(ring, os.path.join(out_dir, "gate_ring.glb"))
ring.location = (0, DEPTH - 0.4, 2.15)
if render: preview(render, (6.5, -11, 4.0), (0, 1.0, 2.2), lens=38)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "cave.blend"))
print("SAVED", os.path.join(source, "cave.blend"))
