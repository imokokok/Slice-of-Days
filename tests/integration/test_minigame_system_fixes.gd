extends SceneTree

var gs
var modules
var life
var chapter
var router
var save
var people
var dialogue
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	else: print("PASS ",message)

func fresh(role := "A", day := 1, minute := 610) -> void:
	chapter.start_new_game()
	gs.switch_to_role(role,day,true)
	chapter.align_saved_chapter()
	gs.current_minute=minute
	gs.current_location="residence"
	router.active_space_id=""
	router.transitioning=false

func has_card(id: String) -> bool:
	return life.known_cards().any(func(card: Dictionary) -> bool: return str(card.id)==id)

func settle() -> void:
	await process_frame
	while router.transitioning: await process_frame
	await process_frame
	if is_instance_valid(current_scene): current_scene.set_process(false)

func cooking(role: String, choice: String) -> void:
	fresh(role,5,610)
	chapter.story().reveal_completed=true
	if role=="A": check(gs.combine_flexible_time(),"A joins time for the real cooking session")
	gs.current_location="night_market"; router.active_space_id="restaurant"
	var opened: bool=router.gameplay_module("cooking","regression")
	check(opened,"Real kitchen opens for "+role+" / "+choice)
	if not opened: return
	await settle()
	var kitchen=current_scene
	for ingredient in ["bread","cheese","lemon"]: kitchen._toggle_token(ingredient)
	preload("res://tests/integration/cooking_walkthrough.gd").prepare_and_cook(kitchen)
	check(kitchen.stage_ready,"Preparation, heat, stirring, tasting and plating finish")
	var snapshot: Dictionary=gs.to_save_data().duplicate(true)
	var original=save.get_script()
	var failing:=GDScript.new()
	failing.source_code="extends \"res://scripts/core/save_manager.gd\"\nfunc save_or_report(_context := \"\") -> bool:\n\treturn false\n"
	check(failing.reload()==OK,"Cooking save-failure fixture compiles")
	save.set_script(failing)
	kitchen._complete_choice(choice)
	check(not kitchen.completed and gs.to_save_data()==snapshot,"Failed cooking save rolls back time, resources, recipe and people facet")
	save.set_script(original)
	# Legacy result data cannot reintroduce direct signatures through either layer.
	for row in modules.prototypes.cooking.choices:
		if str(row.id)==choice:
			row.results["confirmations"]={"shi_yongqi":"granted"}
			row.results_by_role[role]["confirmations"]={"xanni":"granted","zhou_xiaoliu":"granted"}
	kitchen._complete_choice(choice)
	check(kitchen.completed and gs.current_minute==700,"Retry completes real ninety-minute cooking")
	check(gs.confirmed_residents.is_empty(),"Cooking grants no automatic signatures for "+role+" / "+choice)
	check(people.page("shi_yongqi").facets.size()==1,"Actual cooking records one sourced Shi experience")
	var facet: Dictionary=people.page("shi_yongqi").facets[0]
	check(str(facet.role)==role and int(facet.minute)==700 and str(facet.text).contains("石泳琪"),"Cooking facet keeps actor, time and actual service response")
	check(people.page("xanni").facets.is_empty() and people.page("zhou_xiaoliu").facets.is_empty(),"Absent diners receive no invented facets")
	check(save.save_game() and save.load_game() and people.page("shi_yongqi").facets.size()==1,"Cooking experience survives real save reload")
	var completed: Dictionary=gs.to_save_data().duplicate(true)
	kitchen._complete_choice(choice)
	check(gs.to_save_data()==completed,"Repeated submission cannot duplicate rewards or people sides")
	modules.load_prototype_data(modules.PROTOTYPES_PATH)
	root.get_node("EconomySystem")._apply_work_prices()
	kitchen.return_button.pressed.emit(); await settle()
	check(people.offer("shi_yongqi").kind=="observe","Cooking still requires a distinct later observation")
	check(not people.act("shi_yongqi","signature").ok,"One cooking side cannot sign the album")
	check(people.act("shi_yongqi","observe").ok,"Later physical observation adds a second personal side")
	check(not people.act("shi_yongqi","signature").ok,"Two sides do not bypass the later-review wait")
	gs.current_minute=770
	check(people.act("shi_yongqi","signature").ok and gs.confirmed_residents.has("shi_yongqi"),"Later in-person review grants the signature")
	check(save.save_game() and save.load_game() and gs.confirmed_residents.has("shi_yongqi"),"Earned signatures survive reload")
	if role=="B":
		check(router.gameplay_module("cooking","repeat-regression"),"Signed character can cook another real meal")
		await settle(); kitchen=current_scene
		for ingredient in ["bread","cheese","lemon"]: kitchen._toggle_token(ingredient)
		preload("res://tests/integration/cooking_walkthrough.gd").prepare_and_cook(kitchen)
		kitchen._complete_choice(choice)
		check(kitchen.completed and people.page("shi_yongqi").facets.size()==2 and gs.confirmed_residents.has("shi_yongqi"),"Another meal neither farms facets nor revokes an earned signature")
		kitchen.return_button.pressed.emit(); await settle()

func run() -> void:
	# --isolated-save alone does not isolate extension saves. Require a separate
	# project-wide user directory so this regression cannot touch a player's game.
	if not OS.get_cmdline_user_args().has("--isolated-save") or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("Solmere_Test_"):
		push_error("Run in a copied project with a unique Solmere_Test_ user directory.")
		quit(2); return
	gs=root.get_node("GameState"); modules=root.get_node("GameplayModuleSystem")
	life=root.get_node("LifeSystem"); chapter=root.get_node("ChapterSystem")
	router=root.get_node("SceneRouter"); save=root.get_node("SaveManager")
	people=root.get_node("PeoplePuzzleSystem"); dialogue=root.get_node("DialogueSystem")
	root.get_node("CoreLoopSystem").set_process(false); chapter.set_process(false)
	for fixture in [["A",1,610,"record_store","xanni","sound_sampling"],["A",3,610,"handcraft_shop","mossner","ghostwriting"],["B",2,1080,"chess_stall","naonao","chess"]]:
		fresh(fixture[0],fixture[1],fixture[2]); gs.current_location=fixture[3]
		var id: String=fixture[5]
		check(not has_card(id),"Undiscovered first activity is hidden: "+id)
		var cash: int=gs.money; var minute: int=gs.current_minute
		check(not dialogue.accept_invitation(fixture[4]).is_empty(),"Real invitation accepted: "+id)
		check(has_card(id) and not modules.is_unlocked(id),"First invitation permits planning before play: "+id)
		check(gs.money==cash and gs.current_minute==minute and int(modules.state_for(id).plays)==0 and modules.pending_module_id().is_empty(),"Discovery creates no play, income or time charge: "+id)
		if fixture[0]=="A": check(gs.combine_flexible_time(),"A joins a real continuous slot")
		check(life.add_plan(id,minute,"walk").ok,"First activity can be written into the planner: "+id)
		check(not life.add_plan(id,minute,"walk").ok,"Discovery preserves overlapping-plan rejection")
		check(save.save_game() and save.load_game() and has_card(id),"Discovery and first plan survive real reload")
	fresh(); gs.current_location="record_store"
	dialogue.mark_invitation_heard("xanni",false)
	check(has_card("sound_sampling"),"Hearing an invitation is enough without accepting")
	gs.shared_state.knowledge_A[0].erase("module")
	check(has_card("sound_sampling"),"Legacy heard-invitation facts remain discoverable")
	fresh(); root.get_node("CoreLoopSystem").encounter("xanni")
	check(has_card("sound_sampling"),"A sourced network lead permits first planning")
	gs.switch_to_role("B",2,true)
	check(not has_card("sound_sampling"),"Another role's discovery cannot bypass chapter ownership")
	chapter.story().reveal_completed=true; gs.switch_to_role("B",5,true)
	check(not has_card("sound_sampling"),"Reveal does not copy A's private discovery")
	gs.switch_to_role("A",5,true)
	check(has_card("sound_sampling"),"Discovered leads remain known across days")
	fresh(); gs.shared_state.accepted_invitations={"A_1_sound_sampling":{"module":"sound_sampling"}}
	check(has_card("sound_sampling"),"Legacy accepted invitations need no new discovery flag")
	check(not has_card("translation") and not life.add_plan("unknown",610,"walk").ok,"Unavailable and unknown modules stay unplannable")
	for role in ["A","B"]:
		for choice in ["improvise","careful_menu"]: await cooking(role,choice)
	fresh("B",2,610); gs.current_location="night_market"; router.active_space_id="restaurant"
	check(modules.begin_session("cooking","external-regression"),"External cooking result has an actual owned session")
	check(modules.complete_external("cooking",{"interaction":{"context":modules.session_context()}},{"confirmations":{"shi_yongqi":"granted"}}) and gs.confirmed_residents.is_empty(),"External cooking result cannot inject legacy signatures either")
	# Existing signed saves are never revoked by the new rule.
	fresh("B",2,600); root.get_node("RelationshipSystem").set_confirmation("shi_yongqi","granted")
	check(save.save_game() and save.load_game() and gs.confirmed_residents.has("shi_yongqi") and people.page("shi_yongqi").facets.is_empty(),"Legacy signatures remain intact without retroactive facets")
	fresh(); gs.current_location="print_shop"; router.active_space_id="print_studio"
	var clock=load("res://scripts/ui/clock_repair.gd").new(); root.add_child(clock); await process_frame
	check(clock.submit_button.get_minimum_size().x<=clock.submit_button.size.x and clock.submit_button.get_rect().end.x<1340,"Clock duration and payment text fit beside the close button")
	var before: Dictionary=gs.to_save_data().duplicate(true)
	clock.submit_button.pressed.emit()
	check(gs.to_save_data()==before,"Wrong clock setting earns nothing and spends no time")
	clock.hour_value=clock.target_hour; clock.minute_value=clock.target_minute
	gs.shared_state.pending_module={"module_id":"sound_sampling","role":"A","day":1}
	before=gs.to_save_data().duplicate(true); clock.submit_button.pressed.emit()
	check(gs.to_save_data()==before,"Clock cannot settle while another activity owns the session")
	gs.shared_state.erase("pending_module")
	gs.current_minute=658; before=gs.to_save_data().duplicate(true)
	clock.submit_button.pressed.emit()
	check(gs.to_save_data()==before and clock.status_label.text.contains("空档"),"Clock rejects crossing a private commitment")
	gs.current_minute=1435; before=gs.to_save_data().duplicate(true); clock.submit_button.pressed.emit()
	check(gs.to_save_data()==before,"Clock cannot settle after closing or cross midnight")
	gs.current_minute=610; router.active_space_id=""; before=gs.to_save_data().duplicate(true); clock.submit_button.pressed.emit()
	check(gs.to_save_data()==before,"Clock cannot be submitted outside its real room")
	router.active_space_id="print_studio"; before=gs.to_save_data().duplicate(true)
	var original=save.get_script(); var failing:=GDScript.new()
	failing.source_code="extends \"res://scripts/core/save_manager.gd\"\nfunc save_or_report(_context := \"\") -> bool:\n\tGameState.shared_state[\"meta_checkpoint\"]={\"version\":1,\"timestamp\":-1}\n\treturn false\n"
	check(failing.reload()==OK,"Clock save-failure fixture compiles")
	save.set_script(failing); clock.submit_button.pressed.emit()
	check(gs.to_save_data()==before and not clock._is_paid(),"Failed clock save restores whole state including ledger, time, journal and checkpoint")
	check(clock.status_label.text.contains("撤销") and clock.status_label.text.contains("重试"),"Failed clock UI reports rollback and retry")
	save.set_script(original)
	var cash: int=gs.money; var body: float=life.value("body"); var engagement: float=life.value("engagement")
	clock.submit_button.pressed.emit()
	check(gs.current_minute==620 and gs.money==cash+20 and clock._is_paid(),"Clock retry settles ten minutes and twenty yuan once")
	check(life.value("body")<body and life.value("engagement")<engagement,"Clock work affects physical state and engagement")
	check(gs.money_ledger.size()==1 and int(gs.money_ledger[0].work_minutes)==10,"Clock income ledger records actual work duration")
	check(save.load_game() and gs.current_minute==620 and gs.money==cash+20 and clock._is_paid(),"Actual clock save restores time, cash and paid marker")
	before=gs.to_save_data().duplicate(true); clock.submit_button.pressed.emit()
	check(gs.to_save_data()==before,"Repeated clock confirmation does not settle again")
	gs.switch_to_role("B",2,true); before=gs.to_save_data().duplicate(true); clock.submit_button.pressed.emit()
	check(gs.to_save_data()==before,"Another character cannot collect the shared clock reward again")
	clock.queue_free()
	print("MINIGAME_SYSTEM_FIXES: ",checks," checks / ",failures," failures")
	quit(failures)
