extends Node
## Progression metadata lives alongside existing role saves. Materials, knowledge,
## economy and relationships remain owned by their existing domain services.
var catalog: Dictionary={}
var _elapsed := 0.0
var _seen := {}
var _session := ""
var refreshing := false
func _ready() -> void:
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/story/core_loop.json"))
	GameplayModuleSystem.module_completed.connect(_module_completed)
	GameState.session_restored.connect(func() -> void: _seen.clear(); _session="")
func state() -> Dictionary:
	var key := "core_loop_"+GameState.current_role
	if not GameState.shared_state.has(key): GameState.shared_state[key]={"version":1,"days":{},"callbacks":{},"introduced":{},"shared":{},"opportunities":{},"personal":[]}
	return GameState.shared_state[key]
func day_state() -> Dictionary:
	var days: Dictionary=state().days; var key := str(GameState.current_day)
	if not days.has(key): days[key]={"connected":[],"participated":[],"reviewed":false,"reflection":"","brief_seen":false}
	return days[key]
func home() -> String: return "residence"
func day_stamp() -> String: return "DAY %02d"%GameState.current_day

func contract(module: String) -> Dictionary: return catalog.get("modules",{}).get(module,{})
func _learn(id: String, text: String, npc: String, location: String, module := "", window: Dictionary={}) -> void:
	var key := "knowledge_"+GameState.current_role
	var facts: Array=GameState.shared_state.get(key,[])
	if facts.any(func(row: Dictionary) -> bool: return str(row.get("id",""))==id): return
	var fact := {"id":id,"text":text,"source_npc_id":npc,"subject_id":location,"predicate":"lead","confidence":1.0,"learned_day":GameState.current_day,"learned_time":GameState.current_minute,"module":module}
	fact.merge(window,true); facts.append(fact); GameState.shared_state[key]=facts
func encounter(npc: String) -> void:
	var row: Dictionary=catalog.get("people",{}).get(npc,{})
	if row.is_empty(): return
	if not day_state().connected.has(npc): day_state().connected.append(npc)
	state().introduced[npc]={"day":GameState.current_day,"minute":GameState.current_minute}
	state()["active_source"]=npc
	_learn("network_"+npc,str(row.lead),npc,str(row.place),str(row.module))
	# Callback dialogue was shown before this completed conversation. An early Esc
	# never reaches this method and cannot grant the exchange or recognition.
	for id in ready_callbacks(npc).slice(0,1):
		var callback: Dictionary=state().callbacks[id]
		callback.acknowledged=true
		RelationshipSystem.record_encounter(npc,"callback_"+id,["remembered_"+str(callback.module)])
		var next: Dictionary=contract(str(callback.module))
		_learn("after_"+id,str(next.get("next_text","")),npc,str(next.get("next_place","library")),str(next.get("next_module","archives")))
		_check_recognition(npc)
	for opportunity in opportunities():
		if str(opportunity.source)==npc and str(opportunity.status)=="missed": state().opportunities[opportunity.id]["retold"]=true
	GameEvents.publish("RelationshipChanged",{"npc":npc,"reason":"encounter"})
	GameState.commit_active_role_state(); GuidanceSystem.refresh()
func ready_callbacks(npc: String) -> Array:
	var result: Array=[]
	for id in state().callbacks:
		var c: Dictionary=state().callbacks[id]
		if str(c.npc)==npc and not bool(c.acknowledged) and int(c.day)<=GameState.current_day and ResidencySystem.state().materials.has(str(c.material_id)): result.append(id)
	return result
func dialogue_prefix(npc: String) -> Array:
	var result: Array=[]
	for id in ready_callbacks(npc).slice(0,1):
		var c: Dictionary=state().callbacks[id]
		var material: Dictionary=ResidencySystem.state().materials.get(str(c.material_id),{})
		if material.is_empty(): continue
		if bool(c.get("shared",false)):
			result.append(["npc",str(contract(str(c.module)).get("callback","昨天留下的东西，我又想了一遍。"))])
			result.append(["player","你还记得那一段。" if GameState.current_role=="A" else "原来你也留意到了。我还想再理一理。"])
			result.append(["npc","记得。你给我看过的《"+str(material.title)+"》，那个细节还在。"])
		else:
			var origin := str(c.get("origin_npc",contract(str(c.module)).get("npc","")))
			result.append(["npc",GuidanceSystem.source_name(origin)+"提起你们做的《"+str(material.title)+"》。你要是带着，也让我看看吧。"])
			result.append(["player","我把它留在随身本里了。"])
			result.append(["npc","愿意的话，拿给我看看。也想听你自己说。"])
	for opportunity in opportunities():
		if str(opportunity.source)==npc and str(opportunity.status)=="missed" and not bool(state().opportunities[opportunity.id].get("retold",false)):
			result.append(["npc",str(opportunity.retell)])
			break
	return result
func _module_completed(role: String, module: String, _outcome: Dictionary) -> void:
	if role!=GameState.current_role: return
	var c := contract(module)
	if c.is_empty(): return
	var index := maxi(0,GameplayModuleSystem.state_for(module).get("outcomes",[]).size()-1)
	var material_id := "module_%s_%d" % [module,index]
	participated(material_id)
	var npc := str(c.npc)
	var material: Dictionary=ResidencySystem.state().materials.get(material_id,{})
	material["related_npc"]=npc
	RelationshipSystem.record_encounter(npc,"made_"+material_id,["participated_"+module])
	var id := GameState.current_role+"_"+material_id
	if not state().callbacks.has(id):
		state().callbacks[id]={"id":id,"npc":str(c.callback_npc),"origin_npc":npc,"module":module,"material_id":material_id,"day":mini(5,GameState.current_day+1),"acknowledged":false,"shared":false,"returned":false}
		GameEvents.publish("WorldCallbackScheduled",state().callbacks[id])
	_learn("return_"+id,"把《"+str(material.get("title","这次的作品"))+"》带给"+GuidanceSystem.source_name(str(c.callback_npc))+"看看。",npc,str(c.callback_place),"",{"callback_id":id,"callback_stage":"share"})
	GameState.shared_state.get_or_add("world_artifacts",{}).get_or_add("loop_contributions",{})[id]={"source_material":material_id,"location":GameState.current_location,"created_by":role,"day":GameState.current_day,"module":module}
	GameEvents.publish("MinigameCompleted",{"module":module,"material_id":material_id})
	_check_recognition(npc); GameState.commit_active_role_state()
func participated(material_id: String) -> void:
	if not day_state().participated.has(material_id): day_state().participated.append(material_id)
func memory_return(material_id: String) -> void:
	var id := GameState.current_role+"_"+material_id
	if state().callbacks.has(id): return
	state().callbacks[id]={"id":id,"npc":"maya","module":"memory","material_id":material_id,"day":mini(5,GameState.current_day+1),"acknowledged":false}
	GameEvents.publish("WorldCallbackScheduled",state().callbacks[id])
func open_evening() -> void:
	if not get_tree().get_nodes_in_group("evening_review").is_empty(): return
	var scene := get_tree().current_scene
	if scene!=null: scene.add_child(preload("res://scripts/ui/components/evening_review.gd").new())
func pin_personal(text: String, location := "") -> void:
	if text.strip_edges().is_empty(): return
	state().personal.append({"id":"personal_"+str(Time.get_ticks_usec()),"text":text.strip_edges(),"location":location,"done":false})
	GameState.commit_active_role_state(); SaveManager.save_or_report("私人计划保存失败"); GuidanceSystem.updated.emit()
func share_candidates(npc: String) -> Array:
	var row: Dictionary=catalog.get("people",{}).get(npc,{})
	if row.is_empty(): return []
	var types: Array=row.get("likes",[])
	var result: Array=[]
	for id in ResidencySystem.state().materials:
		var item: Dictionary=ResidencySystem.state().materials[id]
		if not bool(item.get("can_show_to_npc",true)) or str(item.get("source",""))=="walk" or state().shared.get(npc,[]).has(id): continue
		if not callback_for_material(npc,str(id)).is_empty() or types.has(str(item.get("kind",""))) or str(item.get("source","")).begins_with("module:"+str(row.get("module","missing"))): result.append(item)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return not callback_for_material(npc,str(a.id)).is_empty() and callback_for_material(npc,str(b.id)).is_empty())
	return result
func share_material(npc: String, material_id: String) -> Dictionary:
	if not share_candidates(npc).any(func(item: Dictionary) -> bool: return str(item.id)==material_id): return {"ok":false,"message":"这件材料现在不在身边。先在随身本里看看留下的东西。"}
	var snapshot := GameState.to_save_data().duplicate(true)
	var ids: Array=state().shared.get(npc,[]); ids.append(material_id); state().shared[npc]=ids
	RelationshipSystem.record_encounter(npc,"shared_"+material_id,["shared_material"])
	var callback := callback_for_material(npc,material_id)
	var response := str(catalog.people[npc].get("share_reply","这个细节，我刚才还没注意到。谢谢你让我看看。"))
	if not callback.is_empty(): response=_exchange_callback(callback,npc)
	_check_recognition(npc)
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("分享暂时没能保存，可以再试一次"):
		GameState.load_save_data(snapshot); return {"ok":false,"message":"还没能记住这次分享，材料仍在。可以再试一次。"}
	GameEvents.publish("RelationshipChanged",{"npc":npc,"material_id":material_id,"meaningful":true})
	return {"ok":true,"message":response}

func callback_for_material(npc: String, material_id: String) -> Dictionary:
	for c in state().callbacks.values():
		if int(c.day)>GameState.current_day: continue
		if str(c.npc)==npc and str(c.material_id)==material_id and not bool(c.get("shared",false)): return c
		var origin := str(c.get("origin_npc",contract(str(c.module)).get("npc","")))
		if origin==npc and str(c.get("reply_material",""))==material_id and not bool(c.get("returned",false)): return c
	return {}

func _exchange_callback(c: Dictionary, npc: String) -> String:
	var detail := contract(str(c.module))
	var origin := str(c.get("origin_npc",detail.get("npc","")))
	if str(c.npc)==npc and not bool(c.get("shared",false)):
		var reply := str(detail.get("share_reply",detail.get("callback","我会记住这次一起留下的东西。")))
		var reply_id := "reply_"+str(c.id)
		c.shared=true; c.reply_material=reply_id
		ResidencySystem._add(reply_id,"note",GuidanceSystem.source_name(npc)+"留下的几句话",{"text":reply,"source":"resident_reply","source_material":str(c.material_id),"related_npc":npc,"callback_id":str(c.id),"can_edit":false})
		_learn("reply_return_"+str(c.id),"把"+GuidanceSystem.source_name(npc)+"的回应带给"+GuidanceSystem.source_name(origin),npc,npc_place(origin,str(detail.get("next_place",""))),"",{"callback_id":str(c.id),"callback_stage":"return"})
		RelationshipSystem.record_encounter(npc,"exchange_"+str(c.id),["remembered_"+str(c.module)])
		return reply+"\n我写了几句。你下次碰见"+GuidanceSystem.source_name(origin)+"，也给对方看看吧。"
	c.returned=true
	RelationshipSystem.record_encounter(npc,"return_"+str(c.id),["remembered_"+str(c.module)])
	return str(detail.get("return_reply","原来那件小事还留在对方心里。谢谢你特意带回来。"))

func npc_place(npc: String, fallback := "") -> String:
	if not ResidentProfileSystem.is_core(npc): return fallback
	# Ask the actual population, including today's activity collaborator.
	for location in ResidencySystem.locations:
		if DialogueSystem.people_at(str(location)).has(npc): return str(location)
	return fallback

func next_meeting(npc: String) -> Dictionary:
	var candidates: Array=[]
	for activity in ScheduleSystem.residents.get(npc,{}).get("schedule",[]):
		for day in activity.get("days",[]):
			var moment := int(day)*1440+int(activity.start)
			if moment>GameState.current_day*1440+GameState.current_minute: candidates.append({"moment":moment,"day":int(day),"minute":int(activity.start),"location":str(activity.location)})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.moment)<int(b.moment))
	return candidates[0] if not candidates.is_empty() else {}

func connection_steps() -> Array:
	var result: Array=[]
	for c in state().callbacks.values():
		if int(c.day)>GameState.current_day or bool(c.get("returned",false)): continue
		var returning := bool(c.get("shared",false))
		var detail := contract(str(c.module))
		var origin := str(c.get("origin_npc",detail.get("npc","")))
		var npc := origin if returning else str(c.npc)
		var material_id := str(c.get("reply_material","")) if returning else str(c.material_id)
		var item: Dictionary=ResidencySystem.state().materials.get(material_id,{})
		if npc.is_empty() or item.is_empty(): continue
		var location := npc_place(npc)
		var available := not location.is_empty()
		var meeting := next_meeting(npc) if not available else {}
		if not available: location=str(meeting.get("location",detail.get("callback_place","")))
		if not ResidencySystem.locations.has(location): continue
		var title := str(item.get("title","这次留下的东西"))
		var context := str(detail.get("relationship","你们做过的事，在另一个人那里有了下文。"))
		var text := "把《"+title+"》带给"+GuidanceSystem.source_name(npc)
		if not available:
			context=("Day %02d · %s 后可以再去。"%[int(meeting.day),GuidanceSystem.time_text(int(meeting.minute))]) if not meeting.is_empty() else "现在没碰见对方。先把材料留好，之后再来看看。"
		result.append({"id":"exchange_"+str(c.id)+( "_return" if returning else "_share"),"text":text,"context":context,"source":str(c.npc) if returning else origin,"npc":npc,"location":location,"action":"map","priority":"connection","material_id":material_id,"returning":returning,"available":available})
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a.location)==GameState.current_location and str(b.location)!=GameState.current_location)
	return result

func lead_available(fact: Dictionary) -> bool:
	var id := str(fact.get("id",""))
	var callback_id := str(fact.get("callback_id",id.trim_prefix("return_") if id.begins_with("return_") else ""))
	if not callback_id.is_empty() and state().callbacks.has(callback_id):
		var c: Dictionary=state().callbacks[callback_id]
		if int(c.day)>GameState.current_day: return false
		return not bool(c.get("returned",false)) if str(fact.get("callback_stage","share"))=="return" else not bool(c.get("shared",false))
	var module := str(fact.get("module",""))
	if not module.is_empty() and not ChapterSystem.module_available(module): return false
	if not module.is_empty() and not GameplayModuleSystem.state_for(module).get("outcomes",[]).is_empty(): return false
	return true
func _check_recognition(npc: String) -> void:
	if not catalog.people.has(npc) or GameState.confirmed_residents.has(npc): return
	var meaningful := false
	var module := str(catalog.people[npc].module)
	for c in state().callbacks.values():
		if str(c.npc)==npc and bool(c.acknowledged): meaningful=true
	for item in ResidencySystem.state().materials.values():
		if str(item.get("source","")).begins_with("module:"+module+":"): meaningful=true
	# A different role need not repeat the resident's entire main minigame.
	# Two personally held, relevant kinds of material shared in conversation
	# also establish a relationship. Re-showing one item cannot advance this.
	var kinds: Array[String]=[]
	for id in state().shared.get(npc,[]):
		var item: Dictionary=ResidencySystem.state().materials.get(str(id),{})
		var kind := str(item.get("kind",""))
		if not kind.is_empty() and not kinds.has(kind): kinds.append(kind)
	if kinds.size()>=2: meaningful=true
	if state().introduced.has(npc) and not state().shared.get(npc,[]).is_empty() and (meaningful or RelationshipSystem.has_flag(npc,"participated_"+module)):
		RelationshipSystem.set_confirmation(npc,"granted")
func opportunities() -> Array:
	var result: Array=[]
	for source in catalog.get("opportunities",[]):
		var row: Dictionary=source.duplicate(true)
		if not state().introduced.has(str(row.source)): continue
		var absolute := GameState.current_day*1440+GameState.current_minute
		var start := int(row.day)*1440+int(row.start); var end := int(row.day)*1440+int(row.end)
		var history: Dictionary=state().opportunities.get(row.id,{"warned":false,"retold":false})
		row.status="upcoming" if absolute<start else "available" if absolute<=end else "missed"
		history.status=row.status; state().opportunities[row.id]=history
		row["expires_in"]=end-absolute
		result.append(row)
	return result
func objectives() -> Array: return ChapterSystem.objectives()

func _source() -> String:
	var fallback: Array=catalog.get("daily_contacts",["wu_wu"])
	return str(state().get("active_source",fallback[(GameState.current_day-1)%fallback.size()]))
func _contact_place() -> String:
	var npc := str(catalog.daily_contacts[GameState.current_day-1])
	return str(ScheduleSystem.activity_at(npc,GameState.current_day,GameState.current_minute).get("location","cafe"))
func _action_place() -> String: return str(catalog.people.get(_source(),{}).get("place","record_store"))
func active_guidance() -> Dictionary:
	return GuidanceSystem.possibility()

func review_day(reflection: String) -> Dictionary:
	if GameState.current_location!=home(): return {"ok":false,"message":"先回自己的住处，材料可以留到晚上整理。"}
	if reflection.strip_edges().is_empty() and not bool(ChapterSystem.day_state().main_completed): return {"ok":false,"message":"今天还没留下东西。写下一件真正见到的小事，也可以去录一段声音。"}
	var snapshot := GameState.to_save_data().duplicate(true)
	if not reflection.strip_edges().is_empty():
		var id := "reflection_%s_%d" % [GameState.current_role,GameState.current_day]
		ResidencySystem._add(id,"note","Day %02d · 回房后的几句话"%GameState.current_day,{"text":reflection,"source":"player","can_edit":true})
		ResidencySystem.state().materials[id].text=reflection
		day_state().reflection=reflection; participated(id)
	day_state().reviewed=true
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("整理记录没有保存成功，可以重试"):
		GameState.load_save_data(snapshot); return {"ok":false,"message":"材料仍在，请再试一次保存。"}
	GuidanceSystem.refresh(); return {"ok":true,"message":"材料已经收好。作品页可以现在做，也可以之后补。"}
func reference_entries() -> Array:
	var result: Array=[]
	for item in ResidencySystem.state().materials.values():
		if str(item.kind)=="official": continue
		result.append({"id":item.id,"text":"Day %02d · %s · %s"%[int(item.day),TravelSystem.location_name(str(item.get("location",""))),str(item.title)]})
	return result

func extend_application() -> Dictionary: return {"ok":false,"message":"五日旅程没有申请延期条件。"}

func _process(delta: float) -> void:
	_elapsed+=delta
	if _elapsed<.5: return
	_elapsed=0; refresh()
func refresh() -> void:
	if refreshing or catalog.is_empty(): return
	refreshing=true
	# Upgrade existing completed shares without losing or replaying their history.
	for c in state().callbacks.values():
		if int(c.day)<=GameState.current_day and not bool(c.get("shared",false)) and state().shared.get(str(c.npc),[]).has(str(c.material_id)):
			_exchange_callback(c,str(c.npc))
	var key := GameState.current_role+str(GameState.current_day)
	if key!=_session: _session=key; _seen.clear()
	for item in ResidencySystem.state().materials.values():
		var id := str(item.id)
		if _seen.has(id): continue
		_seen[id]=true
		if int(item.get("day",0))==GameState.current_day and (str(item.kind) in ["photo","sound","letter"] or str(item.get("source","")).begins_with("module:") or str(item.get("source",""))=="player"):
			participated(id)
	for o in opportunities():
		var history: Dictionary=state().opportunities[o.id]
		if str(o.status)=="available" and int(o.expires_in)<=30 and not bool(history.warned):
			history.warned=true; GuidanceSystem.notification.emit("HEARD",str(o.text)+"，时间快到了。")
	refreshing=false

func material_in_use(id: String) -> bool:
	if bool(ResidencySystem.state().materials.get(id,{}).get("protected",false)): return true
	for shared in state().shared.values():
		if shared.has(id): return true
	for callback in state().callbacks.values():
		if str(callback.material_id)==id or str(callback.get("reply_material",""))==id: return true
	for refs in ResidencySystem.state().get("final_references",{}).values():
		if refs.has(id): return true
	return false

func direction_thought() -> void:
	if not bool(UIStateSystem.policy().notify): return
	var next := active_guidance()
	var scene := get_tree().current_scene
	if next.is_empty() or scene==null: return
	var words := preload("res://scripts/meta/flowing_thought.gd").new()
	words.position=Vector2(680,230); words.size=Vector2(450,160); words.mouse_filter=Control.MOUSE_FILTER_IGNORE
	words.text=LocalizationSystem.text("也许，先去"+TravelSystem.location_name(str(next.get("location",GameState.current_location)))+"看看。" if GameState.current_role=="A" else "还可以从"+TravelSystem.location_name(str(next.get("location",GameState.current_location)))+"开始……")
	words.add_theme_font_override("font",PaperLanguage.handwriting); words.add_theme_font_size_override("font_size",24)
	scene.add_child(words); words.modulate.a=0
	var fade := words.create_tween(); fade.tween_property(words,"modulate:a",1.0,.4); fade.tween_interval(5); fade.tween_property(words,"modulate:a",0.0,.6); fade.tween_callback(words.queue_free)
