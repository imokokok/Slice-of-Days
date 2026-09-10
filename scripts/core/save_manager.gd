extends Node

const SAVE_PATH := "user://solmere_save.json"
const LEGACY_SAVE_PATH := "user://vertical_slice_save.json"
const PREVIOUS_PROJECT_DIR := "100game"


func has_save(path := SAVE_PATH) -> bool:
	if FileAccess.file_exists(path):
		return true
	if path != SAVE_PATH:
		return false
	for candidate in _legacy_candidates():
		if FileAccess.file_exists(candidate):
			return true
	return false


func save_game(path := SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(GameState.to_save_data(), "\t"))
	return true


func load_game(path := SAVE_PATH) -> bool:
	var source_path: String = path
	if path == SAVE_PATH and not FileAccess.file_exists(path):
		for candidate in _legacy_candidates():
			if FileAccess.file_exists(candidate):
				source_path = candidate
				break
	if not FileAccess.file_exists(source_path):
		return false
	var file := FileAccess.open(source_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	GameState.load_save_data(parsed)
	if source_path != SAVE_PATH:
		save_game(SAVE_PATH)
	return true


func _legacy_candidates() -> Array[String]:
	var current_user_dir := ProjectSettings.globalize_path(SAVE_PATH).get_base_dir()
	var app_userdata_dir := current_user_dir.get_base_dir()
	var previous_dir := app_userdata_dir.path_join(PREVIOUS_PROJECT_DIR)
	return [
		LEGACY_SAVE_PATH,
		previous_dir.path_join("solmere_save.json"),
		previous_dir.path_join("vertical_slice_save.json"),
	]
