extends SceneTree
## Walks the production state/scene path; never seeds chapter completion flags.
var checks := 0
var failures := 0
var gs
var chapter
var modules
var router
var save
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message); quit(1)
	else: print("PASS ",message)
func settle() -> void:
	await process_frame
	var frames := 0
	while router.transitioning and frames<1200:
		await process_frame
		frames+=1
	await create_timer(.2).timeout
func capture(name: String) -> void:
	var folder := OS.get_environment("FIVE_DAY_CAPTURE_DIR")
	if folder.is_empty(): return
	DirAccess.make_dir_recursive_absolute(folder)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func travel(location: String) -> void:
	# Exercise the existing travel service. Omit only the transit-card animation.
	if gs.current_location!=location:
		var result: Dictionary=root.get_node("TravelSystem").travel(location,"walk")
		check(bool(result.get("ok",false)),"travel to "+location)
	router.active_space_id=""
	gs.shared_state["map_arrival"]=location
	router.town_day()
	await settle()
func talk(npc: String) -> void:
	current_scene._talk_nearby(npc)
	await process_frame
	var panel=current_scene.conversation
	check(is_instance_valid(panel),"real conversation opens for "+npc)
	if not is_instance_valid(panel): return
	panel.typewriter=false
	var limit := 0
	while is_instance_valid(panel) and not panel.closing and limit<100:
		if is_instance_valid(panel.vendor_choices):
			panel.vendor_choices.get_child(0).pressed.emit()
		else: panel._advance()
		await process_frame
		limit+=1
	check(limit<100,"conversation completes without debug flags")
func inspect_other() -> void:
	await travel(root.get_node("CoreLoopSystem").home())
	router.enter_space("home_a" if gs.current_role=="A" else "home_b")
	await settle()
	for index in current_scene.objects.size():
		if str(current_scene.objects[index].get("kind",""))=="everyday":
			current_scene.selected_index=index
			current_scene.stage.player_x=current_scene._hotspot_x(index)
	current_scene.get_node("GameplayShell").hints.pressed.emit()
	await process_frame
	var panel=current_scene.pocket_panel
	check(is_instance_valid(panel),"ordinary home shelf opens through the actual room object")
	var id := ""
	var guidance_before: String=root.get_node("GuidanceSystem").next_step().text
	var count := 0
	for trace in chapter.everyday_at(gs.current_location):
		if str(trace.owner)==gs.current_role: continue
		id=str(trace.id)
		panel.actions.get_node("Trace_"+id).pressed.emit()
		count+=1
		if count==1 and gs.current_day in [3,4]:
			check(not bool(chapter.story().get(gs.current_role+"_noticing",false)),"one ordinary object cannot confirm another person")
			panel.actions.get_node("Trace_"+id).pressed.emit()
			check(not bool(chapter.story().get(gs.current_role+"_noticing",false)),"repeated clicks cannot count as two independent observations")
	check(not id.is_empty(),"other role's real record is present in shared world")
	check(bool(chapter.story().get(gs.current_role+"_noticing",false)) or gs.current_day<3,"clicking actual trace records discovery")
	if gs.current_day in [3,4]:
		check(count>=2 and bool(chapter.story().get("day%d_%s_confirmed_other_person"%[gs.current_day,gs.current_role.to_lower()],false)),"two sourced ordinary objects set the day-specific narrative flag")
		check(root.get_node("GuidanceSystem").next_step().text!=guidance_before,"actual observations change possibility guidance")
	if gs.current_day==2:
		check(panel.audio.stream!=null,"shared cabinet loads actual Day 1 record audio")
		panel.media.get_child(0).pressed.emit()
		check(panel.audio.playing,"B can listen to A's public recording")
	await capture("public-cabinet-day-"+str(gs.current_day))
	panel.queue_free(); await process_frame

func switch_at_planner() -> void:
	var characters=root.get_node("CharacterSystem")
	check(not characters.can_switch(),"no instant character switch while simply walking")
	var shell=current_scene.get_node("GameplayShell")
	shell.open_paper("day_schedule"); await process_frame
	var target := "B" if gs.current_role=="A" else "A"
	var button=shell.overlay.find_child("Choose_"+target,true,false)
	check(button!=null and not button.disabled,"explicit safe planner exposes real other-role button")
	button.pressed.emit()
	check(gs.current_role==target,"planner button switches the actual role")
	shell.overlay.close(); await process_frame

func ensure_time(minutes: int) -> void:
	while not gs.can_fit_now(minutes):
		var shell=current_scene.get_node("GameplayShell")
		shell.open_paper("day_schedule"); await process_frame
		var button=shell.overlay.find_child("WaitForWindow",true,false)
		check(button!=null and not button.disabled,"next real time block remains available")
		button.pressed.emit(); await process_frame
		var before: int=gs.current_minute
		get_nodes_in_group("native_confirmation")[0].accepted.emit()
		await process_frame
		check(gs.current_minute>before,"confirmed wait consumes shared world time")
		shell.overlay.close(); await process_frame
func native(module: String, tokens: Array, choice: String) -> void:
	check(router.gameplay_module(module,"street:"+gs.current_location),"start production module "+module)
	await settle()
	var scene=current_scene
	check(scene.module_id==module,"production scene resolves active context")
	for token in tokens: scene._toggle_token(str(token))
	if module=="cooking": scene.value_slider.value=.58
	scene._perform_primary_action()
	if module=="sound_sampling": await create_timer(2.7).timeout
	check(scene.stage_ready,"actual mechanic ready "+module)
	scene._complete_choice(choice)
	check(scene.completed,"real result saved "+module)
	scene.return_button.pressed.emit()
	await settle()
func end_day() -> void:
	var before: int=gs.current_day
	var home: String="residence" if gs.current_role=="A" else "dorm"
	await travel(home)
	router.enter_space("home_a" if gs.current_role=="A" else "home_b")
	await settle()
	check(chapter.sleep_at_home(),"EndDay accepts actual completed activity and narrative")
	await create_timer(3.7).timeout
	check(gs.current_day==mini(5,before+1),"one overnight advances exactly one day")
	check(save.save_game() and save.load_game(),"overnight save and reload preserves day and role")
func studio() -> void:
	var hours: Dictionary=root.get_node("WorldGraph").location_status("record_store")
	if gs.current_minute<int(hours.opens): check(gs.use_free_time(int(hours.opens)-gs.current_minute),"wait for record shop opening consumes actual free time")
	check(modules.entry_check("sound_sampling",60).ok,"music fits the actual shop hours and character schedule")
	var recorder=load("res://scripts/town_sound/RecorderScreen.gd").new()
	recorder.shop_mode=true; current_scene.add_child(recorder)
	await process_frame
	for index in 2:
		recorder.source_picker.select(0); recorder._start_recording()
		check(recorder.recorder.capturing,"capture actual game audio, no microphone")
		await create_timer(4.5).timeout
		recorder._stop()
		check(recorder.draft!=null and recorder.draft.get_length()>=4,"game recording has real audio duration")
		recorder.name_input.text="街边的声音 "+str(index+1); recorder._save_draft()
	var samples: Array=recorder.store.list_samples()
	check(samples.size()==2,"only this character's recordings appear")
	var work=load("res://scripts/town_sound/studio/StudioScreen.gd").new()
	recorder.add_child(work); await process_frame
	check(work.model.hosted_role==gs.current_role,"production Studio reads current character")
	work.model.add_sample(samples[0],0,0); work.model.add_sample(samples[1],1,4.5); work.changed()
	await work.open_visual(); await process_frame
	var room=recorder.get_child(recorder.get_child_count()-1)
	check(room.has_method("submit"),"actual visual sound room opened")
	if not room.has_method("submit"): return
	await room.submit()
	check(is_instance_valid(room.pressing),"boss listens to actual mixed recording")
	var press=room.pressing
	for step_index in 11: await press.advance()
	check(press.step==11 and not press.saved_record.is_empty(),"eleven production pressing steps deliver real WAV and cover")
	var balance: int=gs.money
	check(modules.record_studio_delivery(press.saved_record) and gs.money==balance,"retrying delivery cannot duplicate rewards")
	recorder.queue_free(); await process_frame
func letter() -> void:
	await wait_for_opening("handcraft_shop")
	check(router.gameplay_module("ghostwriting","street:handcraft_shop"),"real letter host starts")
	await settle()
	var host=current_scene
	var game=host.experience
	check(str(game.get_meta("solmere_context").current_character)==gs.current_role,"letter receives current character")
	while not game.ready_done: await process_frame
	game.open_browser(); game.take_material()
	game.pointer=game.active.position; game._press()
	motion(game,game.main_paper.position); game._release()
	game.save_game()
	check(gs.artifacts.minigame_drafts.ghostwriting.papers.size()==2,"letter draft belongs to current role")
	await game.begin_folding()
	check(game.stage=="FOLDING","actual placed paper allows folding")
	game.pointer=Vector2(700,600); game._press(); motion(game,Vector2(700,400)); game._release()
	game.pointer=Vector2(700,300); game._press(); motion(game,Vector2(700,510)); game._release()
	check(game.stage=="ENVELOPE","two real fold gestures form letter")
	game.pointer=game.packed_letter_at; game._press(); motion(game,Vector2(1000,450)); game._release()
	await create_timer(.65).timeout
	game.pointer=Vector2(1000,280); game._press(); motion(game,Vector2(1000,560)); game._release()
	check(game.stage=="WAX_SEAL","insert and close envelope")
	game.pointer=Vector2(350,620); game._press()
	motion(game,Vector2(480,620)); motion(game,Vector2(335,620)); motion(game,Vector2(509,382))
	game._process_wax(.6); game._release()
	check(game.candle_lit,"struck match lights actual candle")
	game.pointer=Vector2(600,322); game._press(); motion(game,Vector2(390,330)); game._release()
	game.pointer=Vector2(600,322); game._press(); motion(game,Vector2(509,350)); game._release()
	game._process_wax(6.1)
	game.pointer=Vector2(509,350); game._press(); motion(game,Vector2(1000,455)); game._process_wax(1.9); game._release()
	game.pointer=Vector2(1360,455); game._press(); motion(game,Vector2(1000,477)); game._process_wax(1.1); game._release()
	game._process_wax(2.6)
	check(game.wax_step==6,"actual melt, pour, stamp and cooling reach posting")
	await game.send_letter()
	check(host._experience_completed(),"actual NPC delivery reaches completion")
	host._complete(); await settle()
func motion(game: Node, at: Vector2) -> void:
	game.previous_pointer=game.pointer; game.pointer=at
	game._motion(InputEventMouseMotion.new())
func chess() -> void:
	await wait_for_opening("chess_stall")
	check(router.gameplay_module("chess","street:chess_stall"),"same production chess host starts")
	await settle()
	var host=current_scene
	var game=host.experience
	game.game_selected.emit(&"gomoku")
	await process_frame
	var match_view=game.match_view
	var turn_count := 0
	while not match_view.ended and turn_count<120:
		var empty: int=match_view.board.find(0)
		if empty<0: break
		match_view.play_stone(empty,1)
		if not match_view.ended: await match_view.ai_turn()
		turn_count+=1
	check(match_view.ended and turn_count>2,"real legal moves versus AI reach a game result")
	check(host._experience_completed(),"board result reaches host")
	host._complete(); await settle()
func wait_for_opening(location: String) -> void:
	var hours: Dictionary=root.get_node("WorldGraph").location_status(location)
	if gs.current_minute<int(hours.opens):
		check(gs.use_free_time(int(hours.opens)-gs.current_minute),"wait for "+location+" opening consumes actual free time")
	await process_frame

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	gs=root.get_node("GameState"); chapter=root.get_node("ChapterSystem"); modules=root.get_node("GameplayModuleSystem"); router=root.get_node("SceneRouter"); save=root.get_node("SaveManager")
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.gui_disable_input=true
	DisplayServer.window_set_title("Solmere · 五日流程验证")
	if OS.get_cmdline_user_args().has("--reload-only"):
		check(save.load_game("user://five_day_roundtrip.json"),"separate process loads completed five-day save")
		check(gs.current_role=="B" and gs.current_day==5 and root.get_node("CharacterSystem").switch_unlocked(),"quit then restart preserves chosen role and reveal")
		check(gs.shared_state.public_traces.size()==4 and gs.shared_state.public_traces.A_1_sound_sampling.owner=="A","quit then restart preserves public objects and owners")
		check(gs.role_states.A.artifacts.minigame_drafts.ghostwriting.stage=="END" and not gs.artifacts.get("minigame_drafts",{}).has("ghostwriting"),"finished letter remains A's private draft across process restart")
		check(save.load_game("user://stage2_cross_domain.json"),"separate process loads the real cross-domain completion save")
		check(gs.current_role=="B" and gs.current_day==5,"cross-domain save restores B at Day 5")
		check(gs.artifacts.minigame_drafts.ghostwriting.stage=="END" and gs.role_states.A.artifacts.minigame_drafts.ghostwriting.stage=="END","both letters remain in independent private drafts")
		for role in ["A","B"]:
			for module in (["cooking","chess"] if role=="A" else ["sound_sampling","ghostwriting"]):
				var outcome: Dictionary=gs.role_states[role].module_states[module].outcomes[-1]
				check(outcome.context.current_character==role and int(outcome.context.day)==5,"saved cross-domain result belongs to "+role+" / "+module)
		check(chapter.everyday_objects().size()>=9,"sourced everyday objects survive a process restart")
		var object_count: int=chapter.everyday_objects().size()
		gs.shared_state.erase("everyday_objects")
		check(chapter.everyday_objects().size()==object_count,"earlier five-day saves rebuild ordinary objects only from real delivered work and original owner's receipts")
		print("FIVE_DAY_RELOAD: PASS checks=",checks); quit(0); return
	chapter.start_new_game()
	save.active_slot=3
	check(chapter.chapter_sequence().size()==5,"five chapters, one role per day")
	check(not chapter.can_end_day().ok,"empty day cannot be skipped")
	check(not modules.begin_session("translation"),"retired translation cannot launch")
	check(not root.get_node("CharacterSystem").switch_unlocked(),"no character switching or reveal on Day 1")
	await travel("record_store")
	await studio()
	check(chapter.day_state().main_completed,"Day 1 genuine music completion")
	await talk("xanni")
	var a_money: int=gs.money
	await end_day()
	check(gs.current_role=="B" and gs.money==1600,"Day 2 loads B's private money")
	check(gs.role_states.A.money==a_money,"A money survives overnight")
	var music_memory: Dictionary=root.get_node("RelationshipSystem").npc_memory("xanni")
	check(music_memory.actual_met_A and not music_memory.actual_met_B and music_memory.perceived_same_person,"NPC actual encounters are separate from perceived identity")
	check(preload("res://scripts/town_sound/data/SampleStore.gd").new().list_samples().is_empty(),"B does not inherit A's audio library")
	await inspect_other()
	check(not chapter.story().B_searching and not chapter.story().B_noticing,"Day 2 trace does not prematurely start search")
	await travel("night_market")
	router.active_space_id="restaurant"
	check(root.get_node("EconomySystem").accept_procurement().ok,"real restaurant order accepted")
	await travel("produce_stall")
	if gs.current_minute<630: gs.use_free_time(630-gs.current_minute)
	for id in ["tomato","herbs","sea_beans"]:
		check(root.get_node("EconomySystem").purchase("produce_stall",id).ok,"purchase real ingredient "+id)
	await travel("night_market"); router.active_space_id="restaurant"
	check(root.get_node("EconomySystem").deliver_procurement().ok,"procurement delivered with receipts")
	await native("cooking",["tomato","herbs","sea_beans"],"careful_menu")
	await travel("night_market"); await talk("shi_yongqi")
	await end_day()
	check(gs.current_role=="A" and gs.current_day==3,"Day 3 returns to A")
	check(not chapter.story().A_noticing,"Day 3 does not seed noticing flags")
	await travel("handcraft_shop"); await letter()
	check(chapter.day_state().main_completed,"Day 3 actual letter completes main task")
	await inspect_other()
	await travel("handcraft_shop"); await talk("mossner")
	check(chapter.story().A_searching,"real clue then conversation starts search")
	await end_day()
	check(gs.current_role=="B" and gs.current_day==4,"Day 4 returns to B")
	await travel("chess_stall"); await chess()
	await inspect_other(); await travel("chess_stall"); await talk("naonao")
	check(chapter.story().meeting_arranged,"real dialogue choice arranges meeting")
	await end_day()
	check(gs.current_day==5 and not root.get_node("CharacterSystem").switch_unlocked(),"Day 5 starts before reveal; switching locked")
	await travel("print_shop"); current_scene._open_meeting(); await process_frame
	await capture("day-five-meeting")
	var meeting=current_scene.conversation
	meeting.next.pressed.emit(); meeting.next.pressed.emit()
	check(not root.get_node("CharacterSystem").switch_unlocked(),"reading first beats does not unlock")
	meeting.next.pressed.emit(); await settle()
	check(root.get_node("CharacterSystem").switch_unlocked(),"only actual final meeting acknowledgement unlocks")
	var original: Dictionary=gs.role_states.duplicate(true)
	var shared: Dictionary=gs.shared_state.public_traces.duplicate(true)
	var minute: int=gs.current_minute
	var scene_before: Node=current_scene
	await switch_at_planner()
	check(gs.current_role=="B" and gs.money==int(original.B.money),"switch loads B private balance")
	check(gs.inventory==original.B.inventory and gs.relationships==original.B.relationships,"switch loads B's independent inventory and relationships")
	check(scene_before==current_scene,"switch preserves the actual world scene")
	check(gs.current_minute==minute and gs.shared_state.public_traces==shared,"switch preserves time and shared world")
	check(save.save_game("user://five_day_roundtrip.json"),"five-day save written")
	chapter.start_new_game()
	check(save.load_game("user://five_day_roundtrip.json"),"new session loads five-day save")
	check(gs.current_role=="B" and gs.current_day==5 and root.get_node("CharacterSystem").switch_unlocked(),"reveal and chosen role survive load")
	# JSON roundtrips normalize int/float and typed arrays. Compare serialized
	# values, including payloads, rather than Variant container types.
	check(JSON.stringify(gs.shared_state.public_traces)==JSON.stringify(shared),"world trace ownership and discovery survive load")
	# Actually complete the opposite domains, not just mount their scenes.
	await switch_at_planner() # A: restaurant and chess.
	var b_before: Dictionary=gs.role_states.B.duplicate(true)
	await travel("night_market"); router.active_space_id="restaurant"
	check(root.get_node("EconomySystem").accept_procurement().ok,"Day 5 A accepts a real restaurant order")
	await travel("produce_stall")
	if gs.current_minute<630: check(gs.use_free_time(630-gs.current_minute),"wait for the produce shop uses actual time")
	for ingredient in ["tomato","herbs","sea_beans"]: check(root.get_node("EconomySystem").purchase("produce_stall",ingredient).ok,"A buys own cooking ingredient")
	await travel("night_market"); router.active_space_id="restaurant"
	check(root.get_node("EconomySystem").deliver_procurement().ok,"A's own receipts reimburse A")
	var cooking_before: int=gs.current_minute
	await native("cooking",["tomato","herbs","sea_beans"],"careful_menu")
	check(gs.current_minute==cooking_before+90 and modules.latest_outcome("cooking").context.current_character=="A","A's actual cooking cost and result route correctly")
	await travel("chess_stall"); await chess()
	check(modules.latest_outcome("chess").context.current_character=="A","A actually completes the existing chess game")
	check(gs.role_states.B.inventory==b_before.inventory and gs.role_states.B.money==b_before.money,"A's completed cross-domain activities do not alter B's wallet or items")
	await switch_at_planner()
	var a_before: Dictionary=gs.role_states.A.duplicate(true)
	await ensure_time(120); await travel("record_store")
	await ensure_time(60)
	var music_before: int=gs.current_minute
	await studio()
	check(gs.current_minute>=music_before+60 and modules.latest_outcome("sound_sampling").context.current_character=="B","B creates actual music and pays its real time cost")
	await ensure_time(90); await travel("handcraft_shop"); await letter()
	check(modules.latest_outcome("ghostwriting").context.current_character=="B","B actually completes and saves a private letter")
	check(gs.role_states.A.inventory==a_before.inventory and gs.role_states.A.money==a_before.money,"B's completed cross-domain activities preserve A's private accounts")
	check(save.save_game("user://stage2_cross_domain.json"),"cross-domain outcomes save after real completion")
	for role in ["A","B"]:
		if gs.current_role!=role: await switch_at_planner()
		for module in ["sound_sampling","cooking","ghostwriting","chess"]:
			# This final pass checks launch/cancel as time allows; all four opposite
			# domains above have already completed through real mechanics.
			if not modules.entry_check(module).ok: continue
			check(router.gameplay_module(module,"street:"+gs.current_location),"Day 5 "+role+" can enter "+module)
			await settle()
			check(modules.session_context().current_character==role,"minigame reads correct character context")
			check(not root.get_node("CharacterSystem").can_switch(),"switching is disabled while a minigame owns the context")
			if module in ["ghostwriting","chess"]:
				if module=="ghostwriting":
					while not current_scene.experience.ready_done: await process_frame
				check(current_scene.experience.get_meta("solmere_context").current_character==role,"mounted extension receives correct role")
				current_scene._cancel()
			else: current_scene._return_or_cancel()
			await settle()
	var old: Dictionary=gs.to_save_data(); old.save_version=6
	check(not gs.compatible_save(old),"old seven-day save explicitly rejected")
	check(gs.artifacts.get("residency",{}).get("submitted",{}).is_empty(),"no portfolio or application submission required")
	print("FIVE_DAY_FLOW: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(failures)
