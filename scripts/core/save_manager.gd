extends Node

const SAVE_PATH := "user://vertical_slice_save.json"


func has_save(path := SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func save_game(path := SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(GameState.to_save_data(), "\t"))
	return true


func load_game(path := SAVE_PATH) -> bool:
	if not has_save(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	GameState.load_save_data(parsed)
	return true
