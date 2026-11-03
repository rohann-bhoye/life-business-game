extends RefCounted

# The floors of Gufa Darwaza as grid maps (dungeon_floor.gd builds them): one character
# per 4 m cell, rows run +z, columns +x. Every open cell gets floor and ceiling, and a
# rock wall on each side that touches rock.
#   #  solid rock             .  open floor            w  stream (no walking)
#   p  plank bridge over it   E  entry stone (arrive, and E there to climb up)
#   X  stairs down            C  treasure chest        L  treasure lying about
#   o  ore rock (break it with the lathi)  x  rubble
#   m  glowing mushrooms      r  boulder               T  torch on a nearby wall
#   S  monster spawn          b  boss                  B  boss chamber floor
#   1-4  a page of Dada-ji's diary on a stand (dungeon_books.gd)
const CELL := 4.0

## Jugnu Gufa, the firefly cave: the entry hall (south-west) leads up to a mushroom
## grove, a stream splits the cave with two plank bridges, an east cavern, and the boss
## chamber with the chest and the stairs down.
const FLOOR_1 := [
	"########################",
	"##.......###ww##########",
	"#3.m..L..o.#ww#.......T#",
	"#.m...S..m.#ww#..L..S..#",
	"#T.......m..pp.........#",
	"##.....r..x#ww#..r..o..#",
	"###.S......#ww##...m..##",
	"####..m..###ww###..#####",
	"####.2...###ww###..#####",
	"###.x.#####.ww.#BBBBBB##",
	"##..S..####.ww.BBBBBBBB#",
	"#.1.r..T....pp4BBBbBBCB#",
	"#..E.o.S.##.ww.BBBBBBBT#",
	"##.....#####ww#BBBBBBXB#",
	"###..#######ww##########",
	"########################",
]

static func rows(index: int) -> Array:
	return [FLOOR_1][clampi(index, 0, 0)]
