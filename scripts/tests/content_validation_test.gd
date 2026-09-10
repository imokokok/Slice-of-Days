extends Node

var failures: Array[String] = []


func _ready() -> void:
	var locations := _load_json("res://data/world/locations.json")
	var routes := _load_json("res://data/world/travel_routes.json")
	var residents := _load_json("res://data/npcs/demo_npcs.json")
	var events := _load_json("res://data/story/events.json")
	var modules := _load_json("res://data/gameplay/modules.json")
	var prototypes := _load_json("res://data/gameplay/module_prototypes.json")
	var arcana := _load_json("res://data/tarot/major_arcana.json")
	var tarot_cases := _load_json("res://data/tarot/cases.json")
	var location_ids := _unique_ids(locations.get("locations", []), "location")
	var resident_ids := _unique_ids(residents.get("residents", []), "resident")
	var event_ids := _unique_ids(events.get("events", []), "event")
	var module_ids := _unique_ids(modules.get("modules", []), "module")
	_validate_schedules(residents.get("residents", []), location_ids)
	_validate_routes(routes.get("edges", []), location_ids)
	_validate_events(events.get("events", []), location_ids, resident_ids, event_ids, module_ids)
	_validate_prototypes(prototypes.get("prototypes", []), module_ids, resident_ids)
	_validate_tarot(arcana.get("cards", []), tarot_cases.get("cases", []))
	if failures.is_empty():
		print("CONTENT VALIDATION PASS: world data, story data, gameplay modules and tarot cases")
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


func _validate_tarot(cards: Array, cases: Array) -> void:
	var card_ids := _unique_ids(cards, "tarot card")
	if card_ids.size() != 22:
		failures.append("the major arcana catalog should contain exactly 22 cards")
	var image_ids_by_card: Dictionary = {}
	for raw_card in cards:
		var card: Dictionary = raw_card
		var card_id := str(card.get("id", ""))
		for field in ["number", "name", "name_zh", "theme"]:
			if str(card.get(field, "")).is_empty():
				failures.append("tarot card %s is missing %s" % [card_id, field])
		var images: Array = card.get("images", [])
		if images.size() < 3 or images.size() > 5:
			failures.append("tarot card %s should expose 3–5 readable images" % card_id)
		var image_ids: Array[String] = []
		for raw_image in images:
			var image_data: Dictionary = raw_image
			var image_id := str(image_data.get("id", ""))
			if image_id.is_empty() or image_ids.has(image_id):
				failures.append("tarot card %s has an empty or duplicated image id: %s" % [card_id, image_id])
			else:
				image_ids.append(image_id)
			if str(image_data.get("label", "")).is_empty() or str(image_data.get("keywords", "")).is_empty():
				failures.append("tarot card %s image %s needs a label and keywords" % [card_id, image_id])
		image_ids_by_card[card_id] = image_ids
	var case_ids := _unique_ids(cases, "tarot case")
	for raw_case in cases:
		var case_data: Dictionary = raw_case
		var case_id := str(case_data.get("id", ""))
		var deck: Array = case_data.get("deck", [])
		if deck.size() < 6 or deck.size() > 9:
			failures.append("tarot case %s should use a 6–9 card deck" % case_id)
		var deck_seen: Array[String] = []
		for raw_card_id in deck:
			var card_id := str(raw_card_id)
			if not card_ids.has(card_id):
				failures.append("tarot case %s references missing card %s" % [case_id, card_id])
			elif deck_seen.has(card_id):
				failures.append("tarot case %s repeats card %s in its deck" % [case_id, card_id])
			else:
				deck_seen.append(card_id)
		var opening_draw: Array = case_data.get("opening_draw", [])
		if opening_draw.size() != 3:
			failures.append("tarot case %s should define a three-card opening draw" % case_id)
		for card_id in opening_draw:
			if not deck.has(card_id):
				failures.append("tarot case %s opening draw contains out-of-deck card %s" % [case_id, str(card_id)])
		var solution_groups: Array = case_data.get("solution_groups", [])
		var solution_hints: Array = case_data.get("solution_hints", [])
		if solution_groups.is_empty() or solution_hints.size() != solution_groups.size():
			failures.append("tarot case %s needs one non-spoiler hint per solution group" % case_id)
		var required := int(case_data.get("solution_required", 0))
		if required <= 0 or required > solution_groups.size():
			failures.append("tarot case %s has an invalid solution requirement" % case_id)
		var rule_ids: Array[String] = []
		for raw_rule in case_data.get("readings", []):
			_validate_tarot_rule(raw_rule as Dictionary, case_id, deck, image_ids_by_card, rule_ids, false)
		for raw_rule in case_data.get("cross_readings", []):
			_validate_tarot_rule(raw_rule as Dictionary, case_id, deck, image_ids_by_card, rule_ids, true)
	if case_ids.is_empty():
		failures.append("at least one tarot case is required")


func _validate_tarot_rule(rule: Dictionary, case_id: String, deck: Array, image_ids_by_card: Dictionary, rule_ids: Array[String], is_cross: bool) -> void:
	var rule_id := str(rule.get("id", ""))
	if rule_id.is_empty() or rule_ids.has(rule_id):
		failures.append("tarot case %s has an empty or duplicated rule id: %s" % [case_id, rule_id])
	else:
		rule_ids.append(rule_id)
	if (rule.get("concepts", []) as Array).is_empty() or str(rule.get("fact", "")).is_empty():
		failures.append("tarot rule %s needs semantic concepts and a factual response" % rule_id)
	if is_cross:
		var pair: Array = rule.get("cards", [])
		if pair.size() != 2 or str(pair[0]) == str(pair[1]):
			failures.append("cross reading %s should connect two different cards" % rule_id)
		else:
			for card_id in pair:
				if not deck.has(card_id):
					failures.append("cross reading %s uses out-of-deck card %s" % [rule_id, str(card_id)])
	else:
		var card_id := str(rule.get("card", ""))
		var image_id := str(rule.get("image", ""))
		if not deck.has(card_id):
			failures.append("tarot rule %s uses out-of-deck card %s" % [rule_id, card_id])
		elif not (image_ids_by_card.get(card_id, []) as Array).has(image_id):
			failures.append("tarot rule %s references missing image %s/%s" % [rule_id, card_id, image_id])


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
