extends Control

const PANEL := Color("fff8eb", 0.96)
const BONE := Color("4a342b")
const MUTED := Color("806b5c")
const AMBER := Color("c85f43")
const CYAN := Color("4f7d83")
const LINE := Color("b88963")

var locations: Dictionary = {}
var status_message := ""

var backdrop: Control
var clock_label: Label
var location_title: Label
var event_overlay: ColorRect
var event_panel: Panel
var staged_event_id := ""
var staged_event_data: Dictionary = {}
var staged_event_index := 0
var pocket_panel: Control
var pocket_opening := false
var interactive_spaces: Array[Dictionary] = []
var street: Control
var street_order: Array[String] = []
const BLOCK_WIDTH := 1600.0
const Atlas = preload("res://scripts/ui/scene_atlas.gd")
var outdoor_objects: Array = []
var current_index := -1
var segment_id := ""
var conversation: Control
var dialogue_choices: Array[Button] = []
var spoken_line: Label
var speech_tween: Tween
var wallet_label: Label
var wallet_icon: TextureRect
var displayed_money := -1
var time_guidance_label: Label


func _ready() -> void:
	_load_locations()
	_load_interactive_spaces()
	var segment := WorldGraph.segment_for(GameState.current_location)
	segment_id = str(segment.id)
	for location_id in segment.locations: street_order.append(str(location_id))
	var object_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/street_objects.json"))
	if object_data is Dictionary:
		outdoor_objects = object_data.get("objects", [])
	else:
		push_error("Invalid street object data")
	street = preload("res://scripts/ui/walk_stage.gd").new()
	add_child(street)
	backdrop = street
	street.world_width = street_order.size() * BLOCK_WIDTH
	street.composition_anchor = 800.0
	for index in street_order.size():
		street.places.append({"id": street_order[index], "name": _location_name(street_order[index]), "kind":locations[street_order[index]].kind, "interior":locations[street_order[index]].interior, "x": index * BLOCK_WIDTH + 800.0})
	# Load this connected street before walking so a new plate never stalls a boundary crossing.
	for location_id in street_order:
		Atlas.plate(Atlas.street(location_id))
	var saved: Dictionary = GameState.shared_state.get("street_positions", {})
	var layout := int(GameState.shared_state.get("street_layout_version",0))
	if layout == 4:
		for saved_key in saved: saved[saved_key] = float(saved[saved_key]) * BLOCK_WIDTH / 900.0
	elif layout != 5: saved = {}
	GameState.shared_state["street_positions"] = saved
	GameState.shared_state["street_layout_version"] = 5
	var key := "%s_%d_%s" % [GameState.current_role, GameState.current_day, segment_id]
	var default_x := maxi(0, street_order.find(GameState.current_location)) * BLOCK_WIDTH + 300.0
	if not saved.has(key):
		var legacy := WorldGraph.legacy_segment_for(GameState.current_location)
		var old_key := "%s_%d_%s" % [GameState.current_role, GameState.current_day, str(legacy.get("id", ""))]
		if saved.has(old_key):
			var old_places: Array = legacy.locations
			var old_index := clampi(int(float(saved[old_key]) / BLOCK_WIDTH), 0, old_places.size() - 1)
			default_x = street_order.find(str(old_places[old_index])) * BLOCK_WIDTH + fposmod(float(saved[old_key]), BLOCK_WIDTH)
	street.player_x = float(saved.get(key, default_x))
	if str(GameState.shared_state.get("map_arrival", "")) == GameState.current_location:
		street.player_x = default_x
		GameState.shared_state.erase("map_arrival")
	street.move_player(0, 0)
	street.moved.connect(_on_walk)
	_build_ui()
	GameState.state_changed.connect(_refresh)
	_on_walk(street.player_x)
	_refresh()
	WorldSound.set_active(true)
	ChapterSystem.mark_opening_seen()


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


func _load_interactive_spaces() -> void:
	interactive_spaces.clear()
	var path := "res://data/world/interactive_spaces.json"
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid interactive space data")
		return
	for row in parsed.get("spaces", []):
		if row is Dictionary:
			interactive_spaces.append(row)


func _build_ui() -> void:
	location_title = _label(self, "", Vector2(142, 18), Vector2(590, 35), 23, Color("e9dcc4"))
	clock_label = _label(self, "", Vector2(720, 22), Vector2(330, 30), 17, Color("aab8b6"), HORIZONTAL_ALIGNMENT_RIGHT)
	wallet_icon = TextureRect.new()
	wallet_icon.texture = preload("res://scripts/town_sound/MediaTheme.gd").icon("wallet")
	wallet_icon.position = Vector2(1072, 20)
	wallet_icon.size = Vector2(28, 28)
	wallet_icon.modulate = Color("f1d08d")
	wallet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wallet_icon)
	wallet_label = _label(self, "", Vector2(1102, 22), Vector2(103, 30), 17, Color("f1d08d"), HORIZONTAL_ALIGNMENT_RIGHT)
	var guide_panel := _panel(self, Vector2(38, 80), Vector2(950, 48), Color("10161c", 0.82), Color("6d817c", 0.75))
	time_guidance_label = _label(guide_panel, "", Vector2(16, 9), Vector2(918, 30), 16, Color("f0e3c7"))
	var map_button := _button(self, "地图 M", Vector2(42, 15), Vector2(80, 40), "quiet")
	map_button.pressed.connect(_open_map)
	var tools := [{"id":"recorder", "label":"R · 录音", "action":_open_pocket_recorder}, {"id":"camera", "label":"C · 相机", "action":_open_pocket_camera}, {"id":"album", "label":"P · 相册", "action":_open_pocket_album}]
	for index in tools.size():
		var button := _button(self, "", Vector2(1220 + index * 54, 15), Vector2(44, 40), "quiet")
		button.icon = preload("res://scripts/town_sound/MediaTheme.gd").icon(str(tools[index].id))
		button.tooltip_text = str(tools[index].label)
		button.pressed.connect(tools[index].action)
	var notes := _button(self, "Pocket" if GameState.current_role == "A" else "日程本", Vector2(1395, 15), Vector2(78, 40), "quiet")
	notes.tooltip_text = "J / Tab · 打开随身本"
	notes.pressed.connect(_open_journal)
	var menu := _button(self, "回到主页", Vector2(1480, 15), Vector2(106, 40), "quiet")
	menu.pressed.connect(_return_to_menu)
	_label(self, "R 录音 · C 拍照 · P 相册 · J / Tab 随身本", Vector2(1010, 88), Vector2(550, 28), 14, Color("f0e3c7"), HORIZONTAL_ALIGNMENT_RIGHT)
	_build_event_modal()


func _refresh() -> void:
	if not is_instance_valid(street) or not is_instance_valid(location_title): return
	WorldSound.set_location(GameState.current_location)
	GameState.refresh_appointments()
	location_title.text = _location_name(GameState.current_location)
	clock_label.text = "%s · 第%d天 · %s" % [GameState.current_role,GameState.current_day,GameState.clock_text()]
	var money_changed := displayed_money >= 0 and displayed_money != GameState.money
	displayed_money = GameState.money
	wallet_label.text = "%d 元" % GameState.money
	if money_changed and is_instance_valid(wallet_icon):
		wallet_icon.scale = Vector2(1.35, 1.35)
		wallet_icon.pivot_offset = wallet_icon.size * 0.5
		create_tween().tween_property(wallet_icon, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	time_guidance_label.text = _time_guidance_text()
	if GameState.current_day == 6 and GameState.current_minute >= 1200: clock_label.text += " · 确认%d/12" % GameState.residency_confirmations
	street.walk_limit = street_order.find("park") * BLOCK_WIDTH + 1060 if GameState.current_minute < WorldGraph.LOOKOUT_OPEN and street_order.has("park") else INF
	if street.player_x > street.walk_limit:
		street.player_x = street.walk_limit
		street.move_player(0, 0)
	_rebuild_hotspots()


func _time_guidance_text() -> String:
	var base := GameState.current_time_guidance()
	if GameState.current_role != "B":
		return base
	var commitment := GameState.next_commitment()
	if commitment.is_empty() or str(commitment.get("location", "")) == GameState.current_location:
		return base
	var return_by := int(commitment.get("return_by", commitment.get("start", 0)))
	var home_x := street_order.find(str(commitment.get("location", "dorm"))) * BLOCK_WIDTH + 800.0
	var shortest := int(ceil(absf(home_x - street.player_x) / street.SPEED / 4.0)) + 1
	var leave_by := return_by - shortest
	return "%s 回家工作 · 慢走约%d分钟 · %s%s动身" % [_minute_text(return_by), shortest, "往左" if home_x < street.player_x else "往右", "，现在该" if GameState.current_minute >= leave_by else "，" + _minute_text(leave_by) + "前"]


func _spaces_at(location_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for space in interactive_spaces:
		if str(space.get("location_id", "")) == location_id:
			result.append(space)
	return result


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
	camera.context = {"location": GameState.current_location, "title": _location_name(GameState.current_location), "day": GameState.current_day, "role": GameState.current_role, "game_minute": GameState.current_minute, "subjects": _camera_subjects()}
	_show_pocket_panel(camera)

func _camera_subjects() -> Array[Dictionary]:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/photography/subjects.json"))
	var result: Array[Dictionary] = []
	# Authored points belong to the scene plate, never to a fixed screen center.
	for index in street_order.size():
		var left: float = index * BLOCK_WIDTH - 80.0 - street.camera_x
		if left > 1600.0 or left + 1760.0 < 0.0: continue
		for raw in catalog.get("locations", {}).get(street_order[index], []):
			var subject: Dictionary = raw.duplicate(true)
			var target: Array = subject.get("target", [0.5, 0.5])
			var screen_x: float = (left + float(target[0]) * 1760.0) / 1600.0
			if screen_x < 0.04 or screen_x > 0.96: continue
			subject["target"] = [screen_x, float(target[1])]
			result.append(subject)
	return result


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
	SaveManager.save_or_report("居民互动后保存失败")
	_refresh()
	_show_line(name, profile_line if not profile_line.is_empty() else status_message)


func _ambient_event_id(resident_id: String) -> String:
	return "ambient_d%d_%s_%s" % [GameState.current_day, GameState.current_role.to_lower(), resident_id]


func _confirmation_request_event_id(resident_id: String) -> String:
	return "confirmation_request_d%d_%s_%s" % [GameState.current_day, GameState.current_role.to_lower(), resident_id]


func _request_confirmation(resident_id: String) -> void:
	var result := RelationshipSystem.request_confirmation_action(resident_id)
	status_message = str(result.get("message", "这次请求已经被记录。"))
	SaveManager.save_or_report("确认请求后保存失败")
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
		var launch_module := str(result.get("launch_module", ""))
		if not launch_module.is_empty():
			event_overlay.visible = false
			if not SceneRouter.gameplay_module(launch_module, event_id, result.get("rollback_snapshot", {})):
				event_overlay.visible = true
				status_message = "玩法暂时无法启动，本次事件尚未生效。"
				_refresh()
			return
		SaveManager.save_or_report("事件完成后保存失败")
		_show_event_result(result, before)
	else:
		_show_line("", status_message)
	_refresh()


func _show_event_result(result: Dictionary, _before: Dictionary) -> void:
	_show_line("", str(result.get("message", "这段经历留在了记忆里。")))


func _build_event_modal() -> void:
	event_overlay = ColorRect.new()
	event_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_overlay.color = Color(0, 0, 0, 0.12)
	event_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(event_overlay)
	event_panel = _panel(event_overlay, Vector2(810, 260), Vector2(740, 360), Color("16232b", 0.98), Color("647676"))
	event_overlay.visible = false


func _open_event(event_id: String) -> void:
	if not EventSystem.events.has(event_id): return
	var invitation_npc := str(EventSystem.events[event_id].get("invitation_npc",""))
	if not invitation_npc.is_empty():
		_talk_nearby(invitation_npc,"minigame_hook")
		return
	staged_event_id = event_id
	staged_event_data = EventSystem.events[event_id]
	staged_event_index = 0
	var presentation := EventSystem.resolved_presentation(staged_event_data)
	var beats: Array = presentation.get("beats", [])
	if beats.is_empty():
		beats = presentation.get("lines", []).duplicate(true)
	if beats.is_empty():
		beats = [{"speaker":"", "text":str(presentation.get("summary", staged_event_data.get("choice_text", "")))}]
	staged_event_data = staged_event_data.duplicate(true)
	staged_event_data["walking_beats"] = beats
	_show_dialogue_beat()


func _spend_action_time(minutes: int) -> bool:
	if GameState.use_free_time(minutes):
		return true
	status_message = "这一刻太短了。可以在长椅上坐一会，或回家休息。"
	_show_line("", status_message)
	_refresh()
	return false


func _return_to_menu() -> void:
	_remember_position()
	if _guard_pocket_audio(): return
	if not SaveManager.save_or_report("返回菜单前保存失败"):
		status_message = "存档写入失败，暂时留在小镇。"
		_refresh()
		return
	SceneRouter.main_menu()


func _location_name(id: String) -> String:
	var row: Dictionary = locations.get(id, {})
	return str(row.get("name", id))


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
	if kind == "dialogue":
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", Color("d6c19f"))
		button.add_theme_color_override("font_hover_color", Color("fff5da"))
		button.add_theme_font_size_override("font_size", 20)
		return
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


func _exit_tree() -> void:
	WorldSound.set_active(false)

func _guard_pocket_audio() -> bool:
	if is_instance_valid(pocket_panel) and pocket_panel.has_method("set_compact"):
		if pocket_panel.recorder.capturing or pocket_panel.draft != null:
			pocket_panel.set_compact(false)
			pocket_panel.status_label.text = "请先停止并保存，或放弃当前录音，再离开小镇。"
			return true
	return false

func _process(delta: float) -> void:
	street.enabled = not is_instance_valid(conversation) and not event_overlay.visible and not _pocket_blocks_walking() and not pocket_opening and not SceneRouter.transitioning
	if street.enabled and DisplayServer.window_is_focused():
		GameState.advance_world_clock(delta)

func _on_walk(x: float) -> void:
	var index := clampi(int(x / BLOCK_WIDTH), 0, street_order.size() - 1)
	if index == current_index: return
	current_index = index
	GameState.current_location = street_order[index]
	_remember_position()
	GameState.commit_active_role_state()
	SaveManager.save_or_report("街道位置保存失败")
	_refresh()

func _remember_position() -> void:
	GameState.shared_state["street_layout_version"] = 5
	var positions: Dictionary = GameState.shared_state.get("street_positions", {})
	positions["%s_%d_%s" % [GameState.current_role, GameState.current_day, segment_id]] = street.player_x
	GameState.shared_state["street_positions"] = positions

func _rebuild_hotspots() -> void:
	street.hotspots.clear()
	for index in street_order.size():
		var bench = Atlas.street(street_order[index]).get("bench_x")
		if bench != null:
			street.hotspots.append({"x":index*BLOCK_WIDTH+float(bench),"kind":"bench","label":"坐一会"})
	if street.sitting:
		street.hotspots.append({"x":street.player_x,"kind":"bench","label":"长椅"})
	# Keep exits on the actual movement limits. The old right exit shared the
	# same x position as the final bench, so nearest() always selected the bench
	# and made the road interaction unreachable.
	var center := current_index * BLOCK_WIDTH + float(Atlas.street(GameState.current_location).get("door_x",800))
	if GameState.current_location == "park" and GameState.current_minute < WorldGraph.LOOKOUT_OPEN:
		street.hotspots.append({"x":current_index * BLOCK_WIDTH + 1060.0, "kind":"closed", "label":"观景台 · 21:00 开放"})
		street.hotspots.append({"x":current_index * BLOCK_WIDTH + 930.0, "kind":"wait_open", "label":"坐下等到 21:00"})
		return
	# Outdoor residents remain available even after the shop closes.
	var people := ScheduleSystem.residents_at(GameState.current_location, GameState.current_day, GameState.current_minute)
	for index in mini(people.size(), 3):
		var person: Dictionary = ScheduleSystem.residents.get(people[index], {})
		street.hotspots.append({"x":current_index*BLOCK_WIDTH + 450 + index * 150, "kind":"person", "id":people[index], "label":"和%s交谈" % str(person.get("display_name", people[index]))})
	var hours: Array = locations.get(GameState.current_location,{}).get("hours",[])
	var open_now := hours.is_empty() or hours.any(func(h: Array) -> bool: return GameState.current_minute >= int(h[0]) and GameState.current_minute < int(h[1]))
	if not open_now:
		street.hotspots.append({"x":center,"kind":"shop_closed","label":"门已经合上了"})
		return
	if GameState.current_location in ["residence", "dorm"]:
		var own_home := "residence" if GameState.current_role == "A" else "dorm"
		if GameState.current_location == own_home:
			street.hotspots.append({"x":center, "kind":"home", "label":"回家"})
	else:
		var rooms := _spaces_at(GameState.current_location)
		for i in rooms.size():
			street.hotspots.append({"x":center + i * 120, "kind":"door", "id":str(rooms[i].id), "label":"进入" + str(rooms[i].name)})
	for item in outdoor_objects:
		if str(item.get("location_id", "")) == GameState.current_location:
			if str(item.get("kind","")) == "dialogue":
				if not DialogueSystem.invitation_for(str(item.npc_id)).is_empty(): street.hotspots.append({"x":center,"kind":"invitation","id":str(item.npc_id),"label":str(item.name)})
			elif str(item.get("kind", "")) == "shop":
				street.hotspots.append({"x":center + 145.0, "kind":"shop", "id":str(item.get("shop_id", "")), "label":str(item.name)})
			else: street.hotspots.append({"x":center, "kind":"module", "id":str(item.module_id), "label":str(item.name) + " · " + GameplayModuleSystem.time_hint(str(item.module_id))})
	var available := EventSystem.available_events()
	for index in available.size():
		street.hotspots.append({"x":center - 190.0 - index * 110.0, "kind":"event", "id":str(available[index].id), "label":str(available[index].get("choice_text", "交谈"))})
	street.queue_redraw()

func _interact() -> void:
	var item: Dictionary = street.nearest()
	if item.is_empty(): return
	if str(item.kind) in ["home", "door", "module"] and _guard_pocket_audio(): return
	_remember_position()
	SaveManager.save_or_report("地点互动前保存失败")
	match str(item.kind):
		"shop_closed": _show_line("", "门内很安静，桌上留着半杯咖啡。晚一点或明天再来。")
		"roads": _open_map()
		"closed": _show_line("", "观景台将在晚上九点开放。可以在旁边的长椅坐一会。")
		"wait_open": _sit_on_bench(item)
		"home": SceneRouter.enter_space("home_a" if GameState.current_role == "A" else "home_b")
		"door":
			if not _guard_pocket_audio(): SceneRouter.enter_space(str(item.id))
		"shop": _open_shop(str(item.id))
		"invitation": _talk_nearby(str(item.id),"minigame_hook")
		"module":
			if _guard_pocket_audio(): return
			var invite := DialogueSystem.invitation_for_module(str(item.id))
			if str(item.id) == "chess" and not DialogueSystem.invitation_accepted("chess"):
				if not DialogueSystem.invitation_for(str(invite.get("npc",""))).is_empty(): _talk_nearby(str(invite.npc),"minigame_hook")
				else: _show_line("", "棋盘摆好了，对面的椅子还空着。等棋友来再聊聊。")
			else: SceneRouter.gameplay_module(str(item.id), "street:" + GameState.current_location)
		"event": _open_event(str(item.id))
		"person": _talk_nearby(str(item.id))
		"bench": _sit_on_bench(item)

func _talk_nearby(resident_id: String, topic := "greeting") -> void:
	if is_instance_valid(conversation): return
	conversation = preload("res://scripts/ui/conversation_panel.gd").new()
	conversation.npc = resident_id
	conversation.starting_topic = topic
	for item in street.hotspots:
		if str(item.get("id","")) == resident_id and absf(float(item.x)-street.player_x) > 1.0: street.facing = signf(float(item.x)-street.player_x)
	street.velocity = 0.0
	add_child(conversation)

func _legacy_talk_nearby(resident_id: String) -> void:
	if not GameState.has_event(_ambient_event_id(resident_id)):
		_ambient_talk(resident_id)
		return
	var preview := RelationshipSystem.confirmation_request_preview(resident_id)
	if bool(preview.get("available", false)) and not GameState.has_event(_confirmation_request_event_id(resident_id)):
		_request_confirmation(resident_id)
		_show_line("", status_message)
	else:
		_show_line("", "刚才的话还留在风里。下次见面再聊吧。")

func _clear_dialogue() -> void:
	if speech_tween: speech_tween.kill()
	spoken_line = null
	dialogue_choices.clear()
	for child in event_panel.get_children():
		event_panel.remove_child(child)
		child.queue_free()
	event_panel.position.x = 810 if street.player_x - street.camera_x < 800 else 50
	event_overlay.visible = true
	street.enabled = false

func _show_line(speaker: String, text: String) -> void:
	_clear_dialogue()
	_label(event_panel, speaker, Vector2(32, 18), Vector2(675, 28), 19, Color("d6b58d"))
	var line := _label(event_panel, text, Vector2(32, 61), Vector2(675, 180), 23, Color("ede3ce"))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spoken_line = line
	line.visible_characters = 0
	speech_tween = create_tween()
	speech_tween.tween_property(line, "visible_characters", text.length(), maxf(0.3, text.length() / 28.0))
	var next := _button(event_panel, "继续  Space / Enter", Vector2(430, 288), Vector2(265, 43), "dialogue")
	next.pressed.connect(func() -> void: event_overlay.hide())
	dialogue_choices.append(next)

func _show_dialogue_beat() -> void:
	var beats: Array = staged_event_data.get("walking_beats", [])
	if staged_event_index >= beats.size():
		var choices: Array = staged_event_data.get("choices", [])
		if choices.is_empty():
			_resolve_event(staged_event_id)
			return
		_clear_dialogue()
		_label(event_panel, "你说……    W / S 或 ↑ / ↓ 选择 · Enter 回应", Vector2(32, 16), Vector2(675, 35), 18, Color("ede3ce"))
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(30, 62)
		scroll.size = Vector2(680, 265)
		event_panel.add_child(scroll)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(box)
		for i in choices.size():
			var choice: Dictionary = choices[i]
			var button := _button(box, "你：%s" % str(choice.get("label", "")), Vector2.ZERO, Vector2(650, 56), "dialogue")
			button.custom_minimum_size = Vector2(650, 56)
			button.pressed.connect(_resolve_event.bind(staged_event_id, str(choice.id)))
			dialogue_choices.append(button)
		if not dialogue_choices.is_empty(): dialogue_choices[0].grab_focus()
		return
	var raw = beats[staged_event_index]
	var beat: Dictionary = raw if raw is Dictionary else {"text":str(raw)}
	_show_line(str(beat.get("speaker", "")), str(beat.get("text", "")))
	var next := dialogue_choices[0]
	for connection in next.pressed.get_connections(): next.pressed.disconnect(connection.callable)
	next.pressed.connect(func() -> void:
		staged_event_index += 1
		_show_dialogue_beat())

func _open_journal() -> void:
	if _guard_pocket_audio(): return
	_remember_position()
	if not SaveManager.save_or_report("打开日志前保存失败"):
		status_message = "存档写入失败，暂时无法离开当前画面。"
		_refresh()
		return
	SceneRouter.journal()


func _open_shop(shop_id: String) -> void:
	if is_instance_valid(pocket_panel): return
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	panel.shop_id = shop_id
	_show_pocket_panel(panel)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(conversation): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if SceneRouter.transitioning: return
	if _pocket_blocks_walking() or pocket_opening: return
	if event_overlay.visible:
		if street.sitting and event.is_action_pressed("interact"):
			if not dialogue_choices.is_empty(): dialogue_choices[0].pressed.emit()
		elif event.is_action_pressed("ui_cancel"):
			if street.sitting: _stand_from_bench()
			else: event_overlay.hide()
		elif (event.is_action_pressed("dialogue_advance") or event.is_action_pressed("ui_accept")) and dialogue_choices.size() == 1:
			if is_instance_valid(spoken_line) and spoken_line.visible_characters >= 0 and spoken_line.visible_characters < spoken_line.text.length():
				if speech_tween: speech_tween.kill()
				spoken_line.visible_characters = -1
			else: dialogue_choices[0].pressed.emit()
		elif dialogue_choices.size() > 1 and (event.is_action_pressed("ui_up") or event.physical_keycode == KEY_W):
			_focus_dialogue_choice(-1)
		elif dialogue_choices.size() > 1 and (event.is_action_pressed("ui_down") or event.physical_keycode == KEY_S):
			_focus_dialogue_choice(1)
	elif event.is_action_pressed("open_camera"): _open_pocket_camera()
	elif event.is_action_pressed("open_recorder"): _open_pocket_recorder()
	elif event.is_action_pressed("open_album"): _open_pocket_album()
	elif event.is_action_pressed("interact"): _interact()
	elif event.is_action_pressed("open_journal"): _open_journal()
	elif event.is_action_pressed("open_map"): _open_map()
	elif event.is_action_pressed("ui_cancel"): _return_to_menu()
	get_viewport().set_input_as_handled()

func _focus_dialogue_choice(step: int) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var current := dialogue_choices.find(focused)
	dialogue_choices[posmod(current + step, dialogue_choices.size())].grab_focus()
	WorldSound.play_ui("focus")

func _pocket_blocks_walking() -> bool:
	if not is_instance_valid(pocket_panel): return false
	return not (pocket_panel.has_method("set_compact") and bool(pocket_panel.get("compact")))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(street):
		_remember_position()
		SaveManager.save_or_report("关闭窗口前保存失败")

func _open_map() -> void:
	if _guard_pocket_audio(): return
	_remember_position()
	if not SaveManager.save_or_report("打开地图前保存失败"):
		status_message = "存档写入失败，暂时无法离开当前画面。"
		_refresh()
		return
	SceneRouter.town_map()

func _sit_on_bench(item: Dictionary) -> void:
	street.player_x = float(item.x)
	street.velocity = 0.0
	street.gait_weight = 0.0
	street.sitting = true
	street.queue_redraw()
	_bench_menu()
func _bench_menu() -> void:
	_clear_dialogue()
	_label(event_panel,"坐在长椅上 · " + GameState.clock_text(),Vector2(30,20),Vector2(670,40),24,Color("f0e3c7"))
	_label(event_panel,"海风从身旁经过。",Vector2(30,70),Vector2(670,40),22,Color("c9d8cd"))
	var minutes := mini(30, GameState.current_block_remaining())
	if minutes > 0:
		var wait := _button(event_panel,"坐一会 · %d分钟" % minutes,Vector2(30,132),Vector2(660,45),"dialogue")
		wait.pressed.connect(_wait_on_bench.bind(minutes))
		dialogue_choices.append(wait)
	if GameState.current_location == "park" and GameState.current_minute < WorldGraph.LOOKOUT_OPEN and GameState.can_fit_now(WorldGraph.LOOKOUT_OPEN - GameState.current_minute):
		var until_open := _button(event_panel,"等到观景台开放 · 21:00",Vector2(30,188),Vector2(660,45),"dialogue")
		until_open.pressed.connect(_wait_on_bench.bind(WorldGraph.LOOKOUT_OPEN-GameState.current_minute))
		dialogue_choices.append(until_open)
	var stand := _button(event_panel,"站起来 · Esc",Vector2(30,264),Vector2(660,45),"dialogue")
	stand.pressed.connect(_stand_from_bench)
	dialogue_choices.append(stand)
	dialogue_choices[0].grab_focus()
func _wait_on_bench(minutes: int) -> void:
	if not GameState.use_free_time(minutes):
		status_message = "这段空闲时间不够，不能一直等到那个时刻。"
		_show_line("", status_message)
		return
	if not street.hotspots.any(func(h: Dictionary) -> bool: return str(h.kind) in ["bench","wait_open"] and absf(float(h.x)-street.player_x)<1):
		street.hotspots.append({"x":street.player_x,"kind":"bench","label":"长椅"})
	_remember_position()
	SaveManager.save_or_report("长椅等待后保存失败")
	_bench_menu()
func _stand_from_bench() -> void:
	street.sitting = false
	street.queue_redraw()
	event_overlay.hide()
