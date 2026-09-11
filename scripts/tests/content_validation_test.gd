extends Node

var failures: Array[String] = []


func _ready() -> void:
	var locations := _load_json("res://data/world/locations.json")
	var routes := _load_json("res://data/world/travel_routes.json")
	var residents := _load_json("res://data/npcs/demo_npcs.json")
	var core_residents := _load_json("res://data/npcs/core_residents.json")
	var events := _load_json("res://data/story/events.json")
	var openings := _load_json("res://data/story/day_openings.json")
	var transitions := _load_json("res://data/story/transitions.json")
	var endings := _load_json("res://data/story/endings.json")
	var characters := _load_json("res://data/story/characters.json")
	var modules := _load_json("res://data/gameplay/modules.json")
	var prototypes := _load_json("res://data/gameplay/module_prototypes.json")
	var arcana := _load_json("res://data/tarot/major_arcana.json")
	var tarot_cases := _load_json("res://data/tarot/cases.json")
	var location_ids := _unique_ids(locations.get("locations", []), "location")
	var resident_rows := ScheduleSystem.expand_resident_rows(residents)
	var resident_ids := _unique_ids(resident_rows, "resident")
	var event_ids := _unique_ids(events.get("events", []), "event")
	var module_ids := _unique_ids(modules.get("modules", []), "module")
	_validate_schedules(resident_rows, location_ids)
	_validate_core_residents(core_residents.get("profiles", []), resident_ids)
	if resident_rows.size() != 100:
		failures.append("the graybox roster should expand to exactly 100 residents, got %d" % resident_rows.size())
	_validate_routes(routes.get("edges", []), location_ids)
	_validate_events(events.get("events", []), location_ids, resident_ids, event_ids, module_ids)
	_validate_appointments(events.get("events", []), location_ids, event_ids)
	_validate_day_openings(openings)
	_validate_transitions(transitions)
	_validate_endings(endings, module_ids, prototypes.get("prototypes", []))
	_validate_characters(characters)
	_validate_prototypes(prototypes.get("prototypes", []), module_ids, resident_ids)
	_validate_module_coverage(modules.get("modules", []), prototypes.get("prototypes", []))
	_validate_tarot(arcana.get("cards", []), tarot_cases.get("cases", []))
	if failures.is_empty():
		print("CONTENT VALIDATION PASS: world data, character and core resident profiles, day openings, story events, appointments, chapter transitions, endings, gameplay modules and tarot cases")
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
		var resident_id := str(resident.get("id", ""))
		if str(resident.get("display_name", "")).is_empty():
			failures.append("resident %s needs a display name" % resident_id)
		if typeof(resident.get("draft", false)) != TYPE_BOOL:
			failures.append("resident %s draft marker should be a boolean" % resident_id)
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


func _validate_core_residents(rows: Array, resident_ids: Array[String]) -> void:
	var core_ids := _unique_ids(rows, "core resident profile")
	if core_ids.size() != 12:
		failures.append("core resident profiles should define exactly 12 residents, got %d" % core_ids.size())
	for row in rows:
		var resident_id := str(row.get("id", ""))
		if not resident_ids.has(resident_id):
			failures.append("core resident profile references missing resident %s" % resident_id)
		for field in ["town_role", "public_face", "private_pressure", "recognition_basis", "refusal_basis", "voice", "recurring_image"]:
			if str(row.get(field, "")).is_empty():
				failures.append("core resident %s is missing %s" % [resident_id, field])
		var lenses: Dictionary = row.get("role_lens", {})
		var ambient: Dictionary = row.get("ambient_lines", {})
		for role in ["A", "B"]:
			if str(lenses.get(role, "")).is_empty():
				failures.append("core resident %s is missing the %s role lens" % [resident_id, role])
			if (ambient.get(role, []) as Array).size() < 2:
				failures.append("core resident %s needs at least two %s ambient lines" % [resident_id, role])


func _validate_routes(edges: Array, location_ids: Array[String]) -> void:
	for edge in edges:
		for key in ["from", "to"]:
			var location_id := str(edge.get(key, ""))
			if not location_ids.has(location_id):
				failures.append("route references missing location %s" % location_id)


func _validate_events(rows: Array, location_ids: Array[String], resident_ids: Array[String], event_ids: Array[String], module_ids: Array[String]) -> void:
	for event in rows:
		var event_id := str(event.get("id", ""))
		var presentation: Dictionary = event.get("presentation", {})
		var module_echo: Dictionary = presentation.get("module_echo", {})
		var echo_module_id := str(module_echo.get("module_id", ""))
		if not echo_module_id.is_empty() and not module_ids.has(echo_module_id):
			failures.append("event %s echoes missing module %s" % [event_id, echo_module_id])
		for line in presentation.get("lines", []):
			if line is Dictionary:
				if str(line.get("text", "")).is_empty():
					failures.append("event %s has a dialogue line without text" % event_id)
			elif str(line).is_empty():
				failures.append("event %s has an empty presentation line" % event_id)
		for beat in presentation.get("beats", []):
			if str(beat.get("text", "")).is_empty():
				failures.append("event %s has a staged beat without text" % event_id)
		var image_path := str(presentation.get("image_path", ""))
		if not image_path.is_empty() and not ResourceLoader.exists(image_path):
			failures.append("event %s references missing presentation image %s" % [event_id, image_path])
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
		for forbidden in conditions.get("forbidden_events", []):
			if not event_ids.has(str(forbidden)):
				failures.append("event %s forbids missing event %s" % [event_id, str(forbidden)])
		var launch_module := str(event.get("launch_module", ""))
		if not launch_module.is_empty() and not module_ids.has(launch_module):
			failures.append("event %s launches missing module %s" % [event_id, launch_module])
		_validate_results(event_id, event.get("results", {}), resident_ids, module_ids)
		var choice_ids: Array[String] = []
		for choice in event.get("choices", []):
			var choice_id := str(choice.get("id", ""))
			if choice_id.is_empty() or choice_ids.has(choice_id):
				failures.append("event %s has an empty or duplicated choice id: %s" % [event_id, choice_id])
			else:
				choice_ids.append(choice_id)
			_validate_results("%s/%s" % [event_id, str(choice.get("id", ""))], choice.get("results", {}), resident_ids, module_ids)


func _validate_appointments(rows: Array, location_ids: Array[String], event_ids: Array[String]) -> void:
	var appointment_ids: Array[String] = []
	for event in rows:
		var result_sets: Array[Dictionary] = [event.get("results", {})]
		for choice in event.get("choices", []):
			result_sets.append(choice.get("results", {}))
		for results in result_sets:
			for appointment in results.get("appointments", []):
				var appointment_id := str(appointment.get("id", ""))
				if appointment_id.is_empty() or appointment_ids.has(appointment_id):
					failures.append("appointment has an empty or duplicated id: %s" % appointment_id)
				else:
					appointment_ids.append(appointment_id)
				if not location_ids.has(str(appointment.get("location", ""))):
					failures.append("appointment %s references a missing location" % appointment_id)
				if int(appointment.get("day", 0)) < 1:
					failures.append("appointment %s needs a valid day" % appointment_id)
				if int(appointment.get("end", int(appointment.get("start", 0)) + 120)) <= int(appointment.get("start", 0)):
					failures.append("appointment %s has an invalid time window" % appointment_id)
	for event in rows:
		var required := str(event.get("conditions", {}).get("required_appointment", ""))
		if not required.is_empty() and not appointment_ids.has(required):
			failures.append("event %s requires missing appointment %s" % [str(event.get("id", "")), required])
		if not required.is_empty() and str(event.get("id", "")) != required:
			failures.append("appointment event %s should share the appointment id %s" % [str(event.get("id", "")), required])


func _validate_prototypes(rows: Array, module_ids: Array[String], resident_ids: Array[String]) -> void:
	var seen: Array[String] = []
	for prototype in rows:
		var module_id := str(prototype.get("module_id", ""))
		if not module_ids.has(module_id):
			failures.append("prototype references missing module %s" % module_id)
		if seen.has(module_id):
			failures.append("prototype is duplicated for module %s" % module_id)
		seen.append(module_id)
		var background_path := str(prototype.get("background_path", ""))
		if not background_path.is_empty() and not ResourceLoader.exists(background_path):
			failures.append("prototype %s references missing background %s" % [module_id, background_path])
		_validate_module_interaction(module_id, prototype.get("interaction", {}))
		_validate_choice_token_constraints(module_id, prototype.get("choices", []), prototype.get("interaction", {}))
		for choice in prototype.get("choices", []):
			var label := "%s/%s" % [module_id, str(choice.get("id", ""))]
			_validate_results(label, choice.get("results", {}), resident_ids, module_ids)
			for role in choice.get("results_by_role", {}):
				_validate_results(label + "/" + str(role), choice.get("results_by_role", {})[role], resident_ids, module_ids)


func _validate_module_interaction(module_id: String, interaction: Dictionary) -> void:
	if interaction.is_empty():
		failures.append("prototype %s is missing its interaction board" % module_id)
		return
	if str(interaction.get("prompt", "")).is_empty():
		failures.append("prototype %s interaction needs a prompt" % module_id)
	if not ["ordered", "toggle"].has(str(interaction.get("mode", ""))):
		failures.append("prototype %s interaction uses an unsupported mode" % module_id)
	var minimum := int(interaction.get("min_select", 0))
	var maximum := int(interaction.get("max_select", 0))
	var tokens: Array = interaction.get("tokens", [])
	if minimum <= 0 or maximum < minimum or maximum > tokens.size():
		failures.append("prototype %s interaction has invalid selection limits" % module_id)
	var token_ids: Array[String] = []
	for token in tokens:
		var token_id := str(token.get("id", ""))
		if token_id.is_empty() or token_ids.has(token_id):
			failures.append("prototype %s has an empty or duplicated interaction token" % module_id)
		else:
			token_ids.append(token_id)
		if str(token.get("label", "")).is_empty() or str(token.get("detail", "")).is_empty():
			failures.append("prototype %s token %s needs label and detail" % [module_id, token_id])
	var progress_steps: Array = interaction.get("progress_steps", [])
	if not progress_steps.is_empty():
		if progress_steps.size() < maximum + 1:
			failures.append("prototype %s needs one progress step for each selection count" % module_id)
		for step in progress_steps:
			if str(step).is_empty():
				failures.append("prototype %s has an empty progress step" % module_id)


func _validate_choice_token_constraints(module_id: String, choices: Array, interaction: Dictionary) -> void:
	var token_ids: Array[String] = []
	for token in interaction.get("tokens", []):
		token_ids.append(str(token.get("id", "")))
	for choice in choices:
		var choice_id := str(choice.get("id", ""))
		var required: Array = choice.get("required_tokens", [])
		var forbidden: Array = choice.get("forbidden_tokens", [])
		for token_id_value in required + forbidden:
			var token_id := str(token_id_value)
			if not token_ids.has(token_id):
				failures.append("prototype %s/%s constrains missing token %s" % [module_id, choice_id, token_id])
		for token_id_value in required:
			if forbidden.has(token_id_value):
				failures.append("prototype %s/%s both requires and forbids token %s" % [module_id, choice_id, str(token_id_value)])


func _validate_module_coverage(modules: Array, prototypes: Array) -> void:
	var prototype_ids: Array[String] = []
	for prototype in prototypes:
		prototype_ids.append(str(prototype.get("module_id", "")))
	for module in modules:
		if str(module.get("stage", "")) == "graybox" and not prototype_ids.has(str(module.get("id", ""))):
			failures.append("graybox module %s needs a playable prototype" % str(module.get("id", "")))


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


func _validate_transitions(data: Dictionary) -> void:
	var days: Array = data.get("days", [])
	if days.size() != 7:
		failures.append("transition data should define exactly seven days")
	var seen_days: Array[int] = []
	for row in days:
		var day := int(row.get("day", 0))
		if day < 1 or day > 7 or seen_days.has(day):
			failures.append("transition data has an invalid or duplicated day: %d" % day)
		else:
			seen_days.append(day)
		for kind in ["same_day", "next_day"]:
			_validate_transition_beat("day %d/%s" % [day, kind], row.get(kind, {}))
	_validate_transition_beat("final", data.get("final", {}))


func _validate_day_openings(data: Dictionary) -> void:
	var days: Array = data.get("days", [])
	if days.size() != 7:
		failures.append("day openings should define exactly seven days")
	var seen_days: Array[int] = []
	for row in days:
		var day := int(row.get("day", 0))
		if day < 1 or day > 7 or seen_days.has(day):
			failures.append("day openings have an invalid or duplicated day: %d" % day)
		else:
			seen_days.append(day)
		if str(row.get("theme", "")).is_empty():
			failures.append("day opening %d needs a theme" % day)
		for role in ["A", "B"]:
			var opening: Dictionary = row.get(role, {})
			for field in ["title", "body", "focus", "memory"]:
				if str(opening.get(field, "")).is_empty():
					failures.append("day opening %d/%s is missing %s" % [day, role, field])


func _validate_transition_beat(label: String, beat: Dictionary) -> void:
	for field in ["eyebrow", "title", "body", "instruction", "completion", "motion", "motif"]:
		if str(beat.get(field, "")).is_empty():
			failures.append("transition %s is missing %s" % [label, field])
	if not ["horizontal", "vertical", "diagonal", "insert"].has(str(beat.get("motion", ""))):
		failures.append("transition %s uses an unsupported motion" % label)
	var roles: Dictionary = beat.get("roles", {})
	for role in ["A", "B"]:
		var role_data: Dictionary = roles.get(role, {})
		for field in ["label", "caption", "tint"]:
			if str(role_data.get(field, "")).is_empty():
				failures.append("transition %s/%s is missing %s" % [label, role, field])


func _validate_endings(data: Dictionary, module_ids: Array[String], prototypes: Array) -> void:
	var variants: Dictionary = data.get("variants", {})
	for variant_id in ["both_passed", "a_passed", "b_passed", "neither_passed"]:
		var variant: Dictionary = variants.get(variant_id, {})
		for field in ["title", "subtitle", "closing"]:
			if str(variant.get(field, "")).is_empty():
				failures.append("ending %s is missing %s" % [variant_id, field])
	var role_outcomes: Dictionary = data.get("role_outcomes", {})
	for role in ["A", "B"]:
		for status in ["passed", "failed"]:
			if str(role_outcomes.get(role, {}).get(status, "")).is_empty():
				failures.append("ending role outcome %s/%s is missing" % [role, status])
	if int(data.get("max_echoes", 0)) < 1 or int(data.get("max_echoes", 0)) > 6:
		failures.append("ending max_echoes should be between 1 and 6")
	if str(data.get("fallback_echo", "")).is_empty():
		failures.append("ending fallback_echo is missing")
	var prototype_choice_ids: Dictionary = {}
	for prototype in prototypes:
		var choice_ids: Array[String] = []
		for choice in prototype.get("choices", []):
			choice_ids.append(str(choice.get("id", "")))
		prototype_choice_ids[str(prototype.get("module_id", ""))] = choice_ids
	var echo_ids: Array[String] = []
	for echo in data.get("echoes", []):
		var echo_id := str(echo.get("id", ""))
		if echo_id.is_empty() or echo_ids.has(echo_id):
			failures.append("ending echo has an empty or duplicated id: %s" % echo_id)
		else:
			echo_ids.append(echo_id)
		if str(echo.get("category", "")).is_empty():
			failures.append("ending echo %s is missing its category" % echo_id)
		var text := str(echo.get("text", ""))
		if text.is_empty():
			failures.append("ending echo %s is missing text" % echo_id)
		var role := str(echo.get("role", ""))
		if not role.is_empty() and not ["A", "B"].has(role):
			failures.append("ending echo %s uses invalid role %s" % [echo_id, role])
		var module_id := str(echo.get("module_id", ""))
		var module_choice_id := str(echo.get("module_choice_id", ""))
		if not module_id.is_empty() and not module_ids.has(module_id):
			failures.append("ending echo %s references missing module %s" % [echo_id, module_id])
		if not module_choice_id.is_empty() and module_id.is_empty():
			failures.append("ending echo %s has a module choice without a module" % echo_id)
		elif not module_choice_id.is_empty() and not (prototype_choice_ids.get(module_id, []) as Array).has(module_choice_id):
			failures.append("ending echo %s references missing module choice %s/%s" % [echo_id, module_id, module_choice_id])
		var has_condition := not module_id.is_empty() or not str(echo.get("choice_key", "")).is_empty() or not str(echo.get("journal_id", "")).is_empty() or not str(echo.get("journal_kind", "")).is_empty() or not str(echo.get("artifact_id", "")).is_empty()
		if not has_condition:
			failures.append("ending echo %s needs at least one state condition" % echo_id)
		if (text.contains("{selected_") or text.contains("{module_choice}")) and module_id.is_empty():
			failures.append("ending echo %s uses module placeholders without a module" % echo_id)
		if text.contains("{journal_text}") and str(echo.get("journal_id", "")).is_empty() and str(echo.get("journal_kind", "")).is_empty():
			failures.append("ending echo %s uses journal_text without a journal condition" % echo_id)


func _validate_characters(data: Dictionary) -> void:
	var rows: Array = data.get("characters", [])
	if rows.size() != 2:
		failures.append("character data should define exactly A and B")
	var seen_roles: Array[String] = []
	for raw_row in rows:
		var row: Dictionary = raw_row
		var role := str(row.get("role", ""))
		if not ["A", "B"].has(role) or seen_roles.has(role):
			failures.append("character data has an invalid or duplicated role: %s" % role)
		else:
			seen_roles.append(role)
		if int(row.get("age", 0)) != 25:
			failures.append("character %s should preserve the outline age of 25" % role)
		for field in ["job_title", "job_title_zh", "background", "ambition", "inner_tension", "reason_for_solmere", "work_habit", "life_habit", "visual_direction"]:
			if str(row.get(field, "")).is_empty():
				failures.append("character %s is missing %s" % [role, field])
		if (row.get("memory_motifs", []) as Array).is_empty():
			failures.append("character %s needs at least one memory motif" % role)
	for role in ["A", "B"]:
		if not seen_roles.has(role):
			failures.append("character data is missing role %s" % role)
	var shared: Dictionary = data.get("shared_direction", {})
	for field in ["common_ground", "contrast", "magic_rule"]:
		if str(shared.get(field, "")).is_empty():
			failures.append("shared character direction is missing %s" % field)


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
