extends Node

signal state_changed
signal message_posted(message: String)
signal role_changed(role: String)

const SAVE_VERSION := 3
const CALENDAR_PATH := "res://data/story/calendar.json"

var current_role := "A"
var current_day := 1
var current_minute := 9 * 60
var money := 180
var residency_confirmations := 0
var current_location := "residence"

var completed_events: Array[String] = []
var confirmed_residents: Array[String] = []
var encountered_residents: Array[String] = []
var known_facts: Array[String] = []
var relationships: Dictionary = {}
var journal_entries: Array[Dictionary] = []
var artifacts: Dictionary = {}
var appointments: Array[Dictionary] = []
var known_schedule_entries: Array[String] = []
var module_states: Dictionary = {}
var choice_history: Array[Dictionary] = []

var role_states: Dictionary = {}
var shared_state: Dictionary = {}
var calendar_data: Dictionary = {}


func _ready() -> void:
	calendar_data = _load_json(CALENDAR_PATH)
	if role_states.is_empty():
		_initialize_new_state("A")


func begin_new_game(start_role: String = "A") -> void:
	_initialize_new_state(start_role)
	state_changed.emit()


# Kept as a compatibility entry point for first-stage capture tools.
func begin_vertical_slice(role: String) -> void:
	begin_new_game(role)


func _initialize_new_state(start_role: String) -> void:
	role_states = {
		"A": _default_role_state("A"),
		"B": _default_role_state("B"),
	}
	shared_state = {
		"chapter_index": 0,
		"chapter_start_role": start_role if role_states.has(start_role) else "A",
		"completed_chapters": [],
		"completed_transitions": [],
		"seen_openings": [],
		"world_artifacts": {},
		"game_complete": false,
	}
	_load_role_state(str(shared_state.chapter_start_role))


func _default_role_state(role: String) -> Dictionary:
	var schedule := schedule_for(role, 1)
	return {
		"day": 1,
		"minute": int(schedule.get("start", 9 * 60)),
		"money": int(schedule.get("starting_money", 180 if role == "A" else 45)),
		"location": "residence",
		"completed_events": [],
		"confirmed_residents": [],
		"encountered_residents": [],
		"known_facts": schedule.get("opening_facts", []).duplicate(true),
		"relationships": {},
		"journal_entries": [],
		"artifacts": {},
		"appointments": [],
		"known_schedule_entries": [],
		"module_states": {},
		"choice_history": [],
	}


func commit_active_role_state() -> void:
	if current_role.is_empty():
		return
	role_states[current_role] = {
		"day": current_day,
		"minute": current_minute,
		"money": money,
		"location": current_location,
		"completed_events": completed_events.duplicate(),
		"confirmed_residents": confirmed_residents.duplicate(),
		"encountered_residents": encountered_residents.duplicate(),
		"known_facts": known_facts.duplicate(),
		"relationships": relationships.duplicate(true),
		"journal_entries": journal_entries.duplicate(true),
		"artifacts": artifacts.duplicate(true),
		"appointments": appointments.duplicate(true),
		"known_schedule_entries": known_schedule_entries.duplicate(),
		"module_states": module_states.duplicate(true),
		"choice_history": choice_history.duplicate(true),
	}


func switch_to_role(role: String, day := -1, reset_to_schedule_start := false) -> bool:
	if not role_states.has(role):
		return false
	commit_active_role_state()
	_load_role_state(role)
	if day > 0:
		current_day = day
	if reset_to_schedule_start:
		var schedule := schedule_for(role, current_day)
		current_minute = int(schedule.get("start", 9 * 60))
		current_location = "residence"
		for fact in schedule.get("opening_facts", []):
			add_fact(str(fact), false)
	refresh_appointments()
	commit_active_role_state()
	role_changed.emit(current_role)
	state_changed.emit()
	return true


func _load_role_state(role: String) -> void:
	current_role = role
	var data: Dictionary = role_states.get(role, _default_role_state(role))
	current_day = int(data.get("day", 1))
	current_minute = int(data.get("minute", 9 * 60))
	money = int(data.get("money", 180 if role == "A" else 45))
	current_location = str(data.get("location", "residence"))
	completed_events.assign(data.get("completed_events", []))
	confirmed_residents.assign(data.get("confirmed_residents", []))
	encountered_residents.assign(data.get("encountered_residents", []))
	known_facts.assign(data.get("known_facts", []))
	relationships = data.get("relationships", {}).duplicate(true)
	journal_entries.assign(data.get("journal_entries", []))
	artifacts = data.get("artifacts", {}).duplicate(true)
	appointments.assign(data.get("appointments", []))
	known_schedule_entries.assign(data.get("known_schedule_entries", []))
	module_states = data.get("module_states", {}).duplicate(true)
	choice_history.assign(data.get("choice_history", []))
	residency_confirmations = confirmed_residents.size()


func schedule_for(role: String, day: int) -> Dictionary:
	var defaults: Dictionary = calendar_data.get("default_role_schedules", {})
	var result: Dictionary = defaults.get(role, {
		"start": 540,
		"blocks": [[540, 1260]],
		"starting_money": 180 if role == "A" else 45,
	}).duplicate(true)
	for override in calendar_data.get("day_overrides", []):
		if int(override.get("day", 0)) != day:
			continue
		var roles: Dictionary = override.get("roles", {})
		var role_override: Dictionary = roles.get(role, {})
		for key in role_override:
			result[key] = role_override[key]
	return result


func active_time_blocks() -> Array:
	return schedule_for(current_role, current_day).get("blocks", [])


func spend_time(minutes: int) -> bool:
	if minutes <= 0:
		return true
	current_minute = min(current_minute + minutes, 24 * 60 - 1)
	refresh_appointments()
	commit_active_role_state()
	state_changed.emit()
	return true


func use_free_time(minutes: int) -> bool:
	if not can_fit_now(minutes):
		return false
	return spend_time(minutes)


func can_fit_now(minutes: int) -> bool:
	if minutes < 0:
		return false
	for block in active_time_blocks():
		var start := int(block[0])
		var end := int(block[1])
		if current_minute >= start and current_minute + minutes <= end:
			return true
	return false


func current_block_remaining() -> int:
	for block in active_time_blocks():
		if current_minute >= int(block[0]) and current_minute < int(block[1]):
			return int(block[1]) - current_minute
	return 0


func advance_to_next_free_block() -> bool:
	for block in active_time_blocks():
		if current_minute < int(block[0]):
			current_minute = int(block[0])
			refresh_appointments()
			commit_active_role_state()
			state_changed.emit()
			return true
	return false


func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	commit_active_role_state()
	state_changed.emit()
	return true


func earn_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	commit_active_role_state()
	state_changed.emit()


func add_fact(fact: String, notify := true) -> void:
	if fact.is_empty() or known_facts.has(fact):
		return
	known_facts.append(fact)
	commit_active_role_state()
	if notify:
		state_changed.emit()


func add_confirmation(resident_id: String) -> void:
	if resident_id.is_empty() or confirmed_residents.has(resident_id):
		return
	confirmed_residents.append(resident_id)
	residency_confirmations = confirmed_residents.size()
	commit_active_role_state()
	state_changed.emit()


func remove_confirmation(resident_id: String) -> void:
	confirmed_residents.erase(resident_id)
	residency_confirmations = confirmed_residents.size()
	commit_active_role_state()
	state_changed.emit()


func mark_event(event_id: String) -> void:
	if event_id.is_empty() or completed_events.has(event_id):
		return
	completed_events.append(event_id)
	refresh_appointments()
	commit_active_role_state()
	state_changed.emit()


func has_event(event_id: String) -> bool:
	return completed_events.has(event_id)


func unmark_event(event_id: String) -> void:
	if not completed_events.has(event_id):
		return
	completed_events.erase(event_id)
	commit_active_role_state()
	state_changed.emit()


func meet_resident(resident_id: String) -> void:
	if resident_id.is_empty() or encountered_residents.has(resident_id):
		return
	encountered_residents.append(resident_id)
	commit_active_role_state()
	state_changed.emit()


func add_journal_entry(entry: Dictionary) -> void:
	var entry_id := str(entry.get("id", ""))
	for existing in journal_entries:
		if not entry_id.is_empty() and str(existing.get("id", "")) == entry_id:
			return
	var stored := entry.duplicate(true)
	stored["day"] = int(stored.get("day", current_day))
	stored["role"] = str(stored.get("role", current_role))
	journal_entries.append(stored)
	commit_active_role_state()
	state_changed.emit()


func add_artifact(collection: String, artifact: Dictionary, shared := false) -> void:
	if collection.is_empty():
		return
	var target: Dictionary = shared_state.get("world_artifacts", {}) if shared else artifacts
	var rows: Array = target.get(collection, [])
	var artifact_id := str(artifact.get("id", ""))
	for existing in rows:
		if not artifact_id.is_empty() and str(existing.get("id", "")) == artifact_id:
			return
	rows.append(artifact.duplicate(true))
	target[collection] = rows
	if shared:
		shared_state["world_artifacts"] = target
	else:
		artifacts = target
	commit_active_role_state()
	state_changed.emit()


func add_appointment(appointment: Dictionary) -> void:
	var appointment_id := str(appointment.get("id", ""))
	for existing in appointments:
		if not appointment_id.is_empty() and str(existing.get("id", "")) == appointment_id:
			return
	var stored := appointment.duplicate(true)
	stored["day"] = int(stored.get("day", current_day))
	stored["start"] = int(stored.get("start", current_minute))
	stored["end"] = int(stored.get("end", int(stored.start) + 120))
	stored["status"] = str(stored.get("status", "scheduled"))
	stored["created_day"] = current_day
	stored["created_role"] = current_role
	appointments.append(stored)
	refresh_appointments()
	commit_active_role_state()
	state_changed.emit()


func appointment_by_id(appointment_id: String) -> Dictionary:
	for appointment in appointments:
		if str(appointment.get("id", "")) == appointment_id:
			return appointment
	return {}


func appointment_status(appointment_id: String) -> String:
	return str(appointment_by_id(appointment_id).get("status", "missing"))


func appointments_for_day(day := -1) -> Array[Dictionary]:
	var target_day := current_day if day < 0 else day
	var result: Array[Dictionary] = []
	for appointment in appointments:
		if int(appointment.get("day", 0)) == target_day:
			result.append(appointment)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("start", 0)) < int(b.get("start", 0))
	)
	return result


func next_relevant_appointment() -> Dictionary:
	refresh_appointments()
	var candidates: Array[Dictionary] = []
	for appointment in appointments:
		if ["scheduled", "active"].has(str(appointment.get("status", "scheduled"))):
			candidates.append(appointment)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := int(a.get("day", 0)) * 1440 + int(a.get("start", 0))
		var b_key := int(b.get("day", 0)) * 1440 + int(b.get("start", 0))
		return a_key < b_key
	)
	return candidates[0] if not candidates.is_empty() else {}


func refresh_appointments() -> Array[Dictionary]:
	var changed: Array[Dictionary] = []
	for index in appointments.size():
		var appointment: Dictionary = appointments[index]
		var previous := str(appointment.get("status", "scheduled"))
		var appointment_id := str(appointment.get("id", ""))
		var day := int(appointment.get("day", current_day))
		var start := int(appointment.get("start", 0))
		var end := int(appointment.get("end", start + 120))
		var status := previous
		if completed_events.has(appointment_id):
			status = "completed"
		elif current_day > day or (current_day == day and current_minute >= end):
			status = "missed"
		elif current_day == day and current_minute >= start:
			status = "active"
		else:
			status = "scheduled"
		if status == previous:
			continue
		appointment["status"] = status
		appointments[index] = appointment
		changed.append(appointment)
		if status == "missed":
			_add_missed_appointment_journal(appointment)
	return changed


func _add_missed_appointment_journal(appointment: Dictionary) -> void:
	var appointment_id := str(appointment.get("id", "appointment"))
	var entry_id := "missed_%s" % appointment_id
	for entry in journal_entries:
		if str(entry.get("id", "")) == entry_id:
			return
	journal_entries.append({
		"id": entry_id,
		"kind": "missed_appointment",
		"text": "错过预约：%s。时间没有自动退回。" % str(appointment.get("label", appointment_id)),
		"day": current_day,
		"role": current_role,
	})


func reveal_schedule_entry(activity_id: String) -> void:
	if activity_id.is_empty() or known_schedule_entries.has(activity_id):
		return
	known_schedule_entries.append(activity_id)
	commit_active_role_state()
	state_changed.emit()


func record_choice(event_id: String, choice_id: String, label := "") -> void:
	if event_id.is_empty() or choice_id.is_empty():
		return
	var key := "%s/%s" % [event_id, choice_id]
	for choice in choice_history:
		if str(choice.get("key", "")) == key:
			return
	choice_history.append({
		"key": key,
		"event_id": event_id,
		"choice_id": choice_id,
		"label": label,
		"day": current_day,
		"role": current_role,
	})
	commit_active_role_state()
	state_changed.emit()


func has_choice(key: String) -> bool:
	for choice in choice_history:
		if str(choice.get("key", "")) == key:
			return true
	return false


func clock_text() -> String:
	return "%02d:%02d" % [current_minute / 60, current_minute % 60]


func reset_demo() -> void:
	begin_new_game("A")


func to_save_data() -> Dictionary:
	commit_active_role_state()
	return {
		"save_version": SAVE_VERSION,
		"current_role": current_role,
		"role_states": role_states.duplicate(true),
		"shared_state": shared_state.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("role_states"):
		role_states = data.get("role_states", {}).duplicate(true)
		shared_state = data.get("shared_state", {}).duplicate(true)
		for role in ["A", "B"]:
			if not role_states.has(role):
				role_states[role] = _default_role_state(role)
		_load_role_state(str(data.get("current_role", "A")))
	else:
		_migrate_legacy_save(data)
	commit_active_role_state()
	state_changed.emit()


func _migrate_legacy_save(data: Dictionary) -> void:
	var role := str(data.get("current_role", "A"))
	_initialize_new_state(role)
	current_day = int(data.get("current_day", 1))
	current_minute = int(data.get("current_minute", 540))
	money = int(data.get("money", money))
	current_location = str(data.get("current_location", "residence"))
	completed_events.assign(data.get("completed_events", []))
	confirmed_residents.assign(data.get("confirmed_residents", []))
	encountered_residents.assign(data.get("encountered_residents", []))
	known_facts.assign(data.get("known_facts", []))
	residency_confirmations = confirmed_residents.size()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Data file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON data: %s" % path)
		return {}
	return parsed
