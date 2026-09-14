extends Node

signal chapter_started(chapter: Dictionary)
signal chapter_completed(chapter: Dictionary)
signal journey_completed


func start_new_game(_start_role: String = "A") -> void:
	var start_role := "A"
	GameState.begin_new_game(start_role)
	GameState.shared_state["chapter_index"] = 0
	GameState.shared_state["chapter_start_role"] = start_role if ["A", "B"].has(start_role) else "A"
	GameState.shared_state["completed_chapters"] = []
	GameState.shared_state["completed_transitions"] = []
	GameState.shared_state["seen_openings"] = []
	GameState.shared_state["game_complete"] = false
	var chapter := current_chapter()
	GameState.switch_to_role(str(chapter.get("role", start_role)), int(chapter.get("day", 1)), true)
	GameState.current_location = "bus_stop"
	GameState.shared_state["street_layout_version"] = 6
	GameState.shared_state["street_positions"] = {"A_1_main_street":150.0}
	GameState.commit_active_role_state()
	EchoSystem.begin_day()
	chapter_started.emit(chapter)


func chapter_sequence() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var roles: Array = GameState.calendar_data.get("day_roles", ["A","B","B","A","B","A","choice"])
	for index in roles.size():
		var role := str(roles[index])
		if role == "choice": role = str(GameState.shared_state.get("final_role", "choice"))
		result.append({"id":"day_%d_%s" % [index+1,role.to_lower()], "day":index+1, "role":role})
	return result

func choose_final_role(role: String) -> bool:
	if GameState.current_day != 6 or role not in ["A","B"] or not bool(GameState.shared_state.get("sleep_pending",false)): return false
	GameState.shared_state["final_role"] = role
	return true

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
	if str(next_chapter().get("role", "")) == "choice": return {"ok":false,"needs_choice":true}
	EchoSystem.close_day()
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
	EchoSystem.begin_day()
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

func sleep_at_home() -> bool:
	if SceneRouter.active_space_id != ("home_a" if GameState.current_role == "A" else "home_b") or GameState.current_location not in ["residence", "dorm"]:
		return false
	if bool(GameState.shared_state.get("sleep_pending", false)): return false
	var sleep_at := int(GameState.schedule_for(GameState.current_role, GameState.current_day).get("sleep_at", 1320))
	if GameState.current_minute < sleep_at:
		GameState.current_minute = sleep_at
		GameState.clock_remainder = 0.0
	var rollback_snapshot := GameState.to_save_data().duplicate(true)
	GameState.shared_state["sleep_pending"] = true
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("入睡前保存失败"):
		GameState.load_save_data(rollback_snapshot)
		return false
	SceneRouter.chapter_transition()
	return true


func _process(_delta: float) -> void:
	var sleep_at := int(GameState.schedule_for(GameState.current_role, GameState.current_day).get("sleep_at", 1320))
	if GameState.current_minute < sleep_at or SceneRouter.transitioning: return
	if bool(GameState.shared_state.get("sleep_pending", false)) or bool(GameState.shared_state.get("game_complete", false)): return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path not in [SceneRouter.TOWN_DAY, SceneRouter.INTERACTIVE_SPACE]: return
	# Finish any minigame/transition before ending the day on return to exploration.
	GameState.shared_state["sleep_pending"] = true
	GameState.shared_state["midnight_rest"] = true
	GameState.clock_remainder = 0.0
	GameState.commit_active_role_state()
	SaveManager.save_game()
	SceneRouter.chapter_transition()
