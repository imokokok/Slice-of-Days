extends Node

const CHARACTER_PATH := "res://data/story/characters.json"

var profiles: Dictionary = {}
var shared_direction: Dictionary = {}


func _ready() -> void:
	load_character_data(CHARACTER_PATH)


func load_character_data(path: String) -> bool:
	profiles.clear()
	shared_direction.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load character data: %s" % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid character data: %s" % path)
		return false
	for row in parsed.get("characters", []):
		var role := str(row.get("role", ""))
		if not role.is_empty():
			profiles[role] = row.duplicate(true)
	shared_direction = parsed.get("shared_direction", {}).duplicate(true)
	return not profiles.is_empty()


func profile(role := "") -> Dictionary:
	var target := role if not role.is_empty() else GameState.current_role
	return (profiles.get(target, {}) as Dictionary).duplicate(true)


func job_title(role := "") -> String:
	var row := profile(role)
	return str(row.get("job_title_zh", row.get("job_title", "")))


func portrait_path(role := "") -> String:
	return str(profile(role).get("portrait_path", ""))
