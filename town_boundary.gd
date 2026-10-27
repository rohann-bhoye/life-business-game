extends RefCounted

# The town's name and its extents. The whole land is open: the player may walk out
# of town onto the hills and mountains (the Landscape has collision) and only the
# end of the land stops them (LAND_*, walls in neighbourhood.gd). There is no
# barrier or send-home countdown any more.
## The town's name (welcome gates in town_expansion.gd, the top of the HUD).
const TOWN_NAME := "Dholkarpur Gaon"
## The flat town: lawn ground, grass and paths (environment_details.gd).
const MIN_X := -72.0
const MAX_X := 72.0
const MIN_Z := -52.0
const MAX_Z := 62.0
## The North Road lane through the hills (north_river.gd), grassed on the terrain.
const ROAD_MIN_X := 40.0
const ROAD_MAX_X := 60.0
const ROAD_END_Z := -232.0
## The end of the land (land_shape.gd covers x -128..127, z -256..127), a few
## metres in from its edge.
const LAND_MIN_X := -124.0
const LAND_MAX_X := 123.0
const LAND_MIN_Z := -252.0
const LAND_MAX_Z := 123.0
