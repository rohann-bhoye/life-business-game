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

## The parts [from, to] of the span `start`..`end` left after cutting out `gaps`
## ([from, to] pairs): a sidewalk or edge line stops at every road that joins it, so the
## asphalt runs straight through the junction.
static func pieces(start: float, end: float, gaps: Array) -> Array:
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(a, b): return a[0] < b[0])
	var result := []
	var at := start
	for gap in sorted:
		if gap[1] <= at or gap[0] >= end: continue
		if gap[0] > at: result.append([at, gap[0]])
		at = maxf(at, gap[1])
	if at < end: result.append([at, end])
	return result
