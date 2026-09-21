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

func time_text(minute: int) -> String:
	return "%02d:%02d" % [minute/60,minute%60]

func organized(day: int) -> bool:
	var s := ResidencySystem.state()
	var page: Array=s.get("free_pages",{}).get("day_%d" % day,[])
	return ResidencySystem.night_organized(day) or (not page.is_empty() and not s.pages[day-1].get("organized_at",{}).is_empty())

func today_rows() -> Array:
	var s := ResidencySystem.state()
	var audit := ResidencySystem.audit()
	var receipts: int = EconomySystem.state().receipts.size()
	var visits: int = s.visits.size()
	var rows: Array = []
	match GameState.current_day:
		1:
			rows = [{"text":"领取资料袋，走访三个地方","done":bool(s.packet) and visits>=3,"action":"map","location":"print_shop"}, {"text":"留下一张消费小票","done":receipts>=1,"action":"map","location":"cafe"}]
		2:
			rows = [{"text":"记录一次新发现","done":audit.get("exploration_kinds",[]).has("discover"),"action":"exploration"},{"text":"换个时段回访，写下想带人来的地方","done":bool(audit.requirements.exploration),"action":"exploration"}]
		3:
			rows = [{"text":"完成一次工作，领取收入证明","done":bool(audit.requirements.income),"action":"map","location":"night_market"},{"text":"累计三张小票，覆盖两种用途","done":bool(audit.requirements.living_receipts) and bool(audit.requirements.receipt_categories),"action":"receipts"}]
		4:
			var contribution_place := "handcraft_shop"
			var revisited := false
			for contribution in GameState.shared_state.get("world_artifacts",{}).get("contributions",[]):
				if str(contribution.get("created_by","")) != GameState.current_role or not bool(contribution.get("accepted",false)): continue
				contribution_place = str(contribution.location)
				if contribution.has("revisited_day"): revisited = true
			rows = [{"text":"把一件作品交给小镇，领取贡献证明","done":bool(audit.requirements.contribution),"action":"map","location":contribution_place},{"text":"回到作品留下的地方看一看","done":revisited,"action":"map","location":contribution_place}]
		5:
			rows = [{"text":"查看已留下的居民认可","done":bool(audit.requirements.recognition),"action":"recognition"},{"text":"认识不同生活圈的居民","done":bool(audit.requirements.recognition_circles),"action":"recognition"}]
		6:
			rows = [{"text":"补齐申请要求里的空缺","done":bool(audit.requirements.income) and bool(audit.requirements.contribution) and bool(audit.requirements.exploration),"action":"requirements"},{"text":"留下自己的选择与感受","done":bool(audit.requirements.personal),"action":"personal"}]
		7:
			rows = [{"text":"逐页核对七日记录","done":bool(audit.requirements.pages) and bool(audit.requirements.ledger),"action":"requirements"},{"text":"18:00 前到社区中心交件","done":not s.submitted.is_empty(),"action":"map","location":"print_shop"}]
	rows.append({"text":"回房整理今天的材料与收支","done":organized(GameState.current_day),"action":"organize","location":"residence" if GameState.current_role=="A" else "dorm"})
	return rows

func next_step() -> Dictionary:
	var s := ResidencySystem.state()
	if not bool(s.packet): return {"text":"去社区中心领取资料袋","action":"map","location":"print_shop"}
	var commitment := GameState.next_commitment()
	if not commitment.is_empty():
		var start := int(commitment.get("return_by",commitment.get("start",1440)))
		var destination := str(commitment.get("location","dorm"))
		if GameState.current_minute+maxi(0,WorldGraph.walk_minutes(GameState.current_location,destination))+10>=start and start+10>=GameState.current_minute:
			return {"text":time_text(start)+" 前到"+TravelSystem.location_name(destination)+"工作","action":"map","location":destination}
	if GameState.current_day==1:
		if EconomySystem.state().receipts.is_empty(): return {"text":"去杂货店买一件需要的小物，收好小票","action":"map","location":"cafe"}
		if not KnowledgeSystem.facts().any(func(f: Dictionary)->bool:return str(f.get("id","")) in ["grocery_hours","beetman_shopping"]):
			return {"text":"问问店主营业时间，记进手记","action":"map","location":"cafe"}
		if s.visits.size()<3: return {"text":"去菜摊走走，留下第一印象","action":"map","location":"produce_stall"}
		if not organized(1): return {"text":"回住处，把小票放进 Day 1","action":"organize","location":"residence" if GameState.current_role=="A" else "dorm"}
	if not EconomySystem.active_order().is_empty() and not bool(EconomySystem.active_order().get("completed",false)):
		var procurement := EconomySystem.procurement_summary()
		return {"text":procurement.next,"action":"map","location":procurement.source_locations[0]}
	for row in today_rows():
		if not bool(row.done): return row
	return {"text":"今天的材料收好了，可以自由走走","action":"today"}

func opportunities(location := "") -> Array:
	var rows: Array = []
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

func idle_tick(delta: float, walking: bool) -> void:
	var key := str(GameState.current_day)+GameState.current_location+str(ResidencySystem.state().materials.size())+str(KnowledgeSystem.facts().size())
	if key!=progress_key or walking: idle_seconds=0; progress_key=key
	else: idle_seconds+=delta
	if idle_seconds<90 or reminded==key: return
	for entry in opportunities():
		if entry.has("start") and int(entry.start)>GameState.current_minute and int(entry.start)-GameState.current_minute<=30:
			GameState.message_posted.emit("那件约好的事快到时间了。Tab 看看路。")
			reminded=key
			break


func state() -> Dictionary:
	var key := "guidance_"+GameState.current_role
	if not GameState.shared_state.has(key):
		GameState.shared_state[key]={"tracked_lead":"", "personal":"", "seen":{}}
	return GameState.shared_state[key]

# Public records are projections, not a second quest/material inventory.
func must_objectives() -> Array:
	var rows := today_rows()
	if GameState.current_day==2:
		rows=[{"text":"认识两位居民，听听各自的事","done":GameState.encountered_residents.size()>=2,"action":"map","location":"record_store"},{"text":"循着一条听来的线索去看看","done":leads().any(func(lead: Dictionary) -> bool: return ResidencySystem.state().visits.has(str(lead.location))),"action":"heard"},rows.back()]
	elif GameState.current_day==3:
		rows=[rows[0],{"text":"留下一份照片、录音或自己的作品","done":ResidencySystem.state().materials.values().any(func(item: Dictionary) -> bool: return str(item.get("kind","")) in ["photo","sound","work"]),"action":"sound_library"},rows.back()]
	for i in rows.size():
		rows[i]["id"]="must_%d_%d" % [GameState.current_day,i]
		rows[i]["type"]="MustObjective"
	return rows.slice(0,3)

func leads() -> Array:
	var result: Array=[]
	for fact in KnowledgeSystem.facts():
		var location := str(fact.get("location",fact.get("subject_id","")))
		if not ResidencySystem.locations.has(location): continue
		result.append({"type":"Lead","id":str(fact.get("id","")),"text":str(fact.get("text","")),"location":location,"source":str(fact.get("source_npc_id","")),"available":str(fact.get("status",""))!="Outdated"})
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
	return str(ScheduleSystem.residents.get(id,{}).get("display_name",id if not id.is_empty() else "沿途发现"))

func hear(id: String, text: String, source: String, location: String) -> void:
	KnowledgeSystem.learn({"id":id,"text":text,"source_npc_id":source,"subject_id":location,"predicate":"lead","confidence":1.0})
	refresh()

func _process(delta: float) -> void:
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
		if str(material.get("kind","")) in ["photo","sound","receipt","work","letter"]:
			snapshot["material_"+str(id)]={"type":"Material","kind":"FOUND","text":str(material.get("title","新材料"))}
	for id in GameState.confirmed_residents:
		snapshot["recognition_"+str(id)]={"type":"RecognitionEvent","kind":"CONNECTED","text":source_name(str(id))+"留下了认可"}
	var key := GameState.current_role+":"+str(GameState.current_day)
	if _session_key!=key:
		_session_key=key; _previous=snapshot; return
	var seen: Dictionary=state().seen
	for id in snapshot:
		if not _previous.has(id) and not seen.has(id):
			notification.emit(str(snapshot[id].kind),str(snapshot[id].text)); seen[id]=true
	if snapshot!=_previous: updated.emit()
	_previous=snapshot

func _ready() -> void:
	GameState.session_restored.connect(func() -> void: _session_key=""; _previous.clear())
