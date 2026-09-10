extends Node

signal relationship_changed(role: String, resident_id: String)


func ensure_resident(resident_id: String) -> Dictionary:
	if resident_id.is_empty():
		return {}
	if not GameState.relationships.has(resident_id):
		GameState.relationships[resident_id] = {
			"encounters": 0,
			"flags": [],
			"confirmation": "unknown",
			"last_day": 0,
			"last_event": "",
		}
	return GameState.relationships[resident_id]


func record_encounter(resident_id: String, event_id := "", flags: Array = []) -> void:
	var state := ensure_resident(resident_id)
	if state.is_empty():
		return
	state["encounters"] = int(state.get("encounters", 0)) + 1
	state["last_day"] = GameState.current_day
	state["last_event"] = event_id
	var stored_flags: Array = state.get("flags", [])
	for flag in flags:
		var value := str(flag)
		if not value.is_empty() and not stored_flags.has(value):
			stored_flags.append(value)
	state["flags"] = stored_flags
	GameState.relationships[resident_id] = state
	GameState.meet_resident(resident_id)
	GameState.commit_active_role_state()
	relationship_changed.emit(GameState.current_role, resident_id)
	GameState.state_changed.emit()


func add_flags(resident_id: String, flags: Array) -> void:
	var state := ensure_resident(resident_id)
	if state.is_empty():
		return
	var stored_flags: Array = state.get("flags", [])
	for flag in flags:
		var value := str(flag)
		if not value.is_empty() and not stored_flags.has(value):
			stored_flags.append(value)
	state["flags"] = stored_flags
	state["last_day"] = GameState.current_day
	GameState.relationships[resident_id] = state
	GameState.commit_active_role_state()
	relationship_changed.emit(GameState.current_role, resident_id)
	GameState.state_changed.emit()


func set_confirmation(resident_id: String, status: String) -> void:
	if not ["unknown", "pending", "granted", "refused", "withdrawn"].has(status):
		push_warning("Unsupported confirmation status: %s" % status)
		return
	var state := ensure_resident(resident_id)
	if state.is_empty():
		return
	state["confirmation"] = status
	state["last_day"] = GameState.current_day
	GameState.relationships[resident_id] = state
	if status == "granted":
		GameState.add_confirmation(resident_id)
	elif status == "withdrawn":
		GameState.remove_confirmation(resident_id)
	GameState.commit_active_role_state()
	relationship_changed.emit(GameState.current_role, resident_id)
	GameState.state_changed.emit()


func confirmation_status(resident_id: String) -> String:
	return str(ensure_resident(resident_id).get("confirmation", "unknown"))


func has_flag(resident_id: String, flag: String) -> bool:
	return ensure_resident(resident_id).get("flags", []).has(flag)


func summary(resident_id: String) -> Dictionary:
	return ensure_resident(resident_id).duplicate(true)
