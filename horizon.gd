extends RefCounted

# The road's profile past both ends of the town. Beyond the future town (|x| > 75)
# the land rises to a gentle crest, then falls away down a valley along the road, so
# from the shop the road and its traffic disappear over the horizon, like the earth
# curving away. Used by town_expansion.gd (road and valley) and traffic.gd (cars).
const START := 75.0
const CREST := 81.0
const RISE := 0.6
const FALL := 0.012

## Height of the road above the town ground at `x` (0 inside the town).
static func height(x: float) -> float:
	var distance := absf(x)
	if distance <= START: return 0.0
	if distance <= CREST: return RISE * smoothstep(START, CREST, distance)
	return RISE - FALL * (distance - CREST) * (distance - CREST)

## Rise per metre along +x at `x`.
static func slope(x: float) -> float:
	return (height(x + 0.05) - height(x - 0.05)) / 0.1
