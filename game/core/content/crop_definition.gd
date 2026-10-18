@tool
class_name GopalaCropDefinition
extends Resource
## Immutable crop recipe; growth and harvest state lives on a field zone.

@export var id: StringName
@export var display_name: String
@export var harvest_resource: StringName
@export_range(1, 1000000) var growth_ticks: int = 1200
@export_range(1, 100) var yield_amount: int = 6
@export_range(0.0, 1.0) var minimum_fertility: float = 0.2
@export_range(0.0, 1.0) var minimum_moisture: float = 0.15
@export_range(1, 1000) var work_ticks: int = 12
