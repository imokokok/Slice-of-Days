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
func home() -> String: return "residence" if GameState.current_role=="A" else "dorm"
func day_stamp() -> String:
	var extra := int(state().get("extra_nights",0)) if GameState.current_day==7 else 0
	return "DAY %02d"%GameState.current_day+(" +%d"%extra if extra>0 else "")
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
		result.append(["npc",str(contract(str(c.module)).get("callback","昨天留下的东西，我又看了一遍。"))])
		result.append(["player","你还记得那一段。" if GameState.current_role=="A" else "原来你也留意到了。我还想再理一理。"])
		result.append(["npc","记得。你留下的《"+str(material.title)+"》，我没有收进抽屉。"])
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
		state().callbacks[id]={"id":id,"npc":str(c.callback_npc),"module":module,"material_id":material_id,"day":mini(7,GameState.current_day+1),"acknowledged":false}
		GameEvents.publish("WorldCallbackScheduled",state().callbacks[id])
	_learn("return_"+id,"改天问问"+GuidanceSystem.source_name(str(c.callback_npc))+"，这次留下的东西后来怎么样了。",npc,str(c.callback_place))
	GameState.shared_state.get_or_add("world_artifacts",{}).get_or_add("loop_contributions",{})[id]={"source_material":material_id,"location":GameState.current_location,"created_by":role,"day":GameState.current_day,"module":module}
	GameEvents.publish("MinigameCompleted",{"module":module,"material_id":material_id})
	_check_recognition(npc); GameState.commit_active_role_state()
func participated(material_id: String) -> void:
	if not day_state().participated.has(material_id): day_state().participated.append(material_id)
func memory_return(material_id: String) -> void:
	var id := GameState.current_role+"_"+material_id
	if state().callbacks.has(id): return
	state().callbacks[id]={"id":id,"npc":"maya","module":"memory","material_id":material_id,"day":mini(7,GameState.current_day+1),"acknowledged":false}
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
		if types.has(str(item.get("kind",""))) or str(item.get("source","")).begins_with("module:"+str(row.get("module","missing"))): result.append(item)
	return result
func share_material(npc: String, material_id: String) -> Dictionary:
	if not share_candidates(npc).any(func(item: Dictionary) -> bool: return str(item.id)==material_id): return {"ok":false,"message":"这件材料现在不在身边。先在随身本里看看留下的东西。"}
	var snapshot := GameState.to_save_data().duplicate(true)
	var ids: Array=state().shared.get(npc,[]); ids.append(material_id); state().shared[npc]=ids
	RelationshipSystem.record_encounter(npc,"shared_"+material_id,["shared_material"])
	_check_recognition(npc)
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("分享暂时没能保存，可以再试一次"):
		GameState.load_save_data(snapshot); return {"ok":false,"message":"还没能记住这次分享，材料仍在。可以再试一次。"}
	GameEvents.publish("RelationshipChanged",{"npc":npc,"material_id":material_id,"meaningful":true})
	return {"ok":true,"message":str(catalog.people[npc].get("share_reply","这个细节，我刚才还没注意到。谢谢你让我看看。"))}
func _check_recognition(npc: String) -> void:
	if not catalog.people.has(npc) or GameState.confirmed_residents.has(npc): return
	var meaningful := false
	var module := str(catalog.people[npc].module)
	for c in state().callbacks.values():
		if str(c.npc)==npc and bool(c.acknowledged): meaningful=true
	for item in ResidencySystem.state().materials.values():
		if str(item.get("source","")).begins_with("module:"+module+":"): meaningful=true
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
func objectives() -> Array:
	var ds := day_state(); var day := GameState.current_day
	var participation: bool = not ds.participated.is_empty()
	var connected: bool = not ds.connected.is_empty()
	var titles: Array=catalog.days[str(day)]
	var rows: Array=[{"id":"must_%d_0"%day,"text":str(titles[0]),"done":connected and (day!=1 or bool(ResidencySystem.state().packet)),"action":"map","location":"print_shop" if day==1 and not ResidencySystem.state().packet else _contact_place()}, {"id":"must_%d_1"%day,"text":str(titles[1]),"done":participation,"action":"map","location":_action_place()}, {"id":"must_%d_2"%day,"text":str(titles[2]),"done":bool(ds.reviewed),"action":"evening","location":home()}]
	if day==7:
		rows[0].done=range(1,8).all(func(d: int) -> bool: return not ResidencySystem.state().get("free_pages",{}).get("day_%d"%d,[]).is_empty()); rows[0].action="portfolio"
		rows[1].done=not ResidencySystem.state().submitted.is_empty(); rows[1].action="final"; rows[1].location="print_shop"
	for row in rows: row["type"]="MustObjective"; row["fallback"]="回住处写下今天的经历，未完的事情明天仍可继续。"
	return rows
func _source() -> String:
	var fallback: Array=catalog.get("daily_contacts",["wu_wu"])
	return str(state().get("active_source",fallback[(GameState.current_day-1)%fallback.size()]))
func _contact_place() -> String:
	var npc := str(catalog.daily_contacts[GameState.current_day-1])
	return str(ScheduleSystem.activity_at(npc,GameState.current_day,GameState.current_minute).get("location","cafe"))
func _action_place() -> String: return str(catalog.people.get(_source(),{}).get("place","record_store"))
func active_guidance() -> Dictionary:
	for o in opportunities():
		if str(o.status)=="available" and int(o.expires_in)<=30: return {"id":o.id,"text":str(o.text),"context":"还有约%d分钟；错过后也可以再问问。"%int(o.expires_in),"action":"map","location":o.location,"priority":"critical"}
	var commitment := GameState.next_commitment()
	if not commitment.is_empty():
		var due := int(commitment.get("return_by",commitment.get("start",1440)))
		if due>=GameState.current_minute and due-GameState.current_minute<=30: return {"text":"记得回到"+TravelSystem.location_name(str(commitment.location)),"context":GuidanceSystem.time_text(due)+"的约定","location":commitment.location,"action":"map","priority":"critical"}
	if GameState.current_minute>=1260 and not bool(day_state().reviewed): return {"id":"evening","text":"回住处，把今天慢慢收好","context":"没有完成的事情可以留到明天。","location":home(),"action":"evening"}
	var rows := objectives()
	for i in rows.size():
		if bool(rows[i].done): continue
		var row: Dictionary=rows[i].duplicate(true)
		if i==0 and GameState.current_day!=7:
			if GameState.current_day==1 and not ResidencySystem.state().packet: row.text="去社区中心领取资料袋"; row.context="然后找一位镇上的人聊聊。"
			else: row.text="问问"+GuidanceSystem.source_name(str(catalog.daily_contacts[GameState.current_day-1]))+"今天的事"; row.context="也可以和路上遇见的其他居民聊聊。"
		elif i==1 and GameState.current_day!=7:
			var source := _source(); var lead: Dictionary=catalog.people.get(source,{})
			row.context=str(lead.get("lead","跟着听来的消息，或者记录自己的发现。"))
			row.text=(str(contract(str(lead.get("module",""))).get("action","看看这里能做什么")) if GameState.current_location==row.location else "去"+TravelSystem.location_name(str(row.location))+"看看")
			row.source=source
		else: row.context="整理今日材料，也可以明天再补作品页。"
		row["priority"]="must"; return row
	var pinned := GuidanceSystem.tracked_lead()
	if not pinned.is_empty(): return pinned.merged({"action":"map","priority":"personal"})
	for personal in state().personal:
		if not bool(personal.done): return personal.merged({"action":"personal","priority":"personal"})
	for o in opportunities():
		if str(o.status)=="available" and str(o.location)==GameState.current_location: return o.merged({"action":"map","priority":"opportunity"})
	return {}
func review_day(reflection: String) -> Dictionary:
	if GameState.current_location!=home(): return {"ok":false,"message":"先回自己的住处，材料可以留到晚上整理。"}
	if reflection.strip_edges().is_empty() and day_state().participated.is_empty(): return {"ok":false,"message":"今天还没留下东西。写下一件真正见到的小事，也可以去录一段声音。"}
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

func extend_application() -> Dictionary:
	if GameState.current_day!=7 or GameState.current_minute<1260 or GameState.current_location!=home() or not ResidencySystem.state().submitted.is_empty(): return {"ok":false,"message":"晚上回住处后，可以选择再留一晚补齐申请。"}
	var snapshot := GameState.to_save_data().duplicate(true)
	state()["extra_nights"]=int(state().get("extra_nights",0))+1
	var blocks: Array=GameState.schedule_for(GameState.current_role,7).get("blocks",[[480,1320]])
	GameState.current_minute=int(blocks[0][0]); GameState.clock_remainder=0
	day_state().reviewed=false
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("续住安排未保存，可以重试"):
		GameState.load_save_data(snapshot); return {"ok":false,"message":"续住安排没有保存，请重试。"}
	GuidanceSystem.notification.emit("HEARD","又留了一晚。七张作品页仍在，未完成的申请可以继续。")
	return {"ok":true,"message":"今天可以继续补齐申请。"}
func _process(delta: float) -> void:
	_elapsed+=delta
	if _elapsed<.5: return
	_elapsed=0; refresh()
func refresh() -> void:
	if refreshing or catalog.is_empty(): return
	refreshing=true
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
		if str(callback.material_id)==id: return true
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
	words.text="也许，先去"+TravelSystem.location_name(str(next.get("location",GameState.current_location)))+"看看。" if GameState.current_role=="A" else "还可以从"+TravelSystem.location_name(str(next.get("location",GameState.current_location)))+"开始……"
	words.add_theme_font_override("font",PaperLanguage.handwriting); words.add_theme_font_size_override("font_size",24)
	scene.add_child(words); words.modulate.a=0
	var fade := words.create_tween(); fade.tween_property(words,"modulate:a",1.0,.4); fade.tween_interval(5); fade.tween_property(words,"modulate:a",0.0,.6); fade.tween_callback(words.queue_free)
