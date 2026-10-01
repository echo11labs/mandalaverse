@tool
extends Node

## Generates 2D thumbnails from 3D models for the build menu UI.
## To use: instantiate this scene in the editor, set the building_scene, and click "generate".

@export var building_scene: PackedScene
@export var output_path: String = "res://assets/ui/thumbnails/"
@export var generate: bool = false: set = _on_generate

var viewport: SubViewport
var camera: Camera3D
var model_instance: Node3D

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
		
	# Setup the rendering viewport
	viewport = SubViewport.new()
	viewport.size = Vector2(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	
	# Setup Isometric Camera
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.position = Vector3(10, 10, 10)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	viewport.add_child(camera)
	
	# Directional light for consistent icon shading
	var light = DirectionalLight3D.new()
	light.position = Vector3(5, 10, 5)
	light.look_at(Vector3.ZERO, Vector3.UP)
	viewport.add_child(light)

func _on_generate(val: bool) -> void:
	if not val or not Engine.is_editor_hint():
		return
		
	if building_scene == null:
		print("ThumbnailGenerator: No building scene assigned.")
		return
		
	# Clear previous model
	if model_instance != null:
		model_instance.queue_free()
		
	# Instance and render
	model_instance = building_scene.instantiate()
	viewport.add_child(model_instance)
	
	# Wait for rendering to complete (need to yield a frame or two in editor)
	call_deferred("_save_capture")

func _save_capture() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	
	var image = viewport.get_texture().get_image()
	var filename = building_scene.resource_path.get_file().get_basename() + "_thumb.png"
	var save_path = output_path + filename
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(output_path):
		dir.make_dir_recursive(output_path)
		
	var err = image.save_png(save_path)
	if err == OK:
		print("ThumbnailGenerator: Saved thumbnail to " + save_path)
	else:
		print("ThumbnailGenerator: Error saving thumbnail: ", err)
