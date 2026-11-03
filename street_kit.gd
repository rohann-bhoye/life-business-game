class_name StreetKit
extends RefCounted
## One set of numbers for every road, sidewalk and path in town, so they all line up:
## asphalt is a 1.2 cm slab (top y 0.117), sidewalks and paths are raised 4 cm above
## the road, so each one has a kerb step.

const ASPHALT := Color(0.16, 0.18, 0.19)
const PAVING := Color(0.66, 0.69, 0.67)
const ROAD_Y := 0.111
const ROAD_THICK := 0.012
const PAVE_THICK := 0.058
const PAVE_Y := 0.129  # slab from the ground (0.1) up to 0.158
const PAVE_TOP := 0.158

## Size and centre of a sidewalk slab for a footprint of w (x) by d (z) at (x, z).
static func pavement_size(w: float, d: float) -> Vector3:
	return Vector3(w, PAVE_THICK, d)

static func pavement_at(x: float, z: float) -> Vector3:
	return Vector3(x, PAVE_Y, z)
