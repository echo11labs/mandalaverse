# GOPALA — Farthest Frontier reference and tree replacement

Research date: 30 September 2026. Direction supplied by the user: change the tree models, use Farthest Frontier as the main game reference, and use externally authored assets rather than modelling trees ourselves. This document records research and a proposed implementation sequence. It does not mark an art replacement or economy milestone complete.

## Decision

Target naturalistic, textured 3D vegetation with clear silhouettes at settlement zoom. The MegaKit direction does not meet the latest brief. The official Standard archive contains the same Pine/CommonTree/TwistedTree files already present in the older StylizedNature folder; downloading that archive was provenance verification, not a new model library. The procedural cone/blob canopy layer was removed during the preceding work, but the current external MegaKit forest remains an unaccepted intermediate study.

The user subsequently specified **free assets only**. Paid Nature Manufacture and SpeedTree options are therefore excluded from acquisition. The leading free pipeline under evaluation is Bentley's now-free PlantFactory with its externally authored PlantCatalog presets. The user explicitly authorized accepting the e-on EULA and evaluating the library on 30 September 2026. No trees will be modelled from scratch. Exporting an existing publisher preset at its provided realtime/LOD settings is asset conversion, and still requires Godot rendering and performance validation.

Bentley permits embedding exported plants in commercial games while prohibiting sale of PlantCatalog-derived models as standalone assets. Its native Apple Silicon 2024 build is supplied as an unfinished beta; the older 2023 build uses Rosetta. [Official product/download and license FAQ](https://www.bentley.com/products/e-on-software/), [EULA](https://www.bentley.com/link/efb8b569396041b28dec5a40b8a000c4.aspx).

The new lead came from a [Godot community discussion about realistic optimized trees](https://www.reddit.com/r/godot/comments/1vuns8f/where_do_i_get_realistic_optimized_tree_models/), then was verified against Bentley's own offering. This is not evidence that Crate uses it.

## What Crate documents

Farthest Frontier uses Unity: Crate explicitly discusses a Unity upgrade in its [v0.8.1 patch notes](https://forums.crateentertainment.com/t/farthest-frontier-v0-8-1-v0-8-1a/124931).

Crate's artist describes historical references, concept sketches, 3D modelling, UV work, photographs combined with hand painting, normal/specular/glow/snow maps, ground decals and small plants around structures. This explains how its buildings and ground dressing are produced; it does not identify a tree generator. [Journey Log #08](https://forums.crateentertainment.com/t/journey-log-08-how-the-art-is-made/115296).

Map type and seed determine the initial terrain/resource layout; subsequent events have separate randomness. [Official world-generation guide](https://www.farthestfrontier.com/guide/game-settings/world-gen/).

The publisher describes villagers carrying goods between remote work sites, processing, homes and stores, alongside roads and wagons. [Official Steam description](https://store.steampowered.com/app/1044720/Farthest_Frontier/).

The sources reviewed do not establish Crate's tree supplier, exact scattering algorithm, tree polygon budgets, internal LOD implementation or camera projection. Do not claim that it uses SpeedTree, ProtonScatter or an orthographic camera without further evidence. Its engine choice does not require GOPALA to change engines.

## Visual observations and their implications

These are observations of the [official media gallery](https://www.farthestfrontier.com/media/), including its early-town and larger-town images, rather than claims about source code.

- Tree crowns have branch/leaf detail and irregular silhouettes. Use a new model family with believable trunks, bark and cutout foliage; a different colour on the same MegaKit mesh is not a replacement.
- Woods transition into open clearings through saplings, shrubs, grasses, rocks and scattered mature trees. Distribute several vegetation layers, rather than covering every hill with identical mature trees.
- Houses, people, trees and roads read together in a local settlement view. Establish one metre scale and review assets beside a house/villager scale fixture before scattering widely.
- Ground contains variations in meadow, exposed soil, worn paths and forest litter. Better trees alone will not reproduce this look on the current mostly uniform terrain material.
- Winter images have bare broadleaf branches and snow, while conifers retain their structure. Seasonal appearance requires compatible model/material variants; tinting a green crown white is insufficient.

These are transferable presentation principles. GOPALA's architecture, species and historical claims still need its own Nepal-specific research.

## Model/library comparison

Prices are displayed USD before tax when checked; sales and terms may change. No purchase has been made.

| Candidate | Verified offering | Assessment for this brief | Admission work |
|---|---|---|---|
| [Bentley PlantFactory / PlantCatalog](https://www.bentley.com/products/e-on-software/) | Free perpetual software and authored plant library; native Mac ARM exporter; commercial game embedding allowed, standalone PlantCatalog model sales prohibited. | Leading free pipeline under evaluation following the user's EULA authorization. Authored presets and realtime LODs must be inspected. | Export existing library plants; preserve species/preset/seed/LOD, textures and source receipts. Evaluate beta compatibility before selecting it for production. |
| [Nature Manufacture Forest Environment](https://naturemanufacture.com/forest-environment-set/) | Photoscanned forest foliage and prepared LODs; Unity/Unreal editions. [Unity listing](https://marketplace.unity.com/packages/3d/vegetation/forest-environment-dynamic-nature-150668) displayed $30 sale / $60 regular, 3.4 GB. | Paid visual benchmark, excluded by the free-only constraint. Publisher screenshots support the visual direction; local Godot appearance and performance remain untested. | Inspect the acquired meshes, texture sets, LODs and third-party notices. Recreate eligible materials/wind in Godot; engine shaders are not drop-in. Keep restricted raw assets outside public source distribution. |
| [Nature Manufacture Mountain Environment](https://naturemanufacture.com/mountain-environment-set/) | Photoscanned mountain/forest library; optimized assets, tree cross LODs. | Candidate for mountainous conifer environments. A supplement, not a reason to buy two packs immediately. | Confirm model/species roster, price and portable source files before purchase. |
| [SpeedTree](https://unity.com/products/speedtree) | Procedural modeler, authored vegetation library and export pipeline. Indie $19/month; separately listed library subscription $999/year. | Premium species/season/LOD workflow. More expensive and more integration work than a ready asset pack. Modeler access does not imply the full library is included. | Select externally authored library assets; confirm intended engine/export/license. Import meshes and implement Godot materials/animation. Do not assume native Godot SpeedTree runtime support. |
| [Daemoniumrex Trees Pack Vol. 1](https://daemoniumrex.itch.io/trees-pack-vol-1) | $1.99; ten trees, author-stated LODs around 3,000 / 1,000 / 200–300 triangles, 1K bark/leaf textures; universal archive. Royalty-free use, no standalone redistribution. | Low-cost comparison candidate with useful stated budgets. Not enough evidence to call its visual quality the best. | Inspect the archive license, complete mesh/materials and top-down silhouette. Verify author-stated triangle counts locally. |
| [Poly Haven trees](https://polyhaven.com/models/nature/trees) | CC0, realistic models, some with LODs. [Tree Small 02](https://polyhaven.com/a/tree_small_02) lists 5M triangles for its high-detail asset. | Strong free visual reference, but high-detail downloads are not automatically suitable for mass forests. | Inspect provided lower LODs and leaf representation. Do not scatter the cinematic mesh or assume automatic decimation makes it game-ready. |
| [loafbrr Foliage_1](https://loafbrr.itch.io/foliage-1) | CC0; glTF/FBX/Blender archive, 2K textures, author-stated 7,134 total triangles. | Genuinely different free models, but publisher previews show rounded stylized crowns; rejected as the main Farthest Frontier match. | Useful only for an explicitly different art direction. |
| MegaKit / KayKit / Kenney Nature | Stylized asset families, with verified public-domain offerings in the earlier research. | Their simple/cartoon silhouettes are not the selected direction. Do not keep cycling through these as a quality upgrade. | Retain only as diagnostics where useful; do not present them as final replacement trees. |

Unity explicitly permits eligible Asset Store assets in other engines subject to the applicable terms and accompanying component licenses. This does not make Unity shaders compatible with Godot, nor permit publishing raw purchased assets. [Unity's cross-engine guidance](https://support.unity.com/hc/en-us/articles/34387186019988-Can-I-use-assets-from-the-Asset-Store-with-other-engines).

## What changes in GOPALA

The current geographic scene represents a 40 km square at 100 metres per Godot unit. Its logical cell is 20 metres, and its displayed ground mesh has approximately 78-metre vertex spacing. Terrain relief is exaggerated by 3; that exaggeration must not stretch trees. These values come from the local implementation, not Farthest Frontier.

A 24-metre tree is 0.24 Godot units. A 1.7-metre person would be 0.017 units. Showing most of the 40 km region will make both tiny regardless of asset quality. Our detailed settlement view should cover hundreds of metres, with regional views using cheaper distant representations. More detailed local ground can add artistic surface dressing, but the source elevation cannot establish centimetre-scale surveyed features.

| Layer | Proposed Godot approach | Acceptance evidence |
|---|---|---|
| Scale and camera | Physical metre scale; uniform imported-model sizing; adjustable management camera centred on a roughly 300–800 m local view. Preserve regional navigation. | New tree, a scale fixture for a dwelling, and a 1.7 m person visible together; roots meet the displayed ground. No relief multiplier applied to tree geometry. |
| Trees | Import a genuinely new library, with complete bark/foliage materials and source LODs. Choose several mature forms plus saplings/dead trees. | Source hashes differ from old models; branches and crown shapes are legible at gameplay zoom and from above. No procedural canopy fallback. |
| Forest placement | Retain ProtonScatter as the placement tool if its checks pass. Use seeded patches, species groups, crown-aware spacing, gaps and explicit water/road/building exclusions. | Stable placements, natural grove boundaries and open work areas. Density and species masks are design data, not claims of surveyed ancient vegetation. |
| Rendering | Spatially divided MultiMesh batches and imported mesh LOD. Consider authored distant impostors after testing their top-down views. | Draw calls, frame times, memory and transitions measured at close/management/regional views. No whole-map MultiMesh. |
| Materials and ground | Bark normals; cutout leaves; restrained backlighting; subtle wind. Meadow/soil/litter/rock masks and local undergrowth. | Matching colour/lighting across assets; no opaque foliage rectangles or shimmering canopy. Godot Compatibility needs its own material solution for features unsupported there. |
| Seasons | Compatible leafless variants and snow masks; simulation owns seasonal state. | Broadleaf/conifer behaviour remains distinct; appearance never changes resource counts. |
| Timber gameplay | Stable tree records containing model/species reference, position, growth and remaining timber; rendering observes those records. | Harvest orders select a real source; workers cut and haul finite logs; depletion/regrowth and saves are deterministic. Decorative scatter is not an inventory. |

Godot automatically generates imported mesh LOD and supports it on MultiMesh; each batch shares its LOD selection and culling boundary, which is why spatial splitting matters. [Godot mesh LOD documentation](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html). Artist-authored LOD/impostor representations can use [visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html). Judge these from the tilted management camera, not only at eye level: the [community top-down LOD discussion](https://www.reddit.com/r/godot/comments/1toxqo5/my_tree_lods_look_fine_until_you_look_at_them/) highlights the need to inspect crown coverage.

## Build order and completion boundary

1. Acquire and inspect one new realistic tree family. Compare three trees at the intended camera angle beside scale fixtures, a river bank, and dressed ground. Reject it if the geometry/materials do not improve the current view.
2. Integrate its complete materials, authored LODs and source receipts; record conversion separately from source geometry. No hand-built tree modelling.
3. Scatter a small local forest with mature trees, saplings, shrubs and meadow gaps. Check ground contact and slope/water exclusions. Measure GPU frame times before expanding coverage.
4. Extend to chunked regional representations. Check camera transitions and canopy appearance from above.
5. Follow the existing backlog for real construction/logistics: stockpile and dwelling placement, entrances/routes, worker reservations, physical harvesting and delivery, then persistence. Matching Farthest Frontier's appearance does not complete those systems.

Current status: free-only research produced a new candidate and the authorized official PlantFactory download is in progress. Godot conversion and visual acceptance remain outstanding. The current MegaKit bake is not the accepted new tree library. No Farthest Frontier asset extraction, engine switch or paid purchase is part of this research result.

## Direct asset inspection: Poly Haven glTF exports

The official 1K glTF descriptors were downloaded from the linked Poly Haven APIs and inspected before fetching geometry. They contain only LOD0 nodes, despite the publisher pages tagging the assets as having LODs. Lower source LODs would need to be examined in the native Blender files.

| Source | Actual glTF triangle counts by mesh | Referenced geometry buffer |
|---|---|---|
| Pine Tree 01 | 6,951,524 / 4,234,432 / 5,996,296 | 948,849,556 bytes |
| Fir Tree 01 | 4,176,819 / 2,300,624 / 505,494 | 478,462,204 bytes |
| Tree Small 02 | 2,062,487 | 95,102,324 bytes |

These direct exports are unsuitable as the default mass-forest mesh. No cinematic LOD0 geometry has been admitted into GOPALA. Descriptor/API evidence is retained in `.tools/research/free-trees/`; counts are computed from indexed triangle accessor counts, rather than the website's aggregate display.
