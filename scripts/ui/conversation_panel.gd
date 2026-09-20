extends Control
## Forward-moving speech with the vendor's optional, same-card counter choices.
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
var line_ids: Array[String] = []
var dialogue_id := ""
var hint_label: Label
var vendor_choices: VBoxContainer
var vendor_committed := false
var shopping := false

func _ready() -> void:
	add_to_group("meta_dialogue")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.position = Vector2(600,380)
	panel.size = Vector2(430,184)
	speech_card = panel
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fffaf0",0.12)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	speaker_label = _label(panel,Vector2(18,12),Vector2(394,26),17,Color("eed577"))
	text_label = _label(panel,Vector2(18,47),Vector2(394,93),22,Color("f0e2c5"))
	hint_label = _label(panel,Vector2(18,149),Vector2(394,25),13,Color("a8bbb7"))
	hint_label.text = LocalizationSystem.text("Space 继续 · Esc 离开")
	typewriter = bool(GameState.shared_state.get("typewriter",true))
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

func _label(parent: Control, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color("254966",.8))
	label.add_theme_constant_override("outline_size",2)
	parent.add_child(label)
	return label

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
		for beat in DialogueSystem.linear_conversation(npc): _append(str(beat[0]),str(beat[1]))
	elif starting_topic != "minigame_hook":
		for line in DialogueSystem.reply(npc,starting_topic): _append("npc",line)
	if starting_topic == "minigame_hook" or (records_story and DialogueSystem.should_invite(npc)):
		offer = DialogueSystem.invitation_for(npc)
		for line in offer.get("lines",[]): _append("npc",str(line))
		if not offer.is_empty():
			_append("player",str(offer.accept) if starting_topic == "minigame_hook" else "好，我记下了。空下来就过去看看。")
	if lines.is_empty(): _append("npc","我先把手边收拾好。你想试的时候再过来。")

func _show_line() -> void:
	var speaker := speakers[index]
	_position_card(speaker)
	speaker_label.text = LocalizationSystem.text("你" if speaker == "player" else "" if speaker == "narrator" else shop_name if not shop_name.is_empty() else str(ScheduleSystem.residents.get(npc,{}).get("display_name",npc)))
	text_label.text = LocalizationSystem.text(lines[index])
	DialogueSystem.present_line({"npc":npc,"speaker":speaker,"text":lines[index],"index":index,"total":lines.size(),"location":GameState.current_location,"owner":self,"conversation_id":get_instance_id(),"dialogue_id":dialogue_id,"line_id":line_ids[index],"topic":starting_topic})
	progress = 0
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
	if not offer.is_empty():
		DialogueSystem.mark_invitation_heard(npc,false)
		DialogueSystem.accept_invitation(npc,false)
	if not SaveManager.save_or_report("保存谈话失败"):
		GameState.load_save_data(snapshot)
		commit_retry = true
		speaker_label.text = ""
		text_label.text = LocalizationSystem.text("这段谈话暂时没能保存，点击或按空格重试。")
		text_label.visible_characters = -1
		return
	# Only walking up to a game point requests entry. Casual chat returns to walking.
	if starting_topic == "minigame_hook" and bool(offer.get("launch",false)):
		var minutes := int(GameplayModuleSystem.modules.get(str(offer.module),{}).get("direct_time_minutes",0))
		if GameState.can_fit_now(minutes): SceneRouter.gameplay_module(str(offer.module),"street:"+GameState.current_location+":invitation:"+npc)
	_close()

func _close() -> void:
	if closing: return
	closing = true
	closed.emit()
	queue_free()

func _show_vendor_choices() -> void:
	if is_instance_valid(vendor_choices): return
	speech_card.size.y = 340
	_position_card("npc")
	speaker_label.text = LocalizationSystem.text("BEETMAN" if npc == "beetman" else "杂货店老板")
	text_label.text = LocalizationSystem.text("我就在摊边。你想接着聊，还是看看今天的罐头？" if npc == "beetman" else "你慢慢看。想买什么、冲照片，或者再说几句都可以。")
	text_label.visible_characters = -1
	text_label.size.y = 58
	hint_label.hide()
	vendor_choices = VBoxContainer.new()
	vendor_choices.position = Vector2(18, 111)
	vendor_choices.size = Vector2(394, 168)
	vendor_choices.add_theme_constant_override("separation", 3)
	speech_card.add_child(vendor_choices)
	var options := [["再聊一会儿 · 15分钟", "chat"], ["看看今天的罐头" if npc == "beetman" else "看看货架", "shop"], ["问点事 · 5分钟", "ask"], ["约个时间挑旧标签" if npc == "beetman" else "摄影与冲洗", "appointment" if npc == "beetman" else "film"], ["先走了", "leave"]]
	for option in options:
		var button := Button.new()
		button.text = LocalizationSystem.text(str(option[0]))
		button.custom_minimum_size.y = 36
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color("e8e0c9"))
		var paper := StyleBoxFlat.new()
		paper.bg_color = Color("465b52")
		paper.set_corner_radius_all(3)
		button.add_theme_stylebox_override("normal", paper)
		var hover: StyleBoxFlat = paper.duplicate()
		hover.bg_color = Color("607d77")
		button.add_theme_stylebox_override("hover", hover)
		vendor_choices.add_child(button)
		button.pressed.connect(_vendor_action.bind(str(option[1])))
	vendor_choices.get_child(0).grab_focus()

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
		vendor_choices.queue_free()
		vendor_choices = null
	speech_card.size.y = 184
	text_label.size.y = 93
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
		progress += delta*28
		text_label.visible_characters = int(progress)

func _gui_input(event: InputEvent) -> void:
	if shopping or is_instance_valid(vendor_choices): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_advance()
		accept_event()

func _input(event: InputEvent) -> void:
	if shopping: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.is_action_pressed("ui_cancel"): _close()
	elif is_instance_valid(vendor_choices):
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("dialogue_advance"):
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and vendor_choices.is_ancestor_of(focused): focused.pressed.emit()
		else: return
	elif event.is_action_pressed("toggle_typewriter"):
		typewriter = not typewriter
		GameState.shared_state["typewriter"] = typewriter
		text_label.visible_characters = -1 if not typewriter else int(progress)
	elif event.is_action_pressed("dialogue_advance") or event.is_action_pressed("ui_accept"): _advance()
	else: return
	get_viewport().set_input_as_handled()

func _position_card(speaker: String) -> void:
	var scene := get_parent()
	var world: Control = scene.get("street") if scene.get("street") != null else scene.get("stage")
	if world == null: return
	var actor_x := float(world.player_x)
	if speaker != "player":
		for point in world.hotspots:
			if str(point.get("id","")) == npc or (not shop_id.is_empty() and str(point.get("kind","")) == "shopkeeper"): actor_x = float(point.x); break
	var x := actor_x-float(world.camera_x)
	var head := float(world.call("_actor_ground_at",actor_x))-float(world.call("_actor_height"))
	speech_card.position = Vector2(clampf(x-215,24,1146),clampf(head-speech_card.size.y-18,140,495))
