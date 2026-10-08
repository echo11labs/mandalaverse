class_name GopalaCattleView
extends Node3D
## Original prototype geometry; dimensions come from the shared metre standard.
var geometry: Node3D
func _init():
	geometry = Node3D.new()
	add_child(geometry)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c3a889")
	material.roughness = 0.9
	part(Vector3(0.62,0.6,1.45),Vector3(0,0.85,0),material)
	part(Vector3(0.38,0.45,0.48),Vector3(0,0.92,-0.85),material)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("554538")
	for x in [-0.23,0.23]:
		for z in [-0.5,0.5]: part(Vector3(0.12,0.6,0.14),Vector3(x,0.3,z),dark)
	for x in [-0.23,0.23]: part(Vector3(0.16,0.09,0.2),Vector3(x,1.16,-0.84),material)
	GopalaScaleStandard.normalize_height(geometry,GopalaScaleStandard.number("cattle","height"))
func part(size: Vector3, center: Vector3, material: Material):
	var view := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	view.mesh = box
	view.position = center
	view.material_override = material
	geometry.add_child(view)
