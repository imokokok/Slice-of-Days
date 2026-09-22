extends Control
## Real story and transaction flow; DialogueCard owns only its presentation.
signal closed
signal purchase_requested
var shop_id := ""
var shop_name := ""
var npc := ""
var starting_topic := "greeting"
var offer: Dictionary = {}
var lines: Array[String] = []
var speakers: Array[String] = []
var index := 0
var text_label: Label
var speaker_label: Label
var progress := 0.0
var typewriter := true
var closing := false
var commit_retry := false
var records_story := false
var speech_card: Panel
var punctuation_delay := 0.0
var line_ids: Array[String] = []
var dialogue_id := ""
var hint_label: Label
var vendor_choices: VBoxContainer
var vendor_committed := false
var shopping := false
var offer_decided := false
var offer_accepted := false
var encounter_choice := false
var encounter_finished := false
var shared_choice_offered := false

func _ready() -> void:
	add_to_group("meta_dialogue")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	speech_card = preload("res://scripts/ui/components/dialogue_card.gd").new()
	add_child(speech_card)
	var scene := get_tree().current_scene
	var stage: Control = scene.get("street") if scene.get("street")!=null else scene.get("stage")
	speech_card.configure(stage,npc)
	speaker_label = speech_card.speaker_label
	text_label = speech_card.text_label
	hint_label = speech_card.hint_label
	hint_label.text = SettingsSystem.binding_text("dialogue_advance")+" 继续 · "+SettingsSystem.binding_text("ui_cancel")+" 离开"
	typewriter = bool(GameState.shared_state.get("typewriter",true)) and not SettingsSystem.reduced_motion()
	if shop_id.is_empty() or npc in ["beetman", "grocery"]:
		_build_conversation()
	else:
		var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy/shops.json"))
		for shop in catalog.get("shops",[]):
			if str(shop.id) == shop_id:
				shop_name = str(shop.get("owner_name","店老板"))
				_append("npc",str(shop.get("greeting","今天想买点什么？")))
	if lines.is_empty(): _append("npc","今天也出来走走？")
	_show_line()

func _append(speaker: String, text: String) -> void:
	var remaining := text
	while remaining.length() > 52:
		var cut := 52
		for i in range(51,25,-1):
			if remaining[i] in ["。","，","；","！","？"]: cut = i+1; break
		speakers.append(speaker)
		line_ids.append(dialogue_id + "." + str(lines.size()))
		lines.append(remaining.left(cut))
		remaining = remaining.substr(cut)
	speakers.append(speaker)
	line_ids.append(dialogue_id + "." + str(lines.size()))
	lines.append(remaining)

func _build_conversation() -> void:
	dialogue_id = DialogueSystem.conversation_id(npc, starting_topic)
	records_story = starting_topic == "greeting"
	if records_story:
		for beat in CoreLoopSystem.dialogue_prefix(npc): _append(str(beat[0]),str(beat[1]))
	if records_story and npc=="wu_wu" and int(GameState.shared_state.get("linear_talk_counts_"+GameState.current_role,{}).get(npc,0))==0:
		encounter_choice=true
		_append("npc","它平时没这么喜欢陌生人。刚才还躲在我腿后面。")
		return
	if records_story:
		for beat in DialogueSystem.linear_conversation(npc): _append(str(beat[0]),str(beat[1]))
	elif starting_topic != "minigame_hook":
		for line in DialogueSystem.reply(npc,starting_topic): _append("npc",line)
	if starting_topic == "minigame_hook" or (records_story and DialogueSystem.should_invite(npc)):
		offer = DialogueSystem.invitation_for(npc)
		for line in offer.get("lines",[]): _append("npc",str(line))

	if lines.is_empty(): _append("npc","我先把手边收拾好。你想试的时候再过来。")

func _show_line() -> void:
	var speaker := speakers[index]
	speaker_label.text = LocalizationSystem.text("你" if speaker == "player" else "" if speaker == "narrator" else shop_name if not shop_name.is_empty() else str(ScheduleSystem.residents.get(npc,{}).get("display_name",npc)))
	text_label.text = LocalizationSystem.text(lines[index])
	speech_card.layout(true)
	DialogueSystem.present_line({"npc":npc,"speaker":speaker,"text":lines[index],"index":index,"total":lines.size(),"location":GameState.current_location,"owner":self,"conversation_id":get_instance_id(),"dialogue_id":dialogue_id,"line_id":line_ids[index],"topic":starting_topic})
	progress = 0
	punctuation_delay = .16
	text_label.visible_characters = 0 if typewriter else -1

func _advance() -> void:
	if closing or shopping or is_instance_valid(vendor_choices): return
	if commit_retry: _finish(); return
	if typewriter and text_label.visible_characters >= 0 and text_label.visible_characters < text_label.text.length():
		progress = text_label.text.length()
		text_label.visible_characters = -1
		return
	WorldSound.play_ui("dialogue")
	index += 1
	if index < lines.size(): _show_line()
	else: _finish()

func _finish() -> void:
	if closing: return
	if encounter_choice and not encounter_finished:
		_show_encounter_choices(); return
	if not offer.is_empty() and not offer_decided:
		_show_invitation_choices(); return
	if records_story and not shared_choice_offered:
		shared_choice_offered=true
		var materials := CoreLoopSystem.share_candidates(npc)
		if not materials.is_empty():
			_choice_box([["给你看看《"+str(materials[0].title)+"》",str(materials[0].id)],["下次再带给你看。",""]],_share_loop_material)
			return
	if npc in ["beetman", "grocery"] and not shop_id.is_empty():
		if not vendor_committed:
			var before := GameState.to_save_data().duplicate(true)
			if records_story: DialogueSystem.complete_linear_conversation(npc)
			if not SaveManager.save_or_report("保存谈话失败"):
				GameState.load_save_data(before)
				commit_retry = true
				text_label.text = LocalizationSystem.text("这段谈话暂时没能保存，按空格重试。")
				text_label.visible_characters = -1
				return
			vendor_committed = true
			commit_retry = false
		_show_vendor_choices()
		return
	if not shop_id.is_empty():
		purchase_requested.emit()
		_close()
		return
	var snapshot := GameState.to_save_data().duplicate(true)
	if records_story: DialogueSystem.complete_linear_conversation(npc)
	if encounter_finished:
		var facts: Array=GameState.shared_state.get("knowledge_"+GameState.current_role,[])
		if not facts.any(func(row: Dictionary) -> bool: return str(row.get("id",""))=="cici_record_store"):
			facts.append({"id":"cici_record_store","text":"Cici 说 Xanni 会听路上录到的声音，可以带去唱片店。","source_npc_id":npc,"subject_id":"record_store","predicate":"lead","confidence":1.0,"learned_day":GameState.current_day})
		GameState.shared_state["knowledge_"+GameState.current_role]=facts
	if not offer.is_empty():
		DialogueSystem.mark_invitation_heard(npc,false)
		if offer_accepted: DialogueSystem.accept_invitation(npc,false)
	if not SaveManager.save_or_report("保存谈话失败"):
		GameState.load_save_data(snapshot)
		commit_retry = true
		speaker_label.text = ""
		text_label.text = LocalizationSystem.text("这段谈话暂时没能保存，点击或按空格重试。")
		text_label.visible_characters = -1
		return
	# Only walking up to a game point requests entry. Casual chat returns to walking.
	if starting_topic == "minigame_hook" and offer_accepted and bool(offer.get("launch",false)):
		var minutes := int(GameplayModuleSystem.modules.get(str(offer.module),{}).get("direct_time_minutes",0))
		if GameState.can_fit_now(minutes): SceneRouter.gameplay_module(str(offer.module),"street:"+GameState.current_location+":invitation:"+npc)
	_close()

func _close() -> void:
	if closing: return
	closing = true
	speech_card.dismiss()
	closed.emit()
	queue_free()

func _share_loop_material(id: String) -> void:
	_clear_choices()
	if id.is_empty(): _finish(); return
	var result := CoreLoopSystem.share_material(npc,id)
	_append("npc",str(result.message)); index=lines.size()-1; _show_line()

func _show_vendor_choices() -> void:
	if is_instance_valid(vendor_choices): return
	speaker_label.text = LocalizationSystem.text("BEETMAN" if npc == "beetman" else "杂货店老板")
	text_label.text = LocalizationSystem.text("我就在摊边。你想接着聊，还是看看今天的罐头？" if npc == "beetman" else "你慢慢看。想买什么、冲照片，或者再说几句都可以。")
	text_label.visible_characters = -1
	var options := [["再聊一会儿 · 15分钟", "chat"], ["看看今天的罐头" if npc == "beetman" else "看看货架", "shop"], ["问点事 · 5分钟", "ask"], ["约个时间挑旧标签" if npc == "beetman" else "摄影与冲洗", "appointment" if npc == "beetman" else "film"], ["先走了", "leave"]]
	_choice_box(options,_vendor_action)

func _vendor_action(action: String) -> void:
	if closing or shopping or not is_instance_valid(vendor_choices): return
	if action == "leave": _close()
	elif action == "shop":
		shopping = true
		hide()
		purchase_requested.emit()
	elif action == "chat":
		_restart_vendor("greeting")
	elif action == "appointment":
		text_label.text = LocalizationSystem.text(str(EconomySystem.book_vendor_visit().message))
	elif action == "film":
		shopping = true
		hide()
		FilmSystem.open_counter(get_parent())
		_close()
	elif action == "ask":
		shopping = true
		hide()
		var ask := preload("res://scripts/meta/ask_panel.gd").new()
		ask.npc = npc
		ask.chosen.connect(func(topic: String) -> void:
			shopping = false
			show()
			_restart_vendor(topic))
		ask.tree_exited.connect(resume_from_shop)
		get_parent().add_child(ask)

func resume_from_shop() -> void:
	if closing: return
	shopping = false
	show()

func _restart_vendor(topic: String) -> void:
	if not MetaExperience.pay_conversation(topic): return
	if is_instance_valid(vendor_choices):
		_clear_choices()
	hint_label.show()
	lines.clear()
	speakers.clear()
	line_ids.clear()
	index = 0
	vendor_committed = false
	starting_topic = topic
	_build_conversation()
	SaveManager.save_or_report("继续谈话后保存失败")
	_show_line()

func _process(delta: float) -> void:
	if is_instance_valid(text_label) and typewriter and text_label.visible_characters >= 0:
		punctuation_delay -= delta
		if punctuation_delay>0: return
		var before := int(progress)
		progress = minf(progress+delta*32,text_label.text.length())
		for i in range(before,int(progress)):
			if text_label.text[i] in ["，","、",",","。","！","？","…","!","?"]:
				progress=i+1; punctuation_delay=.16 if text_label.text[i] in ["，","、",","] else .3; break
		text_label.visible_characters = int(progress)

func _gui_input(event: InputEvent) -> void:
	if shopping or is_instance_valid(vendor_choices): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_advance()
		accept_event()

func _input(event: InputEvent) -> void:
	if shopping: return
	if not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("ui_cancel"): _close()
	elif is_instance_valid(vendor_choices):
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("dialogue_advance"):
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and not focused.disabled and vendor_choices.is_ancestor_of(focused): focused.pressed.emit()
		else: return
	elif event.is_action_pressed("toggle_typewriter"):
		typewriter = not typewriter
		GameState.shared_state["typewriter"] = typewriter
		text_label.visible_characters = -1 if not typewriter else int(progress)
	elif event.is_action_pressed("dialogue_advance") or event.is_action_pressed("ui_accept"): _advance()
	else: return
	get_viewport().set_input_as_handled()

func _choice_box(options: Array, action: Callable) -> void:
	if is_instance_valid(vendor_choices): return
	hint_label.text=SettingsSystem.binding_text("ui_accept")+" 回应 · "+SettingsSystem.binding_text("ui_cancel")+" 离开"
	vendor_choices=VBoxContainer.new()
	for option in options:
		var button := preload("res://scripts/ui/components/dialogue_choice.gd").new()
		button.text=LocalizationSystem.text(str(option[0])); button.custom_minimum_size=Vector2(0,46)
		vendor_choices.add_child(button); button.pressed.connect(action.bind(str(option[1])))
	speech_card.attach_choices(vendor_choices)
	vendor_choices.get_child(0).grab_focus()

func _clear_choices() -> void:
	vendor_choices.get_parent().remove_child(vendor_choices)
	vendor_choices.queue_free(); vendor_choices=null; speech_card.choices=null
	hint_label.text=SettingsSystem.binding_text("dialogue_advance")+" 继续 · "+SettingsSystem.binding_text("ui_cancel")+" 离开"
	hint_label.show()

func _show_invitation_choices() -> void:
	_choice_box([[str(offer.accept),"accept"],["我先走走，之后再说。","later"]],_choose_invitation)

func _choose_invitation(choice: String) -> void:
	offer_decided=true; offer_accepted=choice=="accept"; _clear_choices()
	_append("npc","好，东西给你留着。准备好了就过来。" if offer_accepted else str(offer.get("decline","好，想好了再来。")))
	index=lines.size()-1; _show_line()

func _show_encounter_choices() -> void:
	var options := [["那我应该感到荣幸？","honor"],["我可以摸摸它吗？","touch"],["我先让它闻闻。","wait"]]
	if not PhotoLibrary.new().list_photos().is_empty(): options.append(["[照片] 我今天拍到了这个。","photo"])
	_choice_box(options,_choose_encounter)

func _choose_encounter(choice: String) -> void:
	_clear_choices(); encounter_finished=true
	var branch: Array={
		"honor":["可以。它对我的新鞋都考察了半小时。","我本来以为它会很勇敢，后来才发现，它只是装得像。"],
		"touch":["先把手放低，让它自己过来。","别急。它走这两步，要鼓很久的勇气。"],
		"wait":["嗯，这样就好。你不催它，它反而会靠近。","有时候我也想像它这样，慢一点再决定。"],
		"photo":["这是你今天拍的？光落在这里真好。","给我看看……你会把路上很小的东西留下来。"]}[choice]
	var start := lines.size()
	for line in branch: _append("npc",str(line))
	_append("npc","Xanni 也爱收集路上的声音。上次我在唱片店听了半天，才发现那段是雨落在狗碗里。")
	_append("npc","你要是录到什么，带去给她听听。她的制作台常空着一边。")
	index=start; _show_line()
