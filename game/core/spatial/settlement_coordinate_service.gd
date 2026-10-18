class_name GopalaSettlementCoordinateService
extends Node
## Pure scene-owned spatial foundation for deterministic world/cell conversions.

var _config: GopalaSettlementGridConfig

func configure(config: GopalaSettlementGridConfig) -> bool:
	if _config != null:
		return false
	if config == null or not config.is_valid():
		return false
	_config = config
	return true

func is_configured() -> bool:
	return _config != null

func world_to_settlement_cell(world_xz: Vector2) -> Vector2i:
	if _config == null:
		return Vector2i()
	var relative = (world_xz - _config.origin_xz) / _config.world_units_per_cell
	var cell_x = floori(relative.x + 0.5)
	var cell_y = floori(relative.y + 0.5)
	return Vector2i(cell_x, cell_y)

func settlement_cell_to_world_xz(cell: Vector2i) -> Vector2:
	if _config == null:
		return Vector2()
	var center_offset = Vector2(cell.x, cell.y) * _config.world_units_per_cell
	return _config.origin_xz + center_offset

## Converts regional world coordinates. Explicitly unavailable adapter boundary.
## Does not duplicate regional-grid formulas to avoid coupling this pure service to Kathmandu terrain.
func regional_cell_from_world(_world_xz: Vector2) -> Vector2i:
	push_error("regional_cell_from_world is an unavailable adapter boundary in pure coordinate service.")
	return Vector2i()

func is_in_bounds(cell: Vector2i) -> bool:
	if _config == null:
		return false
	return _config.bounds.has_point(cell)

func cells_in_bounds(cells: Array[Vector2i]) -> bool:
	if _config == null:
		return false
	for cell in cells:
		if not _config.bounds.has_point(cell):
			return false
	return true

func config_snapshot() -> Dictionary:
	if _config == null:
		return {}
	return _config.snapshot()
