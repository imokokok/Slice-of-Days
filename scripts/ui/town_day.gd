extends Control

const PANEL := Color(0.025, 0.039, 0.052, 0.96)
const PANEL_SOFT := Color(0.043, 0.061, 0.073, 0.95)
const BONE := Color("d8d0bd")
const MUTED := Color("819092")
const AMBER := Color("d98a39")
const CYAN := Color("58abb2")
const LINE := Color("40515a")

var locations: Dictionary = {}
var selected_location := "residence"
var location_buttons: Dictionary = {}
var status_message := "选择地点，再决定用什么方式抵达。"

var backdrop: Control
var role_label: Label
var clock_label: Label
var money_label: Label
var confirmation_label: Label
var location_title: Label
var location_subtitle: Label
var resident_label: Label
var message_label: Label
var timeline_label: Label
var actions_box: VBoxContainer
var notebook_panel: Panel


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--capture-town-a"):
		GameState.begin_vertical_slice("A")
	elif args.has("--capture-town-b"):
		GameState.begin_vertical_slice("B")
	_load_locations()
	selected_location = GameState.current_location
	backdrop = $Backdrop
	_build_ui()
	GameState.state_changed.connect(_refresh)
	_refresh()
	if args.has("--capture-town-a") or args.has("--capture-town-b"):
		_capture.call_deferred("town-%s.png" % GameState.current_role.to_lower())


func _load_locations() -> void:
	var file := FileAccess.open("res://data/world/locations.json", FileAccess.READ)
	if file == null:
		push_error("Unable to load location data")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid location data")
		return
	for row in parsed.get("locations", []):
		locations[str(row.get("id", ""))] = row


func _build_ui() -> void:
	var header := _panel(self, Vector2.ZERO, Vector2(1600, 78), Color(0.012, 0.02, 0.027, 0.98), LINE.darkened(0.4))
	_label(header, "第七日之前", Vector2(28, 14), Vector2(240, 30), 22, BONE)
	role_label = _label(header, "", Vector2(28, 44), Vector2(400, 21), 13, MUTED)
	clock_label = _label(header, "", Vector2(980, 19), Vector2(150, 28), 18, BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	money_label = _label(header, "", Vector2(1140, 19), Vector2(115, 28), 16, BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	confirmation_label = _label(header, "", Vector2(1265, 19), Vector2(180, 28), 16, BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	var save := _button(header, "保存", Vector2(1460, 16), Vector2(58, 34), "quiet")
	var menu := _button(header, "菜单", Vector2(1524, 16), Vector2(58, 34), "quiet")
	save.pressed.connect(_save_game)
	menu.pressed.connect(SceneRouter.main_menu)

	_label(self, "小镇路线 / 选择目的地", Vector2(35, 100), Vector2(500, 25), 15, MUTED)
	for id in locations:
		var row: Dictionary = locations[id]
		var point := _point_for(row)
		var button := _button(self, str(row.get("name", id)), point - Vector2(75, 24), Vector2(150, 48), "location")
		button.pressed.connect(_select_location.bind(id))
		location_buttons[id] = button

	var details := _panel(self, Vector2(1215, 96), Vector2(350, 566), PANEL, LINE)
	_label(details, "地点", Vector2(20, 17), Vector2(80, 20), 13, CYAN)
	location_title = _label(details, "", Vector2(20, 42), Vector2(310, 31), 21, BONE)
	location_subtitle = _label(details, "", Vector2(20, 78), Vector2(310, 52), 13, MUTED)
	location_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resident_label = _label(details, "", Vector2(20, 142), Vector2(310, 54), 14, BONE.darkened(0.05))
	message_label = _label(details, "", Vector2(20, 206), Vector2(310, 68), 13, AMBER)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(details, "此刻可以做", Vector2(20, 292), Vector2(180, 24), 15, CYAN)
	actions_box = VBoxContainer.new()
	actions_box.position = Vector2(18, 326)
	actions_box.size = Vector2(314, 215)
	actions_box.add_theme_constant_override("separation", 9)
	details.add_child(actions_box)

	var bottom := _panel(self, Vector2(0, 686), Vector2(1600, 214), Color(0.015, 0.026, 0.035, 0.99), LINE.darkened(0.15))
	_label(bottom, "交通", Vector2(28, 18), Vector2(70, 23), 16, BONE)
	var travel_options := [["步行", "walk"], ["公交", "bus"], ["打车", "taxi"], ["朋友顺路", "friend"]]
	for index in travel_options.size():
		var item: Array = travel_options[index]
		var travel_button := _button(bottom, str(item[0]), Vector2(28 + index * 142, 52), Vector2(128, 43), "travel")
		travel_button.pressed.connect(_travel.bind(str(item[1])))
	_label(bottom, "时间", Vector2(625, 18), Vector2(70, 23), 16, BONE)
	var wait20 := _button(bottom, "停留 20 分钟", Vector2(625, 52), Vector2(150, 43), "quiet")
	var wait60 := _button(bottom, "等待 1 小时", Vector2(786, 52), Vector2(150, 43), "quiet")
	var next := _button(bottom, "下个空闲段", Vector2(947, 52), Vector2(150, 43), "quiet")
	wait20.pressed.connect(_wait.bind(20))
	wait60.pressed.connect(_wait.bind(60))
	next.pressed.connect(_next_free_block)
	timeline_label = _label(bottom, "", Vector2(625, 111), Vector2(500, 72), 13, MUTED)
	timeline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var notes_text := "打开随身记忆" if GameState.current_role == "A" else "打开计划本"
	var notes := _button(bottom, notes_text, Vector2(1228, 48), Vector2(330, 48), "primary")
	notes.pressed.connect(_toggle_notebook)
	_label(bottom, "目标：找到夏透明，并请她确认你确实认识这座城。", Vector2(1228, 111), Vector2(330, 55), 13, BONE.darkened(0.06))

	notebook_panel = _panel(self, Vector2(820, 105), Vector2(370, 535), PANEL_SOFT, CYAN.darkened(0.25))
	notebook_panel.visible = false


func _select_location(id: String) -> void:
	selected_location = id
	status_message = "已标记%s。选择下方交通方式。" % _location_name(id)
	_refresh()


func _travel(method: String) -> void:
	if selected_location == GameState.current_location:
		status_message = "你已经在这里。"
	else:
		var result: Dictionary = TravelSystem.travel(selected_location, method)
		status_message = str(result.get("message", ""))
		if bool(result.get("ok", false)):
			SaveManager.save_game()
	_refresh()


func _wait(minutes: int) -> void:
	if GameState.use_free_time(minutes):
		status_message = "时间经过了 %d 分钟。小镇里的人也继续移动。" % minutes
	else:
		status_message = "当前空闲时间块不足。可以跳到下个空闲段。"
	_refresh()


func _next_free_block() -> void:
	status_message = "翻到下一段可行动时间。" if GameState.advance_to_next_free_block() else "今天已经没有下一段空闲时间。"
	_refresh()


func _refresh() -> void:
	role_label.text = "%s视角 · %s" % [GameState.current_role, "连续时间" if GameState.current_role == "A" else "碎片时间"]
	clock_label.text = "第 %d 天  %s" % [GameState.current_day, GameState.clock_text()]
	money_label.text = "%d 元" % GameState.money
	confirmation_label.text = "确认 %d / 12" % GameState.residency_confirmations
	var selected: Dictionary = locations.get(selected_location, {})
	location_title.text = str(selected.get("name", "未知地点"))
	location_subtitle.text = str(selected.get("subtitle", ""))
	message_label.text = status_message
	var current_people := ScheduleSystem.residents_at(GameState.current_location, GameState.current_day, GameState.current_minute)
	resident_label.text = "当前位置：%s\n此刻在场：%s" % [_location_name(GameState.current_location), _resident_names(current_people)]
	backdrop.set_points(_point_for(locations.get(GameState.current_location, {})), _point_for(selected))
	for id in location_buttons:
		_style_button(location_buttons[id], "location_active" if id == selected_location else "location")
	_render_actions(current_people)
	_render_timeline()
	if notebook_panel.visible:
		_render_notebook()


func _render_actions(current_people: Array[String]) -> void:
	for child in actions_box.get_children():
		actions_box.remove_child(child)
		child.queue_free()
	if selected_location != GameState.current_location:
		_add_action("先抵达这里，才能互动", Callable(), true)
		return
	if current_people.has("xia_touming"):
		_add_action("与夏透明谈谈（20分钟）", _talk_to_xia)
	if current_people.has("mossner") and not GameState.has_event("mossner_clue"):
		_add_action("询问 Mossner（10分钟）", _talk_to_mossner)
	match GameState.current_location:
		"library":
			if not GameState.has_event("library_archive"):
				_add_action("查阅居民活动册（20分钟）", _inspect_library)
		"cafe":
			if not GameState.has_event("cafe_rumor"):
				_add_action("听吧台传闻（20分钟）", _hear_cafe_rumor)
		"night_market":
			if GameState.current_role == "A" and not GameState.has_event("dinner_invite"):
				_add_action("接受陌生人的拼桌（20分钟）", _accept_dinner)
		"tarot_stall":
			_add_action("坐到塔拉牌桌前", SceneRouter.tarot_table)
	if actions_box.get_child_count() == 0:
		_add_action("观察周围（20分钟）", _observe)


func _talk_to_xia() -> void:
	if not _spend_action_time(20):
		return
	GameState.meet_resident("xia_touming")
	GameState.add_fact("夏透明承认：认识一座城，不等于记住所有道路。")
	GameState.mark_event("xia_conversation")
	GameState.add_confirmation("xia_touming")
	status_message = "夏透明在确认表上签了名。第一条完整体验链已经闭合。"
	SaveManager.save_game()
	_refresh()


func _talk_to_mossner() -> void:
	if not _spend_action_time(10):
		return
	GameState.meet_resident("mossner")
	GameState.mark_event("mossner_clue")
	GameState.add_fact("Mossner说夏透明逢单数日傍晚会去河岸公园。")
	status_message = "Mossner没有给地址，只在纸上画了一条通向河岸的线。"
	_refresh()


func _inspect_library() -> void:
	if not _spend_action_time(20):
		return
	GameState.mark_event("library_archive")
	GameState.add_fact("居民活动册：夏透明，第1日18:00—20:00，河岸公园。")
	status_message = "你在一本没人借阅的活动册里找到了夏透明的固定日程。"
	_refresh()


func _hear_cafe_rumor() -> void:
	if not _spend_action_time(20):
		return
	GameState.mark_event("cafe_rumor")
	GameState.add_fact("吧台传闻：夏透明通常在天色变暗后离开室内。")
	status_message = "这不是准确情报，但足够改变接下来的路线。"
	_refresh()


func _accept_dinner() -> void:
	if not _spend_action_time(20):
		return
	GameState.mark_event("dinner_invite")
	GameState.add_fact("偶遇：夜市摊主见过夏透明沿河岸方向离开。")
	status_message = "A没有按计划得到情报，却因为一次拼桌知道了河岸。"
	_refresh()


func _observe() -> void:
	if _spend_action_time(20):
		status_message = "灯光移动了，但没有人专门为你停下。"
		_refresh()


func _spend_action_time(minutes: int) -> bool:
	if GameState.use_free_time(minutes):
		return true
	status_message = "当前时间块不足以完成这个行动。"
	_refresh()
	return false


func _save_game() -> void:
	SaveManager.save_game()
	status_message = "进度已保存。"
	_refresh()


func _toggle_notebook() -> void:
	notebook_panel.visible = not notebook_panel.visible
	if notebook_panel.visible:
		_render_notebook()


func _render_notebook() -> void:
	for child in notebook_panel.get_children():
		notebook_panel.remove_child(child)
		child.queue_free()
	var title := "A的随身记忆" if GameState.current_role == "A" else "B的计划本"
	_label(notebook_panel, title, Vector2(20, 18), Vector2(300, 30), 20, BONE)
	_label(notebook_panel, "已知事实", Vector2(20, 62), Vector2(120, 23), 14, CYAN)
	var facts := ""
	for fact in GameState.known_facts:
		facts += "• %s\n\n" % fact
	var fact_text := _label(notebook_panel, facts if not facts.is_empty() else "尚无记录。", Vector2(20, 92), Vector2(330, 285), 13, BONE.darkened(0.05))
	fact_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(notebook_panel, "今日可行动时间", Vector2(20, 400), Vector2(180, 23), 14, CYAN)
	_label(notebook_panel, _block_text(), Vector2(20, 430), Vector2(330, 75), 13, MUTED)


func _render_timeline() -> void:
	var remaining := GameState.current_block_remaining()
	if GameState.current_role == "A":
		timeline_label.text = "连续时段 14:00—21:00\n当前时段剩余：%d 分钟" % remaining
	else:
		timeline_label.text = "碎片时段：%s\n当前时段剩余：%d 分钟" % [_block_text(), remaining]


func _block_text() -> String:
	var parts: Array[String] = []
	for block in GameState.active_time_blocks():
		parts.append("%s—%s" % [_minute_text(int(block[0])), _minute_text(int(block[1]))])
	return " / ".join(parts)


func _add_action(text_value: String, callback: Callable, disabled := false) -> void:
	var action := _button(actions_box, text_value, Vector2.ZERO, Vector2(314, 40), "action")
	action.custom_minimum_size = Vector2(314, 40)
	action.disabled = disabled
	if not disabled:
		action.pressed.connect(callback)


func _resident_names(ids: Array[String]) -> String:
	if ids.is_empty():
		return "无人可见"
	var names: Array[String] = []
	for id in ids:
		var row: Dictionary = ScheduleSystem.residents.get(id, {})
		names.append(str(row.get("display_name", id)))
	return "、".join(names)


func _location_name(id: String) -> String:
	var row: Dictionary = locations.get(id, {})
	return str(row.get("name", id))


func _point_for(row: Dictionary) -> Vector2:
	var values: Array = row.get("position", [156, 592])
	return Vector2(float(values[0]), float(values[1]))


func _minute_text(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


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
	var accent := LINE
	var alpha := 0.22
	match kind:
		"location_active", "primary":
			accent = AMBER
			alpha = 0.30
		"travel":
			accent = CYAN
		"action":
			accent = Color("7d445c")
		"quiet":
			accent = LINE
			alpha = 0.13
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent, alpha)
	normal.border_color = Color(accent, 0.78)
	normal.set_border_width_all(1)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(accent, min(alpha + 0.14, 0.7))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", BONE)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.25))


func _capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/%s" % filename))
	get_tree().quit()
