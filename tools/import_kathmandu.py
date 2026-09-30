"""Offline, reproducible Copernicus/OSM import; never invent geographic routes."""
from pathlib import Path
import collections
import hashlib
import json
import math
import heapq
import numpy as np
import rasterio
from rasterio.warp import reproject, transform, Resampling
from rasterio.transform import from_origin
from scipy.ndimage import median_filter, distance_transform_edt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/data/geography"
CACHE = ROOT / ".tools/geography"
N = 1025
SPAN = 40000.0
SCALE = 100.0
BASE = 1200.0
CX, CY = transform("EPSG:4326", "EPSG:32645", [85.375], [27.695])
CX, CY = CX[0], CY[0]
STEP = SPAN / (N - 1)
# Raw coordinates show this braid ordered against the northward Godawari trunk.
# Reversing it removes an 11-edge cycle. Preserve source GeoJSON unchanged.
FLOW_DIRECTION_REVIEW = {"way/342105339": "Reverse side channel against northward Godawari trunk; removes directed cycle"}


def world(lon, lat):
    x, y = transform("EPSG:4326", "EPSG:32645", [lon], [lat])
    return ((x[0] - CX) / SCALE, (CY - y[0]) / SCALE)


def sample(grid, x, z):
    col = np.clip((np.asarray(x) * SCALE + SPAN / 2) / STEP, 0, N - 1)
    row = np.clip((np.asarray(z) * SCALE + SPAN / 2) / STEP, 0, N - 1)
    c0, r0 = col.astype(int), row.astype(int)
    c1, r1 = np.minimum(c0 + 1, N - 1), np.minimum(r0 + 1, N - 1)
    a, b = col - c0, row - r0
    return (grid[r0, c0] * (1-a) + grid[r0, c1] * a) * (1-b) + (grid[r1, c0] * (1-a) + grid[r1, c1] * a) * b


def river_name(properties):
    name = properties.get("name_en") or properties.get("name") or ""
    low = name.lower()
    for key, label in [("bagmati", "Bagmati"), ("bishnumati", "Bishnumati"), ("manohara", "Manohara"), ("hanumante", "Hanumante"), ("rudramati", "Dhobi Khola"), ("dhobu", "Dhobi Khola"), ("balkhu", "Balkhu"), ("nakhhu", "Nakhu"), ("nakhu", "Nakhu"), ("godawari", "Godawari"), ("kodku", "Kodku"), ("karmanasha", "Kodku"), ("icchumati", "Tukucha"), ("tukucha", "Tukucha"), ("tukuchha", "Tukucha"), ("manamati", "Manamati")]:
        if key in low:
            return label
    return name or "Unnamed stream"


def reconstruct_headwater(dem, origin, target):
    # Least-cost downhill corridor at DEM sample resolution, explicitly inferred.
    sx, sz = world(*origin)
    tx, tz = target[0], target[2]
    start = (round((sz*SCALE+SPAN/2)/STEP), round((sx*SCALE+SPAN/2)/STEP))
    end = (round((tz*SCALE+SPAN/2)/STEP), round((tx*SCALE+SPAN/2)/STEP))
    top, bottom = max(0,min(start[0],end[0])-40), min(N-1,max(start[0],end[0])+40)
    left, right = max(0,min(start[1],end[1])-40), min(N-1,max(start[1],end[1])+40)
    costs, parents, queue = {start:0.0}, {}, [(0.0,start)]
    while queue:
        cost, a = heapq.heappop(queue)
        if cost != costs[a]: continue
        if a == end: break
        for dr,dc in [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]:
            b = (a[0]+dr,a[1]+dc)
            if not (top<=b[0]<=bottom and left<=b[1]<=right): continue
            candidate = cost + STEP*math.hypot(dr,dc) + max(0,float(dem[b]-dem[a]))*30
            if candidate < costs.get(b,float('inf')):
                costs[b] = candidate
                parents[b] = a
                heapq.heappush(queue,(candidate,b))
    path, cursor = [end], end
    while cursor != start:
        cursor = parents[cursor]
        path.append(cursor)
    path.reverse()
    points, previous = [], float('inf')
    for row,col in path:
        x,z = (col*STEP-SPAN/2)/SCALE,(row*STEP-SPAN/2)/SCALE
        previous = min(previous,float(dem[row,col]))
        points.append([round(x,7),round((previous-BASE)/SCALE,7),round(z,7)])
    points[0][0],points[0][2] = sx,sz
    points[-1] = target
    return {"id":"derived/bagdwar-dem-corridor","name":"Bagdwar headwater estimate","kind":"reconstructed","points":points,
            "confidence":"Unsurveyed estimate; not an exact modern or ancient channel",
            "method":"DEM least-cost corridor, uphill penalty; connects mapped Bagdwar landmark to first named Bagmati reach"}


def main():
    dem_path = CACHE / "copernicus_N27_E085.tif"
    dem = np.zeros((N, N), dtype=np.float32)
    with rasterio.open(dem_path) as source:
        reproject(rasterio.band(source, 1), dem, src_transform=source.transform, src_crs=source.crs,
                  dst_transform=from_origin(CX - SPAN/2 - STEP/2, CY + SPAN/2 + STEP/2, STEP, STEP),
                  dst_crs="EPSG:32645", resampling=Resampling.bilinear)
    if not np.isfinite(dem).all() or dem.min() < 500:
        raise ValueError("Invalid or missing elevation coverage")
    # Source DSM remains intact. Median cleanup is a disclosed presentation layer.
    visual = median_filter(dem, size=3)
    source_data = json.loads((OUT / "osm-kathmandu-waterways.geojson").read_text())
    ways = []
    node_positions = {}
    adjacency = collections.defaultdict(set)
    edges = set()
    direction_review = dict(FLOW_DIRECTION_REVIEW)
    for feature in source_data["features"]:
        p = feature["properties"]
        if p.get("waterway") not in ("river", "stream"):
            continue
        coords = feature["geometry"]["coordinates"]
        xs, ys = transform("EPSG:4326", "EPSG:32645", [c[0] for c in coords], [c[1] for c in coords])
        pieces, current = [], []
        for ll, x, y in zip(coords, xs, ys):
            x, z = (x - CX) / SCALE, (CY - y) / SCALE
            if max(abs(x), abs(z)) > SPAN / SCALE / 2:
                if len(current) > 1:
                    pieces.append(current)
                current = []
                continue
            key = (round(ll[0], 7), round(ll[1], 7))
            node_positions[key] = (x, z)
            if not current or current[-1] != key:
                current.append(key)
        if len(current) > 1:
            pieces.append(current)
        for piece in pieces:
            if p["id"] in FLOW_DIRECTION_REVIEW:
                piece = list(reversed(piece))
            elif float(sample(visual,*node_positions[piece[-1]])) - float(sample(visual,*node_positions[piece[0]])) > 8:
                rise = float(sample(visual,*node_positions[piece[-1]])) - float(sample(visual,*node_positions[piece[0]]))
                direction_review[p["id"]] = "Reversed mapped order with %.1f m net uphill rise in source DEM" % rise
                piece = list(reversed(piece))
            ways.append({"id": p["id"], "name": river_name(p), "kind": p["waterway"], "nodes": piece,
                         "covered": p.get("covered"), "tunnel": p.get("tunnel"), "width_tag": p.get("width")})
            for a, b in zip(piece, piece[1:]):
                edges.add((a, b))
                adjacency[a].add(b)
                adjacency[b].add(a)
    # Connected-component filtering removes rivers on the far side of the rim.
    seed = next(w["nodes"][0] for w in ways if w["name"] == "Bagmati")
    basin, queue = {seed}, collections.deque([seed])
    while queue:
        for node in adjacency[queue.popleft()]:
            if node not in basin:
                basin.add(node)
                queue.append(node)
    basin_ways = [w for w in ways if w["nodes"][0] in basin]
    named_missing = sorted({w["name"] for w in ways if w["name"] in ["Bishnumati", "Manohara", "Hanumante", "Dhobi Khola", "Balkhu", "Nakhu", "Godawari", "Kodku", "Tukucha"] and w not in basin_ways})
    # Preserve OSM node order (downstream convention), explicitly audit its graph.
    basin_edges = {(a,b) for a,b in edges if a in basin and b in basin}
    downstream, indegree = collections.defaultdict(set), {node: 0 for node in basin}
    for a,b in basin_edges:
        downstream[a].add(b)
        indegree[b] += 1
    elevations = {node: float(sample(visual, *node_positions[node])) for node in basin}
    original = elevations.copy()
    queue = collections.deque(sorted(node for node in basin if indegree[node] == 0))
    visited = []
    while queue:
        a = queue.popleft()
        visited.append(a)
        for b in sorted(downstream[a]):
            elevations[b] = min(elevations[b], elevations[a])
            indegree[b] -= 1
            if indegree[b] == 0:
                queue.append(b)
    if len(visited) != len(basin):
        states, parents = {}, {}
        cycle = []
        for start in sorted(basin):
            if states.get(start): continue
            stack = [(start,iter(sorted(downstream[start])))]
            states[start] = 1
            while stack and not cycle:
                a,iterator = stack[-1]
                b = next(iterator,None)
                if b is None:
                    states[a] = 2
                    stack.pop()
                elif states.get(b,0) == 0:
                    parents[b] = a
                    states[b] = 1
                    stack.append((b,iter(sorted(downstream[b]))))
                elif states.get(b) == 1:
                    cycle = [(a,b)]
                    while a != b:
                        cycle.append((parents[a],a))
                        a = parents[a]
            if cycle: break
        print("Cycle segments:",cycle[:10],"count",len(cycle))
        for w in basin_ways:
            if any((a,b) in cycle for a,b in zip(w["nodes"],w["nodes"][1:])):
                print("Review way:",w["id"],w["name"],w["nodes"][:2],w["nodes"][-2:])
        print("Unprocessed nodes:",len(basin)-len(visited))
        raise ValueError("Mapped basin contains directed cycles; manual review needed")
    rivers, dense_points, dense_heights = [], [], []
    for way in basin_ways:
        points = [[round(node_positions[node][0], 7), round((elevations[node]-BASE)/SCALE, 7), round(node_positions[node][1], 7)] for node in way["nodes"]]
        rivers.append({k:v for k,v in way.items() if k != "nodes"} | {"points": points})
        for a,b in zip(points, points[1:]):
            distance = math.hypot(b[0]-a[0], b[2]-a[2]) * SCALE
            count = max(2, math.ceil(distance / 10))
            t = np.linspace(0, 1, count)
            dense_points.extend(zip(a[0]+t*(b[0]-a[0]), a[2]+t*(b[2]-a[2])))
            dense_heights.extend((a[1]+t*(b[1]-a[1]))*SCALE+BASE)
    bagdwar = json.loads((OUT/"bagdwar-source.json").read_text())[0]
    target_way = next(w for w in rivers if w["id"]=="way/591536939")
    reconstruction = reconstruct_headwater(visual,(float(bagdwar["lon"]),float(bagdwar["lat"])),target_way["points"][0])
    points = np.asarray(dense_points)
    rows = np.clip(np.rint((points[:,1]*SCALE+SPAN/2)/STEP).astype(int), 0, N-1)
    cols = np.clip(np.rint((points[:,0]*SCALE+SPAN/2)/STEP).astype(int), 0, N-1)
    channel = np.full((N,N), np.inf, dtype=np.float32)
    np.minimum.at(channel, (rows,cols), np.asarray(dense_heights))
    distance, nearest = distance_transform_edt(~np.isfinite(channel), sampling=STEP, return_indices=True)
    nearest_height = channel[nearest[0],nearest[1]]
    # A shallow channel dressing makes the mapped water visible through DSM noise.
    factor = np.clip(1-distance/90, 0, 1)
    target = np.minimum(visual, nearest_height-2)
    visual = visual*(1-factor)+target*factor
    for name, array in [("kathmandu-source-height.f32", dem), ("kathmandu-ground-height.f32", visual), ("kathmandu-river-distance.f32", distance)]:
        np.asarray(array, dtype="<f4").tofile(OUT/name)
    bagdwar = json.loads((OUT/"bagdwar-source.json").read_text())[0]
    bx,bz = world(float(bagdwar["lon"]), float(bagdwar["lat"]))
    bh = float(sample(dem,bx,bz))
    all_river_points = np.array([p for w in rivers for p in w["points"]])
    source_gap = float(np.min(np.linalg.norm(all_river_points[:,[0,2]]-np.array([bx,bz]),axis=1))*SCALE)
    # Fixed landmark coordinates are orientation references, not ancient locations.
    landmarks = []
    for name,lon,lat,kind in [("Bagdwar · Bagmati source",float(bagdwar["lon"]),float(bagdwar["lat"]),"mapped_source"),
                             ("Shivapuri",85.3846,27.8156,"ridge_reference"), ("Nagarjun",85.2690,27.7568,"ridge_reference"),
                             ("Chandragiri",85.2075,27.6618,"ridge_reference"), ("Phulchowki",85.4070,27.5712,"ridge_reference"),
                             ("Chobhar · drainage outlet",85.2940,27.6560,"outlet_reference")]:
        x,z=world(lon,lat)
        landmarks.append({"name":name,"lon":lon,"lat":lat,"position":[x,(float(sample(dem,x,z))-BASE)/SCALE,z],"kind":kind,
                          "coordinate_basis":"OSM node 8307928519" if kind=="mapped_source" else "Approximate orientation reference; not surveyed"})
    correction = max(original[n]-elevations[n] for n in basin)
    report = {"mapped_ways":len(ways),"bagmati_component_ways":len(rivers),"graph_nodes":len(basin),"graph_edges":len(basin_edges),
              "directed_cycles":0,"named_rivers":dict(collections.Counter(w["name"] for w in rivers if w["name"]!="Unnamed stream")),
              "disconnected_major_names":named_missing,"bagdwar_to_mapped_network_m":round(source_gap,2),
              "maximum_water_profile_lowering_m":round(correction,2),"source_elevation_range_m":[float(dem.min()),float(dem.max())],"flow_direction_repairs":direction_review}
    metadata={"schema":1,"grid_samples":N,"extent_m":SPAN,"metres_per_unit":SCALE,"base_elevation_m":BASE,
              "utm_crs":"EPSG:32645","utm_center":[CX,CY],"source_center_lonlat":[85.375,27.695],"sample_spacing_m":STEP,
              "source_dem_resolution":"1 arc-second (~30 m)","vertical_exaggeration":1.0,"history":"Evidence-aware pre-urban interpretation; modern channels are proxies, ancient meanders are unverified",
              "rivers":rivers,"reconstruction":[reconstruction],"landmarks":landmarks,"audit":report}
    (OUT/"kathmandu.json").write_text(json.dumps(metadata,ensure_ascii=False,separators=(",",":")))
    (ROOT/"reports/kathmandu-import.json").write_text(json.dumps(report,indent=2))
    receipts={"retrieved":"2026-09-29","osm_extract_date":"2026-09-09","osm_country_archive_sha256":"163476ee99c1b471bddce2c06214a10e11075013a92b2a1c6b0b5d5495ae6d6e",
              "dem_url":"https://copernicus-dem-30m.s3.amazonaws.com/Copernicus_DSM_COG_10_N27_00_E085_00_DEM/Copernicus_DSM_COG_10_N27_00_E085_00_DEM.tif",
              "dem_sha256":hashlib.sha256(dem_path.read_bytes()).hexdigest(),
              "osm_url":"https://production-raw-data-api.s3.amazonaws.com/ISO3/NPL/waterways/hotosm_npl_waterways_osm_geojson.zip",
              "files":{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.iterdir()) if p.suffix in (".f32",".json",".geojson") and p.name!="source-receipt.json"}}
    (OUT/"source-receipt.json").write_text(json.dumps(receipts,indent=2))
    print(json.dumps(report,indent=2))


if __name__=="__main__":
    main()
