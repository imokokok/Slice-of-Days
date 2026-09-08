extends Control

const INK := Color("07090f")
const PANEL := Color(0.025, 0.039, 0.052, 0.98)
const PANEL_SOFT := Color(0.043, 0.061, 0.073, 0.95)
const BONE := Color("d8d0bd")
const MUTED := Color("819092")
const AMBER := Color("d98a39")
const CYAN := Color("58abb2")
const LINE := Color("40515a")
const LOCATION_FALLBACK_NAMES := {
	"dorm": "宿舍",
	"court": "排球场",
	"theatre": "剧场",
}

var locations: Dictionary = {}
var resident_ids: Array[String] = []
var resident_buttons: Dictionary = {}
var selected_resident_id := ""

var summary_label: Label
var detail_name: Label
var detail_id: Label
var detail_count: Label
var answer_text: RichTextLabel


func _ready() -> void:
	_load_locations()
	_prepare_residents()
	_build_ui()
	if not resident_ids.is_empty():
		_select_resident(resident_ids[0])
	if OS.get_cmdline_user_args().has("--capture-survey-results"):
		_capture.call_deferred()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	var sx := size.x / 1600.0
	var sy := size.y / 900.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 720), Vector2(340, 610), Vector2(665, 700), Vector2(1030, 570),
		Vector2(1340, 655), Vector2(1600, 590), Vector2(1600, 900), Vector2(0, 900)
	]), Color("101923"))
	draw_line(Vector2(0, 705), Vector2(1600, 565), Color(CYAN, 0.24), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _load_locations() -> void:
	var parsed = _load_json("res://data/world/locations.json")
	for row in parsed.get("locations", []):
		locations[str(row.get("id", ""))] = row


func _prepare_residents() -> void:
	for resident_id in ScheduleSystem.residents:
		resident_ids.append(str(resident_id))
	resident_ids.sort_custom(_sort_resident_ids)


func _sort_resident_ids(a: String, b: String) -> bool:
	var name_a := str(ScheduleSystem.residents.get(a, {}).get("display_name", a))
	var name_b := str(ScheduleSystem.residents.get(b, {}).get("display_name", b))
	return name_a.naturalnocasecmp_to(name_b) < 0


func _build_ui() -> void:
	var header := _panel(self, Vector2.ZERO, Vector2(1600, 78), Color(0.012, 0.02, 0.027, 0.98), LINE.darkened(0.4))
	_label(header, "第七日之前", Vector2(28, 14), Vector2(240, 30), 22, BONE)
	_label(header, "内部资料 · NPC 调查问卷", Vector2(28, 44), Vector2(400, 21), 13, MUTED)
	var back := _button(header, "返回主菜单", Vector2(1432, 18), Vector2(140, 42), "quiet")
	back.pressed.connect(SceneRouter.main_menu)

	_label(self, "NPC 调查问卷结果", Vector2(60, 118), Vector2(800, 48), 34, BONE)
	summary_label = _label(self, _summary_text(), Vector2(62, 170), Vector2(900, 28), 15, MUTED)
	_label(self, "结果直接读取当前 NPC 数据表；新增居民后会自动出现在此处。", Vector2(62, 205), Vector2(900, 24), 13, CYAN)

	var index_panel := _panel(self, Vector2(60, 260), Vector2(420, 540), PANEL, LINE)
	_label(index_panel, "已收录居民", Vector2(24, 20), Vector2(300, 30), 20, BONE)
	_label(index_panel, "选择一位居民查看完整记录", Vector2(24, 54), Vector2(340, 22), 13, MUTED)
	var list := VBoxContainer.new()
	list.position = Vector2(22, 96)
	list.size = Vector2(376, 410)
	list.add_theme_constant_override("separation", 12)
	index_panel.add_child(list)
	for resident_id in resident_ids:
		var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
		var schedule: Array = resident.get("schedule", [])
		var button := _button(list, "%s    %d 条记录" % [str(resident.get("display_name", resident_id)), schedule.size()], Vector2.ZERO, Vector2(376, 58), "resident")
		button.custom_minimum_size = Vector2(376, 58)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_resident.bind(resident_id))
		resident_buttons[resident_id] = button

	var detail_panel := _panel(self, Vector2(515, 260), Vector2(1025, 540), PANEL, LINE)
	_label(detail_panel, "问卷记录", Vector2(28, 20), Vector2(180, 25), 14, CYAN)
	detail_name = _label(detail_panel, "", Vector2(28, 53), Vector2(620, 40), 28, BONE)
	detail_id = _label(detail_panel, "", Vector2(28, 96), Vector2(620, 23), 13, MUTED)
	detail_count = _label(detail_panel, "", Vector2(760, 58), Vector2(230, 30), 16, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	var separator := ColorRect.new()
	separator.position = Vector2(28, 138)
	separator.size = Vector2(969, 1)
	separator.color = LINE
	detail_panel.add_child(separator)
	_label(detail_panel, "填写内容 / 常驻日程", Vector2(28, 161), Vector2(300, 27), 17, BONE)
	answer_text = RichTextLabel.new()
	answer_text.position = Vector2(28, 204)
	answer_text.size = Vector2(969, 300)
	answer_text.bbcode_enabled = true
	answer_text.scroll_active = true
	answer_text.add_theme_font_size_override("normal_font_size", 15)
	answer_text.add_theme_color_override("default_color", BONE)
	detail_panel.add_child(answer_text)


func _summary_text() -> String:
	var schedule_count := 0
	for resident_id in resident_ids:
		var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
		schedule_count += resident.get("schedule", []).size()
	return "已收录 %d 位居民 · 共 %d 条日程回答" % [resident_ids.size(), schedule_count]


func _select_resident(resident_id: String) -> void:
	selected_resident_id = resident_id
	var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
	var schedule: Array = resident.get("schedule", [])
	detail_name.text = str(resident.get("display_name", resident_id))
	detail_id.text = "记录编号  %s" % resident_id
	detail_count.text = "%d 条日程回答" % schedule.size()
	answer_text.text = _schedule_text(schedule)
	for id in resident_buttons:
		_style_button(resident_buttons[id], "resident_active" if id == resident_id else "resident")


func _schedule_text(schedule: Array) -> String:
	if schedule.is_empty():
		return "[color=#819092]这位居民暂未填写日程。[/color]"
	var rows: Array[String] = []
	for index in schedule.size():
		var item: Dictionary = schedule[index]
		var days := _day_text(item.get("days", []))
		var time := "%s—%s" % [_minute_text(int(item.get("start", 0))), _minute_text(int(item.get("end", 0)))]
		var location_id := str(item.get("location", ""))
		var location_name := str(locations.get(location_id, {}).get("name", LOCATION_FALLBACK_NAMES.get(location_id, location_id)))
		var activity := str(item.get("activity", "未填写"))
		rows.append("[color=#58abb2]%02d[/color]  [color=#d8d0bd]%s[/color]\n      日期：%s    时间：%s\n      地点：%s" % [index + 1, activity, days, time, location_name])
	return "\n\n".join(rows)


func _day_text(days: Array) -> String:
	if days.size() == 7:
		return "每天"
	var parts: Array[String] = []
	for day in days:
		parts.append("第%d天" % int(day))
	return "、".join(parts)


func _minute_text(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load JSON data: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _panel(parent: Node, at: Vector2, panel_size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, kind: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 14)
	parent.add_child(button)
	_style_button(button, kind)
	return button


func _style_button(button: Button, kind: String) -> void:
	var edge := LINE
	var background := PANEL_SOFT
	if kind == "resident_active":
		edge = CYAN
		background = Color("143c45")
	elif kind == "resident":
		background = Color("101820")
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = edge
	style.set_border_width_all(1)
	style.content_margin_left = 18
	var hover := style.duplicate()
	hover.bg_color = background.lightened(0.1)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", BONE)


func _capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/npc-survey-results.png"))
	get_tree().quit()
