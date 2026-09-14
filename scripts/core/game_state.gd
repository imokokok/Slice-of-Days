extends Node

signal state_changed
signal message_posted(message: String)
signal role_changed(role: String)

const REAL_SECONDS_PER_GAME_MINUTE := 4.0
const SAVE_VERSION := 5
const CALENDAR_PATH := "res://data/story/calendar.json"

var current_role := "A"
var current_day := 1
var current_minute := 9 * 60
var clock_remainder := 0.0
var money := 1000
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
var inventory: Dictionary = {}
var money_ledger: Array[Dictionary] = []
var completed_commitments: Array[String] = []

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
		"starting_budget_version": 2,
		"chapter_index": 0,
		"chapter_start_role": start_role if role_states.has(start_role) else "A",
		"completed_chapters": [],
		"completed_transitions": [],
		"seen_openings": [],
		"world_artifacts": {},
		"credited_record_ids": [],
		"game_complete": false,
	}
	_load_role_state(str(shared_state.chapter_start_role))


func _default_role_state(role: String) -> Dictionary:
	var schedule := schedule_for(role, 1)
	return {
		"day": 1,
		"minute": int(schedule.get("start", 9 * 60)),
		"money": int(schedule.get("starting_money", 1000 if role == "A" else 160)),
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
		"inventory": {},
		"money_ledger": [],
		"completed_commitments": [],
	}


func commit_active_role_state() -> void:
	if current_role.is_empty():
		return
	role_states[current_role] = {
		"day": current_day,
		"minute": current_minute,
		"clock_remainder": clock_remainder,
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
		"inventory": inventory.duplicate(true),
		"money_ledger": money_ledger.duplicate(true),
		"completed_commitments": completed_commitments.duplicate(),
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
		clock_remainder = 0.0
		current_location = "residence" if role == "A" else "dorm"
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
	clock_remainder = clampf(float(data.get("clock_remainder", 0.0)), 0.0, REAL_SECONDS_PER_GAME_MINUTE)
	money = int(data.get("money", 1000 if role == "A" else 160))
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
	inventory = data.get("inventory", {}).duplicate(true)
	money_ledger.assign(data.get("money_ledger", []))
	completed_commitments.assign(data.get("completed_commitments", []))
	residency_confirmations = confirmed_residents.size()


func schedule_for(role: String, day: int) -> Dictionary:
	var defaults: Dictionary = calendar_data.get("default_role_schedules", {})
	var result: Dictionary = defaults.get(role, {
		"start": 540,
		"blocks": [[540, 1260]],
		"starting_money": 1000 if role == "A" else 160,
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


func commitments_for_day(role := "", day := -1) -> Array[Dictionary]:
	var target_role := current_role if role.is_empty() else role
	var target_day := current_day if day < 0 else day
	var result: Array[Dictionary] = []
	for raw in schedule_for(target_role, target_day).get("commitments", []):
		if raw is Dictionary:
			result.append((raw as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("start", 0)) < int(b.get("start", 0)))
	return result


func next_commitment() -> Dictionary:
	for commitment in commitments_for_day():
		if completed_commitments.has(_commitment_token(commitment)):
			continue
		if current_minute <= int(commitment.get("end", 0)):
			return commitment
	return {}


func current_time_guidance() -> String:
	var remaining := current_block_remaining()
	var next := next_commitment()
	if not next.is_empty() and bool(next.get("auto_advance", false)):
		return "%s空闲 %d分钟 · %s—%s %s已预留" % ["整块" if remaining >= 90 else "碎片", remaining, _minute_text(int(next.get("start", 0))), _minute_text(int(next.get("end", 0))), str(next.get("label", "固定习惯"))]
	if bool(shared_state.get("pending_commitment", false)) and not next.is_empty():
		return "%s 到了 · 去%s开始（%d分钟）" % [str(next.get("label", "工作")), str(next.get("location_label", "指定地点")), int(next.get("end", 0)) - current_minute]
	if not next.is_empty():
		var return_by := int(next.get("return_by", next.get("start", 0)))
		if current_minute <= return_by:
			if current_location == str(next.get("location", "")):
				return "%s空闲 %d分钟 · 已在%s · %s开始" % ["整块" if remaining >= 90 else "碎片", remaining, str(next.get("location_label", "指定地点")), _minute_text(int(next.get("start", 0)))]
			return "%s空闲 %d分钟 · %s前到%s · %s开始" % ["整块" if remaining >= 90 else "碎片", remaining, _minute_text(return_by), str(next.get("location_label", "指定地点")), _minute_text(int(next.get("start", 0)))]
	var sleep_at := int(schedule_for(current_role, current_day).get("sleep_at", 1320))
	return "%s空闲 %d分钟 · %s休息" % ["整块" if remaining >= 90 else "碎片", remaining, _minute_text(sleep_at)]


## Shared by street and indoor exploration; paused scenes do not feed the clock.
func advance_world_clock(real_seconds: float) -> void:
	if real_seconds <= 0.0 or not is_finite(real_seconds): return
	if bool(shared_state.get("pending_commitment", false)):
		return
	# Fragmented schedules contain unavailable gaps. Natural world time may reach
	# a block boundary, but must never leak through it.
	if current_block_remaining() <= 0:
		if not advance_to_next_free_block():
			clock_remainder = 0.0
			return
	var seconds_per_minute := float(calendar_data.get("real_seconds_per_game_minute", REAL_SECONDS_PER_GAME_MINUTE))
	seconds_per_minute = maxf(seconds_per_minute, 0.1)
	clock_remainder += real_seconds
	var minutes := int(floor((clock_remainder + 0.0000001) / seconds_per_minute))
	if minutes == 0: return
	var usable_minutes := mini(minutes, current_block_remaining())
	clock_remainder = maxf(0.0, clock_remainder - usable_minutes * seconds_per_minute)
	spend_time(usable_minutes)
	if usable_minutes < minutes:
		# Time spent during an unavailable gap is not carried into the next block.
		clock_remainder = 0.0

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
	return can_fit_at(current_role, current_day, current_minute, minutes)


func can_fit_at(role: String, day: int, minute: int, minutes: int) -> bool:
	if minutes < 0:
		return false
	for block in schedule_for(role, day).get("blocks", []):
		var start := int(block[0])
		var end := int(block[1])
		if minute >= start and minute + minutes <= end:
			return true
	return false


func current_block_remaining() -> int:
	for block in active_time_blocks():
		if current_minute >= int(block[0]) and current_minute < int(block[1]):
			return int(block[1]) - current_minute
	return 0


func advance_to_next_free_block() -> bool:
	var commitment := _commitment_due_before_next_block()
	if not commitment.is_empty():
		if bool(commitment.get("auto_advance", false)):
			var result := complete_next_commitment()
			return bool(result.get("ok", false)) and current_block_remaining() > 0
		var required_location := str(commitment.get("location", ""))
		if required_location.is_empty() or current_location == required_location:
			shared_state["pending_commitment"] = true
			commit_active_role_state()
			state_changed.emit()
			return false
		_miss_commitment(commitment)
	for block in active_time_blocks():
		if current_minute < int(block[0]):
			current_minute = int(block[0])
			refresh_appointments()
			commit_active_role_state()
			state_changed.emit()
			return true
	return false


func _commitment_due_before_next_block() -> Dictionary:
	for commitment in commitments_for_day():
		if completed_commitments.has(_commitment_token(commitment)):
			continue
		var return_by := int(commitment.get("return_by", commitment.get("start", 0)))
		if current_minute >= return_by and current_minute <= int(commitment.get("end", 0)):
			return commitment
	return {}


func complete_next_commitment() -> Dictionary:
	var commitment := next_commitment()
	if commitment.is_empty():
		return {"ok": false, "message": "今天已经没有待处理的固定工作。"}
	var required_location := str(commitment.get("location", ""))
	if not required_location.is_empty() and current_location != required_location:
		return {"ok": false, "message": "需要先到%s。" % str(commitment.get("location_label", "指定地点"))}
	var commitment_id := _commitment_token(commitment)
	if completed_commitments.has(commitment_id):
		return {"ok": false, "message": "这段工作已经完成。"}
	var return_by := int(commitment.get("return_by", commitment.get("start", 0)))
	if current_minute < return_by:
		return {"ok": false, "message": "%s前回到电脑即可。现在还有%d分钟可安排。" % [_minute_text(return_by), return_by - current_minute]}
	if current_minute > int(commitment.get("start", 0)) + int(commitment.get("late_grace", 10)):
		_miss_commitment(commitment)
		return {"ok": false, "message": "已经错过这段工作的开始时间。"}
	var minutes := maxi(0, int(commitment.get("end", current_minute)) - current_minute)
	current_minute += minutes
	clock_remainder = 0.0
	refresh_appointments()
	completed_commitments.append(commitment_id)
	shared_state.erase("pending_commitment")
	var payment := int(commitment.get("pay", 0))
	if payment > 0:
		earn_money(payment, str(commitment.get("label", "工作收入")))
	var commitment_kind := str(commitment.get("kind", "work"))
	var journal_text := "%s · 用时%d分钟" % [str(commitment.get("label", "完成日程")), minutes]
	if payment > 0:
		journal_text += " · 收入%d元" % payment
	add_journal_entry({"id": "commitment_%s" % commitment_id, "kind": commitment_kind, "text": journal_text})
	commit_active_role_state()
	state_changed.emit()
	var message := "完成%s，用时%d分钟。" % [str(commitment.get("label", "日程")), minutes]
	if payment > 0:
		message = "完成%s，用时%d分钟，收入%d元。" % [str(commitment.get("label", "工作")), minutes, payment]
	return {"ok": true, "minutes": minutes, "payment": payment, "message": message}


func _miss_commitment(commitment: Dictionary) -> void:
	var commitment_id := _commitment_token(commitment)
	if completed_commitments.has(commitment_id):
		return
	completed_commitments.append(commitment_id)
	shared_state.erase("pending_commitment")
	add_journal_entry({"id": "missed_commitment_%s" % commitment_id, "kind": "missed_work", "text": "错过固定日程：%s。今天没有获得这笔收入。" % str(commitment.get("label", "工作"))})


func _commitment_token(commitment: Dictionary) -> String:
	return "d%d_%s" % [current_day, str(commitment.get("id", "commitment"))]


func spend_money(amount: int, reason := "消费") -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	_record_money(-amount, reason)
	commit_active_role_state()
	state_changed.emit()
	return true


func earn_money(amount: int, reason := "收入") -> void:
	if amount <= 0:
		return
	money += amount
	_record_money(amount, reason)
	commit_active_role_state()
	state_changed.emit()


func _record_money(amount: int, reason: String) -> void:
	money_ledger.append({"day": current_day, "minute": current_minute, "amount": amount, "reason": reason, "balance": money})
	if money_ledger.size() > 80:
		money_ledger = money_ledger.slice(money_ledger.size() - 80)


func buy_item(item: Dictionary) -> Dictionary:
	var item_id := str(item.get("id", ""))
	var price := int(item.get("price", 0))
	var minutes := int(item.get("minutes", 5))
	if item_id.is_empty() or price <= 0:
		return {"ok": false, "message": "这件商品暂时无法结算。"}
	if not can_fit_now(minutes):
		return {"ok": false, "message": "当前空闲时间不足，先处理接下来的日程。"}
	if money < price:
		return {"ok": false, "message": "还差%d元。" % (price - money)}
	if not spend_money(price, "购买%s" % str(item.get("name", item_id))):
		return {"ok": false, "message": "余额不足。"}
	inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	use_free_time(minutes)
	add_journal_entry({"id": "purchase_%s_%d_%d" % [item_id, current_day, current_minute], "kind": "purchase", "text": "在%s买了%s · %d元" % [str(item.get("shop_name", "小镇商店")), str(item.get("name", item_id)), price]})
	commit_active_role_state()
	state_changed.emit()
	return {"ok": true, "message": "买下%s，花费%d元。余额%d元。" % [str(item.get("name", item_id)), price, money]}


func consume_inventory(item_ids: Array[String]) -> Array[String]:
	var consumed: Array[String] = []
	for item_id in item_ids:
		var count := int(inventory.get(item_id, 0))
		if count <= 0:
			continue
		inventory[item_id] = count - 1
		if int(inventory[item_id]) <= 0:
			inventory.erase(item_id)
		consumed.append(item_id)
	commit_active_role_state()
	return consumed


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


func credit_record_once(record_id: String, payment: int, record: Dictionary = {}) -> bool:
	if record_id.is_empty() or payment <= 0:
		return false
	var credited: Array = shared_state.get("credited_record_ids", [])
	if credited.has(record_id):
		return false
	credited.append(record_id)
	shared_state["credited_record_ids"] = credited
	money += payment
	_record_money(payment, "唱片《%s》授权费" % str(record.get("title", "未命名唱片")))
	var artifact := {
		"id": record_id,
		"title": str(record.get("title", "未命名唱片")),
		"artist": str(record.get("artist", current_role)),
		"kind": "record",
		"created_by": current_role,
		"day": current_day,
		"payment": payment,
	}
	add_artifact("records", artifact, true)
	add_journal_entry({
		"id": "record_%s" % record_id,
		"kind": "work",
		"text": "唱片《%s》被放进本地唱片架，获得 %d 元录音授权费。" % [artifact.title, payment],
	})
	commit_active_role_state()
	state_changed.emit()
	return true


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


func _minute_text(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


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
		# Modern saves started A at 300. Add only the missing starting capital;
		# never replace earned/spent balances or pay the adjustment twice.
		if int(shared_state.get("starting_budget_version", 1)) < 2:
			if int(data.get("save_version", 0)) >= 4 and role_states.has("A"):
				var a_state: Dictionary = role_states.A
				var adjustment := int(schedule_for("A", 1).get("starting_money", 1000)) - 300
				a_state.money = int(a_state.get("money", 300)) + adjustment
				var ledger: Array = a_state.get("money_ledger", []).duplicate(true)
				ledger.append({"day":int(a_state.get("day", 1)), "minute":int(a_state.get("minute", 480)), "amount":adjustment, "reason":"初始资金调整", "balance":a_state.money})
				a_state.money_ledger = ledger
			shared_state["starting_budget_version"] = 2
		for role in ["A", "B"]:
			if not role_states.has(role):
				role_states[role] = _default_role_state(role)
		_load_role_state(str(data.get("current_role", "A")))
	else:
		_migrate_legacy_save(data)
	var location_aliases := {"cafeteria":"night_market", "theatre":"print_shop", "studio":"print_shop", "old_station":"bus_stop", "court":"town_entrance"}
	current_location = str(location_aliases.get(current_location, current_location))
	shared_state["chapter_start_role"] = "A"
	shared_state["chapter_index"] = current_day - 1
	if int(data.get("save_version", 0)) < 4:
		var roles: Array = calendar_data.get("day_roles", [])
		while current_day < 7 and str(roles[current_day - 1]) != current_role: current_day += 1
		if current_day == 7: shared_state["final_role"] = current_role
		shared_state["chapter_index"] = current_day - 1
		shared_state.erase("street_positions")
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
