class_name GopalaSettlementRouteService
extends Node
## Fixed-tick, four-neighbour navigation over the same cells used by occupancy.
var enabled := false
var revision := 0
var last_failure: StringName = &""
var _coordinates: GopalaSettlementCoordinateService
var _occupancy: GopalaSettlementOccupancyService
var _queries: GopalaEntityQueryService
var _grid := AStarGrid2D.new()
var _terrain_solid := {}
var _claim_cells := {}
var _dirty := true
var _walkable: Callable

func configure(coordinates: GopalaSettlementCoordinateService, occupancy: GopalaSettlementOccupancyService, queries: GopalaEntityQueryService) -> void:
	_coordinates = coordinates
	_occupancy = occupancy
	_queries = queries
	occupancy.occupancy_changed.connect(func(_snapshot): _dirty = true; revision += 1)
	occupancy.occupancy_reset.connect(func(): _dirty = true; revision += 1)

func enable(bounds: Rect2i, walkable: Callable = Callable()) -> void:
	_grid.region = bounds
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.jumping_enabled = false
	_grid.update()
	_terrain_solid.clear()
	_claim_cells.clear()
	_walkable = walkable
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x,y)
			var solid: bool = walkable.is_valid() and not walkable.call(_coordinates.settlement_cell_to_world_xz(cell))
			_grid.set_point_solid(cell,solid)
			if solid: _terrain_solid[cell] = true
	enabled = true
	_dirty = true
	revision += 1

func _refresh() -> void:
	if not _dirty: return
	for cell in _claim_cells: _grid.set_point_solid(cell, _terrain_solid.has(cell))
	_claim_cells.clear()
	for claim in _occupancy.grid_snapshot().claims:
		for pair in claim.cells:
			var cell := Vector2i(pair[0],pair[1])
			if _grid.region.has_point(cell):
				_claim_cells[cell] = true
				_grid.set_point_solid(cell)
	_dirty = false

func is_open(cell: Vector2i) -> bool:
	_refresh()
	return _grid.region.has_point(cell) and not _grid.is_point_solid(cell)

func plan(position: Vector2, destination: Vector2, purpose: StringName) -> Dictionary:
	_refresh()
	last_failure = &""
	var start := _coordinates.world_to_settlement_cell(position)
	var goal := _coordinates.world_to_settlement_cell(destination)
	if not _grid.region.has_point(start) or not _grid.region.has_point(goal):
		return _failure(&"ROUTE_OUT_OF_BOUNDS")
	if not is_open(start): return _failure(&"ROUTE_START_BLOCKED")
	var goals: Array[Vector2i] = [goal]
	var access := false
	if purpose in [&"DELIVER", &"BUILD", &"NEED"]:
		var claim = _occupancy.claim_at(goal)
		if claim != null:
			access = true
			goals.clear()
			var seen := {}
			for cell in claim.cells:
				for direction in [Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)]:
					var neighbour: Vector2i = cell + direction
					if is_open(neighbour) and not seen.has(neighbour):
						goals.append(neighbour)
						seen[neighbour] = true
			goals.sort_custom(func(a,b):
				var da: int = absi(a.x - start.x) + absi(a.y - start.y)
				var db: int = absi(b.x - start.x) + absi(b.y - start.y)
				return da < db if da != db else (a.x < b.x if a.x != b.x else a.y < b.y)
			)
	if goals.is_empty(): return _failure(&"NO_ACCESS_CELL")
	var chosen: Array[Vector2i] = []
	for candidate in goals:
		if not is_open(candidate): continue
		var path: Array[Vector2i] = _grid.get_id_path(start,candidate)
		if not path.is_empty() and (chosen.is_empty() or path.size() < chosen.size()): chosen = path
	if chosen.is_empty(): return _failure(&"NO_ROUTE")
	var points: Array[Vector2] = []
	# First reach the current cell centre, preventing a diagonal corner cut from
	# an off-centre spawn when the first grid segment turns beside an obstacle.
	for cell in chosen: points.append(_coordinates.settlement_cell_to_world_xz(cell))
	var final := points[-1] if access else destination
	if final.distance_to(points[-1]) > 0.000001: points.append(final)
	return {"ok":true,"points":points,"destination":final,"revision":revision}

func _failure(reason: StringName) -> Dictionary:
	last_failure = reason
	return {"ok":false,"reason":reason}
