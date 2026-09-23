extends SceneTree
var checks := 0
var failures := 0
var messages: Array=[]
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.gui_disable_input=true
	var gs=root.get_node("GameState")
	var chapter=root.get_node("ChapterSystem")
	var guidance=root.get_node("GuidanceSystem")
	var router=root.get_node("SceneRouter")
	var modules=root.get_node("GameplayModuleSystem")
	chapter.start_new_game()
	gs.current_minute=540
	guidance.notification.connect(func(kind: String, words: String): messages.append({"kind":kind,"text":words}))
	check(chapter.everyday_objects().is_empty(),"No invented objects in a new home")
	root.get_node("EchoSystem").close_day()
	check(not gs.shared_state.has("offscreen_B"),"Overnight cannot create a fictional receipt for B")
	var first: Dictionary=guidance.next_step()
	check(first.location=="record_store" and not first.text.contains("A") and not first.text.contains("线索"),"Day 1 possibility guides music without identity or mystery")
	guidance.idle_tick(0,false); guidance.idle_tick(46,true)
	check(guidance.help_level==1 and guidance.next_step().context.contains("现在是"),"First stall level explains time and place even while wandering")
	guidance.idle_tick(46,false)
	check(guidance.help_level==2 and guidance.next_step().text==chapter.plan().label,"Second level names the actual activity")
	guidance.idle_tick(46,false)
	check(guidance.help_level==3 and guidance.next_step().context.contains("地图"),"Third level exposes route instructions")
	check(gs.current_day==1 and not chapter.day_state().main_completed,"Hints never progress the day automatically")
	var before: int=gs.money
	gs.earn_money(12,"测试交易")
	check(gs.money==before+12 and messages.any(func(row): return row.text.contains("+12")),"Money feedback derives from actual balance changes immediately")
	guidance.blocked("当前时间放不下这项活动。")
	check(guidance.next_step().priority=="critical","Blocking feedback outranks optional suggestions")
	guidance.block_age=16
	check(guidance.next_step().priority!="critical","Blocking reminder expires back to current possibilities")
	check(not guidance.location_status("park").open,"Daytime lookout has a real closed reason")
	router.town_day(); await create_timer(.5).timeout
	while router.transitioning: await process_frame
	await process_frame
	var shell=current_scene.get_node("GameplayShell")
	shell.open_paper("map"); await process_frame
	var paper=shell.overlay
	check(is_instance_valid(paper),"Map opens after the scene has finished entering")
	if not is_instance_valid(paper): quit(1); return
	var marker=paper.map_board.get_node("Destination_record_store")
	check(marker.selected,"Current core place is lightly emphasized on the actual map")
	paper.map_board.get_node("Destination_park").pressed.emit()
	check(paper.feedback.text.contains("21:00"),"Clicking closed place gives its actual opening hours")
	check(paper.map_board.get_node("Destination_park").get_meta("state")=="unavailable","Closed state is bound to the native marker")
	gs.current_minute=root.get_node("WorldGraph").LOOKOUT_OPEN; gs.state_changed.emit()
	check(paper.map_board.get_node("Destination_park").get_meta("state")!="unavailable","Opening time refreshes existing markers without reopening the map")
	paper.close(); await process_frame
	check(not modules.entry_check("sound_sampling").ok,"Closed music shop rejects evening entry")
	gs.current_minute=600
	var old_minute: int=gs.current_minute
	check(router.request_gameplay("sound_sampling","street:record_store"),"Real activity request opens a confirmation")
	var confirmations:=get_nodes_in_group("native_confirmation")
	check(confirmations.size()==1 and confirmations[0].description.contains("分钟"),"Time is described before entering the activity")
	check(modules.pending_module_id().is_empty(),"Request alone does not start the activity")
	confirmations[0].cancelled.emit(); confirmations[0].queue_free(); await process_frame
	check(gs.current_minute==old_minute and modules.pending_module_id().is_empty(),"Cancelling costs no time or progress")
	check(not chapter.can_end_day().ok and not chapter.sleep_at_home(),"Missing main activity cannot silently end a day")
	# Unit-level comparison of the actual scheduling interface, without changing
	# chapter flags. Full New Game -> Day 5 is tested by test_five_day_flow.gd.
	check(gs.schedule_for("A",5).blocks.size()==2 and gs.schedule_for("B",5).blocks.size()==4,"Day 5 schedules expose distinct actual time windows")
	check(gs.can_fit_at("A",5,700,60) and not gs.can_fit_at("B",5,700,60),"Identical activity is constrained by the chosen character's real window")
	check(not gs.can_fit_at("B",5,1320,30),"Late-night grace cannot create an unlimited fifth day")
	var state: Dictionary=guidance.flow_state()
	for key in ["day","character","main","blocks","minute","available_locations","side_activity_state","narrative","switch_enabled"]: check(state.has(key),"Guidance reads "+key)
	print("GAMEPLAY_GUIDANCE: ",checks," checks / ",failures," failures")
	quit(failures)
