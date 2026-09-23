extends SceneTree
var failures := 0
var checks := 0
var gs
var chapter
var house
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
	else: print("PASS ",message)
func text_of(node: Node) -> String:
	var value := str(node.text)+"\n" if node is Label or node is BaseButton else ""
	for child in node.get_children(): value+=text_of(child)
	return value
func free_minutes(blocks: Array) -> int:
	var result := 0
	for b in blocks: result+=int(b[1])-int(b[0])
	return result
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	gs=root.get_node("GameState"); chapter=root.get_node("ChapterSystem"); house=root.get_node("HouseholdSystem")
	chapter.start_new_game()
	root.get_node("SceneRouter").enter_space("home_a")
	check(gs.current_location=="bus_stop" and root.get_node("SceneRouter").active_space_id.is_empty(),"private room cannot be used as a teleport from another location")
	check(root.get_node("ResidentProfileSystem").profiles.size()==12,"exactly twelve authored residents")
	check(root.get_node("CharacterSystem").profile("B").ambition.contains("音乐"),"B's ambition is music")
	check(root.get_node("CharacterSystem").profile("A").inner_tension.contains("放下"),"A chooses among genuine interests")
	check(gs.active_time_blocks().size()>gs.schedule_for("B",1).blocks.size(),"A has more fragmented time than B")
	var total := free_minutes(gs.active_time_blocks())
	gs.current_minute=600
	check(not gs.can_fit_now(120),"long activity initially does not fit A's fragment")
	var minute: int=gs.current_minute
	check(gs.combine_flexible_time(),"A can move a private arrangement through the actual schedule service")
	check(gs.current_minute==minute and gs.can_fit_now(120),"rearranging unlocks longer work without rewinding the clock")
	check(free_minutes(gs.active_time_blocks())==total,"moving private time does not create extra free minutes")
	var saved: Dictionary=gs.to_save_data().duplicate(true)
	gs.load_save_data(saved)
	check(gs.can_fit_now(120),"rearranged time survives save restoration")
	var planner=load("res://scripts/ui/components/day_five_planner.gd").new(); root.add_child(planner); await process_frame
	var words := text_of(planner)
	check(not words.contains("另一位") and not words.contains("以 B") and not words.contains(" · A ·"),"early planner has no dual protagonist spoiler")
	planner.queue_free(); await process_frame
	var private_before: Dictionary=gs.role_states.duplicate(true)
	gs.current_minute=1120; house.sync_routines()
	var count: int=house.state().routines.size(); house.sync_routines()
	check(count>0 and house.state().routines.size()==count,"inactive daily movements are persisted once")
	check(gs.role_states==private_before,"background routines cannot earn money, recognition, works or private choices")
	check(not chapter.day_state().main_completed and not chapter.story().A_noticing,"domestic traces cannot complete a main task or reveal another person")
	check(house.mail().size()==2,"both ordinary notices share one mailbox")
	gs.current_location="residence"
	check(house.read_mail("d1_B_notice").ok and house.read_mail("d1_B_notice",true).ok,"wrong notice can be read and put back")
	check(house.state().mail.d1_B_notice.read_by==["A"] and house.state().mail.d1_B_notice.returned_by==["A"],"mail interactions retain actual reader ownership")
	check(not house.exchange_leads(),"resident information sharing is locked before the meeting")
	check(chapter.residency_audit("A").required==12 and not chapter.residency_audit("A").passed,"residency requires twelve real confirmations")
	check(not house.submit_application().ok,"empty application cannot be submitted")
	for id in root.get_node("ResidentProfileSystem").profiles: root.get_node("RelationshipSystem").set_confirmation(str(id),"granted")
	check(house.submit_application().ok,"complete independent application can actually be submitted")
	check(house.state().applications.A.recognitions.size()==12,"submission retains the twelve actual signer identities")
	gs.switch_to_role("B",2,true)
	check(gs.current_location=="residence" and root.get_node("CoreLoopSystem").home()=="residence","both floors use the same physical address")
	check(gs.confirmed_residents.is_empty() and not house.application().passed,"B never inherits A's twelve recognitions")
	check(not gs.combine_flexible_time(),"B cannot silently move a fixed work block")
	gs.current_minute=830
	check(not gs.can_fit_now(30),"activity cannot overlap the fixed restaurant shift")
	gs.current_minute=840; gs.current_location="residence"
	check(not gs.complete_next_commitment().ok,"restaurant shift cannot be completed at home")
	gs.current_location="night_market"
	var money: int=gs.money
	check(gs.complete_next_commitment().ok and gs.current_minute==1080 and gs.money==money+195,"attendance consumes the real fixed block and pays once")
	check(not gs.complete_next_commitment().ok and gs.money==money+195,"shift cannot be paid twice")
	check(not chapter.day_state().main_completed,"ordinary shift attendance does not auto-complete cooking")
	gs.switch_to_role("A",5,true); chapter.story().meeting_arranged=true; gs.current_location="print_shop"
	check(chapter.meeting_lines().any(func(s: String)->bool:return s.contains("海风路17号")),"meeting recovers the shared address")
	check(chapter.meeting_lines().any(func(s: String)->bool:return s.contains("偷偷做过一些音乐")),"B brings existing musical ability to the exchange")
	check(chapter.finish_reveal(),"identity reveal remains its own real acknowledgement")
	check(not chapter.residency_audit("B").passed,"meeting cannot forge B's residency approval")
	check(gs.schedule_for("B",5).commitments.is_empty(),"Day 5 scheduled rest does not pay or cancel an unworked shift")
	house.sync_routines()
	var background_count: int=house.state().routines.size()
	var shared_minute: int=gs.current_minute
	gs.switch_to_role("B",5,false); gs.current_minute=shared_minute; house.sync_routines()
	check(house.state().routines.size()==background_count,"switching perspective cannot backfill an inactive action into played time")
	gs.switch_to_role("A",5,false)
	check(chapter.exchange_motivation("chess").contains("选一步"),"A's chess motivation connects to making a choice")
	var b_private: Dictionary=gs.role_states.B.duplicate(true)
	gs.shared_state["core_loop_B"]["introduced"]={"shi_yongqi":{}}
	gs.current_location="residence"
	check(house.exchange_leads(),"after meeting, a known resident's location can be exchanged")
	check(gs.shared_state.get("knowledge_A",[]).any(func(f: Dictionary)->bool:return f.get("shared_by","")=="B"),"shared location fact records its real source")
	check(gs.role_states.B==b_private,"sharing information does not transfer private relationships")
	var restored: Dictionary=gs.to_save_data().duplicate(true); gs.load_save_data(restored)
	check(house.state().applications.has("A") and not house.state().applications.has("B"),"applications stay private after restoration")
	# Old compatible saves migrate the obsolete second home, retaining content.
	gs.switch_to_role("B",5,false); gs.current_location="dorm"; gs.commit_active_role_state()
	var old: Dictionary=gs.to_save_data().duplicate(true); old.shared_state.erase("architecture_version"); gs.load_save_data(old)
	check(gs.current_location=="residence" and house.state().applications.has("A"),"old separate-home save migrates without losing a submitted application")
	print("ARCHITECTURE_AUDIT: ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
