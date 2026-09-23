extends Node

signal relationship_changed(role: String, resident_id: String)

const IDENTITY_STAGES := [
	"unseen",
	"assumes_same_person",
	"notices_inconsistency",
	"suspects_two_people",
	"identity_confirmed",
]


func ensure_resident(resident_id: String) -> Dictionary:
	if not ResidentProfileSystem.is_core(resident_id):
		return {}
	if not GameState.relationships.has(resident_id):
		GameState.relationships[resident_id] = {
			"encounters": 0,
			"flags": [],
			"confirmation": "unknown",
			"last_day": 0,
			"last_event": "",
			"encounter_events": [],
		}
	var stored: Dictionary = GameState.relationships[resident_id]
	if not stored.has("encounter_events"):
		# Older saves remember only their latest source. Retain earned signatures,
		# but do not turn an unverifiable legacy counter into new recognition.
		stored["encounter_events"] = []
		var last := str(stored.get("last_event",""))
		if not last.is_empty(): stored.encounter_events.append(last)
	return stored


func record_encounter(resident_id: String, event_id := "", flags: Array = []) -> void:
	var state := ensure_resident(resident_id)
	if state.is_empty():
		return
	var token: String = event_id if not event_id.is_empty() else "visit_d%d_%s" % [GameState.current_day,GameState.current_location]
	if state.encounter_events.has(token): return
	state.encounter_events.append(token)
	state["encounters"] = int(state.get("encounters", 0)) + 1
	state["last_day"] = GameState.current_day
	state["last_event"] = token
	var stored_flags: Array = state.get("flags", [])
	for flag in flags:
		var value := str(flag)
		if not value.is_empty() and not stored_flags.has(value):
			stored_flags.append(value)
	state["flags"] = stored_flags
	GameState.relationships[resident_id] = state
	GameState.meet_resident(resident_id)
	_record_actual_memory(resident_id,event_id)
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
	else:
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
	# Core residents are confirmed only through authored story events. This
	# generic conversation action is reserved for draft/free-roam residents.
	if resident.is_empty() or not bool(resident.get("draft", false)):
		return {"available": false}
	var state: Dictionary = ensure_resident(resident_id)
	if state.is_empty():
		return {"available": false}
	var status := str(state.get("confirmation", "unknown"))
	var encounters: int = state.get("encounter_events", []).size()
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
	# Repeated greetings or generic visits are not evidence of meaningful exchange.
	var meaningful: Array=state.get("encounter_events",[]).filter(func(id: Variant) -> bool: return not str(id).begins_with("chat_") and not str(id).begins_with("visit_"))
	var encounters: int=meaningful.size()
	var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
	var name := str(resident.get("display_name", resident_id))
	var next_status := previous
	var message := ""
	if previous == "refused":
		if encounters >= 2:
			next_status = "granted"
			message = "%s看了看之前留下的几次记录，这次愿意写下名字。" % name
		else:
			message = "%s没有改变答复。也许还需要真正一起经历一些事。" % name
	elif encounters >= 2:
		next_status = "granted"
		message = "%s确认这些相处不是一次路过，愿意写下名字。" % name
	elif encounters == 1:
		next_status = "pending"
		message = "%s没有拒绝，但说想再考虑一下。" % name
	else:
		next_status = "refused"
		message = "%s不愿意让一次闲聊立刻变成一份认可。" % name
	add_flags(resident_id, [_request_memory(next_status)])
	set_confirmation(resident_id, next_status)
	return {"ok": true, "status": next_status, "message": message}


func request_confirmation_action(resident_id: String, minutes := 10) -> Dictionary:
	var preview := confirmation_request_preview(resident_id)
	if not bool(preview.get("available", false)):
		return {"ok": false, "message": "现在还不适合提出这个请求。"}
	if not GameState.can_fit_now(minutes):
		return {"ok": false, "message": "当前空闲时段不足以进行这次谈话。"}
	var event_id := "confirmation_request_d%d_%s_%s" % [
		GameState.current_day, GameState.current_role.to_lower(), resident_id
	]
	if GameState.has_event(event_id):
		return {"ok": false, "message": "今天已经认真问过一次了。"}
	if not GameState.use_free_time(minutes):
		return {"ok": false, "message": "当前空闲时段不足以进行这次谈话。"}
	var result := request_confirmation(resident_id)
	if not bool(result.get("ok", false)):
		return result
	GameState.mark_event(event_id)
	GameState.add_journal_entry({
		"id": event_id,
		"kind": "confirmation_request",
		"text": str(result.get("message", "这次请求已经被记录。")),
	})
	return result


func _request_memory(status: String) -> String:
	return {
		"granted": "在几次相处以后认真答应过认可请求",
		"pending": "听过认可请求，但说还需要考虑",
		"refused": "曾拒绝把一次闲聊直接变成认可",
	}.get(status, "谈过一次认可请求")

func _default_npc_memory() -> Dictionary:
	return {
		"actual_met_A": false,
		"actual_met_B": false,
		"perceived_same_person": true,
		"identity_stage": "unseen",
		"identity_history": [],
		"identity_evidence": [],
		"memory_flags": {},
	}


func _identity_stage_index(stage: String) -> int:
	var index := IDENTITY_STAGES.find(stage)
	return index if index >= 0 else 0


func _normalize_npc_memory(memory: Dictionary) -> Dictionary:
	var normalized := _default_npc_memory()
	for key in memory:
		normalized[key] = memory[key]
	if not memory.has("identity_stage"):
		if bool(ChapterSystem.story().get("reveal_completed", false)):
			normalized.identity_stage = "identity_confirmed"
		elif not bool(memory.get("perceived_same_person", true)):
			normalized.identity_stage = "suspects_two_people"
		elif bool(memory.get("actual_met_A", false)) and bool(memory.get("actual_met_B", false)):
			normalized.identity_stage = "notices_inconsistency"
		elif bool(memory.get("actual_met_A", false)) or bool(memory.get("actual_met_B", false)):
			normalized.identity_stage = "assumes_same_person"
	var stage := str(normalized.identity_stage)
	normalized.perceived_same_person = stage in ["unseen", "assumes_same_person", "notices_inconsistency"]
	return normalized


func _memory_for_update(npc: String) -> Dictionary:
	var memories: Dictionary = GameState.shared_state.get("npc_memory", {})
	var memory := _normalize_npc_memory(memories.get(npc, {}))
	memories[npc] = memory
	GameState.shared_state["npc_memory"] = memories
	return memory


func _set_identity_stage(memory: Dictionary, target_stage: String, evidence: Dictionary = {}) -> bool:
	if not IDENTITY_STAGES.has(target_stage): return false
	var current := str(memory.get("identity_stage", "unseen"))
	if _identity_stage_index(target_stage) <= _identity_stage_index(current): return false
	memory.identity_stage = target_stage
	memory.perceived_same_person = target_stage in ["unseen", "assumes_same_person", "notices_inconsistency"]
	var history: Array = memory.get("identity_history", [])
	history.append({
		"stage": target_stage,
		"day": GameState.current_day,
		"role": GameState.current_role,
		"evidence": evidence.duplicate(true),
	})
	memory.identity_history = history
	if not evidence.is_empty():
		var evidence_rows: Array = memory.get("identity_evidence", [])
		evidence_rows.append(evidence.duplicate(true))
		memory.identity_evidence = evidence_rows
	return true


func advance_identity_stage(npc: String, target_stage: String, evidence: Dictionary = {}) -> bool:
	if not ResidentProfileSystem.is_core(npc): return false
	var memories: Dictionary = GameState.shared_state.get("npc_memory", {})
	var memory := _normalize_npc_memory(memories.get(npc, {}))
	if not _set_identity_stage(memory, target_stage, evidence): return false
	memories[npc] = memory
	GameState.shared_state["npc_memory"] = memories
	GameState.commit_active_role_state()
	GameState.state_changed.emit()
	return true


func confirm_all_known_identities(evidence: Dictionary = {}) -> void:
	var memories: Dictionary = GameState.shared_state.get("npc_memory", {})
	for npc in memories.keys():
		var memory := _normalize_npc_memory(memories[npc])
		_set_identity_stage(memory, "identity_confirmed", evidence)
		memories[npc] = memory
	GameState.shared_state["npc_memory"] = memories


func identity_stage(npc: String) -> String:
	return str(_memory_for_update(npc).identity_stage)


func _record_actual_memory(npc: String, event_id: String) -> void:
	var memories: Dictionary = GameState.shared_state.get("npc_memory", {})
	var memory := _normalize_npc_memory(memories.get(npc, {}))
	memory["actual_met_" + GameState.current_role] = true
	var flag_id := GameState.current_role + ":" + (event_id if not event_id.is_empty() else "visit")
	memory.memory_flags[flag_id] = true
	if str(memory.identity_stage) == "unseen":
		_set_identity_stage(memory, "assumes_same_person", {"kind":"encounter", "event_id":event_id})
	elif bool(memory.actual_met_A) and bool(memory.actual_met_B) and not bool(ChapterSystem.story().reveal_completed):
		_set_identity_stage(memory, "notices_inconsistency", {"kind":"met_both_roles", "event_id":event_id})
	if bool(ChapterSystem.story().reveal_completed):
		_set_identity_stage(memory, "identity_confirmed", {"kind":"post_reveal_encounter", "event_id":event_id})
	memories[npc] = memory
	GameState.shared_state["npc_memory"] = memories


func npc_memory(npc: String) -> Dictionary:
	GameState.commit_active_role_state()
	var memory := _memory_for_update(npc).duplicate(true)
	for role in ["A","B"]: memory["relationship_"+role]=GameState.role_states.get(role,{}).get("relationships",{}).get(npc,{}).duplicate(true)
	return memory
