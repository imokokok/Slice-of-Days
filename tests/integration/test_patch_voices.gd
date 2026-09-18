extends SceneTree
## Uses the existing TownDay conversation/observation entry points and real rendered label.
var failures := 0
var checks := 0
var state: Node
var meta: Node
var router: Node
var dialogue: Node
var save: Node
var observed_contexts: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
	else: print("PASS ",label)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	root.gui_disable_input = true
	state = root.get_node("GameState")
	meta = root.get_node("MetaExperience")
	router = root.get_node("SceneRouter")
	dialogue = root.get_node("DialogueSystem")
	save = root.get_node("SaveManager")
	state.begin_new_game("A")
	meta.deterministic_test_mode = true
	meta.catalog.toggles.marginalia = false
	root.get_node("SettingsSystem").values.reduced_motion = true
	dialogue.dialogue_line_presented.connect(func(context: Dictionary) -> void: observed_contexts.append(context))
	await open_town("produce_stall",660)
	var target := {"kind":"dialogue","speaker":"npc","npc_id":"beetman","line_id":"beetman.greeting.0.0","protagonist_id":"B"}
	check(meta.request_thought(target,true).is_empty() and meta.voice_debug.blocking_reason=="wrong_protagonist","Fixed candidate respects protagonist blocker")
	target.protagonist_id = "A"
	target.important_silence = true
	check(meta.request_thought(target,true).is_empty() and meta.voice_debug.blocking_reason=="important_silence","Fixed candidate preserves important silence")
	target.erase("important_silence")
	var paper := Control.new()
	current_scene.add_child(paper)
	paper.add_to_group("meta_modal")
	check(meta.request_thought(target,true).is_empty() and meta.voice_debug.blocking_reason=="ui_blocked","Paper UI blocks a fixed candidate")
	paper.queue_free()
	await process_frame
	current_scene._talk_nearby("beetman")
	await create_timer(1.15).timeout
	check_voice("patch_beetman_tin_labels","A: real vendor full-chat line")
	check(not observed_contexts.is_empty(),"Real DialogueSystem emitted its presented-line signal")
	var context: Dictionary = observed_contexts.back()
	for key in ["speaker_id","npc_id","location_id","event_id","dialogue_id","line_id","protagonist_id","time_of_day","flags","world_state"]:
		check(context.has(key),"Dialogue context includes "+key)
	check(str(context.line_id)=="beetman.greeting.0.0","Vendor target has stable first-chat line ID")
	check(meta._voice_state().once.has("patch_beetman_tin_labels"),"Authored thought stored once for A")
	check(save.save_game(),"Inner voice state saved through normal SaveManager")
	check(save.load_game(),"Inner voice state loaded through normal SaveManager")
	check(meta._voice_state().once.has("patch_beetman_tin_labels"),"Once-only thought survives load")
	meta.last_voice = -100000
	meta.faculty_times.clear()
	check(meta.request_thought(target,true).is_empty() and meta.voice_debug.blocking_reason=="cooldown","Persisted cooldown survives load and runtime-field reset")
	check(meta.voice_cooldown_remaining()>0,"Saved cooldown has real remaining duration")
	await capture("patch_voice_vendor")
	current_scene.conversation._close()
	await process_frame
	await create_timer(meta.voice_cooldown_remaining()+.15).timeout
	check(meta.request_thought(target,true).is_empty() and meta.voice_debug.blocking_reason=="once_already_seen","Same authored trigger stays silent after cooldown")
	dialogue.mark_argument(true)
	current_scene._observe_market_afterward()
	await create_timer(.5).timeout
	check_voice("patch_argument_afterwind","B: actual post-argument observation")
	check(meta._voice_state().event_flags.get("market_argument_finished",false),"Observation event flag persists in voice state")
	await capture("patch_voice_argument")
	await create_timer(meta.voice_cooldown_remaining()+.15).timeout
	await open_town("bookstore",780)
	current_scene._talk_nearby("maya")
	await create_timer(1.15).timeout
	check_voice("patch_maya_window","C: existing Maya ordinary chat")
	check(str(observed_contexts.back().line_id)=="maya.greeting.0.0","Ordinary NPC target uses stable DialogueSystem ID")
	await capture("patch_voice_maya")
	await create_timer(4.0).timeout
	check(meta.voice_label.modulate.a<.01,"Thought fades out within four seconds")
	current_scene.conversation._close()
	await process_frame
	state.switch_to_role("B")
	check(not meta._voice_state().once.has("patch_beetman_tin_labels"),"B has independent once-only state")
	state.switch_to_role("A")
	check(meta._voice_state().once.has("patch_beetman_tin_labels"),"Switching back keeps A thought history")
	check(save.save_game() and save.load_game(),"Both protagonists' voice states round-trip")
	check(state.shared_state.inner_voice_state.has("A") and state.shared_state.inner_voice_state.has("B"),"Save contains separate A/B voice records")
	print("PATCH_VOICES ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(failures)

func open_town(location: String, minute: int) -> void:
	if is_instance_valid(current_scene) and current_scene.get("street") != null:
		current_scene.street.velocity = 0
		current_scene.street.enabled = false
	state.current_location = location
	state.current_minute = minute
	router.active_space_id = ""
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(.5).timeout
	current_scene.street.velocity = 0
	current_scene.street.set_process(false)

func check_voice(thought_id: String, label: String) -> void:
	check(meta.voice_debug.get("selected_ids",[]).has(thought_id),label+" reaches authored candidate")
	check(meta.voice_label.visible and meta.voice_layer.visible and meta.voice_label.modulate.a>0.1,label+" visibly reaches Inner Voice UI")
	check(not meta.voice_label.text.is_empty() and not meta.voice_label.text.contains("empathy"),label+" shows prose without faculty names")
	var voice_rect: Rect2 = meta.voice_label.get_global_rect()
	for panel in get_nodes_in_group("meta_dialogue"):
		check(not voice_rect.intersects(panel.speech_card.get_global_rect()),label+" avoids speech card")

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/meta/"+label+".png")
