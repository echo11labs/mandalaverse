@tool
extends SceneTree

func _init():
	print("Generating Main Theme...")
	var theme = Theme.new()
	
	# Create PanelContainer style (dark translucent with border)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.15, 0.85)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.8, 0.65, 0.4, 1.0) # Bronze/Gold trim
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	
	# Create default Label style
	theme.set_color("font_color", "Label", Color(0.9, 0.9, 0.9, 1.0))
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	
	var err = ResourceSaver.save(theme, "res://assets/ui/theme/main_theme.tres")
	if err == OK:
		print("Successfully saved main_theme.tres")
	else:
		print("Failed to save theme: ", err)
	
	quit()
