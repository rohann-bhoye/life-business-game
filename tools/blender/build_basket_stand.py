# Builds the shop's shopping basket stand: a tidy stack of red baskets with two folding
# handles each, on a small steel base. Origin at the floor centre, ~0.42 x 0.32 x 0.78 m.
# Run: blender --background --factory-startup --python tools/blender/build_basket_stand.py -- <project dir>
import bpy, bmesh, os, sys
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
root = args[0]

def mat(name, hexcol, rough=0.55, metal=0.0):
	m = bpy.data.materials.new(name)
	b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	c = [int(hexcol[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	lin = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
	b.inputs["Base Color"].default_value = (*lin, 1)
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metal
	return m

for o in list(bpy.data.objects): bpy.data.objects.remove(o)
M = {"red": mat("BasketRed", "D93A2B"), "dark": mat("BasketDark", "8E2218"), "steel": mat("Steel", "B9C0C4", 0.35, 0.8), "green": mat("StandGreen", "1F5E4A")}
parts = []

def box(name, size, loc, m, taper=1.0):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
	o = bpy.context.object
	o.name = name
	o.scale = size
	bpy.ops.object.transform_apply(scale=True)
	if taper != 1.0:  # wider at the top: scale the top four vertices
		for v in o.data.vertices:
			if v.co.z > 0: v.co.x *= taper; v.co.y *= taper
	o.data.materials.append(m)
	parts.append(o)
	return o

def basket(z):
	W, D, H, T = 0.40, 0.30, 0.17, 0.012
	box("Floor", (W - 0.06, D - 0.06, T), (0, 0, z + T / 2), M["dark"])
	for sx in (-1, 1):
		box("End", (T, D, H), (sx * (W / 2 - T / 2), 0, z + H / 2), M["red"])
	for sy in (-1, 1):
		box("Side", (W, T, H), (0, sy * (D / 2 - T / 2), z + H / 2), M["red"])
	box("RimX", (W + 0.012, 0.02, 0.014), (0, D / 2, z + H), M["dark"])
	box("RimX2", (W + 0.012, 0.02, 0.014), (0, -D / 2, z + H), M["dark"])
	for sx in (-1, 1):
		box("Handle", (0.016, 0.16, 0.016), (sx * (W / 2 + 0.01), 0, z + H + 0.03), M["steel"])
		box("HandleUp", (0.016, 0.016, 0.06), (sx * (W / 2 + 0.01), 0.075, z + H + 0.005), M["steel"])
		box("HandleUp", (0.016, 0.016, 0.06), (sx * (W / 2 + 0.01), -0.075, z + H + 0.005), M["steel"])

# base plate, post, and four baskets stacked loosely (each a bit nested in the last)
box("Base", (0.46, 0.36, 0.03), (0, 0, 0.015), M["green"])
box("Post", (0.04, 0.04, 0.2), (0, 0, 0.13), M["steel"])
for i in range(4): basket(0.20 + i * 0.12)
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
ob = bpy.context.object
ob.name = "BasketStand"
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "assets/props/basket_stand/source/basket_stand.blend"))
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(root, "assets/props/basket_stand/basket_stand.glb"), export_format="GLB", use_selection=True, export_cameras=False, export_lights=False, export_animations=False)
print("EXPORTED", len(ob.data.polygons))
