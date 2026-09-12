extends Node2D
## A single-screen conversation about different memories behind the same words.

const PAPER := Color("f4f1ea")
const WHITE := Color("fffcf7")
const INK := Color("262523")
const MUTED := Color("807a70")
const LINE := Color("ddd6ca")
const RED := Color("bd4640")
const PALE_RED := Color("f8e9e2")
const GREEN := Color("687962")
const PANEL_RECTS := [Rect2(64, 286, 544, 494), Rect2(672, 286, 544, 494)]
const RESET_RECT := Rect2(1080, 79, 128, 42)
const MEMORY_RECT := Rect2(180, 799, 920, 88)
const SLOT_ORDER := [1, 2, 0, 2, 0, 1]
const OPENING := [
	["你说“吃肉”，我就有点难受。", "能不能别再劝了？"],
	["我只是想和你好好吃顿饭。", "你是不喜欢和我一起吃吗？"],
]
const MEMORIES := [
	{"icon": "pig", "side": 0, "row": 0, "title": "我喂过的猪", "question": "“肉”让你先想到什么？", "answer": "你先想起了自己照顾过的小猪。", "memory": "小时候，我喂过一只会追着我跑的小猪。说到“肉”，我会先想起它。"},
	{"icon": "knife", "side": 0, "row": 1, "title": "第一次明白", "question": "你什么时候开始在意的？", "answer": "你记得第一次意识到生命的时刻。", "memory": "第一次经过肉摊时，我才明白：盘里的食物也曾经有生命。这件事一直留在我心里。"},
	{"icon": "crying", "side": 0, "row": 2, "title": "那次的难过", "question": "不想吃时，你是什么感觉？", "answer": "这句话唤起了你失去小动物的难过。", "memory": "照顾过的小动物离开后，我难过了很久。有时说到吃肉，那种感觉又会回来。"},
	{"icon": "smile", "side": 1, "row": 0, "title": "熟悉的味道", "question": "熟悉的味道带给你什么？", "answer": "熟悉的味道，让你觉得安心。", "memory": "小时候，一闻到那道菜，我就知道今天有人等我吃饭。熟悉的味道让我觉得踏实。"},
	{"icon": "moustache", "side": 1, "row": 1, "title": "爸爸的菜", "question": "这道菜让你想起了谁？", "answer": "这道菜里，有你和爸爸的回忆。", "memory": "爸爸留着胡子，逢年过节会做那道拿手菜。我想把自己喜欢的回忆也分享给你。"},
	{"icon": "table", "side": 1, "row": 2, "title": "每天的一餐", "question": "你平常吃饭时会想到什么？", "answer": "你想到日常的饭菜，不一定想到动物。", "memory": "对我来说，它也是每天熟悉的食物。吃饭时，我通常想着味道和同桌的人，不一定想到它来自哪种动物。"},
]

var body_font: SystemFont
var title_font: SystemFont
var latin_font: SystemFont
var textures: Array[Texture2D] = []
var decoded: Array[bool] = [false, false, false, false, false, false]
var reveal: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var pulse: Array[float] = [0.0, 0.0]
var drag_index := -1
var drag_position := Vector2.ZERO
var drag_offset := Vector2.ZERO
var drag_started := Vector2.ZERO
var return_index := -1
var return_position := Vector2.ZERO
var return_origin := Vector2.ZERO
var return_time := 0.0
var hover_index := -1
var selected_memory := -1
var keyboard_index := -1
var keyboard_mode := false
var ending_time := -1.0
var feedback := "先看看一段记忆，再把它交给对方的一个问题。"
var feedback_time := 0.0
var audio_player: AudioStreamPlayer
var melody_step := 0
var completed_count := 0


func _ready() -> void:
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "WenQuanYi Zen Hei"])
	title_font = SystemFont.new()
	title_font.font_names = body_font.font_names
	title_font.font_weight = 700
	latin_font = SystemFont.new()
	latin_font.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	for item: Dictionary in MEMORIES:
		textures.append(load("res://assets/%s.svg" % item.icon))
	audio_player = AudioStreamPlayer.new()
	audio_player.volume_db = -13.0
	add_child(audio_player)
	if "--qa" in OS.get_cmdline_user_args():
		_run_qa.call_deferred()


func _process(delta: float) -> void:
	for i in range(6):
		reveal[i] = move_toward(reveal[i], 1.0 if decoded[i] else 0.0, delta * 3.0)
	for side in range(2):
		pulse[side] = maxf(0.0, pulse[side] - delta * 1.8)
	if return_index >= 0:
		return_time = minf(1.0, return_time + delta * 5.0)
		return_position = return_origin.lerp(_card_rect(return_index).get_center(), 1.0 - pow(1.0 - return_time, 3.0))
		if return_time >= 1.0:
			return_index = -1
	if ending_time >= 0.0:
		ending_time += delta
	if feedback_time > 0.0:
		feedback_time = maxf(0.0, feedback_time - delta)
		if feedback_time == 0.0:
			feedback = "先看看一段记忆，再把它交给对方的一个问题。"
	if not keyboard_mode:
		hover_index = _card_at(get_global_mouse_position(), true)
	var cursor := Input.CURSOR_ARROW
	if drag_index >= 0:
		cursor = Input.CURSOR_DRAG
	elif hover_index >= 0 or RESET_RECT.has_point(get_global_mouse_position()):
		cursor = Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(cursor)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 960), PAPER)
	_text("语 言 与 语 境  /  一 段 对 话", Vector2(74, 58), 13, MUTED)
	_text("听懂你", Vector2(69, 126), 54, INK, title_font)
	_text("WORDS BETWEEN US", Vector2(253, 122), 15, MUTED, latin_font)
	_text("同样的话，", Vector2(850, 103), 16, MUTED)
	_text("不同的生活记忆。", Vector2(850, 131), 16, MUTED)
	_button(RESET_RECT, "重新开始")
	draw_line(Vector2(72, 170), Vector2(1208, 170), LINE, 1.0, true)
	_center_text("同一个词：「吃肉」", 208, 23, INK)
	_center_text("把一段记忆拖给对方的问题，听懂话语背后的意思。", 238, 13, MUTED)
	for side in range(2):
		_draw_panel(side)
	for i in range(6):
		_draw_memory_card(i)
	_draw_footer()
	if drag_index >= 0:
		_draw_floating_card(drag_index, drag_position)
	if return_index >= 0:
		_draw_floating_card(return_index, return_position)


func _draw_panel(side: int) -> void:
	var panel: Rect2 = PANEL_RECTS[side]
	var count := _received_count(side)
	var progress := 0.0
	for i in range(6):
		if int(MEMORIES[i].side) != side:
			progress += reveal[i] / 3.0
	var speech_color := RED.lerp(INK, progress)
	_text("01" if side == 0 else "02", Vector2(panel.position.x, 263), 18, MUTED, latin_font)
	_text("选择素食的人" if side == 0 else "习惯吃肉的人", Vector2(panel.position.x + 37, 262), 17, INK)
	_text("听见了彼此" if count == 3 else "还在误解之中", Vector2(panel.end.x - 115, 262), 13, MUTED)
	_box(Rect2(panel.position + Vector2(0, 4), panel.size), Color(0.3, 0.25, 0.15, 0.035), Color.TRANSPARENT, 24)
	_box(panel, WHITE, LINE.lerp(GREEN, pulse[side]), 24)
	_text(str(OPENING[side][0]), panel.position + Vector2(26, 39), 24, speech_color)
	_text(str(OPENING[side][1]), panel.position + Vector2(26, 71), 24, speech_color)
	_text("听到“吃肉”时，我想到……", panel.position + Vector2(26, 96), 12, MUTED)
	_text("我想听懂你的……", Vector2(panel.position.x + 26, 540), 13, MUTED)
	for row in range(3):
		_draw_question(side, row)


func _draw_memory_card(index: int) -> void:
	var rect := _card_rect(index)
	var focused := hover_index == index or keyboard_index == index or selected_memory == index
	var color := RED.lerp(INK, reveal[index])
	var fill := PALE_RED.lerp(Color("eeece5"), reveal[index])
	var is_moving := drag_index == index or return_index == index
	if is_moving:
		_box(rect, Color.TRANSPARENT, LINE, 15)
		draw_texture_rect(textures[index], Rect2(rect.position + Vector2(48, 10), Vector2(48, 48)), false, Color(RED, 0.16))
	else:
		_box(rect, fill, color.lightened(0.4) if focused else Color.TRANSPARENT, 15)
		draw_texture_rect(textures[index], Rect2(rect.position + Vector2(48, 10), Vector2(48, 48)), false, color)
	_center_text(str(MEMORIES[index].title), rect.position.y + 78, 16, color, rect.position.x, rect.size.x)
	_center_text("已分享 ✓" if decoded[index] else "可拖动", rect.position.y + 99, 11, MUTED, rect.position.x, rect.size.x)


func _draw_question(listener_side: int, row: int) -> void:
	var index := _question_memory(listener_side, row)
	var rect := _question_rect(listener_side, row)
	var active := drag_index >= 0 and int(MEMORIES[drag_index].side) != listener_side
	var inside := active and rect.has_point(get_global_mouse_position())
	var keyboard_target := keyboard_mode and keyboard_index >= 0 and int(MEMORIES[keyboard_index].side) != listener_side
	var fill := Color("f6f3ed")
	var border := LINE
	if active and not decoded[index]:
		fill = Color("efeee4") if inside else Color("fff9f0")
		border = INK if inside else RED.lightened(0.25)
	if decoded[index]:
		fill = Color("eae8df")
		border = Color("d4d0c5")
	_box(rect, fill, border, 13, 2 if inside else 1)
	if decoded[index]:
		draw_texture_rect(textures[index], Rect2(rect.position + Vector2(13, 11), Vector2(35, 35)), false, INK)
		_text(str(MEMORIES[index].answer), rect.position + Vector2(59, 35), 18, INK)
	else:
		var number_color := RED if active or keyboard_target else MUTED
		_text(str(row + 1).pad_zeros(2), rect.position + Vector2(15, 36), 15, number_color, latin_font)
		_text(str(MEMORIES[index].question), rect.position + Vector2(53, 36), 18, INK)
		if inside:
			_text("松开", Vector2(rect.end.x - 45, rect.position.y + 36), 11, MUTED)


func _draw_footer() -> void:
	var current_index := _current_memory()
	if ending_time >= 0.0 and current_index < 0:
		var alpha := clampf(ending_time * 1.6, 0.0, 1.0)
		var alpha_right := clampf((ending_time - 0.3) * 1.6, 0.0, 1.0)
		_center_text("“原来是这样，你想分享的是家的味道。”", 839, 22, Color(INK, alpha), 64, 544, title_font)
		_center_text("“对不起，我没听懂你为什么难受。”", 839, 22, Color(INK, alpha_right), 672, 544, title_font)
		_center_text("吃各自喜欢的，继续一起聊天。", 882, 17, Color(MUTED, alpha_right))
	else:
		var index := current_index
		_box(MEMORY_RECT, WHITE, LINE, 16)
		if index >= 0:
			var speaker := "素食者的记忆" if int(MEMORIES[index].side) == 0 else "吃肉者的记忆"
			_text(speaker + " · " + str(MEMORIES[index].title), MEMORY_RECT.position + Vector2(23, 24), 12, MUTED)
			_wrapped_text(str(MEMORIES[index].memory), MEMORY_RECT.position + Vector2(23, 49), 17, INK, 874, 25)
		else:
			_center_text("把鼠标放在图形上，看看这是谁的记忆。", 834, 18, INK, MEMORY_RECT.position.x, MEMORY_RECT.size.x)
			_center_text("再把它拖进另一边最贴切的问题里。", 861, 14, MUTED, MEMORY_RECT.position.x, MEMORY_RECT.size.x)
	draw_line(Vector2(72, 907), Vector2(1208, 907), LINE, 1.0, true)
	_text(feedback if completed_count < 6 else "听懂了彼此，选择仍然属于自己。", Vector2(72, 935), 12, MUTED if feedback_time <= 0 else RED)
	_text("Tab 选记忆 · 1 / 2 / 3 配对 · Esc 取消 · R 重来", Vector2(860, 935), 11, MUTED)


func _draw_floating_card(index: int, center: Vector2) -> void:
	var rect := Rect2(center - Vector2(72, 56.5), Vector2(144, 113))
	_box(Rect2(rect.position + Vector2(0, 7), rect.size), Color(0.2, 0.12, 0.1, 0.12), Color.TRANSPARENT, 15)
	_box(rect, WHITE, RED, 15, 2)
	draw_texture_rect(textures[index], Rect2(rect.position + Vector2(47, 10), Vector2(50, 50)), false, RED)
	_center_text(str(MEMORIES[index].title), rect.position.y + 83, 16, RED, rect.position.x, rect.size.x)
	_center_text("给对方的一段记忆", rect.position.y + 103, 10, MUTED, rect.position.x, rect.size.x)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		keyboard_mode = false
		keyboard_index = -1
		if drag_index >= 0:
			drag_position = get_global_mouse_position() + drag_offset
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point := get_global_mouse_position()
		if event.pressed:
			keyboard_mode = false
			keyboard_index = -1
			if RESET_RECT.has_point(point):
				_reset()
				return
			var index := _card_at(point, true)
			selected_memory = index
			if index >= 0:
				selected_memory = index
				if not decoded[index]:
					_begin_drag(index, point)
		elif drag_index >= 0:
			_finish_drag(point)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel_drag()
			selected_memory = -1
			keyboard_index = -1
			keyboard_mode = false
		elif event.keycode == KEY_R:
			_reset()
		elif drag_index < 0:
			if event.keycode == KEY_TAB:
				keyboard_mode = true
				hover_index = -1
				_keyboard_next(-1 if event.shift_pressed else 1)
				get_viewport().set_input_as_handled()
			elif keyboard_index >= 0 and event.keycode in [KEY_1, KEY_2, KEY_3, KEY_KP_1, KEY_KP_2, KEY_KP_3]:
				var row := int(event.keycode - KEY_1) if event.keycode in [KEY_1, KEY_2, KEY_3] else int(event.keycode - KEY_KP_1)
				if _exchange(keyboard_index, 1 - int(MEMORIES[keyboard_index].side), row):
					_keyboard_next(1)
				else:
					_wrong_match()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_drag()


func _begin_drag(index: int, point: Vector2) -> void:
	if index < 0 or index >= 6 or decoded[index]:
		return
	return_index = -1
	drag_index = index
	selected_memory = index
	drag_started = point
	drag_offset = _card_rect(index).get_center() - point
	drag_position = point + drag_offset


func _finish_drag(point: Vector2) -> void:
	var index := drag_index
	if index < 0:
		return
	var destination := _question_at(point)
	if _exchange(index, destination.x, destination.y):
		drag_index = -1
	else:
		var clicked := point.distance_to(drag_started) < 8.0
		_cancel_drag()
		if clicked:
			feedback = "看看下方的记忆，再拖给对方最贴切的问题。"
			feedback_time = 3.0
		else:
			_wrong_match()


func _cancel_drag() -> void:
	if drag_index < 0:
		return
	return_index = drag_index
	return_origin = drag_position
	return_position = drag_position
	return_time = 0.0
	drag_index = -1


func _wrong_match() -> void:
	feedback = "这段记忆，也许回答了另一个问题。"
	feedback_time = 3.0


func _exchange(index: int, destination_side: int, visual_row: int) -> bool:
	if index < 0 or index >= 6 or destination_side < 0 or destination_side > 1 or visual_row < 0 or visual_row > 2:
		return false
	if decoded[index] or int(MEMORIES[index].side) == destination_side or visual_row != int(SLOT_ORDER[index]):
		return false
	decoded[index] = true
	completed_count += 1
	pulse[destination_side] = 1.0
	selected_memory = index
	feedback = "原来，这句话还连着这样一段记忆。"
	feedback_time = 3.0
	_play_tone()
	if completed_count == 6:
		ending_time = 0.0
		selected_memory = -1
		feedback_time = 0.0
	return true


func _reset() -> void:
	decoded.assign([false, false, false, false, false, false])
	reveal.assign([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	pulse.assign([0.0, 0.0])
	completed_count = 0
	drag_index = -1
	return_index = -1
	ending_time = -1.0
	keyboard_index = -1
	keyboard_mode = false
	selected_memory = -1
	hover_index = -1
	feedback = "先看看一段记忆，再把它交给对方的一个问题。"
	feedback_time = 0.0
	melody_step = 0
	if is_instance_valid(audio_player):
		audio_player.stop()


func _keyboard_next(direction: int) -> void:
	var start := keyboard_index
	if start < 0:
		start = -1 if direction > 0 else 0
	for step in range(1, 7):
		var next := posmod(start + step * direction, 6)
		if not decoded[next]:
			keyboard_index = next
			selected_memory = next
			return
	keyboard_index = -1


func _card_rect(index: int) -> Rect2:
	return Rect2(90 + int(MEMORIES[index].side) * 608 + int(MEMORIES[index].row) * 163, 394, 144, 113)


func _card_at(point: Vector2, include_shared: bool = false) -> int:
	for i in range(6):
		if (include_shared or not decoded[i]) and _card_rect(i).has_point(point):
			return i
	return -1


func _question_rect(listener_side: int, visual_row: int) -> Rect2:
	return Rect2(90 + listener_side * 608, 559 + visual_row * 65, 492, 58)


func _question_memory(listener_side: int, visual_row: int) -> int:
	for i in range(6):
		if int(MEMORIES[i].side) != listener_side and int(SLOT_ORDER[i]) == visual_row:
			return i
	return -1


func _question_at(point: Vector2) -> Vector2i:
	for side in range(2):
		for row in range(3):
			if _question_rect(side, row).has_point(point):
				return Vector2i(side, row)
	return Vector2i(-1, -1)


func _received_count(side: int) -> int:
	var count := 0
	for i in range(6):
		if int(MEMORIES[i].side) != side and decoded[i]:
			count += 1
	return count


func _current_memory() -> int:
	if drag_index >= 0:
		return drag_index
	if keyboard_mode and keyboard_index >= 0:
		return keyboard_index
	if hover_index >= 0:
		return hover_index
	return selected_memory


func _text(value: String, baseline: Vector2, font_size: int, color: Color, font: Font = null) -> void:
	draw_string(body_font if font == null else font, baseline, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _center_text(value: String, baseline: float, font_size: int, color: Color, x: float = 0, width: float = 1280, font: Font = null) -> void:
	var used_font: Font = body_font if font == null else font
	var text_width := used_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(value, Vector2(x + (width - text_width) / 2.0, baseline), font_size, color, used_font)


func _wrapped_text(value: String, baseline: Vector2, font_size: int, color: Color, width: float, line_height: float) -> void:
	var line := ""
	var y := baseline.y
	for character in value:
		var next := line + character
		if body_font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not line.is_empty():
			_text(line, Vector2(baseline.x, y), font_size, color)
			y += line_height
			line = character
		else:
			line = next
	if not line.is_empty():
		_text(line, Vector2(baseline.x, y), font_size, color)


func _box(rect: Rect2, fill: Color, border: Color, radius: int, border_width: int = 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	draw_style_box(style, rect)


func _button(rect: Rect2, value: String) -> void:
	var hovered := rect.has_point(get_global_mouse_position())
	_box(rect, Color("e8e3d8") if hovered else Color.TRANSPARENT, LINE, 19)
	_center_text(value, rect.position.y + rect.size.y / 2.0 + 5, 13, INK, rect.position.x, rect.size.x)


func _play_tone() -> void:
	var notes := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
	var frequency: float = notes[mini(melody_step, 5)]
	melody_step += 1
	var sample_rate := 22050
	var duration := 0.5 if completed_count < 6 else 0.9
	var samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / sample_rate
		var envelope := minf(t / 0.012, 1.0) * exp(-t * 8.0) * (1.0 - t / duration)
		var wave := sin(TAU * frequency * t) + 0.24 * sin(TAU * frequency * 2.0 * t)
		data.encode_s16(i * 2, int(clampf(wave * envelope * 0.5, -1.0, 1.0) * 32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = sample_rate
	sound.data = data
	audio_player.stream = sound
	audio_player.play()


func _run_qa() -> void:
	await get_tree().process_frame
	assert(completed_count == 0)
	assert(_card_at(_card_rect(0).get_center()) == 0)
	assert(_question_at(_question_rect(1, 1).get_center()) == Vector2i(1, 1))
	assert(_question_memory(1, 1) == 0 and _question_memory(0, 1) == 5)
	assert(not _exchange(0, 0, 1), "Same-side drops must not advance")
	assert(not _exchange(0, -1, -1), "Outside drops must not advance")
	assert(not _exchange(0, 1, 0), "Unrelated questions must not advance")
	_begin_drag(0, _card_rect(0).get_center())
	_finish_drag(_question_rect(1, 0).get_center())
	assert(completed_count == 0 and return_index == 0 and drag_index == -1)
	_begin_drag(0, _card_rect(0).get_center())
	_cancel_drag()
	assert(drag_index == -1 and completed_count == 0)
	_reset()
	if DisplayServer.get_name() != "headless":
		await _qa_capture("start")
		selected_memory = 5
		await _qa_capture("memory")
	for index: int in [3, 0, 5, 2, 1, 4]:
		var listener := 1 - int(MEMORIES[index].side)
		_begin_drag(index, _card_rect(index).position + Vector2(5, 5))
		_finish_drag(_question_rect(listener, int(SLOT_ORDER[index])).get_center())
		assert(decoded[index] and drag_index == -1)
		assert(not _exchange(index, listener, int(SLOT_ORDER[index])), "Repeated drops must not advance")
		if completed_count == 2 and DisplayServer.get_name() != "headless":
			await get_tree().create_timer(0.45).timeout
			await _qa_capture("partial")
	assert(completed_count == 6 and ending_time >= 0.0 and _received_count(0) == 3 and _received_count(1) == 3)
	if DisplayServer.get_name() != "headless":
		keyboard_mode = true
		keyboard_index = -1
		hover_index = -1
		await get_tree().create_timer(1.2).timeout
		await _qa_capture("complete")
		selected_memory = 0
		await _qa_capture("reread")
	_reset()
	keyboard_mode = true
	_keyboard_next(-1)
	assert(keyboard_index == 5, "Reverse keyboard selection must start with the last memory")
	assert(_exchange(keyboard_index, 0, 1))
	_reset()
	assert(completed_count == 0 and ending_time < 0.0 and drag_index == -1 and return_index == -1)
	for i in range(6):
		assert(not decoded[i])
	print("QA PASS: contextual matches, shuffled question positions, wrong/same-side/outside drops, cancel, duplicate protection, recipient understanding, keyboard order, completion and reset")
	get_tree().quit(0)


func _qa_capture(label: String) -> void:
	queue_redraw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var destination := OS.get_environment("HEARYOU_QA_DIR")
	if not destination.is_empty():
		image.save_png(destination.path_join(label + ".png"))
