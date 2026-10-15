# Neighbourhood Terrain3D

This project uses the owner's installed Terrain3D 1.0.2 addon under
`addons/terrain_3d`. Its MIT licence remains in that folder. The renderer remains
Godot Compatibility; no renderer migration or additional addon was needed.

`neighbourhood_landscape.tscn` is instanced as `Landscape` in `main.tscn.tscn`.
It loads four saved 128-metre regions covering a 256-by-256-metre square. The
central neighbourhood is flat; hills start beyond the existing play boundary.
Terrain collision is disabled. `Ground`, roads, shop/house colliders and boundary
walls still define gameplay collision. This is scenery, not an expanded playable
map or a replacement for the shop floor.

## Editing

Enable Terrain3D in Project Settings > Plugins (already enabled in project.godot).
Open the gameplay scene, select `Landscape` and use the Terrain3D tools. Region
data lives in `assets/terrain/neighbourhood`. Preserve the flat centre and identity
terrain transform. Back up these resources before painting or sculpting.

The small grass albedo and flat-normal textures are original procedurally generated
project assets. They use saved file resources; no external textures are required.
The main asset/material lists remain editable from the Terrain3D inspector.
When creating the Windows demo export, include the entire neighbourhood data
directory: region resources are loaded from `data_directory`, not explicit scene
references. Verify the hills in the exported build as part of release QA.

## Starter Generator

`tools/build_landscape.gd` generated the starter regions and textures. It is NOT
run during gameplay. It refuses to overwrite an existing landscape unless given
the explicit `-- --rebuild` argument. Rebuilding replaces the starter terrain data;
do not run it over hand-painted/sculpted work without a backup.

## Verification

`tests/terrain_landscape_test.gd` uses temporary game saves and checks extension
loading, saved regions/materials, flat gameplay heights, hills, original ground
collision, world boundaries and unchanged economy. Graphical mode captures and
checks terrain pixels at desktop 1152x648 and 1920x1080. No new portrait or mobile
target is part of this task.

Terrain3D 1.0.2 emits a deprecated `instance_reset_physics_interpolation()` warning
on Godot 4.7.2. It is an upstream addon compatibility warning, not an application
assertion. Do not modify the owner's installed addon just to silence it.

Official documentation:
- https://terrain3d.readthedocs.io/en/stable/docs/platforms.html
- https://terrain3d.readthedocs.io/en/stable/api/class_terrain3d.html
- https://terrain3d.readthedocs.io/en/stable/api/class_terrain3ddata.html
