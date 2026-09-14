extends Node
var content: Dictionary = {}
var invitations: Array = []
func _ready() -> void:
	var invitation_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/minigame_invitations.json"))
	if invitation_data is Dictionary:
		invitations = invitation_data.get("invitations", [])
	else:
		push_error("Invalid minigame invitation data")
	var conversation_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/conversations.json"))
	if conversation_data is Dictionary:
		content = conversation_data
	else:
		push_error("Invalid conversation data")
func reply(npc: String, topic: String) -> Array[String]:
	var row: Dictionary = content.get(npc,{})
	var activity := ScheduleSystem.activity_at(npc,GameState.current_day,GameState.current_minute)
	var mood := ScheduleSystem.mood_at(npc,GameState.current_day,GameState.current_minute)
	var history: Array = GameState.shared_state.get("dialogue_history_"+GameState.current_role,[])
	var repeated := history.any(func(h: Dictionary) -> bool: return str(h.get("npc","")) == npc and str(h.get("topic","")) == topic and int(h.get("day",0)) == GameState.current_day)
	var lines: Array[String] = []
	match topic:
		"greeting": lines = [str(row.get("greeting","你好，今天的风有点大。")), "又见面了。刚才那件事后来怎样了？" if repeated else "你也在附近走走吗？"]
		"daily_state": lines = ["我正忙着%s。" % str(activity.get("activity","手边的事")), "等我忙完这一阵，再好好聊。" if mood == "busy" else "今天有点累，想慢一点。" if mood == "tired" else "现在倒是不赶时间。"]
		"small_talk": lines = ["你听，街角又有人在试那段旋律。", "有时候只听到几个音，也会跟着哼一整天。"]
		"personal_topic": lines = [str(row.get("personal","我今天想把手边这件事做完。")), "你呢？最近有没有什么一直惦记的事？"]
		"town_info", "location_info":
			lines = ["观景台在海边高处，从公共区域走过去大约四十五分钟。", "晚上九点才开放。可以从公交站坐车，先看一眼班次。"]
			KnowledgeSystem.learn({"id":"lookout_hours","subject_id":"park","predicate":"opens_at","value":1260,"source_npc_id":npc,"confidence":1.0,"text":"观景台 · 21:00 开放 · 公共区域步行约45分钟"})
		"schedule_info":
			if npc in ["zhou_xiaoliu","xanni"]:
				lines.assign(["我一般十一点半过来，七点半左右收店。", "要去排练的话，我会早一点收设备。你要是看见我还在绕线，进来打个招呼就好。"] if npc == "xanni" else ["你想找 Xanni？她一般十一点半到唱片店，晚上七点半左右收店。", "我有时赶上她收线，就站门口等她一会儿。她一边绕线，还能一边跟你聊。"])
				KnowledgeSystem.learn({"id":"xanni_hours","subject_id":"xanni","predicate":"schedule","value":[690,1170],"source_npc_id":npc,"confidence":0.95,"text":"Xanni · 唱片店 · 11:30—19:30，偶有排练调整"})
			elif not activity.is_empty():
				lines = ["我还会在这儿待一会儿。", "大概到 %02d:%02d 吧。你要回来找我，这之前来就好。" % [int(activity.end)/60,int(activity.end)%60]]
				KnowledgeSystem.learn({"id":npc+"_schedule","subject_id":npc,"predicate":"schedule","value":activity,"source_npc_id":npc,"confidence":0.9,"text":"%s · %s · 今天到%02d:%02d" % [str(ScheduleSystem.residents[npc].display_name),TravelSystem.location_name(str(activity.location)),int(activity.end)/60,int(activity.end)%60]})
			else: lines = ["我今天还没有想好下一站。", "等确定了再告诉你。"]
		"npc_info", "rumor":
			lines = [str(row.get("rumor","我好像在公共区域见过尘缘，记不清是今天还是昨天。")), "你碰见他的时候，还是自己问问吧。"]
		"minigame_hook":
			var offer := invitation_for(npc)
			if offer.is_empty(): lines = ["眼下没有什么要麻烦你的。你可以先在附近转转。"]
			else: lines.assign(offer.lines)
		"relationship_followup": lines = ["我记得我们聊过。", "不用每次都带一个结果来，路过打声招呼也好。"]
		"recognition_related":
			var result := RelationshipSystem.request_confirmation_action(npc)
			lines = [str(result.get("message","我想再考虑一下。"))]
		_: lines = ["那你先走，回头见。"]
	var variants: Array = row.get("authored",{}).get(topic,[])
	if not variants.is_empty():
		var count := history.filter(func(h: Dictionary) -> bool: return str(h.get("npc","")) == npc and str(h.get("topic","")) == topic).size()
		lines.assign(variants[count % variants.size()])
	var activity_lines: Array = activity.get("dialogue", {}).get(topic, [])
	if not activity_lines.is_empty(): lines.assign(activity_lines)
	if topic in ["rumor","npc_info"]:
		KnowledgeSystem.learn({"id":npc+"_recollection","subject_id":npc,"predicate":"recollection","value":lines.duplicate(),"source_npc_id":npc,"confidence":0.6,"text":"听"+str(ScheduleSystem.residents.get(npc,{}).get("display_name",npc))+"说："+" ".join(lines)+"（对方的回忆，未核实）"})
	if mood == "busy" and topic == "personal_topic": lines = ["等我一下，手上这点还没弄完。", "这事我想慢慢跟你说，晚点再聊，行吗？"]
	var encounter_id := "chat_%d_%s_%s" % [GameState.current_day,GameState.current_role,npc]
	if topic == "greeting" and not GameState.has_event(encounter_id):
		RelationshipSystem.record_encounter(npc,encounter_id,["认真听完了一次谈话"])
		GameState.mark_event(encounter_id)
	history.append({"npc":npc,"topic":topic,"day":GameState.current_day,"minute":GameState.current_minute,"lines":lines})
	GameState.shared_state["dialogue_history_"+GameState.current_role] = history.slice(maxi(0,history.size()-80))
	SaveManager.save_or_report("对话后保存失败")
	return lines

func invitation_for(npc: String) -> Dictionary:
	var activity := ScheduleSystem.activity_at(npc,GameState.current_day,GameState.current_minute)
	if not bool(activity.get("allows_invitation", true)): return {}
	for offer in invitations:
		if str(offer.npc) == npc and str(offer.location) == GameState.current_location and str(ScheduleSystem.activity_at(npc,GameState.current_day,GameState.current_minute).get("location","")) == GameState.current_location: return offer
	return {}
func invitation_for_module(module_id: String) -> Dictionary:
	for offer in invitations:
		if str(offer.module) == module_id: return offer
	return {}

func should_invite(npc: String) -> bool:
	var offer := invitation_for(npc)
	return not offer.is_empty() and not invitation_accepted(str(offer.module)) and not GameState.shared_state.get("invitations_heard",{}).has("%s_%d_%s" % [GameState.current_role,GameState.current_day,npc])

func mark_invitation_heard(npc: String) -> void:
	var heard: Dictionary = GameState.shared_state.get("invitations_heard",{})
	heard["%s_%d_%s" % [GameState.current_role,GameState.current_day,npc]] = true
	GameState.shared_state["invitations_heard"] = heard
	SaveManager.save_or_report("记录邀请后保存失败")
func invitation_accepted(module_id: String) -> bool:
	return GameState.shared_state.get("accepted_invitations",{}).has("%s_%d_%s" % [GameState.current_role,GameState.current_day,module_id])
func accept_invitation(npc: String) -> Dictionary:
	var offer := invitation_for(npc)
	if offer.is_empty(): return {}
	var accepted: Dictionary = GameState.shared_state.get("accepted_invitations",{})
	accepted["%s_%d_%s" % [GameState.current_role,GameState.current_day,str(offer.module)]] = offer.duplicate(true)
	GameState.shared_state["accepted_invitations"] = accepted
	var name := str(ScheduleSystem.residents[npc].display_name)
	GameState.add_journal_entry({"kind":"invitation","text":name + "邀请我：" + str(offer.label)})
	SaveManager.save_or_report("接受邀请后保存失败")
	return offer

func notebook_leads() -> Array:
	var notes: Array = []
	var prompts := {"cooking":"想听听厨房里的声音，去饭店找史勇奇聊聊今天的菜。", "ghostwriting":"去书信事务所见见 Mossner，问问桌上那封没写完的信。", "sound_sampling":"带着路上听到的声音，去唱片店跟 Xanni 聊聊。", "tarot":"去塔罗店找夏透明，听听那副旧牌的故事。", "chess":"傍晚去棋摊找闹闹，问问对面的位子有没有人。", "translation":"买菜时和 BEETMAN 聊聊，听说摊边有人把话说岔了。", "contemplation":"晚上九点以后去观景台，遇见余星晴就问问他在看哪片天空。"}
	for offer in invitations:
		var accepted := invitation_accepted(str(offer.module))
		var name := str(ScheduleSystem.residents.get(str(offer.npc),{}).get("display_name",offer.npc))
		var note := str(prompts.get(str(offer.module),""))
		if accepted:
			note = name + "邀我：" + str(offer.accept) + "\n到" + TravelSystem.location_name(str(offer.location)) + ("，再找对方聊起这件事。" if bool(offer.launch) else "，走到台边再开始。")
		notes.append({"kind":"note","heading":"答应的事" if accepted else "想去聊聊","text":note,"place":str(offer.location)})
	return notes
