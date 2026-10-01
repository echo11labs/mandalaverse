@tool
extends SceneTree

func _init():
	print("Generating UI Scenes...")
	
	# 1. Top Resource Bar
	var top_bar = HBoxContainer.new()
	top_bar.name = "TopResourceBar"
	top_bar.theme = load("res://assets/ui/theme/main_theme.tres")
	top_bar.add_theme_constant_override("separation", 20)
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var res_label = Label.new()
	res_label.name = "Gold"
	res_label.text = "Gold: 0"
	top_bar.add_child(res_label)
	res_label.owner = top_bar
	
	save_scene(top_bar, "res://scenes/ui/top_resource_bar.tscn")
	
	# 2. Objective Tracker
	var obj_tracker = PanelContainer.new()
	obj_tracker.name = "ObjectiveTracker"
	obj_tracker.theme = load("res://assets/ui/theme/main_theme.tres")
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	obj_tracker.add_child(vbox)
	vbox.owner = obj_tracker
	
	var title = Label.new()
	title.name = "Title"
	title.text = "Path of Prosperity"
	vbox.add_child(title)
	title.owner = obj_tracker
	
	save_scene(obj_tracker, "res://scenes/ui/objective_tracker.tscn")
	
	# 3. Build Menu
	var build_menu = PanelContainer.new()
	build_menu.name = "BuildMenu"
	build_menu.theme = load("res://assets/ui/theme/main_theme.tres")
	
	var b_vbox = VBoxContainer.new()
	b_vbox.name = "VBox"
	build_menu.add_child(b_vbox)
	b_vbox.owner = build_menu
	
	var tabs = TabContainer.new()
	tabs.name = "Tabs"
	b_vbox.add_child(tabs)
	tabs.owner = build_menu
	
	var all_tab = GridContainer.new()
	all_tab.name = "All"
	all_tab.columns = 5
	tabs.add_child(all_tab)
	all_tab.owner = build_menu
	
	save_scene(build_menu, "res://scenes/ui/build_menu.tscn")
	
	# 4. HUD (Root)
	var hud = CanvasLayer.new()
	hud.name = "HUD"
	
	var control = Control.new()
	control.name = "MainControl"
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(control)
	control.owner = hud
	
	save_scene(hud, "res://scenes/ui/hud.tscn")
	
	print("Finished generating scenes.")
	quit()

func save_scene(node: Node, path: String):
	var packed = PackedScene.new()
	var err = packed.pack(node)
	if err == OK:
		err = ResourceSaver.save(packed, path)
		if err == OK:
			print("Saved ", path)
		else:
			print("Failed to save ", path, " err:", err)
	else:
		print("Failed to pack ", path, " err:", err)
	
	node.free()
