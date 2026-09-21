extends Node
## Guidance projections reuse residency, knowledge and relationship records.
signal updated
signal notification(kind: String, text: String)
var _elapsed := 0.0
var _session_key := ""
var _previous: Dictionary = {}
var idle_seconds := 0.0
var progress_key := ""
var reminded := ""
var help_level := 0
var feedback_queue: Array=[]
var feedback_age := 0.0
var last_direction := ""

func time_text(minute: int) -> String:
	return "%02d:%02d" % [minute/60,minute%60]

func organized(day: int) -> bool:
	return bool(CoreLoopSystem.state().days.get(str(day),{}).get("reviewed",false)) or ResidencySystem.night_organized(day)

func today_rows() -> Array:
	return CoreLoopSystem.objectives()

func next_step() -> Dictionary:
	return CoreLoopSystem.active_guidance()

func opportunities(location := "") -> Array:
	var rows: Array = []
	for opportunity in CoreLoopSystem.opportunities():
		if int(opportunity.day)!=GameState.current_day or str(opportunity.status)=="missed": continue
		if not location.is_empty() and str(opportunity.location)!=location: continue
		rows.append(opportunity)
	for appointment in GameState.appointments:
		if int(appointment.get("day",0))!=GameState.current_day or str(appointment.get("status","scheduled")) not in ["scheduled","active"]: continue
		if not location.is_empty() and str(appointment.get("location",""))!=location: continue
		rows.append({"text":time_text(int(appointment.start))+" "+str(appointment.get("label","约定")),"location":str(appointment.get("location","")),"start":int(appointment.start),"end":int(appointment.end)})
	for fact in KnowledgeSystem.facts():
		if str(fact.get("status",""))=="Outdated" or str(fact.get("text",""))=="": continue
		if not location.is_empty() and str(fact.get("subject_id",""))!=location: continue
		rows.append({"text":str(fact.text),"location":str(fact.get("subject_id","")),"source":str(fact.get("source_npc_id",""))})
	return rows

func known_at(location: String) -> String:
	var lines: Array[String] = []
	var next := next_step()
	if str(next.get("location",""))==location: lines.append(str(next.text))
	for entry in EconomySystem.knowledge_for(location):
		if not lines.has(str(entry)): lines.append(str(entry))
	for entry in opportunities(location):
		if not lines.has(str(entry.text)): lines.append(str(entry.text))
	return "\n".join(lines) if not lines.is_empty() else "可以沿街看看；新的消息要问问当地人。"

func preview(minutes: int, destination := "") -> String:
	var finish := GameState.current_minute+minutes
	var lines: Array[String] = ["预计 "+time_text(finish)+" 结束" if destination.is_empty() else "预计 "+time_text(finish)+" 到达"]
	for entry in opportunities():
		if not entry.has("start"): continue
		var walk := maxi(0,WorldGraph.walk_minutes(GameState.current_location if destination.is_empty() else destination,str(entry.location)))
		if finish+walk>int(entry.start): lines.append("可能错过："+str(entry.text))
	if not destination.is_empty():
		var hours: Array=ResidencySystem.locations.get(destination,{}).get("hours",[])
		if destination=="print_shop": hours=[[540,1080]]
		if not hours.is_empty() and not hours.any(func(h: Array)->bool:return finish>=int(h[0]) and finish<int(h[1])): lines.append("到达时柜台休息")
	return "\n".join(lines)

func idle_tick(delta: float, _walking: bool) -> void:
	var key := JSON.stringify(CoreLoopSystem.day_state())+str(ResidencySystem.state().materials.size())+str(KnowledgeSystem.facts().size())+GameState.current_location
	if key!=progress_key: idle_seconds=0; progress_key=key; reminded=""
	else: idle_seconds+=delta
	var level := mini(4,int(idle_seconds/45.0))
	if help_level!=level: help_level=level; updated.emit()
	if level>=4 and reminded!=key:
		var next := next_step()
		if not next.is_empty(): CoreLoopSystem.direction_thought()
		reminded=key

func state() -> Dictionary:
	var key := "guidance_"+GameState.current_role
	if not GameState.shared_state.has(key):
		GameState.shared_state[key]={"tracked_lead":"", "personal":"", "seen":{}}
	return GameState.shared_state[key]

# Public records are projections, not a second quest/material inventory.
func must_objectives() -> Array:
	return CoreLoopSystem.objectives()

func leads() -> Array:
	var result: Array=[]
	var connections := CoreLoopSystem.connection_steps()
	for fact in KnowledgeSystem.facts():
		var location := str(fact.get("location",fact.get("subject_id","")))
		if not ResidencySystem.locations.has(location): continue
		if not CoreLoopSystem.lead_available(fact): continue
		var row := {"type":"Lead","id":str(fact.get("id","")),"text":str(fact.get("text","")),"location":location,"source":str(fact.get("source_npc_id","")),"available":str(fact.get("status",""))!="Outdated"}
		var callback_id := str(fact.get("callback_id",row.id.trim_prefix("return_") if row.id.begins_with("return_") else ""))
		if not callback_id.is_empty():
			for connection in connections:
				if str(connection.id)=="exchange_"+callback_id+("_return" if str(fact.get("callback_stage","share"))=="return" else "_share"):
					row.location=connection.location; row.available=connection.available; row.text=connection.text; row.context=connection.context
		result.append(row)
	for opportunity in CoreLoopSystem.opportunities():
		var row: Dictionary=opportunity.duplicate(true)
		row["available"]=str(row.status)!="missed"
		row["type"]="Lead"
		row.text="Day %02d · %s–%s\n%s%s"%[int(row.day),time_text(int(row.start)),time_text(int(row.end)),str(row.text),"\n已经错过，可以再向对方打听。" if not row.available else ""]
		result.append(row)
	return result

func tracked_lead() -> Dictionary:
	for lead in leads():
		if str(lead.id)==str(state().tracked_lead) and bool(lead.available): return lead
	return {}

func track(id: String) -> void:
	state().tracked_lead=id
	SaveManager.save_or_report("线索追踪保存失败")
	updated.emit()

func source_name(id: String) -> String:
	if id=="grocery": return "杂货店老板"
	return str(ScheduleSystem.residents.get(id,{}).get("display_name",id if not id.is_empty() else "沿途发现"))

func hear(id: String, text: String, source: String, location: String) -> void:
	KnowledgeSystem.learn({"id":id,"text":text,"source_npc_id":source,"subject_id":location,"predicate":"lead","confidence":1.0})
	refresh()

func _process(delta: float) -> void:
	feedback_age+=delta
	_elapsed+=delta
	if _elapsed<0.5: return
	_elapsed=0
	refresh()

func refresh() -> void:
	if GameState.current_role.is_empty(): return
	var snapshot: Dictionary={}
	for objective in must_objectives():
		if bool(objective.done): snapshot[objective.id]={"kind":"DONE","text":objective.text}
	for lead in leads():
		if bool(lead.available): snapshot["lead_"+str(lead.id)]={"kind":"HEARD","text":str(lead.text)+" — "+source_name(str(lead.source))}
	for id in ResidencySystem.state().materials:
		var material: Dictionary=ResidencySystem.state().materials[id]
		if str(material.get("kind","")) not in ["official","proof"]:
			snapshot["material_"+str(id)]={"type":"Material","kind":"FOUND","text":str(material.get("title","新材料"))}
	for id in GameState.confirmed_residents:
		snapshot["recognition_"+str(id)]={"type":"RecognitionEvent","kind":"CONNECTED","text":source_name(str(id))+"留下了认可"}
	var key := GameState.current_role+":"+str(GameState.current_day)
	if _session_key!=key:
		_session_key=key; _previous=snapshot
		feedback_queue.clear()
	var seen: Dictionary=state().seen
	for id in snapshot:
		if not _previous.has(id) and not seen.has(id):
			notification.emit(str(snapshot[id].kind),str(snapshot[id].text)); seen[id]=true
			GameEvents.publish({"DONE":"ObjectiveCompleted","FOUND":"MaterialAdded","HEARD":"LeadDiscovered","CONNECTED":"RecognitionGranted"}[str(snapshot[id].kind)],snapshot[id].merged({"id":id}))
	if snapshot!=_previous: updated.emit()
	_previous=snapshot
	var next := next_step()
	var direction := str(next.get("id",next.get("text","")))
	if direction!=last_direction:
		last_direction=direction; updated.emit(); GameEvents.publish("ObjectiveUpdated",next)
	# The direction card already introduces the day. Do not repeat it as a toast.
	CoreLoopSystem.day_state().brief_seen=true

func _ready() -> void:
	notification.connect(queue_feedback)
	GameState.session_restored.connect(func() -> void: _session_key=""; _previous.clear())

func queue_feedback(kind: String, text: String) -> void:
	for entry in feedback_queue:
		if entry.kind==kind:
			if not entry.texts.has(text): entry.texts.append(text)
			return
	feedback_queue.append({"kind":kind,"texts":[text],"priority":{"CONNECTED":4,"DONE":3,"HEARD":2,"FOUND":1}.get(kind,0)})
	feedback_age=0
func take_feedback() -> Dictionary:
	if feedback_queue.is_empty() or feedback_age<.25 or not bool(UIStateSystem.policy().notify): return {}
	feedback_queue.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.priority>b.priority)
	var entries := feedback_queue.duplicate(true); feedback_queue.clear()
	var parts: Array[String]=[]
	for entry in entries:
		parts.append(str(entry.texts[0])+("（另有%d项已记入随身本）"%(entry.texts.size()-1) if entry.texts.size()>1 else ""))
	if entries.size()>2:
		var summary: Array[String]=[]
		for entry in entries.slice(1): summary.append(str({"DONE":"今日记录","FOUND":"新材料","HEARD":"新线索","CONNECTED":"居民认可"}.get(entry.kind,"新记录"))+" %d 项"%entry.texts.size())
		parts=[parts[0],"   ".join(summary)]
	return {"heading":str({"DONE":"今天留下了一笔","FOUND":"收进随身包","HEARD":"听来的消息","CONNECTED":"有人记住了你"}.get(entries[0].kind,"刚刚发生")),"text":"\n".join(parts),"entries":entries}
