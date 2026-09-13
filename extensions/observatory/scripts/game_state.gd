extends Node
var discovered: Dictionary = {"bird": false, "whale": false}
var collected: Dictionary = {"bird": false, "whale": false}
var slide_index := 0
var slide_elapsed := 0.0
var slide_file := ""
const SAVE := "user://observatory.json"
func _ready() -> void:
 if FileAccess.file_exists(SAVE):
  var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
  if data is Dictionary:
   for key in discovered:
    discovered[key] = bool(data.get("discovered", {}).get(key, false))
    collected[key] = bool(data.get("collected", {}).get(key, false))
   slide_file = str(data.get("slide_file", ""))
func save_state() -> void:
 var f := FileAccess.open(SAVE, FileAccess.WRITE)
 if f:
  f.store_string(JSON.stringify({"discovered":discovered,"collected":collected,"slide_file":slide_file}))
func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_CLOSE_REQUEST: save_state()
