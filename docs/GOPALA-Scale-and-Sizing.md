# GOPALA scale and sizing standard

`game/data/standards/world_scale.json` is the authoritative contract. Revision 2 replaced the rejected schematic actor scale with physical sizes in metres. `GopalaScaleStandard.number()` converts dimensional profiles to Godot world units. Counts and unit-conversion settings remain unconverted.

## Units

The terrain uses **100 metres per world unit**, XZ ground and +Y up. A 2-metre logical cell is 0.02 world units. A person 1.75 metres tall is **0.0175 world units**, not 2 world units. People, props, carried goods and placeholder building heights use this same conversion. Camera close-zoom limits are also specified in metres.

| Object | Physical target | World units |
| --- | --- | --- |
| Human reference | 1.75 m high, 0.25 m radius | 0.0175 high, 0.0025 radius |
| Loose stone | 0.18–0.30 m wide, at most 0.26 m high | 0.0018–0.003 wide |
| Stone patch | 11 stones within a 0.42 m radius | 0.0042 centre radius |
| Patch picking bounds | 1.4 × 0.4 × 1.4 m | 0.014 × 0.004 × 0.014 |
| Carried stone | 0.28 × 0.22 × 0.28 m | 0.0028 × 0.0022 × 0.0028 |
| Timber source tree | 16 m high | 0.16 high |
| Imported timber shelter maximum | 2.5 m high | 0.025 high |
| Minimum close camera span | 5 m | 0.05 |

The rivers retain their existing artistic display widths: 64 m for Bagmati, 44 m for other rivers and 20 m for streams. These are not surveyed bank widths. The sizing regression compares people with these actual rendered widths and prevents enlarged actor meshes. Terrain retains its existing vertical relief exaggeration; that does not multiply actor or prop dimensions.

Imported model measurements include all descendant transforms and pivots. Apply yaw, normalize to the converted target, cap height and anchor the bottom centre to the ground. Replacing a model or changing export units recomputes its factor automatically. Depletion removes visible pieces without changing the size of each stone. Physical interaction boxes are separate from rendered stone meshes.

## Change workflow

1. Edit physical dimensions in the standard and increment its revision when dimensions, units or coverage change.
2. Add a measured profile/check before migrating another category. Existing forest models retain their metre-height normalization; buildings retain logical footprint sizing.
3. Run `python3 tools/verify.py`. Its sizing stage regenerates `reports/scale-audit.json` with standard/asset hashes, source/fitted dimensions and patch bounds. Live stone tests validate every terrain patch, picking and delivery.
4. Inspect the audit and logs. Refresh the editor and restart the preview to reload the standard.
5. Capture objects beside a person **and an environmental reference such as a river**, at close and management zoom. Do not judge scale from actor-to-prop comparisons alone.

At regional overview, correctly sized people and small stones can be below pixel size. Do not enlarge their world meshes to improve map readability; a separate UI marker would need its own explicit presentation contract. Automatic checks do not establish final artwork or manual player acceptance.


Revision 3 adds camera dimensions: 200 m default vertical span, at least 50 m camera distance, 5 cm near clipping, a 12 km regional relief depth allowance and 2 m padding around measured scenery chunk bounds. Distance grows with zoom span. Culling bounds merge every transformed model, including crowns crossing a chunk edge; orthographic scenery uses frustum culling without a camera-distance cutoff.


Revision 4 extends the contract to motion and starting offsets. `movement.walk_speed` is metres per logical second (1.4 m/s, converted to 0.014 world units/s). `scenario` defines five-metre worker offsets, ten-metre starter-tree offsets, and the bounded dry-bank search/clearance. The runtime scene resolves a dry settlement origin before configuring the logical grid. Authored building/ghost widths use footprint cells × world units per cell, without an extra factor of two.

Revision 5 extends coverage to imported worker and building models. The worker uses a stable normalization wrapper around animated nodes, measured in the static pose at 1.75 m. Timber shelters fit uniformly within their logical footprint and 2.5 m maximum height. Construction roots retain their picking bounds while model ground anchors compensate for stage height. The gate regenerates `reports/model-asset-audit.json` with dimensions and checks the retained source receipts, licenses and external textures. See `GOPALA-Model-Assets.md` for asset provenance and prototype limits.

Revision 6 uses a 40 m starting span around current workers/buildings, an 8 m focus margin and the same 2 m settlement cells for the visible grid. Grid/placement anchors follow rendered terrain triangles. Rendering settings govern nearby scenery padding, tile width and cache size; the terrain partition uses a dimensionless quad count. See `GOPALA-Local-Settlement-View.md` for the rendering, physics and simulation boundaries.

Revision 7 adds an 80 m navigation margin around the planning bounds. Worker routing retains two-metre cells and 1.4 m/s physical speed; waypoint traversal uses the configured logical tick interval. Navigation coverage grows independently of placement bounds.

Revision 8 adds original prototype forage patches and carry bundles. Thatch/fodder stems are at most 1 m tall; wild-food shrubs fit the same 3 m patch width limit. The terrain-following cluster has a 1.65 m vertical bound, including ground relief; individual stems/shrubs remain about 1 m tall. Nine plants occupy a 1.1 m radius, with 3.5 cm stems and 5 cm fruit. Depletion hides plants without resizing survivors. Carried bundles are 45 × 35 × 45 cm. The scale audit records measured category sizes and the authored view's hash. Existing people-to-river regression checks remain mandatory. These are game abstractions, not approved botanical or historical art.

Revision 9 adds the existing CC0 Kenney barrel as a water collection view, normalized through all child transforms to 70 cm height with an 80 cm width bound and bottom-centre anchor. Carried water containers are 30 × 40 × 30 cm. Verification adds measured barrel bounds/hashes and retains human-to-river checks.

Revision 10 adds 1.25-metre cattle, bottom-centre normalized original prototype geometry, eight-metre pastures, and carried milk vessels. The scale audit records measured cattle bounds and its source hash.

G1-11 standard revision 11 adds visual-only fence (0.8m high, at most 2m wide) and axe (0.5m high/wide) profiles. Imported cattle, huts, barrels and nature retain their existing target dimensions and bottom-centre anchors. Physical meshes remain metre-authored, converted through the terrain unit standard.

Revision 14 raises the building height cap to 4 m for the selected compact house models while keeping every existing 4 × 4 m plot. `building_presentation` defines 15 cm plot insets, 3.2 × 3 m work shelters at most 2.5 m high, and a 2.2 m water cover at most 2 m high. Imported houses, shelter dressing and quarter turns are measured inside the same logical footprints. Settlers stay 1.75 m tall; the six local variants and seven carried-goods views are measured against their existing profiles. These are asset-fitting targets, not historical architecture measurements.

Revision 15 adds an `terrace_field` profile for the 8 × 8 m, sixteen-cell agricultural plot, 8 cm raised beds, 30 cm risers, and a 25 cm terrain-step threshold. Field dimensions and vertical presentation are authored in metres and converted through the regional 100 m/world-unit contract; the threshold remains an explicitly metre-valued measured comparison. The scale-standard test checks these conversions and the 8 m plot profile.
