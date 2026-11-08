# Builds Sagar Beach's props (sagar_point.gd places them):
#   rock_a/b/c.glb  low-poly sea rocks (craggy, flat shaded, wet dark base), about 1 m.
#   sea_stack.glb   a tall sea stack with a green cap, 1.6 m wide and 4 m tall (scaled up).
#   crab.glb        a little red beach crab: shell, six legs, two claws, eyes on stalks,
#                   0.3 m across, facing -Y in Blender (+Z in Godot).
#   starfish.glb    a five-armed pink-orange starfish, 0.22 m.
#   palm.glb        a coconut palm: a leaning ringed trunk, eleven drooping fronds and a
#                   bunch of coconuts, 7 m tall.
# Origins at the floor centre. Writes assets/props/beach/*.glb.
# Run: blender --background --factory-startup --python tools/blender/build_beach_props.py -- <project dir>
import bpy, bmesh, os, sys, math, random
from mathutils import Vector, noise

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
out_dir = os.path.join(args[0], "assets/props/beach")
os.makedirs(out_dir, exist_ok=True)
random.seed(7)

for o in list(bpy.data.objects): bpy.data.objects.remove(o)
for block in (bpy.data.meshes, bpy.data.materials):
	for item in list(block): block.remove(item)

def lin(hexcol):
	c = [int(hexcol[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]

def mat(name, hexcol, rough=0.8):
	m = bpy.data.materials.new(name)
	b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	b.inputs["Base Color"].default_value = (*lin(hexcol), 1)
	b.inputs["Roughness"].default_value = rough
	return m

M = {
	"rock": mat("Rock", "8A867C"), "rock_wet": mat("RockWet", "4E4B46", 0.35), "moss": mat("Moss", "5C8A3A"),
	"crab": mat("CrabShell", "E0482A", 0.5), "crab_dark": mat("CrabDark", "9E2A17", 0.6), "eye": mat("Eye", "111111", 0.3),
	"star": mat("Starfish", "F08A5D", 0.7), "star_dot": mat("StarfishDots", "FFD2A8", 0.7),
	"trunk": mat("PalmTrunk", "8E6E4E", 0.9), "ring": mat("PalmRing", "6B513A", 0.9), "frond": mat("PalmFrond", "3F9A3C", 0.7),
	"frond_dark": mat("PalmFrondDark", "2E7A30", 0.7), "coconut": mat("Coconut", "5A3B1E", 0.7),
}
parts = []

def add(o, m):
	o.data.materials.append(m)
	parts.append(o)
	return o

def finish(name):
	global parts
	for o in bpy.context.selected_objects: o.select_set(False)
	for o in parts: o.select_set(True)
	bpy.context.view_layer.objects.active = parts[0]
	bpy.ops.object.join()
	ob = bpy.context.object
	ob.name = name
	bpy.ops.object.shade_flat()
	bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), export_format="GLB", use_selection=True, export_cameras=False, export_lights=False, export_animations=False)
	print("EXPORTED %s %d faces" % (name, len(ob.data.polygons)))
	bpy.data.objects.remove(ob)
	parts = []

def crag(radius, scale, seed, sink=0.25):
	"""A craggy rock: an icosphere pushed about by noise, its low part dark and wet."""
	bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=(0, 0, 0))
	o = bpy.context.object
	offset = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
	for v in o.data.vertices:
		bump = noise.noise(v.co * 1.6 / radius + offset) * 0.35 + noise.noise(v.co * 4.0 / radius + offset) * 0.12
		v.co *= 1.0 + bump
		v.co.x *= scale[0]; v.co.y *= scale[1]; v.co.z *= scale[2]
	low = min(v.co.z for v in o.data.vertices)
	high = max(v.co.z for v in o.data.vertices)
	for v in o.data.vertices: v.co.z -= low + (high - low) * sink
	o.data.materials.append(M["rock"])
	o.data.materials.append(M["rock_wet"])
	for poly in o.data.polygons:
		if poly.center.z < (high - low) * 0.12: poly.material_index = 1
	parts.append(o)
	return o

def tube(points, radii, m, sides=8):
	"""A tube along points (a trunk or a leg) with the given radii."""
	bm = bmesh.new()
	rings = []
	for i, p in enumerate(points):
		ahead = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
		side = ahead.cross(Vector((0, 0, 1)) if abs(ahead.z) < 0.95 else Vector((1, 0, 0))).normalized()
		up = side.cross(ahead).normalized()
		rings.append([bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * radii[i]) for a in [k * math.tau / sides for k in range(sides)]])
	for i in range(len(rings) - 1):
		for k in range(sides):
			bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
	bm.faces.new(list(reversed(rings[0])))
	bm.faces.new(rings[-1])
	mesh = bpy.data.meshes.new("Tube")
	bm.to_mesh(mesh)
	bm.free()
	o = bpy.data.objects.new("Tube", mesh)
	bpy.context.collection.objects.link(o)
	return add(o, m)

def ball(r, loc, m, scale=(1, 1, 1)):
	bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=12, ring_count=7)
	o = bpy.context.object
	o.scale = scale
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	return add(o, m)

# ---------- rocks and a sea stack
for name, scale, seed in (("rock_a", (1.2, 0.9, 0.7), 1), ("rock_b", (0.9, 1.0, 1.0), 2), ("rock_c", (1.4, 1.1, 0.5), 3)):
	crag(0.55, scale, seed)
	finish(name)
crag(0.8, (1.0, 0.9, 2.6), 5, sink=0.05)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.62, location=(0.05, 0, 3.75))
cap = bpy.context.object
cap.scale = (1.0, 0.9, 0.35)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
add(cap, M["moss"])
finish("sea_stack")

# ---------- crab (front toward -Y)
ball(0.1, (0, 0, 0.07), M["crab"], (1.35, 1.0, 0.5))
ball(0.07, (0, 0.02, 0.1), M["crab_dark"], (1.2, 0.8, 0.35))
for s in (-1, 1):
	for k, y in enumerate((-0.03, 0.02, 0.07)):
		tube([Vector((s * 0.1, y, 0.06)), Vector((s * 0.18, y + 0.01, 0.08)), Vector((s * 0.24, y + 0.02, 0.0))], [0.014, 0.012, 0.006], M["crab_dark"], 5)
	tube([Vector((s * 0.08, -0.08, 0.07)), Vector((s * 0.12, -0.14, 0.08))], [0.016, 0.018], M["crab"], 6)
	ball(0.035, (s * 0.13, -0.17, 0.08), M["crab"], (0.9, 1.4, 0.7))
	tube([Vector((s * 0.03, -0.09, 0.09)), Vector((s * 0.035, -0.1, 0.14))], [0.006, 0.006], M["crab_dark"], 4)
	ball(0.013, (s * 0.035, -0.1, 0.15), M["eye"])
finish("crab")

# ---------- starfish
bm = bmesh.new()
centre_top = bm.verts.new((0, 0, 0.025))
centre_low = bm.verts.new((0, 0, 0.0))
rim = []
for k in range(10):
	a = k * math.tau / 10 + math.pi / 2
	r = 0.11 if k % 2 == 0 else 0.035
	rim.append(bm.verts.new((r * math.cos(a), r * math.sin(a), 0.004 if k % 2 == 0 else 0.012)))
for k in range(10):
	bm.faces.new((centre_top, rim[k], rim[(k + 1) % 10]))
	bm.faces.new((centre_low, rim[(k + 1) % 10], rim[k]))
mesh = bpy.data.meshes.new("Starfish")
bm.to_mesh(mesh)
bm.free()
star = bpy.data.objects.new("Starfish", mesh)
bpy.context.collection.objects.link(star)
add(star, M["star"])
finish("starfish")

# ---------- coconut palm (leans toward -Y, the sea)
trunk = [Vector((0, -0.9 * (t ** 1.8), 6.6 * t)) for t in [i / 9 for i in range(10)]]
tube(trunk, [0.2 - 0.07 * i / 9 for i in range(10)], M["trunk"], 8)
for i in range(1, 9):
	p = trunk[i]
	bpy.ops.mesh.primitive_torus_add(major_radius=0.2 - 0.07 * i / 9, minor_radius=0.025, location=p, major_segments=10, minor_segments=4)
	add(bpy.context.object, M["ring"])
top = trunk[-1]
for k in range(11):
	a = k * math.tau / 11 + random.uniform(-0.15, 0.15)
	reach = random.uniform(2.2, 2.9)
	droop = random.uniform(1.0, 1.7)
	bm = bmesh.new()
	left, right = [], []
	for j in range(9):
		t = j / 8
		centre = top + Vector((math.cos(a) * reach * t, math.sin(a) * reach * t, 0.35 * math.sin(t * math.pi) - droop * t * t))
		width = 0.42 * math.sin(min(t * 1.15, 1.0) * math.pi) + 0.02
		across = Vector((-math.sin(a), math.cos(a), 0)) * width
		fold = Vector((0, 0, -0.12 * width))
		left.append(bm.verts.new(centre + across + fold))
		right.append(bm.verts.new(centre - across + fold))
	middle = [bm.verts.new(top + Vector((math.cos(a) * reach * j / 8, math.sin(a) * reach * j / 8, 0.35 * math.sin(j / 8 * math.pi) - droop * (j / 8) ** 2 + 0.05))) for j in range(9)]
	for j in range(8):
		bm.faces.new((left[j], middle[j], middle[j + 1], left[j + 1]))
		bm.faces.new((middle[j], right[j], right[j + 1], middle[j + 1]))
	mesh = bpy.data.meshes.new("Frond")
	bm.to_mesh(mesh)
	bm.free()
	frond = bpy.data.objects.new("Frond", mesh)
	bpy.context.collection.objects.link(frond)
	add(frond, M["frond" if k % 2 == 0 else "frond_dark"])
for k in range(4):
	a = k * math.tau / 4 + 0.4
	ball(0.13, top + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, -0.25)), M["coconut"])
finish("palm")
