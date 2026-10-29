# Converts the Quaternius "Realistic Car Pack - Nov 2018" (CC0, https://quaternius.itch.io/lowpoly-cars)
# from FBX into game-ready .glb files, one per car, with named parts the game animates:
#   Body            the car (its first material is renamed "Paint" so the game can repaint it)
#   Wheel_FL, Wheel_FR   the two front wheels (origin at the wheel's centre: they steer and spin)
#   Wheels_Back     both rear wheels with their axle (origin at the axle's middle: spins)
# The cars face +Z in the files (Blender -Y); car_world/drivable_car.gd turns them to face -Z.
#
# Run (Blender 5.2), with the pack unzipped somewhere:
#   blender --background --factory-startup --python tools/blender/import_car_pack.py -- <project dir> <pack dir>
# Writes assets/props/cars/pack/<kind>.glb and LICENSE.txt.
import bpy, os, sys
args = sys.argv[sys.argv.index("--") + 1:]
project, pack = args[0], args[1]
out_dir = os.path.join(project, "assets", "props", "cars", "pack")
os.makedirs(out_dir, exist_ok=True)
CARS = {"NormalCar1": "normal1", "NormalCar2": "normal2", "Taxi": "taxi", "SUV": "suv", "SportsCar": "sports", "SportsCar2": "sports2", "Cop": "cop"}
for source, kind in CARS.items():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.fbx(filepath=os.path.join(pack, "FBX", source + ".fbx"))
	for ob in list(bpy.context.scene.objects):
		if ob.type != "MESH":
			bpy.data.objects.remove(ob)
			continue
		if ob.name == source: ob.name = "Body"
		elif ob.name.endswith("FrontLeftWheel"): ob.name = "Wheel_FL"
		elif ob.name.endswith("FrontRightWheel"): ob.name = "Wheel_FR"
		elif ob.name.endswith("BackWheels"): ob.name = "Wheels_Back"
	body = bpy.data.objects["Body"]
	if body.data.materials: body.data.materials[0].name = "Paint"
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, kind + ".glb"), export_format="GLB", use_selection=True,
		export_cameras=False, export_lights=False, export_animations=False)
	print("EXPORTED", kind, [ob.name for ob in bpy.context.scene.objects], [round(v, 2) for v in body.dimensions])
with open(os.path.join(out_dir, "LICENSE.txt"), "w") as f:
	f.write("Realistic Car Pack - Nov 2018 by Quaternius (https://quaternius.com), https://quaternius.itch.io/lowpoly-cars\nLicense: CC0 1.0 (public domain dedication). Converted from FBX to GLB by tools/blender/import_car_pack.py.\n")
