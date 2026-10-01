class_name GopalaKathmanduHud
extends CanvasLayer
## Controller for the modernized HUD layout in hud.tscn.

signal valley_requested
signal source_requested
signal camp_requested
signal grid_changed(on: bool)
signal names_changed(on: bool)
signal zoom_in_requested
signal zoom_out_requested
signal turn_left_requested
signal turn_right_requested

var terrain: GopalaKathmanduTerrain

func _ready() -> void:
	# Try to find the minimap viewport and update it if possible
	var viewport = find_child("MinimapViewport", true, false)
	if viewport and viewport is SubViewport:
		# Just an example of how we could interact with the new UI.
		pass

func follow(camera: Camera3D) -> void:
	pass

func close_build() -> void:
	pass

func set_grid(on: bool) -> void:
	pass

func show_place(title_text: String, detail: String) -> void:
	pass
