extends Node

signal event_completed(event_id: String, result: Dictionary)

const EVENTS_PATH := "res://data/story/events.json"

var events: Dictionary = {}


func _ready() -> void:
	load_event_data(EVENTS_PATH)


func load_event_data(path: String) -> void:
	events.clear()
	if not FileAccess.file_exists(path):
		push_warning("Event data not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid event data: %s" % path)
		return
	for event in parsed.get("events", []):
		var event_id := str(event.get("id", ""))
		if not event_id.is_empty():
			events[event_id] = event


func available_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event_id in events:
		var event: Dictionary = events[event_id]
		if is_available(event):
			result.append(event)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 100)) < int(b.get("priority", 100))
	)
	return result


func day_leads() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event_id in events:
		var event: Dictionary = events[event_id]
		if not bool(event.get("repeatable", false)) and GameState.has_event(event_id):
			continue
		var conditions: Dictionary = event.get("conditions", {})
		var roles: Array = conditions.get("roles", [])
		if not roles.is_empty() and not roles.has(GameState.current_role):
			continue
		var days: Array = conditions.get("days", [])
		var matches_day := days.is_empty()
		for day in days:
			if int(day) == GameState.current_day:
				matches_day = true
				break
		if not matches_day:
			continue
		var prerequisites_met := true
		for required in conditions.get("required_events", []):
			if not GameState.has_event(str(required)):
				prerequisites_met = false
		for forbidden in conditions.get("forbidden_events", []):
			if GameState.has_event(str(forbidden)):
				prerequisites_met = false
		for fact in conditions.get("required_facts", []):
			if not GameState.known_facts.has(str(fact)):
				prerequisites_met = false
		var required_appointment := str(conditions.get("required_appointment", ""))
		if not required_appointment.is_empty() and not ["scheduled", "active"].has(GameState.appointment_status(required_appointment)):
			prerequisites_met = false
		if not prerequisites_met:
			continue
		var lead := event.duplicate(true)
		lead["window_passed"] = GameState.current_minute >= int(conditions.get("end", 1440))
		result.append(lead)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_conditions: Dictionary = a.get("conditions", {})
		var b_conditions: Dictionary = b.get("conditions", {})
		var a_key := int(a_conditions.get("start", 0)) * 100 + int(a.get("priority", 100))
		var b_key := int(b_conditions.get("start", 0)) * 100 + int(b.get("priority", 100))
		return a_key < b_key
	)
	return result


func is_available(event: Dictionary) -> bool:
	return bool(availability(event).get("ok", false))


func availability(event: Dictionary) -> Dictionary:
	var event_id := str(event.get("id", ""))
	if not bool(event.get("repeatable", false)) and GameState.has_event(event_id):
		return {"ok": false, "reason": "这个事件已经发生过。"}
	var conditions: Dictionary = event.get("conditions", {})
	var roles: Array = conditions.get("roles", [])
	if not roles.is_empty() and not roles.has(GameState.current_role):
		return {"ok": false, "reason": "当前视角不满足条件。"}
	var days: Array = conditions.get("days", [])
	var day_matches := days.is_empty()
	for day in days:
		if int(day) == GameState.current_day:
			day_matches = true
			break
	if not day_matches:
		return {"ok": false, "reason": "当前日期不满足条件。"}
	var locations: Array = conditions.get("locations", [])
	if not locations.is_empty() and not locations.has(GameState.current_location):
		return {"ok": false, "reason": "当前地点不满足条件。"}
	var start := int(conditions.get("start", 0))
	var end := int(conditions.get("end", 24 * 60))
	if GameState.current_minute < start or GameState.current_minute >= end:
		return {"ok": false, "reason": "当前时间不满足条件。"}
	for required in conditions.get("required_events", []):
		if not GameState.has_event(str(required)):
			return {"ok": false, "reason": "还缺少前置经历。"}
	for forbidden in conditions.get("forbidden_events", []):
		if GameState.has_event(str(forbidden)):
			return {"ok": false, "reason": "之前的选择已经关闭了这个事件。"}
	for fact in conditions.get("required_facts", []):
		if not GameState.known_facts.has(str(fact)):
			return {"ok": false, "reason": "还缺少必要信息。"}
	var required_appointment := str(conditions.get("required_appointment", ""))
	if not required_appointment.is_empty():
		var appointment_state := GameState.appointment_status(required_appointment)
		if not ["scheduled", "active"].has(appointment_state):
			return {"ok": false, "reason": "这次预约没有生效，或者已经错过。"}
	var resident_id := str(conditions.get("resident_present", ""))
	if not resident_id.is_empty():
		var present := ScheduleSystem.residents_at(
			GameState.current_location,
			GameState.current_day,
			GameState.current_minute
		)
		if not present.has(resident_id):
			return {"ok": false, "reason": "相关居民此刻不在这里。"}
	return can_pay_cost(event)


func can_pay_cost(event: Dictionary) -> Dictionary:
	return can_pay_cost_data(event.get("cost", {}))


func can_pay_cost_data(cost: Dictionary) -> Dictionary:
	var minutes := int(cost.get("minutes", 0))
	var amount := int(cost.get("money", 0))
	if not GameState.can_fit_now(minutes):
		return {"ok": false, "reason": "当前时间块不足。"}
	if GameState.money < amount:
		return {"ok": false, "reason": "余额不足。"}
	return {"ok": true, "reason": ""}


func trigger(event_id: String, choice_id: String = "") -> Dictionary:
	if not events.has(event_id):
		return {"ok": false, "message": "找不到这个事件。"}
	var event: Dictionary = events[event_id]
	var check := availability(event)
	if not bool(check.get("ok", false)):
		return {"ok": false, "message": str(check.get("reason", "当前条件不满足。"))}
	var choice := _choice_for(event, choice_id)
	if not event.get("choices", []).is_empty() and choice.is_empty():
		return {"ok": false, "message": "需要先选择一种回应。"}
	var cost: Dictionary = _combined_cost(event.get("cost", {}), choice.get("cost", {}))
	var payment := can_pay_cost_data(cost)
	if not bool(payment.get("ok", false)):
		return {"ok": false, "message": str(payment.get("reason", "当前资源不足。"))}
	var amount := int(cost.get("money", 0))
	var minutes := int(cost.get("minutes", 0))
	if amount > 0:
		GameState.spend_money(amount)
	if minutes > 0:
		GameState.use_free_time(minutes)
	apply_results(event_id, event.get("results", {}))
	apply_results(event_id, choice.get("results", {}))
	if not choice.is_empty():
		GameState.record_choice(event_id, str(choice.get("id", "")), str(choice.get("label", "")))
	if not bool(event.get("repeatable", false)):
		GameState.mark_event(event_id)
	var presentation: Dictionary = event.get("presentation", {})
	var choice_presentation: Dictionary = choice.get("presentation", {})
	var launch_module := str(choice.get("launch_module", event.get("launch_module", "")))
	var result := {
		"ok": true,
		"message": str(choice_presentation.get(
			"result",
			presentation.get("result", presentation.get("summary", "事件已经发生。"))
		)),
		"event": event,
		"choice": choice,
		"launch_module": launch_module,
	}
	event_completed.emit(event_id, result)
	return result


func apply_results(event_id: String, results: Dictionary) -> void:
	for completed_id in results.get("completed_events", []):
		GameState.mark_event(str(completed_id))
	for fact in results.get("facts", []):
		GameState.add_fact(str(fact))
	for resident_id in results.get("encounters", []):
		RelationshipSystem.record_encounter(str(resident_id), event_id)
	var relationship_flags: Dictionary = results.get("relationship_flags", {})
	for resident_id in relationship_flags:
		RelationshipSystem.add_flags(str(resident_id), relationship_flags[resident_id])
	var confirmations: Dictionary = results.get("confirmations", {})
	for resident_id in confirmations:
		RelationshipSystem.set_confirmation(str(resident_id), str(confirmations[resident_id]))
	for entry in results.get("journal_entries", []):
		GameState.add_journal_entry(entry)
	for artifact in results.get("artifacts", []):
		GameState.add_artifact(
			str(artifact.get("collection", "misc")),
			artifact.get("data", {}),
			bool(artifact.get("shared", false))
		)
	for appointment in results.get("appointments", []):
		GameState.add_appointment(appointment)
	for activity_id in results.get("reveal_schedule_entries", []):
		GameState.reveal_schedule_entry(str(activity_id))
	for module_id in results.get("unlock_modules", []):
		GameplayModuleSystem.unlock(str(module_id))
	var earnings := int(results.get("money", 0))
	if earnings > 0:
		GameState.earn_money(earnings)


func _choice_for(event: Dictionary, choice_id: String) -> Dictionary:
	if choice_id.is_empty():
		return {}
	for choice in event.get("choices", []):
		if str(choice.get("id", "")) == choice_id:
			return choice
	return {}


func _combined_cost(base: Dictionary, extra: Dictionary) -> Dictionary:
	return {
		"minutes": int(base.get("minutes", 0)) + int(extra.get("minutes", 0)),
		"money": int(base.get("money", 0)) + int(extra.get("money", 0)),
	}
