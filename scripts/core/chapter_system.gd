extends Node
## Five-day outer loop; game mechanics remain in GameplayModuleSystem.
signal chapter_started(chapter: Dictionary)
signal chapter_completed(chapter: Dictionary)
signal journey_completed
const DAYS := [
 {"role":"A","module":"sound_sampling","location":"record_store","npc":"xanni","label":"在唱片店完成一段声音作品"},
 {"role":"B","module":"cooking","location":"night_market","npc":"shi_yongqi","label":"到饭店完成一道料理"},
 {"role":"A","module":"ghostwriting","location":"handcraft_shop","npc":"mossner","label":"在书信事务所完成并寄出拼贴信"},
 {"role":"B","module":"chess","location":"chess_stall","npc":"naonao","label":"在棋摊完成一局棋"},
 {"role":"A","module":"","location":"print_shop","npc":"","label":"去社区中心赴约"}]
const MAIN_OWNERS := {"sound_sampling":"A","cooking":"B","ghostwriting":"A","chess":"B"}
const MODULE_LOCATIONS := {"sound_sampling":"record_store","cooking":"night_market","ghostwriting":"handcraft_shop","chess":"chess_stall"}
const MAIN_NPCS := ["xanni", "shi_yongqi", "mossner", "naonao"]

var curfew_retry := 0.0

func _process(delta: float) -> void:
	curfew_retry=maxf(0,curfew_retry-delta)
	if GameState.current_minute<1439 or curfew_retry>0 or bool(GameState.shared_state.get("sleep_pending",false)) or bool(GameState.shared_state.get("game_complete",false)): return
	if SceneRouter.transitioning or UIStateSystem.current() not in ["EXPLORATION","RECORDER"]: return
	var scene := get_tree().current_scene
	if scene==null or scene.scene_file_path not in [SceneRouter.TOWN_DAY,SceneRouter.INTERACTIVE_SPACE]: return
	curfew_retry=.5
	_enforce_curfew.call_deferred()

func _enforce_curfew() -> void:
	if SceneRouter.transitioning or GameState.current_minute<1439 or bool(GameState.shared_state.get("sleep_pending",false)): return
	if UIStateSystem.current() not in ["EXPLORATION","RECORDER"] or bool(GameState.shared_state.get("game_complete",false)): return
	var home := "home_a" if GameState.current_role=="A" else "home_b"
	var scene := get_tree().current_scene
	var shell := scene.get_node_or_null("GameplayShell") if scene!=null else null
	if shell!=null and not shell.finish_recording_for_exit(): curfew_retry=5; return
	var snapshot := GameState.to_save_data()
	if GameState.current_location!=CoreLoopSystem.home() or SceneRouter.active_space_id!=home:
		GameState.current_minute=1439
		GameState.clock_remainder=0
		GameState.current_location=CoreLoopSystem.home()
		GameState.shared_state.erase("pending_commitment")
		GameState.commit_active_role_state()
		if not SaveManager.save_or_report("夜间回家保存失败"):
			GameState.load_save_data(snapshot); curfew_retry=5; return
		SceneRouter.enter_space(home)
		GuidanceSystem.notification.emit("NOTICE","23:59，收好东西回到住处。午夜即将翻到下一天。")
		return
	GameState.shared_state.erase("pending_commitment")
	if GameState.current_minute<1440: return
	# Midnight is a deadline, not an invented completion of missing work.
	day_state()["ended_at_midnight"]=true
	GameState.shared_state["midnight_rest"]=true
	GameState.shared_state["sleep_pending"]=true
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("午夜换日保存失败"):
		GameState.load_save_data(snapshot); curfew_retry=5; return
	SceneRouter.chapter_transition()

func story() -> Dictionary:
	if not GameState.shared_state.has("five_day_story"):
		GameState.shared_state["five_day_story"]={}
	var current: Dictionary=GameState.shared_state.five_day_story
	var defaults := {
		"days":{},
		"A_noticing":false,
		"B_noticing":false,
		"A_searching":false,
		"B_searching":false,
		"meeting_arranged":false,
		"reveal_completed":false,
		"observed_A":[],
		"observed_B":[],
		"cross_domain_practice":{"A":[],"B":[]},
		"identity_responses":{"A":{},"B":{}},
	}
	for key in defaults:
		if not current.has(key): current[key]=defaults[key].duplicate(true) if defaults[key] is Array or defaults[key] is Dictionary else defaults[key]
	return current
func day_state(day := -1) -> Dictionary:
	var key := str(GameState.current_day if day<0 else day)
	if not story().days.has(key): story().days[key]={"main_completed":false,"narrative_completed":false,"result":{}}
	return story().days[key]
func plan() -> Dictionary: return DAYS[clampi(GameState.current_day-1,0,4)].duplicate(true)

func start_new_game(_start_role := "A") -> void:
	GameState.begin_new_game("A")
	GameState.shared_state["journey_id"]=Crypto.new().generate_random_bytes(12).hex_encode()
	GameState.shared_state["character_switch_enabled"]=false
	GameState.shared_state["architecture_version"]=2
	GameState.shared_state["public_traces"]={}
	GameState.shared_state["npc_memory"]={}
	story()
	GameState.switch_to_role("A",1,true)
	GameState.current_location="bus_stop"
	GameState.shared_state["street_layout_version"]=6
	GameState.shared_state["street_positions"]={"A_1_main_street":150.0}
	GameState.commit_active_role_state()
	EchoSystem.begin_day()
	chapter_started.emit(current_chapter())
func chapter_sequence() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for i in DAYS.size(): result.append({"id":"day_%d"%(i+1),"day":i+1,"role":DAYS[i].role})
	return result
func current_chapter() -> Dictionary: return chapter_sequence()[clampi(GameState.current_day-1,0,4)]
func next_chapter() -> Dictionary: return {} if GameState.current_day>=5 else chapter_sequence()[GameState.current_day]
func align_saved_chapter() -> void: GameState.shared_state["chapter_index"]=GameState.current_day-1
func transition_context() -> Dictionary:
	return {"from":current_chapter(),"to":next_chapter(),"is_final":GameState.current_day==5,"transition_id":"end_day_%d"%GameState.current_day}
func module_available(module_id: String) -> bool:
	if module_id=="translation": return false
	if not MAIN_OWNERS.has(module_id) or bool(story().reveal_completed): return true
	return str(MAIN_OWNERS[module_id])==GameState.current_role

func module_perspective(module_id: String, role := "") -> String:
	var active_role := GameState.current_role if role.is_empty() else role
	if not MAIN_OWNERS.has(module_id): return "shared"
	return "home_domain" if str(MAIN_OWNERS[module_id])==active_role else "cross_domain"

func exchange_motivation(module_id: String) -> String:
	if not CharacterSystem.switch_unlocked() or module_perspective(module_id)!="cross_domain": return ""
	return str({"A":{"cooking":"原来她就在我常来的饭店工作。想亲手试试喜欢的味道，也照顾到客人的需要。","chess":"这一局有很多可能，我得选一步，再看看它会把局面带到哪里。"},"B":{"sound_sampling":"她介绍我走进唱片店。声音和作品仍由我自己完成，这次先试一次。","ghostwriting":"不必先想好成品。先剪下一片纸，看看接下来会出现什么。"}}.get(GameState.current_role,{}).get(module_id,""))

func register_cross_domain_result(module_id: String, result: Dictionary) -> void:
	result["craft_perspective"]=module_perspective(module_id)
	if not bool(story().reveal_completed) or str(result.craft_perspective)!="cross_domain": return
	var practice: Dictionary=story().cross_domain_practice
	var completed: Array=practice.get(GameState.current_role,[])
	if completed.has(module_id): return
	completed.append(module_id)
	practice[GameState.current_role]=completed
	story().cross_domain_practice=practice
	var names := {"sound_sampling":"声音制作","cooking":"料理","ghostwriting":"拼贴书信","chess":"棋局"}
	GameState.add_journal_entry({"kind":"cross_domain_practice","module_id":module_id,"text":"第一次用自己的方式完成了对方熟悉的%s。"%str(names.get(module_id,module_id))})

func next_cross_domain_activity(role := "") -> Dictionary:
	var active_role := GameState.current_role if role.is_empty() else role
	var completed: Array=story().cross_domain_practice.get(active_role,[])
	if not completed.is_empty(): return {}
	for module_id in ["sound_sampling","cooking","ghostwriting","chess"]:
		if str(MAIN_OWNERS.get(module_id,""))==active_role or completed.has(module_id): continue
		return {"module_id":module_id,"location":str(MODULE_LOCATIONS[module_id]),"perspective":"cross_domain"}
	return {}

func record_main_result(module_id: String, result: Dictionary) -> void:
	var context: Dictionary=result.get("context",{})
	if str(context.get("current_character",""))!=GameState.current_role or int(context.get("day",0))!=GameState.current_day: return
	register_cross_domain_result(module_id,result)
	if module_id==str(plan().module) and GameState.current_role==str(plan().role):
		day_state().main_completed=true
		day_state().result=result.duplicate(true)
	if MAIN_OWNERS.has(module_id):
		var id := "%s_%d_%s"%[GameState.current_role,GameState.current_day,module_id]
		var titles := {"sound_sampling":"唱片机旁的唱片","cooking":"饭店今天的做法","ghostwriting":"寄出信件的留底","chess":"棋摊的对局记录"}
		var traces: Dictionary=GameState.shared_state.get("public_traces",{})
		var discovered: Array=traces.get(id,{}).get("discovered_by",[GameState.current_role])
		traces[id]={"id":id,"owner":GameState.current_role,"day":GameState.current_day,"location":"print_shop","type":module_id,"payload":result.duplicate(true),"title":titles[module_id],"visibility":"public","discovered_by":discovered}
		GameState.shared_state["public_traces"]=traces
		remember_everyday_objects(module_id, traces[id])
	GuidanceSystem.notification.emit("DONE", "作品已保存，可以继续逛逛。" if module_id!="cooking" else "料理已经出餐，收入与小票已记好。")
	GameState.commit_active_role_state()
func traces_at(location: String) -> Array:
	var result: Array=[]
	for trace in GameState.shared_state.get("public_traces",{}).values():
		if str(trace.location)==location and int(trace.day)<=GameState.current_day: result.append(trace.duplicate(true))
	return result
func inspect_trace(id: String) -> Dictionary:
	var traces: Dictionary=GameState.shared_state.get("public_traces",{})
	if not traces.has(id): return {}
	var trace: Dictionary=traces[id]
	if str(trace.location)!=GameState.current_location or int(trace.day)>GameState.current_day: return {}
	if not trace.discovered_by.has(GameState.current_role):
		trace.discovered_by.append(GameState.current_role)
		GameState.add_journal_entry({"kind":"public_trace","trace_id":id,"text":"在小镇看到了："+str(trace.title)})
	observe_everyday_object(id)
	GameState.commit_active_role_state()
	return trace.duplicate(true)
func narrative_lines(npc: String) -> Array:
	if not bool(day_state().main_completed) or bool(day_state().narrative_completed) or npc!=str(plan().npc): return []
	match GameState.current_day:
		1: return [["npc","这段声音收好了。想听的时候，随时可以放来听。"]]
		2: return [["npc","今天的菜做好了，小票也收好了。忙完可以歇一会儿。"]]
		3:
			if bool(story().A_noticing):
				var found_a := _observation_title_text("A")
				return [["player","我在起居角翻到%s。它们能互相印证，但我不记得自己做过这些。"%found_a],["npc","你记得今天寄出的信，却不记得这些生活痕迹。那就先别替另一个人下结论。"],["player","我想知道是谁一直在同一张桌子旁生活。"]]
		4:
			if bool(story().B_noticing):
				var found_b := _observation_title_text("B")
				return [["player","%s都不是我留下的，可镇上的人一直把它们算在我身上。"%found_b],["npc","如果不是记错一件东西，而是一直把两个人记成了一个人呢？"],["npc","明天是你的轮休日，在社区中心见面吧。让留下这些东西的人自己说明。"]]
	return []
func on_conversation_completed(npc: String) -> void:
	if narrative_lines(npc).is_empty(): return
	match GameState.current_day:
		1,2: day_state().narrative_completed=true
		3:
			story().A_searching=true
			day_state().narrative_completed=true
			RelationshipSystem.advance_identity_stage(npc,"notices_inconsistency",{"kind":"ordinary_objects","objects":observation_summary("A").ids})
		4:
			story().B_searching=true
			RelationshipSystem.advance_identity_stage(npc,"suspects_two_people",{"kind":"ordinary_objects","objects":observation_summary("B").ids})
	GameState.commit_active_role_state()

func identity_response(npc: String, role := "") -> String:
	var active_role := GameState.current_role if role.is_empty() else role
	var by_role: Dictionary=story().identity_responses.get(active_role,{})
	return str(by_role.get(npc,{}).get("choice",""))

func identity_response_record(npc: String, role := "") -> Dictionary:
	var active_role := GameState.current_role if role.is_empty() else role
	return story().identity_responses.get(active_role,{}).get(npc,{}).duplicate(true)

func record_identity_response(npc: String, choice: String) -> bool:
	if npc not in MAIN_NPCS or choice not in ["clarify","defer"]: return false
	var responses: Dictionary=story().identity_responses
	var role_rows: Dictionary=responses.get(GameState.current_role,{})
	if role_rows.has(npc): return str(role_rows[npc].get("choice",""))==choice
	var record := {
		"choice":choice,
		"day":GameState.current_day,
		"role":GameState.current_role,
		"identity_stage":RelationshipSystem.identity_stage(npc),
		"observed_ids":observation_summary(GameState.current_role).ids.duplicate(),
	}
	role_rows[npc]=record
	responses[GameState.current_role]=role_rows
	story().identity_responses=responses
	var label := "当场说明这是另一个人的经历" if choice=="clarify" else "先保留疑问，等见面再说明"
	RelationshipSystem.add_flags(npc,["identity_response_"+choice,"identity_response_"+choice+"_by_"+GameState.current_role])
	if choice=="clarify":
		RelationshipSystem.advance_identity_stage(npc,"notices_inconsistency",{"kind":"player_clarification","role":GameState.current_role})
	GameState.record_choice("identity_response_"+npc,choice,label)
	GameState.add_journal_entry({"id":"identity_response_%s_%s"%[GameState.current_role,npc],"kind":"identity_response","text":label+"。","npc":npc,"choice":choice})
	GameState.commit_active_role_state()
	return true
func arrange_meeting() -> bool:
	if GameState.current_day!=4 or GameState.current_location!="chess_stall" or not bool(day_state().main_completed) or not bool(story().A_searching) or not bool(story().B_searching): return false
	story().meeting_arranged=true
	day_state().narrative_completed=true
	RelationshipSystem.advance_identity_stage(str(plan().npc),"suspects_two_people",{"kind":"meeting_arranged"})
	GameState.add_journal_entry({"kind":"appointment","text":"明天去社区中心，和留下那些记录的人见面。"})
	GameState.commit_active_role_state()
	return true
func meeting_available() -> bool: return GameState.current_day==5 and bool(story().meeting_arranged) and not bool(story().reveal_completed)
func finish_reveal() -> bool:
	if not meeting_available() or GameState.current_location!="print_shop": return false
	story().reveal_completed=true
	day_state().main_completed=true
	day_state().narrative_completed=true
	GameState.shared_state["character_switch_enabled"]=true
	RelationshipSystem.confirm_all_known_identities({"kind":"meeting_reveal"})
	for memory in GameState.shared_state.get("npc_memory",{}).values(): memory.memory_flags["identity_revealed"]=true
	GameState.commit_active_role_state()
	return true
func objectives() -> Array:
	var p := plan()
	var day := GameState.current_day
	var rows: Array=[{"id":"day_%d_main"%day,"text":p.label,"done":bool(day_state().main_completed),"location":p.location,"action":"map"}]
	if day==2 and not bool(day_state().main_completed):
		var order := EconomySystem.procurement_summary()
		rows[0].text=str(order.next)
		rows[0].location="produce_stall" if str(order.status)=="buy" else "night_market"
	if day in [3,4] and bool(day_state().main_completed): rows.append({"id":"day_%d_home"%day,"text":"回住处坐坐，桌上的东西可以慢慢翻看","done":bool(story().get(GameState.current_role+"_noticing",false)),"location":CoreLoopSystem.home(),"action":"map"})
	if day in [3,4] and bool(story().get(GameState.current_role+"_noticing",false)): rows.append({"id":"day_%d_talk"%day,"text":"和%s聊聊今天的经历"%str(ScheduleSystem.residents.get(str(p.npc),{}).get("display_name",p.npc)),"done":bool(day_state().narrative_completed),"location":p.location,"action":"map"})
	rows.append({"id":"day_%d_rest"%day,"text":"回家休息" if day<5 else "继续自由探索，或回家收好这段旅程","done":bool(GameState.shared_state.get("game_complete",false)),"location":CoreLoopSystem.home(),"action":"evening"})
	for row in rows: row["type"]="MustObjective"
	return rows
func can_end_day() -> Dictionary:
	if not bool(day_state().main_completed): return {"ok":false,"reason":"今天还有一件想做的事："+str(plan().label)}
	if GameState.current_day>=3 and not bool(day_state().narrative_completed): return {"ok":false,"reason":"还想在住处坐一会儿，看看桌上的东西，再聊聊今天的经历。"}
	return {"ok":true,"reason":""}
func advance_chapter(midnight := false) -> Dictionary:
	var check := can_end_day()
	if midnight and GameState.current_minute<1440: return {"ok":false,"reason":"还没有到午夜。"}
	if not midnight and not bool(check.ok): return check
	var current := current_chapter()
	EchoSystem.close_day()
	var completed: Array=GameState.shared_state.get("completed_chapters",[])
	if not completed.has(current.id): completed.append(current.id)
	GameState.shared_state["completed_chapters"]=completed
	chapter_completed.emit(current)
	if GameState.current_day==5:
		GameState.shared_state["game_complete"]=true
		GameState.commit_active_role_state()
		journey_completed.emit()
		return {"ok":true,"complete":true}
	var next := next_chapter()
	GameState.switch_to_role(str(next.role),int(next.day),true)
	align_saved_chapter()
	EchoSystem.begin_day()
	chapter_started.emit(next)
	return {"ok":true,"complete":false,"chapter":next}
func sleep_at_home() -> bool:
	if SceneRouter.active_space_id!=("home_a" if GameState.current_role=="A" else "home_b") or GameState.current_location!=CoreLoopSystem.home(): return false
	if bool(GameState.shared_state.get("sleep_pending",false)): return false
	var check := can_end_day()
	if not bool(check.ok):
		GameState.message_posted.emit(str(check.reason))
		return false
	var snapshot := GameState.to_save_data()
	GameState.shared_state["sleep_pending"]=true
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("入睡前保存失败"):
		GameState.load_save_data(snapshot)
		return false
	SceneRouter.chapter_transition()
	return true
func mark_transition_complete(id: String) -> void:
	var rows: Array=GameState.shared_state.get("completed_transitions",[])
	if not rows.has(id): rows.append(id)
	GameState.shared_state["completed_transitions"]=rows
func opening_id() -> String: return str(current_chapter().id)
func has_seen_opening(id := "") -> bool: return GameState.shared_state.get("seen_openings",[]).has(opening_id() if id.is_empty() else id)
func mark_opening_seen(id := "") -> void:
	var rows: Array=GameState.shared_state.get("seen_openings",[])
	var value := opening_id() if id.is_empty() else id
	if not rows.has(value): rows.append(value)
	GameState.shared_state["seen_openings"]=rows
func residency_audit(role: String) -> Dictionary:
	GameState.commit_active_role_state()
	var state: Dictionary=GameState.role_states.get(role,{})
	var audit := HouseholdSystem.application(role)
	audit.merge({"completed_events":state.get("completed_events",[]).size(),"journal_entries":state.get("journal_entries",[]).size(),"choices":state.get("choice_history",[]).size()})
	return audit
func journey_audit() -> Dictionary: return {"A":residency_audit("A"),"B":residency_audit("B"),"cross_domain_practice":story().cross_domain_practice.duplicate(true),"identity_responses":story().identity_responses.duplicate(true),"game_complete":bool(GameState.shared_state.get("game_complete",false))}

func ending_reflections() -> Dictionary:
	var works: Array=[]
	for trace in GameState.shared_state.get("public_traces",{}).values(): works.append(trace.duplicate(true))
	works.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		if int(a.get("day",0))==int(b.get("day",0)): return str(a.get("id",""))<str(b.get("id",""))
		return int(a.get("day",0))<int(b.get("day",0)))
	var recognitions: Array=[]
	for npc in MAIN_NPCS:
		var memory: Dictionary=GameState.shared_state.get("npc_memory",{}).get(npc,{})
		if memory.is_empty(): continue
		var response: Dictionary={}
		for role in ["A","B"]:
			var candidate := identity_response_record(npc,role)
			if not candidate.is_empty(): response=candidate; break
		recognitions.append({
			"npc":npc,
			"name":str(ScheduleSystem.residents.get(npc,{}).get("display_name",npc)),
			"stage":RelationshipSystem.identity_stage(npc),
			"response":response,
		})
	var practices: Array=[]
	var module_names := {"sound_sampling":"声音制作","cooking":"料理","ghostwriting":"拼贴书信","chess":"棋局"}
	for role in ["A","B"]:
		for module_id in story().cross_domain_practice.get(role,[]):
			practices.append({"role":role,"module_id":module_id,"name":str(module_names.get(module_id,module_id))})
	return {"works":works,"recognitions":recognitions,"practices":practices}

# Persistent ordinary objects. Sources are real deliveries/receipts, never clues
# awarded for entering a day. The same reading surface is used at the shared
# sitting-room shelf and the community exchange shelf.
func everyday_objects() -> Dictionary:
	if not GameState.shared_state.has("everyday_objects"):
		GameState.shared_state["everyday_objects"]={}
		# Existing five-day saves have authentic deliveries already. Reuse only
		# those sources, not the day number, to restore their ordinary objects.
		for old in GameState.shared_state.get("public_traces",{}).values():
			remember_everyday_objects(str(old.type),old)
	return GameState.shared_state.everyday_objects

func remember_everyday_objects(module: String, source: Dictionary) -> void:
	var item := source.duplicate(true)
	item["source_id"]=str(source.id)
	item["minute"]=GameState.current_minute
	item["places"]=["print_shop","residence","dorm"]
	item["view_kind"]={"sound_sampling":"record","cooking":"recipe","ghostwriting":"letter","chess":"book"}.get(module,"book")
	# These are publicly retained copies of delivered work. No new private item
	# or clue reward is granted when someone views them.
	everyday_objects()[str(item.id)]=item
	if module=="cooking":
		var receipts: Array=[]
		var private: Dictionary=GameState.artifacts if str(item.owner)==GameState.current_role else GameState.role_states.get(str(item.owner),{}).get("artifacts",{})
		for receipt in private.get("economy",{}).get("receipts",{}).values():
			if bool(receipt.get("reimbursed",false)) and int(receipt.get("day",0))==int(item.day):
				receipts.append(receipt.duplicate(true))
		if not receipts.is_empty():
			var receipt_item := item.duplicate(true)
			receipt_item.id=str(item.id)+"_receipts"
			receipt_item.source_id=str(receipts[0].id)
			receipt_item.title="夹在做法旁的采购小票"
			receipt_item.view_kind="receipt"
			receipt_item.payload={"receipts":receipts}
			everyday_objects()[str(receipt_item.id)]=receipt_item

func everyday_at(location: String) -> Array:
	var rows: Array=[]
	for item in everyday_objects().values():
		if int(item.day)<=GameState.current_day and location in item.places: rows.append(item.duplicate(true))
	return rows

func observe_everyday_object(id: String) -> Dictionary:
	if not everyday_objects().has(id): return {}
	var item: Dictionary=everyday_objects()[id]
	if GameState.current_location not in item.places or int(item.day)>GameState.current_day: return {}
	if not item.discovered_by.has(GameState.current_role): item.discovered_by.append(GameState.current_role)
	if GameState.current_day in [3,4] and str(item.owner)!=GameState.current_role and int(item.day)<GameState.current_day:
		var key := "observed_"+GameState.current_role
		var observed: Array=story().get_or_add(key,[])
		if not observed.has(id): observed.append(id)
		var summary := observation_summary(GameState.current_role)
		if summary.kinds.size()>=2:
			story()[GameState.current_role+"_noticing"]=true
			story()["day%d_%s_confirmed_other_person"%[GameState.current_day,GameState.current_role.to_lower()]]=true
	GameState.commit_active_role_state()
	GameState.state_changed.emit()
	return item.duplicate(true)

func observation_summary(role := "", through_day := -1) -> Dictionary:
	var active_role := GameState.current_role if role.is_empty() else role
	var last_day := GameState.current_day if through_day<0 else through_day
	var rows: Array=[]
	var kinds: Array[String]=[]
	var titles: Array[String]=[]
	for id in story().get("observed_"+active_role,[]):
		if not everyday_objects().has(id): continue
		var item: Dictionary=everyday_objects()[id]
		if str(item.get("owner",""))==active_role or int(item.get("day",0))>=last_day: continue
		rows.append(item.duplicate(true))
		var kind := str(item.get("view_kind",item.get("type","book")))
		if not kinds.has(kind): kinds.append(kind)
		var title := str(item.get("title","留下的物件"))
		if not titles.has(title): titles.append(title)
	return {"role":active_role,"ids":rows.map(func(row: Dictionary)->String:return str(row.id)),"kinds":kinds,"titles":titles,"objects":rows}

func _observation_title_text(role: String) -> String:
	var titles: Array=observation_summary(role,5).titles
	if titles.is_empty(): return "几件不属于自己的生活物件"
	var wrapped: Array[String]=[]
	for title in titles.slice(0,2): wrapped.append("《"+str(title)+"》")
	return "和".join(wrapped)

func meeting_lines() -> Array[String]:
	var a_text := _observation_title_text("A")
	var b_text := _observation_title_text("B")
	var aware_names: Array[String]=[]
	for npc in GameState.shared_state.get("npc_memory",{}).keys():
		var stage := RelationshipSystem.identity_stage(str(npc))
		if RelationshipSystem.IDENTITY_STAGES.find(stage)>=RelationshipSystem.IDENTITY_STAGES.find("notices_inconsistency"):
			aware_names.append(str(ScheduleSystem.residents.get(str(npc),{}).get("display_name",npc)))
	aware_names.sort()
	var witnesses := "镇上的人" if aware_names.is_empty() else "、".join(aware_names.slice(0,3))
	return [
		"你也来赴约了。我看到的%s，是你留下的吗？"%a_text,
		"是我。我也翻到%s。原来我们一直在同一座小镇生活。"%b_text,
		"%s已经察觉记录对不上，只是还不知道该怎样称呼这件事。"%witnesses,
		"把各自留下的东西放在一起，才看清：这是两个人的生活，不是一个人漏掉的记忆。",
		"等一下，你也住海风路17号？我一直住楼上。原来楼下的灯、放回信箱的通知，都是你留下的。",
		"我住楼下。我的饭店班次总与你错开。我还偷偷做过一些音乐，想带自己的东西去唱片店试试。",
		"我可以介绍你去。那家饭店原来是你工作的地方！我一直喜欢那里的味道，也想试试做菜，再和你下一局棋。",
		"借一下彼此熟悉的入口吧。作品要自己做，人也要自己认识。做完以后，我们再交换一点心得。",
	]
