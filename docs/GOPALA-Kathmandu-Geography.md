# GOPALA — Kathmandu geography and historical interpretation

Updated 29 September 2026. The main scene is now `game/scenes/landscape/kathmandu_valley.tscn`. This replaces the invented sine-wave valley as the default landscape. Earlier scenes remain diagnostic references.

## Geographic base

The scene covers a 40 × 40 km square centered near 27.695°N, 85.375°E, including the valley bowl, surrounding ridges and some neighboring drainage context. This rectangle is not a delineated Kathmandu watershed boundary. Positions use WGS84 / UTM zone 45N (EPSG:32645), with one Godot unit representing 100 metres east–west/north–south. North is toward negative Z.

Elevation comes from public Copernicus GLO-30, tile N27/E085. The original product is a digital **surface** model, including vegetation, infrastructure and buildings. Its nominal resolution is one arc-second, approximately 30 m. It is reprojected into 1,025 × 1,025 samples at 39.0625 m spacing. The visible 512 × 512 triangle grid samples these at 78.125 m spacing. Numerical elevation inspection reads the source samples; displayed relief uses 3× vertical exaggeration, explicitly shown in the interface. This is not a surveyed bare-earth or exact ancient elevation model.

The supplied [topographic map](https://en-ca.topographic-map.com/map-fpf2kl/Kathmandu-Valley/) provides a visual reference. The pasted geology image mixes geological units and sediment-depth classes; those colours were not treated as surface heights. No image tracing or copied map tiles are used as gameplay terrain.

## Rivers and flow

The HOT/HDX Nepal OSM waterways export is dated 9 September 2026. The retained regional GeoJSON is available under ODbL in `game/data/geography/osm-kathmandu-waterways.geojson`. The native river layer includes 249 mapped river/stream reaches in the connected Bagmati component, with original way IDs and horizontal vertices preserved. It includes Bagmati, Bishnumati, Manohara, Hanumante, Dhobi Khola, Balkhu, Nakhu, Godawari, Kodku and other tributaries.

Mapped order is interpreted using OSM's downstream convention. The importer records DEM-based reversals where a reach has more than eight metres of net uphill rise. A reviewed Godawari side-channel reversal removes an 11-edge directed cycle. These changes do not alter horizontal routes. They are inferred direction repairs, not surveyed hydrology. The repair list is in `reports/kathmandu-import.json`.

Profiles are conditioned to avoid downstream rises and agree at shared graph nodes. Maximum profile lowering is approximately 41.75 m. A separate visual terrain layer uses a three-sample median filter and shallow channel dressing. Source elevations remain intact. Baked Waterways meshes are dressed onto the visible terrain, with animated downstream normals, shore foam and a Compatibility material. Mapped IDs and course endpoints are retained; covered/tunnel reaches stay hidden. These surfaces do not simulate discharge, seasonal volume, flooding or water-surface hydraulics. River widths are enlarged for visibility and are not measured bank widths. See [Waterways integration](GOPALA-Waterways.md) for the pinned addon, baked-asset receipt, source-query API and acceptance limits.

The network is incomplete: portions of Dhobi/Tukucha are disconnected from the retained component. Bagdwar is approximately 4.4 km from the closest retained connected-network vertex, though disconnected mapped streams exist closer. These are data gaps, not evidence that the real rivers stop there.

## Source evidence

| River | Source region supported by reports | Representation |
|---|---|---|
| Bagmati | Bagdwar, Shivapuri | Mapped landmark at 27.8108557°N, 85.3907821°E; OSM node 8307928519. This is a mapped attraction/landmark, not a GNSS survey of the spring. |
| Bishnumati | Bishnudwar, Shivapuri | Source region known; exact point not admitted. |
| Dhobi Khola / Rudramati | Shivapuri watershed | Mapped lower/connected reaches; exact source point pending. |
| Manohara | Manichaur/Manichud watershed | Mapped course; headwater extent remains subject to review. |
| Hanumante | Eastern Mahadev hills | Mapped westward tributary to Manohara. |
| Godawari | Phulchowki area | Mapped northward tributary system. |
| Kodku | Southern hills | Mapped course; exact spring location pending. |
| Nakhu | Southern Bhardeu watershed | Mapped northward drainage toward Bagmati. |
| Balkhu | Western watershed | Mapped eastern drainage into Bagmati. |

Source regions and relationships are checked against the [Government of Nepal / NTNC Bagmati Action Plan](https://literature.wolkersdorfer.info/literature/Bagmati%20Action%20Plan.pdf) and [Government/UN-Habitat information-base report](https://un.info.np/Net/NeoDocs/View/6328). The [Gokarneshwor municipality account](https://info.gokarneshwormun.gov.np/tourist-places/2) independently identifies Bagdwar. Approximate ridge/outlet labels provide orientation; they are not surveyed summit or gorge markers.

The amber dashed headwater is an **unsurveyed estimate**. It connects the mapped Bagdwar landmark to the first named Bagmati reach using a DEM least-cost corridor with an uphill penalty. It is stored separately as `metadata.reconstruction`, not relabeled as mapped OSM data. Its route needs field-quality hydrography before any claim of exactness.

## Ancient interpretation

The user prefers reconstruction where evidence supports it. The scene therefore presents a landscape without imported contemporary roads or buildings, retaining measured regional landforms and river geography as proxies. Elevation-based greens are an art treatment, not a paleovegetation or modern land-cover survey.

[Saijo and Kimura's lake study](https://www.nepjol.info/index.php/HJS/article/view/981) concerns a much older Late Pleistocene lake and drainage through the Bagmati outlet. It does not establish exact river meanders for a Gopala settlement date. A full-basin lake, relocated rivers, levees or recovered ancient channel beds have not been invented. A specific settlement date and georeferenced ancient-channel evidence are still needed for a tighter historical reconstruction.

## Interaction and acceptance

Run `python3 tools/godot.py` or open `game/project.godot`. The orthographic camera starts at 45° yaw and 55° down, with a 200-metre vertical span centred on the local resource area. Camera distance scales with the view instead of remaining 52 km away. Pan with middle-drag, WASD or arrows; Shift speeds keyboard panning up. Shift + middle-drag turns and tilts. Q/E turn unless construction placement is active. Wheel, −/+, view buttons and trackpad pinch zoom; wheel/pinch zoom eases towards the point under the cursor and preserves chosen tilt. Trackpad pan moves the ground. Home resets orientation and returns to the resource area. Right-click remains a villager order. Press Build for structure groups, G for the local planning grid, and click terrain or a river to inspect.

The camera pivot follows terrain height during movement. The map boundary accounts for viewport aspect, yaw and tilt. Camera picking uses a dedicated ground collision layer, so zoom does not anchor on a tree canopy or villager. Scenery chunk bounds merge all transformed mesh bounds, including crowns across tile edges, with a small wind allowance. Orthographic chunks use frustum culling without a distance cutoff. Near clipping is 5 cm; far clipping follows camera distance plus regional relief allowance. These are camera and visibility changes, not a measured performance result.

The local planning area is 48 × 48 cells of 20 m, covering 960 × 960 m. It is a preliminary local prototype. Its grid shares the visible triangle surface; suitability excludes river-adjacent ground and slopes exceeding twelve degrees, calculated without the 3× display exaggeration. These coarse elevation samples do not establish building-scale survey accuracy. Detailed terrain, banks, vegetation and village placement remain subsequent work.

`python3 tools/verify.py` includes source checksums, sample validity, major rivers, non-rising conditioned profiles, explicit reconstruction qualification, source-marker position, model/mesh agreement, local cell conversion and physics picking at three zoom scales. Coordinate checks independently transform all mapped vertices back to geographic coordinates and compare them to the retained raw GeoJSON. Actual graphics captures are `reports/kathmandu-overview.png` and `reports/kathmandu-source.png`.

## Reproduction and rights

Install `tools/requirements-geography.txt` into the project-local Python environment, fetch the elevation tile recorded in `game/data/geography/source-receipt.json` to `.tools/geography/copernicus_N27_E085.tif`, retain the regional GeoJSON and versioned bagdwar-source.json gazetteer input, then run `.tools/python/bin/python tools/import_kathmandu.py`. Raw country/elevation download caches were removed after processing to conserve space; source URLs and SHA-256 receipts remain.

Derived OSM river data stays under ODbL. Elevation samples retain the separate Copernicus licence. See `game/data/geography/ATTRIBUTION.md`. The asset PNG manifest continues to cover raster prototypes; it does not certify this geographic data as final art or historical fact.
