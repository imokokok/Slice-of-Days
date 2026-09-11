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
	elif ["withdrawn", "refused"].has(status):
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


func confirmation_request_preview(resident_id: String) -> Dictionary:
	var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
	if resident.is_empty() or not bool(resident.get("draft", false)):
		return {"available": false}
	var state: Dictionary = GameState.relationships.get(resident_id, {})
	if state.is_empty():
		return {"available": false}
	var status := str(state.get("confirmation", "unknown"))
	var encounters := int(state.get("encounters", 0))
	if status == "granted" or status == "withdrawn" or encounters <= 0:
		return {"available": false}
	if status == "refused":
		return {
			"available": encounters >= 2,
			"label": "重新认真询问是否愿意认可（10分钟）",
		}
	if status == "pending":
		return {
			"available": true,
			"label": "问问对方是否考虑好了（10分钟）",
		}
	return {
		"available": true,
		"label": "请求对方确认这段居住（10分钟）",
	}


func request_confirmation(resident_id: String) -> Dictionary:
	var preview := confirmation_request_preview(resident_id)
	if not bool(preview.get("available", false)):
		return {"ok": false, "message": "现在还不适合提出这个请求。"}
	var state := ensure_resident(resident_id)
	var previous := str(state.get("confirmation", "unknown"))
	var encounters := int(state.get("encounters", 0))
	var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
	var name := str(resident.get("display_name", resident_id))
	var next_status := previous
	var message := ""
	if previous == "refused":
		if encounters >= 4:
			next_status = "granted"
			message = "%s看了看之前留下的几次记录，这次愿意写下名字。" % name
		else:
			message = "%s没有改变答复。也许还需要真正一起经历一些事。" % name
	elif encounters >= 3:
		next_status = "granted"
		message = "%s确认这些相处不是一次路过，愿意写下名字。" % name
	elif encounters == 2:
		next_status = "pending"
		message = "%s没有拒绝，但说想再考虑一下。" % name
	else:
		next_status = "refused"
		message = "%s不愿意让一次闲聊立刻变成一份认可。" % name
	add_flags(resident_id, [_request_memory(next_status)])
	set_confirmation(resident_id, next_status)
	return {"ok": true, "status": next_status, "message": message}


func _request_memory(status: String) -> String:
	return {
		"granted": "在几次相处以后认真答应过认可请求",
		"pending": "听过认可请求，但说还需要考虑",
		"refused": "曾拒绝把一次闲聊直接变成认可",
	}.get(status, "谈过一次认可请求")
