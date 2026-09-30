extends SceneTree
## Deterministic original primitives for import and layout testing only.

var manifest: Array[Dictionary] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/prototype")
	var terrains := {"meadow": Color("71876a"), "earth": Color("9a8061"), "water": Color("608d9c"), "path": Color("b7a085")}
	for key in terrains:
		var image := Image.create(128, 64, false, Image.FORMAT_RGBA8)
		paint_polygon(image, PackedVector2Array([Vector2(64, 1), Vector2(127, 32), Vector2(64, 63), Vector2(1, 32)]), terrains[key])
		store_asset("terrain_" + key, image)
	var colors := [Color("9b7454"), Color("aaa79b"), Color("c0a75d"), Color("679db3"), Color("ad695c"), Color("709455"), Color("eee1b6")]
	var goods := ["timber", "stone", "thatch", "water", "wild_food", "fodder", "milk"]
	for i in range(goods.size()):
		var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		paint_polygon(image, PackedVector2Array([Vector2(24, 4), Vector2(44, 24), Vector2(24, 44), Vector2(4, 24)]), colors[i])
		paint_polygon(image, PackedVector2Array([Vector2(24, 10), Vector2(34, 24), Vector2(24, 34), Vector2(14, 24)]), colors[i].lightened(0.15))
		store_asset("good_" + goods[i], image)
	var buildings := ["dwelling", "stockpile", "timber_camp", "gatherer_shelter", "water_point", "cattle_shelter"]
	for i in range(buildings.size()):
		var image := Image.create(128, 160, false, Image.FORMAT_RGBA8)
		paint_polygon(image, PackedVector2Array([Vector2(64, 106), Vector2(120, 130), Vector2(64, 157), Vector2(8, 130)]), Color(0.05, 0.07, 0.05, 0.2))
		paint_polygon(image, PackedVector2Array([Vector2(12, 74), Vector2(64, 100), Vector2(64, 146), Vector2(12, 120)]), Color("b4916f").darkened(i * 0.025))
		paint_polygon(image, PackedVector2Array([Vector2(64, 100), Vector2(116, 74), Vector2(116, 120), Vector2(64, 146)]), Color("8b7055"))
		paint_polygon(image, PackedVector2Array([Vector2(6, 74), Vector2(64, 32 + i * 3), Vector2(122, 74), Vector2(64, 106)]), Color("c5ad74").darkened(i * 0.025))
		paint_polygon(image, PackedVector2Array([Vector2(36, 108), Vector2(50, 115), Vector2(50, 137), Vector2(36, 130)]), Color("483d31"))
		store_asset("building_" + buildings[i], image)
	for key in ["villager", "cattle"]:
		var image := Image.create(48, 64, false, Image.FORMAT_RGBA8)
		var color := Color("d1b184") if key == "villager" else Color("e1d7be")
		paint_polygon(image, PackedVector2Array([Vector2(24, 6), Vector2(36, 22), Vector2(34, 52), Vector2(14, 52), Vector2(12, 22)]), color)
		store_asset("agent_" + key, image)
	var file := FileAccess.open("res://assets/manifest.json", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"schema_version": 1, "assets": manifest}, "\t") + "\n")
	file.close()
	print("GOPALA_PROTOTYPES=", manifest.size())
	quit(0)

func paint_polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				image.set_pixel(x, y, color)

func store_asset(id: String, image: Image) -> void:
	var path := "res://assets/prototype/" + id + ".png"
	var code := image.save_png(path)
	if code != OK:
		push_error("Could not generate " + id)
		quit(1)
		return
	manifest.append({"id": id, "path": path, "width": image.get_width(), "height": image.get_height(), "sha256": FileAccess.get_sha256(path), "origin": "original_procedural", "status": "prototype", "source": "res://tests/generate_prototypes.gd", "rights": "Original project-authored geometric placeholder; not third-party artwork."})

