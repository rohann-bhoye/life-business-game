# Starts Blender with the whole game layout already imported (Blender runs this with --python).
import bpy, os, math
glb = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "layout", "game_layout.glb")
for ob in list(bpy.data.objects): bpy.data.objects.remove(ob)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(glb))
for area in bpy.context.window.screen.areas:
	if area.type == "VIEW_3D":
		area.spaces[0].shading.type = "MATERIAL"
		area.spaces[0].clip_end = 3000
