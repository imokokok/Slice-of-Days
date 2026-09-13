extends Node
var content: Dictionary = {}
func _ready() -> void:
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/conversations.json"))
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
				lines = ["Xanni 十一点半以后在唱片店，晚上七点半左右收店。", "这是店门上的时间。她要去排练的话，可能提前把设备收好。"]
				KnowledgeSystem.learn({"id":"xanni_hours","subject_id":"xanni","predicate":"schedule","value":[690,1170],"source_npc_id":npc,"confidence":0.95,"text":"Xanni · 唱片店 · 11:30—19:30，偶有排练调整"})
			elif not activity.is_empty():
				lines = ["今天这段时间我会在%s。" % TravelSystem.location_name(str(activity.location)), "我大概待到 %02d:%02d。之后还要做别的事。" % [int(activity.end)/60,int(activity.end)%60]]
				KnowledgeSystem.learn({"id":npc+"_schedule","subject_id":npc,"predicate":"schedule","value":activity,"source_npc_id":npc,"confidence":0.9,"text":"%s · %s · 今天到%02d:%02d" % [str(ScheduleSystem.residents[npc].display_name),TravelSystem.location_name(str(activity.location)),int(activity.end)/60,int(activity.end)%60]})
			else: lines = ["我今天还没有想好下一站。", "等确定了再告诉你。"]
		"npc_info", "rumor":
			lines = [str(row.get("rumor","我好像在公共区域见过尘缘，记不清是今天还是昨天。")), "你碰见他的时候，还是自己问问吧。"]
			KnowledgeSystem.learn({"id":"chenyuan_rumor","subject_id":"chenyuan","predicate":"seen","value":"下午 · 公共区域附近","source_npc_id":npc,"confidence":0.45,"text":"尘缘 / 下午 / 公共区域附近，日期未确认"})
		"minigame_hook": lines = ["走到工作台边，才知道一件事做起来是什么样。", "门口和物件旁边会有提示。坐下来之前，先看看需要多久。"]
		"relationship_followup": lines = ["我记得我们聊过。", "不用每次都带一个结果来，路过打声招呼也好。"]
		"recognition_related":
			var result := RelationshipSystem.request_confirmation(npc)
			lines = [str(result.get("message","我想再考虑一下。"))]
		_: lines = ["那你先走，回头见。"]
	if mood == "busy" and topic == "personal_topic": lines = ["现在有点忙，这件事我想晚点再聊。", "你可以先问问路或者开门时间。"]
	var encounter_id := "chat_%d_%s_%s" % [GameState.current_day,GameState.current_role,npc]
	if topic == "greeting" and not GameState.has_event(encounter_id):
		RelationshipSystem.record_encounter(npc,encounter_id,["认真听完了一次谈话"])
		GameState.mark_event(encounter_id)
	history.append({"npc":npc,"topic":topic,"day":GameState.current_day,"minute":GameState.current_minute,"lines":lines})
	GameState.shared_state["dialogue_history_"+GameState.current_role] = history.slice(maxi(0,history.size()-80))
	SaveManager.save_game()
	return lines
