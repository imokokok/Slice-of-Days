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
var speech_text := ""
var speech_progress := 0.0
var cue_label: Label
var detail_label: Label
var interact_button: Button
var talk_button: Button
var people: Array[String] = []
var pocket_panel: Control
var stage: Control
var room_dialogue: Panel
var notes_overlay: Control


func _ready() -> void:
	_load_active_space()
	if space.is_empty():
		SceneRouter.leave_space()
		return
	objects = space.get("objects", [])
	people = ScheduleSystem.residents_at(GameState.current_location, GameState.current_day, GameState.current_minute)
	if SceneRouter.active_space_id in ["home_a", "home_b"]: people.clear()
	_build_theme()
	stage = preload("res://scripts/ui/walk_stage.gd").new()
	stage.indoor = true
	stage.world_width = 1600
	stage.player_x = 175
	stage.player_x = float(SceneRouter.room_positions.get(SceneRouter.active_space_id, 175.0))
	stage.moved.connect(func(x: float) -> void: SceneRouter.room_positions[SceneRouter.active_space_id] = x)
	stage.room_name = str(space.get("name", ""))
	stage.room_kind = str(space.get("id", ""))
	add_child(stage)
	_build_ui()
	stage.hotspots.append({"x":90, "kind":"exit", "label":"回到街道"})
	for index in objects.size():
		stage.hotspots.append({"x":_hotspot_x(index), "kind":"object", "index":index, "prop":"bed" if str(objects[index].get("kind", "")) == "sleep" else "table", "label":str(objects[index].get("name", ""))})
	for index in mini(people.size(), 3):
		var person: Dictionary = ScheduleSystem.residents.get(people[index], {})
		stage.hotspots.append({"x":920 + index * 180, "kind":"person", "id":people[index], "label":"和%s交谈" % str(person.get("display_name", "居民"))})
	WorldSound.set_active(true)
	WorldSound.set_location(GameState.current_location)


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
	_label(self, str(space.get("name", "")), Vector2(42, 18), Vector2(1000, 42), 25, Color("eadac1"))
	var dialogue := _panel(self, Vector2(390, 305), Vector2(820, 255), Color("17232b", 0.94), Color("566566"), 2)
	room_dialogue = dialogue
	room_dialogue.hide()
	name_label = _label(dialogue, "", Vector2(20, 10), Vector2(775, 28), 16, Color("d0b28a"))
	cue_label = _label(dialogue, "", Vector2(20, 35), Vector2(775, 136), 20, Color("ebdfc7"))
	detail_label = _label(dialogue, "", Vector2(20, 188), Vector2(775, 38), 15, Color("aab7b1"))
	cue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


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
	if index < 0 or index >= objects.size(): return
	selected_index = index
	var item: Dictionary = objects[index]
	name_label.text = str(space.get("name", ""))
	cue_label.text = str(item.get("name", ""))
	detail_label.text = str(item.get("detail", ""))


func _open_selected() -> void:
	if objects.is_empty() or absf(stage.player_x - _hotspot_x(selected_index)) > stage.REACH:
		return
	var item: Dictionary = objects[selected_index]
	if str(item.get("kind", "")) == "journal":
		SceneRouter.journal()
		return
	if str(item.get("kind", "")) == "observe":
		room_dialogue.show()
		cue_label.text = str(item.get("detail", ""))
		return
	if str(item.get("kind", "")) == "book_notes":
		_show_book_notes()
		return
	if str(item.get("kind", "")) == "sleep":
		ChapterSystem.sleep_at_home()
		return
	var module_id := str(item.get("module_id", ""))
	if not module_id.is_empty():
		var metadata: Dictionary = GameplayModuleSystem.modules.get(module_id, {})
		var direct_minutes := int(metadata.get("direct_time_minutes", 0))
		if direct_minutes > 0 and not GameState.can_fit_now(direct_minutes):
			room_dialogue.show()
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
	room_dialogue.show()
	if people.is_empty():
		return
	var nearest: Dictionary = stage.nearest()
	if str(nearest.get("kind", "")) != "person": return
	var resident_id := str(nearest.id)
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
	detail_label.text = "E · 继续"


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


func _process(_delta: float) -> void:
	if is_instance_valid(cue_label) and room_dialogue.visible:
		if speech_text != cue_label.text:
			speech_text = cue_label.text
			speech_progress = 0.0
		speech_progress += _delta * 28.0
		cue_label.visible_characters = int(speech_progress)
	if not is_instance_valid(stage): return
	stage.enabled = not is_instance_valid(pocket_panel) and not is_instance_valid(notes_overlay) and not SceneRouter.transitioning and not room_dialogue.visible
	avatar_x = stage.player_x


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(pocket_panel) or is_instance_valid(notes_overlay) or SceneRouter.transitioning: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if room_dialogue.visible:
		if event.keycode in [KEY_E, KEY_ESCAPE, KEY_ENTER]:
			if event.keycode != KEY_ESCAPE and speech_progress < cue_label.text.length():
				speech_progress = cue_label.text.length()
				cue_label.visible_characters = -1
			else: room_dialogue.hide()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_J:
		SceneRouter.journal()
	elif event.keycode == KEY_E:
		var nearest: Dictionary = stage.nearest()
		match str(nearest.get("kind", "")):
			"exit": SceneRouter.leave_space()
			"person": _talk_to_resident()
			"object":
				_select_object(int(nearest.index))
				_open_selected()
	elif event.keycode == KEY_ESCAPE:
		name_label.text = ""
		cue_label.text = ""
		detail_label.text = ""
	get_viewport().set_input_as_handled()

func _show_book_notes() -> void:
	if is_instance_valid(notes_overlay): return
	notes_overlay = _panel(self, Vector2(230, 180), Vector2(1140, 600), Color("f0e5ce"), Color("738376"), 8)
	_label(notes_overlay, "书店的便利贴墙", Vector2(32, 24), Vector2(1030, 45), 28, INK)
	var input := LineEdit.new()
	input.position = Vector2(32, 90)
	input.size = Vector2(780, 48)
	input.max_length = 80
	input.placeholder_text = "写下你最喜欢的一本书……"
	notes_overlay.add_child(input)
	var note_text := _label(notes_overlay, "", Vector2(32, 174), Vector2(1060, 325), 21, INK)
	note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var refresh := func() -> void:
		var notes: Array = GameState.shared_state.get("bookstore_notes", [])
		note_text.text = "还没有留下书名。" if notes.is_empty() else "\n\n".join(notes.slice(maxi(0, notes.size() - 7)))
	var submit := _button(notes_overlay, "贴上去", Vector2(842, 90), Vector2(260, 48), "primary")
	submit.pressed.connect(func() -> void:
		var title := input.text.strip_edges()
		if title.is_empty(): return
		var notes: Array = GameState.shared_state.get("bookstore_notes", [])
		if not notes.has(title): notes.append(title)
		GameState.shared_state["bookstore_notes"] = notes
		SaveManager.save_game()
		input.clear()
		refresh.call())
	var reload := _button(notes_overlay, "刷新", Vector2(600, 528), Vector2(220, 45), "quiet")
	reload.pressed.connect(refresh)
	var close := _button(notes_overlay, "收起", Vector2(852, 528), Vector2(250, 45), "quiet")
	close.pressed.connect(func() -> void: notes_overlay.queue_free())
	refresh.call()


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
