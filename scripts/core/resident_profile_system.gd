extends Node

const PROFILE_PATH := "res://data/npcs/core_residents.json"

const GENERIC_AMBIENT := {
	"A": [
		"我还得继续%s。你可以在旁边待一会儿，不用把它变成什么作品。",
		"这件事看着和平时一样，其实每天都有一点地方不同。",
		"下次见到我，我可能已经在做别的了。记得今天就够。",
		"先别帮我总结。把手边这一点做完，我们再说别的。",
	],
	"B": [
		"时间记得没错，不过我今天%s，未必明天也一样。",
		"你可以把这一段写进计划，但先留一个能改的空格。",
		"别因为我在这里，就把这当成约定。聊完再决定下一次。",
		"记录没有问题。问题是记录以后，还能不能允许人改变。",
	],
}

var profiles: Dictionary = {}
var legacy_aliases: Dictionary = {}


func _ready() -> void:
	load_profile_data(PROFILE_PATH)


func load_profile_data(path: String) -> bool:
	profiles.clear()
	if not FileAccess.file_exists(path):
		push_warning("Resident profile data not found: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid resident profile data: %s" % path)
		return false
	legacy_aliases = parsed.get("legacy_aliases", {})
	for row in parsed.get("profiles", []):
		var resident_id := str(row.get("id", ""))
		if not resident_id.is_empty():
			profiles[resident_id] = row.duplicate(true)
	return not profiles.is_empty()


func profile_for(resident_id: String) -> Dictionary:
	return (profiles.get(resident_id, {}) as Dictionary).duplicate(true)


func is_core(resident_id: String) -> bool:
	return profiles.has(resident_id)


func canonical_id(resident_id: String) -> String:
	var value := str(legacy_aliases.get(resident_id, resident_id))
	return value if profiles.has(value) else ""


func topics_for(resident_id: String) -> Array:
	var choices: Array = profiles.get(resident_id, {}).get("topics", []).duplicate(true)
	if GameState.current_role == "B": choices.reverse()
	return choices


func topic_lines(resident_id: String, topic_id: String) -> Array:
	for topic: Dictionary in topics_for(resident_id):
		if str(topic.id) == topic_id: return topic.lines.duplicate()
	return []


func town_role(resident_id: String) -> String:
	var core := str(profiles.get(resident_id, {}).get("town_role", ""))
	if not core.is_empty():
		return core
	var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
	if resident.is_empty():
		return ""
	return "%s，在小镇的日程里维持自己的工作与生活" % str(resident.get("display_name", resident_id))


func role_lens(resident_id: String, role := "") -> String:
	var target_role := role if not role.is_empty() else GameState.current_role
	var core := str(profiles.get(resident_id, {}).get("role_lens", {}).get(target_role, ""))
	if not core.is_empty():
		return core
	if not ScheduleSystem.residents.has(resident_id):
		return ""
	if target_role == "A":
		return "对方会留意A是否愿意参与眼前的小事，而不是只带走一段素材。"
	return "对方会留意B的记录是否给临时变化和拒绝留下位置。"


func ambient_line(resident_id: String, role := "", salt := 0) -> String:
	var target_role := role if not role.is_empty() else GameState.current_role
	var lines: Array = profiles.get(resident_id, {}).get("ambient_lines", {}).get(target_role, [])
	if not lines.is_empty():
		return str(lines[posmod(salt, lines.size())])
	if not ScheduleSystem.residents.has(resident_id):
		return ""
	var generic_lines: Array = GENERIC_AMBIENT.get(target_role, GENERIC_AMBIENT["A"])
	var template := str(generic_lines[posmod(hash(resident_id) + salt, generic_lines.size())])
	var activity := ScheduleSystem.activity_at(resident_id, GameState.current_day, GameState.current_minute)
	var activity_text := str(activity.get("activity", "做手边的事"))
	return template % activity_text if template.contains("%s") else template
