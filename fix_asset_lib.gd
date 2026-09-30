extends SceneTree
func _init():
    var es = EditorInterface.get_editor_settings() if Engine.is_editor_hint() else null
    print("Editor settings: ", es)
    quit()
