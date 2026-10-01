import urllib.request
import urllib.parse
import json
import time

places = [
    "Kathmandu Metropolitan City, Nepal",
    "Lalitpur Metropolitan City, Nepal",
    "Bhaktapur Municipality, Nepal",
    "Kirtipur Municipality, Nepal"
]

results = []

for place in places:
    url = f"https://nominatim.openstreetmap.org/search?q={urllib.parse.quote(place)}&format=json&polygon_geojson=1&limit=1"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode('utf-8'))
            if data:
                best_match = data[0]
                name = place.split(",")[0].replace(" Metropolitan City", "").replace(" Municipality", "")
                
                # Use historic names
                if name == "Kathmandu": name = "Kantipur"
                if name == "Lalitpur": name = "Yala"
                if name == "Bhaktapur": name = "Khwopa"
                if name == "Kirtipur": name = "Kipoo"
                
                lat = float(best_match['lat'])
                lon = float(best_match['lon'])
                geojson = best_match.get('geojson', None)
                
                results.append({
                    "name": name,
                    "lat": lat,
                    "lon": lon,
                    "geojson": geojson
                })
                print(f"Fetched polygon for {name}")
            else:
                print(f"Not found: {place}")
    except Exception as e:
        print(f"Error for {place}: {e}")
    time.sleep(1.5)

with open("city_polygons.json", "w") as f:
    json.dump(results, f)
