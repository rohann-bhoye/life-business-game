# Builds the Jugnu Gufa monsters of Gufa Darwaza (monster.gd moves and animates them):
#   jugnu_slime.glb  Body: a round jelly with big anime eyes, shine and blush
#   chamgadar.glb    Body (fur ball, pointed ears, glowing eyes, fangs), WingL, WingR
#   khumbi.glb       Stem (the face), Cap (spotted, on top), FootL, FootR
#   raja_jelly.glb   Body: the boss slime (angry brows), Crown: gold with gems
# Parts are separate objects whose origin is their pivot (wing shoulders, the cap's
# seat, hips, the crown's base), so the game can flap, bob and squash them. Bodies,
# wings and caps are painted light grey so the game tints them per level (green, blue,
# gold elite); faces, feet and the boss keep their own colours. One shared atlas.
# Front faces -Y here (+Z in Godot); feet at the origin (the bat's body centre).
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_monsters.py -- <project dir> [--render out.png]
# Writes assets/characters/monsters/*.glb, monsters_print.png and source/monsters.blend.
import bpy, os, sys, math
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, preview, project_args

SWATCHES = {
	"body": "F2F2F2", "body_shade": "BEBEBE", "body_top": "FFFFFF", "eye": "1B1B2F", "shine": "FFFFFF",
	"blush": "FF9AB0", "mouth": "5A2A3A", "fang": "FFFFFF", "eye_glow": "FFD84A", "stem": "E9E1CC",
	"stem_shade": "C9BFA6", "spot": "FFFFFF", "foot": "7A4E2D", "boss": "3FB8A0", "boss_shade": "2A8C78",
	"boss_top": "7FE0C8", "gold": "E8B84A", "gold_dark": "B8862A", "gem": "D6336C", "gem_blue": "3D7BD9",
}

def part(name, mat, pivot, build):
	b = Builder(SHEET)
	build(b)
	ob = b.to_object(name, mat)
	ob.location = pivot
	return ob

def face(b, y, z, spread, size, brows=False, fangs=False, glow=False):
	"""Anime eyes on the front (-y) at height z: dark ovals with a white shine."""
	for side in (-1, 1):
		x = side * spread
		b.box((x, y, z), (size * 0.62, 0.03, size), "eye_glow" if glow else "eye")
		if not glow: b.box((x - side * size * 0.12, y - 0.02, z + size * 0.22), (size * 0.22, 0.02, size * 0.28), "shine")
		if brows: b.box((x, y - 0.01, z + size * 0.75), (size * 0.9, 0.03, size * 0.16), "eye", rot_z=0)
	if fangs:
		for side in (-1, 1): b.box((side * size * 0.3, y - 0.01, z - size * 0.9), (size * 0.16, 0.02, size * 0.3), "fang")

def flat(b, coords, swatch):
	"""A flat polygon visible from both sides (the back face gets its own vertices)."""
	b.swatch_face([b.vert(c) for c in coords], swatch)
	b.swatch_face([b.vert(c) for c in reversed(coords)], swatch)

def slime_body(b, radius, height, swatches=("body_shade", "body", "body", "body", "body_top")):
	r, h = radius, height
	b.lathe((0, 0, 0), [(r * 0.9, 0.0), (r, h * 0.12), (r * 0.94, h * 0.46), (r * 0.68, h * 0.8), (r * 0.32, h * 0.95), (0.02, h)], list(swatches), 16)

def jugnu_slime(mat):
	def build(b):
		slime_body(b, 0.5, 0.66)
		face(b, -0.475, 0.33, 0.14, 0.17)
		for side in (-1, 1): b.box((side * 0.28, -0.42, 0.22), (0.1, 0.02, 0.05), "blush")
		b.box((0, -0.485, 0.21), (0.07, 0.02, 0.03), "mouth")
	return [part("Body", mat, (0, 0, 0), build)]

def chamgadar(mat):
	def body(b):
		b.lathe((0, 0, 0), [(0.15, -0.26), (0.27, -0.12), (0.28, 0.06), (0.2, 0.22), (0.02, 0.28)], ["body_shade", "body", "body", "body_top"], 12)
		for side in (-1, 1):
			flat(b, [(side * 0.08, 0, 0.2), (side * 0.24, 0, 0.18), (side * 0.2, 0, 0.48)], "body")
		face(b, -0.27, 0.05, 0.1, 0.11, glow=True, fangs=True)
		for side in (-1, 1): b.box((side * 0.08, 0, -0.29), (0.05, 0.05, 0.08), "foot")
	def wing(side):
		def build(b):
			points = [(0, 0.1), (0.35, 0.32), (0.78, 0.16), (0.95, -0.16), (0.62, -0.06), (0.42, -0.22), (0.2, -0.08), (0, -0.1)]
			for k in range(1, len(points) - 1):
				flat(b, [(side * points[0][0], 0, points[0][1]), (side * points[k][0], 0, points[k][1]), (side * points[k + 1][0], 0, points[k + 1][1])], "body_shade")
			for x, z in ((0.35, 0.32), (0.78, 0.16), (0.95, -0.16)):
				b.box((side * x / 2, -0.01, z / 2 + 0.05), (abs(x) * 1.0 + 0.02, 0.02, 0.025), "eye", rot_z=0)
		return build
	return [part("Body", mat, (0, 0, 0), body), part("WingL", mat, (-0.22, 0, 0.06), wing(-1)), part("WingR", mat, (0.22, 0, 0.06), wing(1))]

def khumbi(mat):
	def stem(b):
		b.lathe((0, 0, 0), [(0.18, 0.1), (0.22, 0.24), (0.2, 0.44), (0.15, 0.56)], ["stem_shade", "stem", "stem"], 12)
		face(b, -0.215, 0.34, 0.075, 0.09)
		b.box((0, -0.22, 0.22), (0.06, 0.02, 0.025), "mouth")
	def cap(b):
		b.lathe((0, 0, 0), [(0.12, -0.03), (0.46, 0.02), (0.44, 0.14), (0.31, 0.27), (0.13, 0.34), (0.02, 0.35)], ["body_shade", "body", "body", "body", "body_top"], 14)
		for k, (a, ring, z) in enumerate(((0.3, 0.36, 0.15), (1.6, 0.38, 0.12), (2.7, 0.33, 0.18), (3.9, 0.37, 0.13), (5.0, 0.34, 0.16), (0.9, 0.17, 0.3), (3.3, 0.18, 0.29))):
			b.box((ring * math.cos(a), ring * math.sin(a), z), (0.11, 0.11, 0.05), "spot", rot_z=math.degrees(a))
	def foot(b):
		b.box((0, -0.04, -0.06), (0.13, 0.2, 0.12), "foot")
	return [part("Stem", mat, (0, 0, 0), stem), part("Cap", mat, (0, 0, 0.55), cap), part("FootL", mat, (-0.11, 0, 0.12), foot), part("FootR", mat, (0.11, 0, 0.12), foot)]

def raja_jelly(mat):
	def body(b):
		slime_body(b, 1.15, 1.45, ("boss_shade", "boss", "boss", "boss", "boss_top"))
		face(b, -1.09, 0.72, 0.32, 0.36, brows=True)
		for side in (-1, 1): b.box((side * 0.64, -0.98, 0.5), (0.22, 0.03, 0.1), "blush")
		b.box((0, -1.12, 0.42), (0.32, 0.03, 0.07), "mouth")
	def crown(b):
		b.lathe((0, 0, 0), [(0.42, 0.0), (0.44, 0.16), (0.42, 0.2)], ["gold_dark", "gold"], 14)
		for k in range(5):
			a = 2 * math.pi * k / 5 - math.pi / 2
			b.lathe((0.4 * math.cos(a), 0.4 * math.sin(a), 0), [(0.1, 0.18), (0.02, 0.48)], ["gold"], 5)
			b.box((0.43 * math.cos(a), 0.43 * math.sin(a), 0.09), (0.09, 0.09, 0.09), "gem" if k % 2 == 0 else "gem_blue", rot_z=math.degrees(a))
	return [part("Body", mat, (0, 0, 0), body), part("Crown", mat, (0, 0, 1.38), crown)]

def export_parts(objects, path):
	for other in bpy.context.scene.objects: other.select_set(False)
	for ob in objects: ob.select_set(True)
	bpy.context.view_layer.objects.active = objects[0]
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_cameras=False,
		export_lights=False, export_animations=False, export_keep_originals=True)
	print("EXPORTED", path, sum(len(ob.data.polygons) for ob in objects), "faces")

project, render = project_args()
out_dir = os.path.join(project, "assets", "characters", "monsters")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(512, SWATCHES, 16, 72)
png = os.path.join(out_dir, "monsters_print.png")
SHEET.render(png)
mat = material("Monsters", png)
monsters = {"jugnu_slime": jugnu_slime(mat), "chamgadar": chamgadar(mat), "khumbi": khumbi(mat), "raja_jelly": raja_jelly(mat)}
for name, objects in monsters.items(): export_parts(objects, os.path.join(out_dir, name + ".glb"))
# Preview: the four side by side (the bat raised as if flying).
for name, dx, dz in (("jugnu_slime", -2.6, 0), ("chamgadar", -1.2, 1.0), ("khumbi", 0.0, 0), ("raja_jelly", 2.0, 0)):
	for ob in monsters[name]: ob.location = (ob.location[0] + dx, ob.location[1], ob.location[2] + dz)
if render: preview(render, (0.5, -6.5, 1.6), (0, 0, 0.7), lens=40)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "monsters.blend"))
print("SAVED", os.path.join(source, "monsters.blend"))
