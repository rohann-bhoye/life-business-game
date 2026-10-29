extends RefCounted

# The floors of Gufa Darwaza as grid maps (dungeon_floor.gd builds them): one character
# per 4 m cell, rows run +z, columns +x. Every open cell gets floor and ceiling, and a
# rock wall on each side that touches rock.
#   #  solid rock             .  open floor            w  stream (no walking)
#   p  plank bridge over it   E  entry stone (arrive, and E there to climb up)
#   X  stairs down            C  treasure chest        L  treasure lying about
#   m  glowing mushrooms      r  boulder               T  torch on a nearby wall
#   S  monster spawn          b  boss                  B  boss chamber floor
const CELL := 4.0

## Jugnu Gufa, the firefly cave: the entry hall (south-west) leads up to a mushroom
## grove, a stream splits the cave with two plank bridges, an east cavern, and the boss
## chamber with the chest and the stairs down.
const FLOOR_1 := [
	"########################",
	"##.......###ww##########",
	"#..m..L....#ww#.......T#",
	"#.m...S..m.#ww#..L..S..#",
	"#T.......m..pp.........#",
	"##.....r...#ww#..r.....#",
	"###.S......#ww##...m..##",
	"####..m..###ww###..#####",
	"####.....###ww###..#####",
	"###...#####.ww.#BBBBBB##",
	"##.....####.ww.BBBBBBBB#",
	"#...r..T....pp.BBBbBBCB#",
	"#..E.....##.ww.BBBBBBBT#",
	"##.....#####ww#BBBBBBXB#",
	"###..#######ww##########",
	"########################",
]

static func rows(index: int) -> Array:
	return [FLOOR_1][clampi(index, 0, 0)]
