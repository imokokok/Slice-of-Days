extends Node

signal chapter_started(chapter: Dictionary)
signal chapter_completed(chapter: Dictionary)
signal journey_completed


func start_new_game(start_role: String = "A") -> void:
	GameState.begin_new_game(start_role)
	GameState.shared_state["chapter_index"] = 0
	GameState.shared_state["chapter_start_role"] = start_role if ["A", "B"].has(start_role) else "A"
	GameState.shared_state["completed_chapters"] = []
	GameState.shared_state["completed_transitions"] = []
	GameState.shared_state["seen_openings"] = []
	GameState.shared_state["game_complete"] = false
	var chapter := current_chapter()
	GameState.switch_to_role(str(chapter.get("role", start_role)), int(chapter.get("day", 1)), true)
	chapter_started.emit(chapter)


func chapter_sequence() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var total_days := int(GameState.calendar_data.get("total_days", 7))
	var first_role := str(GameState.shared_state.get("chapter_start_role", "A"))
	var role_order := [first_role, "B" if first_role == "A" else "A"]
	for day in range(1, total_days + 1):
		for role in role_order:
			result.append({
				"id": "day_%d_%s" % [day, str(role).to_lower()],
				"day": day,
				"role": role,
			})
	return result


func current_chapter() -> Dictionary:
	var sequence := chapter_sequence()
	var index := int(GameState.shared_state.get("chapter_index", 0))
	if index < 0 or index >= sequence.size():
		return {}
	return sequence[index]


func next_chapter() -> Dictionary:
	var sequence := chapter_sequence()
	var index := int(GameState.shared_state.get("chapter_index", 0)) + 1
	if index < 0 or index >= sequence.size():
		return {}
	return sequence[index]


func transition_context() -> Dictionary:
	var current := current_chapter()
	var next := next_chapter()
	return {
		"from": current,
		"to": next,
		"is_final": next.is_empty(),
		"transition_id": "%s_to_%s" % [str(current.get("id", "chapter")), str(next.get("id", "ending"))],
	}


func advance_chapter() -> Dictionary:
	var current := current_chapter()
	if current.is_empty():
		return {"ok": false, "complete": true}
	GameState.commit_active_role_state()
	var completed: Array = GameState.shared_state.get("completed_chapters", [])
	var current_id := str(current.get("id", ""))
	if not completed.has(current_id):
		completed.append(current_id)
	GameState.shared_state["completed_chapters"] = completed
	chapter_completed.emit(current)

	var next_index := int(GameState.shared_state.get("chapter_index", 0)) + 1
	var sequence := chapter_sequence()
	if next_index >= sequence.size():
		GameState.shared_state["game_complete"] = true
		GameState.commit_active_role_state()
		journey_completed.emit()
		return {"ok": true, "complete": true, "chapter": current}

	GameState.shared_state["chapter_index"] = next_index
	var next: Dictionary = sequence[next_index]
	GameState.switch_to_role(str(next.role), int(next.day), true)
	chapter_started.emit(next)
	return {"ok": true, "complete": false, "chapter": next}


func mark_transition_complete(transition_id: String) -> void:
	var completed: Array = GameState.shared_state.get("completed_transitions", [])
	if not transition_id.is_empty() and not completed.has(transition_id):
		completed.append(transition_id)
		GameState.shared_state["completed_transitions"] = completed
		GameState.commit_active_role_state()


func opening_id() -> String:
	var chapter := current_chapter()
	return str(chapter.get("id", ""))


func has_seen_opening(chapter_id := "") -> bool:
	var target := chapter_id if not chapter_id.is_empty() else opening_id()
	return GameState.shared_state.get("seen_openings", []).has(target)


func mark_opening_seen(chapter_id := "") -> void:
	var target := chapter_id if not chapter_id.is_empty() else opening_id()
	if target.is_empty():
		return
	var seen: Array = GameState.shared_state.get("seen_openings", [])
	if not seen.has(target):
		seen.append(target)
		GameState.shared_state["seen_openings"] = seen
		GameState.commit_active_role_state()


func residency_audit(role: String) -> Dictionary:
	GameState.commit_active_role_state()
	var state: Dictionary = GameState.role_states.get(role, {})
	var confirmations: Array = state.get("confirmed_residents", [])
	var relationships: Dictionary = state.get("relationships", {})
	var refused := 0
	var pending := 0
	var withdrawn := 0
	for resident_id in relationships:
		var relationship: Dictionary = relationships[resident_id]
		match str(relationship.get("confirmation", "unknown")):
			"refused":
				refused += 1
			"pending":
				pending += 1
			"withdrawn":
				withdrawn += 1
	return {
		"role": role,
		"confirmed": confirmations.size(),
		"required": 12,
		"passed": confirmations.size() >= 12,
		"refused": refused,
		"pending": pending,
		"withdrawn": withdrawn,
		"completed_events": state.get("completed_events", []).size(),
		"journal_entries": state.get("journal_entries", []).size(),
		"choices": state.get("choice_history", []).size(),
	}


func journey_audit() -> Dictionary:
	return {
		"A": residency_audit("A"),
		"B": residency_audit("B"),
		"game_complete": bool(GameState.shared_state.get("game_complete", false)),
	}
