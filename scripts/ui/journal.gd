extends Control

const LOCATIONS_PATH := "res://data/world/locations.json"
const PAPER := Color("fff8eb")
const PAPER_SOFT := Color("f1dfc7")
const INK := Color("4a342b")
const MUTED := Color("806b5c")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")
const LINE := Color("b88963")

var location_names: Dictionary = {}


func _ready() -> void:
	_load_location_names()
	_build_ui()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("ead9bd"))
	for y in range(110, 900, 34):
		draw_line(Vector2(0, y), Vector2(1600, y), Color("b8a98e", 0.18), 1)


func _build_ui() -> void:
	var title := "A的随身记忆与相册" if GameState.current_role == "A" else "B的计划本"
	_label(self, title, Vector2(45, 24), Vector2(600, 46), 30, INK)
	var job_title := CharacterSystem.job_title(GameState.current_role)
	_label(self, "%s · 第 %d 天 · %s · %d元 · 认可 %d/12" % [job_title, GameState.current_day, GameState.clock_text(), GameState.money, GameState.residency_confirmations], Vector2(48, 70), Vector2(850, 28), 15, MUTED)
	var back := _button(self, "返回小镇", Vector2(1380, 28), Vector2(170, 44), TERRACOTTA)
	back.pressed.connect(SceneRouter.town_day)

	_text_panel(Vector2(38, 125), Vector2(355, 710), "已知事实", _fact_text())
	_text_panel(Vector2(420, 125), Vector2(355, 710), "居民关系", _relationship_text())
	_text_panel(Vector2(802, 125), Vector2(355, 710), "经历与作品", _memory_text())
	_text_panel(Vector2(1184, 125), Vector2(378, 710), "时间与预约", _planning_text())


func _fact_text() -> String:
	if GameState.known_facts.is_empty():
		return "尚无记录。"
	var lines: Array[String] = []
	for fact in GameState.known_facts:
		lines.append("• %s" % fact)
	return "\n\n".join(lines)


func _relationship_text() -> String:
	if GameState.relationships.is_empty():
		return "尚未真正认识任何居民。"
	var lines: Array[String] = []
	for resident_id in GameState.relationships:
		var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
		var state: Dictionary = GameState.relationships[resident_id]
		var status := _confirmation_text(str(state.get("confirmation", "unknown")))
		var flags: Array = state.get("flags", [])
		var town_role := ResidentProfileSystem.town_role(str(resident_id))
		var lens := ResidentProfileSystem.role_lens(str(resident_id), GameState.current_role)
		var profile_text := ""
		if not town_role.is_empty():
			profile_text += "\n%s" % town_role
		if not lens.is_empty():
			profile_text += "\n%s" % lens
		lines.append("%s  ·  %s\n相遇%d次%s%s" % [
			str(resident.get("display_name", resident_id)),
			status,
			int(state.get("encounters", 0)),
			profile_text,
			"\n" + "、".join(flags) if not flags.is_empty() else "",
		])
	return "\n\n".join(lines)


func _memory_text() -> String:
	var lines: Array[String] = []
	if not GameState.choice_history.is_empty():
		lines.append("关键选择")
		for choice in GameState.choice_history:
			lines.append("• 第%d天 · %s" % [
				int(choice.get("day", GameState.current_day)),
				str(choice.get("label", choice.get("choice_id", "未命名选择"))),
			])
	for entry in GameState.journal_entries:
		lines.append("第%d天  %s" % [int(entry.get("day", GameState.current_day)), str(entry.get("text", ""))])
	for collection in GameState.artifacts:
		var rows: Array = GameState.artifacts[collection]
		lines.append("\n%s（%d）" % [str(collection), rows.size()])
		for artifact in rows:
			lines.append("• %s" % str(artifact.get("title", artifact.get("id", "未命名"))))
	var world: Dictionary = GameState.shared_state.get("world_artifacts", {})
	for collection in world:
		var rows: Array = world[collection]
		lines.append("\n公共%s（%d）" % [str(collection), rows.size()])
		for artifact in rows:
			lines.append("• %s" % str(artifact.get("title", artifact.get("id", "未命名"))))
	return "\n\n".join(lines) if not lines.is_empty() else "还没有留下作品或私人记录。"


func _planning_text() -> String:
	var goal := str(GameState.schedule_for(GameState.current_role, GameState.current_day).get("goal", ""))
	var lines: Array[String] = ["本段目标\n%s\n\n今日可行动时间\n%s" % [goal, _block_text()]]
	var leads := EventSystem.day_leads()
	if not leads.is_empty():
		lines.append("\n今日可追踪机会")
		for lead in leads:
			var conditions: Dictionary = lead.get("conditions", {})
			var lead_locations: Array = conditions.get("locations", [])
			var location_id := str(lead_locations[0]) if not lead_locations.is_empty() else ""
			var status := "已过时间窗" if bool(lead.get("window_passed", false)) else "尚可前往"
			lines.append("• %s—%s · %s\n  %s（%s）" % [
				_minute_text(int(conditions.get("start", 0))),
				_minute_text(int(conditions.get("end", 1440))),
				_location_name(location_id),
				str(lead.get("choice_text", lead.get("id", "未命名机会"))),
				status,
			])
	if not GameState.appointments.is_empty():
		lines.append("\n预约")
		for appointment in GameState.appointments:
			lines.append("• [%s] 第%d天 %s—%s\n  %s · %s" % [
				_appointment_status_text(str(appointment.get("status", "scheduled"))),
				int(appointment.get("day", GameState.current_day)),
				_minute_text(int(appointment.get("start", 0))),
				_minute_text(int(appointment.get("end", int(appointment.get("start", 0)) + 120))),
				str(appointment.get("label", "未命名预约")),
				_location_name(str(appointment.get("location", ""))),
			])
	if not GameState.known_schedule_entries.is_empty():
		lines.append("\n已确认的居民日程")
		for activity_id in GameState.known_schedule_entries:
			var activity := ScheduleSystem.activity_by_id(str(activity_id))
			if activity.is_empty():
				lines.append("• %s" % activity_id)
				continue
			lines.append("• %s · %s—%s\n  %s · %s" % [
				str(activity.get("resident_name", activity_id)),
				_minute_text(int(activity.get("start", 0))),
				_minute_text(int(activity.get("end", 0))),
				str(activity.get("activity", "日常活动")),
				_location_name(str(activity.get("location", ""))),
			])
	return "\n".join(lines)


func _load_location_names() -> void:
	if not FileAccess.file_exists(LOCATIONS_PATH):
		return
	var file := FileAccess.open(LOCATIONS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for location in parsed.get("locations", []):
		location_names[str(location.get("id", ""))] = str(location.get("name", ""))


func _location_name(location_id: String) -> String:
	return str(location_names.get(location_id, location_id if not location_id.is_empty() else "未知地点"))


func _block_text() -> String:
	var parts: Array[String] = []
	for block in GameState.active_time_blocks():
		parts.append("%s—%s" % [_minute_text(int(block[0])), _minute_text(int(block[1]))])
	return " / ".join(parts)


func _minute_text(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


func _confirmation_text(status: String) -> String:
	return {
		"unknown": "尚未询问",
		"pending": "仍在考虑",
		"granted": "已经认可",
		"refused": "拒绝认可",
		"withdrawn": "撤回认可",
	}.get(status, status)


func _appointment_status_text(status: String) -> String:
	return {
		"scheduled": "待赴约",
		"active": "可赴约",
		"completed": "已完成",
		"missed": "已错过",
	}.get(status, status)


func _text_panel(at: Vector2, panel_size: Vector2, title: String, content: String) -> void:
	var panel := Panel.new()
	panel.position = at
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PAPER, 0.94)
	style.border_color = LINE
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_label(panel, title, Vector2(22, 16), Vector2(panel_size.x - 44, 34), 20, TEAL)
	var text := RichTextLabel.new()
	text.position = Vector2(22, 62)
	text.size = Vector2(panel_size.x - 44, panel_size.y - 84)
	text.text = content
	text.fit_content = false
	text.scroll_active = true
	text.add_theme_font_size_override("normal_font_size", 14)
	text.add_theme_color_override("default_color", INK)
	panel.add_child(text)


func _label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = color.darkened(0.16)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(11)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	parent.add_child(button)
	return button
