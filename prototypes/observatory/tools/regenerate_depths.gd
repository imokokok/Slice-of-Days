extends SceneTree
# godot --headless --path . --script res://tools/regenerate_depths.gd
func _init() -> void:
 for id in ["bird", "whale"]:
  var path := "res://resources/" + id + "_constellation.tres"
  var data := load(path) as ConstellationData
  data.regenerate_depths(42 if id == "bird" else 95)
  ResourceSaver.save(data,path)
 quit()
