extends Node2D
## Inspectable content laboratory, not a settlement simulation.

func _ready() -> void:
	var title := Label.new()
	title.text = "GOPALA  /  Dawn of the Valley\nContent laboratory — prototype resources"
	title.position = Vector2(40, 28)
	title.add_theme_font_size_override("font_size", 26)
	add_child(title)
	var world := Node2D.new()
	world.name = "SortedWorld"
	world.y_sort_enabled = true
	add_child(world)
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.z_index = -1
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(128, 64)
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tiles.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/prototype/terrain_meadow.png")
	atlas.texture_region_size = Vector2i(128, 64)
	atlas.create_tile(Vector2i.ZERO)
	tiles.add_source(atlas, 0)
	ground.tile_set = tiles
	ground.position = Vector2(540, 140)
	add_child(ground)
	for y in range(7):
		for x in range(7):
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var catalog: Dictionary = GopalaContentAudit.load_json(GopalaContentAudit.REGISTRY_PATH)
	for i in range(catalog.buildings.size()):
		var definition: GopalaBuildingDefinition = load(catalog.buildings[i])
		var sprite := Sprite2D.new()
		sprite.name = str(definition.id)
		sprite.texture = definition.prototype_sprite
		sprite.position = ground.position + ground.map_to_local(Vector2i(1 + (i % 3) * 2, 1 + (i / 3) * 3))
		sprite.offset = Vector2(0, -48)
		world.add_child(sprite)
		var label := Label.new()
		label.text = definition.display_name
		label.position = Vector2(-64, 8)
		label.add_theme_font_size_override("font_size", 14)
		sprite.add_child(label)
	var goods := HBoxContainer.new()
	goods.position = Vector2(40, 670)
	goods.add_theme_constant_override("separation", 26)
	add_child(goods)
	for path in catalog.resources:
		var definition: GopalaResourceDefinition = load(path)
		var column := VBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = definition.icon
		icon.custom_minimum_size = Vector2(48, 48)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		column.add_child(icon)
		var label := Label.new()
		label.text = definition.display_name
		column.add_child(label)
		goods.add_child(column)
	var state := Label.new()
	state.text = "Content audit: " + ("PASS" if GopalaContentAudit.run().ok else "FAIL") + "  |  No worker simulation yet"
	state.position = Vector2(40, 760)
	add_child(state)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var code := get_viewport().get_texture().get_image().save_png("res://../reports/content-lab.png")
		print("GOPALA_CAPTURE_RESULT=", code)
		get_tree().quit(code)

