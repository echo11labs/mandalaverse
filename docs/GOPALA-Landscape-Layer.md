# GOPALA — Landscape layer

Implemented 29 September 2026. This is the first interactive landscape, not a functioning settlement economy.

## Current direction

The user permits mixed 2D/3D presentation when it improves quality and iteration. The main scene uses native Godot 3D terrain with an orthographic management camera and a screen-space interface. The settlement still uses a 48 × 48 logical ground grid. Original 2D TileMap experiments remain available as diagnostics; they are separate maps, not interchangeable save formats.

Run `python3 tools/godot.py` from the project root, or open `game/project.godot` in the pinned engine. The main scene is `game/scenes/landscape/scenic_valley.tscn`.

## Delivered

- A seeded height field with a connected winding riverbed, riverbanks, wooded foothills and a gently sloped starting clearing.
- A 180 × 180 world-unit settlement area, surrounded by scenic terrain. One planning cell is 3.75 world units.
- Native ground mesh, a physics picking surface, animated water, clustered broadleaf/conifer shapes, grasses, and river stones.
- Fixed orthographic orientation; scroll zoom, middle-drag/WASD/arrow pan, overview and clearing shortcuts.
- Optional planning grid and click inspection showing cell coordinates, surface type and suitable/unsuitable ground.
- Construction suitability samples each cell's center and corners: land must be above water and no steeper than 12 degrees. Future placement must also check an entire building footprint, entrances, occupancy and routes.

The geometry and shaders are original procedural work. The vegetation is a stylized visual study, not verified Nepali botanical or archaeological reconstruction. Trees and stones do not yet represent inventory or gatherable sources.

## Acceptance and evidence

`python3 tools/verify.py` imports the project, checks authored scripts, tests content, retains the 2D terrain regression suite, tests the scenic landscape, and executes the main scene headlessly. The scenic suite checks seed repeatability, submerged riverbed, water/riverbank agreement, grid round trips, flat clearing, mesh/model agreement, finite upward normals, physics picking at four zoom levels and camera limits.

Real graphics captures are separate from headless verification. `-- --capture` saves `reports/landscape-3d-overview.png`; `-- --capture-close` saves `reports/landscape-3d-clearing.png`. These show the actual Godot scene, not concept art. The tested renderer is Compatibility on Apple M4 Pro. An optional Forward+/Metal capture failed to complete within approximately two minutes; it was stopped and is not accepted for this layer.

No mobile performance, desktop export, navigation, erosion, seasonal simulation or save integrity claim is made.

## Next layer

Add placement previews and occupation to this same logical grid: first a stockpile and dwelling footprint, then entrances and navigable routes. Keep terrain selection and decorative trees separate from authored gatherable state. Introduce a worker only after path and placement rules are visible and testable. Physically delivered construction materials follow with the economy milestone.

## Source decisions

Native Godot meshes and MultiMesh keep this pass self-contained. Terrain3D was evaluated but not installed; its native extension and larger terrain authoring workflow can be reconsidered if editable large worlds become necessary. See [Godot procedural mesh documentation](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/arraymesh.html), [renderer guide](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) and [Terrain3D upstream](https://github.com/TokisanGames/Terrain3D).

## Kathmandu geographic revision

The main scene is now the geographic Kathmandu view, not the invented starting valley described above. Its 40 km regional extent, measured elevation, river graph, local planning grid and reconstruction limits are recorded in [Kathmandu geography](GOPALA-Kathmandu-Geography.md). Earlier landscape scenes remain diagnostics.
