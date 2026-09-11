extends Node

const PROFILE_PATH := "res://data/npcs/core_residents.json"

var profiles: Dictionary = {}


func _ready() -> void:
	load_profile_data(PROFILE_PATH)


func load_profile_data(path: String) -> bool:
	profiles.clear()
	if not FileAccess.file_exists(path):
		push_warning("Resident profile data not found: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid resident profile data: %s" % path)
		return false
	for row in parsed.get("profiles", []):
		var resident_id := str(row.get("id", ""))
		if not resident_id.is_empty():
			profiles[resident_id] = row.duplicate(true)
	return not profiles.is_empty()


func profile_for(resident_id: String) -> Dictionary:
	return (profiles.get(resident_id, {}) as Dictionary).duplicate(true)


func is_core(resident_id: String) -> bool:
	return profiles.has(resident_id)


func town_role(resident_id: String) -> String:
	return str(profiles.get(resident_id, {}).get("town_role", ""))


func role_lens(resident_id: String, role := "") -> String:
	var target_role := role if not role.is_empty() else GameState.current_role
	return str(profiles.get(resident_id, {}).get("role_lens", {}).get(target_role, ""))


func ambient_line(resident_id: String, role := "", salt := 0) -> String:
	var target_role := role if not role.is_empty() else GameState.current_role
	var lines: Array = profiles.get(resident_id, {}).get("ambient_lines", {}).get(target_role, [])
	if lines.is_empty():
		return ""
	return str(lines[posmod(salt, lines.size())])
