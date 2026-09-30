@tool
class_name GopalaResourceDefinition
extends Resource
## Immutable authored goods. Inventory quantities belong to simulation records.

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export_range(1, 100) var carry_units: int = 5

