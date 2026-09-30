extends SceneTree
## Bake the original terrain atlas, authoritative map, and editable scene once.

func _initialize() -> void:
	var map := GopalaValleyTerrain.generate()
	var image := Image.create(GopalaValleyTerrain.TILE_SIZE.x * GopalaValleyTerrain.VARIANTS, GopalaValleyTerrain.TILE_SIZE.y * GopalaValleyTerrain.NAMES.size(), false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 9201
	noise.frequency = 0.045
	for kind in range(GopalaValleyTerrain.NAMES.size()):
		for variant in range(GopalaValleyTerrain.VARIANTS):
			for y in range(64):
				for x in range(128):
					var diamond: float = abs((float(x) + 0.5 - 64.0) / 64.0) + abs((float(y) + 0.5 - 32.0) / 32.0)
					if diamond > 1.0:
						continue
					var variation: float = noise.get_noise_2d(x + variant * 128, y + kind * 64) * 0.075 + float(variant - 1) * 0.006
					var color: Color = GopalaValleyTerrain.PALETTE[kind]
					color = color.lightened(variation) if variation > 0 else color.darkened(-variation)
					if kind == GopalaValleyTerrain.Kind.WATER:
						color = color.lightened(0.028 * sin(float(x + y * 2) / 17.0))
					image.set_pixel(x + variant * 128, y + kind * 64, color)
	var atlas_path := "res://assets/terrain/valley_atlas.png"
	if image.save_png(atlas_path) != OK:
		quit(1)
		return
	# Use an imported texture when baking a persisted TileSet. The first pass
	# writes the image; import it before rerunning this script with --bake-scene.
	var manifest: Dictionary = GopalaContentAudit.load_json(GopalaContentAudit.MANIFEST_PATH)
	var kept: Array = []
	for entry in manifest.assets:
		if entry.id != "valley_atlas":
			kept.append(entry)
	kept.append({"id": "valley_atlas", "path": atlas_path, "width": image.get_width(), "height": image.get_height(), "sha256": FileAccess.get_sha256(atlas_path), "origin": "original_procedural", "status": "prototype", "source": "res://tests/bake_landscape.gd", "rights": "Original project-authored terrain texture."})
	manifest.assets = kept
	var file := FileAccess.open(GopalaContentAudit.MANIFEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	if ResourceSaver.save(map, "res://data/maps/starting_valley.tres") != OK:
		quit(1)
		return
	if not "--bake-scene" in OS.get_cmdline_user_args():
		print("GOPALA_LANDSCAPE_IMAGE_READY")
		quit(0)
		return
	var tiles := TileSet.new()
	tiles.tile_size = GopalaValleyTerrain.TILE_SIZE
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tiles.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(atlas_path)
	atlas.texture_region_size = GopalaValleyTerrain.TILE_SIZE
	for kind in range(GopalaValleyTerrain.NAMES.size()):
		for variant in range(GopalaValleyTerrain.VARIANTS):
			atlas.create_tile(Vector2i(variant, kind))
	tiles.add_source(atlas, 0)
	if ResourceSaver.save(tiles, "res://data/maps/valley_tileset.tres") != OK:
		quit(1)
		return
	var world := Node2D.new()
	world.name = "Valley"
	world.set_script(load("res://scenes/world/valley.gd"))
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = load("res://data/maps/valley_tileset.tres")
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	world.add_child(ground)
	ground.owner = world
	for y in range(map.size.y):
		for x in range(map.size.x):
			var cell := Vector2i(x, y)
			ground.set_cell(cell, 0, Vector2i(map.variant_at(cell), map.kind_at(cell)))
	var overlay := Node2D.new()
	overlay.name = "TerrainOverlay"
	overlay.set_script(load("res://scenes/world/terrain_overlay.gd"))
	world.add_child(overlay)
	overlay.owner = world
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.set_script(load("res://scenes/world/valley_camera.gd"))
	world.add_child(camera)
	camera.owner = world
	var scene := PackedScene.new()
	var code := scene.pack(world)
	if code == OK:
		code = ResourceSaver.save(scene, "res://scenes/world/valley.tscn")
	world.free()
	print("GOPALA_LANDSCAPE_BAKE=", code)
	quit(0 if code == OK else 1)
