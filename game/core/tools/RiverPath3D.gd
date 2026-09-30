@tool
extends Path3D
class_name RiverPath3D

@export var river_width: float = 2.0 :
	set(value):
		river_width = value
		_update_mesh()

@export var river_material: Material :
	set(value):
		river_material = value
		if mesh_instance:
			mesh_instance.material_override = river_material

@export var generate_river: bool = false :
	set(value):
		if value:
			_update_mesh()
			generate_river = false

var mesh_instance: MeshInstance3D

func _ready() -> void:
	if not Engine.is_editor_hint():
		_update_mesh()
		
	# Hook up signal if the path changes
	curve_changed.connect(_update_mesh)

func _update_mesh() -> void:
	if curve == null or curve.get_baked_points().size() < 2:
		return
		
	if not mesh_instance:
		for child in get_children():
			if child is MeshInstance3D and child.name == "RiverMesh":
				mesh_instance = child
				break
				
		if not mesh_instance:
			mesh_instance = MeshInstance3D.new()
			mesh_instance.name = "RiverMesh"
			add_child(mesh_instance)
			
	if river_material:
		mesh_instance.material_override = river_material
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var points = curve.get_baked_points()
	var ups = curve.get_baked_up_vectors()
	var total_length = curve.get_baked_length()
	var current_length = 0.0
	
	for i in range(points.size()):
		var p = points[i]
		var up = ups[i]
		var forward = Vector3.FORWARD
		
		if i < points.size() - 1:
			forward = (points[i+1] - p).normalized()
		elif i > 0:
			forward = (p - points[i-1]).normalized()
			
		var right = forward.cross(up).normalized()
		
		if i > 0:
			current_length += points[i-1].distance_to(p)
			
		var v_coord = current_length
		
		# Left vertex
		st.set_normal(up)
		st.set_uv(Vector2(0.0, v_coord))
		st.add_vertex(p - right * (river_width * 0.5))
		
		# Right vertex
		st.set_normal(up)
		st.set_uv(Vector2(1.0, v_coord))
		st.add_vertex(p + right * (river_width * 0.5))
		
	# Generate triangles
	for i in range(points.size() - 1):
		var base_idx = i * 2
		
		# First triangle
		st.add_index(base_idx)
		st.add_index(base_idx + 1)
		st.add_index(base_idx + 2)
		
		# Second triangle
		st.add_index(base_idx + 1)
		st.add_index(base_idx + 3)
		st.add_index(base_idx + 2)
		
	st.generate_normals()
	st.generate_tangents()
	
	mesh_instance.mesh = st.commit()
