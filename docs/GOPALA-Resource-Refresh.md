# Resource library refresh — 12 October 2026

The requested `/resources` library resolves to this project's `Resources` directory on the case-insensitive local volume. Eight supplied archives and one loose GLB were reviewed against the previous resource survey and current runtime references.

## Applied replacements

| Existing object | Updated presentation | Source |
| --- | --- | --- |
| Wild-food shrubs | Four alternating bush shapes, fitted to the existing 0.55 m shrub-width limit; visible berries at the canopy edge | Existing KayKit Bush_1_A/Bush_2_A plus new Bush_3_A/Bush_4_A |
| Thatch | Taller grass silhouettes with an instance-only straw material | KayKit Grass_2_A/Grass_2_B |
| Fodder | Mixed short and taller fresh-green tufts | Existing Grass_1_A plus Grass_2_B |
| Collectible stones | Four alternating rock silhouettes | Existing Rock_1_A/Rock_3_A plus Rock_1_B/Rock_3_B |
| Storage shelter | Two crates and a barrel within the existing footprint | Already admitted Highlands WoodCrate/Barrel |
| Timber camp | Two crates plus the existing axe | Already admitted Highlands WoodCrate/Axe |
| Water shelter | Paired barrels | Already admitted Highlands Barrel |

All selected new models come from the original KayKit Forest Nature archive. Its embedded CC0 license is byte-identical to the already admitted license. `tools/admit_resource_refresh.py` repacks original glTF, buffers and palette PNG into self-contained GLB; it preserves source geometry/UVs/textures, records archive/dependency/output hashes and refuses to overwrite different models. The separate `game/assets/models/nature/kaykit/resource-refresh-receipt.json` extends the package without changing the receipt used by the existing forest bake.

Forage receives per-instance material overrides, keeping imported source resources unchanged. The resource count, scatter RNG sequence, depletion, inventories, colliders and simulation remain intact. Plant yaw variation uses a deterministic formula without consuming scatter RNG. Props are visual details, not additional storage or inventory. Existing metre profiles and bottom-centre anchors remain authoritative; standard revision 13 is unchanged because dimensions/unit contracts did not change. Scale measurements are refreshed for the new rock variants and forage views.

## Other useful library assets

Cattle, huts, crates, barrels, fences, axes and the original KayKit nature variants were already integrated. This refresh retains them. Local villager overrides already select two medieval peasant models when available; redistributable checkouts retain the licensed Kenney fallback. Additional Craftpix models remain outside the public asset package. Unsupported animals and European towers/windmills are not replacements for existing gameplay objects. Vegetation, tools_mekmeesk, the Unity Forest Scene and Everything Animals volume 002 do not have sufficient matching redistribution evidence in the local library for admission here.

These remain stylized placeholder assets, not final Nepali architectural or botanical reconstruction. This work does not change the existing local forest override or regenerate its population/bake.

## Evidence

`reports/resource-refresh/before.png` and `after.png` use the same measured gallery and camera. `settlement.png` captures the actual initial MVP with unchanged inventory. `validation.json` records the visual checks, scale audit, world-view and model check results, including engine shutdown errors rather than hiding them.

The model assertions pass, but the standalone model test emits two OpenGL texture-leak errors at shutdown. The mandatory full gate continues to fail at import with resource leaks, case-mismatched demo scripts and the known language-server shutdown condition. No export-readiness, final-art or GPU-performance claim is made.
