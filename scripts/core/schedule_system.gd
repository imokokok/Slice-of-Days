extends Node

const SCHEDULE_PATH := "res://data/npcs/demo_npcs.json"
const STAGING_PATH := "res://data/npcs/resident_staging.json"

var residents: Dictionary = {}
var staging: Dictionary = {}


func _ready() -> void:
	load_schedule_data(SCHEDULE_PATH)
	staging = JSON.parse_string(FileAccess.get_file_as_string(STAGING_PATH))


func staging_for(resident_id: String, activity: Dictionary) -> Dictionary:
	var location := str(activity.get("location", ""))
	var layout: Dictionary = staging.get("locations", {}).get(location, {})
	if layout.is_empty(): return {}
	var space := str(staging.get("activities", {}).get(str(activity.get("id", "")), {}).get("space", layout.get("space", "")))
	var slots: Dictionary = layout.get("outdoor" if space.is_empty() else "indoor", {})
	# Missing staging is not permission to spawn at an arbitrary fallback point.
	if not slots.has(resident_id): return {}
	return {"location":location, "space":space, "x":float(slots[resident_id]), "activity_id":str(activity.get("id", ""))}


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
	# Read the same authored roster without relying on later autoload readiness.
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/core_residents.json"))
	var allowed: Array = cast.get("profiles", []).map(func(row: Dictionary) -> String: return str(row.id))
	var result: Array = []
	for row: Dictionary in data.get("residents", []):
		if allowed.has(str(row.get("id", ""))): result.append(row.duplicate(true))
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
	result.sort_custom(func(a: String, b: String) -> bool: return ResidentProfileSystem.is_core(a) and not ResidentProfileSystem.is_core(b))
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

func mood_at(resident_id: String, day: int, minute: int) -> String:
	return str(activity_at(resident_id,day,minute).get("mood","relaxed"))
