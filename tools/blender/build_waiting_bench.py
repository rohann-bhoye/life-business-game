# Builds the shop's waiting bench: a green-painted wooden slat seat and back on steel legs.
# 1.5 x 0.55 x 0.9 m, origin at the floor centre, seat facing +Y here (Godot +Z after export).
# Run: blender --background --factory-startup --python tools/blender/build_waiting_bench.py -- <project dir>
import bpy, os, sys
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
root = args[0]

def mat(name, hexcol, rough=0.6, metal=0.0):
	m = bpy.data.materials.new(name)
	b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	c = [int(hexcol[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	b.inputs["Base Color"].default_value = ([x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1])
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metal
	return m

for o in list(bpy.data.objects): bpy.data.objects.remove(o)
WOOD, WOOD2, STEEL = mat("Wood", "C98F52"), mat("WoodDark", "A8733C"), mat("Steel", "3C4A52", 0.4, 0.7)
parts = []
def box(size, loc, m):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
	o = bpy.context.object
	o.scale = size
	bpy.ops.object.transform_apply(scale=True)
	o.data.materials.append(m)
	parts.append(o)

L = 1.5
for i in range(4):  # seat slats (front to back)
	box((L, 0.1, 0.035), (0, -0.2 + i * 0.12, 0.45), WOOD if i % 2 == 0 else WOOD2)
for i in range(3):  # back slats
	box((L, 0.03, 0.12), (0, -0.27, 0.62 + i * 0.16), WOOD if i % 2 == 0 else WOOD2)
for sx in (-1, 1):
	box((0.04, 0.5, 0.04), (sx * (L / 2 - 0.1), 0.0, 0.42), STEEL)     # seat rail
	box((0.04, 0.04, 0.45), (sx * (L / 2 - 0.1), 0.2, 0.225), STEEL)    # front leg
	box((0.04, 0.04, 0.45), (sx * (L / 2 - 0.1), -0.22, 0.225), STEEL)  # back leg
	box((0.04, 0.04, 0.5), (sx * (L / 2 - 0.1), -0.29, 0.7), STEEL)     # back post
	box((0.05, 0.4, 0.05), (sx * (L / 2 - 0.1), 0.0, 0.7 + 0.0), STEEL) if False else None
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
ob = bpy.context.object
ob.name = "WaitingBench"
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "assets/props/waiting_bench/source/waiting_bench.blend"))
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(root, "assets/props/waiting_bench/waiting_bench.glb"), export_format="GLB", use_selection=True, export_cameras=False, export_lights=False, export_animations=False)
print("EXPORTED", len(ob.data.polygons))
