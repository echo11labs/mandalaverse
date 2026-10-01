import urllib.request
import urllib.parse
import json
import time

places = [
    "Taudaha, Kathmandu, Nepal",
    "Rani Pokhari, Kathmandu, Nepal",
    "Siddha Pokhari, Bhaktapur, Nepal",
    "Nagdaha, Lalitpur, Nepal",
    "Kamal Pokhari, Kathmandu, Nepal",
    "Gahana Pokhari, Kathmandu, Nepal",
    "Naag Pokhari, Kathmandu, Nepal",
    "Pimbahal Pokhari, Lalitpur, Nepal",
    "Bhajya Pukhu, Bhaktapur, Nepal",
    "Na Pukhu, Bhaktapur, Nepal",
    "Kamal Binayak, Bhaktapur, Nepal"
]

results = []

for place in places:
    url = f"https://nominatim.openstreetmap.org/search?q={urllib.parse.quote(place)}&format=json&polygon_geojson=1"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode('utf-8'))
            if data:
                name = place.split(",")[0]
                # Try to find a polygon or multipolygon representing the water body
                best_match = data[0]
                for match in data:
                    if 'geojson' in match and match['geojson']['type'] in ['Polygon', 'MultiPolygon']:
                        best_match = match
                        break
                
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
    time.sleep(1.5) # respect rate limit

with open("nominatim_polygons.json", "w") as f:
    json.dump(results, f)
