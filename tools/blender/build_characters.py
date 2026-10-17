# Builds our own characters on the Kenney Mini Characters rig (CC0): each one keeps the
# Kenney skeleton and all 32 animations, gets new outfit colours from our palette and
# new low-poly parts (apron, caps, turban, saree pallu, hi-vis vest...).
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_characters.py -- <project dir> [ids...] [--render out.png]
# Writes assets/characters/custom/character-<id>.glb (used by the game),
# assets/characters/custom/source/<id>.blend (editable) and source/all_characters.blend (lineup).
import bpy, bmesh, sys, os, math
from mathutils import Vector, Euler

# ---------- palette: 32 flat colours painted into the empty top half of the Kenney colormap
PALETTE = [
	("shirt_cream", "F1E7D0"), ("trousers_slate", "3A4252"), ("apron_green", "2F9A5C"), ("apron_dark", "21774A"),
	("shoe_brown", "6E4327"), ("sole_dark", "2A2421"), ("yellow", "F4C443"), ("red", "D8473F"),
	("hair_black", "1F1B19"), ("staff_green", "4DB677"), ("khaki", "C8AD80"), ("white", "F4F3EE"),
	("id_blue", "3D7BD9"), ("hivis", "FF7F1F"), ("reflect", "DDE4EA"), ("navy", "2E3F5C"),
	("cargo", "646B73"), ("saffron", "F0892A"), ("maroon", "8C2B3B"), ("kurta_white", "F2EEE3"),
	("grey_hair", "B8B8B4"), ("magenta", "C21E63"), ("gold", "E6B13A"), ("teal", "1E9E98"),
	("denim", "3F5D8C"), ("pack_orange", "E8642B"), ("straw", "DDBB6A"), ("mustard", "D7A12A"),
	("sharma_red", "C7352D"), ("saffron_dark", "C9661A"), ("pack_dark", "2F3542"), ("leaf", "7DAA4A"),
]
SLOT = {name: (i % 16, i // 16) for i, (name, _) in enumerate(PALETTE)}

# ---------- characters
# base: Kenney model. top/legs/shoe/sole/belt: zone colours; torso_top: the top on the torso
# only (a sleeveless jacket over the sleeves' colour). top_cells/head_cells: recolour specific
# Kenney palette cells. hand: colour for gloves. trim: hair cut height under a hat. acc: extra parts.
CHARACTERS = {
	"shopkeeper": dict(base="male-a", top="shirt_cream", legs="trousers_slate", shoe="shoe_brown", sole="sole_dark",
		belt="apron_green", remove_glasses=True, acc=[("apron",), ("moustache",)]),
	"staff": dict(base="male-d", top="staff_green", top_cells={(9, 3): "white", (9, 2): "staff_green"}, legs="khaki",
		shoe="sole_dark", sole="sole_dark", belt="sole_dark",
		acc=[("cap", "staff_green", "yellow"), ("lanyard", "yellow", "staff_green")]),
	"staff-f": dict(base="female-b", top="staff_green", legs="khaki", shoe="sole_dark", sole="white", belt="sole_dark",
		head_cells={(5, 2): "staff_green"}, trim=0.55, acc=[("cap", "staff_green", "yellow"), ("lanyard", "yellow", "staff_green")]),
	"warehouse": dict(base="male-f", top="navy", legs="cargo", shoe="shoe_brown", sole="sole_dark", belt="shoe_brown",
		acc=[("vest", "hivis", "reflect"), ("hard_hat", "yellow")]),
	"farmer": dict(base="female-c", top="mustard", legs="maroon", shoe="shoe_brown", sole="sole_dark", belt="maroon",
		head_cells={(3, 3): "hair_black"}, acc=[("straw_hat",), ("gamcha", "red", "white")]),
	"rival-m": dict(base="male-e", top="sharma_red", top_cells={(5, 2): "sole_dark"}, legs="navy", shoe="sole_dark",
		sole="sole_dark", belt="sole_dark", hand=(15, 3), acc=[("cap", "sharma_red", "white"), ("lanyard", "white", "sharma_red")]),
	"rival-f": dict(base="female-f", top="sharma_red", top_cells={(5, 2): "white"}, legs="navy", shoe="sole_dark",
		sole="sole_dark", belt="sole_dark", acc=[("cap", "sharma_red", "white"), ("lanyard", "white", "sharma_red")]),
	"uncle": dict(base="male-b", top="kurta_white", torso_top="saffron", legs="kurta_white", shoe="shoe_brown",
		sole="sole_dark", belt="kurta_white", head_cells={(11, 3): "grey_hair"},
		acc=[("kurta_hem", "kurta_white"), ("nehru", "gold", "maroon"), ("topi",)]),
	"sikh": dict(base="male-b", top="navy", legs="kurta_white", shoe="shoe_brown", sole="sole_dark", belt="navy",
		head_cells={(11, 3): "hair_black"},
		acc=[("kurta_hem", "navy"), ("placket", "navy", "gold"), ("turban", "saffron", "saffron_dark")]),
	"aunty": dict(base="female-d", top="gold", top_cells={(9, 3): "gold"}, legs="magenta", hem="gold", shoe="shoe_brown",
		sole="sole_dark", belt="magenta", head_cells={(11, 3): "hair_black"}, acc=[("pallu", "magenta", "gold"), ("bindi",)]),
	"student": dict(base="female-e", top="teal", legs="denim", shoe="white", sole="sole_dark", belt="pack_dark",
		hand=(15, 3), acc=[("backpack", "pack_orange", "pack_dark")]),
}

SHOE_TOP = 0.1
HEAD_FRONT = -0.157

# ---------- geometry helpers (Blender space: Z up, character faces -Y, its left hand is +X)
def box(x0, x1, y0, y1, z0, z1):
	v = [(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
	return (v, [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)])

def prism_y(outline, y0, y1):
	"""Extrude an x/z outline from y0 to y1."""
	n = len(outline)
	v = [(x, y0, z) for x, z in outline] + [(x, y1, z) for x, z in outline]
	f = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
	return (v, f)

def prism_z(outline, z0, z1, top=None, cy=0.0):
	"""Extrude an x/y outline from z0 to z1 (optionally tapering to a top outline)."""
	top = top or outline
	n = len(outline)
	v = [(x, y + cy, z0) for x, y in outline] + [(x, y + cy, z1) for x, y in top]
	f = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
	return (v, f)

def chamfer(hx, hy, c):
	"""Octagon: a hx*hy rectangle with corners cut by c."""
	return [(hx, -hy + c), (hx, hy - c), (hx - c, hy), (-hx + c, hy), (-hx, hy - c), (-hx, -hy + c), (-hx + c, -hy), (hx - c, -hy)]

def slab(points, y0, y1):
	return prism_y(points, y0, y1)

# ---------- accessories: each returns [(mesh, bone, colour, [polys])]
def acc_apron(A):
	tf, bf = A["tf"], A["bf"]
	return [
		("body", "torso", "apron_green", [box(-0.085, 0.085, tf - 0.013, tf + 0.002, 0.205, 0.318),
			box(-0.132, 0.132, bf - 0.013, bf + 0.001, 0.135, 0.205)]),
		("body", "torso", "apron_dark", [box(-0.085, -0.068, tf - 0.016, tf + 0.001, 0.30, 0.343),
			box(0.068, 0.085, tf - 0.016, tf + 0.001, 0.30, 0.343), box(-0.062, 0.062, bf - 0.02, bf - 0.011, 0.146, 0.186)]),
		("body", "torso", "red", [box(0.028, 0.040, bf - 0.019, bf - 0.009, 0.168, 0.200)]),
		("body", "torso", "yellow", [box(0.030, 0.068, tf - 0.019, tf - 0.011, 0.255, 0.290)]),
	]

def acc_moustache(A, colour="hair_black"):
	m = [(-0.072, 0.414), (-0.058, 0.438), (-0.030, 0.452), (0.0, 0.446), (0.030, 0.452), (0.058, 0.438),
		(0.072, 0.414), (0.050, 0.424), (0.022, 0.430), (0.0, 0.426), (-0.022, 0.430), (-0.050, 0.424)]
	return [("head", "head", colour, [prism_y(m, HEAD_FRONT - 0.019, HEAD_FRONT)])]

def acc_cap(A, colour, logo):
	A["trim"] = 0.64
	return [
		("head", "head", colour, [prism_z(chamfer(0.185, 0.185, 0.035), 0.612, 0.69),
			prism_z(chamfer(0.185, 0.185, 0.035), 0.69, 0.735, top=chamfer(0.15, 0.15, 0.04)),
			box(-0.15, 0.15, -0.295, -0.18, 0.612, 0.630)]),
		("head", "head", logo, [box(-0.034, 0.034, -0.193, -0.183, 0.638, 0.676), box(-0.02, 0.02, -0.02, 0.02, 0.735, 0.745)]),
	]

def acc_hard_hat(A, colour):
	A["trim"] = 0.64
	return [("head", "head", colour, [
		prism_z(chamfer(0.205, 0.205, 0.05), 0.612, 0.69, top=chamfer(0.19, 0.19, 0.055)),
		prism_z(chamfer(0.19, 0.19, 0.055), 0.69, 0.74, top=chamfer(0.12, 0.12, 0.04)),
		prism_z(chamfer(0.235, 0.235, 0.07), 0.606, 0.622),
		box(-0.13, 0.13, -0.31, -0.2, 0.606, 0.622),
		box(-0.022, 0.022, -0.2, 0.2, 0.68, 0.752)])]

def acc_straw_hat(A, colour="straw", band="red"):
	A["trim"] = 0.64
	return [
		("head", "head", colour, [prism_z(chamfer(0.33, 0.33, 0.12), 0.622, 0.638),
			prism_z(chamfer(0.2, 0.2, 0.055), 0.638, 0.735, top=chamfer(0.165, 0.165, 0.05))]),
		("head", "head", band, [prism_z(chamfer(0.206, 0.206, 0.057), 0.638, 0.664)]),
	]

def acc_turban(A, colour, accent):
	A["trim"] = 0.6
	return [
		("head", "head", colour, [prism_z(chamfer(0.192, 0.192, 0.05), 0.56, 0.64, top=chamfer(0.2, 0.2, 0.055)),
			prism_z(chamfer(0.2, 0.2, 0.055), 0.64, 0.71, top=chamfer(0.18, 0.185, 0.06)),
			prism_z(chamfer(0.18, 0.185, 0.06), 0.71, 0.752, top=chamfer(0.12, 0.13, 0.05))]),
		("head", "head", accent, [prism_z([(0.075, -0.185), (0.0, -0.222), (-0.075, -0.185), (0.0, -0.15)], 0.575, 0.735,
			top=[(0.045, -0.165), (0.0, -0.19), (-0.045, -0.165), (0.0, -0.14)])]),
	]

def acc_topi(A, colour="white"):
	A["trim"] = 0.66
	out = [(-0.155, 0.618), (0.155, 0.618), (0.13, 0.69), (0.036, 0.738), (-0.036, 0.738), (-0.13, 0.69)]
	return [("head", "head", colour, [prism_y(out, -0.205, 0.205)])]

def acc_bindi(A, colour="red"):
	if A["fringe"] < 0.536: return []
	return [("head", "head", colour, [box(-0.009, 0.009, HEAD_FRONT - 0.007, HEAD_FRONT + 0.002, 0.516, 0.532)])]

def _vest_panels(A, gap):
	tf, tb = A["tf"], A["tb"]
	return [box(-0.137, -gap, tf - 0.016, tf + 0.002, 0.19, 0.345), box(gap, 0.137, tf - 0.016, tf + 0.002, 0.19, 0.345),
		box(-0.137, 0.137, tb - 0.002, tb + 0.016, 0.19, 0.345),
		box(-0.143, -0.124, tf, tb, 0.19, 0.222), box(0.124, 0.143, tf, tb, 0.19, 0.222)]

def acc_vest(A, colour, strip):
	tf, tb = A["tf"], A["tb"]
	strips = []
	for z in (0.232, 0.284):
		strips += [box(-0.137, -0.012, tf - 0.02, tf - 0.014, z, z + 0.017), box(0.012, 0.137, tf - 0.02, tf - 0.014, z, z + 0.017),
			box(-0.137, 0.137, tb + 0.014, tb + 0.02, z, z + 0.017)]
	return [("body", "torso", colour, _vest_panels(A, 0.012)), ("body", "torso", strip, strips)]

def acc_nehru(A, buttons, pocket):
	"""Buttons and pocket square; the jacket itself is the torso_top colour."""
	tf = A["tf"]
	return [("body", "torso", buttons, [box(-0.018, -0.008, tf - 0.021, tf - 0.015, z, z + 0.01) for z in (0.22, 0.257, 0.294)]),
		("body", "torso", pocket, [box(0.07, 0.112, tf - 0.021, tf - 0.015, 0.29, 0.303)])]

def acc_kurta_hem(A, colour):
	f = min(A["tf"], A["bf"]) - 0.004
	b = max(A["tb"], A["bb"]) + 0.004
	return [("body", "torso", colour, [box(-0.15, 0.15, f - 0.014, f, 0.125, 0.212), box(-0.15, 0.15, b, b + 0.014, 0.125, 0.212),
		box(-0.152, -0.138, f, b, 0.125, 0.212), box(0.138, 0.152, f, b, 0.125, 0.212)])]

def acc_placket(A, colour, buttons):
	tf = A["tf"]
	return [("body", "torso", colour, [box(-0.016, 0.016, tf - 0.007, tf + 0.001, 0.24, 0.343)]),
		("body", "torso", buttons, [box(-0.006, 0.006, tf - 0.011, tf - 0.006, z, z + 0.011) for z in (0.26, 0.288, 0.316)])]

def acc_lanyard(A, strap, stripe):
	tf = A["tf"]
	y0, y1 = tf - 0.007, tf + 0.001
	return [("body", "torso", strap, [slab([(-0.072, 0.343), (-0.056, 0.343), (-0.006, 0.262), (-0.02, 0.262)], y0, y1),
			slab([(0.056, 0.343), (0.072, 0.343), (0.02, 0.262), (0.006, 0.262)], y0, y1)]),
		("body", "torso", "white", [box(-0.032, 0.032, tf - 0.012, tf - 0.005, 0.196, 0.262)]),
		("body", "torso", stripe, [box(-0.032, 0.032, tf - 0.0135, tf - 0.011, 0.243, 0.262),
			box(-0.02, 0.02, tf - 0.0135, tf - 0.011, 0.212, 0.222)])]

def acc_pallu(A, colour, border):
	tf, tb = A["tf"], A["tb"]
	front = [(-0.14, 0.345), (-0.14, 0.27), (0.14, 0.165), (0.14, 0.235), (-0.055, 0.345)]
	return [("body", "torso", colour, [slab(front, tf - 0.014, tf + 0.002), box(-0.14, -0.03, tb - 0.002, tb + 0.014, 0.2, 0.345),
			box(-0.152, -0.126, tf, tb, 0.27, 0.345)]),
		("body", "torso", border, [slab([(-0.14, 0.27), (-0.14, 0.287), (0.14, 0.182), (0.14, 0.165)], tf - 0.018, tf - 0.012),
			box(-0.14, -0.03, tb + 0.012, tb + 0.018, 0.2, 0.217)])]

def acc_gamcha(A, colour, stripe):
	tf, tb = A["tf"], A["tb"]
	cy = (tf + tb) / 2
	hy = (tb - tf) / 2 + 0.014
	return [("body", "torso", colour, [prism_z(chamfer(0.15, hy, 0.03), 0.322, 0.352, cy=cy),
			box(0.045, 0.1, tf - 0.024, tf - 0.012, 0.215, 0.33)]),
		("body", "torso", stripe, [box(0.045, 0.1, tf - 0.027, tf - 0.022, z, z + 0.011) for z in (0.245, 0.282)])]

def acc_backpack(A, colour, dark):
	tf, tb = A["tf"], A["tb"]
	return [("body", "torso", colour, [box(-0.105, 0.105, tb - 0.004, tb + 0.085, 0.19, 0.335),
			box(-0.07, 0.07, tb + 0.083, tb + 0.1, 0.205, 0.27)]),
		("body", "torso", dark, [box(-0.109, 0.109, tb - 0.004, tb + 0.089, 0.298, 0.34),
			box(-0.085, -0.06, tf - 0.008, tf + 0.001, 0.215, 0.343), box(0.06, 0.085, tf - 0.008, tf + 0.001, 0.215, 0.343)])]

ACCESSORIES = {k[4:]: v for k, v in globals().items() if k.startswith("acc_")}

# ---------- mesh helpers
def cell_of(me, p):
	uvl = me.uv_layers.active.data
	c = sum((uvl[li].uv for li in p.loop_indices), Vector((0, 0))) / p.loop_total
	return (min(int(c.x * 16), 15), min(int((1 - c.y) * 4), 3))

def target_slot(colour):
	return SLOT[colour] if isinstance(colour, str) else colour  # name in our palette, or a Kenney (col, row) cell

def move_face(me, p, src, colour):
	"""Move a face's UVs from its Kenney cell into another cell, keeping its place in the gradient."""
	uvl = me.uv_layers.active.data
	tc, tr = target_slot(colour)
	e = 0.002
	for li in p.loop_indices:
		u, v = uvl[li].uv
		u = min(max(u + (tc - src[0]) / 16, tc / 16 + e), (tc + 1) / 16 - e)
		v = v + 0.25 * (src[1] - tr)
		v = min(max(v, 1 - 0.25 * (tr + 1) + e), 1 - 0.25 * tr - e)
		uvl[li].uv = (u, v)

def dominant_group(obj, me, p):
	names = {g.index: g.name for g in obj.vertex_groups}
	w = {}
	for i in p.vertices:
		for g in me.vertices[i].groups: w[names[g.group]] = w.get(names[g.group], 0) + g.weight
	return max(w, key=w.get) if w else "root"

def zone_of(obj, me, p, skin):
	g = dominant_group(obj, me, p)
	zs = [me.vertices[i].co.z for i in p.vertices]
	xs = [abs(me.vertices[i].co.x) for i in p.vertices]
	c = cell_of(me, p)
	if max(zs) <= 0.03: return "sole"
	if g.startswith("leg") or (g == "root" and max(zs) < 0.18):
		if max(zs) <= SHOE_TOP: return "shoe"
		if max(zs) <= 0.125: return "hem"
		return "legs"
	if c in skin: return "skin"
	if g.startswith("arm") and min(xs) >= 0.32: return "hand"
	if g == "torso" and min(zs) >= 0.165 and max(zs) <= 0.222: return "belt"
	return "top"

def add_part(target, bone, name, colour, polys, mat):
	me = bpy.data.meshes.new(name)
	obj = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(obj)
	bm = bmesh.new()
	for verts, faces in polys:
		bv = [bm.verts.new(v) for v in verts]
		for f in faces: bm.faces.new([bv[i] for i in f])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	uvl = bm.loops.layers.uv.new("UVMap")
	zs = [v.co.z for v in bm.verts]
	z0, z1 = min(zs), max(zs)
	col, row = target_slot(colour)
	for f in bm.faces:
		f.smooth = False
		for l in f.loops:
			t = 0.15 + 0.7 * (z1 - l.vert.co.z) / max(z1 - z0, 1e-4)  # lighter at the top, like Kenney's cells
			l[uvl].uv = ((col + 0.5) / 16, 1 - 0.25 * row - 0.25 * t)
	bm.to_mesh(me)
	bm.free()
	me.materials.append(mat)
	vg = obj.vertex_groups.new(name=bone)
	vg.add(range(len(me.vertices)), 1.0, "REPLACE")
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	target.select_set(True)
	bpy.context.view_layer.objects.active = target
	bpy.ops.object.join()

def delete_faces(obj, pred):
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	uv = bm.loops.layers.uv.active
	def cell(f):
		c = sum((l[uv].uv for l in f.loops), Vector((0, 0))) / len(f.loops)
		return (min(int(c.x * 16), 15), min(int((1 - c.y) * 4), 3))
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if pred(f, cell(f))], context="FACES")
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	bm.to_mesh(obj.data)
	bm.free()

def make_palette(path):
	src = next(i for i in bpy.data.images if i.name.startswith("colormap"))
	n = src.size[0]
	px = list(src.pixels[:])
	cw = n // 16
	ch = n // 4
	for name, hx in PALETTE:
		col, row = SLOT[name]
		rgb = [int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4)]
		for py in range(ch):
			f = 1.08 - 0.22 * py / (ch - 1)
			y = n - 1 - (row * ch + py)
			for x in range(col * cw, col * cw + cw):
				i = (y * n + x) * 4
				px[i:i + 4] = [min(1, c * f) for c in rgb] + [1.0]
	img = bpy.data.images.new("characters_colormap", n, n, alpha=True)
	img.pixels.foreach_set(px)
	img.filepath_raw = path
	img.file_format = "PNG"
	img.save()
	return img

def frame_view(location, distance, yaw):
	for screen in bpy.data.screens:
		for area in screen.areas:
			if area.type != "VIEW_3D": continue
			for space in area.spaces:
				if space.type != "VIEW_3D": continue
				space.shading.type = "SOLID"
				space.shading.color_type = "TEXTURE"
				r = space.region_3d
				r.view_perspective = "PERSP"
				r.view_location = location
				r.view_distance = distance
				r.view_rotation = Euler((math.radians(80), 0, math.radians(yaw))).to_quaternion()

# ---------- build one character
def build(char_id, spec, project):
	kenney = os.path.join(project, "assets", "characters", "kenney")
	custom = os.path.join(project, "assets", "characters", "custom")
	source = os.path.join(custom, "source")
	os.makedirs(os.path.join(source, "Textures"), exist_ok=True)
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=os.path.join(kenney, "character-%s.glb" % spec["base"]))
	for o in list(bpy.data.objects):
		if o.name.startswith("Icosphere"): bpy.data.objects.remove(o)
	arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
	arm.name = arm.data.name = "character-" + char_id
	body = bpy.data.objects["body-mesh"]
	head = bpy.data.objects["head-mesh"]
	img = make_palette(os.path.join(source, "Textures", "characters_colormap.png"))
	mat = body.data.materials[0]
	for node in mat.node_tree.nodes:
		if node.type == "TEX_IMAGE": node.image = img
	mat.name = "characters"

	# Skin is the head cell with the face/scalp's 124 faces; its gradient partner cell too (V-necks).
	counts = {}
	for p in head.data.polygons:
		c = cell_of(head.data, p)
		counts[c] = counts.get(c, 0) + 1
	sc = next(c for c, n in counts.items() if n == 124)
	skin = {sc, (sc[0] ^ 1, 3)}

	# Anchors measured from this base so parts sit on its surface.
	me = body.data
	A = {"tf": 1.0, "tb": -1.0, "bf": 1.0, "bb": -1.0, "fringe": 1.0, "trim": None}
	for p in me.polygons:
		if dominant_group(body, me, p) != "torso": continue
		for i in p.vertices:
			v = me.vertices[i].co
			if 0.24 < v.z < 0.34: A["tf"] = min(A["tf"], v.y); A["tb"] = max(A["tb"], v.y)
			if 0.176 <= v.z <= 0.215: A["bf"] = min(A["bf"], v.y); A["bb"] = max(A["bb"], v.y)
	if A["bf"] > A["bb"]: A["bf"], A["bb"] = A["tf"], A["tb"]
	for p in head.data.polygons:
		if cell_of(head.data, p) in skin: continue
		c = p.center
		if c.y < -0.162 and abs(c.x) < 0.03 and c.z > 0.5:
			A["fringe"] = min(A["fringe"], min(head.data.vertices[i].co.z for i in p.vertices))

	# Recolour the body by zone.
	for p in me.polygons:
		src = cell_of(me, p)
		zone = zone_of(body, me, p, skin)
		colour = None
		if zone == "top":
			colour = spec["top"]
			if "torso_top" in spec and dominant_group(body, me, p) == "torso": colour = spec["torso_top"]
			colour = spec.get("top_cells", {}).get(src, colour)
		elif zone == "hem": colour = spec.get("hem", spec["legs"])
		elif zone == "hand": colour = spec.get("hand")
		elif zone != "skin": colour = spec.get(zone)
		if colour is not None: move_face(me, p, src, colour)
	for p in head.data.polygons:
		src = cell_of(head.data, p)
		if src in spec.get("head_cells", {}): move_face(head.data, p, src, spec["head_cells"][src])

	if spec.get("remove_glasses"):
		delete_faces(head, lambda f, c: c in {(7, 3), (9, 3)})

	parts = []
	for entry in spec.get("acc", []):
		parts += ACCESSORIES[entry[0]](A, *entry[1:])
	if A["trim"] is not None:  # hair that would poke through a hat
		t = spec.get("trim", A["trim"])
		delete_faces(head, lambda f, c: c not in skin and f.calc_center_median().z > t
			and abs(f.calc_center_median().x) <= 0.27 and abs(f.calc_center_median().y) <= 0.32)
	for k, (target, bone, colour, polys) in enumerate(parts):
		add_part(body if target == "body" else head, bone, "%s_part%d" % (char_id, k), colour, polys, mat)

	out_glb = os.path.join(custom, "character-%s.glb" % char_id)
	bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", export_animations=True,
		export_animation_mode="ACTIONS", export_cameras=False, export_lights=False)

	ad = arm.animation_data
	for t in ad.nla_tracks: t.mute = True
	ad.action = bpy.data.actions["walk"]
	scene = bpy.context.scene
	scene.frame_start, scene.frame_end = 0, 16
	scene.frame_set(0)
	frame_view((0, 0, 0.36), 1.5, -28)
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "%s.blend" % char_id), relative_remap=True)
	print("BUILT", char_id, "anchors", {k: round(v, 3) if isinstance(v, float) else v for k, v in A.items()})

# ---------- lineup of every character, for viewing (and an optional preview render)
def lineup(project, ids, render_path=None, action="idle", frame=0):
	custom = os.path.join(project, "assets", "characters", "custom")
	bpy.ops.wm.read_factory_settings(use_empty=True)
	spacing = 0.62
	for i, char_id in enumerate(ids):
		before = set(bpy.data.actions)
		bpy.ops.import_scene.gltf(filepath=os.path.join(custom, "character-%s.glb" % char_id))
		acts = {a.name.split(".")[0]: a for a in set(bpy.data.actions) - before}
		arm = next(o for o in bpy.context.selected_objects if o.type == "ARMATURE") if bpy.context.selected_objects else \
			[o for o in bpy.data.objects if o.type == "ARMATURE"][-1]
		arm.location.x = (i - (len(ids) - 1) / 2) * spacing
		ad = arm.animation_data_create()
		for t in ad.nla_tracks: t.mute = True
		ad.action = acts[action]
		label = bpy.data.objects.new("label-" + char_id, bpy.data.curves.new("label-" + char_id, "FONT"))
		label.data.body = char_id
		label.data.align_x = "CENTER"
		label.data.size = 0.07
		label.location = (arm.location.x, -0.25, 0.0)
		label.rotation_euler = (math.radians(90), 0, 0)
		bpy.context.scene.collection.objects.link(label)
	scene = bpy.context.scene
	scene.frame_start, scene.frame_end = 0, 32
	scene.frame_set(frame)
	frame_view((0, 0, 0.3), spacing * len(ids) * 0.95, 0)
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(custom, "source", "all_characters.blend"))
	if render_path:
		scene.render.engine = "BLENDER_WORKBENCH"
		scene.view_settings.view_transform = "Standard"
		sh = scene.display.shading
		sh.light = "STUDIO"
		sh.color_type = "TEXTURE"
		sh.background_type = "VIEWPORT"
		sh.background_color = (0.86, 0.9, 0.93)
		scene.render.resolution_x = 260 * len(ids)
		scene.render.resolution_y = 420
		cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
		scene.collection.objects.link(cam)
		cam.data.type = "ORTHO"
		cam.data.ortho_scale = spacing * len(ids)
		cam.location = (0, -3, 0.33)
		cam.rotation_euler = (math.radians(90), 0, 0)
		scene.camera = cam
		scene.render.filepath = render_path
		bpy.ops.render.render(write_still=True)
		print("RENDERED", render_path)

args = sys.argv[sys.argv.index("--") + 1:]
render = None
if "--render" in args:
	k = args.index("--render")
	render = args[k + 1]
	del args[k:k + 2]
project, ids = args[0], args[1:] or list(CHARACTERS)
for char_id in ids:
	build(char_id, CHARACTERS[char_id], project)
lineup(project, list(CHARACTERS), render)
