extends "res://extensions/hear_you/npc_dialogue.gd"
## Conversation stays on the live street. Only words and shared memories overlay it.
signal finish_requested
const WORDS := Rect2(170,745,1260,143)
var street: Control
var world_x := 0.0
var save_message := ""

func _head(side: int) -> Vector2:
	return Vector2(world_x + (-46 if side == 0 else 46) - street.camera_x,515)

func _thought_rect(index: int) -> Rect2:
	var side := int(MEMORIES[index].side)
	var head := _head(side)
	return Rect2(clampf(head.x+(-246 if side == 0 else 30),20,1342),362,238,112)

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
	_box(WORDS,Color("152d36",0.96),Color("62756e"),5)
	var speaker := ""
	var words := ""
	if not save_message.is_empty(): words = save_message
	elif finished: words = "他们提起菜篮，准备接着往前走。"
	elif waiting: words = "两个人都停了一下。也许先让对方看见自己想到的画面。"
	elif not current_line.is_empty():
		speaker = NAMES[int(current_line[0])]
		words = LocalizationSystem.text(str(current_line[1])).substr(0,int(typed))
	_text(speaker,WORDS.position+Vector2(26,29),18,Color("d6b58d"))
	_wrapped_text(words,WORDS.position+Vector2(26,64),22,Color("f4ead7"),1190,30)
	_text("拖动记忆到对方身上" if waiting else "点击 / 空格继续",WORDS.position+Vector2(26,124),14,Color("a8bbb7"))
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
			elif WORDS.has_point(point): _advance_street()
		elif drag_index >= 0:
			var index := drag_index
			drag_index = -1
			if not _give(index,_recipient_at(point)):
				return_index = index
				return_origin = point
				return_position = point
				return_time = 0
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			# This is the opening's mandatory encounter. Escape may put a memory
			# token back, but cannot dismiss the conversation before it is heard.
			if drag_index >= 0: _cancel_drag()
		elif event.keycode in [KEY_SPACE,KEY_ENTER]: _advance_street()
		get_viewport().set_input_as_handled()
