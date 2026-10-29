# Builds the Darwaza Guild office (dungeon_world.gd places it at the foot of the west
# hill, on the way to the cave): an anime-style adventurers' guild with an Indian
# touch. A stone plinth with steps, sandstone lower walls, a timber-framed upper floor
# with white panels, a red tiled roof with a little flag turret, an open counter window
# with a wooden counter (the clerk stands behind it), a big DARWAZA GUILD board with the
# gate-ring emblem, blue and gold banners, two lanterns, a notice board (the game writes
# the gate times on it) and crates by the door.
# Front faces -Y here (+Z in Godot), origin at the middle of the plinth's front edge.
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_guild_office.py -- <project dir> [--render out.png]
# Writes assets/props/dungeon/guild_office.glb, guild_print.png, source/guild.blend.
import bpy, os, sys, math
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, export_glb, preview, project_args

W, D = 9.0, 7.0
PLINTH = 0.5
FLOOR2, EAVES = 3.6, 6.2
SWATCHES = {
	"plinth": "8E8578", "plinth_dark": "6C655B", "sandstone": "D9B98A", "sandstone_dark": "B8956A",
	"timber": "5E3A22", "plaster": "F2ECDD", "roof": "B6452F", "roof_dark": "8C3322", "counter": "8A5A32",
	"counter_top": "C99A62", "inside": "3A2A20", "banner_blue": "2F5DBF", "banner_gold": "E8B84A",
	"lantern": "FFD27A", "iron": "3A3D42", "cork": "B98A55", "paper": "F7F3E6", "crate": "A07448",
	"crate_dark": "6E4D2E", "flag": "C0392B", "glass": "2C3E50",
}
SIGN = (16, 16, 480, 150)

def draw_print(s):
	x, y, w, h = SIGN
	s.rect(x, y, w, h, "2F5DBF")
	s.rect(x + 8, y + 8, w - 16, h - 16, "E8B84A", 0.01)
	s.rect(x + 14, y + 14, w - 28, h - 28, "1E3F8A", 0.02)
	s.text("DARWAZA GUILD", x + w / 2 + 34, y + 70, 44, "FFFFFF", 0.03, "ariblk.ttf", w - 120)
	s.text("Treasure bought here", x + w / 2 + 34, y + 115, 22, "F2D27A", 0.03, "arialbd.ttf", w - 120)
	# The gate-ring emblem on the left of the board.
	cx, cy = x + 62, y + h / 2
	s.rect(cx - 40, cy - 40, 80, 80, "E8B84A", 0.03, r=40)
	s.rect(cx - 30, cy - 30, 60, 60, "1E3F8A", 0.04, r=30)
	s.rect(cx - 18, cy - 18, 36, 36, "6FD3FF", 0.05, r=18)

def build(mat):
	b = Builder(SHEET)
	half = W / 2
	b.box((0, D / 2, PLINTH / 2), (W + 0.6, D + 0.4, PLINTH), {"+z": "plinth", "rest": "plinth_dark"})
	for k in range(2): b.box((0, -0.25 - k * 0.3, PLINTH / 2 - (k + 1) * 0.17 + 0.09), (3.0, 0.3, PLINTH - (k + 1) * 0.17), "plinth")
	base = PLINTH
	# Ground floor: sandstone side and back walls, front with a wide counter window.
	for x in (-half + 0.15, half - 0.15): b.box((x, D / 2, base + FLOOR2 / 2), (0.3, D, FLOOR2), "sandstone")
	b.box((0, D - 0.15, base + FLOOR2 / 2), (W, 0.3, FLOOR2), "sandstone")
	for x in (-3.4, 3.4): b.box((x, 0.15, base + FLOOR2 / 2), (2.2, 0.3, FLOOR2), "sandstone")
	b.box((0, 0.15, base + 0.45), (4.6, 0.3, 0.9), "sandstone_dark")
	b.box((0, 0.15, base + FLOOR2 - 0.35), (4.6, 0.3, 0.7), "sandstone")
	b.box((0, 0.6, base + 0.95), (4.4, 0.7, 0.12), "counter_top")
	b.box((0, 3.2, base + FLOOR2 / 2), (W - 0.6, 0.1, FLOOR2), "inside")
	b.box((0, 2.0, base + 0.02), (W - 0.6, 3.6, 0.04), "counter")
	# Upper floor: timber frame with white panels and two small windows.
	top = base + FLOOR2
	b.box((0, D / 2, top + 0.1), (W + 0.3, D + 0.3, 0.2), "timber")
	for x in (-half + 0.15, half - 0.15): b.box((x, D / 2, top + (EAVES - FLOOR2) / 2), (0.3, D, EAVES - FLOOR2), "plaster")
	b.box((0, 0.15, top + (EAVES - FLOOR2) / 2), (W, 0.3, EAVES - FLOOR2), "plaster")
	b.box((0, D - 0.15, top + (EAVES - FLOOR2) / 2), (W, 0.3, EAVES - FLOOR2), "plaster")
	for x in (-half + 0.1, -1.5, 1.5, half - 0.1): b.box((x, -0.02, top + (EAVES - FLOOR2) / 2), (0.22, 0.08, EAVES - FLOOR2), "timber")
	for z in (top + 0.25, base + EAVES - 0.15): b.box((0, -0.02, z), (W, 0.08, 0.2), "timber")
	for x in (-3.0, 3.0):
		b.box((x, -0.03, top + 1.35), (1.1, 0.06, 1.0), "timber")
		b.box((x, -0.06, top + 1.35), (0.9, 0.04, 0.8), "glass")
	# Roof: two red tiled slopes over the long side, gables, a ridge and a flag turret.
	ridge = base + EAVES + 2.1
	for side in (-1, 1):
		y0, y1 = (-0.6, D / 2) if side < 0 else (D + 0.6, D / 2)
		quad = [b.vert((-half - 0.5, y0, base + EAVES - 0.3)), b.vert((half + 0.5, y0, base + EAVES - 0.3)), b.vert((half + 0.5, y1, ridge)), b.vert((-half - 0.5, y1, ridge))]
		if side > 0: quad.reverse()
		b.swatch_face(quad, "roof")
		for k in range(1, 5):
			t = k / 5
			b.box((0, y0 + (y1 - y0) * t, base + EAVES - 0.3 + (ridge - base - EAVES + 0.3) * t + 0.03), (W + 1.0, 0.08, 0.06), "roof_dark")
	for x in (-half, half):
		tri = [b.vert((x, 0, base + EAVES)), b.vert((x, D, base + EAVES)), b.vert((x, D / 2, ridge - 0.1))]
		b.swatch_face(tri if x > 0 else list(reversed(tri)), "plaster")
	b.box((0, D / 2, ridge + 0.05), (W + 1.0, 0.25, 0.2), "roof_dark")
	b.box((half - 1.2, D / 2, ridge + 0.6), (0.8, 0.8, 1.2), "plaster")
	b.lathe((half - 1.2, D / 2, 0), [(0.6, ridge + 1.2), (0.02, ridge + 1.9)], ["roof"], 4)
	b.box((half - 1.2, D / 2, ridge + 2.5), (0.05, 0.05, 1.2), "iron")
	b.box((half - 0.85, D / 2, ridge + 2.85), (0.65, 0.03, 0.4), "flag")
	# The guild board over the counter window, banners and lanterns.
	x, y, w, h = SIGN
	idx = [b.vert((-2.4, -0.42, top - 0.05)), b.vert((2.4, -0.42, top - 0.05)), b.vert((2.4, -0.42, top + 1.45)), b.vert((-2.4, -0.42, top + 1.45))]
	b.region_face(idx, SIGN)
	b.box((0, -0.3, top + 0.7), (5.0, 0.2, 1.7), "timber")
	for side in (-1, 1):
		bx = side * 3.4
		b.box((bx, -0.2, top - 0.1), (1.1, 0.06, 1.6), "banner_blue")
		b.box((bx, -0.24, top - 0.1), (0.22, 0.04, 1.6), "banner_gold")
		b.box((bx, -0.22, top + 0.72), (1.3, 0.1, 0.1), "timber")
		b.box((side * 2.6, -0.45, base + 2.7), (0.06, 0.5, 0.06), "iron")
		b.lathe((side * 2.6, -0.7, 0), [(0.14, base + 2.15), (0.2, base + 2.35), (0.2, base + 2.6), (0.08, base + 2.7)], ["lantern", "lantern", "iron"], 6)
	# Notice board on posts to the left of the steps, crates to the right.
	nx = -4.0
	for px in (nx - 0.8, nx + 0.8): b.box((px, -1.6, 0.9), (0.12, 0.12, 1.8), "timber")
	b.box((nx, -1.55, 1.45), (1.9, 0.08, 1.1), "cork")
	for k, (px, pz) in enumerate(((-0.5, 0.2), (0.4, 0.25), (-0.1, -0.25), (0.6, -0.2))):
		b.box((nx + px, -1.6, 1.45 + pz), (0.45, 0.02, 0.36), "paper")
	for k, (cx, cy, s) in enumerate(((3.4, -1.3, 0.7), (4.1, -1.0, 0.6), (3.7, -1.2, 0.5))):
		z = s / 2 + (0.7 if k == 2 else 0)
		b.box((cx, cy, z), (s, s, s), "crate")
		b.box((cx, cy - s / 2 - 0.005, z), (s * 0.9, 0.01, 0.1), "crate_dark")
	return b.to_object("GuildOffice", mat)

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "dungeon")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(512, SWATCHES, 190, 72)
draw_print(SHEET)
png = os.path.join(out_dir, "guild_print.png")
SHEET.render(png)
guild = build(material("Guild", png))
export_glb(guild, os.path.join(out_dir, "guild_office.glb"))
if render: preview(render, (9, -16, 5.5), (0, 2, 3.5), lens=36)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "guild.blend"))
print("SAVED", os.path.join(source, "guild.blend"))
