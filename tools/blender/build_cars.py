# Builds the drivable cars of Dholkarpur Gaon: hatchback, sedan, suv and pickup, each as
# separate named parts in one .glb so the game can paint, light and animate them:
#   Body    the paint (light grey here; Godot tints it per car)
#   Trim    black plastic: bumpers, grille, mirrors, door lines, seats, dashboard, wheel arches
#   Glass   windows (the game makes them see-through)
#   Lamps   headlights (front) and tail lights (rear), lit at night by the game
#   Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR   tyre and rim; origin at the wheel's centre
# The car faces +Y here (-Z in Godot), origin on the ground between the axles. The
# driver sits on the right (India drives on the left): Godot seat (+0.37, 1.05, 0.15).
#
# Run (Blender 5.2):
#   blender --background --factory-startup --python tools/blender/build_cars.py -- <project dir> [--render out.png]
# Writes assets/props/cars/<kind>.glb, cars_print.png and source/cars.blend.
import bpy, os, sys, math
from mathutils import Vector
sys.path.append(os.path.dirname(__file__))
from prop_kit import Sheet, Builder, clear_scene, material, preview, project_args

SWATCHES = {
	"paint": "F2F2F2", "paint_shade": "C4C4C4", "trim": "1E2024", "trim_light": "3A3E45", "glass": "5B7C99",
	"lamp_head": "FFF6D8", "lamp_tail": "D8221C", "lamp_amber": "FFA21A", "tyre": "1A1A1C", "rim": "B7BEC6",
	"rim_dark": "6E757D", "seat": "8A6F58", "plate": "F2F2EE", "bed": "9C9C9C",
}
# kind: length, width, roof height, belt height, cabin back/front (y), wheelbase, wheel radius, hood height
CARS = {
	"hatchback": dict(L=3.85, W=1.68, roof=1.5, belt=0.92, cb=-1.65, cf=0.55, wb=2.45, r=0.3, hood=0.82, tail=0.1),
	"sedan": dict(L=4.45, W=1.78, roof=1.45, belt=0.93, cb=-1.2, cf=0.62, wb=2.65, r=0.32, hood=0.86, tail=0.5),
	"suv": dict(L=4.6, W=1.88, roof=1.78, belt=1.08, cb=-2.05, cf=0.9, wb=2.7, r=0.38, hood=1.02, tail=0.0),
	"pickup": dict(L=5.15, W=1.88, roof=1.75, belt=1.1, cb=-0.25, cf=1.0, wb=3.1, r=0.4, hood=1.0, tail=0.0),
}

def poly(b, pts, x0, x1, swatch):
	"""A prism: the side outline `pts` (y, z) extruded from x0 to x1 (flat caps, quad sides)."""
	left = [b.vert((x0, y, z)) for y, z in pts]
	right = [b.vert((x1, y, z)) for y, z in pts]
	b.swatch_face(list(reversed(left)), swatch)
	b.swatch_face(right, swatch)
	for k in range(len(pts)):
		j = (k + 1) % len(pts)
		b.swatch_face((left[k], left[j], right[j], right[k]), swatch)

def wheel(mat, r, width):
	b = Builder(SHEET)
	rings = []
	for x, radius, name in ((-width / 2, r * 0.62, "rim"), (-width / 2, r, "tyre"), (width / 2, r, "tyre"), (width / 2, r * 0.62, "rim_dark")):
		rings.append([b.vert((x, radius * math.cos(2 * math.pi * k / 16), radius * math.sin(2 * math.pi * k / 16))) for k in range(16)])
	for i, name in enumerate(("tyre", "tyre", "tyre")): b.quad_strip(rings[i], rings[i + 1], name)
	hub = [b.vert((-width / 2 - 0.01, 0, 0))]
	for k in range(16): b.swatch_face((hub[0], rings[0][(k + 1) % 16], rings[0][k]), "rim" if k % 2 else "rim_dark")
	hub2 = b.vert((width / 2 + 0.01, 0, 0))
	for k in range(16): b.swatch_face((hub2, rings[3][k], rings[3][(k + 1) % 16]), "rim_dark")
	return b.to_object("Wheel", mat)

def build(kind, mat):
	c = CARS[kind]
	L, W, h = c["L"], c["W"], c["L"] / 2
	body, trim, glass, lamps = Builder(SHEET), Builder(SHEET), Builder(SHEET), Builder(SHEET)
	hw = W / 2
	lift = c["r"] * 0.9
	# Lower body: a convex side profile, from the rear bumper to the nose.
	pts = [(-h, lift), (h, lift), (h, lift + 0.32), (h - 0.1, c["hood"] - 0.04), (c["cf"] + 0.1, c["hood"] + 0.02),
		(c["cf"] - 0.2, c["belt"]), (c["cb"] + 0.1, c["belt"]), (-h + c["tail"] * 0.2, c["belt"] - 0.02 if kind != "pickup" else c["belt"]), (-h, c["belt"] - 0.15)]
	poly(body, pts, -hw, hw, "paint")
	if kind == "pickup":
		# The open load bed behind the cab: a floor and low side walls.
		body.box((0, (c["cb"] - h) / 2 - 0.1, c["belt"] - 0.05), (W - 0.04, h + c["cb"] - 0.1, 0.1), "paint_shade")
		for s in (-1, 1): body.box((s * (hw - 0.05), (c["cb"] - h) / 2 - 0.1, c["belt"] + 0.2), (0.1, h + c["cb"] - 0.1, 0.5), "paint")
		body.box((0, c["cb"] - 0.05, c["belt"] + 0.2), (W - 0.04, 0.1, 0.5), "paint")
		body.box((0, -h + 0.05, c["belt"] + 0.2), (W - 0.04, 0.1, 0.5), "paint_shade")
	# Greenhouse: glass trapezoid, a slim body-coloured roof on top.
	rear_slope = 0.05 if kind in ("suv", "pickup") else 0.55 + c["tail"] * 0.2
	front_slope = 0.55 if kind != "suv" else 0.4
	cab = [(c["cb"] + 0.05, c["belt"]), (c["cf"] - 0.2, c["belt"]), (c["cf"] - 0.2 - front_slope, c["roof"] - 0.06), (c["cb"] + 0.05 + rear_slope, c["roof"] - 0.06)]
	poly(glass, cab, -hw + 0.07, hw - 0.07, "glass")
	body.box((0, (cab[2][0] + cab[3][0]) / 2, c["roof"] - 0.03), (W - 0.1, abs(cab[2][0] - cab[3][0]) + 0.14, 0.07), "paint")
	# Bumpers, grille, plates, door lines, mirrors, wheel arches.
	trim.box((0, h + 0.02, lift + 0.12), (W - 0.04, 0.16, 0.24), "trim")
	trim.box((0, -h - 0.02, lift + 0.12), (W - 0.04, 0.16, 0.24), "trim")
	trim.box((0, h - 0.04, lift + 0.5), (W * 0.5, 0.08, 0.2), "trim_light")
	trim.box((0, h + 0.075, lift + 0.18), (0.42, 0.02, 0.12), "plate")
	trim.box((0, -h - 0.075, lift + 0.18), (0.42, 0.02, 0.12), "plate")
	for s in (-1, 1):
		trim.box((s * (hw + 0.005), (c["cb"] + c["cf"]) / 2, (c["belt"] + lift) / 2 - 0.05), (0.02, 0.02, c["belt"] - lift - 0.25), "trim")
		trim.box((s * (hw + 0.01), cab[1][0] - 0.25, c["belt"] + 0.03), (0.06, 0.18, 0.1), "trim")
		trim.box((s * (hw + 0.14), cab[1][0] - 0.15, c["belt"] + 0.12), (0.2, 0.1, 0.12), "trim")
		for wy in (c["wb"] / 2, -c["wb"] / 2):
			trim.box((s * (hw - 0.02), wy, c["r"] + 0.08), (0.04, c["r"] * 2.3, c["r"] * 1.3), "trim")
	# Lamps: headlights at the nose corners with amber indicators, tail lights at the back.
	for s in (-1, 1):
		lamps.box((s * (hw - 0.3), h - 0.03, c["hood"] - 0.2), (0.36, 0.06, 0.16), "lamp_head")
		lamps.box((s * (hw - 0.08), h - 0.03, c["hood"] - 0.2), (0.12, 0.06, 0.1), "lamp_amber")
		lamps.box((s * (hw - 0.22), -h + 0.02, c["belt"] - 0.3), (0.34, 0.05, 0.18), "lamp_tail")
	# Interior: seats, a dashboard, a steering wheel on the right.
	for s in (-1,):
		trim.box((s * 0.37, 0.1, lift + 0.35), (0.44, 0.5, 0.15), "seat")
		trim.box((s * 0.37, -0.12, lift + 0.7), (0.44, 0.1, 0.55), "seat")
	trim.box((0, c["cf"] - 0.35, c["belt"] - 0.12), (W - 0.2, 0.3, 0.25), "trim_light")
	trim.box((0, -0.9, lift + 0.35), (W - 0.2, 0.7, 0.15), "seat")
	objects = [body.to_object("Body", mat), trim.to_object("Trim", mat), glass.to_object("Glass", mat), lamps.to_object("Lamps", mat)]
	for name, sx, sy in (("FL", -1, 1), ("FR", 1, 1), ("RL", -1, -1), ("RR", 1, -1)):
		w = wheel(mat, c["r"], 0.22)
		w.name = "Wheel_" + name
		w.location = (sx * (hw - 0.12), sy * c["wb"] / 2, c["r"])
		objects.append(w)
	return objects

def export(objects, path):
	for other in bpy.context.scene.objects: other.select_set(False)
	for ob in objects: ob.select_set(True)
	bpy.context.view_layer.objects.active = objects[0]
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_cameras=False,
		export_lights=False, export_animations=False, export_keep_originals=True)
	print("EXPORTED", path, sum(len(ob.data.polygons) for ob in objects), "faces")

project, render = project_args()
out_dir = os.path.join(project, "assets", "props", "cars")
source = os.path.join(out_dir, "source")
os.makedirs(source, exist_ok=True)
open(os.path.join(source, ".gdignore"), "a").close()

clear_scene()
SHEET = Sheet(512, SWATCHES, 16, 72)
png = os.path.join(out_dir, "cars_print.png")
SHEET.render(png)
mat = material("Cars", png)
cars = {kind: build(kind, mat) for kind in CARS}
for kind, objects in cars.items(): export(objects, os.path.join(out_dir, kind + ".glb"))
for k, kind in enumerate(CARS):
	for ob in cars[kind]: ob.location = (ob.location[0] + (k % 2) * 3.4 - 1.7, ob.location[1] + (k // 2) * 6.0 - 3.0, ob.location[2])
if render: preview(render, (11, -9, 4.5), (0, 0, 0.8), lens=40)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source, "cars.blend"))
print("SAVED", os.path.join(source, "cars.blend"))
