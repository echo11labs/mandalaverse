import urllib.request
import urllib.parse
import json
import time

# Kathmandu Valley Bounding Box
bbox = "27.55,85.20,27.85,85.55"

query = f"""
[out:json][timeout:25];
(
  node["natural"="water"]["name"]({bbox});
  way["natural"="water"]["name"]({bbox});
  relation["natural"="water"]["name"]({bbox});
  
  node["water"="pond"]["name"]({bbox});
  way["water"="pond"]["name"]({bbox});
  relation["water"="pond"]["name"]({bbox});
);
out center;
"""

url = "https://overpass.kumi.systems/api/interpreter"
data = urllib.parse.urlencode({'data': query}).encode('utf-8')

try:
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/110.0',
        'Accept': '*/*'
    }
    req = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.urlopen(req) as response:
        result = json.loads(response.read().decode('utf-8'))
        
        lakes = []
        for el in result.get('elements', []):
            tags = el.get('tags', {})
            name = tags.get('name:en', tags.get('name', 'Unknown')) # Prefer english name if available
            
            lat = el.get('center', el).get('lat')
            lon = el.get('center', el).get('lon')
            
            if lat and lon and name != 'Unknown':
                lakes.append({"name": name, "lat": lat, "lon": lon})
                
        unique_lakes = {}
        for l in lakes:
            key = (l['name'], round(l['lat'], 3), round(l['lon'], 3))
            if key not in unique_lakes:
                unique_lakes[key] = l
                
        output = list(unique_lakes.values())
        print(f"Found {len(output)} named water bodies.")
        with open('kathmandu_lakes.json', 'w') as f:
            json.dump(output, f, indent=2)
except Exception as e:
    print(f"Error: {e}")
