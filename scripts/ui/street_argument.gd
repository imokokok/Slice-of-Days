extends "res://extensions/hear_you/npc_dialogue.gd"
## Conversation stays on the live street. Only words and shared memories overlay it.
signal finish_requested
signal cancel_requested

var street: Control
var world_x := 0.0
var save_message := ""
var dialogue_card: Panel
var displayed_words := ""

func _ready() -> void:
	super._ready()
	dialogue_card=preload("res://scripts/ui/components/dialogue_card.gd").new()
	add_child(dialogue_card)
	dialogue_card.configure(street,"translation")
	dialogue_card.minimum_body_height=96

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(dialogue_card): return
	var words := ""
	var speaker := ""
	if not save_message.is_empty(): words=save_message
	elif finished: words="他们提起菜篮，准备接着往前走。"
	elif waiting: words="两个人都停了一下。也许先让对方看见自己想到的画面。"
	elif not current_line.is_empty():
		speaker=NAMES[int(current_line[0])]
		words=LocalizationSystem.text(str(current_line[1]))
	dialogue_card.speaker_label.text=speaker
	dialogue_card.text_label.text=words
	dialogue_card.text_label.visible_characters=-1 if waiting or finished or SettingsSystem.reduced_motion() else int(typed)
	dialogue_card.hint_label.text=("拖动记忆到对方身上" if waiting else SettingsSystem.binding_text("dialogue_advance")+" 继续")+" · "+SettingsSystem.binding_text("ui_cancel")+" 离开"
	dialogue_card.additional_obstacles.clear()
	for side in 2:
		var memory_index: int=PAIRS[chapter][side]
		if waiting or decoded[memory_index]: dialogue_card.additional_obstacles.append(_thought_rect(memory_index))
	if words!=displayed_words:
		displayed_words=words
		dialogue_card.layout(true)
	var hand := _speech_rect().has_point(get_local_mouse_position()) or hovering>=0
	Input.set_default_cursor_shape(Input.CURSOR_DRAG if drag_index>=0 else Input.CURSOR_POINTING_HAND if hand else Input.CURSOR_ARROW)

func _head(side: int) -> Vector2:
	var x := world_x + (-70 if side == 0 else 70)
	return Vector2(x-street.camera_x,street._actor_ground_at(x)-street._actor_height())

func _thought_rect(index: int) -> Rect2:
	var side := int(MEMORIES[index].side)
	var head := _head(side)
	return Rect2(clampf(head.x+(-246 if side == 0 else 30),20,1342),maxf(80,head.y-220),238,112)

func _recipient_at(point: Vector2) -> int:
	for side in range(2):
		if Rect2(_head(side)-Vector2(42,5),Vector2(84,220)).has_point(point): return side
	return -1

func _draw() -> void:
	for side in range(2):
		var head := _head(side)
		if not current_line.is_empty() and int(current_line[0]) == side:
			draw_circle(head-Vector2(0,8),3,Color("f5dfb3"))
		var index: int = PAIRS[chapter][side]
		if not waiting and not decoded[index]: continue
		var rect := _thought_rect(index)
		draw_line(rect.get_center()+Vector2(0,56),head,Color("e4d8bd"),2,true)
		_box(rect,Color("f8f4ec"),Color("9b8b70"),12)
		if drag_index != index and return_index != index:
			draw_texture_rect(textures[index],Rect2(rect.position+Vector2(15,34),Vector2(48,48)),false,INK)
		_text(NAMES[side]+"想到的",rect.position+Vector2(14,24),15,MUTED)
		_text(str(MEMORIES[index].title),rect.position+Vector2(76,54),18,INK)
		_text("对方听见了" if decoded[index] else "拖给对方看看",rect.position+Vector2(76,82),14,MUTED)
	if drag_index >= 0: _draw_token(drag_index,drag_position)
	if return_index >= 0: _draw_token(return_index,return_position)

func _advance_street() -> void:
	if finished: finish_requested.emit()
	else:
		_continue()
		if finished: finish_requested.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and drag_index >= 0:
		drag_position = get_global_transform_with_canvas().affine_inverse()*event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		if event.pressed:
			var index := _thought_at(point) if waiting else -1
			if index >= 0:
				drag_index = index
				drag_position = point
				return_index = -1
			elif _speech_rect().has_point(point): _advance_street()
		elif drag_index >= 0:
			var index := drag_index
			drag_index = -1
			if not _give(index,_recipient_at(point)):
				return_index = index
				return_origin = point
				return_position = point
				return_time = 0
		get_viewport().set_input_as_handled()
	elif event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("ui_cancel"):
			if drag_index >= 0: _cancel_drag()
			dialogue_card.dismiss()
			cancel_requested.emit()
		elif event.is_action_pressed("dialogue_advance") or event.is_action_pressed("ui_accept"): _advance_street()
		else: return
		get_viewport().set_input_as_handled()

func _speech_rect() -> Rect2:
	return dialogue_card.get_rect() if is_instance_valid(dialogue_card) else Rect2()

func _text(value: String, baseline: Vector2, font_size: int, color: Color, font: Font = null) -> void:
	var used: Font = PaperLanguage.handwriting if font==null else font
	var line := LocalizationSystem.text(value)
	if color.get_luminance()>.5:
		draw_string_outline(used,baseline,line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("234d68",.9))
	draw_string(used,baseline,line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
