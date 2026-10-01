# GOPALA Waterways terrain integration

Implemented 30 September 2026 for Godot 4.7.2 and the Compatibility renderer.

The Kathmandu terrain loads a baked Waterways river scene. It includes all 249 mapped reaches and retains their OSM way IDs, names, endpoint positions and downstream ordering. The 46 reaches tagged covered or tunnel are retained but hidden; 203 surface reaches are drawn and exposed by the water-source query. The amber, unsurveyed Bagdwar reconstruction remains a separate layer.

## Source and licence

Upstream is [Arnklit/Waterways](https://github.com/Arnklit/Waterways/tree/godot4_5_1), Godot 4 branch `godot4_5_1`, revision `cd4c6330a02b0b57908c33181fd387aad53aa584`, addon version 0.3. The MIT licence is retained in `game/addons/waterways/LICENSE.md`; `tools/waterways-source.json` records the source hashes and local patches. Existing compatibility fallbacks, constant-width optimization and GUI adjustments are preserved. This integration also types the River property list for Godot 4.7 and frees detached plugin controls on shutdown.

Mapped geometry remains ODbL data. Terrain dressing retains the separate Copernicus elevation licence. The generated scene and its input/output receipt live beside that geographic data in `game/data/geography/waterways/`; see `game/data/geography/ATTRIBUTION.md`.

## Delivered behaviour

- Waterways generates the river meshes and UV2 atlases; the project adapter dresses vertices onto the visible terrain with a 0.045-unit lift. Zero curve handles retain mapped courses without Bezier overshoot. Tight-turn triangle winding is corrected before normals are generated.
- The project shader supplies animated downstream normals, bank foam, soft edges and restrained screen refraction. Depth reconstruction handles Compatibility's OpenGL range and orthographic projection. These effects require an actual renderer; headless tests alone cannot validate them.
- Flow/foam and shore/distance textures are baked on the CPU into the Waterways UV2 layout, then saved with the meshes. These are artistic directional and shore masks, **not collider-derived obstacle maps or hydraulic flow simulations**. Startup loads the saved resources without mesh generation or GPU baking.
- Display widths are enlarged: Bagmati 64 m, other rivers 44 m, streams 20 m. They are visual proxies, not measured banks. The terrain itself is a regional elevation proxy, not a detailed riverbed survey.
- `world.water_network.sample(world_position)` returns `has_water`, stable `source_id`, `name`, centerline `distance_m`, displayed `surface_y`, normalized downstream `flow_direction`, and `mapped`. It uses a spatial index, excludes covered reaches and the inferred headwater, and returns dry outside the rendered bands. Queries do not create water inventory or promise a safe access path. Workers, delivered water, reservations and save state remain economy backlog work.

## Rebuild and review

From the project root:

```sh
python3 tools/godot.py --headless --script core/tools/bake_waterways.gd
python3 tools/verify.py
python3 tools/godot.py --rendering-method gl_compatibility -- --capture-water
```

Rebake after changes to mapped data, the ground model, River adapter, shader or Waterways mesh helpers. Verification rejects stale inputs, changed vendored source bytes and a changed baked output. For a newly added file, refresh the Godot editor before playtesting.

`run_waterways_tests.gd` checks source integrity, bake inputs and output, all 249 deserialized reaches, endpoint/source preservation, surface visibility, map activation and bank masks, sampled finite geometry and upward normals, terrain clearance, and independently specified wet/dry source-query boundaries and flow direction. The normal Kathmandu tests continue checking geography, construction suitability, ground picking and camera behaviour.

`reports/kathmandu-waterways.png` is the actual Compatibility-rendered close-up. The river nodes remain editable in the baked scene, but manual edits are overwritten by the next geography rebuild. Change the source or adapter for persistent changes. Standard upstream River/WaterSystem/Buoyant tools remain installed; obstacle-raycast baking, global buoyancy maps, waterfalls, lakes, flood dynamics and downstream joins with shared hydraulic state are outside this terrain integration's acceptance.
