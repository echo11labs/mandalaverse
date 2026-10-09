# Local trees from the three requested packs

The user's 2026-10-08 request replaces trees using `Resources/Vegetation.zip`, `KayKit_Forest_Nature_Pack_1.0_FREE.zip` and `Forest Scene.zip`. `GopalaNatureModels` applies optional local models to the reviewed regional forest, nearby detail trees, and collectible timber stands. Without the local files, the licensed KayKit models remain usable.

## Selected models

Vegetation supplies the leafy `Tree_03_V`, `Tree_04_V`, and `Tree_05_V` broadleaf variants. The base, bare-branch versions were rejected during visual inspection. Forest Scene supplies Conifer Small, Medium and Tall LOD1 Unity meshes. KayKit supplies the three scrub aliases and the public fallback for all sixteen aliases. Archive hashes, converted GLB hashes and the mapping are in the ignored `game/assets/models/local_nature/source-receipt.json` and `variants.json`.

Vegetation has no included licence; Forest Scene's Unity package licences do not establish redistribution rights for the conifer art. Both packs and their conversions remain local, excluded from Git. This is local integration of user-provided files, not public asset admission. KayKit's CC0 receipt and original licence remain tracked.

## Reproduction

Place the three named archives in `Resources/`, then run:

```
python3 tools/convert_local_trees.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/export_local_trees_blender.py
python3 tools/verify.py
```

Preparation needs Pillow. The Blender exporter was run with Blender 5.2 LTS. It uses a fresh background scene, not the user's interactive scene. Preparation extracts only selected vegetation textures and the FBX, plus Forest Scene's serialized meshes and two textures. Intermediate files stay in a `.gdignore` source directory. Godot imports embedded images as uncompressed internal resources to avoid generated external texture UID dependencies. JSON receipts use the keep importer to avoid the user's animation importer.

Unity channel layouts are validated before decoding; triangle winding and coordinate handedness are converted, UVs retained, and source LOD1 meshes are used without inventing geometry. Photoshop TIFF's unspecified fourth channel is preserved as foliage alpha. Materials use double-sided alpha cutout rather than blended foliage, with textures capped at 1024 pixels. Original Unity wind, translucency and texture-array shaders are not ported. Blender emits a sampler-selection warning while exporting reused images; the resulting GLBs are inspected in Godot. This warning is separate from the Godot gate reports.

## Invariants and evidence

Runtime merging includes child transforms and all material surfaces. For the regional bake, replacement meshes are fitted to each original mesh's height and bottom-centre anchor. MultiMesh resources are duplicated; instance buffers remain byte-identical. Seed, positions, rotations, physical heights, instance counts and 4,811 spatial batches are preserved. The baked public scene and its review receipt are unchanged. New mesh bounds drive culling; nearby batches retain their existing conservative transformed bounds.

Collectible timber still has three trees and hides them as its existing resource amount declines. No inventories, simulation ticks, distribution rules, balance or performance benchmark sources change. The scale standard's unit/dimension contract stays at revision 11. Verification adds measured, hashed tree bounds to `reports/scale-audit.json`, including bottom-centre anchors and the existing people-to-river regressions.

The renderer-backed `run_nature_model_tests.gd` compares every regional instance buffer and count against an untouched loaded bake, checks bounds and source immutability, and checks timber depletion. Its local report is `reports/local/tree-replacement.json`. Local screenshots are `reports/local/tree-pack-gallery.png` and `tree-replacement-{camp,cattle,source,forest}.png`. These previews stay out of public Git alongside the unverified art. This does not satisfy the still-pending matched eight-run performance acceptance for G1-11/G1-12.

The final workspace gate passed 178/178 stages with no captured Godot warnings or timeouts. The replacement fixture passed 3,941 checks and changed 3,887 of the 4,811 existing batches. With the local mapping disabled in a separate process, the public-model fixture passed 54 checks with zero changed batches and the scale fixture passed 174 checks. The local mapping and measured audit were restored afterwards. Comparison-gallery trees are normalized to 12 m (KayKit scrub to 3 m) for material inspection; in-game variants keep their original configured heights.
