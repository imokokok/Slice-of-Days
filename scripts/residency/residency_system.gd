extends Node
## Formal records live inside the existing, role-separated artifact save.
signal changed
var content: Dictionary = {}
var locations: Dictionary = {}
var importing := false

func _ready() -> void:
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/residency/portfolio.json"))
	var places: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/locations.json"))
	for place in places.locations: locations[str(place.id)] = place
	GameState.money_recorded.connect(_money)
	GameplayModuleSystem.module_completed.connect(_module)
	GameState.state_changed.connect(_sync_sources)

func state() -> Dictionary:
	if not GameState.artifacts.has("residency"):
		var pages: Array = []
		for day in range(1,8): pages.append({"day":day,"fields":{},"today":"","record":"","keep":[],"marks":[],"ledger_checked":false})
		GameState.artifacts.residency = {"version":1,"packet":false,"pages":pages,"materials":{},"filing":{},"ledger":[],"visits":{},"annotations":[],"map_notes":{},"submitted":{},"opening_balance":GameState.money,"imported":false}
	var s: Dictionary = GameState.artifacts.residency
	if not s.has("visit_history"):
		s.visit_history = {}
		for location in s.visits:
			var first: Dictionary = s.visits[location].duplicate(true)
			first["period"] = exploration_period(int(first.get("minute",540)))
			s.visit_history[location] = [first]
	if not s.has("explorations"): s.explorations = {}
	if not s.has("cover_photo_id"): s.cover_photo_id = ""
	s.version = 3
	return s

func persist() -> void:
	GameState.commit_active_role_state()
	changed.emit()
	SaveManager.save_or_report("档案保存失败，请保留当前窗口后重试")

func _sync_sources() -> void:
	if importing: return
	importing = true
	var s := state()
	if not bool(s.imported):
		s.imported = true
		if not GameState.money_ledger.is_empty(): s.opening_balance = int(GameState.money_ledger[0].balance)-int(GameState.money_ledger[0].amount)
		for row in GameState.money_ledger: _money(row, false)
		for module in GameState.module_states:
			var outcomes: Array = GameState.module_states[module].get("outcomes",[])
			for i in outcomes.size(): _work_material(str(module),outcomes[i],i)
	for collection in ["photos","samples","letters","recipes"]:
		for item in GameState.artifacts.get(collection,[]):
			var id := str(item.get("id",""))
			if id.is_empty(): continue
			if collection == "photos" and str(item.get("status","DEVELOPED")) != "DEVELOPED": continue
			var kind := "photo" if collection == "photos" else "sound" if collection == "samples" else "object"
			var details: Dictionary = item.duplicate(true)
			details["kind"] = kind
			if s.materials.has(id): s.materials[id].merge(details,true)
			else: _add(id,kind,str(item.get("title",collection)),details)
	for receipt in GameState.artifacts.get("economy",{}).get("receipts",{}).values(): ingest_receipt(receipt)
	for item in GameState.shared_state.get("world_artifacts",{}).get("records",[]):
		if str(item.get("created_by","")) != GameState.current_role: continue
		var id := "archive_"+str(item.id)
		_add(id,"work","唱片入库 · "+str(item.title),{"source":item.id,"day":item.day,"issuer":"record_store","proof_kind":"contribution","medium":"唱片","archive_id":item.id,"paid":item.get("payment",0)})
		_mark_accepted(id,"record_store",{"source":"record_shop_archive","external_id":str(item.id)})
	for resident in GameState.confirmed_residents:
		_ensure_mark(str(resident))
	GameState.commit_active_role_state()
	importing = false

func _add(id: String, kind: String, title: String, details: Dictionary = {}) -> void:
	var s := state()
	if s.materials.has(id): return
	var row := {"id":id,"kind":kind,"title":title,"day":GameState.current_day,"minute":GameState.current_minute,"role":GameState.current_role,"location":GameState.current_location,"collected":true}
	row.merge(details,true)
	s.materials[id] = row
	changed.emit()

func _money(row: Dictionary, announce := true) -> void:
	var s := state()
	var source := str(row.get("transaction_id",JSON.stringify(row).sha256_text().left(18)))
	if s.ledger.any(func(r: Dictionary) -> bool: return str(r.get("source","")) == source): return
	var entry := row.duplicate(true)
	entry.source = source
	s.ledger.append(entry)
	var amount := int(row.amount)
	var reason := str(row.reason)
	if amount < 0:
		var transport := reason.contains("公交") or reason.contains("交通") or reason.contains("出租车")
		ingest_receipt({"id":"receipt_"+source,"kind":"ticket" if transport else "receipt","title":reason,"source":source,"source_transaction_id":source,"amount":amount,"total":-amount,"balance":row.balance,"day":row.day,"minute":row.minute,"category":"transport" if transport else "unclassified","valid_for_living_record":transport,"merchant_id":"town_transport" if transport else "","line_items":[{"name":reason,"quantity":1,"unit_price":-amount,"total":-amount}],"reimbursed":false})
	elif amount > 0 and not reason.contains("初始资金") and str(row.get("kind","")) != "reimbursement" and not reason.contains("报销"):
		var issuer := "record_store" if reason.contains("唱片") or reason.contains("sound") else "handcraft_shop" if reason.contains("ghostwriting") or reason.contains("代笔") or reason.contains("书信") else "night_market" if reason.contains("cooking") or reason.contains("料理") else "dorm"
		issuer = str(row.get("issuer",issuer))
		var display_reason := reason
		for module in GameplayModuleSystem.modules:
			if reason.contains(str(module)): display_reason = str(GameplayModuleSystem.modules[module].get("name","工作"))+"报酬"; break
		_add("wage_"+source,"work","收入记录 · "+display_reason,{"source":source,"amount":amount,"paid":amount,"balance":row.balance,"day":row.day,"minute":row.minute,"issuer":issuer,"proof_kind":"income","detail":display_reason,"work_minutes":int(row.get("work_minutes",0))})
	if announce: changed.emit()

func ingest_receipt(receipt: Dictionary) -> bool:
	var id := str(receipt.get("id",""))
	var source := str(receipt.get("source_transaction_id",receipt.get("source","")))
	if id.is_empty() or source.is_empty(): return false
	var details := receipt.duplicate(true)
	details["source"] = source
	details["source_transaction_id"] = source
	details["kind"] = "ticket" if str(details.get("category","")) == "transport" else "receipt"
	details["title"] = str(details.get("title",TravelSystem.location_name(str(details.get("merchant_id","")))+" · 消费小票"))
	details["amount"] = -absi(int(details.get("total",-int(details.get("amount",0)))))
	details["total"] = -int(details.amount)
	var s := state()
	if s.materials.has(id):
		# Financial corrections and the REIMBURSED stamp update this same sheet.
		s.materials[id].merge(details,true)
	else: _add(id,str(details.kind),str(details.title),details)
	changed.emit()
	return true

func valid_living_receipt(item: Dictionary, ledger: Array) -> bool:
	if item.get("kind","") not in ["receipt","ticket"] or not bool(item.get("valid_for_living_record",false)): return false
	if str(item.get("category","")) in ["","unclassified"] or int(item.get("total",0)) <= 0: return false
	var source := str(item.get("source_transaction_id",item.get("source","")))
	return ledger.any(func(row: Dictionary) -> bool: return str(row.get("transaction_id",row.get("source",""))) == source and int(row.get("amount",0)) == -int(item.total))

func _module(role: String, module: String, outcome: Dictionary) -> void:
	if role != GameState.current_role: return
	var count := int(GameState.module_states.get(module,{}).get("outcomes",[]).size())-1
	_work_material(module,outcome,maxi(0,count))
	if bool(outcome.get("contribution_accepted",false)):
		var accepted: Dictionary = outcome.get("acceptance",{})
		_mark_accepted("module_%s_%d" % [module,maxi(0,count)],str(accepted.get("location","handcraft_shop")),accepted)
	GameState.commit_active_role_state()

func _work_material(module: String, outcome: Dictionary, index: int) -> void:
	var issuer := "night_market" if module == "cooking" else "handcraft_shop" if module == "ghostwriting" else "record_store" if module == "sound_sampling" else ""
	var details := {"source":"module:%s:%d" % [module,index],"day":int(outcome.get("day",GameState.current_day)),"outcome":outcome.duplicate(true),"issuer":issuer,"proof_kind":"contribution" if not issuer.is_empty() else "","quantity":1,"contribution_created":not issuer.is_empty(),"contribution_entered_town":false}
	_add("module_%s_%d" % [module,index],"work",str(GameplayModuleSystem.modules.get(module,{}).get("name",module))+" · "+str(outcome.get("label","完成记录")),details)
	if bool(outcome.get("contribution_accepted",false)):
		var accepted: Dictionary = outcome.get("acceptance",{})
		_mark_accepted("module_%s_%d" % [module,index],str(accepted.get("location",issuer)),accepted)

func accept_contribution(source_id: String, location: String, evidence: Dictionary = {}) -> Dictionary:
	var s := state()
	var source: Dictionary = s.materials.get(source_id,{})
	if source.is_empty(): return {"ok":false,"message":"先完成一件自己的作品。"}
	if requires_record_archive(source): return {"ok":false,"message":"到唱片店制片台完成唱片并入库，再凭入库记录领取证明。"}
	if GameState.current_location != location or SceneRouter.active_space_id.is_empty(): return {"ok":false,"message":"请亲自到"+TravelSystem.location_name(location)+"留下作品。"}
	# A shift started while open can finish after closing. Its served order is
	# already accepted by the kitchen; paper proof still follows counter hours.
	var served_order := false
	if location == "night_market" and str(evidence.get("source","")) == "restaurant_served":
		var economy := get_node_or_null("/root/EconomySystem")
		if economy != null:
			var order: Dictionary = economy.active_order()
			var last_index: int = GameState.module_states.get("cooking",{}).get("outcomes",[]).size()-1
			var served: Dictionary = order.get("outcome",{}).duplicate(true)
			served["day"] = int(order.get("day",GameState.current_day))
			served_order = bool(order.get("completed",false)) and bool(order.get("accepted",false)) and bool(order.get("paid",false)) and bool(order.get("placed_contribution",false)) and source_id == "module_cooking_%d" % last_index and served == source.get("outcome",{})
	if not office_open(location) and not served_order: return {"ok":false,"message":"请在营业时间回来交件。"}
	if source.kind == "photo":
		if location != "print_shop" or str(source.get("status","DEVELOPED")) != "DEVELOPED": return {"ok":false,"message":"冲洗后的照片可在社区中心参加公共展示。"}
		var photo_source := "display_"+source_id
		_add(photo_source,"work","照片展出 · "+str(source.title),{"source":source_id,"photo_id":source_id,"issuer":"print_shop","proof_kind":"contribution","contribution_created":true,"contribution_entered_town":false})
		source_id = photo_source
		source = s.materials[source_id]
	if source.kind != "work" or str(source.get("proof_kind","")) != "contribution" or str(source.get("issuer","")) != location: return {"ok":false,"message":"这件材料需要交给对应的工作地点。"}
	if bool(source.get("contribution_entered_town",false)): return {"ok":false,"message":"这件作品已经在这里留下了。","source_id":source_id}
	_mark_accepted(source_id,location,evidence)
	persist()
	GameState.message_posted.emit("作品已留下 · 柜台可领取贡献证明")
	return {"ok":true,"message":"作品已收下，柜台可领取贡献证明。","source_id":source_id}

func requires_record_archive(item: Dictionary) -> bool:
	return str(item.get("issuer","")) == "record_store" and str(item.get("source","")).begins_with("module:sound_sampling:") and str(item.get("archive_id","")).is_empty()

func _mark_accepted(source_id: String, location: String, evidence: Dictionary) -> void:
	var s := state()
	if not s.materials.has(source_id): return
	var source: Dictionary = s.materials[source_id]
	var trace_id := "contribution_"+GameState.current_role+"_"+source_id
	if bool(source.get("contribution_entered_town",false)) and _has_contribution_trace(trace_id): return
	source["contribution_created"] = true
	source["contribution_entered_town"] = true
	source["accepted_day"] = GameState.current_day
	source["accepted_minute"] = GameState.current_minute
	source["accepted_at"] = location
	source["acceptance"] = evidence.duplicate(true)
	source["world_trace_id"] = trace_id
	var world: Dictionary = GameState.shared_state.get("world_artifacts",{})
	var placed: Array = world.get("contributions",[])
	if not placed.any(func(row: Dictionary) -> bool: return str(row.get("id","")) == trace_id):
		placed.append({"id":trace_id,"source_material":source_id,"created_by":GameState.current_role,"day":GameState.current_day,"minute":GameState.current_minute,"location":location,"title":source.title,"accepted":true,"evidence":evidence.duplicate(true)})
	world["contributions"] = placed
	GameState.shared_state["world_artifacts"] = world
	var echoes: Array = GameState.shared_state.get("visible_echoes",[])
	if not echoes.any(func(row: Dictionary) -> bool: return str(row.get("id","")) == trace_id):
		var response := "有人在纸边留了一句：下次经过，还想再看看。"
		if location == "night_market": response = "黑板下多了句话：昨天那道菜，下次还有吗？"
		elif location == "record_store": response = "试听卡被翻过。铅笔添了一句：这段声音像拐过街角。"
		elif location == "handcraft_shop": response = "回信旁留着一行字：收到，谢谢你替我把话寄出去。"
		echoes.append({"id":trace_id,"day":GameState.current_day,"role":GameState.current_role,"location":location,"text":"这里留下了："+str(source.title),"response":response,"source_material":source_id})
	GameState.shared_state["visible_echoes"] = echoes
	changed.emit()

func _has_contribution_trace(id: String) -> bool:
	if id.is_empty(): return false
	return GameState.shared_state.get("world_artifacts",{}).get("contributions",[]).any(func(row: Dictionary) -> bool: return str(row.get("id","")) == id and bool(row.get("accepted",false)))

func recognition_circle(resident: String) -> String:
	var circles: Dictionary = content.get("recognition_circles",{})
	if circles.get("residents",{}).has(resident): return str(circles.residents[resident])
	var schedule: Array = ScheduleSystem.residents.get(resident,{}).get("schedule",[])
	var longest := -1
	var found := ""
	for slot in schedule:
		var circle := str(circles.get("locations",{}).get(str(slot.get("location","")),""))
		var duration := int(slot.get("end",0))-int(slot.get("start",0))
		if not circle.is_empty() and duration > longest: longest = duration; found = circle
	return found

func visit(location: String) -> void:
	var s := state()
	if not locations.has(location): return
	var entry := {"day":GameState.current_day,"minute":GameState.current_minute,"period":exploration_period(GameState.current_minute)}
	if not s.visits.has(location):
		s.visits[location] = entry.duplicate(true)
		_add("visit_"+location,"note","走到"+TravelSystem.location_name(location),{"location":location,"source":"walk"})
	var history: Array = s.visit_history.get(location,[])
	if not history.any(func(row: Dictionary) -> bool: return int(row.day) == GameState.current_day and str(row.get("period","")) == str(entry.period)):
		history.append(entry)
		s.visit_history[location] = history
	for contribution in GameState.shared_state.get("world_artifacts",{}).get("contributions",[]):
		if str(contribution.get("created_by","")) != GameState.current_role or not bool(contribution.get("accepted",false)): continue
		if str(contribution.get("location","")) != location:
			contribution["left_after_acceptance"] = true
		elif bool(contribution.get("left_after_acceptance",false)) and not contribution.has("revisited_day"):
			contribution["revisited_day"] = GameState.current_day
			contribution["revisited_minute"] = GameState.current_minute
	GameState.commit_active_role_state()

func exploration_period(minute: int) -> String:
	for period in content.get("exploration_periods",[[0,720,"morning"],[720,1020,"afternoon"],[1020,1140,"dusk"],[1140,1440,"night"]]):
		if minute >= int(period[0]) and minute < int(period[1]): return str(period[2])
	return "night"

func record_exploration(kind: String, location: String, text: String, evidence_id := "") -> Dictionary:
	var s := state()
	if kind not in ["discover","revisit","shareplace"] or not s.visits.has(location): return {"ok":false,"message":"先亲自到过这个地方，再留下实地记录。"}
	if text.strip_edges().is_empty(): return {"ok":false,"message":"写下一句自己的观察。"}
	if not s.submitted.is_empty(): return {"ok":false,"message":"已交出的档案保持封存。"}
	var history: Array = s.visit_history.get(location,[])
	var periods: Array = []
	for row in history:
		if not periods.has(str(row.period)): periods.append(str(row.period))
	if kind == "revisit" and periods.size() < 2: return {"ok":false,"message":"再换个时段回来，留下第二次到访的时间。"}
	if not evidence_id.is_empty():
		var evidence: Dictionary = s.materials.get(evidence_id,{})
		if evidence.is_empty() or str(evidence.get("location_id",evidence.get("location",""))) != location: return {"ok":false,"message":"这件材料需要来自所选地点。"}
		if evidence.get("kind","") == "photo" and str(evidence.get("status","DEVELOPED")) != "DEVELOPED": return {"ok":false,"message":"先领回冲洗好的照片。"}
	var id := "explore_"+kind
	var titles := {"discover":"自己发现的地方","revisit":"换个时段的回访","shareplace":"想带别人去的地方"}
	var details := {"kind":"exploration","title":str(titles[kind])+" · "+TravelSystem.location_name(location),"exploration_kind":kind,"location":location,"text":text,"evidence_id":evidence_id,"visits":history.duplicate(true),"source":"player_observation"}
	if s.materials.has(id): s.materials[id].merge(details,true)
	else: _add(id,"exploration",str(details.title),details)
	s.explorations[kind] = id
	persist()
	return {"ok":true,"message":"探索记录已放进素材本，可以选择夹入哪一页。","id":id}

func office_open(location := "print_shop") -> bool:
	var minute := GameState.current_minute
	if location == "print_shop": return minute >= 540 and minute < 1080
	if location == "dorm": return minute >= 540 and minute < 1260
	var hours: Array = locations.get(location,{}).get("hours",[[540,1260]])
	return hours.any(func(h: Array) -> bool: return minute >= int(h[0]) and minute < int(h[1]))

func collect_packet() -> String:
	if GameState.current_location != "print_shop" or SceneRouter.active_space_id != "print_studio": return "请到社区中心柜台领取。"
	if not office_open(): return "柜台开放时间 09:00–18:00。"
	var s := state()
	if s.packet: return "资料袋已经领过，F 可随时查看。"
	s.packet = true
	for paper in content.starter: _add("starter_"+str(paper.id),"official",str(paper.title),{"text":paper.text,"source":"community_counter"})
	persist()
	return "六份资料已收好。F 看档案，B 看素材，晚上回房间整理。"

func proof_status(source_id: String) -> Dictionary:
	var s := state()
	var source: Dictionary = s.materials.get(source_id,{})
	var proof_id := "proof_"+source_id
	return {"created":source.get("kind","") == "work" and not str(source.get("proof_kind","")).is_empty(),"accepted":bool(source.get("contribution_entered_town",false)),"collected":s.materials.has(proof_id),"filed":str(s.filing.get(proof_id,"loose")) != "loose","proof_id":proof_id,"issuer":source.get("issuer","")}

func _ensure_mark(resident: String) -> String:
	var id := "recognition_"+resident
	if not GameState.confirmed_residents.has(resident): return ""
	var display_name := str(ScheduleSystem.residents.get(resident,{}).get("display_name",resident))
	_add(id,"recognition",display_name+"的签记",{"source":"resident_recognition","resident":resident,"signature":display_name,"text":"这张签记来自"+display_name+"。可以夹入七日页面，或收进居民认可页。"})
	state().materials[id]["circle"] = recognition_circle(resident)
	state().materials[id]["relationship_evidence"] = GameState.relationships.get(resident,{}).duplicate(true)
	# Existing saves may already have a day-page signature from the earlier interface.
	if not state().filing.has(id):
		for page in state().pages:
			if page.marks.has(resident): state().filing[id] = "day_%d" % int(page.day); break
	return id

func proof_candidates(location: String) -> Array:
	_sync_sources()
	var result: Array = []
	for item in state().materials.values():
		if item.kind == "work" and str(item.get("issuer","")) == location and not str(item.get("proof_kind","")).is_empty(): result.append(item)
	return result

func issuer_at(location: String) -> String:
	var candidates: Dictionary = {"night_market":["restaurant_owner","shi_yongqi"],"handcraft_shop":["mossner"],"record_store":["xanni","recordist"],"print_shop":["print_apprentice","mingming","stagehand","camera_keeper"]}
	for resident in candidates.get(location,[]):
		if str(ScheduleSystem.activity_at(str(resident),GameState.current_day,GameState.current_minute).get("location","")) == location: return str(resident)
	return ""

func collect_proof(source_id: String) -> String:
	var s := state()
	var source: Dictionary = s.materials.get(source_id,{})
	if source.is_empty() or source.kind != "work" or str(source.get("proof_kind","")).is_empty(): return "还没有对应的完成记录。"
	if source.proof_kind == "contribution" and (not bool(source.get("contribution_entered_town",false)) or not _has_contribution_trace(str(source.get("world_trace_id","")))): return "先把作品交给店里，让它在小镇留下。"
	var issuer := str(source.issuer)
	if GameState.current_location != issuer or SceneRouter.active_space_id.is_empty(): return "请回到"+TravelSystem.location_name(issuer)+"柜台领取。"
	if not office_open(issuer): return "柜台现在已关闭，请在营业时间回来。"
	var owner := issuer_at(issuer)
	if issuer != "dorm" and owner.is_empty(): return "负责签字的人暂时外出，请稍后回来。"
	var id := "proof_"+source_id
	if s.materials.has(id): return "这份证明已经领过。"
	var proof := source.duplicate(true)
	proof.erase("id")
	proof.erase("kind")
	proof.erase("title")
	proof["source_material"] = source_id
	proof["issued_day"] = GameState.current_day
	proof["issued_minute"] = GameState.current_minute
	proof["applicant"] = GameState.current_role
	proof["signature"] = str(ScheduleSystem.residents.get(owner,{}).get("display_name","工作室电子结算单"))
	proof["issuer_npc"] = owner
	proof["work_dates"] = "Day %d" % int(source.day)
	proof["hours"] = "%d 分钟" % int(source.work_minutes) if int(source.get("work_minutes",0)) > 0 else "此项按作品结算"
	proof["share"] = "已结算"
	_add(id,"proof",("收入证明" if source.proof_kind == "income" else "贡献证明")+" · "+str(source.title),proof)
	persist()
	return "证明已放入素材本，领取不会重复发放报酬。"

func residence_proof() -> String:
	var home := "home_a" if GameState.current_role == "A" else "home_b"
	if SceneRouter.active_space_id != home: return "请在自己的住处领取居住确认。"
	_add("residence_confirmation","proof","居住确认",{"source":"home_register","proof_kind":"residence","address":TravelSystem.location_name(GameState.current_location),"dates":"Day 1–7","signature":"住处管理人","issued_day":GameState.current_day})
	persist()
	return "居住确认已收进素材本。"

func can_organize() -> bool:
	return SceneRouter.active_space_id == ("home_a" if GameState.current_role == "A" else "home_b") and GameState.current_minute >= 1080

func page_record_complete(page: Dictionary) -> bool:
	return not str(page.get("today","")).strip_edges().is_empty() and (not str(page.get("record","")).strip_edges().is_empty() or not page.get("keep",[]).is_empty())

func _record_organize() -> void:
	if not can_organize() or not state().packet or GameState.current_day < 1 or GameState.current_day > 7: return
	state().pages[GameState.current_day-1]["organized_at"] = {"day":GameState.current_day,"minute":GameState.current_minute,"space":SceneRouter.active_space_id}

func night_organized(day: int) -> bool:
	if day < 1 or day > 7: return false
	var s := state()
	var page: Dictionary = s.pages[day-1]
	var action: Dictionary = page.get("organized_at",{})
	if action.is_empty() or int(action.get("day",0)) != day or int(action.get("minute",0)) < 1080 or str(action.get("space","")) != ("home_a" if GameState.current_role == "A" else "home_b"): return false
	if not page_record_complete(page) or not bool(page.ledger_checked): return false
	# Day one's taught action is filing a real receipt, not merely opening the desk.
	return day != 1 or page.keep.any(func(id: String) -> bool: return valid_living_receipt(s.materials.get(id,{}),s.ledger))

func set_field(day: int, key: String, value: String) -> bool:
	var s := state()
	if day < 1 or day > mini(7,GameState.current_day) or not s.submitted.is_empty(): return false
	var page: Dictionary = s.pages[day-1]
	if key in ["today","record"]: page[key] = value
	else: page.fields[key] = value
	_record_organize()
	GameState.commit_active_role_state()
	return true

func file_material(id: String, destination: String, require_home := false) -> bool:
	var s := state()
	if not s.packet or not s.materials.has(id) or not s.submitted.is_empty(): return false
	if require_home and not can_organize(): return false
	var item: Dictionary = s.materials[id]
	if item.kind == "official": return false
	if item.kind == "recognition" and not GameState.confirmed_residents.has(str(item.get("resident",""))): return false
	if item.kind == "recognition" and destination.begins_with("day_"):
		return assign_mark(str(item.get("resident","")),int(destination.trim_prefix("day_")))
	if destination.begins_with("day_"):
		var day := int(destination.trim_prefix("day_"))
		if day < 1 or day > mini(7,GameState.current_day): return false
	elif destination not in ["proof","recognition","personal","loose"]: return false
	if destination == "recognition" and item.kind != "recognition": return false
	if item.kind == "recognition" and destination not in ["recognition","loose"]: return false
	for page in s.pages: page.keep.erase(id)
	if item.kind == "recognition":
		for page in s.pages: page.marks.erase(str(item.resident))
	s.filing[id] = destination
	if destination.begins_with("day_"): s.pages[int(destination.trim_prefix("day_"))-1].keep.append(id)
	if item.kind == "photo":
		item["submitted_to_dossier"] = destination != "loose"
		for photo in GameState.artifacts.get("photos",[]):
			if str(photo.get("id","")) == id: photo["submitted_to_dossier"] = destination != "loose"
		var film := get_node_or_null("/root/FilmSystem")
		if destination != "loose" and film != null and film.has_method("mark_photo_use"): film.mark_photo_use(id,"dossier")
	_record_organize()
	persist()
	return true

func assign_mark(resident: String, day: int) -> bool:
	var s := state()
	if not s.packet or not GameState.confirmed_residents.has(resident) or day < 1 or day > mini(7,GameState.current_day) or not s.submitted.is_empty(): return false
	if s.pages[day-1].marks.has(resident): return true
	if s.pages[day-1].marks.size() >= 2: return false
	for page in s.pages: page.marks.erase(resident)
	s.pages[day-1].marks.append(resident)
	var id := _ensure_mark(resident)
	s.filing[id] = "day_%d" % day
	_record_organize()
	persist()
	return true

func check_ledger(day: int) -> void:
	if day < 1 or day > mini(7,GameState.current_day) or not state().submitted.is_empty(): return
	state().pages[day-1].ledger_checked = true
	_record_organize()
	persist()

func set_cover_photo(id: String) -> bool:
	_sync_sources()
	var s := state()
	if id.is_empty():
		s.cover_photo_id = ""
		persist()
		return true
	var item: Dictionary = s.materials.get(id,{})
	if str(item.get("kind","")) != "photo" or str(item.get("status","DEVELOPED")) != "DEVELOPED": return false
	s.cover_photo_id = id
	item["submitted_to_dossier"] = true
	for photo in GameState.artifacts.get("photos",[]):
		if str(photo.get("id",photo.get("photo_id",""))) == id: photo["submitted_to_dossier"] = true
	var library := PhotoLibrary.new()
	library.root_path = str(item.get("library_root",library.root_path))
	library.update_metadata(id,{"submitted_to_dossier":true})
	persist()
	return true

func ledger_for(day: int, s: Dictionary = {}) -> Dictionary:
	if s.is_empty(): s = state()
	var income := 0
	var expense := 0
	var balance := int(s.get("opening_balance",0))
	for row in s.ledger:
		if int(row.day) <= day: balance = int(row.balance)
		if int(row.day) == day:
			if int(row.amount) > 0: income += int(row.amount)
			else: expense -= int(row.amount)
	return {"income":income,"expense":expense,"balance":balance}

func audit(role := "") -> Dictionary:
	if role.is_empty(): role = GameState.current_role
	GameState.commit_active_role_state()
	var role_state: Dictionary = GameState.role_states.get(role,{})
	var s: Dictionary = role_state.get("artifacts",{}).get("residency",{})
	var result := {"packet":false,"pages":false,"income":false,"living_receipts":false,"receipt_categories":false,"ledger":false,"exploration":false,"recognition":false,"recognition_circles":false,"contribution":false,"personal":false,"why_stay":false}
	if s.is_empty(): return {"ready":false,"requirements":result,"missing":result.keys(),"submitted":{}}
	var minimum: Dictionary = content.get("requirements",{})
	result.packet = bool(s.packet)
	var complete := 0
	var ledger := 0
	var income_proofs := 0
	var contribution_proofs := 0
	var living_receipts := 0
	var eligible_receipts := 0
	var receipt_categories: Array = []
	var exploration_kinds: Array = []
	var recognition_circles: Array = []
	var marks: Array = []
	var granted: Array = role_state.get("confirmed_residents",[])
	for page in s.pages:
		if page_record_complete(page): complete += 1
		if bool(page.ledger_checked): ledger += 1
		for mark in page.marks:
			if granted.has(mark) and not marks.has(mark): marks.append(mark)
	result.pages = complete >= int(minimum.get("pages",7))
	result.ledger = ledger >= int(minimum.get("ledger",7))
	for item in s.materials.values():
		if valid_living_receipt(item,s.ledger): eligible_receipts += 1
	for id in s.filing:
		if s.filing[id] == "loose": continue
		var item: Dictionary = s.materials.get(id,{})
		if item.get("kind","") == "recognition" and s.filing[id] == "recognition":
			var resident := str(item.get("resident",""))
			if granted.has(resident) and not marks.has(resident): marks.append(resident)
		if valid_living_receipt(item,s.ledger):
			living_receipts += 1
			if not receipt_categories.has(str(item.category)): receipt_categories.append(str(item.category))
		if valid_exploration(item,s):
			if not exploration_kinds.has(str(item.exploration_kind)): exploration_kinds.append(str(item.exploration_kind))
		if item.get("kind","") != "proof": continue
		var source: Dictionary = s.materials.get(str(item.get("source_material","")),{})
		if item.get("proof_kind","") == "income" and int(source.get("amount",0)) > 0 and s.ledger.any(func(row: Dictionary) -> bool: return str(row.get("source","")) == str(source.get("source","")) and int(row.get("amount",0)) > 0 and str(row.get("kind","")) != "reimbursement" and not str(row.get("reason","")).contains("报销") and not str(row.get("reason","")).contains("初始资金")): income_proofs += 1
		if item.get("proof_kind","") == "contribution" and bool(source.get("contribution_entered_town",false)) and _has_contribution_trace(str(source.get("world_trace_id",""))): contribution_proofs += 1
	for resident in marks:
		var circle := recognition_circle(str(resident))
		if not circle.is_empty() and not recognition_circles.has(circle): recognition_circles.append(circle)
	result.income = income_proofs >= int(minimum.get("income",1))
	result.contribution = contribution_proofs >= int(minimum.get("contribution",1))
	result.living_receipts = living_receipts >= int(minimum.get("living_receipts",3))
	result.receipt_categories = receipt_categories.size() >= int(minimum.get("receipt_categories",2))
	result.recognition = marks.size() >= int(minimum.get("recognition",12))
	result.recognition_circles = recognition_circles.size() >= int(minimum.get("recognition_circles",4))
	result.exploration = exploration_kinds.size() >= int(minimum.get("exploration",3))
	var personal: Dictionary = s.pages[4].fields
	var answered := 0
	for i in range(1,10):
		if not str(personal.get("q%d" % i,"")).strip_edges().is_empty(): answered += 1
	result.personal = answered >= 3 or not str(personal.get("free","")).strip_edges().is_empty() or s.filing.values().has("personal")
	var final_fields: Dictionary = s.pages[6].fields
	result.why_stay = ["why_stay","choice","signature"].all(func(k: String) -> bool: return not str(final_fields.get(k,"")).strip_edges().is_empty())
	var missing: Array = []
	for key in result:
		if not result[key]: missing.append(key)
	var counts := {"packet":int(result.packet),"pages":complete,"income":income_proofs,"living_receipts":living_receipts,"receipt_categories":receipt_categories.size(),"ledger":ledger,"exploration":exploration_kinds.size(),"recognition":marks.size(),"recognition_circles":recognition_circles.size(),"contribution":contribution_proofs,"personal":int(result.personal),"why_stay":int(result.why_stay)}
	var progress: Dictionary = {}
	for key in counts: progress[key] = {"count":counts[key],"target":int(minimum.get(key,1))}
	return {"ready":missing.is_empty(),"requirements":result,"progress":progress,"missing":missing,"submitted":s.submitted,"pages_complete":complete,"recognitions":marks.size(),"recognition_circles":recognition_circles,"receipt_categories":receipt_categories,"collected_living_receipts":eligible_receipts,"exploration_kinds":exploration_kinds}

func valid_exploration(item: Dictionary, s: Dictionary = {}) -> bool:
	if s.is_empty(): s = state()
	if item.get("kind","") != "exploration" or str(item.get("text","")).strip_edges().is_empty(): return false
	var kind := str(item.get("exploration_kind",""))
	if kind not in ["discover","revisit","shareplace"]: return false
	var history: Array = s.get("visit_history",{}).get(str(item.get("location","")),[])
	if history.is_empty(): return false
	if kind != "revisit": return true
	var periods: Array = []
	for row in item.get("visits",[]):
		if history.any(func(actual: Dictionary) -> bool: return int(actual.day) == int(row.get("day",0)) and int(actual.minute) == int(row.get("minute",-1))):
			var period := str(row.get("period",""))
			if not period.is_empty() and not periods.has(period): periods.append(period)
	return periods.size() >= 2

func submit() -> Dictionary:
	var s := state()
	if not s.submitted.is_empty(): return {"ok":false,"message":"这份档案已提交。"}
	if GameState.current_day != 7 or GameState.current_minute >= 1080: return {"ok":false,"message":"提交时间是 Day 7 · 09:00–18:00。"}
	if GameState.current_location != "print_shop" or SceneRouter.active_space_id != "print_studio" or not office_open(): return {"ok":false,"message":"请到社区中心柜台交件。"}
	var review := audit()
	if not review.ready: return {"ok":false,"message":"还需要补齐标出的材料。","audit":review}
	var choice := str(s.pages[6].fields.get("choice","还没想好"))
	var outcome := "申请材料已受理。你为留下做出了自己的选择。"
	if choice.contains("离开"): outcome = "材料已存档。你选择离开，这七天仍属于你。"
	elif choice.contains("没") or choice.contains("清楚"): outcome = "材料已存档。你为自己保留了继续考虑的时间。"
	s.submitted = {"day":7,"minute":GameState.current_minute,"role":GameState.current_role,"choice":choice,"outcome":outcome,"snapshot":{"pages":s.pages.duplicate(true),"filing":s.filing.duplicate(true)}}
	persist()
	return {"ok":true,"message":outcome}

func submit_free_application() -> Dictionary:
	var s := state()
	if not s.submitted.is_empty(): return {"ok":false,"message":"申请已经提交。"}
	if GameState.current_day < 7: return {"ok":false,"message":"先把这七天好好过完，第七天再提交。"}
	var pages: Dictionary = s.get("free_pages",{})
	if pages.get("personal",[]).is_empty(): return {"ok":false,"message":"个人信息页还没有留下你的表达。"}
	if pages.get("life",[]).is_empty(): return {"ok":false,"message":"生活记录页还没有留下生活材料。"}
	if GameState.confirmed_residents.size()<12: return {"ok":false,"message":"还有居民等着认识你。"}
	for d in range(1,8):
		if pages.get("day_%d" % d,[]).is_empty(): return {"ok":false,"message":"Day %02d 的作品页还是空白。" % d}
	var answers: Dictionary = s.get("final_answers",{})
	for key in ["0","1","2","3","4","signature"]:
		if str(answers.get(key,"")).strip_edges().is_empty(): return {"ok":false,"message":"请补完最终文件，并留下签名。"}
	var application_pages := pages.duplicate(true)
	application_pages.erase("notebook")
	s.submitted={"day":GameState.current_day,"minute":GameState.current_minute,"role":GameState.current_role,"outcome":"你的申请已收到。谢谢你把这七天留给 Solmere。","snapshot":{"free_pages":application_pages,"final_answers":answers.duplicate(true)}}
	persist()
	return {"ok":true,"message":s.submitted.outcome}

func add_note(text: String, revision_of := "", mark := "") -> String:
	if text.strip_edges().is_empty(): return ""
	var id := "note_"+Crypto.new().generate_random_bytes(8).hex_encode()
	_add(id,"note","私人笔记",{"text":text,"revision_of":revision_of,"mark":mark,"source":"player"})
	if not revision_of.is_empty(): state().annotations.append({"from":revision_of,"to":id,"mark":"crossout","day":GameState.current_day})
	persist()
	return id
