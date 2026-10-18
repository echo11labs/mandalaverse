# Path building

Implemented 12 October 2026 as a gameplay slice within the existing development plan.

## Player controls

- Press **R** (or Road in the bottom dock), then drag a continuous route to plan a dirt path. Press Space to run time if paused.
- An available idle settler automatically becomes the builder. Existing supply jobs are preserved. A selected settler can also be assigned through the site list or by right-clicking the path site.
- Dirt requires four work ticks per new cell and no materials. The builder walks to each cell before preparing it. Amber cells are plans; finished dirt cells provide the existing 1.25× travel benefit.
- Press **Shift+R** to pave finished dirt. Each cell needs two stone, one timber and eight work ticks. The builder reserves, carries and delivers materials to the first selected work cell before beginning work. Finished paving cells provide the existing 1.6× travel benefit.
- Select a path to inspect completed cells, work, delivered materials and its builder. Cancel unfinished work from the inspector. Completed cells remain; unused stock is returned, while installed paving materials remain consumed.
- Stopping a road builder disables automatic reassignment for that job. Manually assign a settler to resume it.

## Runtime contract

Road entities hold construction records and use the shared fixed-tick construction labor and storage services. Planning creates no completed surface or movement bonus. Pausing prevents both movement and construction. Rendering observes completed cell boundaries; it does not grant progress or consume inventory.

Automatic assignments use the typed command queue and only workers without an active task, cargo or existing work role. One builder works each stretch. Work rates are provisional gameplay values.

Version-2 saves accept legacy finished roads and persist new construction state, deliveries, reservations and worker cargo. Validation rejects inconsistent work budgets, invalid cells and material totals. Saves taken during dirt work and paving haul are exercised through JSON serialization and restoration. Dirt stretches may skip cells already covered by an existing path; paving currently operates within one existing road entity.

## Appearance and scale

Dirt uses an original procedural earth shader. Path surfaces clip the actual terrain triangles to their footprints, preventing terrain from cutting through thin surfaces on slopes. Stones follow terrain height and slope, with deterministic color variation and batched MultiMesh rendering. Picking uses the surface mesh and the existing entity adapter.

Physical dimensions remain governed by `game/data/standards/world_scale.json`, revision 13. Paver dimensions are converted from metres to world units once; the previous second conversion caused excessive instance counts. The six-cell review fixture checks bounded instance counts, authored stone widths, picker binding and visible color variation.

## Evidence and limits

`game/tests/run_path_construction_tests.gd` covers real worker movement, material conservation at each tick, incomplete-surface speed restrictions, partial completion, cancellation including carried goods, and save restoration. `game/tools/review_path_building.gd` exercises the actual MVP scene and captures planned, active, dirt and paved stages in `reports/path-building/`.

Focused regression results and the latest full-gate receipt are recorded in `reports/path-building/validation.json`. The mandatory full gate remains blocked at import by existing leaked resources; demo-script case warnings and the known language-server shutdown error are also recorded. This slice does not establish export readiness, GPU performance, final art, bridges or multi-builder scheduling.
