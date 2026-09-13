extends Control
signal closed
var npc := ""
var starting_topic := "greeting"
var offer: Dictionary = {}
var lines: Array[String] = []
var index := 0
var text_label: Label
var box: VBoxContainer
var progress := 0.0
var typewriter := true
var options: Array[Button] = []
var next_action: Callable
var invite_after_chat := false
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.position = Vector2(70,350)
	panel.size = Vector2(930,330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152d36",0.94)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	box = VBoxContainer.new()
	box.position = Vector2(28,18)
	box.size = Vector2(874,290)
	panel.add_child(box)
	typewriter = bool(GameState.shared_state.get("typewriter",true))
	_show_topic(starting_topic)
func _clear() -> void:
	text_label = null
	options.clear()
	for child in box.get_children(): box.remove_child(child); child.queue_free()
func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 850
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("f0e2c5"))
	box.add_child(label)
	return label
func _button(value: String, action: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(830,34)
	button.add_theme_font_size_override("font_size",21)
	for state in ["normal","hover","pressed","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_color_override("font_focus_color",Color("ffe17e"))
	button.add_theme_color_override("font_hover_color",Color("ffe17e"))
	button.pressed.connect(action)
	box.add_child(button)
	options.append(button)
func _show_topic(topic: String) -> void:
	invite_after_chat = topic == "greeting" and DialogueSystem.should_invite(npc)
	offer = DialogueSystem.invitation_for(npc) if topic == "minigame_hook" else {}
	if not offer.is_empty(): DialogueSystem.mark_invitation_heard(npc)
	lines = DialogueSystem.reply(npc,topic)
	index = 0
	_show_line()
func _show_line() -> void:
	_clear()
	_label(str(ScheduleSystem.residents.get(npc,{}).get("display_name",npc)) + "     T · 切换逐字显示",18)
	text_label = _label(lines[index],25)
	text_label.custom_minimum_size.y = 140
	progress = 0.0
	text_label.visible_characters = 0 if typewriter else -1
	_button("继续  E",_advance)
	next_action = _advance
func _advance() -> void:
	if is_instance_valid(text_label) and typewriter and text_label.visible_characters >= 0 and text_label.visible_characters < text_label.text.length():
		progress = text_label.text.length()
		text_label.visible_characters = -1
		return
	index += 1
	if index < lines.size(): _show_line()
	elif invite_after_chat:
		invite_after_chat = false
		_show_topic("minigame_hook")
	elif not offer.is_empty(): _offer_choices()
	else: _topics()
func _topics(page := 0) -> void:
	_clear()
	_label("你说……",19)
	var topics := [[str(DialogueSystem.content.get(npc,{}).get("chat_label","今天过得怎么样？")),"daily_state"],["晚点还能在这儿碰到你吗？","schedule_info"],["最近有什么小事？","rumor"],["我想去海边看看。","location_info"],["后来呢？再讲一点吧。","personal_topic"],["我再陪你坐一会儿。","small_talk"],["你刚才说的那件事……","relationship_followup"],["我们也算熟人了吧？","recognition_related"]]
	var invitation := DialogueSystem.invitation_for(npc)
	if not invitation.is_empty():
		topics = topics.filter(func(t: Array) -> bool: return str(t[1]) != "minigame_hook")
		topics.push_front([str(invitation.label),"minigame_hook"])
	for i in range(page*4,mini(page*4+4,topics.size())):
		var item: Array = topics[i]
		_button("%d  %s" % [options.size()+1,str(item[0])],_show_topic.bind(str(item[1])))
	_button("再聊点别的。",_topics.bind((page+1)%int(ceil(topics.size()/4.0))))
	_button("先聊到这里。",_close)
	options[0].grab_focus()
func _close() -> void:
	closed.emit()
	queue_free()
func _process(delta: float) -> void:
	if is_instance_valid(text_label) and typewriter and text_label.visible_characters >= 0:
		progress += delta*28.0
		text_label.visible_characters = int(progress)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: _close()
		elif event.keycode == KEY_T:
			typewriter = not typewriter
			GameState.shared_state["typewriter"] = typewriter
			if is_instance_valid(text_label): text_label.visible_characters = -1 if not typewriter else int(progress)
		elif event.keycode in [KEY_E,KEY_SPACE] and is_instance_valid(text_label): _advance()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var number := int(event.keycode-KEY_1)
			if number < options.size(): options[number].pressed.emit()
		get_viewport().set_input_as_handled()

func _offer_choices() -> void:
	_clear()
	_label(str(ScheduleSystem.residents[npc].display_name),18)
	var duration := GameplayModuleSystem.time_hint(str(offer.module))
	_label(str(offer.lines.back()),23)
	if not duration.is_empty(): _label("约 " + duration,16)
	_button("1  " + str(offer.accept),_accept_offer)
	_button("2  我晚一点再来。",_decline_offer)
	options[0].grab_focus()
func _decline_offer() -> void:
	var farewell := str(offer.get("decline","好，不着急。你想好了再来找我。"))
	offer = {}
	lines = [farewell]
	index = 0
	_show_line()
func _accept_offer() -> void:
	var accepted := DialogueSystem.accept_invitation(npc)
	if accepted.is_empty(): _close(); return
	if bool(accepted.get("launch",false)):
		var minutes := int(GameplayModuleSystem.modules.get(str(accepted.module),{}).get("direct_time_minutes",0))
		if not GameState.can_fit_now(minutes):
			offer = {}
			lines = ["这会儿时间不够，等你空下来我们再开始。"]
			index = 0
			_show_line()
			return
		SceneRouter.gameplay_module(str(accepted.module),"street:"+GameState.current_location+":invitation:"+npc)
	_close()
