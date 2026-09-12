extends Control

const OPENINGS_PATH := "res://data/story/day_openings.json"
const OPENING_BACKGROUND := preload("res://art/reference/town-direction-warm-v2.png")
const PANEL := Color("fff8eb", 0.96)
const PANEL_SOFT := Color("f1dfc7", 0.97)
const BONE := Color("4a342b")
const MUTED := Color("806b5c")
const AMBER := Color("c85f43")
const CYAN := Color("4f7d83")
const LINE := Color("b88963")

var locations: Dictionary = {}
var selected_location := "residence"
var location_buttons: Dictionary = {}
var district_buttons: Dictionary = {}
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
var onboarding_label: Label
var actions_box: VBoxContainer
var notebook_panel: Panel
var event_overlay: ColorRect
var event_panel: Panel
var opening_overlay: ColorRect
var staged_event_id := ""
var staged_event_data: Dictionary = {}
var staged_event_index := 0
var staged_speaker_label: Label
var staged_line_label: Label
var staged_direction_label: Label
var staged_progress_label: Label
var staged_advance_button: Button
var staged_choices_box: VBoxContainer
var pocket_panel: Control
var pocket_opening := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var capture_event_id := ""
	var capture_opening := ""
	var capture_appointment := args.has("--capture-appointment")
	if capture_appointment:
		ChapterSystem.start_new_game("A")
		GameState.current_day = 5
		GameState.current_minute = 840
		GameState.current_location = "studio"
		GameState.add_appointment({
			"id": "shared_d5_studio_blocking",
			"day": 5,
			"start": 840,
			"end": 1020,
			"location": "studio",
			"label": "去摄影棚看分镜走位",
		})
		GameState.commit_active_role_state()
	elif args.has("--capture-town-a"):
		GameState.begin_vertical_slice("A")
	elif args.has("--capture-town-b"):
		GameState.begin_vertical_slice("B")
	else:
		for arg in args:
			if arg.begins_with("--capture-opening="):
				capture_opening = arg.trim_prefix("--capture-opening=")
				var opening_parts := capture_opening.split(":")
				var opening_role := str(opening_parts[0]).to_upper()
				GameState.begin_new_game(opening_role)
				GameState.current_day = int(opening_parts[1]) if opening_parts.size() > 1 else 1
				GameState.current_minute = int(GameState.schedule_for(opening_role, GameState.current_day).get("start", 540))
				GameState.current_location = "residence"
				GameState.commit_active_role_state()
				break
			if arg.begins_with("--capture-event="):
				capture_event_id = arg.trim_prefix("--capture-event=")
				var event: Dictionary = EventSystem.events.get(capture_event_id, {})
				var conditions: Dictionary = event.get("conditions", {})
				var roles: Array = conditions.get("roles", ["A"])
				var days: Array = conditions.get("days", [1])
				var event_locations: Array = conditions.get("locations", ["residence"])
				GameState.begin_new_game(str(roles[0]) if not roles.is_empty() else "A")
				GameState.current_day = int(days[0]) if not days.is_empty() else 1
				GameState.current_minute = int(conditions.get("start", 540))
				GameState.current_location = str(event_locations[0]) if not event_locations.is_empty() else "residence"
				GameState.commit_active_role_state()
				_seed_capture_module_echo(event)
				break
	WorldSound.set_active(true)
	_load_locations()
	selected_location = GameState.current_location
	backdrop = $Backdrop
	_build_ui()
	GameState.state_changed.connect(_refresh)
	_refresh()
	if not capture_opening.is_empty():
		_show_day_opening.call_deferred()
		_capture.call_deferred("day-opening-%s.png" % capture_opening.replace(":", "-"))
	elif not capture_event_id.is_empty():
		_open_event.call_deferred(capture_event_id)
		_capture.call_deferred("event-%s.png" % capture_event_id)
	elif capture_appointment:
		_capture.call_deferred("town-appointment.png")
	if args.has("--capture-town-a") or args.has("--capture-town-b"):
		_capture.call_deferred("town-%s.png" % GameState.current_role.to_lower())
	elif capture_event_id.is_empty() and capture_opening.is_empty() and not capture_appointment and not ChapterSystem.has_seen_opening():
		_show_day_opening.call_deferred()


func _seed_capture_module_echo(event: Dictionary) -> void:
	var module_echo: Dictionary = event.get("presentation", {}).get("module_echo", {})
	var module_id := str(module_echo.get("module_id", ""))
	if module_id.is_empty():
		return
	var prototype := GameplayModuleSystem.prototype_for(module_id)
	var interaction: Dictionary = prototype.get("interaction", {})
	var selected_tokens: Array[String] = []
	var selected_labels: Array[String] = []
	var count := int(interaction.get("min_select", 3))
	for token in interaction.get("tokens", []):
		if selected_tokens.size() >= count:
			break
		selected_tokens.append(str(token.get("id", "")))
		selected_labels.append(str(token.get("label", "")))
	GameplayModuleSystem.unlock(module_id)
	GameplayModuleSystem.complete(module_id, {
		"choice_id": "capture",
		"label": "截图示例",
		"source_event_id": "capture",
		"interaction": {
			"mode": str(interaction.get("mode", "toggle")),
			"selected_tokens": selected_tokens,
			"selected_labels": selected_labels,
		},
	})


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
	var header := _panel(self, Vector2.ZERO, Vector2(1600, 78), Color("fff8eb", 0.97), LINE)
	_label(header, "第七日之前", Vector2(28, 14), Vector2(240, 30), 22, BONE)
	role_label = _label(header, "", Vector2(28, 44), Vector2(400, 21), 13, MUTED)
	clock_label = _label(header, "", Vector2(840, 19), Vector2(170, 28), 18, BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	money_label = _label(header, "", Vector2(1020, 19), Vector2(110, 28), 16, BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	confirmation_label = _label(header, "", Vector2(1138, 19), Vector2(140, 28), 16, BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	var pocket_tools := [{"id": "recorder", "name": "随身录音 · 本地素材", "action": _open_pocket_recorder}, {"id": "camera", "name": "拍照 · 游戏内取景", "action": _open_pocket_camera}, {"id": "album", "name": "本地相册", "action": _open_pocket_album}]
	for index in pocket_tools.size():
		var tool: Dictionary = pocket_tools[index]
		var icon_button := _button(header, "", Vector2(1290 + index * 50, 16), Vector2(44, 38), "quiet")
		icon_button.icon = preload("res://scripts/town_sound/MediaTheme.gd").icon(tool.id)
		icon_button.tooltip_text = tool.name
		icon_button.pressed.connect(tool.action)
	var save := _button(header, "保存", Vector2(1460, 16), Vector2(58, 34), "quiet")
	var menu := _button(header, "菜单", Vector2(1524, 16), Vector2(58, 34), "quiet")
	save.pressed.connect(_save_game)
	menu.pressed.connect(_return_to_menu)

	_label(self, "小镇路线 / 选择目的地", Vector2(35, 100), Vector2(500, 25), 15, MUTED)
	for id in locations:
		var row: Dictionary = locations[id]
		if not bool(row.get("map_visible", true)):
			continue
		var point := _point_for(row)
		var button := _button(self, str(row.get("name", id)), point - Vector2(75, 24), Vector2(150, 48), "location")
		button.pressed.connect(_select_location.bind(id))
		location_buttons[id] = button

	_label(self, "街区里的地点", Vector2(34, 602), Vector2(180, 22), 13, CYAN)
	var district_index := 0
	for id in locations:
		var row: Dictionary = locations[id]
		if not bool(row.get("district_visible", false)):
			continue
		var district_button := _button(
			self,
			str(row.get("name", id)),
			Vector2(34 + district_index * 164, 630),
			Vector2(150, 40),
			"district"
		)
		district_button.tooltip_text = str(row.get("subtitle", ""))
		district_button.pressed.connect(_select_location.bind(id))
		district_buttons[id] = district_button
		district_index += 1

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

	var bottom := _panel(self, Vector2(0, 686), Vector2(1600, 214), Color("fff8eb", 0.98), LINE)
	_label(bottom, "交通", Vector2(28, 18), Vector2(70, 23), 16, BONE)
	var travel_options := [["步行", "walk"], ["公交", "bus"], ["打车", "taxi"], ["朋友顺路", "friend"]]
	for index in travel_options.size():
		var item: Array = travel_options[index]
		var travel_button := _button(bottom, str(item[0]), Vector2(28 + index * 142, 52), Vector2(128, 43), "travel")
		travel_button.pressed.connect(_travel.bind(str(item[1])))
	_label(bottom, "当前引导", Vector2(28, 111), Vector2(100, 23), 14, CYAN)
	onboarding_label = _label(bottom, "", Vector2(28, 140), Vector2(550, 52), 13, MUTED)
	onboarding_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(bottom, "时间", Vector2(625, 18), Vector2(70, 23), 16, BONE)
	var wait20 := _button(bottom, "停留 20 分钟", Vector2(625, 52), Vector2(150, 43), "quiet")
	var wait60 := _button(bottom, "等待 1 小时", Vector2(786, 52), Vector2(150, 43), "quiet")
	var next := _button(bottom, "下个空闲段", Vector2(947, 52), Vector2(150, 43), "quiet")
	var finish := _button(bottom, "结束本段", Vector2(1107, 52), Vector2(110, 43), "quiet")
	wait20.pressed.connect(_wait.bind(20))
	wait60.pressed.connect(_wait.bind(60))
	next.pressed.connect(_next_free_block)
	finish.pressed.connect(_finish_chapter)
	timeline_label = _label(bottom, "", Vector2(625, 111), Vector2(500, 72), 13, MUTED)
	timeline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var notes_text := "打开随身记忆" if GameState.current_role == "A" else "打开计划本"
	var notes := _button(bottom, notes_text, Vector2(1228, 48), Vector2(330, 48), "primary")
	notes.pressed.connect(SceneRouter.journal)
	var chapter_goal := str(GameState.schedule_for(GameState.current_role, GameState.current_day).get("goal", "七天内获得12位居民认可。"))
	var goal := _label(bottom, "本段：%s" % chapter_goal, Vector2(1228, 111), Vector2(330, 55), 13, BONE.darkened(0.06))
	goal.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY

	notebook_panel = _panel(self, Vector2(820, 105), Vector2(370, 535), PANEL_SOFT, CYAN)
	notebook_panel.visible = false
	_build_event_modal()


func _select_location(id: String) -> void:
	selected_location = id
	status_message = "已标记%s。选择下方交通方式。" % _location_name(id)
	_refresh()


func _travel(method: String) -> void:
	WorldSound.play_detail(true)
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
		SaveManager.save_game()
	else:
		status_message = "当前空闲时间块不足。可以跳到下个空闲段。"
	_refresh()


func _next_free_block() -> void:
	var advanced := GameState.advance_to_next_free_block()
	status_message = "翻到下一段可行动时间。" if advanced else "今天已经没有下一段空闲时间。"
	if advanced:
		SaveManager.save_game()
	_refresh()


func _refresh() -> void:
	WorldSound.set_location(GameState.current_location)
	var appointment_changes := GameState.refresh_appointments()
	for appointment in appointment_changes:
		if str(appointment.get("status", "")) == "missed":
			status_message = "错过预约：%s。它已经写进计划记录，时间不会自动退回。" % str(appointment.get("label", "未命名预约"))
	var job_title := CharacterSystem.job_title(GameState.current_role)
	role_label.text = "存档 %d · %s视角%s · %s" % [
		SaveManager.active_slot,
		GameState.current_role,
		" · %s" % job_title if not job_title.is_empty() else "",
		"连续时间" if GameState.current_role == "A" else "碎片时间",
	]
	clock_label.text = "第 %d 天  %s" % [GameState.current_day, GameState.clock_text()]
	money_label.text = "%d 元" % GameState.money
	confirmation_label.text = "确认 %d / 12" % GameState.residency_confirmations
	var selected: Dictionary = locations.get(selected_location, {})
	location_title.text = str(selected.get("name", "未知地点"))
	location_subtitle.text = str(selected.get("subtitle", ""))
	message_label.text = status_message
	onboarding_label.text = _onboarding_text()
	var current_people := ScheduleSystem.residents_at(GameState.current_location, GameState.current_day, GameState.current_minute)
	resident_label.text = "当前位置：%s\n此刻在场：%s" % [_location_name(GameState.current_location), _resident_names(current_people)]
	backdrop.set_points(_point_for(locations.get(GameState.current_location, {})), _point_for(selected))
	for id in location_buttons:
		location_buttons[id].text = _location_button_text(id)
		_style_button(location_buttons[id], "location_active" if id == selected_location else "location")
	for id in district_buttons:
		district_buttons[id].text = _location_button_text(id)
		_style_button(district_buttons[id], "district_active" if id == selected_location else "district")
	_render_actions(current_people)
	_render_timeline()
	if notebook_panel.visible:
		_render_notebook()


func _onboarding_text() -> String:
	if GameState.current_day != 1:
		return "地图负责抵达，计划本负责记住；认可来自共同经历，不来自一次点击。"
	if GameState.current_role == "A":
		if not GameState.has_event("a_d1_print_help"):
			return "① 标记“打印店” → 选择交通 → 抵达后打开橙色经历。一次偶遇会产生下一条线索。"
		if not GameState.has_event("a_d1_mossner_coffee"):
			return "② 线索指向咖啡馆。居民会按自己的日程移动，抵达时间也算选择。"
		if not GameState.has_event("a_d1_theatre_rehearsal"):
			return "③ 彩排已写入预约。前往剧场；共同收尾会形成关系与认可。"
		if not GameState.has_event("a_d1_evening_photo"):
			return "④ 傍晚去公园拍照。小游戏里的构图选择也会留进个人记录。"
		return "第一天的偶遇链已经闭合：线索 → 邀请 → 预约 → 共同经历 → 私人作品。"
	if not GameState.has_event("b_d1_cafeteria_observe"):
		return "① 标记“学院食堂”并选择交通。B先确认日程，也会记录对方的边界。"
	if not GameState.has_event("b_d1_library_wait"):
		return "② 18:00前后去图书馆。准确抵达不保证关系立刻发生。"
	if not GameState.has_event("b_d1_notebook_anomaly"):
		return "③ 回到住处整理计划本。已知日程、关系和异常会分别保存。"
	return "第一天的观察链已经闭合：时间窗 → 日程 → 边界 → 未完成关系 → 私人异常。"


func _render_actions(current_people: Array[String]) -> void:
	for child in actions_box.get_children():
		actions_box.remove_child(child)
		child.queue_free()
	if selected_location != GameState.current_location:
		_add_action("先抵达这里，才能互动", Callable(), true)
		return
	if GameState.current_location == "record_store":
		_add_action("进入唱片店工作台 · 编曲 / 制作 / 唱片架", _open_record_store)
	for event in EventSystem.available_events():
		var event_id := str(event.get("id", ""))
		var choice_text := str(event.get("choice_text", event_id))
		_add_action(choice_text, _open_event.bind(event_id))
	if GameState.current_location == "tarot_stall":
		_add_action("坐到 Solmere 塔罗牌桌前", SceneRouter.tarot_table)
	for resident_id in current_people:
		if actions_box.get_child_count() >= 4:
			break
		var request_id := _confirmation_request_event_id(resident_id)
		var request_preview := RelationshipSystem.confirmation_request_preview(resident_id)
		if bool(request_preview.get("available", false)) and not GameState.has_event(request_id):
			_add_action(str(request_preview.get("label", "请求居民认可（10分钟）")), _request_confirmation.bind(resident_id))
			if actions_box.get_child_count() >= 4:
				break
		var ambient_event_id := _ambient_event_id(resident_id)
		if GameState.has_event(ambient_event_id):
			continue
		var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
		_add_action("和%s聊几句（20分钟）" % str(resident.get("display_name", resident_id)), _ambient_talk.bind(resident_id))
	if actions_box.get_child_count() == 0:
		_add_action("观察周围（20分钟）", _observe)


func _show_pocket_panel(panel: Control) -> void:
	pocket_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.tree_exited.connect(func() -> void:
		pocket_panel = null
		if is_inside_tree() and not is_queued_for_deletion(): _refresh())


func _open_pocket_recorder() -> void:
	if is_instance_valid(pocket_panel) or pocket_opening: return
	var panel = load("res://scenes/town_sound/Recorder.tscn").instantiate()
	panel.shop_mode = false
	_show_pocket_panel(panel)


func _open_record_store() -> void:
	if GameState.current_location != "record_store": return
	if is_instance_valid(pocket_panel) or pocket_opening: return
	var panel = load("res://scenes/town_sound/Recorder.tscn").instantiate()
	panel.shop_mode = true
	_show_pocket_panel(panel)


func _open_pocket_album() -> void:
	if is_instance_valid(pocket_panel) or pocket_opening: return
	_show_pocket_panel(load("res://scripts/town_sound/PhotoAlbum.gd").new())


func _open_pocket_camera() -> void:
	if is_instance_valid(pocket_panel) or pocket_opening: return
	pocket_opening = true
	var hidden_widgets: Array[CanvasItem] = []
	for child in get_children():
		if child is CanvasItem and child != backdrop and child.visible:
			hidden_widgets.append(child)
			child.hide()
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	for child in hidden_widgets:
		if is_instance_valid(child): child.show()
	pocket_opening = false
	var camera = load("res://scripts/town_sound/PocketCamera.gd").new()
	camera.source = frame
	camera.context = {"location": GameState.current_location, "title": _location_name(GameState.current_location), "day": GameState.current_day}
	_show_pocket_panel(camera)


func _ambient_talk(resident_id: String) -> void:
	if not _spend_action_time(20):
		return
	var activity := ScheduleSystem.activity_at(resident_id, GameState.current_day, GameState.current_minute - 20)
	var resident: Dictionary = ScheduleSystem.residents.get(resident_id, {})
	var name := str(resident.get("display_name", resident_id))
	var activity_text := str(activity.get("activity", "今天的日常"))
	var memory := "在%s聊过%s" % [_location_name(GameState.current_location), activity_text]
	var event_id := _ambient_event_id(resident_id)
	RelationshipSystem.record_encounter(resident_id, event_id, [memory])
	GameState.mark_event(event_id)
	var profile_line := ResidentProfileSystem.ambient_line(resident_id, GameState.current_role, GameState.current_day + int(GameState.relationships.get(resident_id, {}).get("encounters", 0)))
	if profile_line.is_empty():
		status_message = "%s说起%s。没有人因此立刻给出认可，但这次相处被记住了。" % [name, activity_text]
	else:
		status_message = "%s：“%s”\n这次谈话发生在%s，没有人因此立刻给出认可。" % [name, profile_line, activity_text]
	SaveManager.save_game()
	_refresh()


func _ambient_event_id(resident_id: String) -> String:
	return "ambient_d%d_%s_%s" % [GameState.current_day, GameState.current_role.to_lower(), resident_id]


func _confirmation_request_event_id(resident_id: String) -> String:
	return "confirmation_request_d%d_%s_%s" % [GameState.current_day, GameState.current_role.to_lower(), resident_id]


func _request_confirmation(resident_id: String) -> void:
	if not _spend_action_time(10):
		return
	var result := RelationshipSystem.request_confirmation(resident_id)
	status_message = str(result.get("message", "这次请求已经被记录。"))
	GameState.mark_event(_confirmation_request_event_id(resident_id))
	GameState.add_journal_entry({
		"id": _confirmation_request_event_id(resident_id),
		"kind": "confirmation_request",
		"text": status_message,
	})
	SaveManager.save_game()
	_refresh()


func _resolve_event(event_id: String, choice_id: String = "") -> void:
	var before := {
		"minute": GameState.current_minute,
		"money": GameState.money,
		"confirmations": GameState.residency_confirmations,
	}
	var result := EventSystem.trigger(event_id, choice_id)
	status_message = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		SaveManager.save_game()
		var launch_module := str(result.get("launch_module", ""))
		if not launch_module.is_empty():
			event_overlay.visible = false
			SceneRouter.gameplay_module(launch_module, event_id)
			return
		_show_event_result(result, before)
	else:
		event_overlay.visible = false
	_refresh()


func _show_event_result(result: Dictionary, before: Dictionary) -> void:
	for child in event_panel.get_children():
		event_panel.remove_child(child)
		child.queue_free()
	var event: Dictionary = result.get("event", {})
	var presentation: Dictionary = event.get("presentation", {})
	_label(event_panel, "这段经历已经发生", Vector2(32, 25), Vector2(676, 25), 14, CYAN)
	_label(event_panel, str(presentation.get("title", "留下的结果")), Vector2(32, 58), Vector2(676, 42), 26, BONE)
	var message := _label(event_panel, str(result.get("message", "这次经历已经被记录。")), Vector2(32, 116), Vector2(676, 100), 17, BONE.darkened(0.05))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var consequence := _event_consequence_text(result, before)
	var consequence_panel := _panel(event_panel, Vector2(32, 238), Vector2(676, 174), Color("f1dfc7", 0.82), CYAN)
	_label(consequence_panel, "留下的变化", Vector2(20, 16), Vector2(260, 26), 16, CYAN)
	var consequence_label := _label(consequence_panel, consequence, Vector2(20, 52), Vector2(636, 98), 14, BONE)
	consequence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close := _button(event_panel, "继续今天", Vector2(488, 478), Vector2(220, 50), "primary")
	close.pressed.connect(func() -> void: event_overlay.visible = false)
	event_overlay.visible = true


func _event_consequence_text(result: Dictionary, before: Dictionary) -> String:
	var pieces: Array[String] = []
	var minutes := GameState.current_minute - int(before.get("minute", GameState.current_minute))
	var money_delta := GameState.money - int(before.get("money", GameState.money))
	var confirmation_delta := GameState.residency_confirmations - int(before.get("confirmations", GameState.residency_confirmations))
	if minutes > 0:
		pieces.append("时间经过 %d 分钟" % minutes)
	if money_delta != 0:
		pieces.append("金钱 %s%d 元" % ["+" if money_delta > 0 else "", money_delta])
	if confirmation_delta != 0:
		pieces.append("居民认可 %s%d" % ["+" if confirmation_delta > 0 else "", confirmation_delta])
	var event: Dictionary = result.get("event", {})
	var choice: Dictionary = result.get("choice", {})
	var combined_results: Array[Dictionary] = [event.get("results", {}), choice.get("results", {})]
	var residents: Array[String] = []
	for result_data in combined_results:
		for resident_id in result_data.get("encounters", []):
			var resident: Dictionary = ScheduleSystem.residents.get(str(resident_id), {})
			var name := str(resident.get("display_name", resident_id))
			if not residents.has(name):
				residents.append(name)
	if not residents.is_empty():
		pieces.append("这段经历涉及：%s" % "、".join(residents))
	if pieces.is_empty():
		pieces.append("没有新增数值；这段经历仍已写进当前角色的记录。")
	return "\n\n".join(pieces)


func _build_event_modal() -> void:
	event_overlay = ColorRect.new()
	event_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_overlay.color = Color(BONE, 0.42)
	event_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(event_overlay)
	event_panel = _panel(event_overlay, Vector2(430, 150), Vector2(740, 580), PANEL, LINE)
	event_overlay.visible = false


func _show_day_opening() -> void:
	var opening := _opening_for(GameState.current_day, GameState.current_role)
	if opening.is_empty():
		ChapterSystem.mark_opening_seen()
		return
	opening_overlay = ColorRect.new()
	opening_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	opening_overlay.color = Color(BONE, 0.52)
	opening_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(opening_overlay)
	var card := _panel(opening_overlay, Vector2(250, 125), Vector2(1100, 650), Color("fff8eb", 0.98), LINE)
	var role_color := AMBER if GameState.current_role == "A" else CYAN
	_label(card, "第 %d 天 · %s" % [GameState.current_day, str(opening.get("theme", "小镇生活"))], Vector2(36, 28), Vector2(700, 28), 15, role_color)
	var title := _label(card, str(opening.get("title", "走进今天")), Vector2(34, 62), Vector2(1000, 50), 30, BONE)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var image := TextureRect.new()
	image.position = Vector2(36, 130)
	image.size = Vector2(390, 360)
	image.texture = _opening_texture(opening)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.modulate = Color(1, 1, 1, 0.92)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(image)
	var wash := ColorRect.new()
	wash.position = image.position
	wash.size = image.size
	wash.color = Color(role_color, 0.13)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(wash)
	_label(card, GameState.current_role, Vector2(56, 145), Vector2(55, 50), 34, Color("fff8eb"))

	var body := _label(card, str(opening.get("body", "")), Vector2(465, 130), Vector2(590, 100), 17, BONE.darkened(0.04))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(card, "今天的重点", Vector2(465, 252), Vector2(220, 26), 15, CYAN)
	var focus := _label(card, str(opening.get("focus", "")), Vector2(465, 286), Vector2(590, 88), 16, BONE)
	focus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(card, "留下的一句话", Vector2(465, 394), Vector2(220, 26), 15, role_color)
	var memory := _label(card, str(opening.get("memory", "")), Vector2(465, 428), Vector2(590, 75), 16, MUTED)
	memory.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var rule_text := "七天结束前，需要十二位居民愿意确认：她确实在这里生活过。" if GameState.current_day == 1 else "小镇照常运转。没有人会固定站在原地等待。"
	var rule := _label(card, rule_text, Vector2(36, 520), Vector2(740, 46), 14, MUTED)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var enter := _button(card, "走进今天", Vector2(820, 548), Vector2(235, 52), "primary")
	enter.pressed.connect(_dismiss_day_opening)


func _dismiss_day_opening() -> void:
	ChapterSystem.mark_opening_seen()
	SaveManager.save_game()
	if opening_overlay != null:
		opening_overlay.queue_free()
		opening_overlay = null


func _opening_for(day: int, role: String) -> Dictionary:
	if not FileAccess.file_exists(OPENINGS_PATH):
		return {}
	var file := FileAccess.open(OPENINGS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	for row in parsed.get("days", []):
		if int(row.get("day", 0)) == day:
			var result: Dictionary = row.get(role, {}).duplicate(true)
			result["theme"] = str(row.get("theme", ""))
			return result
	return {}


func _opening_texture(opening: Dictionary) -> Texture2D:
	var path := str(opening.get("image_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			return loaded
	var portrait_path := CharacterSystem.portrait_path(GameState.current_role)
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		var portrait = load(portrait_path)
		if portrait is Texture2D:
			return portrait
	return OPENING_BACKGROUND


func _open_event(event_id: String) -> void:
	if not EventSystem.events.has(event_id):
		return
	for child in event_panel.get_children():
		event_panel.remove_child(child)
		child.queue_free()
	var event: Dictionary = EventSystem.events[event_id]
	var presentation := EventSystem.resolved_presentation(event)
	var beats: Array = presentation.get("beats", [])
	if not beats.is_empty():
		_open_staged_event(event_id, event, presentation, beats)
		return
	event_panel.position = Vector2(430, 150)
	event_panel.size = Vector2(740, 580)
	var image_path := str(presentation.get("image_path", ""))
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		var loaded_image = load(image_path)
		if loaded_image is Texture2D:
			var event_image := TextureRect.new()
			event_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			event_image.texture = loaded_image
			event_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			event_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			event_image.modulate = Color(1, 1, 1, 0.14)
			event_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			event_panel.add_child(event_image)
	_label(event_panel, str(presentation.get("title", event.get("choice_text", "事件"))), Vector2(32, 25), Vector2(676, 42), 26, BONE)
	var summary := _label(event_panel, str(presentation.get("summary", "")), Vector2(32, 80), Vector2(676, 64), 16, MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var lines_text := _presentation_lines_text(presentation.get("lines", []))
	var lines := _label(event_panel, lines_text, Vector2(32, 155), Vector2(676, 150), 15, BONE.darkened(0.05))
	lines.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var cost: Dictionary = event.get("cost", {})
	var cost_text := "基础花费：%d分钟 · %d元" % [int(cost.get("minutes", 0)), int(cost.get("money", 0))]
	_label(event_panel, cost_text, Vector2(32, 320), Vector2(676, 25), 13, CYAN)
	var choices: Array = event.get("choices", [])
	if choices.is_empty():
		var confirm := _button(event_panel, "进入这段经历", Vector2(32, 375), Vector2(320, 52), "primary")
		confirm.pressed.connect(_resolve_event.bind(event_id, ""))
	else:
		for index in choices.size():
			var choice: Dictionary = choices[index]
			var button := _button(
				event_panel,
				str(choice.get("label", "选择")),
				Vector2(32 + index * 340, 375),
				Vector2(320, 52),
				"action"
			)
			button.tooltip_text = str(choice.get("detail", ""))
			button.pressed.connect(_resolve_event.bind(event_id, str(choice.get("id", ""))))
	var cancel := _button(event_panel, "暂时离开", Vector2(520, 500), Vector2(188, 44), "quiet")
	cancel.pressed.connect(func() -> void: event_overlay.visible = false)
	event_overlay.visible = true


func _open_staged_event(event_id: String, event: Dictionary, presentation: Dictionary, beats: Array) -> void:
	staged_event_id = event_id
	staged_event_data = event
	staged_event_index = 0
	event_panel.position = Vector2(180, 100)
	event_panel.size = Vector2(1240, 700)

	var image := TextureRect.new()
	image.position = Vector2(28, 82)
	image.size = Vector2(548, 460)
	image.texture = _event_texture(presentation)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.modulate = Color(1, 1, 1, 0.94)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_panel.add_child(image)
	var image_wash := ColorRect.new()
	image_wash.position = image.position
	image_wash.size = image.size
	image_wash.color = Color(AMBER if GameState.current_role == "A" else CYAN, 0.09)
	image_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_panel.add_child(image_wash)

	var location_text := str(presentation.get("location_cue", _location_name(GameState.current_location)))
	_label(event_panel, "%s · 第%d天 %s" % [location_text, GameState.current_day, GameState.clock_text()], Vector2(32, 22), Vector2(760, 24), 14, CYAN)
	_label(event_panel, str(presentation.get("title", event.get("choice_text", "一段经历"))), Vector2(30, 47), Vector2(1120, 42), 27, BONE)

	staged_speaker_label = _label(event_panel, "", Vector2(620, 112), Vector2(550, 34), 17, AMBER if GameState.current_role == "A" else CYAN)
	staged_line_label = _label(event_panel, "", Vector2(620, 154), Vector2(550, 188), 24, BONE.darkened(0.04))
	staged_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	staged_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	staged_direction_label = _label(event_panel, "", Vector2(620, 365), Vector2(550, 88), 15, MUTED)
	staged_direction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	staged_progress_label = _label(event_panel, "", Vector2(620, 470), Vector2(550, 24), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

	var cost: Dictionary = event.get("cost", {})
	_label(event_panel, "这段经历会经过 %d 分钟%s" % [
		int(cost.get("minutes", 0)),
		"，花费 %d 元" % int(cost.get("money", 0)) if int(cost.get("money", 0)) > 0 else "",
	], Vector2(32, 574), Vector2(548, 30), 13, CYAN)
	var summary := _label(event_panel, str(presentation.get("summary", "")), Vector2(32, 610), Vector2(548, 56), 14, MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	staged_choices_box = VBoxContainer.new()
	staged_choices_box.position = Vector2(620, 510)
	staged_choices_box.size = Vector2(550, 132)
	staged_choices_box.add_theme_constant_override("separation", 10)
	event_panel.add_child(staged_choices_box)
	staged_advance_button = _button(event_panel, "让这一刻继续", Vector2(820, 530), Vector2(350, 52), "primary")
	staged_advance_button.pressed.connect(_advance_staged_event.bind(beats))
	var cancel := _button(event_panel, "暂时离开", Vector2(1012, 638), Vector2(158, 38), "quiet")
	cancel.pressed.connect(func() -> void: event_overlay.visible = false)
	_show_staged_beat(beats)
	event_overlay.visible = true


func _show_staged_beat(beats: Array) -> void:
	if beats.is_empty() or staged_event_index < 0 or staged_event_index >= beats.size():
		return
	var beat: Dictionary = beats[staged_event_index]
	var speaker := str(beat.get("speaker", ""))
	staged_speaker_label.text = speaker if not speaker.is_empty() else "画面"
	staged_line_label.text = str(beat.get("text", ""))
	staged_direction_label.text = str(beat.get("direction", ""))
	staged_progress_label.text = "%02d / %02d" % [staged_event_index + 1, beats.size()]
	staged_advance_button.text = "听完，再决定" if staged_event_index == beats.size() - 1 and not staged_event_data.get("choices", []).is_empty() else "让这一刻继续"


func _advance_staged_event(beats: Array) -> void:
	if staged_event_index < beats.size() - 1:
		staged_event_index += 1
		_show_staged_beat(beats)
		return
	var choices: Array = staged_event_data.get("choices", [])
	if choices.is_empty():
		_resolve_event(staged_event_id)
		return
	_show_staged_choices(choices)


func _show_staged_choices(choices: Array) -> void:
	staged_advance_button.visible = false
	staged_direction_label.text = "这不是一道正确答案。它只决定她怎样留下这一刻。"
	for child in staged_choices_box.get_children():
		staged_choices_box.remove_child(child)
		child.queue_free()
	for raw_choice in choices:
		var choice: Dictionary = raw_choice
		var button := _button(staged_choices_box, str(choice.get("label", "选择")), Vector2.ZERO, Vector2(550, 50), "action")
		button.custom_minimum_size = Vector2(550, 50)
		button.tooltip_text = str(choice.get("detail", ""))
		button.pressed.connect(_resolve_event.bind(staged_event_id, str(choice.get("id", ""))))


func _event_texture(presentation: Dictionary) -> Texture2D:
	var image_path := str(presentation.get("image_path", ""))
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		var loaded = load(image_path)
		if loaded is Texture2D:
			return loaded
	return OPENING_BACKGROUND


func _presentation_lines_text(raw_lines: Array) -> String:
	var formatted: Array[String] = []
	for raw_line in raw_lines:
		if raw_line is Dictionary:
			var line: Dictionary = raw_line
			var speaker := str(line.get("speaker", ""))
			var text_value := str(line.get("text", ""))
			formatted.append("%s：%s" % [speaker, text_value] if not speaker.is_empty() else text_value)
		else:
			formatted.append(str(raw_line))
	return "\n\n".join(formatted)


func _finish_chapter() -> void:
	if _guard_pocket_audio(): return
	GameState.commit_active_role_state()
	SaveManager.save_game()
	SceneRouter.chapter_transition()


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
		SaveManager.save_game()
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


func _return_to_menu() -> void:
	if _guard_pocket_audio(): return
	SaveManager.save_game()
	SceneRouter.main_menu()


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
	var fact_text := _label(notebook_panel, facts if not facts.is_empty() else "尚无记录。", Vector2(20, 92), Vector2(330, 220), 13, BONE.darkened(0.05))
	fact_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var relation_summary := "遇见 %d 位居民 · 获得 %d 份认可 · 留下 %d 条个人记录" % [
		GameState.encountered_residents.size(),
		GameState.confirmed_residents.size(),
		GameState.journal_entries.size(),
	]
	_label(notebook_panel, "关系与经历", Vector2(20, 325), Vector2(180, 23), 14, CYAN)
	var relation_text := _label(notebook_panel, relation_summary, Vector2(20, 352), Vector2(330, 42), 13, BONE.darkened(0.05))
	relation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(notebook_panel, "今日可行动时间", Vector2(20, 400), Vector2(180, 23), 14, CYAN)
	_label(notebook_panel, _block_text(), Vector2(20, 430), Vector2(330, 75), 13, MUTED)


func _render_timeline() -> void:
	var remaining := GameState.current_block_remaining()
	var mode := "连续时间" if GameState.current_role == "A" else "碎片时间"
	var appointment_text := _next_appointment_text()
	timeline_label.text = "%s：%s\n当前时段剩余：%d 分钟%s" % [mode, _block_text(), remaining, appointment_text]


func _next_appointment_text() -> String:
	var appointment := GameState.next_relevant_appointment()
	if appointment.is_empty():
		return ""
	var status := str(appointment.get("status", "scheduled"))
	var prefix := "现在可赴约" if status == "active" else "下个预约"
	return "\n%s：第%d天 %s · %s · %s" % [
		prefix,
		int(appointment.get("day", GameState.current_day)),
		_minute_text(int(appointment.get("start", 0))),
		_location_name(str(appointment.get("location", ""))),
		str(appointment.get("label", "未命名预约")),
	]


func _location_button_text(location_id: String) -> String:
	var name := _location_name(location_id)
	for appointment in GameState.appointments_for_day():
		if str(appointment.get("location", "")) != location_id:
			continue
		if ["scheduled", "active"].has(str(appointment.get("status", "scheduled"))):
			return "%s · 预约" % name
	return name


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
	for id in ids.slice(0, 2):
		var row: Dictionary = ScheduleSystem.residents.get(id, {})
		names.append(str(row.get("display_name", id)))
	var remaining := ids.size() - names.size()
	return "%s 等%d人" % ["、".join(names), ids.size()] if remaining > 0 else "、".join(names)


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
	style.set_border_width_all(2)
	if panel_size.x < 1500:
		style.set_corner_radius_all(16)
		style.shadow_color = Color("704936", 0.18)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0, 5)
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
	var base := Color("fff9ed", 0.92)
	var accent := LINE
	var font_color := BONE
	match kind:
		"location":
			base = Color("fff9ed", 0.91)
			accent = LINE
		"location_active", "primary":
			base = AMBER
			accent = AMBER
			font_color = Color("fff8e8")
		"district":
			base = Color("e9e1cc", 0.96)
			accent = CYAN
		"district_active":
			base = CYAN
			accent = CYAN.darkened(0.12)
			font_color = Color("fff8e8")
		"travel":
			base = Color("dce8df", 0.96)
			accent = CYAN
		"action":
			base = Color("f2d2c0", 0.97)
			accent = AMBER
		"quiet":
			base = Color("f6e9d6", 0.92)
			accent = Color(LINE, 0.75)
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.border_color = accent
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.shadow_color = Color("704936", 0.13)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = base.lightened(0.08)
	hover.border_color = accent.lightened(0.08)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = base.darkened(0.08)
	pressed.shadow_size = 1
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.25))


func _capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/%s" % filename))
	get_tree().quit()

func _exit_tree() -> void:
	WorldSound.set_active(false)

func _guard_pocket_audio() -> bool:
	if is_instance_valid(pocket_panel) and pocket_panel.has_method("set_compact"):
		if pocket_panel.recorder.capturing or pocket_panel.draft != null:
			pocket_panel.set_compact(false)
			pocket_panel.status_label.text = "请先停止并保存，或放弃当前录音，再离开小镇。"
			return true
	return false
