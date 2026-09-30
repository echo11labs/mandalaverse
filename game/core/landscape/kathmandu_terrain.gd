class_name GopalaKathmanduTerrain
extends Resource
## Immutable geographic samples; visual cleanup is distinct from source DSM.
const DIRECTORY := "res://data/geography/"
const METRES_PER_UNIT := 100.0
const BASE_ELEVATION := 1200.0
const EXTENT := 400.0
const GRID_SIZE := 48
const CELL_SIZE := 0.2
const RELIEF := 3.0
var metadata: Dictionary
var source: PackedFloat32Array
var ground: PackedFloat32Array
var distance_field: PackedFloat32Array
var samples := 1025
var camp := Vector2(-74.9,12.3)
func load_data() -> void:
	if not source.is_empty(): return
	metadata = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "kathmandu.json"))
	samples = int(metadata.grid_samples)
	source = FileAccess.get_file_as_bytes(DIRECTORY+"kathmandu-source-height.f32").to_float32_array()
	ground = FileAccess.get_file_as_bytes(DIRECTORY+"kathmandu-ground-height.f32").to_float32_array()
	distance_field = FileAccess.get_file_as_bytes(DIRECTORY+"kathmandu-river-distance.f32").to_float32_array()
func sample_grid(field: PackedFloat32Array,x: float,z: float) -> float:
	var column := clampf((x/EXTENT+0.5)*(samples-1),0,samples-1)
	var row := clampf((z/EXTENT+0.5)*(samples-1),0,samples-1)
	var c := floori(column)
	var r := floori(row)
	var c1 := mini(c+1,samples-1)
	var r1 := mini(r+1,samples-1)
	return lerpf(lerpf(field[r*samples+c],field[r*samples+c1],column-c),lerpf(field[r1*samples+c],field[r1*samples+c1],column-c),row-r)
func elevation_at(x: float,z: float) -> float:
	return sample_grid(source,x,z)
func height_at(x: float,z: float) -> float:
	# Match the displayed 512-square triangle mesh, so picking and grid placement
	# share the same surface between vertices. Source elevation stays separate.
	var c := clampf((x/EXTENT+0.5)*512,0,512)
	var r := clampf((z/EXTENT+0.5)*512,0,512)
	var c0 := mini(floori(c),511)
	var r0 := mini(floori(r),511)
	var tx := c-c0
	var tz := r-r0
	var a := ground[r0*2*samples+c0*2]
	var b := ground[r0*2*samples+(c0+1)*2]
	var d := ground[(r0+1)*2*samples+c0*2]
	var e := ground[(r0+1)*2*samples+(c0+1)*2]
	var value: float = a+(b-a)*tx+(d-a)*tz if tx+tz<=1 else e+(d-e)*(1-tx)+(b-e)*(1-tz)
	return (value-BASE_ELEVATION)/METRES_PER_UNIT*RELIEF
func river_distance(x: float,z: float) -> float:
	return sample_grid(distance_field,x,z)
func normal_at(x: float,z: float,physical := false) -> Vector3:
	var e := 0.4
	var h := Vector3(height_at(x-e,z)-height_at(x+e,z),e*2,height_at(x,z-e)-height_at(x,z+e))
	if physical:
		h.x /= RELIEF
		h.z /= RELIEF
	return h.normalized()
func contains(cell: Vector2i) -> bool:
	return Rect2i(0,0,GRID_SIZE,GRID_SIZE).has_point(cell)
func cell_at(point: Vector3) -> Vector2i:
	var local := Vector2(point.x,point.z)-camp+Vector2.ONE*GRID_SIZE*CELL_SIZE*0.5
	return Vector2i(floori(local.x/CELL_SIZE),floori(local.y/CELL_SIZE))
func cell_position(cell: Vector2i) -> Vector3:
	var p := camp+(Vector2(cell)+Vector2.ONE*0.5-Vector2.ONE*GRID_SIZE*0.5)*CELL_SIZE
	return Vector3(p.x,height_at(p.x,p.y),p.y)
func is_buildable(cell: Vector2i) -> bool:
	if not contains(cell): return false
	var p := cell_position(cell)
	for corner in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5),Vector2.ZERO]:
		var x: float = p.x+corner.x*CELL_SIZE
		var z: float = p.z+corner.y*CELL_SIZE
		if river_distance(x,z)<30 or normal_at(x,z,true).y<cos(deg_to_rad(12)): return false
	return true
func nearest_river(point: Vector3) -> Dictionary:
	var result := {"name":"","distance":INF,"way_id":"","reconstructed":false}
	var position := Vector2(point.x,point.z)
	var reaches: Array = metadata.rivers+metadata.reconstruction
	for river in reaches:
		var points: Array = river.points
		for i in range(points.size()-1):
			var a := Vector2(points[i][0],points[i][2])
			var b := Vector2(points[i+1][0],points[i+1][2])
			var delta := b-a
			var t := clampf((position-a).dot(delta)/maxf(delta.length_squared(),0.0000001),0,1)
			var d := position.distance_to(a+delta*t)*METRES_PER_UNIT
			if d < result.distance: result = {"name":river.name,"distance":d,"way_id":river.id,"reconstructed":river.kind=="reconstructed"}
	return result
