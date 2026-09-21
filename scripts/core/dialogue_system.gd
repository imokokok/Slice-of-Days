extends Node
signal dialogue_line_presented(context: Dictionary)

func present_line(context: Dictionary) -> void:
	context = context.duplicate()
	context["npc_id"] = str(context.get("npc", ""))
	context["speaker_id"] = GameState.current_role if str(context.get("speaker", "")) == "player" else str(context.get("npc", ""))
	context["location_id"] = str(context.get("location", GameState.current_location))
	context["event_id"] = str(context.get("event_id", ""))
	context["protagonist_id"] = GameState.current_role
	context["time_of_day"] = GameState.current_minute
	context["flags"] = {"argument_seen":bool(argument_state().get("seen", false)), "argument_finished":bool(argument_state().get("finished", false))}
	context["world_state"] = context["flags"].duplicate()
	dialogue_line_presented.emit(context)

var content: Dictionary = {}
var invitations: Array = []
var linear_stories: Dictionary = {}
var relationship_notes: Array = []
const ARGUMENT_PEOPLE := ["wu_wu", "chenyuan"]
const ARGUMENT_LINGER_MINUTES := 90

func argument_state() -> Dictionary:
	var key := "market_argument_" + GameState.current_role
	var state: Dictionary = GameState.shared_state.get(key, {})
	if state.is_empty():
		state = {"seen":false, "finished":false}
		# Earlier saves already contain the completed market conversation.
		for day in range(1, 8):
			var legacy := "market_encounter_%s_%d" % [GameState.current_role, day]
			if bool(GameState.shared_state.get(legacy, false)): state.seen = true
			if bool(GameState.shared_state.get(legacy + "_done", false)):
				state.merge({"seen":true,"finished":true,"day":day,"minute":-ARGUMENT_LINGER_MINUTES}, true)
		GameState.shared_state[key] = state
	return state

func argument_pending() -> bool:
	# The old per-day encounter marker was written as soon as the overlay opened.
	# It therefore cannot decide whether the optional conversation was actually
	# completed: leaving early keeps it available for another voluntary interaction.
	return not bool(argument_state().get("finished", false))

func mark_argument(finished: bool) -> void:
	var state := argument_state()
	state.seen = true
	if finished:
		state.merge({"finished":true,"day":GameState.current_day,"minute":GameState.current_minute}, true)
		for person in ARGUMENT_PEOPLE: RelationshipSystem.add_flags(person, ["post_argument"])
	GameState.shared_state["market_argument_" + GameState.current_role] = state
	GameState.shared_state["argument_seen"] = true
	GameState.shared_state["argument_finished"] = bool(state.get("finished", false))

func argument_lingering() -> bool:
	var state := argument_state()
	return bool(state.get("finished", false)) and int(state.get("day", 0)) == GameState.current_day and GameState.current_minute < int(state.get("minute", 0)) + ARGUMENT_LINGER_MINUTES

func people_at(location: String) -> Array[String]:
	var people := ScheduleSystem.residents_at(location, GameState.current_day, GameState.current_minute)
	for person in ARGUMENT_PEOPLE: people.erase(person)
	if bool(argument_state().get("finished", false)):
		for person in ARGUMENT_PEOPLE:
			var destination := "produce_stall" if argument_lingering() else str(ScheduleSystem.activity_at(person, GameState.current_day, GameState.current_minute).get("location", ""))
			if destination == location: people.push_front(person)
	# Keep the actual vendor reachable even on a crowded market day.
	if people.has("beetman"):
		people.erase("beetman")
		people.push_front("beetman")
	return people

func conversation_id(npc: String, topic: String) -> String:
	var count := int(GameState.shared_state.get("linear_talk_counts_" + GameState.current_role, {}).get(npc, 0))
	var state := "post_argument" if npc in ARGUMENT_PEOPLE and bool(argument_state().get("finished", false)) else topic
	return "%s.%s.%d" % [npc, state, count]
func _ready() -> void:
	linear_stories = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/linear_conversations.json"))
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
	var relationship_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/relationships.json"))
	if relationship_data is Dictionary:
		relationship_notes = relationship_data.get("relationships", [])
func reply(npc: String, topic: String) -> Array[String]:
	var row: Dictionary = content.get(npc,{})
	var activity := ScheduleSystem.activity_at(npc,GameState.current_day,GameState.current_minute)
	if npc in ARGUMENT_PEOPLE and argument_lingering():
		activity = {"location":"produce_stall","end":int(argument_state().get("minute",0))+ARGUMENT_LINGER_MINUTES,"activity":"收好刚买的菜"}
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
			lines = ["沿着这条街一直往右，走过公交站和停车的地方，就能看见海了。", "观景台晚上九点开门。我喜欢早一点过去，坐在门边听听浪声。"]
			KnowledgeSystem.learn({"id":"lookout_hours","subject_id":"park","predicate":"opens_at","value":1260,"source_npc_id":npc,"confidence":1.0,"text":"观景台 · 21:00 开放 · 沿街一直往右走"})
		"schedule_info":
			if npc == "grocery":
				lines = ["每天早上八点到晚上十点，我都在柜台。", "餐厅采购要留小票。摄影柜台的接件时间写在旁边。"]
				KnowledgeSystem.learn({"id":"grocery_hours","subject_id":"cafe","predicate":"hours","value":[480,1320],"source_npc_id":npc,"confidence":1.0,"status":"Confirmed","text":"杂货店 · 08:00—22:00 · 日用品、采购、旧物、摄影"})
			elif npc in ["zhou_xiaoliu","xanni"]:
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
		"relationship_followup": lines = _relationship_lines(npc)
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

func _relationship_lines(npc: String) -> Array[String]:
	for note in relationship_notes:
		var people: Array = note.get("people", [])
		if people.has(npc):
			var others: Array[String] = []
			for person in people:
				if str(person) != npc:
					others.append(str(ScheduleSystem.residents.get(str(person), {}).get("display_name", person)))
			return ["我和%s是%s。" % ["、".join(others), str(note.get("kind", "熟人"))], str(note.get("summary", "我们偶尔会聊起共同经历的事。"))]
	return ["我记得我们聊过。", "不用每次都带一个结果来，路过打声招呼也好。"]

func linear_conversation(npc: String) -> Array:
	var counts: Dictionary = GameState.shared_state.get("linear_talk_counts_"+GameState.current_role,{})
	var count := int(counts.get(npc,0))
	var row: Dictionary = linear_stories.get(npc,{})
	if npc in ARGUMENT_PEOPLE and bool(argument_state().get("finished", false)):
		var post: Array = row.get("post_argument_smalltalk", [])
		if not post.is_empty(): return post[count % post.size()].duplicate(true)
	var episodes: Array = row.get("episodes",[])
	if not episodes.is_empty():
		var beats: Array = (episodes[count % episodes.size()] if bool(row.get("rotate", false)) else episodes[count] if count < episodes.size() else row.get("after",episodes.back())).duplicate(true)
		var remembered := EconomySystem.remembered_line(npc)
		if npc=="wu_wu" and ResidencySystem.state().visits.has("record_store") and KnowledgeSystem.facts().any(func(f: Dictionary) -> bool: return str(f.get("id",""))=="cici_record_store"):
			remembered="你去过唱片店了？我就知道，你们能聊到一块儿。下回路过，可以把新录的声音带上。"
		if not remembered.is_empty(): beats.push_front(["npc", remembered])
		if npc == "zhou_xiaoliu" and count == 0:
			if GameState.current_role == "A":
				beats[3][1] = "你不能先给自己放个假吗？"
				beats[4][1] = "能。我休一天，房租可不会休。等钱到账吧。"
			else: beats[3][1] = "一单后面还有一单，什么时候算忙完？"
		return beats
	var activity := ScheduleSystem.activity_at(npc,GameState.current_day,GameState.current_minute)
	var authored: Array = activity.get("dialogue",{}).get("greeting",[])
	if authored.is_empty():
		var personal := ResidentProfileSystem.ambient_line(npc,GameState.current_role,GameState.current_day+count)
		authored = [personal if not personal.is_empty() else str(content.get(npc,{}).get("greeting","今天也在附近走走吗？")), "手边这件事还没弄完。你不赶时间的话，可以在这儿坐会儿。"]
	var result: Array = []
	for line in authored: result.append(["npc",str(line)])
	return result

func complete_linear_conversation(npc: String) -> void:
	CoreLoopSystem.encounter(npc)
	EconomySystem.chat_completed(npc)
	var key := "linear_talk_counts_"+GameState.current_role
	var counts: Dictionary = GameState.shared_state.get(key,{})
	counts[npc] = int(counts.get(npc,0))+1
	GameState.shared_state[key] = counts
	var encounter_id := "chat_%d_%s_%s" % [GameState.current_day,GameState.current_role,npc]
	if not GameState.has_event(encounter_id):
		RelationshipSystem.record_encounter(npc,encounter_id,["认真听完了一次谈话"])
		GameState.mark_event(encounter_id)

func invitation_for(npc: String) -> Dictionary:
	var activity := ScheduleSystem.activity_at(npc,GameState.current_day,GameState.current_minute)
	if not bool(activity.get("allows_invitation", true)): return {}
	for offer in invitations:
		if bool(offer.get("encounter",false)): continue
		if str(offer.npc) == npc and str(offer.location) == GameState.current_location and str(ScheduleSystem.activity_at(npc,GameState.current_day,GameState.current_minute).get("location","")) == GameState.current_location: return offer
	return {}
func invitation_for_module(module_id: String) -> Dictionary:
	for offer in invitations:
		if str(offer.module) == module_id: return offer
	return {}

func should_invite(npc: String) -> bool:
	var offer := invitation_for(npc)
	return not offer.is_empty() and not invitation_accepted(str(offer.module)) and not GameState.shared_state.get("invitations_heard",{}).has("%s_%d_%s" % [GameState.current_role,GameState.current_day,npc])

func mark_invitation_heard(npc: String, persist := true) -> void:
	var invitation := invitation_for(npc)
	if not invitation.is_empty():
		# Called only after the invitation has actually been heard.
		var fact := {"id":"invite_"+str(invitation.module),"text":str(invitation.label),"source_npc_id":npc,"subject_id":str(invitation.location),"predicate":"lead","confidence":1.0,"learned_day":GameState.current_day}
		var facts: Array=GameState.shared_state.get("knowledge_"+GameState.current_role,[])
		if not facts.any(func(row: Dictionary) -> bool: return row.get("id","")==fact.id): facts.append(fact)
		GameState.shared_state["knowledge_"+GameState.current_role]=facts
	var heard: Dictionary = GameState.shared_state.get("invitations_heard",{})
	heard["%s_%d_%s" % [GameState.current_role,GameState.current_day,npc]] = true
	GameState.shared_state["invitations_heard"] = heard
	if persist: SaveManager.save_or_report("记录邀请后保存失败")
func invitation_accepted(module_id: String) -> bool:
	return GameState.shared_state.get("accepted_invitations",{}).has("%s_%d_%s" % [GameState.current_role,GameState.current_day,module_id])
func accept_invitation(npc: String, persist := true) -> Dictionary:
	var offer := invitation_for(npc)
	if offer.is_empty(): return {}
	var accepted: Dictionary = GameState.shared_state.get("accepted_invitations",{})
	accepted["%s_%d_%s" % [GameState.current_role,GameState.current_day,str(offer.module)]] = offer.duplicate(true)
	GameState.shared_state["accepted_invitations"] = accepted
	var name := str(ScheduleSystem.residents[npc].display_name)
	GameState.add_journal_entry({"kind":"invitation","text":name + "邀请我：" + str(offer.label)})
	if persist: SaveManager.save_or_report("接受邀请后保存失败")
	return offer

func notebook_leads() -> Array:
	var notes: Array = []
	var prompts := {"cooking":"想听听厨房里的声音，去饭店找史勇奇聊聊今天的菜。", "ghostwriting":"去书信事务所见见 Mossner，问问桌上那封没写完的信。", "sound_sampling":"带着路上听到的声音，去唱片店跟 Xanni 聊聊。", "tarot":"去塔罗店找夏透明，听听那副旧牌的故事。", "chess":"傍晚去棋摊找闹闹，问问对面的位子有没有人。", "translation":"买菜时和 BEETMAN 聊聊，听说摊边有人把话说岔了。", "contemplation":"晚上九点以后去观景台，遇见余星晴就问问他在看哪片天空。"}
	for offer in invitations:
		var accepted := invitation_accepted(str(offer.module))
		if bool(offer.get("encounter",false)):
			notes.append({"kind":"note","heading":"路上听见的事","text":"买菜摊旁，两个人为了晚饭争执起来。走近听听他们各自在意什么。","place":"produce_stall"})
			continue
		var name := str(ScheduleSystem.residents.get(str(offer.npc),{}).get("display_name",offer.npc))
		var note := str(prompts.get(str(offer.module),""))
		if accepted:
			note = name + "邀我：" + str(offer.accept) + "\n到" + TravelSystem.location_name(str(offer.location)) + ("，再找对方聊起这件事。" if bool(offer.launch) else "，走到台边再开始。")
		notes.append({"kind":"note","heading":"答应的事" if accepted else "想去聊聊","text":note,"place":str(offer.location)})
	return notes
