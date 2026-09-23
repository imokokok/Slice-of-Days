extends Node
## Shared domestic boundaries. Background routines never award playable work,
## private inventory, NPC encounters, confirmations, or chapter completion.
const ADDRESS := "海风路17号"
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed<1.0: return
	elapsed=0.0
	if not GameState.shared_state.has("journey_id"): return
	sync_routines()

func state() -> Dictionary:
	return GameState.shared_state.get_or_add("household",{"version":1,"mail":{},"routines":{},"applications":{},"shared_leads":{}})

func sync_routines() -> void:
	var house := state()
	var now := GameState.current_day*1440+GameState.current_minute
	var previous := int(house.get("background_cursor",now))
	for day in range(1,GameState.current_day+1):
		var cutoff := GameState.current_minute if day==GameState.current_day else 1440
		for role in ["A","B"]:
			var id := "d%d_%s_notice"%[day,role]
			if cutoff>=480 and not house.mail.has(id):
				house.mail[id]={"id":id,"owner":role,"day":day,"title":"唱片店的开放通知" if role=="A" else "饭店排班通知","text":"今天可以带着声音来唱片店。请先保留每一段声音的来路。" if role=="A" else "固定班次 14:00—18:00。请到出餐口旁签到；采购与料理另按实际完成记录。","read_by":[],"returned_by":[],"source":"ordinary_mail"}
				if role=="B" and day==5: house.mail[id].text="今天是排班表上的轮休日，明天再照常回店。可以把这一整天留给自己的安排。"
			var inactive: bool=role != str(ChapterSystem.DAYS[day-1].role) if day<5 else role!=GameState.current_role
			if not inactive: continue
			for activity in [{"at":450,"id":"breakfast","place":"residence","text":"水壶里留了热水，餐桌已经擦干净。"},{"at":840,"id":"out","place":"night_market" if role=="B" else "library","text":"门口的伞被带走了，楼梯上留着刚收起的晾衣夹。"},{"at":1110,"id":"return","place":"residence","text":"门边多了一袋日用品，公共灯已经打开。"}]:
				# Day 5 has player-selected perspectives: never backfill a routine
				# into an interval when that person may have been actively played.
				if day==5 and day*1440+int(activity.at)<=previous: continue
				var key := "d%d_%s_%s"%[day,role,activity.id]
				if cutoff>=int(activity.at) and not house.routines.has(key):
					house.routines[key]={"owner":role,"day":day,"minute":activity.at,"location":activity.place,"text":activity.text,"kind":"domestic_routine"}
	house["background_cursor"]=maxi(now,previous)

func mail() -> Array:
	sync_routines()
	var rows: Array=state().mail.values().duplicate(true)
	rows.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.day)>int(b.day))
	return rows

func read_mail(id: String, put_back := false) -> Dictionary:
	if GameState.current_location!=CoreLoopSystem.home() or not state().mail.has(id): return {"ok":false,"message":"请先走到门口的信箱。"}
	var snapshot := GameState.to_save_data().duplicate(true)
	var row: Dictionary=state().mail[id]
	var key := "returned_by" if put_back else "read_by"
	if not row[key].has(GameState.current_role): row[key].append(GameState.current_role)
	if not SaveManager.save_or_report("信箱记录未能保存"):
		GameState.load_save_data(snapshot); return {"ok":false,"message":"没能保存，可以再看一次。"}
	return {"ok":true,"message":"把这封通知放回了信箱。" if put_back else str(row.text)}

func application(role := "") -> Dictionary:
	var owner := GameState.current_role if role.is_empty() else role
	GameState.commit_active_role_state()
	var confirmed: Array=GameState.role_states.get(owner,{}).get("confirmed_residents",[])
	var accepted: Array[String]=[]
	for id in confirmed:
		if ResidentProfileSystem.is_core(str(id)) and not accepted.has(str(id)): accepted.append(str(id))
	return {"role":owner,"confirmed":accepted.size(),"required":12,"passed":accepted.size()==12,"ids":accepted,"submitted":state().applications.has(owner)}

func submit_application() -> Dictionary:
	if GameState.current_location!=CoreLoopSystem.home(): return {"ok":false,"message":"申请表留在门口信箱旁。"}
	var audit := application()
	if not bool(audit.passed): return {"ok":false,"message":"已有 %d/12 位居民的认可。还有些关系需要自己慢慢建立。"%int(audit.confirmed)}
	if bool(audit.submitted): return {"ok":true,"message":"你的申请已经放进信箱，不必重复投递。"}
	var snapshot := GameState.to_save_data().duplicate(true)
	state().applications[GameState.current_role]={"owner":GameState.current_role,"day":GameState.current_day,"minute":GameState.current_minute,"recognitions":audit.ids.duplicate(),"address":ADDRESS}
	if not SaveManager.save_or_report("旅居申请未能保存"):
		GameState.load_save_data(snapshot); return {"ok":false,"message":"投递未保存，申请表仍在手边。"}
	return {"ok":true,"message":"申请已经投递。居民留下的认可仍属于你自己。"}

func exchange_leads() -> bool:
	if not CharacterSystem.switch_unlocked() or GameState.current_location!=CoreLoopSystem.home(): return false
	var snapshot := GameState.to_save_data().duplicate(true)
	var source := "B" if GameState.current_role=="A" else "A"
	var introduced: Dictionary=GameState.shared_state.get("core_loop_"+source,{}).get("introduced",{})
	var facts: Array=GameState.shared_state.get("knowledge_"+GameState.current_role,[])
	var added := 0
	for npc in introduced:
		var person: Dictionary=CoreLoopSystem.catalog.get("people",{}).get(npc,{})
		if person.is_empty(): continue
		var id := "shared_lead_"+source+"_"+str(npc)
		if facts.any(func(f: Dictionary)->bool:return str(f.get("id",""))==id): continue
		facts.append({"id":id,"text":str(person.lead),"source_npc_id":npc,"subject_id":str(person.place),"predicate":"lead","confidence":1.0,"learned_day":5,"learned_time":GameState.current_minute,"shared_by":source,"module":str(person.module)})
		added+=1
	GameState.shared_state["knowledge_"+GameState.current_role]=facts
	state().shared_leads[GameState.current_role]=added
	if not SaveManager.save_or_report("交流的地点信息未能保存"):
		GameState.load_save_data(snapshot); return false
	return true
