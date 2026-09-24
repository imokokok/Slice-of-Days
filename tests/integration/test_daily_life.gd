extends SceneTree
var gs
var life
var people
var router
var modules
var chapter
var save
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(title)
	else: print("PASS ",title)

func settle() -> void:
	await process_frame
	while router.transitioning: await process_frame
	await process_frame
	if is_instance_valid(current_scene): current_scene.set_process(false)

func fresh(role := "A", day := 1, time := 480) -> void:
	chapter.start_new_game(); gs.switch_to_role(role,day,true); gs.current_minute=time
	gs.current_location="residence"; router.active_space_id=""; router.transitioning=false

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	gs=root.get_node("GameState"); life=root.get_node("LifeSystem"); people=root.get_node("PeoplePuzzleSystem"); router=root.get_node("SceneRouter"); modules=root.get_node("GameplayModuleSystem"); chapter=root.get_node("ChapterSystem"); save=root.get_node("SaveManager")
	root.get_node("CoreLoopSystem").set_process(false)
	root.get_node("ChapterSystem").set_process(false)
	fresh()
	check(life.describe().size()==4,"four verbal states, no exposed numerical HUD")
	check(not life.add_plan("unknown_activity",480,"walk").ok,"undiscovered activity cannot be planned")
	var snapshot: Dictionary=gs.to_save_data().duplicate(true)
	var first: Dictionary=life.add_plan("rest",480,"walk")
	check(first.ok and str(life.state().plans[0].status)=="planned","writing a plan does not execute it")
	check(gs.current_minute==480,"planning costs no activity time")
	check(not life.add_plan("quiet",490,"walk").ok,"overlapping plans rejected")
	check(not life.add_plan("rest",520,"walk").ok,"long action cannot cross a private commitment")
	check(not life.everyday("rest").ok,"rest cannot be executed remotely outside home")
	router.active_space_id="home_a"
	var body: float=life.value("body")
	check(life.everyday("rest").ok,"actual home rest executes")
	check(gs.current_minute==510 and str(life.state().plans[0].status)=="done","home rest settles once with real thirty minutes")
	check(life.value("body")>body,"rest changes body state")
	gs.load_save_data(snapshot); router.active_space_id="home_a"
	check(not life.everyday("meal").ok,"meal requires actual food")
	gs.inventory["bread"]=2
	check(life.everyday("meal").ok and gs.inventory.bread==1,"meal consumes one inventory item")
	check(life.add_plan("quiet",500,"walk").ok,"short activity fits remaining gap")
	var token: String=life.state().plans[-1].id
	check(life.cancel_plan(token).ok,"plan cancellation records crossed out history")
	var clarity: float=life.value("clarity")
	check(not life.cancel_plan(token).ok and life.value("clarity")==clarity,"repeat cancellation cannot charge state again")
	gs.load_save_data(snapshot); router.active_space_id=""
	gs.current_minute=524; gs.clock_remainder=0
	gs.advance_world_clock(8.0)
	check(gs.current_minute==526,"natural clock crosses a schedule boundary without jumping to next gap")
	gs.current_minute=480
	var minutes_before := 0
	for span in gs.active_time_blocks(): minutes_before+=int(span[1])-int(span[0])
	check(gs.combine_flexible_time(),"A can move private commitment to join two gaps")
	var minutes_after := 0
	for span in gs.active_time_blocks(): minutes_after+=int(span[1])-int(span[0])
	check(minutes_before==minutes_after and gs.can_fit_now(60),"joining preserves total free minutes and permits real long activity")
	for i in 3: life.edited("重排测试")
	check(life.value("clarity")<65,"frequent replanning has a cumulative consequence")
	var travel=root.get_node("TravelSystem")
	var normal: Dictionary=travel.route("residence","record_store","walk","A",480)
	life.state().values.body=15
	var slow: Dictionary=travel.route("residence","record_store","walk","A",480)
	check(normal.available and slow.available and int(slow.minutes)>int(normal.minutes),"fatigue actually increases walking journey minutes")
	check(life.walk_multiplier()<1,"fatigue also affects street locomotion")
	life.state().values.engagement=20
	check(not life.thought().is_empty(),"low engagement changes internal response")
	gs.money=180; life.state().values.security=20
	check(not life.spending_concern(100).is_empty(),"low security produces a spending concern")
	gs.earn_money(100,"测试收入"); check(life.today_income()==100,"income summary derives from actual ledger")
	gs.current_minute=1430; life.state().values.body=10
	life.close_day(); var recovered: float=life.value("body")
	life.close_day(); check(life.value("body")==recovered,"sleep cannot be applied twice")
	gs.switch_to_role("B",2,true); check(life.value("body")!=recovered,"other role has independent body state")
	gs.switch_to_role("A",3,true); life.begin_day()
	check(gs.current_minute==520,"severe previous fatigue delays next playable morning")
	life.begin_day(); check(gs.current_minute==520,"dawn delay applies once")
	check(save.save_game() and save.load_game(),"real save reload restores life state")
	life.begin_day()
	check(gs.current_minute==520 and is_equal_approx(life.value("body"),recovered),"state and dawn marker survive reload without duplicate delay")
	fresh("B",2,800)
	check(not life.adjust_shift("swap").ok,"work swap requires actual prior cooperation")
	var cash: int=gs.money
	check(life.adjust_shift("leave").ok,"leave before shift is allowed")
	check(gs.money==cash and gs.can_fit_now(240),"leave yields no wage and frees actual reserved time")
	check(not life.adjust_shift("leave").ok,"leave cannot be claimed twice")
	fresh("B",2,800)
	root.get_node("RelationshipSystem").add_flags("shi_yongqi",["completed_shift"])
	check(life.adjust_shift("swap").ok,"prior collaborator can agree a shift swap")
	check(gs.commitments_for_day("B",4).size()==2,"swap retains next afternoon shift and adds morning work")
	check(not gs.can_fit_at("B",4,600,60) and gs.can_fit_now(240),"swapped future shift consumes future freedom")
	gs.switch_to_role("B",4,true)
	check(life.adjust_shift("leave").ok and gs.commitments_for_day().size()==1,"cancelling swapped morning preserves the separate afternoon job")
	check(not gs.can_fit_now(700),"cancelling one shift does not free another shift's time")
	fresh("B",2,840); gs.current_location="night_market"; router.active_space_id="restaurant"
	var before_shift: Dictionary=gs.to_save_data().duplicate(true)
	check(life.start_shift(true).ok,"start actual kitchen for early shift")
	await settle()
	check(modules.pending_module_id()=="cooking" and gs.money==1600,"starting work gives no instant wage")
	check(int(root.get_node("EconomySystem").cooking_cost({}).minutes)==90,"early shift quotes actual ninety minute service")
	modules.cancel_session(); check(life.active_shift().is_empty() and gs.current_minute==840,"cancelling kitchen restores time and shift availability")
	router.return_from_gameplay(); await settle()
	check(life.start_shift(true).ok,"cancelled work can be started again")
	await settle()
	var kitchen=current_scene
	for ingredient in ["bread","cheese","lemon"]: kitchen._toggle_token(ingredient)
	preload("res://tests/integration/cooking_walkthrough.gd").prepare_and_cook(kitchen)
	check(kitchen.stage_ready,"actual chop, heat and cooking interactions complete")
	var choices: Array=modules.prototype_for("cooking").choices
	var choice_id := ""
	for choice in choices:
		if modules.choice_interaction_check("cooking",str(choice.id),{"selected_tokens":["bread","cheese","lemon"]}).ok: choice_id=str(choice.id); break
	check(not choice_id.is_empty(),"cooking has a valid recipe choice")
	if not choice_id.is_empty(): kitchen._complete_choice(choice_id)
	check(kitchen.completed,"real kitchen commits completed meal")
	check(gs.current_minute==930 and gs.money==1673,"ninety minute early shift pays floor of 195 times 90 over 240")
	var earned: int=gs.money; life.finish_shift()
	check(gs.money==earned and life.active_shift().is_empty(),"shift cannot pay twice")
	check(gs.completed_commitments.has("d2_b_restaurant_service"),"finished early shift is resolved for this day")
	kitchen.return_button.pressed.emit(); await settle()
	gs.load_save_data(before_shift); router.active_space_id="restaurant"
	check(life.start_shift().ok,"full shift starts a separate actual kitchen session")
	await settle(); kitchen=current_scene
	for ingredient in ["bread","cheese","lemon"]: kitchen._toggle_token(ingredient)
	preload("res://tests/integration/cooking_walkthrough.gd").prepare_and_cook(kitchen)
	kitchen._complete_choice(choice_id)
	check(kitchen.completed and gs.current_minute==1080 and gs.money==1795,"complete four hour shift pays exactly one full wage after actual cooking")
	kitchen.return_button.pressed.emit(); await settle()
	gs.load_save_data(before_shift); router.active_space_id="restaurant"
	gs.current_minute=1081; life.tick(1)
	check(gs.money==1600 and root.get_node("RelationshipSystem").has_flag("shi_yongqi","missed_shift_d2"),"missed shift pays nothing and affects work relationship")
	fresh(); gs.current_location="record_store"; gs.current_minute=610; router.active_space_id="record_shop"
	check(people.present("xanni"),"facet event requires physically present NPC")
	check(people.act("xanni","observe").ok,"specific observation produces first sourced facet")
	check(people.page("xanni").facets.size()==1 and not people.act("xanni","observe").ok,"repeating same observation cannot farm facets")
	for i in 3: root.get_node("DialogueSystem").complete_linear_conversation("xanni")
	check(people.page("xanni").facets.size()==1 and not gs.confirmed_residents.has("xanni"),"repeated conversation neither reveals hidden sides nor grants signature")
	gs.current_minute=690; life.state().values.clarity=20
	check(people.offer("xanni").kind=="detail","low clarity requires looking again before complex choice")
	check(people.act("xanni","detail").ok,"extra observation restores access to exact known detail")
	check(people.act("xanni","wrong").ok and people.page("xanni").facets.size()==1,"uninformed choice earns no facet")
	check(people.act("xanni","help").ok and people.page("xanni").facets.size()==2,"specific informed action unlocks second side")
	check(not gs.confirmed_residents.has("xanni"),"enough information does not auto grant signature")
	gs.current_minute=770
	check(people.act("xanni","signature").ok and gs.confirmed_residents.has("xanni"),"later in-person review grants signature")
	gs.switch_to_role("B",5,true); chapter.story().reveal_completed=true; gs.shared_state.character_switch_enabled=true
	people.exchange()
	check(people.page("xanni").facets.is_empty() and not gs.confirmed_residents.has("xanni"),"shared knowledge does not copy another role's relationship")
	check(gs.shared_state.shared_people_facets.xanni.size()==2,"Day 5 exchange shares source-stamped facets")
	check(people.text_for("xanni").contains("A 的经历"),"album distinguishes exchanged provenance")
	fresh(); gs.current_location="record_store"
	check(life.add_plan("rest",610,"walk").ok,"known home activity can be planned from town")
	var plan_id: String=life.state().plans[-1].id
	var quote: Dictionary=life.departure_quote(plan_id)
	check(quote.ok and quote.transport=="walk" and quote.location=="residence","saved transport preference resolves an actual route")
	router.active_space_id="record_shop"
	check(not life.departure_quote(plan_id).ok,"planned departure cannot teleport out of an interior")
	router.active_space_id=""; gs.spend_time(200)
	check(str(life.state().plans[-1].status)=="missed" and not life.departure_quote(plan_id).ok,"time passing expires missed plan without completing it")
	# Real notebook buttons and scrollable layout, without replacing the world art.
	fresh(); router.town_day(0.01); await settle()
	var shell=current_scene.get_node("GameplayShell")
	check(shell.switch_button.visible,"planner has visible in-game entrance before reveal")
	shell.open_paper("day_schedule"); await process_frame
	var planner=shell.overlay.find_child("DayFivePlanner",true,false)
	check(planner!=null and planner.find_child("LifeTab_me",true,false)!=null,"new notebook loads inside production paper overlay")
	planner.find_child("LifeTab_plan",true,false).pressed.emit(); await process_frame
	planner.find_child("AddPlan",true,false).pressed.emit(); await process_frame
	check(life.state().plans.size()==1 and str(life.state().plans[0].status)=="planned","real planner button adds intent only")
	check(planner.find_child("Choose_B",true,false)==null,"other role stays hidden before reveal")
	print("DAILY_LIFE: ",checks," checks / ",failures," failures")
	quit(failures)
