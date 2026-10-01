import os

hud_path = "scenes/landscape/kathmandu_hud.gd"
with open(hud_path, "r") as f:
    lines = f.readlines()

new_hud = []
skip = False

for line in lines:
    if "func _ready() -> void:" in line:
        new_hud.append(line)
        new_hud.append("\tset_anchors_preset(PRESET_FULL_RECT)\n")
        new_hud.append("\tmouse_filter = MOUSE_FILTER_PASS\n")
        new_hud.append("\tvar hud_theme: Theme = load(\"res://assets/ui/kathmandu/kathmandu_theme.tres\").duplicate()\n")
        new_hud.append("\thud_theme.default_font = ui_font()\n")
        new_hud.append("\ttheme = hud_theme\n")
        new_hud.append("\tbuild_top_bar()\n") # NEW TOP BAR
        new_hud.append("\tbuild_status()\n")
        new_hud.append("\tbuild_view_tools()\n")
        new_hud.append("\tbuild_categories()\n")
        new_hud.append("\tbuild_action()\n")
        new_hud.append("\tbuild_card()\n")
        new_hud.append("\tcategory_row.visible = false\n")
        new_hud.append("\tcard.visible = false\n")
        new_hud.append("\tlayout.call_deferred()\n")
        skip = True
        continue
    
    if skip and line.startswith("func _notification"):
        skip = False
    
    if line.startswith("func layout() -> void:"):
        skip = True
        new_hud.append(line)
        new_hud.append("\tvar view := get_viewport_rect().size\n")
        new_hud.append("\tif view.x < 100.0: return\n")
        new_hud.append("\tvar status_width := status_box.get_combined_minimum_size().x\n")
        new_hud.append("\n")
        new_hud.append("\t# Top Bar stretches across the top\n")
        new_hud.append("\tif is_instance_valid(top_bar):\n")
        new_hud.append("\t\ttop_bar.position = Vector2(0, 0)\n")
        new_hud.append("\t\ttop_bar.size = Vector2(view.x, 80)\n")
        new_hud.append("\n")
        new_hud.append("\t# Bottom Right: Time controls & views\n")
        new_hud.append("\tstatus_box.position = Vector2(view.x - status_width - 16, view.y - 50)\n")
        new_hud.append("\tview_tools.position = Vector2(view.x - 200, view.y - 100)\n")
        new_hud.append("\tsources_button.position = Vector2(view.x - 120, view.y - 100)\n")
        new_hud.append("\tcredits.position = Vector2(view.x - 280, view.y - 160)\n")
        new_hud.append("\n")
        new_hud.append("\t# Bottom Center: Build Menu & Tabs\n")
        new_hud.append("\tvar build_size := build_button.get_combined_minimum_size()\n")
        new_hud.append("\tbuild_button.position = Vector2(16, view.y - 52)\n")
        new_hud.append("\tvar categories_width := category_row.get_combined_minimum_size().x\n")
        new_hud.append("\tcategory_row.position = Vector2((view.x - categories_width) * 0.5, view.y - 52)\n")
        new_hud.append("\tcard.position = Vector2((view.x - 324) * 0.5, view.y - 250)\n")
        new_hud.append("\tcard.size = Vector2(324, 180)\n")
        continue

    if skip and line.startswith("func display_font() -> Font:"):
        skip = False

    if line.startswith("func build_title() -> void:"):
        skip = True
        new_hud.append("var top_bar: PanelContainer\n\n")
        new_hud.append("func build_top_bar() -> void:\n")
        new_hud.append("\ttop_bar = PanelContainer.new()\n")
        new_hud.append("\tvar style = StyleBoxFlat.new()\n")
        new_hud.append("\tstyle.bg_color = Color(0.08, 0.08, 0.08, 0.95)\n")
        new_hud.append("\tstyle.border_width_bottom = 2\n")
        new_hud.append("\tstyle.border_color = GOLD\n")
        new_hud.append("\ttop_bar.add_theme_stylebox_override(\"panel\", style)\n")
        new_hud.append("\tadd_child(top_bar)\n")
        new_hud.append("\t\n")
        new_hud.append("\tvar main_hbox = HBoxContainer.new()\n")
        new_hud.append("\tmain_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN\n")
        new_hud.append("\ttop_bar.add_child(main_hbox)\n")
        new_hud.append("\t\n")
        new_hud.append("\tvar crest = TextureRect.new()\n")
        new_hud.append("\tcrest.texture = load(\"res://assets/ui/theme/crest.png\")\n")
        new_hud.append("\tcrest.custom_minimum_size = Vector2(80, 80)\n")
        new_hud.append("\tcrest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE\n")
        new_hud.append("\tcrest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED\n")
        new_hud.append("\tmain_hbox.add_child(crest)\n")
        new_hud.append("\t\n")
        new_hud.append("\tvar info_vbox = VBoxContainer.new()\n")
        new_hud.append("\tinfo_vbox.alignment = BoxContainer.ALIGNMENT_CENTER\n")
        new_hud.append("\tinfo_vbox.add_theme_constant_override(\"separation\", 2)\n")
        new_hud.append("\tmain_hbox.add_child(info_vbox)\n")
        new_hud.append("\t\n")
        new_hud.append("\tvar name_label = Label.new()\n")
        new_hud.append("\tname_label.text = \"Dudhkunda\"\n")
        new_hud.append("\tname_label.add_theme_font_override(\"font\", display_font())\n")
        new_hud.append("\tname_label.add_theme_font_size_override(\"font_size\", 22)\n")
        new_hud.append("\tname_label.add_theme_color_override(\"font_color\", GOLD)\n")
        new_hud.append("\tinfo_vbox.add_child(name_label)\n")
        new_hud.append("\t\n")
        new_hud.append("\tvar details_label = Label.new()\n")
        new_hud.append("\tdetails_label.text = \"Early Summer    18°C\\nYear 1                 Rain\"\n")
        new_hud.append("\tdetails_label.add_theme_font_size_override(\"font_size\", 12)\n")
        new_hud.append("\tdetails_label.add_theme_color_override(\"font_color\", PAPER)\n")
        new_hud.append("\tinfo_vbox.add_child(details_label)\n")
        new_hud.append("\t\n")
        new_hud.append("\tvar spacer = Control.new()\n")
        new_hud.append("\tspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n")
        new_hud.append("\tmain_hbox.add_child(spacer)\n")
        new_hud.append("\t\n")
        new_hud.append("\tvar stores = HBoxContainer.new()\n")
        new_hud.append("\tstores.add_theme_constant_override(\"separation\", 20)\n")
        new_hud.append("\tstores.alignment = BoxContainer.ALIGNMENT_CENTER\n")
        new_hud.append("\tmain_hbox.add_child(stores)\n")
        new_hud.append("\t\n")
        new_hud.append("\tvar catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(\"res://data/catalog.json\"))\n")
        new_hud.append("\tfor path in catalog.resources:\n")
        new_hud.append("\t\tvar good: GopalaResourceDefinition = load(path)\n")
        new_hud.append("\t\tvar slot = HBoxContainer.new()\n")
        new_hud.append("\t\tslot.add_theme_constant_override(\"separation\", 6)\n")
        new_hud.append("\t\tstores.add_child(slot)\n")
        new_hud.append("\t\t\n")
        new_hud.append("\t\tvar icon = TextureRect.new()\n")
        new_hud.append("\t\tvar icon_name = \"food\" if str(good.id) == \"wild_food\" else str(good.id)\n")
        new_hud.append("\t\ticon.texture = load(\"res://assets/ui/kathmandu/icon_%s.png\" % icon_name)\n")
        new_hud.append("\t\ticon.custom_minimum_size = Vector2(22, 22)\n")
        new_hud.append("\t\ticon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE\n")
        new_hud.append("\t\ticon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED\n")
        new_hud.append("\t\tslot.add_child(icon)\n")
        new_hud.append("\t\t\n")
        new_hud.append("\t\tvar amt = Label.new()\n")
        new_hud.append("\t\tamt.text = str(randi() % 500) # Mock\n")
        new_hud.append("\t\tamt.add_theme_font_size_override(\"font_size\", 15)\n")
        new_hud.append("\t\tamt.add_theme_color_override(\"font_color\", PAPER)\n")
        new_hud.append("\t\tslot.add_child(amt)\n")
        new_hud.append("\t\n")
        new_hud.append("\tvar spacer2 = Control.new()\n")
        new_hud.append("\tspacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n")
        new_hud.append("\tmain_hbox.add_child(spacer2)\n")
        new_hud.append("\t\n")
        new_hud.append("\tvar minimap = TextureRect.new()\n")
        new_hud.append("\tminimap.texture = load(\"res://assets/ui/theme/minimap_frame.png\")\n")
        new_hud.append("\tminimap.custom_minimum_size = Vector2(80, 80)\n")
        new_hud.append("\tminimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE\n")
        new_hud.append("\tminimap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED\n")
        new_hud.append("\tmain_hbox.add_child(minimap)\n")
        continue

    if skip and line.startswith("func build_status() -> void:"):
        skip = False
    
    if line.startswith("func build_map() -> void:"):
        skip = True
        continue
        
    if skip and line.startswith("func build_view_tools() -> void:"):
        skip = False

    if not skip:
        new_hud.append(line)

with open(hud_path, "w") as f:
    f.writelines(new_hud)
print("Finished rewriting HUD.")
