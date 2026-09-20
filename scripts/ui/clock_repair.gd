extends Control

const REWARD_KEY := "community_clock_repair_paid"
const INK := Color("31658b")
const MUTED := Color("698594")
const PAPER := Color("faf7ee")
const TERRACOTTA := Color("31658b")
const SEA := Color("31658b")
const GOLD := Color("eed577")
const FACE_CENTER := Vector2(800, 425)
const FACE_RADIUS := 205.0

var target_hour := 10
var target_minute := 20
var reward := 20
var hour_value := 7
var minute_value := 35
var selected_hand := "minute"
var dragging := false
var status_label: Label
var time_label: Label
var hour_button: Button
var minute_button: Button
var submit_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	add_to_group("world_tool")
	_build_ui()
	_refresh()


func _build_ui() -> void:
	_label("社区中心 · 旧钟校准", Vector2(72, 55), Vector2(620, 44), 29, INK)
	_label("校时单", Vector2(1125, 150), Vector2(280, 35), 18, TERRACOTTA)
	_label("请把旧钟调到", Vector2(1125, 205), Vector2(300, 34), 20, MUTED)
	_label(_format_time(target_hour, target_minute), Vector2(1115, 245), Vector2(320, 70), 46, INK)
	_label("先选择时针或分针，再在钟面上拖动。\n也可以用下方按钮逐格微调。", Vector2(1085, 330), Vector2(365, 90), 18, MUTED)
	status_label = _label("", Vector2(1085, 600), Vector2(370, 72), 18, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	time_label = _label("", Vector2(610, 676), Vector2(380, 36), 22, INK, HORIZONTAL_ALIGNMENT_CENTER)

	hour_button = _button("时针", Vector2(490, 735), Vector2(125, 48), _select_hand.bind("hour"))
	minute_button = _button("分针", Vector2(630, 735), Vector2(125, 48), _select_hand.bind("minute"))
	hour_button.toggle_mode = true
	minute_button.toggle_mode = true
	_button("−", Vector2(775, 735), Vector2(64, 48), _step_selected.bind(-1))
	_button("+", Vector2(853, 735), Vector2(64, 48), _step_selected.bind(1))
	submit_button = _button("确认时间", Vector2(1085, 704), Vector2(240, 55), _submit)
	_button("收起", Vector2(1340, 704), Vector2(120, 55), queue_free)


func _label(text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = LocalizationSystem.text(text_value)
	label.position = at
	label.size = label_size
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _button(text_value: String, at: Vector2, button_size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = LocalizationSystem.text(text_value)
	button.position = at
	button.size = button_size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	add_child(button)
	return button


func _select_hand(hand: String) -> void:
	selected_hand = hand
	_refresh()


func _step_selected(direction: int) -> void:
	if selected_hand == "hour":
		hour_value = posmod(hour_value - 1 + direction, 12) + 1
	else:
		minute_value = posmod(minute_value + direction * 5, 60)
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.distance_to(FACE_CENTER) <= FACE_RADIUS + 24:
			dragging = true
			_set_hand_from_pointer(event.position)
		elif not event.pressed:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		_set_hand_from_pointer(event.position)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		queue_free()
	elif event.is_action_pressed("ui_left"):
		_step_selected(-1)
	elif event.is_action_pressed("ui_right"):
		_step_selected(1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		_select_hand("hour" if selected_hand == "minute" else "minute")
	else:
		return
	get_viewport().set_input_as_handled()


func _set_hand_from_pointer(pointer: Vector2) -> void:
	var vector := pointer - FACE_CENTER
	var turns := fposmod(atan2(vector.y, vector.x) + PI / 2.0, TAU) / TAU
	if selected_hand == "hour":
		var clock_hour := int(round(turns * 12.0)) % 12
		hour_value = 12 if clock_hour == 0 else clock_hour
	else:
		minute_value = (int(round(turns * 12.0)) % 12) * 5
	_refresh()


func _submit() -> void:
	if _is_paid():
		status_label.text = LocalizationSystem.text("这只钟已经校准过，20 元工钱也已经领过了。")
		return
	if not is_correct():
		status_label.text = LocalizationSystem.text("还没对准。再看看校时单上的时间。")
		WorldSound.play_ui("dialogue")
		return
	GameState.shared_state[REWARD_KEY] = true
	GameState.earn_money(reward, "校准社区中心旧钟", {
		"kind": "income",
		"issuer": "print_shop",
		"source": "community_clock_repair",
	})
	GameState.add_journal_entry({
		"id": "community_clock_repair",
		"kind": "work",
		"text": "把社区中心的旧钟校准到 %s，领到 %d 元工钱。" % [_format_time(target_hour, target_minute), reward],
	})
	SaveManager.save_or_report("旧钟校准后保存失败")
	WorldSound.play_ui("coin")
	status_label.text = LocalizationSystem.text("指针与校时单完全一致。工钱 +%d 元，已经放进钱包。" % reward)
	_refresh()


func is_correct() -> bool:
	return hour_value == target_hour and minute_value == target_minute


func _is_paid() -> bool:
	return bool(GameState.shared_state.get(REWARD_KEY, false))


func _refresh() -> void:
	if not is_instance_valid(time_label):
		return
	time_label.text = LocalizationSystem.text("当前 %s" % _format_time(hour_value, minute_value))
	hour_button.button_pressed = selected_hand == "hour"
	minute_button.button_pressed = selected_hand == "minute"
	if _is_paid():
		submit_button.text = LocalizationSystem.text("已经校准 · 已领 20 元")
	else:
		submit_button.text = LocalizationSystem.text("确认时间 · +%d 元" % reward)
	queue_redraw()


func _format_time(hour: int, minute: int) -> String:
	return "%02d:%02d" % [hour, minute]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("17232b", 0.9))
	draw_style_box(_paper_style(), Rect2(45, 35, 1510, 795))
	draw_rect(Rect2(1045, 125, 440, 660), Color("f7e7c8"), true)
	draw_line(Vector2(1065, 445), Vector2(1465, 445), Color(GOLD, 0.5), 2)

	# Clock case and minute marks.
	draw_circle(FACE_CENTER, FACE_RADIUS + 24, Color("6b4b38"))
	draw_circle(FACE_CENTER, FACE_RADIUS + 13, Color("d4b176"))
	draw_circle(FACE_CENTER, FACE_RADIUS, Color("f9edcf"))
	for index in range(60):
		var angle := float(index) / 60.0 * TAU - PI / 2.0
		var outer := FACE_CENTER + Vector2(cos(angle), sin(angle)) * (FACE_RADIUS - 12)
		var length := 20.0 if index % 5 == 0 else 9.0
		var inner := FACE_CENTER + Vector2(cos(angle), sin(angle)) * (FACE_RADIUS - 12 - length)
		draw_line(inner, outer, INK, 4.0 if index % 5 == 0 else 1.5, true)
	for number in range(1, 13):
		var angle := float(number) / 12.0 * TAU - PI / 2.0
		var at := FACE_CENTER + Vector2(cos(angle), sin(angle)) * 151.0
		draw_string(ThemeDB.fallback_font, at + Vector2(-13, 9), str(number), HORIZONTAL_ALIGNMENT_CENTER, 26, 24, INK)

	var minute_angle := float(minute_value) / 60.0 * TAU - PI / 2.0
	var hour_angle := (float(hour_value % 12) + float(minute_value) / 60.0) / 12.0 * TAU - PI / 2.0
	var hour_color := TERRACOTTA if selected_hand == "hour" else INK
	var minute_color := TERRACOTTA if selected_hand == "minute" else SEA
	draw_line(FACE_CENTER, FACE_CENTER + Vector2(cos(hour_angle), sin(hour_angle)) * 105.0, hour_color, 13.0, true)
	draw_line(FACE_CENTER, FACE_CENTER + Vector2(cos(minute_angle), sin(minute_angle)) * 158.0, minute_color, 8.0, true)
	draw_circle(FACE_CENTER, 13, GOLD)
	draw_circle(FACE_CENTER, 5, INK)


func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color("d1b886")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.shadow_color = Color("000000", 0.25)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 7)
	return style
