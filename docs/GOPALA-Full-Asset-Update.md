# Existing-object asset update — 12 October 2026

This completes the building/settler/cargo pass requested after the resource refresh. It updates existing gameplay objects; it does not add tower, windmill, barracks, crop or animal systems to the development plan.

## Buildings

All six definitions now have distinct presentation:

- **Dwelling:** compact Craftpix houses 05/06/11, chosen deterministically by entity ID, with warm roof coloration.
- **Stockpile:** houses 02/03 with slate-colored roofs and storage crates.
- **Gatherer shelter:** compact round-front house 15 with crate/barrel dressing.
- **Timber camp:** open canvas shelter with crates, axe and a rear fence.
- **Water point:** smaller open cover with three water barrels.
- **Cattle shelter:** open roof with three fence sides and a container; front access remains open.

The selected house pack was converted from the supplied `Resources/free-medieval-houses-3d-low-poly-pack.zip`. Twenty complete houses were converted and rendered for selection; large mansions/towers are retained only in the local catalog and are not selected by gameplay. Original source meshes/UVs are preserved, child transforms baked, textures reduced to 1024px and embedded, and collision objects excluded. The runtime shader changes blue roof pixels to earth or slate tones without mutating the source atlas.

Converted Craftpix houses and settlers are gitignored local game-use assets. Craftpix's freebie license permits game use/modification but restricts asset redistribution: https://craftpix.net/file-licenses/ (checked 12 October 2026). Conversion scripts and source/output hashes remain available; `game/assets/models/local_buildings/RECEIPT.json` and the villager receipt record the actual conversion. Public source checkouts retain the existing CC0 fallback models. Packaging includes the new shaders; no export was performed in this pass.

The runtime has no dependency on Blender. Each new model uses the existing entity IDs, definition IDs, construction progress, collider, occupancy and entrance rules. Completed buildings appear only after completion; the normalized frame remains visible during construction. Mesh and dressing are fitted inside each authoritative plot for all four quarter turns. Rotations now apply to the visual model and dressing as well as the picking footprint.

## Settlers and resources

All six supplied peasant variants use the existing project-authored static, idle, walk and pickup/work animations. Entity IDs choose variants deterministically; people remain 1.75m tall with bottom-centre foot anchors. Pausing still freezes animation. Kings, unsupported animals and other unrelated types are not spawned.

Seven carried-resource types now have actual goods views: log bundles, a rock, wooden water/milk containers, a food crate and straw/fodder bundles. Cargo uses the existing size profiles, follows worker heading and updates only when the resource type changes. The original invisible size proxy remains for compatibility; the goods view never modifies cargo quantities or transfers inventory.

The earlier KayKit plant/stone refresh and the already integrated cattle, timber trees and local forest replacements remain in place. No forest population or bake was changed.

## Scale and evidence

World scale revision 14 raises the generic building height cap from 2.5m to 4m for the compact houses, retains all existing 4×4m plots, and adds explicit shelter/inset dimensions. Open work shelters stay at most 2.5m tall and the water cover at most 2m. Actor/cargo dimensions and the 100 metres per world unit contract are unchanged.

The regenerated scale audit measures every building in all rotations, all six settler variants and seven cargo categories, including asset/script hashes. Gallery and actual-game captures are in `reports/building-refresh/`. The actual-game review creates a home using typed placement/assignment commands and real worker delivery/labor, without changing the user's running settlement or save.

Focused validation and engine errors are preserved in `reports/building-refresh/validation.json`. The full gate still stops at import on the existing leaked resource/RID errors, with case-mismatched demo script warnings and the known language-server shutdown condition. Model assertions pass but the standalone model test reports two OpenGL texture leaks during shutdown. This is not a clean full toolchain, export-readiness, GPU-performance or final historical-art claim.
