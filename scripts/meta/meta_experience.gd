extends Node
## Optional narrative layer; persistent content remains in GameState.shared_state.
signal voice_spoken(text: String, faculty: String)
var catalog: Dictionary = {}
var memories: Array = []
var rng := RandomNumberGenerator.new()
var last_voice := -100000.0
var faculty_times: Dictionary = {}
var recent_voice_ids: Array[String] = []
var place_cooldowns: Dictionary = {}
var voice_layer: CanvasLayer
var voice_label: Label
var voice_tween: Tween
var voice_debug: Dictionary = {}
var marginalia_debug: Dictionary = {}
var conversation_counts: Dictionary = {}
var voice_context: Dictionary = {}
var debug_panel: Control
var deterministic_test_mode := false
var _active_voice_token := ""
var _voice_duration := 3.4
var _pending_clock := 0.0
var _serving_important := false

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/meta/catalog.json"))
	memories = JSON.parse_string(FileAccess.get_file_as_string("res://data/meta/memories.json")).get("rooms", [])
	rng.randomize()
	deterministic_test_mode = OS.is_debug_build() and OS.get_cmdline_user_args().has("--inner-voice-test")
	GameState.state_changed.connect(func() -> void: EchoSystem.update_presence())
	voice_layer = CanvasLayer.new()
	voice_layer.layer = 18
	add_child(voice_layer)
	voice_label = Label.new()
	voice_label.position = Vector2(190,545)
	voice_label.size = Vector2(900,60)
	voice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	voice_label.modulate.a = 0
	voice_label.add_theme_color_override("font_color",Color("eee2ce"))
	voice_label.add_theme_color_override("font_shadow_color",Color("182b33"))
	voice_label.add_theme_constant_override("shadow_offset_x",1)
	voice_label.add_theme_constant_override("shadow_offset_y",2)
	voice_layer.add_child(voice_label)
	voice_spoken.connect(_display_voice)
	DialogueSystem.dialogue_line_presented.connect(_on_dialogue_line)
	voice_label.position = Vector2(500,155)
	voice_label.size = Vector2(600,110)
	voice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	voice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var handwriting := SystemFont.new()
	handwriting.font_names = PackedStringArray(["KaiTi","Microsoft YaHei"])
	voice_label.add_theme_font_override("font",handwriting)

func _on_dialogue_line(context: Dictionary) -> void:
	var normalized := _normalize_voice_context(context)
	voice_context = normalized.duplicate(true)
	_debug_start(normalized)
	if str(normalized.get("speaker","")) != "npc" or bool(normalized.get("silent",false)):
		_block_voice("important_silence")
		return
	var conversation_id := str(normalized.get("conversation_id",0))
	if int(conversation_counts.get(conversation_id,0)) >= 2:
		_block_voice("conversation_limit")
		return
	if int(normalized.get("index",0)) % 3 != 0 and not _has_authored_trigger(normalized):
		_block_voice("natural_pause")
		return
	await get_tree().create_timer(.6).timeout
	var owner = normalized.get("owner")
	if not is_instance_valid(owner) or owner.is_queued_for_deletion():
		_block_voice("dialogue_ended")
		return
	if int(owner.index) != int(normalized.get("index",-1)):
		_block_voice("line_changed")
		return
	if not request_thought(normalized,deterministic_test_mode).is_empty():
		conversation_counts[conversation_id] = int(conversation_counts.get(conversation_id,0))+1
	if conversation_counts.size() > 80: conversation_counts.erase(conversation_counts.keys()[0])

func observe(location: String, detail := "", context: Dictionary = {}) -> String:
	var observation := context.duplicate()
	observation["location_id"] = location
	observation["location"] = location
	observation["text"] = detail
	observation["kind"] = "place"
	if not observation.has("event_id"): observation["event_id"] = "observe:"+location+":"+detail.sha256_text().left(12)
	if str(observation.event_id).begins_with("echo_"):
		observation["source_event_id"] = observation.event_id
		observation.event_id = "v3_environment_detail"
	if _is_important(observation):
		queue_important(str(observation.event_id),observation)
		return "queued"
	return request_thought(observation,deterministic_test_mode)

func _normalize_voice_context(context: Dictionary) -> Dictionary:
	var result := context.duplicate()
	result["kind"] = str(context.get("kind","dialogue"))
	result["npc_id"] = str(context.get("npc_id",context.get("npc","")))
	result["speaker_id"] = str(context.get("speaker_id",result.get("npc_id","")))
	result["location_id"] = str(context.get("location_id",context.get("location",GameState.current_location)))
	result["event_id"] = str(context.get("event_id",""))
	result["dialogue_id"] = str(context.get("dialogue_id",str(result.get("npc_id",""))+":"+str(context.get("topic","greeting"))))
	result["line_id"] = str(context.get("line_id",str(result.get("dialogue_id",""))+":"+str(context.get("index",0))))
	result["protagonist_id"] = str(context.get("protagonist_id",GameState.current_role))
	result["time_of_day"] = str(context.get("time_of_day","night" if GameState.current_minute >= 1140 else "dusk" if GameState.current_minute >= 1020 else "day"))
	result["flags"] = context.get("flags",{}).duplicate(true)
	result["world_state"] = context.get("world_state",{}).duplicate(true)
	return result

func _voice_state() -> Dictionary:
	var all_states: Dictionary = GameState.shared_state.get("inner_voice_state",{})
	var role := GameState.current_role
	if not all_states.has(role):
		all_states[role] = {"version":1,"token":str(Time.get_unix_time_from_system())+"_"+str(rng.randi()),"once":{},"last_epoch":-100000.0,"faculties":{},"recent":[],"history":{},"event_flags":{}}
		GameState.shared_state["inner_voice_state"] = all_states
	var state: Dictionary = all_states[role]
	if _active_voice_token != str(state.get("token","")):
		_active_voice_token = str(state.get("token",""))
		if voice_tween: voice_tween.kill()
		if is_instance_valid(voice_label): voice_label.modulate.a = 0
		voice_context.clear()
		last_voice = -100000.0
		faculty_times.clear()
		recent_voice_ids.assign(state.get("recent",[]))
		conversation_counts.clear()
	return state

func voice_cooldown_remaining() -> float:
	var state := _voice_state()
	return maxf(0,float(catalog.get("timing",{}).get("voice_global_seconds",24))-(Time.get_unix_time_from_system()-float(state.get("last_epoch",-100000.0))))

func _debug_start(context: Dictionary) -> void:
	voice_debug = {"context":str(context.get("text","")),"trigger":str(context.get("line_id","")) if str(context.get("kind","")) == "dialogue" else str(context.get("event_id","")),"protagonist":str(context.get("protagonist_id","")),"npc":str(context.get("npc_id","")),"location":str(context.get("location_id","")),"candidates":[],"selected":[],"selected_ids":[],"reason":"等待自然停顿","blocking_reason":"","state":"READY","last_trigger":str(context.get("event_id",context.get("line_id",""))),"candidate_count":0,"selected_id":"","render_success":false}

func _block_voice(reason: String) -> String:
	voice_debug["blocking_reason"] = reason
	voice_debug["reason"] = reason
	voice_debug["state"] = "BLOCKED"
	_log_voice()
	return ""

func _log_voice() -> void:
	if OS.is_debug_build() and (OS.get_cmdline_user_args().has("--inner-voice-test") or OS.get_cmdline_user_args().has("--meta-preview")):
		print("[InnerVoice] trigger=",voice_debug.get("trigger","")," protagonist=",voice_debug.get("protagonist","")," candidates=",voice_debug.get("candidates",[]).size()," selected=",voice_debug.get("selected_ids",[])," blocking=",voice_debug.get("blocking_reason",""))

func _matches_trigger(entry: Dictionary, context: Dictionary) -> bool:
	var trigger: Dictionary = entry.get("trigger",{})
	if trigger.is_empty(): return false
	for key in trigger:
		if str(context.get(key,"")) != str(trigger[key]): return false
	return true

func _has_authored_trigger(context: Dictionary) -> bool:
	for entry in catalog.voices:
		if _matches_trigger(entry,context): return true
	return false

func enabled(key: String) -> bool:
	return bool(catalog.get("toggles",{}).get(key,false))

func _process(_delta: float) -> void:
	_pending_clock += _delta
	if _pending_clock >= .2 and not GameState.role_states.is_empty():
		_pending_clock = 0
		_drain_important()
	if not is_instance_valid(voice_layer): return
	var clear := not modal_open() and not SceneRouter.transitioning and get_tree().get_nodes_in_group("world_tool").is_empty()
	voice_layer.visible = clear
	if not clear and voice_label.modulate.a > 0:
		if voice_tween: voice_tween.kill()
		voice_label.modulate.a = 0
	elif clear and voice_label.modulate.a > 0:
		var zone := _voice_safe_zone()
		if zone.has_area(): voice_label.position = zone.position
		else:
			if voice_tween: voice_tween.kill()
			voice_label.modulate.a = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not GameState.role_states.is_empty():
		SaveManager.save_or_report("退出时保存失败")

func modal_open() -> bool:
	return _has_visible_group("meta_modal")

func _has_visible_group(group_name: String) -> bool:
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.is_visible_in_tree():
			return true
	return false

func pay_conversation(topic: String) -> bool:
	if topic == "minigame_hook": return true
	var key := "chat_minutes" if topic == "greeting" else "ask_minutes"
	var minutes := int(catalog.timing[key])
	if not GameState.use_free_time(minutes):
		GameState.message_posted.emit("现在只剩一点空闲时间，待会儿再聊。")
		return false
	return true

func trigger_voice(context: String, now: float = -1.0) -> String:
	var request := voice_context.duplicate()
	request["kind"] = context
	return request_thought(request,deterministic_test_mode,now)

func request_thought(context: Dictionary, deterministic := false, now: float = -1.0) -> String:
	var normalized := _normalize_voice_context(context)
	voice_context = normalized.duplicate(true)
	_debug_start(normalized)
	var state := _voice_state()
	if not enabled("voices"): return _block_voice("disabled")
	if str(normalized.get("protagonist_id",GameState.current_role)) != GameState.current_role: return _block_voice("wrong_protagonist")
	if bool(normalized.get("silent",false)) or bool(normalized.get("important_silence",false)): return _block_voice("important_silence")
	if modal_open() or SceneRouter.transitioning or not get_tree().get_nodes_in_group("world_tool").is_empty(): return _block_voice("ui_blocked")
	if str(normalized.get("kind","")) == "place" and _has_visible_group("meta_dialogue"): return _block_voice("ui_blocked")
	if now < 0: now = Time.get_ticks_msec()/1000.0
	var cooldown := maxf(voice_cooldown_remaining(),float(catalog.timing.voice_global_seconds)-(now-last_voice))
	voice_debug["cooldown"] = maxf(0,cooldown)
	if cooldown > 0: return _block_voice("cooldown")
	var role := GameState.current_role
	var epoch := Time.get_unix_time_from_system()
	var words := str(normalized.get("text",""))
	var possible: Array = []
	var authored: Array = []
	var rejected_once := false
	for entry in catalog.voices:
		if str(entry.get("context","")) != str(normalized.get("kind","")): continue
		if not entry.get("roles",["A","B"]).has(role): continue
		if not entry.get("trigger",{}).is_empty() and not _matches_trigger(entry,normalized): continue
		var thought_id := str(entry.get("id",""))
		if bool(entry.get("once",false)) and state.get("once",{}).has(thought_id):
			if _matches_trigger(entry,normalized): rejected_once = true
			continue
		if state.get("recent",[]).has(thought_id): continue
		var faculty := str(entry.get("faculty","daily"))
		if epoch-float(state.get("faculties",{}).get(faculty,-100000.0)) < float(catalog.get("timing",{}).get("voice_faculty_seconds",38)): continue
		if now-float(faculty_times.get(faculty,-100000.0)) < float(catalog.get("timing",{}).get("voice_faculty_seconds",38)): continue
		var allowed := true
		for flag in entry.get("requires_flags",[]):
			if not bool(normalized.get("flags",{}).get(flag,normalized.get("world_state",{}).get(flag,GameState.shared_state.get(flag,false)))): allowed = false
		if not allowed: continue
		possible.append(entry)
		if _matches_trigger(entry,normalized): authored.append(entry)
	voice_debug["candidates"] = possible.map(func(row: Dictionary) -> String: return str(row.id))
	voice_debug["candidate_count"] = possible.size()
	if _has_authored_trigger(normalized) and authored.is_empty():
		return _block_voice("once_already_seen" if rejected_once else "cooldown")
	if possible.is_empty(): return _block_voice("once_already_seen" if rejected_once else "no_candidate")
	# A fixed candidate only affects selection. Every eligibility and UI blocker above still applies.
	if deterministic and OS.is_debug_build() and not authored.is_empty(): possible = [authored[0]]
	elif not authored.is_empty(): possible = authored
	elif rng.randf() > float(catalog.get("voice_rules",{}).get("dialogue_chance" if str(normalized.get("kind",""))=="dialogue" else "observation_chance",.75)):
		return _block_voice("natural_silence")
	var tone_counts: Dictionary = {}
	for entry in possible:
		var tone := str(entry.get("tone","daily"))
		tone_counts[tone] = int(tone_counts.get(tone,0))+1
	var total := 0.0
	var options: Array = []
	for entry in possible:
		var tone := str(entry.get("tone","daily"))
		var weight := float(entry.get("weight",1.0))*float(catalog.get("voice_rules",{}).get("tone_weights",{}).get(tone,.6))/float(tone_counts[tone])
		weight *= float(catalog.get("role_bias",{}).get(role,{}).get(str(entry.get("faculty","daily")),1.0))
		var relevant := 1.0
		for word in entry.get("keywords",[]):
			if words.contains(str(word)): relevant += 1.5
		weight *= relevant/(1.0+.08*float(state.history.get(entry.faculty,0)))
		total += weight
		options.append({"entry":entry,"ceiling":total})
	var roll := rng.randf()*total
	for option in options:
		if roll > float(option.ceiling): continue
		var entry: Dictionary = option.get("entry",{})
		var zone := _voice_safe_zone()
		if not zone.has_area(): return _block_voice("ui_blocked")
		voice_label.position = zone.position
		voice_label.size = zone.size
		var thought_id := str(entry.get("id",""))
		last_voice = now
		var selected_faculty := str(entry.get("faculty","daily"))
		faculty_times[selected_faculty] = now
		state["last_epoch"] = epoch
		state["faculties"][selected_faculty] = epoch
		state["recent"].append(thought_id)
		if state["recent"].size() > 5: state["recent"].pop_front()
		recent_voice_ids.assign(state.get("recent",[]))
		state["history"][selected_faculty] = int(state.get("history",{}).get(selected_faculty,0))+1
		if bool(entry.get("once",false)): state["once"][thought_id] = {"day":GameState.current_day,"minute":GameState.current_minute,"trigger":str(voice_debug.get("trigger",""))}
		if not str(normalized.get("event_id","")).is_empty(): state["event_flags"][str(normalized.get("event_id",""))] = true
		_voice_duration = clampf(float(entry.get("duration",3.4)),1.8,4.0)
		voice_debug["selected"] = [selected_faculty]
		voice_debug["selected_ids"] = [thought_id]
		voice_debug["selected_id"] = thought_id
		voice_debug["state"] = "READY"
		voice_debug["render_success"] = true
		voice_debug["reason"] = "已显示"
		voice_debug["blocking_reason"] = ""
		voice_debug["safe_zone"] = [zone.position.x,zone.position.y,zone.size.x,zone.size.y]
		SaveManager.save_or_report("保存心声记录失败")
		voice_spoken.emit(str(entry.get("text","")),selected_faculty)
		_log_voice()
		return thought_id
	return _block_voice("no_candidate")

func _voice_safe_zone() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var blocked: Array[Rect2] = [Rect2(viewport_size.x-460,0,460,270),Rect2(0,0,170,100)]
	for dialogue in get_tree().get_nodes_in_group("meta_dialogue"):
		var card = dialogue.get("speech_card")
		if card is Control: blocked.append(card.get_global_rect().grow(22))
	var scene := get_tree().current_scene
	if scene != null:
		var stage = scene.get("street") if scene.get("street") != null else scene.get("stage")
		if stage is Control and stage.has_method("_ground_at"):
			var actors: Array = [{"x":stage.player_x}]
			for point in stage.hotspots:
				if str(point.get("kind","")) in ["person","npc","resident","shopkeeper"]: actors.append(point)
			for actor in actors:
				var head_y := float(stage.call("_ground_at",float(actor.x)))-float(stage.call("_actor_height"))
				blocked.append(Rect2(float(actor.x)-float(stage.camera_x)-65,head_y-20,130,145))
		for layer in get_tree().get_nodes_in_group("marginalia_layers"):
			for label in layer.labels:
				if is_instance_valid(label): blocked.append(label.get_global_rect().grow(15))
	for fraction in [Vector2(.36,.16),Vector2(.07,.19),Vector2(.65,.27),Vector2(.34,.34),Vector2(.07,.34)]:
		var zone := Rect2(viewport_size*fraction,Vector2(minf(430,viewport_size.x*.28),88))
		if zone.end.x > viewport_size.x-24 or zone.end.y > viewport_size.y-90: continue
		var clear := true
		for area in blocked:
			if area.intersects(zone): clear = false; break
		if clear: return zone
	return Rect2()

func _display_voice(text: String, _faculty: String) -> void:
	if voice_tween: voice_tween.kill()
	voice_label.text = LocalizationSystem.text(text)
	voice_label.modulate.a = 0
	voice_label.add_theme_font_size_override("font_size",clampi(int(SettingsSystem.values.get("voice_size",21)),17,24))
	voice_tween = create_tween()
	voice_label.rotation = 0 if SettingsSystem.reduced_motion() else -.006
	voice_tween.tween_property(voice_label,"modulate:a",float(SettingsSystem.values.get("voice_opacity",0.86)),.3)
	voice_tween.tween_interval(_voice_duration-.75)
	voice_tween.tween_property(voice_label,"modulate:a",0.0,.45)

func notes_page(page: int) -> Array:
	var notes: Array = catalog.notes.duplicate(true)
	for row in GameState.shared_state.get("bookstore_notes",[]):
		notes.append(row if row is Dictionary else {"text":str(row),"byline":"旅人","date":"","kind":"留言"})
	var count := maxi(1,ceili(notes.size()/9.0))
	var start := posmod(page,count)*9
	return notes.slice(start,mini(start+9,notes.size()))

func coverage_report() -> Dictionary:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/meta/participant_index.json"))
	return {"protagonists":index.protagonists.size(),"existing_npcs":index.existing_npc_ids.size(),"verified_contributors":index.verified_real_contributors.size(),"unassigned":index.unassigned_real_trace_slots}

func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F8:
		if is_instance_valid(debug_panel): debug_panel.queue_free()
		else:
			debug_panel=load("res://scripts/meta/runtime_debug.gd").new()
			voice_layer.add_child(debug_panel)
		get_viewport().set_input_as_handled()
		return
	if not OS.get_cmdline_user_args().has("--meta-preview"): return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9:
		if modal_open(): return
		var report: Control = load("res://scripts/meta/trace_panel.gd").new()
		report.mode = "coverage"
		get_tree().current_scene.add_child(report)
		get_viewport().set_input_as_handled()


func _is_important(context: Dictionary) -> bool:
	for entry in catalog.voices:
		if bool(entry.get("important",false)) and _matches_trigger(entry,context) and entry.get("roles",["A","B"]).has(GameState.current_role): return true
	return false

func queue_important(event_id: String, context: Dictionary = {}) -> void:
	var request: Dictionary={"kind":"place","event_id":event_id,"location_id":GameState.current_location,"protagonist_id":GameState.current_role,"flags":{},"text":""}
	# Save only data. A dialogue owner Node may disappear before the paper overlay closes.
	for key in context:
		if typeof(context[key]) in [TYPE_STRING,TYPE_INT,TYPE_FLOAT,TYPE_BOOL,TYPE_DICTIONARY,TYPE_ARRAY]: request[key]=context[key]
	request.event_id=event_id
	request.kind="place"
	if not _is_important(request): return
	var state:=_voice_state()
	for entry in catalog.voices:
		if _matches_trigger(entry,request) and entry.get("roles",["A","B"]).has(GameState.current_role) and state.once.has(str(entry.id)): return
	if not state.has("important_pending"): state.important_pending=[]
	if state.important_pending.any(func(item: Dictionary)->bool:return str(item.event_id)==event_id): return
	state.important_pending.append(request)
	if state.important_pending.size()>8: state.important_pending.pop_front()
	SaveManager.save_or_report("保存待留意的心声失败")
	_drain_important()

func _drain_important() -> void:
	if _serving_important: return
	var state:=_voice_state()
	if state.get("important_pending",[]).is_empty(): return
	if modal_open() or SceneRouter.transitioning or not get_tree().get_nodes_in_group("world_tool").is_empty() or not get_tree().get_nodes_in_group("meta_dialogue").is_empty(): return
	if voice_cooldown_remaining()>0: return
	_serving_important=true
	var context: Dictionary=state.important_pending[0]
	var selected:=request_thought(context,true)
	if not selected.is_empty() or str(voice_debug.get("blocking_reason","")) in ["once_already_seen","wrong_protagonist","no_candidate"]:
		state.important_pending.pop_front()
		SaveManager.save_or_report("保存心声播放状态失败")
	_serving_important=false
