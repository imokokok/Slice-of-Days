extends SceneTree
var failures := 0
var checks := 0
var notices: Array=[]
var gs: Node
var loop: Node
var guide: Node
var residency: Node
var router: Node
var save: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func settle() -> void:
	await process_frame; await process_frame
func snap(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	Input.warp_mouse(Vector2.ZERO); await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://core_"+tag+".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	gs=root.get_node("GameState"); loop=root.get_node("CoreLoopSystem"); guide=root.get_node("GuidanceSystem"); residency=root.get_node("ResidencySystem"); router=root.get_node("SceneRouter"); save=root.get_node("SaveManager")
	if OS.get_cmdline_user_args().has("--load-only"):
		check(save.load_game("user://core_loop_roundtrip.json"),"Reload in a second process")
		check(loop.day_state().reviewed and loop.day_state().reflection=="海浪和刹车声，原来也能被人认真听见。","Evening state survives process restart")
		check(loop.state().personal[0].text=="明天把作品带给Cici","Personal pin survives restart")
		var piece: Dictionary=residency.state().free_pages.day_1[0]
		check(piece.material=="module_sound_sampling_0" and piece.rotation>0 and piece.scale>1 and piece.x==270,"Canonical material ID and transforms survive restart")
		check(residency.state().final_references["0"]==["module_sound_sampling_0"],"Final reflection retains source ID")
		check(loop.state().callbacks["A_module_sound_sampling_0"].acknowledged,"NPC callback survives restart")
		check(guide.state().tracked_lead=="network_wu_wu","Pinned sourced lead survives restart")
		print("CORE LOOP RELOAD checks=",checks," failures=",failures); quit(failures); return
	root.get_node("ChapterSystem").start_new_game("A")
	router.town_day(.01); await create_timer(.8).timeout
	gs.shared_state.typewriter=false; guide.connect("notification",func(kind: String, message: String) -> void: notices.append([kind,message]))
	var shell: Control=current_scene.get_node("GameplayShell")
	guide.refresh(); shell._update_active_direction(); await settle()
	check(not is_instance_valid(shell.overlay),"Morning never forces Notebook open")
	check(shell.next_button.text.contains("领取资料袋"),"New save has an active direction without Notebook")
	check(not shell.next_button.flat and shell.next_button.get_theme_stylebox("normal").bg_color.a==1.0,"Guidance has an opaque native normal-state background")
	check(shell.clock_back.get_theme_stylebox("panel").bg_color==Color("254b66"),"Clock retains solid blue after deferred global styling")
	check(shell.next_button.get_theme_stylebox("hover").bg_color.a==1.0,"Hover keeps the guidance background opaque")
	check(not loop.objectives()[1].done,"Walking into the first location cannot complete participation")
	await snap("01_readable_hud")
	gs.current_location="print_shop"; gs.current_minute=660; router.active_space_id="print_studio"
	residency.collect_packet(); router.active_space_id=""; gs.current_location="cafe"
	var talk: Control=load("res://scripts/ui/conversation_panel.gd").new(); talk.npc="wu_wu"; current_scene.add_child(talk); await settle(); talk._advance()
	check(root.get_node("UIStateSystem").current()=="DIALOGUE","Conversation owns a separate UI state")
	var minute: int=gs.current_minute; gs.advance_world_clock(60); check(gs.current_minute==minute,"Reading dialogue pauses passive time")
	talk.vendor_choices.get_child(1).pressed.emit(); await finish_talk(talk)
	guide.refresh(); shell._update_active_direction()
	check(loop.state().introduced.has("wu_wu") and loop.objectives()[0].done,"Real Cici branch completes the contact objective")
	check(guide.next_step().location=="record_store","HUD follows the NPC lead without opening Notebook")
	check(notices.any(func(row: Array) -> bool: return row[0]=="HEARD"),"Completed conversation reports HEARD")
	await snap("02_sourced_direction")
	shell.open_paper("notebook"); await settle(); var paper: Control=shell.overlay
	check(paper.task_checks[0].button_pressed and not paper.task_checks[1].button_pressed,"Checkboxes reflect actual contact and participation")
	paper.notebook_section="heard"; paper.build(); check(guide.leads().any(func(row: Dictionary) -> bool: return row.id=="network_wu_wu" and row.source=="wu_wu"),"Lead keeps its source and destination")
	guide.track("network_wu_wu"); paper.mode="map"; paper.build(); await settle()
	check(paper.map_board.get_node("Destination_record_store").selected,"Pinned lead highlights the real map marker")
	await snap("03_pinned_map"); paper.close(); await settle()
	gs.money=500
	var route: Dictionary=root.get_node("TravelSystem").route("cafe","record_store","taxi","A",gs.current_minute)
	check(route.available,"An existing paid route is available")
	var before_money: int=gs.money; minute=gs.current_minute
	shell.open_paper("map"); paper=shell.overlay; paper._map_select("record_store"); paper._travel_selected("taxi"); await settle()
	var confirmation: Node=get_nodes_in_group("native_confirmation").back(); confirmation.accepted.emit()
	await create_timer(4.2).timeout
	check(gs.current_location=="record_store" and gs.money==before_money-int(route.cost),"Confirmed travel reaches the place and charges exactly once")
	check(gs.current_minute>=minute+int(route.minutes),"Travel consumes real world minutes")
	check(not loop.objectives()[1].done,"The taxi receipt cannot stand in for creative participation")
	check(router.gameplay_module("sound_sampling","street:record_store"),"Lead destination launches the existing sound activity")
	await create_timer(1.1).timeout
	var game: Control=current_scene
	check(root.get_node("UIStateSystem").current()=="MINIGAME","Native activity takes over UI state")
	for token in ["rain_awning","bus_brake","distant_flute"]: game._toggle_token(token)
	game._perform_primary_action(); await create_timer(2.7).timeout
	check(game.stage_ready,"Real sound selection and playback reach the activity gate")
	minute=gs.current_minute; game._complete_choice("planned_route"); await settle()
	check(game.completed and loop.day_state().participated.has("module_sound_sampling_0"),"Completed activity supplies the same canonical material to the loop")
	check(gs.current_minute>minute,"Activity completion charges its existing time cost")
	check(gs.shared_state.world_artifacts.loop_contributions.has("A_module_sound_sampling_0"),"Actual result leaves a persistent contribution")
	check(loop.state().callbacks.has("A_module_sound_sampling_0"),"Actual result schedules its NPC response")
	await snap("04_real_activity_result")
	router.return_from_gameplay(); await create_timer(1.0).timeout
	guide.refresh(); guide.feedback_age=1
	var merged: Dictionary=current_scene.get_node("GameplayShell/GuidanceToast").current
	if merged.is_empty(): merged=guide.take_feedback()
	check(not merged.is_empty() and merged.entries.any(func(entry: Dictionary) -> bool: return entry.kind=="DONE") and merged.entries.any(func(entry: Dictionary) -> bool: return entry.kind=="FOUND"),"DONE and FOUND merge in one feedback card")
	# New-day setup exercises a genuinely completed callback, not an invented result.
	gs.current_day=2; gs.current_minute=660; gs.current_location="cafe"; guide.refresh()
	talk=load("res://scripts/ui/conversation_panel.gd").new(); talk.npc="wu_wu"; current_scene.add_child(talk); await settle()
	check(str(talk.lines).contains("没有收进抽屉"),"Next encounter refers to the actual previous material")
	talk._close(); await settle(); check(not loop.state().callbacks["A_module_sound_sampling_0"].acknowledged,"Esc/close cannot acknowledge an unheard callback")
	talk=load("res://scripts/ui/conversation_panel.gd").new(); talk.npc="wu_wu"; current_scene.add_child(talk); await settle(); await finish_talk(talk,true)
	check(loop.state().callbacks["A_module_sound_sampling_0"].acknowledged,"Finishing callback acknowledges the previous contribution")
	check(gs.confirmed_residents.has("wu_wu"),"Sharing a relevant work plus meaningful participation grants recognition")
	check(not loop.share_material("wu_wu","module_sound_sampling_0").ok,"Same material cannot farm repeated sharing")
	check(guide.leads().any(func(row: Dictionary) -> bool: return str(row.id).begins_with("after_")),"Callback leads to a new discovery")
	# End-of-day fixture returns to day one to verify the full evening/portfolio path.
	gs.current_day=1; gs.current_minute=1260; gs.current_location="residence"; router.enter_space("home_a"); await create_timer(1.0).timeout
	shell=current_scene.get_node("GameplayShell"); loop.open_evening(); await settle()
	var evening: Control=get_nodes_in_group("evening_review").back(); evening.reflection.text="海浪和刹车声，原来也能被人认真听见。"
	await snap("05_evening_review"); evening._portfolio(); await settle()
	paper=shell.overlay; check(paper.mode=="dossier" and paper.archive_tab=="days","Evening button opens today's real portfolio")
	paper.canvas._drop_data(Vector2(250,120),{"residency_material":"module_sound_sampling_0"}); paper.canvas.transform_selected("rotate_right"); paper.canvas.transform_selected("larger"); paper.canvas.move_selected(Vector2(20,10))
	check(paper.canvas.pieces[0].material=="module_sound_sampling_0","Portfolio places the original material by ID")
	await snap("06_portfolio")
	paper.day=2; paper.build(); check(paper.canvas.pieces.is_empty(),"Next day is independently blank")
	paper.day=1; paper.build(); check(paper.canvas.pieces[0].x==270,"Page switch keeps material position")
	paper.mode="notebook"; paper.notebook_section="personal"; paper.build(); paper.body.get_node("PersonalPlanText").text="明天把作品带给Cici"; paper.body.get_node("PinPersonalPlan").pressed.emit(); await settle()
	check(loop.state().personal.size()==1,"Player creates a genuine private plan")
	paper.mode="dossier"; paper.archive_tab="final"; paper.build(); paper._reference_picker("0")
	var choices: Array=paper.detail.find_children("*","Button",true,false)
	for choice in choices:
		if choice.text.contains("采样"):
			choice.pressed.emit(); break
	check(residency.state().get("final_references",{}).get("0",[]).has("module_sound_sampling_0"),"Final question can cite a real earned material")
	await snap("07_final_references"); paper.close(); await settle()
	check(save.save_game("user://core_loop_roundtrip.json"),"Existing SaveManager saves the whole loop")
	await edge_cases()
	print("CORE LOOP checks=",checks," failures=",failures); quit(failures)
func finish_talk(talk: Control, share := false) -> void:
	for i in 55:
		if not is_instance_valid(talk) or talk.is_queued_for_deletion(): break
		if is_instance_valid(talk.vendor_choices):
			var buttons: Array=talk.vendor_choices.get_children()
			buttons[0 if share else buttons.size()-1].pressed.emit()
		else: talk._advance()
		await settle()
	check(not is_instance_valid(talk) or talk.is_queued_for_deletion(),"Conversation returns to the scene")
func edge_cases() -> void:
	guide.progress_key=""; guide.idle_tick(0,false)
	for i in 4: guide.idle_tick(46,true)
	check(guide.help_level==4,"Walking aimlessly does not reset progressive help")
	loop.pin_personal("走到海边")
	gs.current_location="port"; guide.idle_tick(0,false); check(guide.help_level==0,"Meaningful location progress resets help")
	gs.current_day=4; gs.current_minute=1120; loop.state().introduced["naonao"]={"day":1}; guide.refresh()
	loop.refresh(); var count: int=notices.size(); loop.refresh()
	check(notices.size()==count,"An expiring opportunity warns only once")
	check(guide.next_step().get("priority","")=="critical","An unpinned expiring opportunity has priority")
	gs.current_minute=1180
	check(loop.opportunities().any(func(row: Dictionary) -> bool: return row.source=="naonao" and row.status=="missed"),"Missed opportunities remain in history")
	check(not loop.dialogue_prefix("naonao").is_empty(),"Missed event has an authored NPC retelling")
	gs.money=0; var route: Dictionary=root.get_node("TravelSystem").travel("cafe","taxi")
	check(not route.ok and gs.money==0,"Unaffordable travel preserves money and provides a failure")
	gs.current_location="residence"; gs.current_day=7; gs.current_minute=1320; router.active_space_id="home_a"; loop.day_state().reviewed=true
	check(not root.get_node("ChapterSystem").sleep_at_home() and not gs.shared_state.get("sleep_pending",false),"Day seven never skips an unsubmitted application")
	await settle()
	var evening: Control=get_nodes_in_group("evening_review").back(); evening._extend(); await settle()
	check(loop.state().extra_nights==1 and gs.can_fit_now(30),"Explicit final-day fallback gives real time to recover missing materials")
	check(loop.day_stamp().contains("+1") and gs.current_day==7,"Extra stay is visible without adding an eighth portfolio page")
	if DisplayServer.get_name()!="headless": await memory_contract()
	root.get_node("ChapterSystem").start_new_game("A")
	for npc in loop.catalog.people:
		if npc=="grocery": continue
		var module: String=loop.catalog.people[npc].module
		residency._add("contract_"+npc,"work","居民相关作品",{"source":"module:"+module+":0"})
		loop.encounter(npc); check(loop.share_material(npc,"contract_"+npc).ok,"All twelve residents accept a relevant material")
		check(gs.confirmed_residents.has(npc),"Each core resident has a reachable meaningful recognition condition")
	check(gs.confirmed_residents.size()==12,"Twelve core recognition paths are reachable")

func memory_contract() -> void:
	gs.current_day=1; gs.current_minute=600
	var memory: Control=load("res://scripts/meta/memory_view.gd").new()
	var rooms: Array=root.get_node("MetaExperience").memories
	memory.definition=rooms.filter(func(row: Dictionary) -> bool: return str(row.id)=="A1")[0]
	current_scene.add_child(memory); await create_timer(5.5).timeout
	check(memory.ready_to_walk and root.get_node("UIStateSystem").current()=="MEMORY","Real 3D room runs under memory input state")
	var item: Dictionary=memory.objects.items.filter(func(row: Dictionary) -> bool: return str(row.kind)=="read")[0]
	memory.objects.interact(item)
	check(is_instance_valid(memory.objects.reading),"Authored memory object opens a genuine reading interaction")
	await snap("08_memory_interaction"); memory.objects.close_paper(); memory._leave(); await settle()
	check(gs.current_minute==605 and residency.state().materials.has("memory_A1"),"Examined memory returns with real time and a canonical material")
	check(loop.state().callbacks.has("A_memory_A1"),"Examined memory connects back to a resident")
