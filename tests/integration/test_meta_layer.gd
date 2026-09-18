extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	var meta = root.get_node("MetaExperience")
	var echo = root.get_node("EchoSystem")
	var knowledge = root.get_node("KnowledgeSystem")
	var router = root.get_node("SceneRouter")
	var settings = root.get_node("SettingsSystem")
	state.begin_new_game("A")
	settings.values.reduced_motion = true
	check(meta.memories.size() == 14,"All 14 memory definitions available")
	var first: Array = meta.notes_page(0)
	var second: Array = meta.notes_page(1)
	check(first.size() == 9 and second.size() == 9,"Nine notes per batch")
	for row in first: check(not second.any(func(other: Dictionary) -> bool: return other.id == row.id),"No repeats across first two note batches")
	var minute: int = state.current_minute
	check(meta.pay_conversation("greeting"),"Casual chat fits free time")
	check(state.current_minute == minute+15,"Chat charges configured 15 minutes")
	check(meta.pay_conversation("schedule_info"),"Direct question fits free time")
	check(state.current_minute == minute+20,"Question charges configured five minutes")
	state.current_minute = 1139
	check(not meta.pay_conversation("greeting"),"Chat blocked at schedule boundary")
	check(state.current_minute == 1139,"Failed chat leaves time unchanged")
	state.current_minute = 600
	knowledge.learn({"id":"test_revision","text":"九点开门","confidence":0.5})
	knowledge.learn({"id":"test_revision","text":"十点开门","confidence":1})
	var fact: Dictionary = knowledge.facts().back()
	check(fact.revisions.size()==1 and fact.revisions[0].text=="九点开门","Previous wording remains in notebook")
	var save: Dictionary = state.to_save_data().duplicate(true)
	state.begin_new_game("B")
	state.load_save_data(save)
	check(knowledge.facts().back().revisions.size()==1,"Notebook revision round trips in existing save")
	minute = state.current_minute
	var day: int = state.current_day
	state.shared_state.meta_checkpoint={"version":1,"timestamp":1000}
	state.shared_state.erase("ambient_applied_at")
	check(echo.resume_ambient(100000),"Offline ambient changes applied")
	check(state.current_minute==minute and state.current_day==day,"Offline ambient does not advance seven-day calendar")
	var trace_count: int = state.shared_state.get("ambient_traces",[]).size()
	echo.resume_ambient(100000)
	check(state.shared_state.ambient_traces.size()==trace_count,"Repeated load cannot duplicate ambient traces")
	state.current_minute = 800
	echo.update_presence()
	check(state.shared_state.ambient_traces.any(func(row: Dictionary) -> bool: return row.get("id","")=="presence_repair"),"Offscreen event leaves later trace")
	var voice_context := {"kind":"dialogue","speaker":"npc","npc_id":"beetman","line_id":"beetman.greeting.0.0"}
	var test_voice: String = meta.request_thought(voice_context,true,1000)
	check(not test_voice.is_empty(),"Authored voice is eligible during dialogue")
	check(meta.request_thought(voice_context,true,1001).is_empty(),"Global voice cooldown enforced")
	for role in ["A","B"]:
		state.begin_new_game(role)
		router.active_space_id="home_a" if role=="A" else "home_b"
		change_scene_to_file("res://scenes/interactive_space.tscn")
		await create_timer(.2).timeout
		check(current_scene.objects[0].kind=="memory","Room memory entry exists for "+role)
		var entry = load("res://scripts/meta/memory_entry.gd").new()
		current_scene.add_child(entry)
		await process_frame
		check(entry.papers.size()==7,"Seven layers on each desk")
		await screenshot("desk_"+role)
		entry.queue_free()
		await process_frame
	for row in meta.memories:
		check(ResourceLoader.exists(str(row.model)),"Blender GLB exists: "+str(row.id))
		var view = load("res://scripts/meta/memory_view.gd").new()
		view.definition=row
		current_scene.add_child(view)
		await create_timer(1.3).timeout
		check(view.ready_to_walk,"First person handoff: "+str(row.id))
		check(view.body is CharacterBody3D,"Collision controller: "+str(row.id))
		var start_y: float=view.body.position.y
		view.body.velocity=Vector3(0,-2,0)
		await create_timer(.2).timeout
		check(view.body.position.y > -.1,"Floor collision: "+str(row.id))
		if row.id in ["A6","B3"]: await screenshot(str(row.id))
		view._leave()
		await process_frame
		check(not is_instance_valid(view),"Free early exit: "+str(row.id))
	var notes=load("res://scripts/meta/trace_panel.gd").new()
	current_scene.add_child(notes)
	await process_frame
	check(meta.modal_open(),"Modal text suppresses ambient layer")
	await screenshot("notes")
	notes.queue_free()
	await process_frame
	print("META_LAYER "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
	quit(failures)

func screenshot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/meta/qa_"+label+".png")
