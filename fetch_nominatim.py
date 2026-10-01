import urllib.request
import urllib.parse
import json
import time

places = [
    "Kamal Pokhari, Kathmandu, Nepal",
    "Gahana Pokhari, Kathmandu, Nepal",
    "Naag Pokhari, Kathmandu, Nepal",
    "Pimbahal Pokhari, Lalitpur, Nepal",
    "Bhajya Pukhu, Bhaktapur, Nepal",
    "Na Pukhu, Bhaktapur, Nepal",
    "Kamal Binayak, Bhaktapur, Nepal",
    "Godawari Kunda, Lalitpur, Nepal",
    "Indra Daha, Kathmandu, Nepal"
]

results = []

for place in places:
    url = f"https://nominatim.openstreetmap.org/search?q={urllib.parse.quote(place)}&format=json"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'})
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode('utf-8'))
            if data:
                name = place.split(",")[0]
                lat = float(data[0]['lat'])
                lon = float(data[0]['lon'])
                results.append({"name": name, "lat": lat, "lon": lon})
                print(f"Found {name}: {lat}, {lon}")
            else:
                print(f"Not found: {place}")
    except Exception as e:
        print(f"Error for {place}: {e}")
    time.sleep(1.5) # respect rate limit

with open("nominatim_lakes.json", "w") as f:
    json.dump(results, f, indent=2)
