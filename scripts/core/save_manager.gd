extends Node

const SAVE_PATH := "user://solmere_save.json"
const LEGACY_SAVE_PATH := "user://vertical_slice_save.json"
const PREVIOUS_PROJECT_DIR := "100game"
const SLOT_COUNT := 3

var active_slot := 1


func path_for_slot(slot: int) -> String:
	var safe_slot := clampi(slot, 1, SLOT_COUNT)
	return SAVE_PATH if safe_slot == 1 else "user://solmere_save_%d.json" % safe_slot


func set_active_slot(slot: int) -> void:
	active_slot = clampi(slot, 1, SLOT_COUNT)


func has_slot(slot: int) -> bool:
	return has_save(path_for_slot(slot))


func has_any_save() -> bool:
	for slot in range(1, SLOT_COUNT + 1):
		if has_slot(slot):
			return true
	return false


func has_save(path := "") -> bool:
	var target_path := path_for_slot(active_slot) if str(path).is_empty() else str(path)
	if FileAccess.file_exists(target_path):
		return true
	if target_path != SAVE_PATH:
		return false
	for candidate in _legacy_candidates():
		if FileAccess.file_exists(candidate):
			return true
	return false


func save_game(path := "") -> bool:
	var target_path := path_for_slot(active_slot) if str(path).is_empty() else str(path)
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(GameState.to_save_data(), "\t"))
	return true


func load_game(path := "") -> bool:
	var target_path := path_for_slot(active_slot) if str(path).is_empty() else str(path)
	var source_path: String = target_path
	if target_path == SAVE_PATH and not FileAccess.file_exists(target_path):
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
		if target_path == SAVE_PATH:
			save_game(SAVE_PATH)
	return true


func load_slot(slot: int) -> bool:
	set_active_slot(slot)
	return load_game()


func slot_summary(slot: int) -> Dictionary:
	var path := path_for_slot(slot)
	if not FileAccess.file_exists(path):
		if slot == 1:
			for candidate in _legacy_candidates():
				if FileAccess.file_exists(candidate):
					path = candidate
					break
	if not FileAccess.file_exists(path):
		return {"slot": slot, "exists": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"slot": slot, "exists": false}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"slot": slot, "exists": false, "invalid": true}
	var current_role := str(parsed.get("current_role", "A"))
	var role_states: Dictionary = parsed.get("role_states", {})
	var active_state: Dictionary = role_states.get(current_role, parsed)
	var a_state: Dictionary = role_states.get("A", {})
	var b_state: Dictionary = role_states.get("B", {})
	return {
		"slot": slot,
		"exists": true,
		"role": current_role,
		"day": int(active_state.get("day", parsed.get("current_day", 1))),
		"minute": int(active_state.get("minute", parsed.get("current_minute", 540))),
		"a_confirmed": (a_state.get("confirmed_residents", []) as Array).size(),
		"b_confirmed": (b_state.get("confirmed_residents", []) as Array).size(),
		"modified": int(FileAccess.get_modified_time(path)),
	}


func _legacy_candidates() -> Array[String]:
	var current_user_dir := ProjectSettings.globalize_path(SAVE_PATH).get_base_dir()
	var app_userdata_dir := current_user_dir.get_base_dir()
	var previous_dir := app_userdata_dir.path_join(PREVIOUS_PROJECT_DIR)
	return [
		LEGACY_SAVE_PATH,
		previous_dir.path_join("solmere_save.json"),
		previous_dir.path_join("vertical_slice_save.json"),
	]
