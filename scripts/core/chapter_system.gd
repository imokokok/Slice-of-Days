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

func story() -> Dictionary:
	if not GameState.shared_state.has("five_day_story"):
		GameState.shared_state["five_day_story"]={"days":{},"A_noticing":false,"B_noticing":false,"A_searching":false,"B_searching":false,"meeting_arranged":false,"reveal_completed":false}
	return GameState.shared_state.five_day_story
func day_state(day := -1) -> Dictionary:
	var key := str(GameState.current_day if day<0 else day)
	if not story().days.has(key): story().days[key]={"main_completed":false,"narrative_completed":false,"result":{}}
	return story().days[key]
func plan() -> Dictionary: return DAYS[clampi(GameState.current_day-1,0,4)].duplicate(true)

func start_new_game(_start_role := "A") -> void:
	GameState.begin_new_game("A")
	GameState.shared_state["journey_id"]=Crypto.new().generate_random_bytes(12).hex_encode()
	GameState.shared_state["character_switch_enabled"]=false
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

func record_main_result(module_id: String, result: Dictionary) -> void:
	var context: Dictionary=result.get("context",{})
	if str(context.get("current_character",""))!=GameState.current_role or int(context.get("day",0))!=GameState.current_day: return
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
		GameState.add_journal_entry({"kind":"public_trace","trace_id":id,"text":"在公共柜看到了："+str(trace.title)})
	observe_everyday_object(id)
	GameState.commit_active_role_state()
	return trace.duplicate(true)
func narrative_lines(npc: String) -> Array:
	if not bool(day_state().main_completed) or npc!=str(plan().npc): return []
	match GameState.current_day:
		1: return [["npc","这段声音收好了。想听的时候，随时可以放来听。"]]
		2: return [["npc","今天的菜做好了，小票也收好了。忙完可以歇一会儿。"]]
		3:
			if bool(story().A_noticing): return [["player","桌上的做法和小票对得上，但我不记得自己做过这些。想知道是谁用过那张桌子。"],["npc","不急。今天先把手边的信收好。"]]
		4:
			if bool(story().B_noticing): return [["player","那份声音作品不是我的，可有人把它认成了我留下的。"],["npc","正好，也有人问起这些记录。要不要明天在社区中心见面，把各自的事情说清楚？"]]
	return []
func on_conversation_completed(npc: String) -> void:
	if narrative_lines(npc).is_empty(): return
	match GameState.current_day:
		1,2: day_state().narrative_completed=true
		3:
			story().A_searching=true
			day_state().narrative_completed=true
		4: story().B_searching=true
	GameState.commit_active_role_state()
func arrange_meeting() -> bool:
	if GameState.current_day!=4 or GameState.current_location!="chess_stall" or not bool(day_state().main_completed) or not bool(story().A_searching) or not bool(story().B_searching): return false
	story().meeting_arranged=true
	day_state().narrative_completed=true
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
	for memory in GameState.shared_state.get("npc_memory",{}).values():
		memory.perceived_same_person=false
		memory.memory_flags["identity_revealed"]=true
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
func advance_chapter() -> Dictionary:
	var check := can_end_day()
	if not bool(check.ok): return check
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
	return {"role":role,"passed":bool(story().reveal_completed),"completed_events":state.get("completed_events",[]).size(),"journal_entries":state.get("journal_entries",[]).size(),"choices":state.get("choice_history",[]).size(),"confirmed":state.get("confirmed_residents",[]).size(),"required":0}
func journey_audit() -> Dictionary: return {"A":residency_audit("A"),"B":residency_audit("B"),"game_complete":bool(GameState.shared_state.get("game_complete",false))}

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
		if observed.size()>=2:
			story()[GameState.current_role+"_noticing"]=true
			story()["day%d_%s_confirmed_other_person"%[GameState.current_day,GameState.current_role.to_lower()]]=true
	GameState.commit_active_role_state()
	GameState.state_changed.emit()
	return item.duplicate(true)
