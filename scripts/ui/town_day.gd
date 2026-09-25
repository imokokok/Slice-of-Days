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
var BLOCK_WIDTH := 1600.0
var route_offset := 0.0
var route_hint: Label
const Atlas = preload("res://scripts/ui/scene_atlas.gd")
const Composition = preload("res://scripts/ui/street_composition.gd")
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
	route_offset = float(segment.get("offset", 0))
	BLOCK_WIDTH = (float(segment.width) - route_offset) / street_order.size()
	var object_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/street_objects.json"))
	if object_data is Dictionary:
		outdoor_objects = object_data.get("objects", [])
	else:
		push_error("Invalid street object data")
	street = preload("res://scripts/ui/walk_stage.gd").new()
	add_child(street)
	backdrop = street
	street.world_width = float(segment.width)
	street.route_id = segment_id
	street.composition_anchor = 800.0
	for index in street_order.size():
		street.places.append({"id": street_order[index], "name": _location_name(street_order[index]), "kind":locations[street_order[index]].kind, "interior":locations[street_order[index]].interior, "x": _world_x(index, Composition.center_local(street_order[index])), "width":BLOCK_WIDTH})
	# Exteriors use the simple street geometry and approved hand-drawn cutouts.
	# The AI reference atlas is reserved for existing interiors.
	var saved: Dictionary = GameState.shared_state.get("street_positions", {})
	var layout := int(GameState.shared_state.get("street_layout_version",0))
	if layout == 4:
		for saved_key in saved: saved[saved_key] = float(saved[saved_key]) * 1600.0 / 900.0
	elif layout not in [5, 6]: saved = {}
	GameState.shared_state["street_positions"] = saved
	GameState.shared_state["street_layout_version"] = 6
	var key := "%s_%d_%s" % [GameState.current_role, GameState.current_day, segment_id]
	var restore_saved_position := saved.has(key)
	var default_x := _world_x(maxi(0, street_order.find(GameState.current_location)), 300)
	if not saved.has(key):
		var legacy := WorldGraph.legacy_segment_for(GameState.current_location)
		var old_key := "%s_%d_%s" % [GameState.current_role, GameState.current_day, str(legacy.get("id", ""))]
		if saved.has(old_key):
			var old_places: Array = legacy.locations
			var old_index := clampi(int(float(saved[old_key]) / 1600.0), 0, old_places.size() - 1)
			if layout == 4 and street_order.has(str(old_places[old_index])):
				GameState.current_location = str(old_places[old_index])
				default_x = _world_x(street_order.find(GameState.current_location), fposmod(float(saved[old_key]), 1600.0))
	street.player_x = float(saved.get(key, default_x))
	# Scripted relocations and restored saves can request another location on
	# the same joined coast. Do not let an old coast coordinate undo that move.
	if saved.has(key) and _index_at(street.player_x) != street_order.find(GameState.current_location):
		street.player_x = default_x
	if str(GameState.shared_state.get("map_arrival", "")) == GameState.current_location:
		street.player_x = default_x
		GameState.shared_state.erase("map_arrival")
	var arrival: Dictionary = GameState.shared_state.get("route_arrival", {})
	if str(arrival.get("route", "")) == segment_id:
		street.player_x = float(arrival.x)
		street.facing = float(arrival.get("facing", 1))
		GameState.shared_state.erase("route_arrival")
	street.camera_x = clampf(street.player_x - 800, 0, street.world_width - 1600)
	street.move_player(0, 0)
	street.moved.connect(_on_walk)
	_build_ui()
	GameState.state_changed.connect(_refresh)
	_on_walk(street.player_x)
	_refresh()
	if not restore_saved_position:
		var block_left := route_offset+current_index*BLOCK_WIDTH
		var clear_x := Composition.clear_arrival(street.player_x,street.hotspots,block_left,block_left+BLOCK_WIDTH)
		if not is_equal_approx(clear_x,street.player_x):
			street.player_x=clear_x
			street.move_player(0,0)
			_remember_position()
			SaveManager.save_or_report("抵达位置保存失败")
	WorldSound.set_active(true)
	ChapterSystem.mark_opening_seen()
	add_child(preload("res://scripts/residency/gameplay_shell.gd").new())


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
	route_hint = _label(self, "", Vector2(380, 750), Vector2(840, 50), 23, Color("fff3d8"), HORIZONTAL_ALIGNMENT_CENTER)
	route_hint.add_theme_color_override("font_shadow_color", Color("152f3e"))
	route_hint.add_theme_constant_override("shadow_offset_x", 2)
	route_hint.add_theme_constant_override("shadow_offset_y", 2)
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
		button.tooltip_text = LocalizationSystem.text(tools[index].label)
		button.pressed.connect(tools[index].action)
	var notes := _button(self, "Pocket" if GameState.current_role == "A" else "日程本", Vector2(1395, 15), Vector2(78, 40), "quiet")
	notes.tooltip_text = LocalizationSystem.text("J / Tab · 打开随身本")
	notes.pressed.connect(_open_journal)
	var menu := _button(self, "回到主页", Vector2(1480, 15), Vector2(106, 40), "quiet")
	menu.pressed.connect(_return_to_menu)
	_label(self, "R 录音 · C 拍照 · P 相册 · J / Tab 随身本", Vector2(1010, 88), Vector2(550, 28), 14, Color("f0e3c7"), HORIZONTAL_ALIGNMENT_RIGHT)
	_build_event_modal()


func _refresh() -> void:
	if not is_instance_valid(street) or not is_instance_valid(location_title): return
	WorldSound.set_location(GameState.current_location)
	GameState.refresh_appointments()
	location_title.text = LocalizationSystem.text(_location_name(GameState.current_location))
	clock_label.text = LocalizationSystem.text("第%d天 · %s" % [GameState.current_day,GameState.clock_text()])
	var money_changed := displayed_money >= 0 and displayed_money != GameState.money
	displayed_money = GameState.money
	wallet_label.text = LocalizationSystem.text("%d 元" % GameState.money)
	if money_changed and is_instance_valid(wallet_icon):
		wallet_icon.scale = Vector2(1.35, 1.35)
		wallet_icon.pivot_offset = wallet_icon.size * 0.5
		create_tween().tween_property(wallet_icon, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	time_guidance_label.text = LocalizationSystem.text(_time_guidance_text())
	street.walk_limit = _world_x(street_order.find("park"), 1060) if GameState.current_minute < WorldGraph.LOOKOUT_OPEN and street_order.has("park") else INF
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
	var home_id := str(commitment.get("location", "dorm"))
	var shortest := WorldGraph.walk_minutes(GameState.current_location,home_id) + 1
	var leave_by := return_by - shortest
	return "%s 到%s · 步行约%d分钟 · %s" % [_minute_text(return_by), str(commitment.get("location_label","工作地点")), shortest, "现在该动身了" if GameState.current_minute >= leave_by else _minute_text(leave_by) + "前动身"]


func _spaces_at(location_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for space in interactive_spaces:
		if bool(space.get("street_counter",false)): continue
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
	if not CharacterSystem.owns_pocket_item("recorder"): return
	if is_instance_valid(pocket_panel) or pocket_opening: return
	GlobalRecorder.open_recorder()


func _open_record_store() -> void:
	if GameState.current_location != "record_store": return
	if is_instance_valid(pocket_panel) or pocket_opening: return
	var panel = load("res://scripts/town_sound/record_shop/RecordShop.gd").new()
	_show_pocket_panel(panel)


func _open_pocket_album() -> void:
	if is_instance_valid(pocket_panel) or pocket_opening: return
	_show_pocket_panel(load("res://scripts/town_sound/PhotoAlbum.gd").new())


func _open_pocket_camera() -> void:
	if is_instance_valid(pocket_panel) or pocket_opening: return
	pocket_opening = true
	GlobalRecorder.capture_hidden=true
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
	GlobalRecorder.capture_hidden=false
	var camera = load("res://scripts/town_sound/PocketCamera.gd").new()
	camera.source = frame
	camera.context = {"location": GameState.current_location, "title": _location_name(GameState.current_location), "day": GameState.current_day, "role": GameState.current_role, "game_minute": GameState.current_minute, "subjects": _camera_subjects()}
	_show_pocket_panel(camera)

func _camera_subjects() -> Array[Dictionary]:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/photography/subjects.json"))
	var result: Array[Dictionary] = []
	# Authored points belong to the scene plate, never to a fixed screen center.
	for index in street_order.size():
		var span := BLOCK_WIDTH + 160.0
		var left: float = _world_x(index, 0) - 80.0 - street.camera_x
		if left > 1600.0 or left + span < 0.0: continue
		for raw in catalog.get("locations", {}).get(street_order[index], []):
			var subject: Dictionary = raw.duplicate(true)
			var target: Array = subject.get("target", [0.5, 0.5])
			var screen_x: float = (left + float(target[0]) * span) / 1600.0
			if screen_x < 0.04 or screen_x > 0.96: continue
			subject["target"] = [screen_x, float(target[1])]
			subject["location"] = street_order[index]
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
	event_panel = preload("res://scripts/ui/components/dialogue_card.gd").new()
	event_overlay.add_child(event_panel)
	event_panel.configure(street)
	event_overlay.visible = false


func _open_event(event_id: String) -> void:
	if event_id == "a_d5_translation":
		_start_market_encounter()
		return
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
	status_message = "这一刻太短了。可以回家休息，或换件事做。"
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
	label.text = LocalizationSystem.text(text_value)
	label.position = at
	label.size = label_size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, kind: String) -> Button:
	var button := Button.new()
	button.text = LocalizationSystem.text(text_value)
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
	# A focused tool owns input; a pocketed global recording survives travel.
	return GlobalRecorder.focused()


func _process(delta: float) -> void:
	street.enabled = not is_instance_valid(conversation) and not event_overlay.visible and not _pocket_blocks_walking() and not pocket_opening and not SceneRouter.transitioning and not (has_node("GameplayShell") and get_node("GameplayShell").blocks_walking())
	if street.enabled and DisplayServer.window_is_focused():
		GameState.advance_world_clock(delta)
	if not street.enabled: route_hint.text = ""; return
	route_hint.text = ""

func _market_encounter_key() -> String:
	return "market_encounter_%s_%d" % [GameState.current_role,GameState.current_day]

func _start_market_encounter() -> void:
	if is_instance_valid(conversation) or _guard_pocket_audio(): return
	if not DialogueSystem.argument_pending():
		_observe_market_afterward()
		return
	var snapshot := GameState.to_save_data().duplicate(true)
	_remember_position()
	GameState.shared_state[_market_encounter_key()] = true
	DialogueSystem.mark_argument(false)
	street.velocity = 0
	if not SaveManager.save_or_report("记录街边相遇失败"):
		GameState.load_save_data(snapshot)
		_show_line("", "先在这里停一会儿，稍后再听他们说。")
		return
	conversation = Control.new()
	conversation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conversation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(conversation)
	var words = preload("res://scripts/ui/street_argument.gd").new()
	words.street = street
	words.world_x = _place_center() + Composition.argument_offset()
	words.finish_requested.connect(_finish_market_encounter.bind(words))
	words.cancel_requested.connect(func() -> void:
		if is_instance_valid(conversation): conversation.queue_free())
	conversation.add_child(words)
	# _process recomputes the movement gate every frame.  Do not write a second
	# permanent value here while a dialogue is opening.
	street.queue_redraw()

func _finish_market_encounter(words: Node2D) -> void:
	if not words.finished: return
	if bool(DialogueSystem.argument_state().get("finished", false)): return
	var snapshot := GameState.to_save_data().duplicate(true)
	var metadata: Dictionary = GameplayModuleSystem.modules.get("translation",{})
	if not GameState.use_free_time(int(metadata.get("direct_time_minutes",30))):
		words.save_message = "眼下该回去忙了。这段话先记在心里，空下来再接着聊。"
		return
	var outcome := {"choice_id":"extension_complete","label":"在菜摊边听懂彼此","source_event_id":"street:produce_stall:conversation","interaction":{"mode":"conversation","selected_labels":["CICI 的记忆","尘缘的记忆"]}}
	GameState.shared_state[_market_encounter_key()+"_done"] = true
	DialogueSystem.mark_argument(true)
	if not GameplayModuleSystem.begin_session("translation","street:produce_stall:conversation") or not GameplayModuleSystem.complete_external("translation",outcome,metadata.get("external_results",{})) or not SaveManager.save_or_report("保存街边对话失败"):
		GameState.load_save_data(snapshot)
		words.save_message = "这段对话暂时没能保存，按空格可以重试。"
		return
	conversation.queue_free()
	_refresh()
	_observe_market_afterward.call_deferred()

func _observe_market_afterward() -> void:
	if is_instance_valid(conversation):
		await get_tree().process_frame
	MetaExperience.observe("produce_stall", "刚才放菜篮的地方，留下了一小片青菜叶。", {"kind":"place","event_id":"market_argument_finished","flags":{"argument_finished":true},"npc_id":"wu_wu","speaker_id":"wu_wu"})

func _world_x(index: int, local_x: float) -> float:
	return route_offset + index * BLOCK_WIDTH + local_x * BLOCK_WIDTH / 1600.0

func _place_center() -> float:
	return _world_x(current_index,Composition.center_local(GameState.current_location))

func _index_at(x: float) -> int:
	return clampi(int((x - route_offset) / BLOCK_WIDTH), 0, street_order.size() - 1)





func _on_walk(x: float) -> void:
	var index := _index_at(x)
	if index == current_index: return
	current_index = index
	GameState.current_location = street_order[index]
	_remember_position()
	GameState.commit_active_role_state()
	SaveManager.save_or_report("街道位置保存失败")
	_refresh()

func _remember_position() -> void:
	GameState.shared_state["street_layout_version"] = 6
	var positions: Dictionary = GameState.shared_state.get("street_positions", {})
	positions["%s_%d_%s" % [GameState.current_role, GameState.current_day, segment_id]] = street.player_x
	GameState.shared_state["street_positions"] = positions

func _transport_sign_positions() -> Array[float]:
	var result: Array[float] = [110.0, street.world_width-110.0]
	if street.world_width<6400: return result
	var doors: Array[float] = []
	for i in street_order.size():
		if not _spaces_at(street_order[i]).is_empty():
			doors.append(_world_x(i,Composition.center_local(street_order[i]))+Composition.entry_offset(street_order[i]))
	# Keep the middle sign near the midpoint, but give door and sign separate reach zones.
	for offset in [0.0,260.0,-260.0,420.0,-420.0]:
		var candidate: float = street.world_width*.5+offset
		if doors.all(func(x: float) -> bool: return absf(candidate-x)>street.DOOR_REACH+130.0):
			result.insert(1,candidate)
			break
	return result

func _rebuild_hotspots() -> void:
	# Snapshot the rendered people before replacing schedule/interaction data.
	street.presented_residents()
	street.hotspots.clear()
	street.neighboring_residents.clear()
	street.queue_redraw()
	var building_center := _place_center()
	var center := building_center + Composition.entry_offset(GameState.current_location)
	if GameState.current_location == "residence":
		center = building_center + Composition.home_entry_offset(GameState.current_role)
	var sign_positions := _transport_sign_positions()
	for sign_x in sign_positions:
		var sign_location := street_order[clampi(_index_at(sign_x),0,street_order.size()-1)]
		street.hotspots.append({"x":sign_x,"reach":110.0,"kind":"transport","id":sign_location,"label":"小镇站牌 · 查看路线与出行方式"})
	for i in street_order.size():
		var place := street_order[i]
		# Adjacent blocks are already visible before the player crosses a boundary.
		if place != GameState.current_location:
			var neighbors := DialogueSystem.people_at(place, "")
			var at := _world_x(i,Composition.center_local(place))
			for npc in neighbors:
				street.neighboring_residents.append({"kind":"person","id":npc,"x":at+float(DialogueSystem.resident_placement(npc).x)})
	if preload("res://scripts/core/coastal_fishing.gd").LOCATIONS.has(GameState.current_location):
		street.hotspots.append({"x":_world_x(current_index,720 if GameState.current_location=="park" else 1190),"kind":"fishing","label":"走到海边钓位 · 每竿 10 分钟"})
	if GameState.current_location == "park" and GameState.current_minute < WorldGraph.LOOKOUT_OPEN:
		street.hotspots.append({"x":_world_x(current_index, 1060), "kind":"closed", "label":"观景台 · 21:00 开放"})
		return
	# Outdoor residents remain available even after the shop closes.
	var people := DialogueSystem.people_at(GameState.current_location, "")
	for index in people.size():
		var person: Dictionary = ScheduleSystem.residents.get(people[index], {})
		var person_x := building_center + float(DialogueSystem.resident_placement(people[index]).x)
		street.hotspots.append({"x":person_x, "kind":"person", "id":people[index], "label":"和%s交谈" % str(person.get("display_name", people[index]))})
	if GameState.current_location in ["residence", "dorm"]:
		var own_home := CoreLoopSystem.home()
		if GameState.current_location == own_home:
			var home_label := "从楼梯回家 · 楼上" if GameState.current_role == "A" else "回家 · 楼下"
			street.hotspots.append({"x":center, "kind":"home", "reach":street.DOOR_REACH, "label":home_label})
	elif GameState.current_location == "cafe":
		var hours := WorldGraph.location_status("cafe")
		street.hotspots.append({"x":center,"kind":"counter","id":"grocery","reach":street.DOOR_REACH,"label":"和老板说话 · 购买杂货" if bool(hours.open) else "杂货店 · 休息中（08:00—22:00）"})
	else:
		var rooms := _spaces_at(GameState.current_location)
		for i in rooms.size():
			var hours := WorldGraph.location_status(GameState.current_location)
			var caption := "进入"+str(rooms[i].name) if bool(hours.open) else str(rooms[i].name)+" · 休息中（"+str(hours.hours)+"）"
			street.hotspots.append({"x":center + i * 120, "kind":"door", "reach":street.DOOR_REACH, "id":str(rooms[i].id), "label":caption})
	for item in outdoor_objects:
		if not ChapterSystem.module_available(str(item.get("module_id",""))): continue
		if str(item.get("location_id", "")) == GameState.current_location:
			if str(item.get("kind","")) == "dialogue":
				if not DialogueSystem.invitation_for(str(item.npc_id)).is_empty(): street.hotspots.append({"x":center,"kind":"invitation","id":str(item.npc_id),"label":str(item.name)})
			elif str(item.get("kind", "")) == "shop":
				street.hotspots.append({"x":center + 145.0, "kind":"shop", "id":str(item.get("shop_id", "")), "label":str(item.name)})
			else: street.hotspots.append({"x":center, "kind":"module", "id":str(item.module_id), "label":str(item.name) + " · " + GameplayModuleSystem.time_hint(str(item.module_id))})
	if GameState.current_location=="print_shop":
		if ChapterSystem.meeting_available(): street.hotspots.append({"x":_world_x(current_index,990),"kind":"meeting","label":"和赴约的人交谈"})
	var available := EventSystem.available_events()
	for index in available.size():
		street.hotspots.append({"x":center - 190.0 - index * 110.0, "kind":"event", "id":str(available[index].id), "label":str(available[index].get("choice_text", "交谈"))})
	street.queue_redraw()

func _interact() -> void:
	var item: Dictionary = street.nearest_interactable()
	if item.is_empty(): return
	# Talking has its own W binding; E is reserved for the physical world.
	if str(item.get("kind", "")) in ["person", "npc", "resident", "shopkeeper", "invitation"]: return
	if str(item.kind) in ["home", "door", "module"] and _guard_pocket_audio(): return
	_remember_position()
	SaveManager.save_or_report("地点互动前保存失败")
	match str(item.kind):
		"echo":
			_show_line("",str(item.get("text","")))
			MetaExperience.observe(GameState.current_location,str(item.get("text","")),{"kind":"place","event_id":"echo_"+GameState.current_location})
		"closed": _show_line("", "观景台将在晚上九点开放。")
		"home": _show_pocket_panel(preload("res://scripts/ui/components/household_panel.gd").new())
		"door":
			if not _guard_pocket_audio(): SceneRouter.enter_space(str(item.id))
		"shop": _open_shop(str(item.id))
		"counter": _open_grocery_counter()
		"transport":
			if not is_instance_valid(pocket_panel): _show_pocket_panel(preload("res://scripts/ui/transport_panel.gd").new())
		"fishing":
			if not is_instance_valid(pocket_panel): _show_pocket_panel(preload("res://scripts/ui/coastal_fishing_panel.gd").new())
		"meeting": _open_meeting()
		"module":
			if _guard_pocket_audio(): return
			SceneRouter.request_gameplay(str(item.id), "street:" + GameState.current_location)
		"event": _open_event(str(item.id))

func _talk_to_nearest() -> void:
	var item: Dictionary = street.nearest_of(["person", "npc", "resident", "shopkeeper", "invitation", "counter"])
	match str(item.get("kind", "")):
		"counter": _open_grocery_counter()
		"person", "npc", "resident": _talk_nearby(str(item.id))
		"shopkeeper": _talk_shopkeeper(str(item.id))
		"invitation": _talk_nearby(str(item.id), "minigame_hook")

func _talk_nearby(resident_id: String, topic := "greeting") -> void:
	if not ResidentProfileSystem.is_core(resident_id): return
	if not DialogueSystem.people_at(GameState.current_location, "").has(resident_id): return
	if is_instance_valid(conversation): return
	if not MetaExperience.pay_conversation(topic): return
	conversation = preload("res://scripts/ui/conversation_panel.gd").new()
	conversation.npc = resident_id
	conversation.starting_topic = topic
	if resident_id == "beetman" and GameState.current_location == "produce_stall":
		conversation.shop_id = "produce_stall"
		conversation.purchase_requested.connect(_open_shop.bind("produce_stall"))
	for item in street.hotspots:
		if str(item.get("id","")) == resident_id and absf(float(item.x)-street.player_x) > 1.0: street.facing = signf(float(item.x)-street.player_x)
	street.velocity = 0.0
	add_child(conversation)
	SaveManager.save_or_report("谈话计时后保存失败")

func _talk_shopkeeper(shop_id: String) -> void:
	_talk_nearby(shop_id)

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
	event_panel.clear_choices()
	event_overlay.visible = true

func _show_line(speaker: String, text: String) -> void:
	_clear_dialogue()
	event_panel.speaker_label.text=LocalizationSystem.text(speaker)
	var line: Label=event_panel.text_label
	line.text=LocalizationSystem.text(text)
	spoken_line = line
	line.visible_characters = -1 if SettingsSystem.reduced_motion() else 0
	if not SettingsSystem.reduced_motion():
		speech_tween = create_tween()
		speech_tween.tween_property(line, "visible_characters", line.text.length(), maxf(0.3, line.text.length() / 28.0))
	var box := VBoxContainer.new()
	var next := preload("res://scripts/ui/components/dialogue_choice.gd").new()
	next.text=LocalizationSystem.text("继续"); next.custom_minimum_size.y=46
	box.add_child(next)
	event_panel.hint_label.text=SettingsSystem.binding_text("dialogue_advance")+" "+LocalizationSystem.text("继续")+" · "+SettingsSystem.binding_text("ui_cancel")+" "+LocalizationSystem.text("离开")
	event_panel.attach_choices(box)
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
		event_panel.speaker_label.text=LocalizationSystem.text("你说")
		event_panel.text_label.text=""
		event_panel.hint_label.text=SettingsSystem.binding_text("ui_accept")+" "+LocalizationSystem.text("回应")+" · "+SettingsSystem.binding_text("ui_cancel")+" "+LocalizationSystem.text("离开")
		var box := VBoxContainer.new()
		for i in choices.size():
			var choice: Dictionary = choices[i]
			var button := preload("res://scripts/ui/components/dialogue_choice.gd").new()
			button.text=LocalizationSystem.text(str(choice.get("label","")))
			button.custom_minimum_size.y=46
			box.add_child(button)
			button.pressed.connect(_resolve_event.bind(staged_event_id, str(choice.id)))
			dialogue_choices.append(button)
		event_panel.attach_choices(box)
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
	if has_node("GameplayShell"): get_node("GameplayShell").open_paper("notebook")


func _open_shop(shop_id: String) -> void:
	if is_instance_valid(pocket_panel): return
	var panel = preload("res://scripts/ui/shop_panel.gd").new()
	panel.shop_id = shop_id
	if is_instance_valid(conversation) and conversation.has_method("resume_from_shop"):
		panel.tree_exited.connect(conversation.resume_from_shop)
	_show_pocket_panel(panel)

func _open_grocery_counter() -> void:
	if GameState.current_location != "cafe" or is_instance_valid(pocket_panel) or is_instance_valid(conversation): return
	var hours := WorldGraph.location_status("cafe")
	if not bool(hours.open): _show_line("杂货店", str(hours.reason)); return
	# The owner speaks from the existing storefront. No second interior or
	# additional roaming story resident is created for this service counter.
	_clear_dialogue()
	event_panel.speaker_label.text=LocalizationSystem.text("杂货店老板")
	event_panel.text_label.text=LocalizationSystem.text("想带点什么？挑好放一起，我给你结账。胶卷和冲洗也可以在这里办。")
	event_panel.text_label.visible_characters=-1
	event_panel.hint_label.text=SettingsSystem.binding_text("ui_cancel")+" · "+LocalizationSystem.text("离开")
	var choices := VBoxContainer.new()
	for action in ["shop","film","leave"]:
		var choice := preload("res://scripts/ui/components/dialogue_choice.gd").new()
		choice.name="Grocery_"+action
		choice.text=LocalizationSystem.text({"shop":"购买杂货","film":"摄影与冲洗","leave":"先走了"}[action])
		choice.pressed.connect(func():
			event_overlay.hide()
			if action=="shop": _open_shop("grocery")
			elif action=="film": FilmSystem.open_counter(self))
		choices.add_child(choice); dialogue_choices.append(choice)
	event_panel.attach_choices(choices)
	dialogue_choices[0].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().get_nodes_in_group("world_tool").is_empty(): return
	if is_instance_valid(conversation): return
	if not event.is_pressed() or event.is_echo(): return
	if SceneRouter.transitioning: return
	if _pocket_blocks_walking() or pocket_opening: return
	if event_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			if speech_tween: speech_tween.kill()
			event_overlay.hide()
		elif (event.is_action_pressed("dialogue_advance") or event.is_action_pressed("ui_accept")) and dialogue_choices.size() == 1:
			if is_instance_valid(spoken_line) and spoken_line.visible_characters >= 0 and spoken_line.visible_characters < spoken_line.text.length():
				if speech_tween: speech_tween.kill()
				spoken_line.visible_characters = -1
			else: dialogue_choices[0].pressed.emit()
		elif dialogue_choices.size() > 1 and (event.is_action_pressed("ui_up") or (event is InputEventKey and event.physical_keycode == KEY_W)):
			_focus_dialogue_choice(-1)
		elif dialogue_choices.size() > 1 and (event.is_action_pressed("ui_down") or (event is InputEventKey and event.physical_keycode == KEY_S)):
			_focus_dialogue_choice(1)
	elif event.is_action_pressed("open_camera"): _open_pocket_camera()
	elif event.is_action_pressed("open_recorder"): _open_pocket_recorder()
	elif event.is_action_pressed("open_album"): _open_pocket_album()
	elif event.is_action_pressed("talk"): _talk_to_nearest()
	elif event.is_action_pressed("ask_directly"):
		var target: Dictionary = street.nearest_of(["person", "resident", "npc", "shopkeeper"])
		if str(target.get("kind", "")) in ["person", "resident", "npc", "shopkeeper"]:
			var ask := preload("res://scripts/meta/ask_panel.gd").new()
			ask.npc = str(target.id)
			ask.chosen.connect(func(topic: String) -> void: _talk_nearby(str(target.id), topic))
			add_child(ask)
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
	if MetaExperience.modal_open(): return true
	if not is_instance_valid(pocket_panel): return false
	return not (pocket_panel.has_method("set_compact") and bool(pocket_panel.get("compact")))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(street):
		_remember_position()
		SaveManager.save_or_report("关闭窗口前保存失败")

func _open_map() -> void:
	if has_node("GameplayShell"):
		get_node("GameplayShell").open_paper("map")
		return
	if _guard_pocket_audio(): return
	_remember_position()
	if not SaveManager.save_or_report("打开地图前保存失败"):
		status_message = "存档写入失败，暂时无法离开当前画面。"
		_refresh()
		return
	SceneRouter.town_map()

func _open_meeting() -> void:
	if is_instance_valid(conversation) or not ChapterSystem.meeting_available(): return
	conversation=preload("res://scripts/ui/components/meeting_scene.gd").new()
	conversation.set_meta("street",street)
	conversation.tree_exited.connect(_refresh)
	add_child(conversation)
