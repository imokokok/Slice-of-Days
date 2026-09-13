extends Control
signal closed
var npc := ""
var lines: Array[String] = []
var index := 0
var text_label: Label
var box: VBoxContainer
var progress := 0.0
var typewriter := true
var options: Array[Button] = []
var next_action: Callable
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
	_show_topic("greeting")
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
	else: _topics()
func _topics(page := 0) -> void:
	_clear()
	_label("你说……",19)
	var topics := [["今天怎么样？","daily_state"],["你什么时候在这里？","schedule_info"],["最近见过谁？","rumor"],["怎么去观景台？","location_info"],["你最近在忙什么？","personal_topic"],["聊聊街角的声音。","small_talk"],["这里有什么可以试试？","minigame_hook"],["还记得上次吗？","relationship_followup"],["愿意确认认识我吗？","recognition_related"]]
	for i in range(page*4,mini(page*4+4,topics.size())):
		var item: Array = topics[i]
		_button("%d  %s" % [options.size()+1,str(item[0])],_show_topic.bind(str(item[1])))
	_button("换个话题 →",_topics.bind((page+1)%3))
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
