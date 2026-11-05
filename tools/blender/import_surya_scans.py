# Turns the Poly Haven CC0 scans used in Surya Nagri (Gufa Darwaza Floor 2) into light
# game models: imports each 1k glTF, decimates every mesh to a triangle budget (the scan's
# own normal map keeps the fine detail) and exports one .glb with its textures inside.
# Sources (all CC0, polyhaven.com, 1k glTF): namaqualand_cliff_01, namaqualand_cliff_02,
# rock_face_01, namaqualand_boulder_04, shrub_04, fern_02, brass_diya_lantern,
# treasure_chest. Download each into <folder>/<name>/ (the .gltf, its .bin and textures/).
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/import_surya_scans.py -- <project dir> <download folder>
# Writes assets/props/dungeon/floor2/scans/<name>.glb.
import bpy, os, sys

# Triangle budget per model (whole model); 0 keeps it as it is (leaf cards must not collapse).
BUDGET = {
	"namaqualand_cliff_01": 16000, "namaqualand_cliff_02": 24000, "rock_face_01": 8000,
	"namaqualand_boulder_04": 6000, "treasure_chest": 9000, "shrub_04": 0, "fern_02": 0, "brass_diya_lantern": 0,
}

args = sys.argv[sys.argv.index("--") + 1:]
project, downloads = args[0], args[1]
out_dir = os.path.join(project, "assets", "props", "dungeon", "floor2", "scans")
os.makedirs(out_dir, exist_ok=True)

def tris(ob):
	return sum(len(p.vertices) - 2 for p in ob.data.polygons)

for name, budget in BUDGET.items():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	source = os.path.join(downloads, name, name + ".gltf")
	bpy.ops.import_scene.gltf(filepath=source)
	meshes = [ob for ob in bpy.context.scene.objects if ob.type == "MESH"]
	before = sum(tris(ob) for ob in meshes)
	if budget and before > budget:
		ratio = budget / before
		for ob in meshes:
			mod = ob.modifiers.new("Decimate", "DECIMATE")
			mod.ratio = ratio
			mod.use_collapse_triangulate = True
			bpy.context.view_layer.objects.active = ob
			for other in bpy.context.scene.objects: other.select_set(False)
			ob.select_set(True)
			bpy.ops.object.modifier_apply(modifier=mod.name)
	after = sum(tris(ob) for ob in meshes)
	path = os.path.join(out_dir, name + ".glb")
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_cameras=False, export_lights=False, export_animations=False, export_image_format="JPEG", export_jpeg_quality=88)
	print("SCAN", name, before, "->", after, "tris", [ob.name for ob in meshes])
