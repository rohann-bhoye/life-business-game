# Surya Nagri scans (Poly Haven, CC0)

Free scanned assets from polyhaven.com (CC0: no credit needed, listed in CREDITS.md).

- Models (1k glTF), made light for the game by `tools/blender/import_surya_scans.py`
  (decimated, textures packed into one .glb each): namaqualand_cliff_01,
  namaqualand_cliff_02, rock_face_01, namaqualand_boulder_04, shrub_04, fern_02,
  brass_diya_lantern, treasure_chest.
- `textures/`: 1k JPG sets (diff, nor_gl, arm) of red_sandstone_pavement,
  large_sandstone_blocks, rabdentse_ruins_wall, sandstone_cracks, mossy_sandstone. The
  kit pieces use them through `assets/materials/real_detail*.gdshader`.
- `sky/`: kloofendal_48d_partly_cloudy_puresky (2k HDR), the sky over the canyon.

To rebuild the models: download each model's 1k glTF into `<folder>/<name>/`, then
`blender --background --factory-startup --python tools/blender/import_surya_scans.py -- <project> <folder>`.
