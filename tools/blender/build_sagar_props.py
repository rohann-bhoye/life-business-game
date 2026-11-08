# Builds Sagar Point's props (sagar_point.gd places them):
#   chhatri.glb     a Rajasthani sandstone chhatri (domed pavilion): plinth, four pillars
#                   with bases and capitals, lintels, sloping chhajja eaves, a drum, a dome
#                   and a gilded kalash finial. 4.2 x 4.2 m, 6.3 m tall.
#   lighthouse.glb  a red and white banded lighthouse on a stone base: gallery with a rail,
#                   a glowing lantern room, a red cap. 4.8 m wide, 16.6 m tall.
# Origins at the floor centre, front toward -Y in Blender (+Z in Godot).
# Writes assets/props/sagar/*.glb.
# Run: blender --background --factory-startup --python tools/blender/build_sagar_props.py -- <project dir>
import bpy, os, sys, math

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
out_dir = os.path.join(args[0], "assets/props/sagar")
os.makedirs(out_dir, exist_ok=True)

for o in list(bpy.data.objects): bpy.data.objects.remove(o)
for block in (bpy.data.meshes, bpy.data.materials):
	for item in list(block): block.remove(item)

def lin(hexcol):
	c = [int(hexcol[i:i + 2], 16) / 255 for i in (0, 2, 4)]
	return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]

def mat(name, hexcol, rough=0.7, metal=0.0, emit=0.0):
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
	"sand": mat("Sandstone", "D49A5E"), "sand_light": mat("SandstoneLight", "E6BC86"),
	"sand_dark": mat("SandstoneDark", "B07A45"), "gold": mat("Kalash", "D9A420", 0.35, 0.8),
	"white": mat("LighthouseWhite", "F4F2EC", 0.5), "red": mat("LighthouseRed", "C8302A", 0.5),
	"stone": mat("BaseStone", "8E8C86", 0.85), "dark": mat("IronDark", "2A2E33", 0.5, 0.6),
	"lamp": mat("LanternGlow", "FFE9A0", 0.2, 0.0, 3.0), "door": mat("DoorTeal", "1F6F78", 0.6),
}
parts = []

def add(o, m):
	o.data.materials.append(m)
	parts.append(o)
	return o

def box(size, loc, m):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
	o = bpy.context.object
	o.scale = size
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	return add(o, m)

def frustum(r1, r2, depth, z, m, vertices=24, turn=0.0):
	bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=(0, 0, z + depth / 2))
	o = bpy.context.object
	o.rotation_euler[2] = turn
	bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
	return add(o, m)

def ball(r, z, m, squash=1.0, cut=False):
	bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(0, 0, z), segments=24, ring_count=12)
	o = bpy.context.object
	o.scale = (1, 1, squash)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	if cut:
		bpy.ops.object.mode_set(mode="EDIT")
		bpy.ops.mesh.select_all(action="SELECT")
		bpy.ops.mesh.bisect(plane_co=(0, 0, z), plane_no=(0, 0, 1), clear_inner=True)
		bpy.ops.object.mode_set(mode="OBJECT")
	return add(o, m)

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

# ---------- chhatri
box((4.2, 4.2, 0.22), (0, 0, 0.11), M["sand_dark"])
box((3.9, 3.9, 0.16), (0, 0, 0.3), M["sand"])
for x in (-1.55, 1.55):
	for y in (-1.55, 1.55):
		box((0.46, 0.46, 0.22), (x, y, 0.49), M["sand_light"])
		box((0.3, 0.3, 2.3), (x, y, 1.75), M["sand"])
		box((0.42, 0.42, 0.18), (x, y, 2.99), M["sand_light"])
		box((0.36, 0.36, 0.1), (x, y, 0.95), M["sand_dark"])
for s in (-1, 1):
	box((3.5, 0.34, 0.3), (0, s * 1.55, 3.23), M["sand"])
	box((0.34, 3.5, 0.3), (s * 1.55, 0, 3.23), M["sand"])
	# Little cusped arch brackets under the lintels.
	for t in (-0.75, 0.0, 0.75):
		box((0.5, 0.12, 0.14), (t, s * 1.55, 3.02), M["sand_light"])
		box((0.12, 0.5, 0.14), (s * 1.55, t, 3.02), M["sand_light"])
frustum(3.15, 2.2, 0.32, 3.38, M["sand_light"], 4, math.pi / 4)
box((2.6, 2.6, 0.28), (0, 0, 3.84), M["sand"])
frustum(1.28, 1.28, 0.42, 3.98, M["sand_dark"], 16)
frustum(1.4, 1.4, 0.08, 4.38, M["sand_light"], 16)
ball(1.36, 4.46, M["sand_light"], 1.12, cut=True)
frustum(0.22, 0.14, 0.18, 5.95, M["gold"], 12)
ball(0.16, 6.22, M["gold"])
ball(0.1, 6.42, M["gold"])
frustum(0.03, 0.01, 0.22, 6.48, M["gold"], 8)
finish("chhatri")

# ---------- lighthouse
frustum(2.4, 2.25, 1.0, 0.0, M["stone"], 16)
frustum(2.0, 1.95, 0.25, 1.0, M["stone"], 16)
for i in range(6):
	r1 = 1.75 - 0.11 * i
	frustum(r1, r1 - 0.11, 2.0, 1.25 + i * 2.0, M["red" if i % 2 == 0 else "white"], 24)
box((0.9, 0.3, 1.7), (0, -2.05, 1.85), M["door"])
box((1.1, 0.34, 0.16), (0, -2.05, 2.75), M["white"])
frustum(1.75, 1.75, 0.22, 13.25, M["dark"], 24)
for k in range(16):
	a = k * math.tau / 16
	bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=0.9, location=(1.62 * math.cos(a), 1.62 * math.sin(a), 13.92), vertices=6)
	add(bpy.context.object, M["dark"])
bpy.ops.mesh.primitive_torus_add(major_radius=1.62, minor_radius=0.05, location=(0, 0, 14.37), major_segments=32, minor_segments=6)
add(bpy.context.object, M["dark"])
frustum(0.95, 0.95, 0.25, 13.47, M["white"], 16)
frustum(0.85, 0.85, 1.35, 13.72, M["lamp"], 16)
for k in range(8):
	a = k * math.tau / 8
	bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=1.35, location=(0.87 * math.cos(a), 0.87 * math.sin(a), 14.4), vertices=6)
	add(bpy.context.object, M["dark"])
frustum(1.12, 0.12, 0.95, 15.07, M["red"], 16)
ball(0.2, 16.15, M["dark"])
finish("lighthouse")
