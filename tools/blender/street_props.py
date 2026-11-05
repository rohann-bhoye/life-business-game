# Street props from free online models (Poly Pizza; authors and licences in
# assets/props/street/README.md) plus our own counter weighing scale.
#
# Each downloaded model is joined into one mesh, sized to real metres, set on its floor
# centre with its front toward -Y in Blender (+Z in Godot), its textures shrunk to 512 px,
# and written to assets/props/street/<name>.glb:
#   bench.glb        park bench, wooden slats on concrete legs, 1.6 x 0.62 x 0.92 m
#   street_bin.glb   green vented street bin, 0.56 x 0.56 x 0.78 m
#   wheelie_bin.glb  green wheelie bin for the colony lanes, 1.07 m tall
#   planter.glb      wooden planter box with three bushes, 1.5 m long
#   pot_plant.glb    clay pot plant for the shop front, 1.0 m tall
# weighing_scale.glb (assets/props/shop) is built here: a kirana digital scale with a steel
# pan, a sloped display for the cashier (+Y in Blender, -Z in Godot) and a pole display
# facing the customer, both reading 0.000. 0.3 x 0.36 x 0.34 m.
#
# Run: blender --background --factory-startup --python tools/blender/street_props.py -- <downloads dir> <project dir>
# The downloads dir holds the five original files (names and links in the README).
import bpy, os, sys, math
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
downloads, root = args[0], args[1]
street_dir = os.path.join(root, "assets/props/street")
shop_dir = os.path.join(root, "assets/props/shop")
os.makedirs(street_dir, exist_ok=True)

# name, downloaded file, target size (x, y, z) in metres; None keeps the model's proportions
# on that axis using the first given axis' scale.
MODELS = [
	("bench", "bench_zsky.glb", (1.6, 0.62, 0.92)),
	("street_bin", "bin_street_isa.glb", (0.56, 0.56, 0.78)),
	("wheelie_bin", "bin_wheelie_quaternius.glb", (None, None, 1.07)),
	("planter", "planter_jtoastie.glb", (1.5, None, None)),
	("pot_plant", "pot_plant_google.glb", (None, None, 1.0)),
]

def clear():
	for o in list(bpy.data.objects): bpy.data.objects.remove(o)
	for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
		for item in list(block):
			try: block.remove(item)
			except (RuntimeError, ReferenceError): pass

def bounds(objects):
	lo = Vector((1e9,) * 3)
	hi = Vector((-1e9,) * 3)
	for o in objects:
		for corner in o.bound_box:
			world = o.matrix_world @ Vector(corner)
			lo = Vector(map(min, lo, world))
			hi = Vector(map(max, hi, world))
	return lo, hi

def joined(name):
	meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	for o in meshes:
		world = o.matrix_world.copy()
		o.parent = None
		o.matrix_world = world
	for o in list(bpy.context.scene.objects):
		if o.type != "MESH": bpy.data.objects.remove(o)
	bpy.ops.object.select_all(action="DESELECT")
	for o in meshes: o.select_set(True)
	bpy.context.view_layer.objects.active = meshes[0]
	if len(meshes) > 1: bpy.ops.object.join()
	ob = bpy.context.view_layer.objects.active
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	ob.name = name
	ob.data.name = name
	return ob

def settle(ob, size):
	lo, hi = bounds([ob])
	now = hi - lo
	given = [s / n for s, n in zip(size, now) if s is not None]
	factor = [s / n if s is not None else given[0] for s, n in zip(size, now)]
	centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
	ob.data.transform(Matrix.Diagonal((*factor, 1.0)) @ Matrix.Translation(-centre))
	ob.data.update()
	bpy.context.view_layer.update()
	lo, hi = bounds([ob])
	return hi - lo

def shrink_textures(limit=512):
	for image in bpy.data.images:
		if image.size[0] > limit or image.size[1] > limit:
			image.scale(limit, limit)
			image.pack()

def export(ob, path):
	bpy.ops.object.select_all(action="DESELECT")
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_cameras=False, export_lights=False, export_animations=False)

for name, file, size in MODELS:
	clear()
	bpy.ops.import_scene.gltf(filepath=os.path.join(downloads, file))
	ob = joined(name)
	final = settle(ob, size)
	shrink_textures()
	# Drop materials the joined mesh never uses (the bench file carries two spare ones).
	used = {slot.material for slot in ob.material_slots}
	for material in list(bpy.data.materials):
		if material not in used: bpy.data.materials.remove(material)
	export(ob, os.path.join(street_dir, name + ".glb"))
	tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
	print("PROP %s size %.2f x %.2f x %.2f m, %d tris" % (name, final.x, final.y, final.z, tris))

# --- Our own kirana weighing scale ---

clear()

def lin(hexcol):
	c = [int(hexcol[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]

def mat(name, hexcol, rough=0.55, metal=0.0, emit=0.0):
	m = bpy.data.materials.new(name)
	b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	b.inputs["Base Color"].default_value = (*lin(hexcol), 1)
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metal
	if emit > 0.0:
		b.inputs["Emission Color"].default_value = (*lin(hexcol), 1)
		b.inputs["Emission Strength"].default_value = emit
	return m

M = {
	"body": mat("ScaleBody", "D8DBDA", 0.5),
	"steel": mat("ScalePan", "C9CED1", 0.22, 0.85),
	"dark": mat("ScaleWindow", "15181B", 0.35),
	"trim": mat("ScaleTrim", "2C5F9E", 0.5),
	"key": mat("ScaleKeys", "8E959A", 0.6),
	"red": mat("ScaleDigits", "FF3A22", 0.4, 0.0, 2.2),
	"rubber": mat("ScaleFeet", "1C1D20", 0.85),
}
parts = []

def box(size, loc, m, frame=Matrix.Identity(4), bevel=0.0):
	bpy.ops.mesh.primitive_cube_add(size=1)
	ob = bpy.context.active_object
	ob.scale = size
	bpy.ops.object.transform_apply(scale=True)
	if bevel > 0.0:
		mod = ob.modifiers.new("Bevel", "BEVEL")
		mod.width = bevel
		mod.segments = 2
		bpy.ops.object.modifier_apply(modifier=mod.name)
	ob.matrix_world = frame @ Matrix.Translation(loc)
	ob.data.materials.append(m)
	parts.append(ob)
	return ob

def cylinder(radius, depth, loc, m, vertices=12):
	bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, vertices=vertices)
	ob = bpy.context.active_object
	ob.data.materials.append(m)
	parts.append(ob)
	return ob

# Seven-segment digits centred on a display window. `frame` maps window space into the
# model: x to the reader's right, z up, and the reader on the -y side.
SEGMENTS = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
	"6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}

def digits(text, frame, height=0.02, depth=0.0015):
	w = height * 0.55
	t = height * 0.13
	half = height / 2
	step = w + t * 2.4
	spots = {
		"a": ((w, depth, t), (0, half)), "g": ((w, depth, t), (0, 0)), "d": ((w, depth, t), (0, -half)),
		"f": ((t, depth, half), (-w / 2, half / 2)), "b": ((t, depth, half), (w / 2, half / 2)),
		"e": ((t, depth, half), (-w / 2, -half / 2)), "c": ((t, depth, half), (w / 2, -half / 2)),
	}
	cx = -(len(text.replace(".", "")) - 1) * step / 2
	for ch in text:
		if ch == ".":
			box((t, depth, t), (cx - step / 2, -0.0015, -half), M["red"], frame)
			continue
		for seg in SEGMENTS[ch]:
			size, (sx, sz) = spots[seg]
			box(size, (cx + sx, -0.0015, sz), M["red"], frame)
		cx += step

# Body: a low rounded case with rubber feet.
box((0.30, 0.30, 0.05), (0, -0.01, 0.033), M["body"], bevel=0.008)
for x in (-0.12, 0.12):
	for y in (-0.13, 0.11):
		cylinder(0.012, 0.008, (x, y, 0.004), M["rubber"], 10)
box((0.30, 0.004, 0.008), (0, 0.141, 0.05), M["trim"])
# Steel pan on a short pedestal, with a raised lip.
cylinder(0.03, 0.012, (0, -0.02, 0.064), M["key"], 12)
box((0.26, 0.23, 0.006), (0, -0.02, 0.073), M["steel"], bevel=0.002)
for x in (-0.13, 0.13):
	box((0.004, 0.23, 0.012), (x, -0.02, 0.079), M["steel"])
for y in (-0.135, 0.095):
	box((0.26, 0.004, 0.012), (0, y, 0.079), M["steel"])
# The cashier's console: a block on the +Y edge, its face tilted up toward the cashier,
# with the reading window on the left and six keys on the right (as the cashier sees it).
console = Matrix.Translation((0, 0.155, 0.045)) @ Matrix.Rotation(math.radians(28), 4, "X")
box((0.29, 0.05, 0.035), (0, 0, 0), M["body"], console, bevel=0.004)
face = console @ Matrix.Translation((0, 0.0255, 0)) @ Matrix.Rotation(math.pi, 4, "Z")
box((0.15, 0.002, 0.026), (-0.05, 0, 0), M["dark"], face)
digits("0.000", face @ Matrix.Translation((-0.05, 0, 0)))
for index in range(6):
	col = index % 3
	row = index // 3
	box((0.014, 0.004, 0.009), (0.065 + col * 0.02, 0, 0.007 - row * 0.012), M["trim"] if index == 0 else M["key"], face)
# The customer's pole display behind the pan, reading toward -Y (the customer).
cylinder(0.009, 0.24, (0, -0.152, 0.17), M["key"], 10)
pole = Matrix.Translation((0, -0.152, 0.31))
box((0.15, 0.03, 0.055), (0, 0, 0), M["body"], pole, bevel=0.004)
box((0.12, 0.002, 0.03), (0, -0.0155, 0), M["dark"], pole)
digits("0.000", pole @ Matrix.Translation((0, -0.0155, 0)))

bpy.ops.object.select_all(action="DESELECT")
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
scale = bpy.context.view_layer.objects.active
scale.name = "WeighingScale"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
lo, hi = bounds([scale])
print("PROP weighing_scale size %.2f x %.2f x %.2f m" % tuple(hi - lo))
export(scale, os.path.join(shop_dir, "weighing_scale.glb"))
