# Street props (free online models)

Downloaded from Poly Pizza and tidied by `tools/blender/street_props.py` (joined into one
mesh, sized to real metres, floor-centre origin, front toward +Z in Godot, textures cut to
512 px). The game places them with `neighbourhood.gd` `street_prop()`.

| File | Original | Author | Licence | Source |
|---|---|---|---|---|
| bench.glb | Bench | Zsky | CC BY 3.0 | https://poly.pizza/m/fm3UkY4k60 |
| street_bin.glb | Trashcan | Isa Lousberg | CC0 1.0 | https://poly.pizza/m/2UXIdGYkg9 |
| wheelie_bin.glb | Trashcan | Quaternius | CC0 1.0 | https://poly.pizza/m/XSwahu252t |
| planter.glb | Planter & Bushes | J-Toastie | CC BY 3.0 | https://poly.pizza/m/wn85Xr9lM3 |
| pot_plant.glb | House plant | Poly by Google | CC BY 3.0 | https://poly.pizza/m/3qh9saogdJd |

CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/) needs the author credited: they are
listed in `CREDITS.md` at the project root, which ships with the game. The models were
resized and their textures shrunk; nothing else was changed.

To rebuild, download the five originals (each page's GLB download) into an empty folder
with the names `bench_zsky.glb`, `bin_street_isa.glb`, `bin_wheelie_quaternius.glb`,
`planter_jtoastie.glb` and `pot_plant_google.glb`, then run:

    blender --background --factory-startup --python tools/blender/street_props.py -- <that folder> .

The same script builds our own counter scale, `assets/props/shop/weighing_scale.glb`.
