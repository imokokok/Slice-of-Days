extends Node
## Per-character life state lives inside the existing atomic save snapshot.
## Plans reserve intent; only physical activity completion can fulfil them.
const LABELS := {"body":"身体", "engagement":"投入", "clarity":"思绪", "security":"安心"}
const LOW := {"body":"有些疲惫，走路想慢一点", "engagement":"提不起劲，想先做熟悉的事", "clarity":"事情有点乱，需要再看一遍安排", "security":"惦记着接下来的花销"}
const MID := {"body":"脚步还轻松", "engagement":"愿意试试新东西", "clarity":"知道接下来要做什么", "security":"心里有底"}
const HIGH := {"body":"精神很好，也要给休息留位置", "engagement":"有点上头，容易忘记休息", "clarity":"安排得很满，留一点临时变化的余地", "security":"很放松，花钱前还是看一眼余额"}

func _ready() -> void:
	GameplayModuleSystem.module_completed.connect(_module_completed)
	GameState.money_recorded.connect(_money_changed)

func state() -> Dictionary:
	return GameState.artifacts.get_or_add("daily_life", {"version":1,"values":{"body":72.0,"engagement":64.0,"clarity":72.0,"security":68.0},"plans":[],"history":[],"settled":[],"dawn_days":[],"closed_days":[],"edits":{},"meals":[]})

func value(key: String, role := "") -> float:
	if role.is_empty() or role==GameState.current_role: return float(state().values.get(key,65))
	return float(GameState.role_states.get(role,{}).get("artifacts",{}).get("daily_life",{}).get("values",{}).get(key,65))

func describe() -> Array:
	var result: Array=[]
	for key in LABELS:
		var n := value(key)
		result.append({"label":LABELS[key],"text":LOW[key] if n<35 else HIGH[key] if n>85 else MID[key]})
	return result

func change(delta: Dictionary, reason: String) -> void:
	for key in delta: state().values[key]=clampf(value(key)+float(delta[key]),0,100)
	if not reason.is_empty():
		state().history.append({"day":GameState.current_day,"minute":GameState.current_minute,"text":reason})
		if state().history.size()>60: state().history.pop_front()

func walk_multiplier(role := "") -> float:
	return 0.72 if value("body",role)<20 else 0.85 if value("body",role)<35 else 1.0

func thought() -> String:
	if value("engagement")<35: return "今天有点提不起劲。也许先听听熟悉的声音，再决定要不要试新的。"
	if value("clarity")<35: return "刚才想做什么来着？先翻一眼随身本。" if CharacterSystem.owns_pocket_item("notebook") else "刚才想做什么来着？先看一眼今天的安排。"
	return ""

func spending_concern(cost: int) -> String:
	var floor_amount := 1000 if GameState.current_role=="A" else 180
	if cost>0 and (value("security")<35 or GameState.money-cost<floor_amount): return "花完这笔，之后还要留车费和饭钱。"
	return ""

func _money_changed(row: Dictionary) -> void:
	var amount := int(row.amount)
	change({"security":minf(5,amount/45.0) if amount>0 else -minf(7,absf(amount)/100.0)},"")

func today_income() -> int:
	var total := 0
	for row in GameState.money_ledger:
		if int(row.day)==GameState.current_day and int(row.amount)>0 and str(row.get("kind",""))!="reimbursement" and not str(row.reason).contains("报销"): total+=int(row.amount)
	return total

func tick(minutes: int) -> void:
	if minutes<=0: return
	change({"body":-minutes*0.018,"security":-minutes*0.018 if GameState.money<(1000 if GameState.current_role=="A" else 180) else 0},"")
	for plan: Dictionary in state().plans:
		if int(plan.day)!=GameState.current_day or str(plan.status)!="planned" or GameState.current_minute<int(plan.end): continue
		var pending: Dictionary=GameState.shared_state.get("pending_module",{})
		if str(pending.get("module_id",""))==str(plan.activity) and int(pending.get("start_minute",-1))>=int(plan.start) and int(pending.get("start_minute",-1))<int(plan.end): continue
		plan.status="missed"
		change({"clarity":-4,"engagement":-3,"security":-5 if not str(plan.get("npc","")).is_empty() else -1},"没赶上："+str(plan.title))
		if not str(plan.get("npc","")).is_empty(): RelationshipSystem.add_flags(str(plan.npc),["missed_plan_d%d"%GameState.current_day])
	for commitment in GameState.commitments_for_day():
		if GameState.current_minute>=int(commitment.end) and not GameState.completed_commitments.has(GameState._commitment_token(commitment)) and active_shift().is_empty(): GameState._miss_commitment(commitment)

func edited(reason: String) -> void:
	var day := str(GameState.current_day)
	state().edits[day]=int(state().edits.get(day,0))+1
	change({"clarity":-2 if int(state().edits[day])<=2 else -6},reason)

func begin_day() -> void:
	if state().dawn_days.any(func(day: Variant) -> bool: return int(day)==GameState.current_day): return
	state().dawn_days.append(GameState.current_day)
	var delay := int(state().get("wake_delay",0))
	if delay>0:
		GameState.current_minute=maxi(GameState.current_minute,int(GameState.schedule_for(GameState.current_role,GameState.current_day).get("start",420))+delay)
		change({},"昨晚的疲惫还没散，今天晚起了 %d 分钟。"%delay)
	state().wake_delay=0
	GameState.commit_active_role_state()

func close_day() -> void:
	if state().closed_days.any(func(day: Variant) -> bool: return int(day)==GameState.current_day): return
	# Missing plans are resolved even when the player chooses to sleep early.
	for plan: Dictionary in state().plans:
		if int(plan.day)==GameState.current_day and str(plan.status)=="planned":
			plan.status="missed"; change({"clarity":-3,"engagement":-2,"security":-3},"今天没有去："+str(plan.title))
	for commitment in GameState.commitments_for_day():
		if not GameState.completed_commitments.has(GameState._commitment_token(commitment)): GameState._miss_commitment(commitment)
	state().closed_days.append(GameState.current_day)
	var severe := value("body")<20
	state().wake_delay=40 if severe else 0
	var sleep_hours := clampf((1440-GameState.current_minute+420)/60.0,0,10)
	change({"body":sleep_hours*(3 if severe else 5),"clarity":sleep_hours*2,"engagement":4},"睡了一觉。"+("疲惫没有完全恢复。" if severe else ""))
	GameState.commit_active_role_state()

func known_cards() -> Array:
	var result: Array=[{"id":"rest","title":"回家歇一会儿","minutes":30,"location":"residence","type":"short","source":"自己的住处"},{"id":"meal","title":"回家吃一顿饭","minutes":20,"location":"residence","type":"short","source":"自己的住处"},{"id":"quiet","title":"安静整理今天的思绪","minutes":20,"location":"residence","type":"short","source":"自己的住处"}]
	for module in GameplayModuleSystem.modules:
		if not GameplayModuleSystem.is_unlocked(str(module)): continue
		var meta: Dictionary=GameplayModuleSystem.modules[module]
		var place := WorldGraph.activity_location(str(module))
		if place.is_empty():
			for person: Dictionary in CoreLoopSystem.catalog.get("people",{}).values():
				if str(person.get("module",""))==str(module): place=str(person.get("place","")); break
		if place.is_empty(): continue
		result.append({"id":module,"title":str(meta.get("name",module)),"minutes":GameplayModuleSystem.required_minutes(str(module)),"location":place,"type":"continuous","source":"已听说的活动"})
	for id in GameState.encountered_residents:
		var person := str(id)
		var place := CoreLoopSystem.npc_place(person)
		if place.is_empty(): continue
		result.append({"id":"talk:"+person,"npc":person,"title":"和"+GuidanceSystem.source_name(person)+"聊一会儿","minutes":10,"location":place,"type":"window","source":"见过的人"})
	return result

func add_plan(id: String, start: int, transport: String) -> Dictionary:
	var card: Dictionary={}
	for item in known_cards():
		if str(item.id)==id: card=item; break
	if card.is_empty(): return fail("还没有听说这件事。")
	if transport not in ["walk","bus","taxi"]: return fail("请选择步行、公交或出租车。")
	var end := start+int(card.minutes)
	if GameplayModuleSystem.modules.has(id):
		var hours := WorldGraph.location_status(str(card.location),start)
		if not bool(hours.open) or end>int(hours.closes): return fail("这次活动要放在营业时间内："+str(hours.hours))
	if start<GameState.current_minute or not GameState.can_fit_at(GameState.current_role,GameState.current_day,start,int(card.minutes)): return fail("这件事需要 %d 分钟连续空档。先重组私人安排，或换个时间。"%int(card.minutes))
	for row in state().plans:
		if int(row.day)==GameState.current_day and str(row.status)=="planned" and start<int(row.end) and end>int(row.start): return fail("和已经写下的安排重叠了。")
	var npc := str(card.get("npc",""))
	if not npc.is_empty():
		var activity := ScheduleSystem.activity_at(npc,GameState.current_day,start)
		if str(activity.get("location",""))!=str(card.location): return fail("这个时间，对方不在这里。按已知日程换个时间。")
	var snapshot := GameState.to_save_data().duplicate(true)
	var token := Crypto.new().generate_random_bytes(8).hex_encode()
	state().plans.append({"id":token,"activity":id,"title":card.title,"day":GameState.current_day,"start":start,"end":end,"location":card.location,"npc":npc,"transport":transport,"status":"planned","source":card.source})
	return persist(snapshot,"写进日程了。出门前还要留好路上的时间。")

func cancel_plan(id: String) -> Dictionary:
	for plan: Dictionary in state().plans:
		if str(plan.id)!=id or str(plan.status)!="planned": continue
		var snapshot := GameState.to_save_data().duplicate(true)
		plan.status="cancelled"; edited("划掉了原先的安排："+str(plan.title))
		change({"engagement":-3,"security":-5 if not str(plan.npc).is_empty() else -1},"")
		if not str(plan.npc).is_empty(): RelationshipSystem.add_flags(str(plan.npc),["cancelled_plan_d%d"%GameState.current_day])
		return persist(snapshot,"已经划掉。旧安排留在本子里。")
	return fail("这条安排已结束，不能重复取消。")

func departure_quote(id: String) -> Dictionary:
	for plan: Dictionary in state().plans:
		if str(plan.id)!=id or int(plan.day)!=GameState.current_day or str(plan.status)!="planned": continue
		if not SceneRouter.active_space_id.is_empty(): return fail("先走到室外，再按计划出发。")
		var route := TravelSystem.route(GameState.current_location,str(plan.location),str(plan.transport),GameState.current_role,GameState.current_minute)
		if not bool(route.get("available",false)): return fail(str(route.get("reason","现在不能出发。")))
		return {"ok":true,"location":plan.location,"transport":plan.transport,"message":"%s前往%s · %d分钟 · %d元\n预计 %s 到达。%s"%[route.label,TravelSystem.location_name(str(plan.location)),int(route.minutes),int(route.cost),GuidanceSystem.time_text(int(route.arrival)),"会晚于写下的时间，可以先调整计划。" if int(route.arrival)>int(plan.start) else ""]}
	return fail("这条计划已经结束。")

func depart(id: String) -> Dictionary:
	var quote := departure_quote(id)
	if not bool(quote.ok): return quote
	return SceneRouter.travel_to(str(quote.location),str(quote.transport))

func completed(activity: String, start: int, minutes: int) -> void:
	for plan: Dictionary in state().plans:
		if int(plan.day)==GameState.current_day and str(plan.status)=="planned" and str(plan.activity)==activity and start>=int(plan.start) and start<int(plan.end) and start+minutes<=int(plan.end):
			plan.status="done"; plan.actual_start=start; plan.actual_minutes=minutes
			change({"clarity":5,"security":4},"如约做完："+str(plan.title)); break

func everyday(id: String) -> Dictionary:
	if GameState.current_location!="residence" or SceneRouter.active_space_id not in ["home_a","home_b"]: return fail("先回到家里，再歇一会儿或吃饭。")
	if not GameplayModuleSystem.pending_module_id().is_empty(): return fail("先收好手头的活动。")
	var duration := 30 if id=="rest" else 20
	if id not in ["rest","meal","quiet"] or not GameState.can_fit_now(duration): return fail("这段空档不够，先看看今天的安排。")
	var meal := ""
	if id=="meal":
		for ingredient in ["bread","tomato","sardine","sea_bream","apple"]:
			if int(GameState.inventory.get(ingredient,0))>0: meal=ingredient; break
		if meal.is_empty(): return fail("家里没有能吃的东西了。先去商店买一点食物。")
	var snapshot := GameState.to_save_data().duplicate(true)
	var start := GameState.current_minute
	# Mark the reserved plan at the same boundary as the actual timed action.
	completed(id,start,duration)
	GameState.spend_time(duration)
	if id=="rest": change({"body":14,"engagement":3,"clarity":3},"在家歇了半小时。")
	if id=="quiet": change({"clarity":14,"engagement":4},"收好桌上的纸，安静想了一会儿。")
	if id=="meal":
		GameState.consume_inventory([meal])
		var meals: Array=state().meals
		var recent := not meals.is_empty() and int(meals[-1].day)==GameState.current_day and start-int(meals[-1].minute)<180
		meals.append({"day":GameState.current_day,"minute":start})
		change({"body":3 if recent else 15,"security":2},"坐下来吃了点东西。"+("还不太饿，吃一点就够了。" if recent else ""))
	return persist(snapshot,"时间到了。"+str(state().history[-1].text))

func talked(npc: String) -> void:
	var token := "talk:%s:%d"%[npc,GameState.current_day]
	if state().settled.has(token): return
	state().settled.append(token)
	var start := GameState.current_minute
	if GameState.can_fit_now(10): completed("talk:"+npc,start,10); GameState.spend_time(10)
	change({"engagement":3,"clarity":1},"和"+GuidanceSystem.source_name(npc)+"说了会儿话。")

func _module_completed(_role: String, module: String, _outcome: Dictionary) -> void:
	var pending: Dictionary=GameState.shared_state.get("pending_module",{})
	var start := int(pending.get("start_minute",GameState.current_minute))
	var duration := maxi(0,GameState.current_minute-start)
	var token := "%s:%d:%d"%[module,GameState.current_day,GameplayModuleSystem.state_for(module).outcomes.size()]
	if state().settled.has(token): return
	state().settled.append(token)
	completed(module,start,duration)
	var work := module in ["cooking","ghostwriting"]
	var tired := value("body")<35
	change({"body":-maxf(3,duration*0.07)*(1.5 if tired else 1),"engagement":-5 if work else 8,"clarity":-4 if duration>=60 else 1,"security":3 if work else 0},"完成了"+str(GameplayModuleSystem.modules.get(module,{}).get("title",module))+"。")
	if value("engagement")>85 and not work: change({"body":-4},"投入得忘了歇一歇。")
	if module=="cooking" and not active_shift().is_empty(): finish_shift()

func active_shift() -> Dictionary:
	return state().get("active_shift",{})

func start_shift(early := false) -> Dictionary:
	var shift := GameState.next_commitment()
	if GameState.current_role!="B" or shift.is_empty(): return fail("今天没有待完成的班次。")
	if GameState.current_location!="night_market" or SceneRouter.active_space_id!="restaurant": return fail("到饭店出餐口和店主说一声，再开始工作。")
	if GameState.current_minute<int(shift.start) or GameState.current_minute>=int(shift.end)-30: return fail("请在班次时间内开始，至少留出半小时。")
	if not GameplayModuleSystem.pending_module_id().is_empty(): return fail("先结束手头的活动。")
	var snapshot := GameState.to_save_data().duplicate(true)
	var end := mini(GameState.current_minute+90,int(shift.end)) if early else int(shift.end)
	state().active_shift=shift.duplicate(true)
	active_shift().merge({"actual_start":GameState.current_minute,"actual_end":end,"token":GameState._commitment_token(shift)},true)
	if not SceneRouter.gameplay_module("cooking","shift:"+str(shift.id),snapshot):
		GameState.load_save_data(snapshot); return fail("工作暂时无法开始；请先完成已接下的采购和交货。")
	return {"ok":true,"message":"开始工作。完成备料和出餐后，按实际工作时段结算。"}

func finish_shift() -> void:
	var shift := active_shift().duplicate(true)
	if shift.is_empty() or GameState.completed_commitments.has(str(shift.token)): return
	var minutes := int(shift.actual_end)-int(shift.actual_start)
	var pay := int(floor(float(shift.pay)*minutes/maxi(1,int(shift.end)-int(shift.start))))
	GameState.completed_commitments.append(str(shift.token))
	GameState.earn_money(pay,"饭店班次工资",{"work_minutes":minutes,"commitment":shift.token,"kind":"income"})
	state().last_shift={"day":GameState.current_day,"pay":pay,"minutes":minutes}
	state().erase("active_shift")
	if int(shift.actual_end)<int(shift.end): change({"security":-4},"提前离开饭店，少做的时段没有工资。")
	RelationshipSystem.record_encounter("shi_yongqi","shift_"+str(shift.token),["completed_shift"])

func adjust_shift(action: String) -> Dictionary:
	var shift := GameState.next_commitment()
	if GameState.current_role!="B" or shift.is_empty() or not active_shift().is_empty(): return fail("现在没有可以调整的班次。")
	if GameState.current_minute>=int(shift.start): return fail("班次已经开始，需要到饭店实际工作；早退按工作时长结算。")
	if action=="swap" and not RelationshipSystem.has_flag("shi_yongqi","completed_shift"): return fail("还没有一起完成过班次。先和店主建立实际工作的信任。")
	if action not in ["leave","swap"]: return fail("班次不能随意移动。")
	var next_day := 4 if GameState.current_day<4 else 5
	if action=="swap" and GameState.current_day>=5: return fail("旅程内没有可换的后续工作日。")
	var snapshot := GameState.to_save_data().duplicate(true)
	var moves: Dictionary=GameState.shared_state.get_or_add("life_shift_moves",{})
	var today_move: Dictionary=moves.get_or_add("B_%d"%GameState.current_day,{})
	today_move.get_or_add("removed_ids",[]).append(str(shift.id))
	GameState.completed_commitments.append(GameState._commitment_token(shift))
	if action=="swap":
		var moved := shift.duplicate(true)
		# A swapped shift uses the next morning, leaving the existing afternoon shift intact.
		moved.id=str(shift.id)+"_from_%d"%GameState.current_day; moved.start=540; moved.end=780; moved.return_by=540
		var target: Dictionary=moves.get_or_add("B_%d"%next_day,{})
		if target.has("added"): GameState.load_save_data(snapshot); return fail("那天上午已经换入一个班次，不能再叠加。")
		target.added=moved
	change({"security":-6 if action=="leave" else -2,"clarity":-2},"今天请假，没有这班工资。" if action=="leave" else "和店主换班：第 %d 天 09:00—13:00 工作，今天这班不领工资。"%next_day)
	return persist(snapshot,str(state().history[-1].text))

func schedule_override(role: String, day: int, original: Dictionary) -> Dictionary:
	var move: Dictionary=GameState.shared_state.get("life_shift_moves",{}).get("%s_%d"%[role,day],{})
	if move.is_empty(): return original
	var result := original.duplicate(true)
	if bool(move.get("removed",false)): result.commitments=[]
	if move.has("added"):
		result.get_or_add("commitments",[]).append(move.added.duplicate(true))
	result.commitments=result.get("commitments",[]).filter(func(c: Dictionary) -> bool: return not move.get("removed_ids",[]).has(str(c.id)))
	result.commitments.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.start)<int(b.start))
	var blocks: Array=[]
	var cursor := 420
	for commitment in result.commitments:
		if cursor<int(commitment.start): blocks.append([cursor,int(commitment.start)])
		cursor=maxi(cursor,int(commitment.end))
	if cursor<1440: blocks.append([cursor,1440])
	result.blocks=blocks
	return result

func work_fits(role: String, minute: int, duration: int) -> bool:
	var shift := active_shift()
	return role==GameState.current_role and not shift.is_empty() and minute>=int(shift.actual_start) and minute+duration<=int(shift.actual_end) and GameState.current_location=="night_market"

func persist(snapshot: Dictionary, message: String) -> Dictionary:
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("生活记录保存失败"):
		GameState.load_save_data(snapshot); return fail("没有保存成功，这次操作已经撤销。")
	GameState.state_changed.emit()
	return {"ok":true,"message":message}

func fail(message: String) -> Dictionary: return {"ok":false,"message":message}
