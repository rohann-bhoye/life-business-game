# Our own characters

Built on Kenney Mini Characters (CC0 1.0, https://kenney.nl/assets/mini-characters): each
keeps a Kenney rig and all 32 animations, with our palette colours and new low-poly parts.
Made by `tools/blender/build_characters.py`.

| id | base | who | look |
|---|---|---|---|
| shopkeeper | male-a | the player | cream shirt, green shop apron, pen, badge, moustache |
| staff | male-d | cashier (worker.tscn) | green polo, shop cap, ID lanyard, khaki trousers |
| staff-f | female-b | stock worker | same shop uniform |
| warehouse | male-f | warehouse worker | navy shirt, hi-vis vest, hard hat, cargo trousers |
| farmer | female-c | farm worker | mustard kurta, maroon salwar, straw hat, red gamcha |
| rival-m | male-e | Mr. Sharma | Sharma red uniform and cap, glasses |
| rival-f | female-f | Sharma's helper | Sharma red uniform and cap |
| uncle | male-b | customer | white kurta, saffron Nehru jacket, topi, grey beard |
| sikh | male-b | customer | navy kurta, saffron turban |
| aunty | female-d | customer | magenta saree with gold border and pallu, bindi |
| student | female-e | customer | teal jacket, jeans, backpack |

- Editable Blender files (Blender 5.2): `source/<id>.blend`; `source/all_characters.blend`
  shows them all side by side. `source/` has a `.gdignore`, so Godot skips the .blend files.
- Rebuild all (or some ids) after changing the script:
  `blender --background --factory-startup --python tools/blender/build_characters.py -- <project dir> [ids...]`
- After editing a .blend by hand: File > Export > glTF 2.0 (.glb), format GLB, Animation
  mode "Actions", save over `character-<id>.glb`. (Rebuilding from the script overwrites it.)

`character_visual.gd` loads `custom/character-<id>.glb` before the Kenney folder, so any
CharacterVisual can use `model = "<id>"`.
