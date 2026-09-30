"""Check geographic vertices against raw OSM coordinates, not a copied rendering."""
from pathlib import Path
import json
import math
import numpy as np
from rasterio.warp import transform
ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"game/data/geography"
r=json.loads((DATA/"kathmandu.json").read_text())
raw=json.loads((DATA/"osm-kathmandu-waterways.geojson").read_text())
by_id={}
for f in raw["features"]:
    by_id.setdefault(f["properties"]["id"],set()).update(tuple(round(v,7) for v in p[:2]) for p in f["geometry"]["coordinates"])
checks=0
failures=[]
maximum=0.0
cx,cy=r["utm_center"]
for reach in r["rivers"]:
    points=reach["points"]
    lon,lat=transform(r["utm_crs"],"EPSG:4326",[cx+p[0]*100 for p in points],[cy-p[2]*100 for p in points])
    for x,y in zip(lon,lat):
        checks+=1
        if (round(x,7),round(y,7)) not in by_id[reach["id"]]: failures.append("Horizontal vertex drift: "+reach["id"])
    expected=by_id[reach["id"]]
    ex,ey=transform("EPSG:4326",r["utm_crs"],[p[0] for p in expected],[p[1] for p in expected])
    projected=dict(zip(expected,zip(ex,ey)))
    for p,x,y in zip(points,lon,lat):
        a,b=projected[(round(x,7),round(y,7))]
        maximum=max(maximum,math.hypot(a-(cx+p[0]*100),b-(cy-p[2]*100)))
checks+=1
if maximum>0.001: failures.append("More than 1 mm conversion/serialization drift")
source=np.fromfile(DATA/"kathmandu-source-height.f32",dtype="<f4")
checks+=1
if len(source)!=1025**2 or not np.isfinite(source).all(): failures.append("Incomplete/nonfinite elevation array")
report={"ok":not failures,"checks":checks,"failures":failures,"maximum_horizontal_serialization_drift_m":maximum,
        "scope":"Projection/serialization agreement only; not absolute OSM or DEM survey accuracy"}
(ROOT/"reports/kathmandu-coordinate-verification.json").write_text(json.dumps(report,indent=2)+"\n")
print("GOPALA_TEST_REPORT="+json.dumps(report))
raise SystemExit(0 if report["ok"] else 1)
