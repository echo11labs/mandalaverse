"""Rebuild the explicitly authored P0 starter definitions (prototype balance)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "game"
GOODS = ["timber", "stone", "thatch", "water", "wild_food", "fodder", "milk"]
BUILDINGS = {
    "dwelling": {"timber": 8, "thatch": 6, "stone": 2},
    "stockpile": {"timber": 4},
    "timber_camp": {"timber": 6, "thatch": 3},
    "gatherer_shelter": {"timber": 4, "thatch": 4},
    "water_point": {"timber": 3, "stone": 3},
    "cattle_shelter": {"timber": 8, "thatch": 8},
}


def write(path, text):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


def main():
    catalog = {"schema_version": 1, "balance_status": "prototype", "resources": [], "buildings": [], "zones": []}
    for key in GOODS:
        path = f"data/resources/{key}.tres"
        write(path, f'''[gd_resource type="Resource" script_class="GopalaResourceDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://core/content/resource_definition.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/prototype/good_{key}.png" id="2"]

[resource]
script = ExtResource("1")
id = &"{key}"
display_name = "{key.replace('_', ' ').title()}"
icon = ExtResource("2")
carry_units = 5
''')
        catalog["resources"].append("res://" + path)
    for key, costs in BUILDINGS.items():
        path = f"data/buildings/{key}.tres"
        cost_literal = ", ".join(f'&"{k}": {v}' for k, v in costs.items())
        write(path, f'''[gd_resource type="Resource" script_class="GopalaBuildingDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://core/content/building_definition.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/prototype/building_{key}.png" id="2"]

[resource]
script = ExtResource("1")
id = &"{key}"
display_name = "{key.replace('_', ' ').title()}"
footprint = Vector2i(2, 2)
entrance = Vector2i(0, 2)
costs = Dictionary[StringName, int]({{{cost_literal}}})
work_ticks = 100
prototype_sprite = ExtResource("2")
''')
        catalog["buildings"].append("res://" + path)
    write("data/zones/pasture.tres", '''[gd_resource type="Resource" script_class="GopalaZoneDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://core/content/zone_definition.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"pasture"
display_name = "Pasture"
minimum_cells = 4
''')
    catalog["zones"].append("res://data/zones/pasture.tres")
    write("data/catalog.json", json.dumps(catalog, indent=2) + "\n")
    print("Created 7 goods, 6 buildings and 1 pasture definition. Balance is provisional.")


if __name__ == "__main__":
    main()

