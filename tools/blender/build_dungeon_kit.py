# Builds a dungeon floor's kit for Gufa Darwaza (dungeon_floor.gd lays it out on a
# 4 m grid from dungeon_layouts.gd). Every piece is its own .glb sharing the floor's
# atlas; glowing parts (mushroom caps, the glow in a firefly jar) are separate pieces so
# the game draws them unshaded. Floor 1 is Jugnu Gufa, the firefly cave: blue-grey
# rock, moss, glowing mushrooms and a stream.
#   floor / ceiling          one 4 x 4 m cell (floor top at 0, ceiling underside 5.2)
#   wall / wall_moss / wall_torch   the rock face on a cell's north edge, facing into it
#   corner                   a rock pillar on a grid corner, hiding wall seams
#   stream / bridge          a stream bed cell and a plank bridge across it
#   mushroom_stem / mushroom_cap, boulder, stalagmite
#   entry_stone, stairs, chest_base / chest_lid (hinge at the back), jar / jar_glow
# Front faces -Y here (+Z in Godot); a cell's centre is the origin.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_dungeon_kit.py -- <project dir> [--render out.png]
# Writes assets/props/dungeon/floor1/*.glb, floor1_print.png and source/floor1.blend.
import bpy, os, sys, math, random
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

FLOOR = "floor1"
SWATCHES = {
	"rock": "3B4A5A", "rock_dark": "2A3644", "rock_light": "52637A", "floor": "45525E", "pebble": "5F6E7C",
	"moss": "4E9F6E", "moss_dark": "3A7A54", "vine": "2F6B44", "ceiling": "222C38",
	"stream_bed": "24404A", "plank": "8A6238", "plank_dark": "5E4126", "rope": "C9B184",
	"stem": "E6E0CF", "cap": "C8FF6A", "cap_spot": "F4FFD0", "cap_blue": "3FC1C9", "cap_pink": "FF7FD0",
	"stone": "8C8A86", "stone_dark": "6A6866", "rune": "6FD3FF", "iron": "3A3D42", "wood": "7A4E2D",
	"chest": "8B5A2B", "chest_dark": "5E3A1C", "gold": "E8B84A", "glass": "BFEFF5", "cork": "A67C52",
	"glow": "D8FF7A", "hole": "0B0E14", "ore": "9FE8FF", "crack": "151B24",
}

def rock(b, centre, size, rng, swatch="rock", seg=7, light="rock_light"):
	"""A rough boulder: a lathe with jittered rings, squashed to `size` (x, y, z)."""
	sx, sy, sz = size
	first = len(b.verts)
	b.lathe((0, 0, 0), [(0.55, -0.5), (1.0, -0.12), (0.9, 0.28), (0.5, 0.5), (0.02, 0.56)], [swatch, swatch, swatch, light], seg)
	for i in range(first, len(b.verts)):
		v = b.verts[i]
		j = 1.0 + rng.uniform(-0.18, 0.18)
		b.verts[i] = type(v)((centre[0] + v.x * sx * j, centre[1] + v.y * sy * j, centre[2] + v.z * sz * j))

def rubble(mat):
	"""A heap of broken stone: angular chunks of different sizes, a cracked slab beside them."""
	rng = random.Random(21)
	b = Builder(SHEET)
	for k in range(9):
		a = rng.uniform(0, 2 * math.pi)
		d = rng.uniform(0.0, 0.9)
		size = rng.uniform(0.16, 0.42)
		rock(b, (d * math.cos(a), d * math.sin(a), size * 0.3), (size * 1.2, size, size * 0.8), rng, "rock" if k % 3 else "rock_dark", 5, "rock_light")
	b.box((1.1, -0.5, 0.06), (0.9, 0.7, 0.12), "rock_dark", rot_z=24)
	b.box((1.1, -0.5, 0.125), (0.9, 0.06, 0.02), "crack", rot_z=24)
	return b.to_object("Rubble", mat)

def ore_rock(mat):
	"""A rock to break open: a rough boulder with glowing pale-blue veins and dark cracks."""
	rng = random.Random(22)
	b = Builder(SHEET)
	rock(b, (0, 0, 0.5), (0.95, 0.85, 1.0), rng, "rock_dark", 8, "rock")
	rock(b, (0.35, 0.3, 0.3), (0.5, 0.45, 0.5), rng, "rock", 6, "rock_light")
	for k in range(4):
		a = k * 1.7 + 0.4
		b.box((0.78 * math.cos(a), 0.78 * math.sin(a), 0.45 + 0.1 * k), (0.2, 0.2, 0.34), "ore", rot_z=math.degrees(a))
	b.box((0, -0.8, 0.55), (0.04, 0.03, 0.7), "crack")
	b.box((0.1, -0.78, 0.3), (0.3, 0.03, 0.04), "crack")
	return b.to_object("OreRock", mat)

def floor_tile(mat):
	rng = random.Random(1)
	b = Builder(SHEET)
	b.box((0, 0, -0.15), (4.0, 4.0, 0.3), {"+z": "floor", "rest": "rock_dark"})
	for k in range(5):
		rock(b, (rng.uniform(-1.6, 1.6), rng.uniform(-1.6, 1.6), 0.02), (0.22, 0.2, 0.12), rng, "pebble", 5, "pebble")
	for k in range(2):
		rock(b, (rng.uniform(-1.3, 1.3), rng.uniform(-1.3, 1.3), 0.0), (0.45, 0.4, 0.14), rng, "moss", 6, "moss_dark")
	return b.to_object("Floor", mat)

def ceiling(mat):
	rng = random.Random(2)
	b = Builder(SHEET)
	b.box((0, 0, 5.45), (4.2, 4.2, 0.5), {"-z": "ceiling", "rest": "rock_dark"})
	for k in range(3):
		x, y = rng.uniform(-1.4, 1.4), rng.uniform(-1.4, 1.4)
		b.lathe((x, y, 0), [(0.02, 4.1 + rng.uniform(0, 0.4)), (0.18, 4.8), (0.32, 5.22)], ["rock", "rock_dark"], 6)
	return b.to_object("Ceiling", mat)

def wall(mat, kind):
	rng = random.Random({"plain": 3, "moss": 4, "torch": 5}[kind])
	b = Builder(SHEET)
	b.box((0, 2.5, 2.7), (4.3, 1.0, 5.6), "rock_dark")
	for k in range(5):
		z = 0.5 + k * 1.15
		for x in (-1.3, 0.1, 1.4):
			rock(b, (x + rng.uniform(-0.3, 0.3), 2.05 + rng.uniform(-0.1, 0.15), z + rng.uniform(-0.2, 0.2)), (rng.uniform(0.9, 1.2), 0.55, rng.uniform(0.75, 1.0)), rng)
	if kind == "moss":
		for x in (-1.2, 0.3, 1.3):
			rock(b, (x, 1.75, 0.35), (0.9, 0.5, 0.45), rng, "moss", 6, "moss_dark")
		for k in range(6):
			b.box((-1.6 + k * 0.62, 1.62, 4.2 - (k % 3) * 0.35), (0.06, 0.04, 1.6 + (k % 3) * 0.6), "vine")
	if kind == "torch":
		b.box((0, 1.62, 3.0), (0.1, 0.5, 0.08), "iron")
		b.box((0, 1.38, 2.88), (0.14, 0.14, 0.5), "wood")
		b.lathe((0, 1.38, 0), [(0.12, 3.1), (0.18, 3.3)], ["iron"], 8)
	return b.to_object("Wall" + kind.capitalize(), mat)

def corner(mat):
	rng = random.Random(6)
	b = Builder(SHEET)
	for k in range(4):
		rock(b, (rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), 0.6 + k * 1.3), (0.9, 0.9, 1.0), rng, "rock" if k % 2 else "rock_dark")
	return b.to_object("Corner", mat)

def stream(mat):
	rng = random.Random(7)
	b = Builder(SHEET)
	b.box((0, 0, -1.0), (4.0, 4.0, 0.2), "stream_bed")
	for side in (-1, 1):
		b.box((side * 1.85, 0, -0.5), (0.3, 4.0, 1.0), "rock_dark")
		for k in range(3):
			rock(b, (side * 1.7, -1.3 + k * 1.3, -0.05), (0.5, 0.6, 0.35), rng, "moss" if k == 1 else "rock", 6)
	return b.to_object("Stream", mat)

def bridge(mat):
	b = Builder(SHEET)
	for k in range(10):
		b.box((-1.8 + k * 0.4, 0, 0.04), (0.34, 2.2, 0.08), "plank" if k % 2 else "plank_dark")
	for side in (-1, 1):
		b.box((0, side * 1.0, -0.06), (4.0, 0.14, 0.12), "plank_dark")
		for x in (-1.8, 0.0, 1.8): b.box((x, side * 1.05, 0.5), (0.1, 0.1, 1.0), "plank_dark")
		b.box((0, side * 1.05, 0.95), (3.8, 0.04, 0.04), "rope")
	return b.to_object("Bridge", mat)

def mushroom_stem(mat):
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(0.12, 0.0), (0.08, 0.35), (0.07, 0.62)], ["stem", "stem"], 7)
	return b.to_object("MushroomStem", mat)

def mushroom_cap(mat):
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(0.08, 0.56), (0.36, 0.6), (0.3, 0.74), (0.16, 0.83), (0.02, 0.86)], ["cap", "cap", "cap", "cap_spot"], 8)
	return b.to_object("MushroomCap", mat)

def boulder(mat):
	rng = random.Random(8)
	b = Builder(SHEET)
	rock(b, (0, 0, 0.55), (1.3, 1.1, 1.2), rng)
	rock(b, (0.9, 0.4, 0.3), (0.7, 0.6, 0.6), rng)
	rock(b, (-0.2, -0.1, 1.05), (0.9, 0.8, 0.35), rng, "moss", 6, "moss_dark")
	return b.to_object("Boulder", mat)

def stalagmite(mat):
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(0.45, 0.0), (0.3, 0.8), (0.14, 1.7), (0.02, 2.4)], ["rock", "rock", "rock_light"], 7)
	b.lathe((0.5, 0.2, 0), [(0.22, 0.0), (0.12, 0.6), (0.02, 1.1)], ["rock", "rock_light"], 6)
	return b.to_object("Stalagmite", mat)

def entry_stone(mat):
	b = Builder(SHEET)
	b.lathe((0, 0, 0), [(1.5, 0.0), (1.4, 0.25), (1.2, 0.3), (0.02, 0.32)], ["stone_dark", "stone", "stone"], 16)
	for k in range(8):
		a = 2 * math.pi * k / 8
		b.box((1.05 * math.cos(a), 1.05 * math.sin(a), 0.33), (0.18, 0.18, 0.03), "rune")
	return b.to_object("EntryStone", mat)

def stairs(mat):
	rng = random.Random(9)
	b = Builder(SHEET)
	b.box((0, 0.3, -0.6), (2.6, 3.0, 0.1), "hole")
	for k in range(4):
		b.box((0, -1.0 + k * 0.6, -0.15 - k * 0.3), (2.4, 0.6, 0.3), "stone" if k % 2 == 0 else "stone_dark")
	for side in (-1, 1):
		b.box((side * 1.45, 0.3, -0.3), (0.3, 3.0, 0.9), "stone_dark")
		for k in range(3): rock(b, (side * 1.7, -0.9 + k * 1.1, 0.35), (0.6, 0.6, 0.7), rng, "stone", 6, "stone")
	for k in range(5):
		a = math.pi * k / 4
		rock(b, (1.6 * math.cos(a), 1.6, 0.4 + 2.2 * math.sin(a)), (0.6, 0.5, 0.6), rng, "stone", 6, "stone")
	return b.to_object("Stairs", mat)

def chest(mat, lid):
	b = Builder(SHEET)
	if not lid:
		b.box((0, 0, 0.3), (1.2, 0.75, 0.6), "chest")
		for x in (-0.45, 0.45): b.box((x, 0, 0.3), (0.08, 0.78, 0.62), "gold")
		b.box((0, -0.39, 0.42), (0.18, 0.04, 0.2), "gold")
	else:
		# Lid: hinge line at the back top edge (origin), closed it covers the box.
		b.box((0, -0.375, 0.12), (1.22, 0.77, 0.24), "chest_dark")
		for x in (-0.45, 0.45): b.box((x, -0.375, 0.12), (0.08, 0.79, 0.26), "gold")
	return b.to_object("ChestLid" if lid else "ChestBase", mat)

def jar(mat, glow):
	b = Builder(SHEET)
	if glow:
		b.lathe((0, 0, 0), [(0.05, 0.06), (0.11, 0.14), (0.09, 0.26), (0.02, 0.3)], ["glow", "glow", "glow"], 7)
	else:
		b.lathe((0, 0, 0), [(0.12, 0.0), (0.15, 0.1), (0.15, 0.3), (0.09, 0.38), (0.09, 0.42)], ["glass", "glass", "glass", "glass"], 8)
		b.lathe((0, 0, 0), [(0.1, 0.4), (0.1, 0.48), (0.02, 0.49)], ["cork", "cork"], 8)
	return b.to_object("JarGlow" if glow else "Jar", mat)

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "dungeon", FLOOR)
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(512, SWATCHES, 16, 72)
png = os.path.join(out_dir, FLOOR + "_print.png")
SHEET.render(png)
mat = material("Kit", png)
pieces = {
	"floor": floor_tile(mat), "ceiling": ceiling(mat), "wall": wall(mat, "plain"), "wall_moss": wall(mat, "moss"),
	"wall_torch": wall(mat, "torch"), "corner": corner(mat), "stream": stream(mat), "bridge": bridge(mat),
	"mushroom_stem": mushroom_stem(mat), "mushroom_cap": mushroom_cap(mat), "boulder": boulder(mat),
	"stalagmite": stalagmite(mat), "entry_stone": entry_stone(mat), "stairs": stairs(mat),
	"rubble": rubble(mat), "ore_rock": ore_rock(mat), "chest_base": chest(mat, False), "chest_lid": chest(mat, True), "jar": jar(mat, False), "jar_glow": jar(mat, True),
}
for name, ob in pieces.items(): export_glb(ob, os.path.join(out_dir, name + ".glb"))
# Preview: a corner of a room.
layout = {"floor": (0, 0), "wall": (0, 0), "wall_moss": (4, 0), "corner": (2, 2), "boulder": (3.5, -1.5), "stalagmite": (-1, -1),
	"mushroom_stem": (1, -1), "mushroom_cap": (1, -1), "chest_base": (-1.2, -3), "jar": (0.6, -2.6), "jar_glow": (0.6, -2.6),
	"entry_stone": (5, -4), "bridge": (-4.5, -3), "stream": (-4.5, -3), "stairs": (8.5, -3), "wall_torch": (8, 0), "ceiling": (40, 0)}
for name, ob in pieces.items():
	at = layout.get(name, (40, 40))
	ob.location = (at[0], at[1], 0)
pieces["chest_lid"].location = (-1.2, -2.625, 0.6)
if render: preview(render, (6, -13, 5.5), (2, 0, 1.4), lens=34)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, FLOOR + ".blend"))
print("SAVED", os.path.join(source, FLOOR + ".blend"))
