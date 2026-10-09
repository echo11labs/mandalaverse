# G1-11 downloaded model upgrade

Devendra's explicit instruction to immediately replace models on 2026-10-08 supersedes the earlier baseline-first hold. The coordinator's approved replacement map remains the asset and gameplay scope. The bridge task is still blocked by its bookkeeping dependency; that state was reported on the bridge rather than bypassed. The previous clean-source benchmark checkout remains at deee176 and was not modified by this upgrade.

## Active replacements

| Presentation | Selected downloaded model | Geometry |
|---|---|---|
| Cattle | Styloo Cow, original skin/idle/walk animations | 4,740 triangles |
| Sixteen regional/detail/hero tree variants | KayKit Tree_2_A/B conifers; Tree_1, Tree_3, Tree_4 broadleaf mappings | 336–988 triangles per selected tree |
| Timber resource stand | KayKit Tree_2_A | 336 triangles |
| Wild-food bushes | KayKit Bush_1_A / Bush_2_A, existing berry markers | 72 / 44 triangles |
| Fodder/thatch plants | KayKit Grass_1_A on the original points | 44 triangles |
| Collectible and decorative stones | KayKit Rock_1_A / Rock_3_A | 48 / 84 triangles |
| Completed dwelling and gatherer shelter | Highlands SM_Hut | 780 triangles |
| Storage/timber-camp prop | Highlands WoodCrate | 456 triangles |
| Water facility and source | Highlands Barrel | 968 triangles |
| Existing cattle-shelter visual | Highlands WoodFence | 90 triangles |
| Existing timber-camp visual | Highlands Axe | 110 triangles |

Villagers now use the downloaded Craftpix peasant_4/peasant_5 locally, selected deterministically by entity ID, normalized to 1.75m and bottom-centre anchored. Their imported rigs had no animation clips, so the conversion authors idle/walk/pickup without root motion, driven through the existing worker presentation states. The FBX axis transforms are baked before export so visible skinning matches measured dimensions. All Craftpix files stay in the gitignored local_villagers folder; the public checkout uses the existing redistributable Kenney fallback. [Craftpix terms](https://craftpix.net/file-licenses/) permit game use but restrict reusable source redistribution. This scope extension follows Devendra's explicit request to update villagers. Open construction frames and open stockpile/timber/water/cattle shelters remain to communicate their function. Highlands huts are European-fantasy placeholders and kitbash pieces, **not final Newari architecture or historical evidence**. No unsupported animals, crops, inventory or roles are introduced. LOCAL-ONLY and LICENCE-UNKNOWN packs remain outside game source. Existing user addon/project/.tscn edits were preserved; Sky3D/SimpleGrass were not enabled by this change.

## Provenance and conversion

Nineteen selected self-contained GLBs are admitted with LICENSE.txt, RECEIPT.md and source hashes beside each pack; [CREDITS](../../CREDITS.md) lists the publishers. [Static audit](../../reports/assets/upgrade/asset-audit.json) records actual sizes, triangle counts, texture dimensions and animation names. Every GLB is under 10MB and every embedded texture is at most 1024px. Whole packs were not copied.

Nature glTF/bin/PNG sources were losslessly repacked into GLB; source geometry/materials and palette atlas are retained. Styloo Cow.glb was copied unchanged. Separate background Blender 5.2 CLI converted selected Highlands FBX, removed UCX_ objects and joined/baked child transforms. Source texture encodings required RGB conversion; Pillow resized maps to 1024px with Lanczos, then base-colour/roughness/normal were embedded. Alpha/metalness maps are omitted for these opaque timber/stone props. Conversion metadata records source hashes and removed objects. No open Blender scene was touched.

## Scale, placement and behaviour

Target dimensions remain in world_scale.json. Runtime fits imported bounds including child transforms to metres converted through terrain units, with bottom-centre ground anchors. Standard revision 11 adds measured fence and axe profiles; existing cattle, people, stone, forage, water, building and tree dimensions are preserved. Forest bake population remains exactly 100,940 trees, 4,811 chunks, and identical per-variant counts, seed, spacing and physical height ranges. Original scatter RNG consumption is preserved for forage. Original picking shapes, grid footprints, depletion and quantities remain authoritative. Picking now accepts rays starting inside a canopy volume: the larger imported canopy exposed this regression, and all 2,112 stone/timber collection/depletion checks pass after the fix.

Cattle walk while the existing cattle_move_state says MOVING, and idle while stationary/grazing/tended. Animation freezes while paused and observes simulation speed. It never changes herd rules, milk production, routing or the clock. The rebuilt forest is hash-pinned as a submitted candidate, with final human visual acceptance still pending.

## Evidence and remaining acceptance

Before/after captures under reports/assets/upgrade/ use identical camp, cattle, source and forest targets/spans at 1280×800 and 1920×1080. The optional building gallery is explicitly presentation-only; it does not grant buildings, spend goods or alter the live settlement. Logs preserve capture metadata.

Focused scale checks passed 142 checks. Model checks validate pack hashes, cattle animation selection/pause and all building footprints/stages. The workspace gate passed all 166 stages, with 253 model checks, 142 scale checks and no captured engine warnings. Its receipt is reports/G1-11-verification.json. The fresh committed-source gate also passed all 166 stages with zero captured warnings, no timeouts or known-error allowances at d25bbd17f7daa4d4077b75770cbea08269738c01. It passed 251 model checks using the public Kenney fallback, with no local Craftpix models. Receipt: reports/G1-11-clean-verification.json. Both source gates preserve the fantasy forest candidate as pending human review; that marker is not an engine warning. The temporary model check run during bake replacement reported a stale forest receipt warning; this was addressed by pinning the newly rebuilt candidate rather than accepting that warning as success. Initial texture-import failures were repaired before final verification. Blender conversion reported Material.use_nodes deprecation warnings; the local character export also reports its four-highest-weight skin influence normalization. These retained conversion warnings are distinct from the final gate's captured engine warnings.

G1-12's complete eight-run baseline and matched before/after performance comparison are still outstanding. The previous bounded-driver attempt completed three valid but over-budget 1280×800 runs and stalled on pre-timing vsync capture. **No <=5% p95 regression or smooth-gameplay claim is made by this asset upgrade.** The geometry reduction cannot resolve the already measured simulation snapshot/registry costs by itself. Optional props remain provisional until a valid matched benchmark establishes their rendering cost.

## Suggestions

Resolve the G1-12 capture question and complete matching before/after measurements from separate source revisions. Profile snapshot/registry copies in a separately approved task. Review huts, grass identity and cow animation at normal camera distances; retain open functional shelters and plan authentic Newari art rather than relabelling fantasy pieces. Keep the shared palette atlas and selected-file receipts to limit import cost and make replacements reversible.
