extends Control
## One forward-moving conversation; no topic hub, reply numbers or goodbye menu.
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.position = Vector2(170,652)
	panel.size = Vector2(1260,230)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152d36",0.96)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	speaker_label = _label(panel,Vector2(28,20),Vector2(1204,30),18,Color("d6b58d"))
	text_label = _label(panel,Vector2(28,63),Vector2(1204,115),25,Color("f0e2c5"))
	var hint := _label(panel,Vector2(28,195),Vector2(1204,24),14,Color("a8bbb7"))
	hint.text = "点击 / 空格 / Enter 继续    ·    Esc 暂时离开    ·    T 文字速度"
	typewriter = bool(GameState.shared_state.get("typewriter",true))
	if shop_id.is_empty():
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
	parent.add_child(label)
	return label

func _append(speaker: String, text: String) -> void:
	speakers.append(speaker)
	lines.append(text)

func _build_conversation() -> void:
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
	speaker_label.text = "你" if speaker == "player" else "" if speaker == "narrator" else shop_name if not shop_id.is_empty() else str(ScheduleSystem.residents.get(npc,{}).get("display_name",npc))
	text_label.text = lines[index]
	progress = 0
	text_label.visible_characters = 0 if typewriter else -1

func _advance() -> void:
	if closing: return
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
		text_label.text = "这段谈话暂时没能保存，点击或按空格重试。"
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

func _process(delta: float) -> void:
	if is_instance_valid(text_label) and typewriter and text_label.visible_characters >= 0:
		progress += delta*28
		text_label.visible_characters = int(progress)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_advance()
		accept_event()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.is_action_pressed("ui_cancel"): _close()
	elif event.is_action_pressed("toggle_typewriter"):
		typewriter = not typewriter
		GameState.shared_state["typewriter"] = typewriter
		text_label.visible_characters = -1 if not typewriter else int(progress)
	elif event.is_action_pressed("dialogue_advance") or event.is_action_pressed("ui_accept"): _advance()
	else: return
	get_viewport().set_input_as_handled()
