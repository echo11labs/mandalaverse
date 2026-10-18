# Resources survey — 2026-10-08

Read-only survey for Devendra's asset replacement request. No new models have been admitted and no scenes changed. Exact replacement map was sent to the coordinator on G1-11, as that task requires an answer before scene edits. G1-11 also depends on G1-12 approval.

## Library inventory

| Download | Contents | Decision |
|---|---|---|
| KayKit Forest Nature | 105 unique meshes in several formats; included CC0 licence | Select trees, bushes, grass and stones |
| Styloo animals | 7 animals, GLB and FBX; publisher CC0 | Select animated cow; other animals lack gameplay support |
| Highlands Fantasy Buildings | 17 FBX meshes; publisher CC0; original 4096px textures | Select hut/crate/barrel; propose fence/axe; reduce maps to 1024px and remove UCX meshes |
| Craftpix medieval people | 28 FBX files | Local-only per project catalogue; keep current Kenney workers |
| Craftpix medieval houses | 131 FBX files | Local-only per project catalogue; exclude from public source |
| Forest Scene | Unity project, library/cache and third-party assets | Exclude; no blanket redistribution licence for its contents |
| Vegetation | One FBX, 130 PNGs, one JPG | No licence/source evidence; exclude |
| tools_mekmeesk | 33 meshes in one GLB | No licence/source evidence; exclude |
| Everything Library Animals 002 | One FBX labelled001 and one blend labelled002 | Volume mismatch; verify exact licence before admission |

## Proposed replacements

| Current | Candidate | Candidate triangles | Texture dimensions | Purpose |
|---|---|---:|---|---|
| Original box cattle | Styloo Cow | 4740 | Three 1024×1024 maps | Recognizable cattle, idle/walk driven by existing herd state |
| Timber-source Pine_Open_A (5355tri) | KayKit Tree_2_A | 336 | Shared 1024×1024 atlas | Clear conifer silhouette, lower geometry |
| Regional/hero conifers | KayKit Tree_2_A/B | 336/492 | Same atlas | Preserve seed, population, metre sizing and culling |
| Regional/hero broadleaf | KayKit Tree_1_A/B, Tree_3_A/B, Tree_4_A/B | 530/636,978/988,404/522 | Same atlas | Cohesive stylized forest; regenerate bake receipt |
| Existing bush detail | KayKit Bush_1_A / Bush_2_A | 72/44 | Same atlas | Readable foliage at game camera |
| Existing grass detail | KayKit Grass_1_A | 44 | Same atlas | Replace existing scatter without adding density |
| Small/large stones (98/264tri) | KayKit Rock_1_A / Rock_3_A | 48/84 | Same atlas | Preserve stone sizes, picking and depletion |
| Completed dwelling/gatherer shelter | Highlands Hut | 780, excluding20 UCX | Source4096 →1024 | Provisional European-fantasy kitbash; not final Newari art |
| Storage/timber-camp box (124tri) | Highlands WoodCrate | 456, excluding12 UCX | Source4096 →1024 | More visible storage detail; retain current if performance/readability loses |
| Water barrel (412tri) | Highlands Barrel | 968, excluding24 UCX | Source4096 →1024 | Water facility detail; same acceptance fallback |
| Cattle shelter boundary (optional) | Highlands WoodFence | 90, excluding12 UCX | Source4096 →1024 | Distinguish existing shelter; no new simulation fencing |
| Timber-camp prop (optional) | Highlands Axe | 110 | Source4096 →1024 | Small visual prop; no new resource or role |

Reject large European towers, town centre, windmill, shield and unsupported animals/crops. Retain open construction frames and functional open shelters where a closed hut would reduce readability. Retain current Kenney worker (72 unique-mesh triangles,1024px atlas,existing animation set) because there is no redistributable replacement person in these downloads.

Measurements in [resource-survey.json](../../reports/assets/resource-survey.json) cover129 candidate models and113 current model files. glTF counts are unique indexed mesh triangles, not a rendered instance total. FBX counts triangulate polygons and separate UCX collision geometry. They do not prove import, skinning, material appearance or runtime performance. Mesh bounds including child transforms will be normalized to the existing metre standard with bottom-centre ground anchors after admission; new prop categories need profiles and scale-audit checks.

Publisher sources checked: [Styloo animals](https://styloo.itch.io/animals), [Highlands](https://visionsmind.itch.io/highlands-fantasy-pack-3d), [Craftpix licence](https://craftpix.net/file-licenses/), [Everything Library Volume01](https://davidoreilly.itch.io/everything-library-animals). KayKit licence is included in the local archive. Exact-volume rights for002 are not established by the Volume01 page.

## Suggestions

Prioritize nature and animated cattle, preserve efficient workers, and compare identical40-settler cameras at both resolutions. Record selected source hashes, conversion steps, licences and credits; admit no whole packs. Snapshot/copy simulation overhead needs a separate performance task: replacing meshes alone cannot establish a passing fixed-tick budget.
