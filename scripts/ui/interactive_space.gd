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
var conversation: Control
var roster_minute := -1


func _ready() -> void:
	_load_active_space()
	if space.is_empty():
		SceneRouter.leave_space()
		return
	objects = space.get("objects", [])
	if SceneRouter.active_space_id in ["home_a","home_b"]:
		objects.append({"id":"everyday_shelf","name":"起居角的唱片与纸张","kind":"everyday","x":850 if SceneRouter.active_space_id=="home_a" else 310})
	people = DialogueSystem.people_at(GameState.current_location)
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
	if SceneRouter.active_space_id == "home_a": add_child(preload("res://scripts/ui/collection_display.gd").new())
	if SceneRouter.active_space_id in ["home_a", "home_b"]: add_child(load("res://scripts/photography/room_photo_display.gd").new())
	_build_ui()
	stage.hotspots.append({"x":145 if SceneRouter.active_space_id=="home_a" else 90, "kind":"exit", "label":"回到街道"})
	for index in objects.size():
		var object_kind := str(objects[index].get("kind", ""))
		stage.hotspots.append({"x":_hotspot_x(index), "kind":"object", "index":index, "prop":"bed" if object_kind == "sleep" else ("computer" if object_kind == "work" else "table"), "label":_object_hint(index)})
	for index in mini(people.size(), 3):
		var person: Dictionary = ScheduleSystem.residents.get(people[index], {})
		stage.hotspots.append({"x":920 + index * 180, "kind":"person", "id":people[index], "label":"和%s交谈" % str(person.get("display_name", "居民"))})
	for echo in EchoSystem.at_location(GameState.current_location):
		stage.hotspots.append({"x":700,"kind":"echo","label":"看黑板上的字","text":str(echo.text)})
	WorldSound.set_active(true)
	WorldSound.set_location(GameState.current_location)
	add_child(preload("res://scripts/residency/gameplay_shell.gd").new())


func _load_active_space() -> void:
	var active_id := SceneRouter.active_space_id
	if active_id.is_empty() or not FileAccess.file_exists(SPACES_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SPACES_PATH))
	if not parsed is Dictionary:
		push_error("Invalid interactive space data")
		return
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
	var home_button := _button(self, "回到主页", Vector2(1445, 15), Vector2(123, 40), "secondary")
	home_button.pressed.connect(_return_home)
	_label(self, str(space.get("name", "")), Vector2(42, 18), Vector2(1000, 42), 25, Color("eadac1"))
	room_dialogue=preload("res://scripts/ui/components/dialogue_card.gd").new()
	add_child(room_dialogue)
	room_dialogue.configure(stage)
	room_dialogue.hide()
	name_label=room_dialogue.speaker_label
	cue_label=room_dialogue.text_label
	detail_label=room_dialogue.hint_label



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
	if objects[index].has("x"): return float(objects[index].x)
	return preload("res://scripts/ui/scene_atlas.gd").object_x(str(space.id),index)


func _select_object(index: int) -> void:
	if index < 0 or index >= objects.size(): return
	selected_index = index
	var item: Dictionary = objects[index]
	name_label.text = LocalizationSystem.text(str(space.get("name", "")))
	cue_label.text = LocalizationSystem.text(str(item.get("name", "")))
	detail_label.text = LocalizationSystem.text(str(item.get("detail", "")))


func _open_selected() -> void:
	if objects.is_empty() or absf(stage.player_x - _hotspot_x(selected_index)) > stage.REACH:
		return
	var item: Dictionary = objects[selected_index]
	if str(item.get("kind",""))=="everyday":
		if not is_instance_valid(pocket_panel):
			pocket_panel=preload("res://scripts/ui/components/public_trace_panel.gd").new()
			add_child(pocket_panel)
		return
	if str(item.get("kind", "")) in ["restaurant_counter", "collections", "grocery_counter"]:
		EconomySystem.open_counter(self, {"restaurant_counter":"restaurant", "collections":"collections", "grocery_counter":"grocery"}[str(item.kind)])
		return
	if str(item.get("kind", "")) in ["memory", "newspaper", "zines"]:
		if str(item.kind) == "memory":
			notes_overlay = preload("res://scripts/meta/memory_entry.gd").new()
		else:
			notes_overlay = preload("res://scripts/meta/trace_panel.gd").new()
			notes_overlay.mode = str(item.kind)
		add_child(notes_overlay)
		return
	if str(item.get("kind", "")) == "journal":
		get_node("GameplayShell").open_paper("notebook")
		return
	if str(item.get("kind", "")) == "observe":
		room_dialogue.show()
		cue_label.text = LocalizationSystem.text(str(item.get("detail", "")))
		return
	if str(item.get("kind", "")) == "book_notes":
		_show_book_notes()
		return
	if str(item.get("kind", "")) == "sleep":
		ChapterSystem.sleep_at_home()
		return
	if str(item.get("kind", "")) == "shop":
		_open_shop(str(item.get("shop_id", "")))
		return
	if str(item.get("kind", "")) == "work":
		var result := GameState.complete_next_commitment()
		WorldSound.play_ui("coin" if bool(result.get("ok", false)) else "dialogue")
		room_dialogue.show()
		name_label.text = LocalizationSystem.text("工作日程")
		cue_label.text = LocalizationSystem.text(str(result.get("message", "")))
		detail_label.text = LocalizationSystem.text("余额 %d元 · Space 收起" % GameState.money)
		SaveManager.save_or_report("工作结算后保存失败")
		return
	if str(item.get("kind", "")) == "clock_repair":
		_open_clock_repair(item)
		return
	var module_id := str(item.get("module_id", ""))
	if module_id == "cooking":
		EconomySystem.open_counter(self, "restaurant")
		return
	if str(item.get("kind","")) == "record_shop": module_id = "sound_sampling"
	if str(item.get("kind","")) == "tarot": module_id = "tarot"
	var invite := DialogueSystem.invitation_for_module(module_id)
	if module_id not in ChapterSystem.MAIN_OWNERS and not invite.is_empty() and not DialogueSystem.invitation_accepted(module_id):
		if not DialogueSystem.invitation_for(str(invite.npc)).is_empty():
			_start_conversation(str(invite.npc),"minigame_hook")
		else:
			name_label.text = LocalizationSystem.text("工作台旁留着便签")
			cue_label.text = LocalizationSystem.text("先和店主聊聊，听听今天的委托。")
			detail_label.text = LocalizationSystem.text("Space · 继续")
			room_dialogue.show()
		return
	if not module_id.is_empty():
		var metadata: Dictionary = GameplayModuleSystem.modules.get(module_id, {})
		var direct_minutes := int(metadata.get("direct_time_minutes", 0))
		if direct_minutes > 0 and not GameState.can_fit_now(direct_minutes):
			room_dialogue.show()
			name_label.text = LocalizationSystem.text("时间提醒")
			cue_label.text = LocalizationSystem.text("这段经历需要完整的 %d 分钟" % direct_minutes)
			detail_label.text = LocalizationSystem.text("当前时间块放不下它。返回街道推进到下一个可行动时段后再来。")
			return
	WorldSound.play_detail(true)
	match str(item.get("kind", "module")):
		"record_shop":
			_open_record_shop()
		"tarot":
			SceneRouter.request_gameplay("tarot", "space:%s:%s" % [str(space.get("id", "")), str(item.get("id", ""))])
		_:
			if not module_id.is_empty():
				SceneRouter.request_gameplay(module_id, "space:%s:%s" % [str(space.get("id", "")), str(item.get("id", ""))])


func _open_clock_repair(item: Dictionary) -> void:
	if is_instance_valid(pocket_panel):
		return
	pocket_panel = preload("res://scripts/ui/clock_repair.gd").new()
	pocket_panel.target_hour = int(item.get("target_hour", 10))
	pocket_panel.target_minute = int(item.get("target_minute", 20))
	pocket_panel.reward = int(item.get("reward", 20))
	add_child(pocket_panel)
	pocket_panel.tree_exited.connect(func() -> void:
		pocket_panel = null
		queue_redraw())


func _open_record_shop() -> void:
	if not ChapterSystem.module_available("sound_sampling"):
		GameState.message_posted.emit("今天先做手边的事情。")
		return
	if is_instance_valid(pocket_panel):
		return
	pocket_panel = load("res://scenes/town_sound/Recorder.tscn").instantiate()
	pocket_panel.shop_mode = true
	pocket_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pocket_panel)
	pocket_panel.tree_exited.connect(func() -> void:
		pocket_panel = null
		if is_instance_valid(conversation): conversation.resume_from_shop()
		queue_redraw())


func _open_shop(target_shop_id: String) -> void:
	if is_instance_valid(pocket_panel): return
	pocket_panel = preload("res://scripts/ui/shop_panel.gd").new()
	pocket_panel.shop_id = target_shop_id
	pocket_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pocket_panel)
	pocket_panel.tree_exited.connect(func() -> void:
		pocket_panel = null
		if is_instance_valid(conversation): conversation.resume_from_shop()
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
		name_label.text = LocalizationSystem.text("室内对话")
		cue_label.text = LocalizationSystem.text("今天已经认真聊过了")
		detail_label.text = LocalizationSystem.text("留一点空白，下次见面时新的话题才会出现。")
		return
	if not GameState.can_fit_now(20):
		name_label.text = LocalizationSystem.text("时间提醒")
		cue_label.text = LocalizationSystem.text("现在的可行动时间不足 20 分钟")
		detail_label.text = LocalizationSystem.text("可以先返回街道，处理下一个预约或时间块。")
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
	SaveManager.save_or_report("室内互动后保存失败")
	name_label.text = LocalizationSystem.text(resident_name).to_upper()
	cue_label.text = LocalizationSystem.text("“%s”" % line)
	detail_label.text = LocalizationSystem.text("Space · 继续")


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
			room_dialogue.layout(true)
		speech_progress += _delta * 28.0
		cue_label.visible_characters = -1 if SettingsSystem.reduced_motion() else int(speech_progress)
	if not is_instance_valid(stage): return
	stage.enabled = not MetaExperience.modal_open() and not is_instance_valid(conversation) and not is_instance_valid(pocket_panel) and not is_instance_valid(notes_overlay) and not SceneRouter.transitioning and not room_dialogue.visible and not (has_node("GameplayShell") and get_node("GameplayShell").blocks_walking())
	if stage.enabled and DisplayServer.window_is_focused():
		GameState.advance_world_clock(_delta)
	if roster_minute != GameState.current_minute:
		roster_minute = GameState.current_minute
		_refresh_people()
	avatar_x = stage.player_x


func _unhandled_input(event: InputEvent) -> void:
	if MetaExperience.modal_open() or not get_tree().get_nodes_in_group("world_tool").is_empty(): return
	if is_instance_valid(conversation): return
	if is_instance_valid(pocket_panel) or is_instance_valid(notes_overlay) or SceneRouter.transitioning: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if room_dialogue.visible:
		if event.is_action_pressed("dialogue_advance") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			if not event.is_action_pressed("ui_cancel") and speech_progress < cue_label.text.length():
				speech_progress = cue_label.text.length()
				cue_label.visible_characters = -1
			else: room_dialogue.hide()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("open_journal"):
		SceneRouter.journal()
	elif event.is_action_pressed("open_map"):
		SceneRouter.town_map()
	elif event.is_action_pressed("talk"):
		var target: Dictionary = stage.nearest_of(["person"])
		if str(target.get("kind", "")) == "person":
			_start_conversation(str(target.id))
	elif event.is_action_pressed("ask_directly"):
		var target: Dictionary = stage.nearest_of(["person"])
		if str(target.get("kind", "")) == "person":
			notes_overlay = preload("res://scripts/meta/ask_panel.gd").new()
			notes_overlay.npc = str(target.id)
			notes_overlay.chosen.connect(func(topic: String) -> void: _start_conversation(str(target.id), topic))
			add_child(notes_overlay)
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("ui_cancel"):
		name_label.text = ""
		cue_label.text = ""
		detail_label.text = ""
	get_viewport().set_input_as_handled()

func _interact() -> void:
	if MetaExperience.modal_open() or is_instance_valid(conversation) or is_instance_valid(pocket_panel) or is_instance_valid(notes_overlay) or SceneRouter.transitioning: return
	var nearest: Dictionary = stage.nearest_interactable()
	match str(nearest.get("kind", "")):
		"echo":
			name_label.text = LocalizationSystem.text("黑板")
			cue_label.text = LocalizationSystem.text(str(nearest.text))
			detail_label.text = SettingsSystem.binding_text("dialogue_advance")+" · 收起视线"
			room_dialogue.show()
			MetaExperience.observe(GameState.current_location,str(nearest.text),{"kind":"place","event_id":"echo_"+GameState.current_location})
		"exit": SceneRouter.leave_space()
		"object":
			_select_object(int(nearest.index))
			_open_selected()

func _show_book_notes() -> void:
	if is_instance_valid(notes_overlay): return
	notes_overlay = preload("res://scripts/meta/trace_panel.gd").new()
	add_child(notes_overlay)


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
	label.text = LocalizationSystem.text(text_value)
	label.position = at
	label.size = label_size
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, kind: String) -> Button:
	var button := Button.new()
	button.text = LocalizationSystem.text(text_value)
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

func _start_conversation(resident_id: String, topic := "greeting") -> void:
	if not ResidentProfileSystem.is_core(resident_id): return
	if is_instance_valid(conversation): return
	if not MetaExperience.pay_conversation(topic): return
	conversation = preload("res://scripts/ui/conversation_panel.gd").new()
	conversation.npc = resident_id
	conversation.starting_topic = topic
	for item in stage.hotspots:
		if str(item.get("id","")) == resident_id and absf(float(item.x)-stage.player_x) > 1.0: stage.facing = signf(float(item.x)-stage.player_x)
	stage.velocity = 0.0
	add_child(conversation)
	SaveManager.save_or_report("谈话计时后保存失败")
func _refresh_people() -> void:
	stage.queue_redraw()
	people = DialogueSystem.people_at(GameState.current_location)
	if SceneRouter.active_space_id in ["home_a","home_b"]: people.clear()
	stage.hotspots = stage.hotspots.filter(func(item: Dictionary) -> bool: return str(item.get("kind","")) != "person")
	for i in mini(people.size(),3):
		stage.hotspots.append({"x":920+i*180,"kind":"person","id":people[i],"label":"和%s交谈" % str(ScheduleSystem.residents[people[i]].display_name)})

func _object_hint(index: int) -> String:
	var item: Dictionary = objects[index]
	if str(item.get("kind", "")) == "work":
		var work := GameState.next_commitment()
		if work.is_empty(): return "书桌 · 今天的工作已处理完"
		return "书桌 · %02d:%02d 开始 · %d分钟 · 收入%d元" % [int(work.start) / 60, int(work.start) % 60, int(work.end) - int(work.start), int(work.get("pay", 0))]
	var hint := GameplayModuleSystem.time_hint(str(item.get("module_id","")))
	return str(item.get("name","")) + (" · " + hint if not hint.is_empty() else "")


func _return_home() -> void:
	if SceneRouter.transitioning or is_instance_valid(pocket_panel) or is_instance_valid(notes_overlay): return
	SceneRouter.room_positions[SceneRouter.active_space_id] = stage.player_x
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("回到主页前保存失败"):
		name_label.text = LocalizationSystem.text("暂时无法返回")
		cue_label.text = LocalizationSystem.text("进度还没保存成功，请稍后再试。")
		detail_label.text = LocalizationSystem.text("Space · 继续")
		room_dialogue.show()
		return
	SceneRouter.main_menu()
