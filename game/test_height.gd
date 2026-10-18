extends SceneTree
func _initialize():
	var terrain = GopalaKathmanduTerrain.new()
	terrain.load_data()
	var h = terrain.height_at(-8.129687, -125.8592)
	print("Terrain height at tree 0: ", h)
	quit()
