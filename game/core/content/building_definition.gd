@tool
class_name GopalaBuildingDefinition
extends Resource
## Authored construction specification in logical grid cells.

@export var id: StringName
@export var display_name: String
@export var footprint: Vector2i = Vector2i(2, 2)
@export var entrance: Vector2i = Vector2i(0, 2)
@export var costs: Dictionary[StringName, int] = {}
@export_range(1, 100000) var work_ticks: int = 100
@export var inventory_limits: Dictionary[StringName, int] = {}
@export_range(0, 100) var home_capacity: int = 0
@export var prototype_sprite: Texture2D
