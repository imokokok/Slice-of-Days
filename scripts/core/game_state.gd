extends Node

signal state_changed
signal message_posted(message: String)

const DAY_END_MINUTE := 24 * 60

var current_day := 1
var current_minute := 13 * 60 + 45
var money := 180
var residency_confirmations := 3
var current_role := "A"
var current_location := "residence"
var completed_events: Array[String] = []
var confirmed_residents: Array[String] = []
var encountered_residents: Array[String] = []
var known_facts: Array[String] = [
	"女人带来了一只空信封。",
	"收信人每晚都会经过夜市。",
]

const ROLE_STARTS := {
	"A": {
		"money": 180,
		"blocks": [[840, 1260]],
		"facts": ["夏透明经常在咖啡馆和公园出现。"],
	},
	"B": {
		"money": 45,
		"blocks": [[840, 870], [920, 960], [1030, 1080], [1140, 1260]],
		"facts": ["夏透明在第1天18:00后可能去公园。", "Mossner下午会在图书馆。"],
	},
}


func spend_time(minutes: int) -> bool:
	if minutes <= 0:
		return true
	current_minute += minutes
	while current_minute >= DAY_END_MINUTE:
		current_minute -= DAY_END_MINUTE
		current_day += 1
	state_changed.emit()
	return true


func use_free_time(minutes: int) -> bool:
	if not can_fit_now(minutes):
		return false
	return spend_time(minutes)


func can_fit_now(minutes: int) -> bool:
	for block in active_time_blocks():
		var start := int(block[0])
		var end := int(block[1])
		if current_minute >= start and current_minute + minutes <= end:
			return true
	return false


func active_time_blocks() -> Array:
	return ROLE_STARTS.get(current_role, ROLE_STARTS["A"]).get("blocks", [])


func current_block_remaining() -> int:
	for block in active_time_blocks():
		if current_minute >= int(block[0]) and current_minute < int(block[1]):
			return int(block[1]) - current_minute
	return 0


func advance_to_next_free_block() -> bool:
	for block in active_time_blocks():
		if current_minute < int(block[0]):
			current_minute = int(block[0])
			state_changed.emit()
			return true
	return false


func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	state_changed.emit()
	return true


func add_fact(fact: String) -> void:
	if fact.is_empty() or known_facts.has(fact):
		return
	known_facts.append(fact)
	state_changed.emit()


func add_confirmation(resident_id: String) -> void:
	if confirmed_residents.has(resident_id):
		return
	confirmed_residents.append(resident_id)
	residency_confirmations += 1
	state_changed.emit()


func mark_event(event_id: String) -> void:
	if not completed_events.has(event_id):
		completed_events.append(event_id)
		state_changed.emit()


func has_event(event_id: String) -> bool:
	return completed_events.has(event_id)


func meet_resident(resident_id: String) -> void:
	if not encountered_residents.has(resident_id):
		encountered_residents.append(resident_id)
		state_changed.emit()


func begin_vertical_slice(role: String) -> void:
	current_role = role if ROLE_STARTS.has(role) else "A"
	current_day = 1
	current_minute = 14 * 60
	var role_data: Dictionary = ROLE_STARTS[current_role]
	money = int(role_data.get("money", 180))
	current_location = "residence"
	residency_confirmations = 3
	completed_events.clear()
	confirmed_residents.clear()
	encountered_residents.clear()
	known_facts.clear()
	for fact in role_data.get("facts", []):
		known_facts.append(str(fact))
	state_changed.emit()


func clock_text() -> String:
	return "%02d:%02d" % [current_minute / 60, current_minute % 60]


func reset_demo() -> void:
	current_day = 1
	current_minute = 13 * 60 + 45
	money = 180
	residency_confirmations = 3
	known_facts = ["女人带来了一只空信封。", "收信人每晚都会经过夜市。"]
	completed_events.clear()
	confirmed_residents.clear()
	encountered_residents.clear()
	state_changed.emit()


func to_save_data() -> Dictionary:
	return {
		"current_role": current_role,
		"current_day": current_day,
		"current_minute": current_minute,
		"money": money,
		"current_location": current_location,
		"residency_confirmations": residency_confirmations,
		"completed_events": completed_events,
		"confirmed_residents": confirmed_residents,
		"encountered_residents": encountered_residents,
		"known_facts": known_facts,
	}


func load_save_data(data: Dictionary) -> void:
	current_role = str(data.get("current_role", "A"))
	current_day = int(data.get("current_day", 1))
	current_minute = int(data.get("current_minute", 840))
	money = int(data.get("money", 180))
	current_location = str(data.get("current_location", "residence"))
	residency_confirmations = int(data.get("residency_confirmations", 3))
	completed_events.assign(data.get("completed_events", []))
	confirmed_residents.assign(data.get("confirmed_residents", []))
	encountered_residents.assign(data.get("encountered_residents", []))
	known_facts.assign(data.get("known_facts", []))
	state_changed.emit()
