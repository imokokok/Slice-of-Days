extends Control

const SPACES_PATH := "res://data/world/interactive_spaces.json"
const CREAM := Color("fff6e5")
const INK := Color("332b28")
const MUTED := Color("75675f")
const TERRACOTTA := Color("b85f45")
const SEA := Color("557a80")

var space: Dictionary = {}
var objects: Array = []
var selected_index := 0
var avatar_x := 250.0
var target_x := 250.0
var background_texture: Texture2D
var object_buttons: Array[Button] = []
var name_label: Label
var cue_label: Label
var detail_label: Label
var interact_button: Button
var talk_button: Button
var people: Array[String] = []
var pocket_panel: Control


func _ready() -> void:
	_load_active_space()
	if space.is_empty():
		SceneRouter.leave_space()
		return
	objects = space.get("objects", [])
	var background_path := str(space.get("background_path", ""))
	if not background_path.is_empty() and ResourceLoader.exists(background_path):
		var loaded = load(background_path)
		if loaded is Texture2D:
			background_texture = loaded
	people = ScheduleSystem.residents_at(GameState.current_location, GameState.current_day, GameState.current_minute)
	_build_theme()
	_build_ui()
	if not objects.is_empty():
		_select_object(0)
	WorldSound.set_active(true)
	WorldSound.set_location(GameState.current_location)
	queue_redraw()


func _load_active_space() -> void:
	var active_id := SceneRouter.active_space_id
	if active_id.is_empty() or not FileAccess.file_exists(SPACES_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SPACES_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for row in parsed.get("spaces", []):
		if str(row.get("id", "")) == active_id:
			space = row.duplicate(true)
			return


func _build_theme() -> void:
	var ui_theme := Theme.new()
	if DisplayServer.get_name() != "headless":
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", "sans-serif"])
		font.allow_system_fallback = true
		ui_theme.default_font = font
	ui_theme.default_font_size = 18
	theme = ui_theme


func _build_ui() -> void:
	var header := _panel(self, Vector2(26, 22), Vector2(1548, 82), Color(CREAM, 0.94), Color(TERRACOTTA, 0.7), 12)
	_label(header, str(space.get("sign", "INTERIOR")), Vector2(24, 12), Vector2(220, 26), 14, SEA)
	_label(header, str(space.get("name", "室内")), Vector2(24, 34), Vector2(560, 36), 27, INK)
	var time_text := "第 %d 天  %s  ·  %s视角" % [GameState.current_day, GameState.clock_text(), GameState.current_role]
	_label(header, time_text, Vector2(850, 26), Vector2(440, 30), 16, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var leave := _button(header, "推门回到街道", Vector2(1310, 18), Vector2(210, 46), "quiet")
	leave.pressed.connect(SceneRouter.leave_space)

	var room_note := _panel(self, Vector2(54, 126), Vector2(580, 90), Color(INK, 0.78), Color(CREAM, 0.25), 10)
	var room_text := str(space.get("interior_note", ""))
	var memory_text := _room_memory_text()
	if not memory_text.is_empty():
		room_text += "\n" + memory_text
	var note := _label(room_note, room_text, Vector2(20, 12), Vector2(540, 68), 14, CREAM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var people_text := "此刻在场：%s" % _resident_names()
	var people_label := _label(self, people_text, Vector2(920, 130), Vector2(600, 32), 15, Color(CREAM, 0.92), HORIZONTAL_ALIGNMENT_RIGHT)
	people_label.add_theme_color_override("font_shadow_color", Color(INK, 0.8))
	people_label.add_theme_constant_override("shadow_offset_x", 1)
	people_label.add_theme_constant_override("shadow_offset_y", 2)

	for index in objects.size():
		var item: Dictionary = objects[index]
		var x := _hotspot_x(index)
		var button := _button(self, "%s  %s" % [str(item.get("icon", "·")), str(item.get("name", "物件"))], Vector2(x - 105, 520), Vector2(210, 56), "hotspot")
		button.tooltip_text = str(item.get("detail", ""))
		button.pressed.connect(_select_object.bind(index))
		button.focus_entered.connect(_select_object.bind(index))
		object_buttons.append(button)

	var dialogue := _panel(self, Vector2(175, 690), Vector2(1250, 174), Color(CREAM, 0.96), Color(TERRACOTTA, 0.85), 12)
	name_label = _label(dialogue, "物件", Vector2(28, 18), Vector2(340, 26), 15, TERRACOTTA)
	cue_label = _label(dialogue, "", Vector2(28, 47), Vector2(770, 37), 25, INK)
	detail_label = _label(dialogue, "", Vector2(28, 90), Vector2(820, 58), 15, MUTED)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk_button = _button(dialogue, "和在场居民聊聊", Vector2(846, 54), Vector2(174, 64), "quiet")
	talk_button.pressed.connect(_talk_to_resident)
	talk_button.disabled = people.is_empty()
	interact_button = _button(dialogue, "靠近并使用", Vector2(1034, 54), Vector2(171, 64), "primary")
	interact_button.pressed.connect(_open_selected)
	_label(self, "A/D 或 ←/→ 选择物件   ·   E 互动   ·   T 对话   ·   Esc 返回街道", Vector2(450, 868), Vector2(700, 24), 13, Color(CREAM, 0.88), HORIZONTAL_ALIGNMENT_CENTER)


func _resident_names() -> String:
	if people.is_empty():
		return "暂时没有人，房间仍保留着刚才的声音"
	var names: Array[String] = []
	for resident_id in people:
		var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
		names.append(str(resident.get("display_name", resident_id)))
	return "、".join(names)


func _room_memory_text() -> String:
	var space_id := str(space.get("id", ""))
	var personal: Dictionary = GameState.artifacts
	var shared: Dictionary = GameState.shared_state.get("world_artifacts", {})
	var mappings := {
		"restaurant": [shared, "recipes", "公共菜谱"],
		"record_shop": [shared, "records", "本地唱片架"],
		"letter_office": [personal, "letters", "私人信件"],
		"chess_club": [shared, "game_records", "共享棋谱"],
		"observatory": [personal, "observations", "星图收藏"],
		"print_studio": [personal, "photos", "个人相册"],
		"old_station_hall": [personal, "models", "空间模型"],
		"public_archive": [shared, "archives", "公共索引"],
	}
	if mappings.has(space_id):
		var config: Array = mappings[space_id]
		var collection: Dictionary = config[0]
		var count := (collection.get(str(config[1]), []) as Array).size()
		return "%s里已有 %d 件由旅程留下的记录。" % [str(config[2]), count] if count > 0 else ""
	if space_id == "tarot_shop":
		var outcomes: Array = GameState.module_states.get("tarot", {}).get("outcomes", [])
		return "牌桌记得 %d 次已经完成的阅读。" % outcomes.size() if not outcomes.is_empty() else ""
	return ""


func _hotspot_x(index: int) -> float:
	if objects.size() <= 1:
		return 800.0
	return 300.0 + float(index) * 1000.0 / float(objects.size() - 1)


func _select_object(index: int) -> void:
	if index < 0 or index >= objects.size():
		return
	selected_index = index
	target_x = _hotspot_x(index)
	var item: Dictionary = objects[index]
	name_label.text = "%s  ·  %s" % [str(space.get("name", "室内")), str(item.get("icon", "物"))]
	cue_label.text = str(item.get("name", "物件"))
	detail_label.text = str(item.get("detail", ""))
	interact_button.text = "靠近并进入" if str(item.get("kind", "module")) != "record_shop" else "靠近制作台"
	for button_index in object_buttons.size():
		_style_button(object_buttons[button_index], "hotspot_active" if button_index == selected_index else "hotspot")
	queue_redraw()


func _open_selected() -> void:
	if objects.is_empty():
		return
	var item: Dictionary = objects[selected_index]
	var module_id := str(item.get("module_id", ""))
	if not module_id.is_empty():
		var metadata: Dictionary = GameplayModuleSystem.modules.get(module_id, {})
		var direct_minutes := int(metadata.get("direct_time_minutes", 0))
		if direct_minutes > 0 and not GameState.can_fit_now(direct_minutes):
			name_label.text = "时间提醒"
			cue_label.text = "这段经历需要完整的 %d 分钟" % direct_minutes
			detail_label.text = "当前时间块放不下它。返回街道推进到下一个可行动时段后再来。"
			return
	WorldSound.play_detail(true)
	match str(item.get("kind", "module")):
		"record_shop":
			_open_record_shop()
		"tarot":
			SceneRouter.gameplay_module("tarot", "space:%s:%s" % [str(space.get("id", "")), str(item.get("id", ""))])
		_:
			if not module_id.is_empty():
				SceneRouter.gameplay_module(module_id, "space:%s:%s" % [str(space.get("id", "")), str(item.get("id", ""))])


func _open_record_shop() -> void:
	if is_instance_valid(pocket_panel):
		return
	pocket_panel = load("res://scenes/town_sound/Recorder.tscn").instantiate()
	pocket_panel.shop_mode = true
	pocket_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pocket_panel)
	pocket_panel.tree_exited.connect(func() -> void:
		pocket_panel = null
		queue_redraw())


func _talk_to_resident() -> void:
	if people.is_empty():
		return
	var resident_id := _next_conversation_resident()
	var event_id := _conversation_event_id(resident_id)
	if GameState.has_event(event_id):
		name_label.text = "室内对话"
		cue_label.text = "今天已经认真聊过了"
		detail_label.text = "留一点空白，下次见面时新的话题才会出现。"
		return
	if not GameState.can_fit_now(20):
		name_label.text = "时间提醒"
		cue_label.text = "现在的可行动时间不足 20 分钟"
		detail_label.text = "可以先返回街道，处理下一个预约或时间块。"
		return
	var minute_before := GameState.current_minute
	GameState.use_free_time(20)
	var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
	var resident_name := str(resident.get("display_name", resident_id))
	var activity := ScheduleSystem.activity_at(resident_id, GameState.current_day, minute_before)
	var activity_text := str(activity.get("activity", "房间里的日常"))
	var memory := "在%s室内聊过%s" % [str(space.get("name", "这间屋子")), activity_text]
	RelationshipSystem.record_encounter(resident_id, event_id, [memory])
	GameState.mark_event(event_id)
	var line := ResidentProfileSystem.ambient_line(
		resident_id,
		GameState.current_role,
		GameState.current_day + int(GameState.relationships.get(resident_id, {}).get("encounters", 0))
	)
	if line.is_empty():
		line = "这里的声音和平时不太一样。慢一点，就能听出来。"
	GameState.add_journal_entry({
		"id": event_id,
		"kind": "interior_conversation",
		"text": "%s在%s说：“%s”" % [resident_name, str(space.get("name", "室内")), line],
	})
	SaveManager.save_game()
	name_label.text = resident_name.to_upper()
	cue_label.text = "“%s”" % line
	detail_label.text = "%s · 20 分钟 · 这次相处已进入关系与日记记录。" % activity_text
	talk_button.text = "继续和另一位居民聊" if _has_unspoken_resident() else "今天的室内对话已记录"
	talk_button.disabled = not _has_unspoken_resident()


func _next_conversation_resident() -> String:
	for resident_id in people:
		if not GameState.has_event(_conversation_event_id(resident_id)):
			return resident_id
	return people[0]


func _has_unspoken_resident() -> bool:
	for resident_id in people:
		if not GameState.has_event(_conversation_event_id(resident_id)):
			return true
	return false


func _conversation_event_id(resident_id: String) -> String:
	return "interior_d%d_%s_%s_%s" % [
		GameState.current_day,
		GameState.current_role.to_lower(),
		str(space.get("id", "space")),
		resident_id,
	]


func _process(delta: float) -> void:
	if absf(avatar_x - target_x) > 0.5:
		avatar_x = move_toward(avatar_x, target_x, delta * 650.0)
		queue_redraw()


func _draw() -> void:
	if background_texture != null:
		draw_texture_rect(background_texture, Rect2(Vector2.ZERO, Vector2(1600, 900)), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1600, 900)), Color("708087"))
	draw_rect(Rect2(Vector2.ZERO, Vector2(1600, 900)), Color(0.12, 0.12, 0.13, 0.32))
	draw_rect(Rect2(0, 580, 1600, 320), Color(0.14, 0.12, 0.11, 0.36))
	draw_line(Vector2(0, 665), Vector2(1600, 665), Color(CREAM, 0.35), 2)
	for index in objects.size():
		var x := _hotspot_x(index)
		draw_line(Vector2(x, 580), Vector2(x, 650), Color(CREAM, 0.24), 2)
		draw_circle(Vector2(x, 650), 7, TERRACOTTA if index == selected_index else Color(CREAM, 0.65))
	_draw_people()
	_draw_avatar(Vector2(avatar_x, 642), TERRACOTTA if GameState.current_role == "A" else SEA)


func _draw_people() -> void:
	for index in mini(people.size(), 4):
		var x := 930.0 + index * 92.0
		_draw_avatar(Vector2(x, 640), Color(INK, 0.82), 0.82)


func _draw_avatar(at: Vector2, color: Color, scale_value := 1.0) -> void:
	draw_circle(at + Vector2(0, -58) * scale_value, 13 * scale_value, color)
	draw_line(at + Vector2(0, -44) * scale_value, at + Vector2(0, -10) * scale_value, color, 12 * scale_value, true)
	draw_line(at + Vector2(0, -34) * scale_value, at + Vector2(-16, -17) * scale_value, color, 6 * scale_value, true)
	draw_line(at + Vector2(0, -34) * scale_value, at + Vector2(17, -21) * scale_value, color, 6 * scale_value, true)
	draw_line(at + Vector2(0, -12) * scale_value, at + Vector2(-12, 16) * scale_value, color, 7 * scale_value, true)
	draw_line(at + Vector2(0, -12) * scale_value, at + Vector2(14, 16) * scale_value, color, 7 * scale_value, true)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(pocket_panel):
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_A, KEY_LEFT]:
		_select_object(maxi(0, selected_index - 1))
	elif event.keycode in [KEY_D, KEY_RIGHT]:
		_select_object(mini(objects.size() - 1, selected_index + 1))
	elif event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
		_open_selected()
	elif event.keycode == KEY_T:
		_talk_to_resident()
	elif event.keycode == KEY_ESCAPE:
		SceneRouter.leave_space()


func _panel(parent: Node, at: Vector2, panel_size: Vector2, color: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(INK, 0.18)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, kind: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	_style_button(button, kind)
	return button


func _style_button(button: Button, kind: String) -> void:
	var fill := Color(CREAM, 0.9)
	var border := Color(SEA, 0.65)
	var text_color := INK
	if kind in ["primary", "hotspot_active"]:
		fill = TERRACOTTA
		border = Color(CREAM, 0.9)
		text_color = CREAM
	elif kind == "quiet":
		fill = Color(SEA, 0.13)
		border = Color(SEA, 0.5)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fill.lightened(0.08) if state == "hover" else (fill.darkened(0.08) if state == "pressed" else fill)
		style.border_color = border
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
