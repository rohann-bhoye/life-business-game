# Shared helpers for our Blender prop scripts (build_carry_bag.py, build_shop_fixtures.py):
# a print sheet (flat shapes and text rendered to one texture atlas, plus plain colour
# swatches) and a mesh builder whose faces take their UVs from that atlas.
import bpy, bmesh, os, sys, math, random
from mathutils import Vector

FONTS = "C:/Windows/Fonts/"

def lin(hex_colour):
	c = [int(hex_colour[k:k + 2], 16) / 255 for k in (0, 2, 4)]
	return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c) + (1.0,)

def clear_scene():
	for ob in list(bpy.data.objects): bpy.data.objects.remove(ob)
	for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
		for item in list(block): block.remove(item)

# ---------- print sheet
class Sheet:
	"""A square atlas drawn in pixels from the top-left: printed regions (x, y, w, h) and a
	grid of plain swatches from `swatch_y`, `cell` px apart. render() writes the PNG."""
	def __init__(self, size, swatches, swatch_y, cell=96):
		self.size, self.swatches, self.swatch_y, self.cell = size, swatches, swatch_y, cell
		self.coll = bpy.data.collections.new("PrintSheet")
		bpy.context.scene.collection.children.link(self.coll)
		self.mats, self.fonts = {}, {}

	def swatch_rect(self, name):
		i = list(self.swatches).index(name)
		per_row = (self.size - 16) // self.cell
		w = self.cell - self.cell // 6
		return (16 + (i % per_row) * self.cell, self.swatch_y + (i // per_row) * self.cell, w, w)

	def uv(self, x, y):
		return (x / self.size, 1.0 - y / self.size)

	def font(self, name):
		if name not in self.fonts:
			path = FONTS + name
			self.fonts[name] = bpy.data.fonts.load(path) if os.path.exists(path) else bpy.data.fonts.load("<builtin>")
		return self.fonts[name]

	def _mat(self, hex_colour):
		if hex_colour not in self.mats:
			m = bpy.data.materials.new("Print_" + hex_colour)
			m.diffuse_color = lin(hex_colour)
			self.mats[hex_colour] = m
		return self.mats[hex_colour]

	def _shape(self, polys, colour, z):
		verts, faces = [], []
		for pts in polys:
			faces.append(list(range(len(verts), len(verts) + len(pts)))[::-1])
			verts += [(px / self.size, -py / self.size, z) for px, py in pts]
		mesh = bpy.data.meshes.new("Shape")
		mesh.from_pydata(verts, [], faces)
		mesh.materials.append(self._mat(colour))
		ob = bpy.data.objects.new("Shape", mesh)
		self.coll.objects.link(ob)
		return ob

	@staticmethod
	def _rect_pts(x, y, w, h, r=0.0, seg=6):
		if r <= 0: return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
		pts = []
		for cx, cy, a0 in ((x + w - r, y + r, -90), (x + w - r, y + h - r, 0), (x + r, y + h - r, 90), (x + r, y + r, 180)):
			for k in range(seg + 1):
				a = math.radians(a0 + 90 * k / seg)
				pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
		return pts

	def rect(self, x, y, w, h, colour, z=0.0, r=0.0, seg=6):
		return self._shape([self._rect_pts(x, y, w, h, r, seg)], colour, z)

	def rects(self, boxes, colour, z=0.0):
		"""Many plain rectangles (x, y, w, h) as one shape: speckles, slots, QR modules."""
		return self._shape([self._rect_pts(*box) for box in boxes], colour, z) if boxes else None

	def polygon(self, pts, colour, z=0.0):
		return self._shape([pts], colour, z)

	def speckle(self, region, count, colours, sizes, z, seed, bleed=6):
		rng = random.Random(seed)
		x, y, w, h = region
		for colour in colours:
			boxes = []
			for _ in range(count // len(colours)):
				sw, sh = rng.uniform(*sizes[0]), rng.uniform(*sizes[1])
				boxes.append((rng.uniform(x - bleed, x + w + bleed - sw), rng.uniform(y - bleed, y + h + bleed - sh), sw, sh))
			self.rects(boxes, colour, z)

	def text(self, body, cx, cy, cap_px, colour, z, font, max_w=None):
		cu = bpy.data.curves.new("Text", "FONT")
		cu.body = body
		cu.font = self.font(font)
		cu.align_x = "CENTER"
		cu.align_y = "CENTER"
		cu.size = cap_px / 0.72 / self.size
		cu.materials.append(self._mat(colour))
		ob = bpy.data.objects.new("Text_" + body[:12], cu)
		self.coll.objects.link(ob)
		ob.location = (cx / self.size, -cy / self.size, z)
		if max_w:
			bpy.context.view_layer.update()
			if ob.dimensions.x > max_w / self.size:
				s = max_w / self.size / ob.dimensions.x
				ob.scale = (s, s, 1)
		return ob

	def render(self, path, background="101010"):
		bleed = (self.cell - self.swatch_rect(next(iter(self.swatches)))[2]) // 2 - 2
		for name, colour in self.swatches.items():
			x, y, w, h = self.swatch_rect(name)
			self.rect(x - bleed, y - bleed, w + 2 * bleed, h + 2 * bleed, colour, 0.0)
		cam_data = bpy.data.cameras.new("PrintCamera")
		cam_data.type = "ORTHO"
		cam_data.ortho_scale = 1.0
		cam = bpy.data.objects.new("PrintCamera", cam_data)
		self.coll.objects.link(cam)
		cam.location = (0.5, -0.5, 5.0)
		scene = bpy.context.scene
		scene.camera = cam
		scene.render.engine = "BLENDER_WORKBENCH"
		scene.display.shading.light = "FLAT"
		scene.display.shading.color_type = "MATERIAL"
		scene.view_settings.view_transform = "Standard"
		scene.world = scene.world or bpy.data.worlds.new("World")
		scene.world.color = lin(background)[:3]
		scene.render.resolution_x = scene.render.resolution_y = self.size
		scene.render.resolution_percentage = 100
		scene.render.image_settings.file_format = "PNG"
		scene.render.image_settings.color_mode = "RGB"
		scene.render.filepath = path
		bpy.ops.render.render(write_still=True)
		bpy.context.view_layer.layer_collection.children[self.coll.name].exclude = True
		print("PRINT", path)

# ---------- mesh builder
# Box sides: corners (sx, sy, sz) seen from outside, bottom-left, bottom-right, top-right,
# top-left, so a printed region reads upright. On top, the print's up is +y.
BOX_SIDES = {
	"-y": ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)),
	"+y": ((1, 1, -1), (-1, 1, -1), (-1, 1, 1), (1, 1, 1)),
	"+x": ((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)),
	"-x": ((-1, 1, -1), (-1, -1, -1), (-1, -1, 1), (-1, 1, 1)),
	"+z": ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)),
	"-z": ((-1, 1, -1), (1, 1, -1), (1, -1, -1), (-1, -1, -1)),
}

class Builder:
	"""Vertices, faces and a UV per face corner, painted from a Sheet: a swatch name
	paints a face one colour, a region (x, y, w, h) prints it across the face."""
	def __init__(self, sheet):
		self.sheet = sheet
		self.verts, self.faces, self.uvs = [], [], []

	def vert(self, co):
		self.verts.append(Vector(co))
		return len(self.verts) - 1

	def face(self, idx, uvs):
		self.faces.append(tuple(idx))
		self.uvs.append(list(uvs))

	def swatch_face(self, idx, name):
		x, y, w, h = self.sheet.swatch_rect(name)
		corners = [(x + w / 4, y + h / 4), (x + w * 3 / 4, y + h / 4), (x + w * 3 / 4, y + h * 3 / 4), (x + w / 4, y + h * 3 / 4)]
		self.face(idx, [self.sheet.uv(*corners[k % 4]) for k in range(len(idx))])

	def region_face(self, idx, region):
		x, y, w, h = region
		self.face(idx, [self.sheet.uv(*p) for p in ((x, y + h), (x + w, y + h), (x + w, y), (x, y))])

	def paint(self, idx, paint):
		if isinstance(paint, str): self.swatch_face(idx, paint)
		else: self.region_face(idx, paint)

	def quad_strip(self, ring_a, ring_b, name, closed=True):
		n = len(ring_a)
		for i in range(n if closed else n - 1):
			j = (i + 1) % n
			self.swatch_face((ring_a[i], ring_a[j], ring_b[j], ring_b[i]), name)

	def box(self, centre, size, paint, rot_z=0.0):
		"""`paint` for every side, or a dict by side ("+x" ... "-z", "rest"); None skips a side."""
		spec = paint if isinstance(paint, dict) else {"rest": paint}
		c, s = math.cos(math.radians(rot_z)), math.sin(math.radians(rot_z))
		for side, corners in BOX_SIDES.items():
			side_paint = spec.get(side, spec.get("rest"))
			if side_paint is None: continue
			idx = []
			for sx, sy, sz in corners:
				x, y = sx * size[0] / 2, sy * size[1] / 2
				idx.append(self.vert(Vector(centre) + Vector((x * c - y * s, x * s + y * c, sz * size[2] / 2))))
			self.paint(idx, side_paint)

	def lathe(self, base, profile, bands, seg=12):
		"""Round body from (radius, height) points; bands name a swatch per span."""
		rings = []
		for r, z in profile:
			if r <= 0:
				rings.append([self.vert(Vector(base) + Vector((0, 0, z)))])
			else:
				rings.append([self.vert(Vector(base) + Vector((r * math.cos(2 * math.pi * k / seg), r * math.sin(2 * math.pi * k / seg), z))) for k in range(seg)])
		for k in range(len(rings) - 1):
			a, c = rings[k], rings[k + 1]
			if len(c) == 1:
				for i in range(seg): self.swatch_face((a[i], a[(i + 1) % seg], c[0]), bands[k])
			else:
				self.quad_strip(a, c, bands[k])

	def to_object(self, name, material, sharp_deg=60, bevel=0.012, bevel_deg=30):
		mesh = bpy.data.meshes.new(name)
		mesh.from_pydata([tuple(v) for v in self.verts], [], self.faces)
		uv = mesh.uv_layers.new(name="UVMap")
		for poly in mesh.polygons:
			for k, li in enumerate(poly.loop_indices):
				uv.data[li].uv = self.uvs[poly.index][k]
		mesh.materials.append(material)
		if bevel: soften_edges(mesh, bevel, bevel_deg)
		mesh.shade_smooth()
		mesh.set_sharp_from_angle(angle=math.radians(sharp_deg))
		mesh.update()
		ob = bpy.data.objects.new(name, mesh)
		bpy.context.scene.collection.objects.link(ob)
		if bevel: weight_normals(ob)
		return ob

def soften_edges(mesh, width, min_deg):
	"""Weld the boxes' duplicated corners, then chamfer every edge sharper than `min_deg` into
	a small step so highlights catch them. A bevel strip takes one flat colour from
	the face beside it, so it never smears across the print sheet."""
	bm = bmesh.new()
	bm.from_mesh(mesh)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
	uv = bm.loops.layers.uv.active
	edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(min_deg)]
	res = bmesh.ops.bevel(bm, geom=edges, offset=width, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
	fresh = set(res["faces"])
	for f in fresh:
		ref = next((l[uv].uv.copy() for v in f.verts for l in v.link_loops if l.face not in fresh), None)
		if ref is not None:
			for l in f.loops: l[uv].uv = ref
	bm.to_mesh(mesh)
	bm.free()

def weight_normals(ob):
	"""Face-area weighted normals keep big flat faces flat while the chamfers stay smooth."""
	mod = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
	mod.keep_sharp = True
	for other in bpy.context.scene.objects: other.select_set(False)
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.modifier_apply(modifier=mod.name)

def material(name, png, roughness=0.85):
	m = bpy.data.materials.new(name)
	nodes = m.node_tree.nodes
	bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
	tex = nodes.new("ShaderNodeTexImage")
	tex.image = bpy.data.images.load(png)
	m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	bsdf.inputs["Roughness"].default_value = roughness
	bsdf.inputs["Metallic"].default_value = 0.0
	return m

def export_glb(ob, path):
	"""One object to a .glb; its texture stays a separate PNG next to it (shared by a kit)."""
	for other in bpy.context.scene.objects: other.select_set(False)
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_cameras=False,
		export_lights=False, export_animations=False, export_keep_originals=True)
	print("EXPORTED", path, len(ob.data.polygons), "faces")

def preview(render_path, eye, target, size=(1000, 640), lens=60, background="C9D3D6"):
	scene = bpy.context.scene
	cam = bpy.data.objects.new("PreviewCamera", bpy.data.cameras.new("PreviewCamera"))
	scene.collection.objects.link(cam)
	cam.data.lens = lens
	cam.location = eye
	cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
	scene.camera = cam
	scene.render.engine = "BLENDER_WORKBENCH"
	scene.display.shading.light = "STUDIO"
	scene.display.shading.color_type = "TEXTURE"
	scene.display.shading.show_cavity = True
	scene.world.color = lin(background)[:3]
	scene.render.resolution_x, scene.render.resolution_y = size
	scene.render.filepath = render_path
	bpy.ops.render.render(write_still=True)
	print("RENDERED", render_path)

def project_args():
	"""(project dir, --render path or None) from the arguments after `--`."""
	args = sys.argv[sys.argv.index("--") + 1:]
	return args[0], (args[args.index("--render") + 1] if "--render" in args else None)
