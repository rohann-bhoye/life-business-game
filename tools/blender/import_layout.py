# Opens the whole game layout (exported from Godot by tools/export_layout.gd) in Blender with a sun,
# sky and a bird's-eye camera. Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/import_layout.py -- <project dir> [--render out.png]
# Writes assets/layout/game_layout.blend.
import bpy, os, sys, math
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:]
project = args[0]
render = args[args.index("--render") + 1] if "--render" in args else None
out = os.path.join(project, "assets", "layout")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(out, "game_layout.glb"))
scene = bpy.context.scene
scene.world = bpy.data.worlds.new("Sky")
scene.world.color = (0.62, 0.78, 0.95)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(35))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("OverviewCamera", bpy.data.cameras.new("OverviewCamera"))
cam.data.lens = 35
cam.data.clip_end = 3000
cam.location = (0, 260, 230)
cam.rotation_euler = (math.radians(30), 0, math.radians(180))
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
if render:
    scene.render.filepath = render
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "game_layout.blend"))
print("SAVED", len(bpy.data.objects), "objects")
