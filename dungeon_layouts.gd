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
# Surya Nagri (Floor 2) adds:
#   ,  garden (grass and flowers)    P  carved pillar          q  broken pillar
#   y  palm tree                     l  lantern post           h  stone elephant
#   W  the Surya Chakra (needs the 3 x 3 cells round it open)  F  temple front on a wall
#   B  is the inlaid boss court there; T  a lamp on the cliff
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

## Surya Nagri, the lost sun city at the bottom of a canyon: you arrive in the south
## hall, walk up between pillars into the plaza where the golden Surya Chakra turns,
## a stone channel runs down the east side with three bridges to the palm garden and
## the stone elephant, ruins and ore to the west, and the inlaid sun court (boss, chest,
## the way down) behind the wheel in the north.
const FLOOR_2 := [
	"########################",
	"##F..#BBBBFBBBB#.ww.F###",
	"#....#BBBBBBBBC#.ww...##",
	"#.q..#BBBbBBBBX#.ww.y.##",
	"#..o.##BBBBBBB##.pp...##",
	"#y...q##..P..##..ww..L.#",
	"#..L....P...P....ww.y..#",
	"##..l.........l..ww..h.#",
	"#F...P...,,,...P.pp....#",
	"#.q.....,,W,,....ww.l..#",
	"#..o.P...,,,...P.ww.y..#",
	"##..l.........l..ww..L.#",
	"#..x....P...P....ww....#",
	"###..q##.....##..pp..y##",
	"###....#.....#...ww...##",
	"####.T.#..E..#.T.ww.F###",
	"####...........S.ww.####",
	"########################",
]

static func rows(index: int) -> Array:
	return [FLOOR_1, FLOOR_2][clampi(index, 0, 1)]
