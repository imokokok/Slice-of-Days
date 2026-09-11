extends Node

const SCHEDULE_PATH := "res://data/npcs/demo_npcs.json"

var residents: Dictionary = {}


func _ready() -> void:
	load_schedule_data(SCHEDULE_PATH)


func load_schedule_data(path: String) -> void:
	residents.clear()
	if not FileAccess.file_exists(path):
		push_warning("Schedule data not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid schedule data: %s" % path)
		return
	for resident in expand_resident_rows(parsed):
		residents[str(resident.get("id", ""))] = resident


func expand_resident_rows(data: Dictionary) -> Array:
	var result: Array = data.get("residents", []).duplicate(true)
	var generated: Dictionary = data.get("generated_roster", {})
	var names: Array = generated.get("display_names", [])
	var patterns: Array = generated.get("schedule_patterns", [])
	if names.is_empty() or patterns.is_empty():
		return result
	var start_index := int(generated.get("start_index", result.size() + 1))
	var id_prefix := str(generated.get("id_prefix", "town_resident"))
	for name_index in names.size():
		var resident_number := start_index + name_index
		var resident_id := "%s_%03d" % [id_prefix, resident_number]
		var pattern: Array = patterns[name_index % patterns.size()]
		var schedule: Array = []
		for activity_index in pattern.size():
			var activity: Dictionary = pattern[activity_index].duplicate(true)
			activity["id"] = "%s_slot_%d" % [resident_id, activity_index + 1]
			schedule.append(activity)
		result.append({
			"id": resident_id,
			"display_name": str(names[name_index]),
			"draft": true,
			"generated": true,
			"schedule": schedule,
		})
	return result


func activity_at(resident_id: String, day: int, minute: int) -> Dictionary:
	if not residents.has(resident_id):
		return {}
	var resident: Dictionary = residents[resident_id]
	for activity in resident.get("schedule", []):
		var days: Array = activity.get("days", [])
		var start := int(activity.get("start", 0))
		var end := int(activity.get("end", 0))
		var day_matches := false
		for scheduled_day in days:
			if int(scheduled_day) == day:
				day_matches = true
				break
		if day_matches and minute >= start and minute < end:
			return activity
	return {}


func residents_at(location_id: String, day: int, minute: int) -> Array[String]:
	var result: Array[String] = []
	for resident_id in residents:
		var activity := activity_at(resident_id, day, minute)
		if str(activity.get("location", "")) == location_id:
			result.append(resident_id)
	return result


func known_schedule_for(resident_id: String, known_activity_ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not residents.has(resident_id):
		return result
	for activity in residents[resident_id].get("schedule", []):
		if known_activity_ids.has(str(activity.get("id", ""))):
			result.append(activity)
	return result


func activity_by_id(activity_id: String) -> Dictionary:
	for resident_id in residents:
		var resident: Dictionary = residents[resident_id]
		for activity in resident.get("schedule", []):
			if str(activity.get("id", "")) == activity_id:
				var result: Dictionary = activity.duplicate(true)
				result["resident_id"] = str(resident_id)
				result["resident_name"] = str(resident.get("display_name", resident_id))
				return result
	return {}
