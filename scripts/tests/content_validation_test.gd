extends Node

var failures: Array[String] = []


func _ready() -> void:
	var locations := _load_json("res://data/world/locations.json")
	var routes := _load_json("res://data/world/travel_routes.json")
	var residents := _load_json("res://data/npcs/demo_npcs.json")
	var events := _load_json("res://data/story/events.json")
	var modules := _load_json("res://data/gameplay/modules.json")
	var prototypes := _load_json("res://data/gameplay/module_prototypes.json")
	var location_ids := _unique_ids(locations.get("locations", []), "location")
	var resident_ids := _unique_ids(residents.get("residents", []), "resident")
	var event_ids := _unique_ids(events.get("events", []), "event")
	var module_ids := _unique_ids(modules.get("modules", []), "module")
	_validate_schedules(residents.get("residents", []), location_ids)
	_validate_routes(routes.get("edges", []), location_ids)
	_validate_events(events.get("events", []), location_ids, resident_ids, event_ids, module_ids)
	_validate_prototypes(prototypes.get("prototypes", []), module_ids, resident_ids)
	if failures.is_empty():
		print("CONTENT VALIDATION PASS: IDs, schedules, routes, events, residents and module results")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _unique_ids(rows: Array, kind: String) -> Array[String]:
	var result: Array[String] = []
	for row in rows:
		var row_id := str(row.get("id", ""))
		if row_id.is_empty():
			failures.append("%s contains an empty id" % kind)
		elif result.has(row_id):
			failures.append("%s id is duplicated: %s" % [kind, row_id])
		else:
			result.append(row_id)
	return result


func _validate_schedules(rows: Array, location_ids: Array[String]) -> void:
	var activity_ids: Array[String] = []
	for resident in rows:
		for activity in resident.get("schedule", []):
			var activity_id := str(activity.get("id", ""))
			if activity_ids.has(activity_id):
				failures.append("schedule activity id is duplicated: %s" % activity_id)
			activity_ids.append(activity_id)
			var location_id := str(activity.get("location", ""))
			if not location_ids.has(location_id):
				failures.append("schedule %s references missing location %s" % [activity_id, location_id])
			if int(activity.get("start", 0)) >= int(activity.get("end", 0)):
				failures.append("schedule %s has an invalid time range" % activity_id)


func _validate_routes(edges: Array, location_ids: Array[String]) -> void:
	for edge in edges:
		for key in ["from", "to"]:
			var location_id := str(edge.get(key, ""))
			if not location_ids.has(location_id):
				failures.append("route references missing location %s" % location_id)


func _validate_events(rows: Array, location_ids: Array[String], resident_ids: Array[String], event_ids: Array[String], module_ids: Array[String]) -> void:
	for event in rows:
		var event_id := str(event.get("id", ""))
		var conditions: Dictionary = event.get("conditions", {})
		for location_id in conditions.get("locations", []):
			if not location_ids.has(str(location_id)):
				failures.append("event %s references missing location %s" % [event_id, str(location_id)])
		var present := str(conditions.get("resident_present", ""))
		if not present.is_empty() and not resident_ids.has(present):
			failures.append("event %s references missing resident %s" % [event_id, present])
		for required in conditions.get("required_events", []):
			if not event_ids.has(str(required)):
				failures.append("event %s requires missing event %s" % [event_id, str(required)])
		var launch_module := str(event.get("launch_module", ""))
		if not launch_module.is_empty() and not module_ids.has(launch_module):
			failures.append("event %s launches missing module %s" % [event_id, launch_module])
		_validate_results(event_id, event.get("results", {}), resident_ids, module_ids)
		for choice in event.get("choices", []):
			_validate_results("%s/%s" % [event_id, str(choice.get("id", ""))], choice.get("results", {}), resident_ids, module_ids)


func _validate_prototypes(rows: Array, module_ids: Array[String], resident_ids: Array[String]) -> void:
	var seen: Array[String] = []
	for prototype in rows:
		var module_id := str(prototype.get("module_id", ""))
		if not module_ids.has(module_id):
			failures.append("prototype references missing module %s" % module_id)
		if seen.has(module_id):
			failures.append("prototype is duplicated for module %s" % module_id)
		seen.append(module_id)
		for choice in prototype.get("choices", []):
			var label := "%s/%s" % [module_id, str(choice.get("id", ""))]
			_validate_results(label, choice.get("results", {}), resident_ids, module_ids)
			for role in choice.get("results_by_role", {}):
				_validate_results(label + "/" + str(role), choice.get("results_by_role", {})[role], resident_ids, module_ids)


func _validate_results(label: String, results: Dictionary, resident_ids: Array[String], module_ids: Array[String]) -> void:
	for resident_id in results.get("encounters", []):
		if not resident_ids.has(str(resident_id)):
			failures.append("%s encounters missing resident %s" % [label, str(resident_id)])
	for resident_id in results.get("confirmations", {}):
		if not resident_ids.has(str(resident_id)):
			failures.append("%s confirms missing resident %s" % [label, str(resident_id)])
	for resident_id in results.get("relationship_flags", {}):
		if not resident_ids.has(str(resident_id)):
			failures.append("%s flags missing resident %s" % [label, str(resident_id)])
	for module_id in results.get("unlock_modules", []):
		if not module_ids.has(str(module_id)):
			failures.append("%s unlocks missing module %s" % [label, str(module_id)])


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures.append("missing data file: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("invalid JSON data: %s" % path)
		return {}
	return parsed
