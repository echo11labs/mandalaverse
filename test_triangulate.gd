extends SceneTree
func _init():
    var poly = PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)])
    var indices = Geometry2D.triangulate_polygon(poly)
    print(indices)
    quit()
