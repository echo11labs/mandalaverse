@tool
class_name GopalaZoneDefinition
extends Resource
## A designation covers existing land without creating a building obstacle.

@export var id: StringName
@export var display_name: String
@export_range(1, 1000) var minimum_cells: int = 4

