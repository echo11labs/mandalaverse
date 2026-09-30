extends SceneTree

func _init():
    print("Testing Waterways")
    var RiverManager = load("res://addons/waterways/river_manager.gd")
    var rm = RiverManager.new()
    var curve = Curve3D.new()
    curve.add_point(Vector3.ZERO, Vector3.ZERO, Vector3(0,0,1))
    curve.add_point(Vector3(0,0,10), Vector3(0,0,-1), Vector3.ZERO)
    rm.curve = curve
    var w: Array[float] = [1.0, 1.0]
    rm.widths = w
    
    var root = Node3D.new()
    root.add_child(rm)
    
    print("Child added, valid? ", rm != null)
    quit()
