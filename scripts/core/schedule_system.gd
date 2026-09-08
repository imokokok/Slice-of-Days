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
	for resident in parsed.get("residents", []):
		residents[str(resident.get("id", ""))] = resident


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
