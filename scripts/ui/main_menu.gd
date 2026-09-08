extends Control

const INK := Color("07090f")
const BONE := Color("d8d0bd")
const MUTED := Color("819092")
const AMBER := Color("d98a39")
const CYAN := Color("58abb2")
const PANEL := Color(0.025, 0.039, 0.052, 0.99)
const LINE := Color("40515a")
const SURVEY_ACCESS_CODE := "100"

var survey_gate: Control
var survey_code_input: LineEdit
var survey_error_label: Label


func _ready() -> void:
	_build_ui()
	var args := OS.get_cmdline_user_args()
	if args.has("--capture-menu"):
		_capture.call_deferred("main-menu.png")
	elif args.has("--capture-survey-gate"):
		_show_survey_gate()
		_capture.call_deferred("npc-survey-gate.png")


func _draw() -> void:
	var sx := size.x / 1600.0
	var sy := size.y / 900.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
	draw_rect(Rect2(0, 0, 1600, 900), INK)
	# Seven days form a road across an otherwise empty stage.
	var road := PackedVector2Array([
		Vector2(0, 705), Vector2(260, 630), Vector2(470, 665), Vector2(700, 565),
		Vector2(930, 600), Vector2(1180, 510), Vector2(1600, 550), Vector2(1600, 690),
		Vector2(1190, 650), Vector2(940, 730), Vector2(710, 680), Vector2(480, 770),
		Vector2(270, 735), Vector2(0, 820)
	])
	draw_colored_polygon(road, Color("151d2b"))
	for index in 7:
		var x := 150.0 + index * 210.0
		var color := AMBER if index == 0 else Color("273849")
		draw_circle(Vector2(x, 680.0 - sin(index * 0.8) * 60.0), 8.0, color)
	# Incomplete town planes.
	draw_colored_polygon(PackedVector2Array([Vector2(980, 170), Vector2(1180, 110), Vector2(1160, 475), Vector2(930, 505)]), Color("101d28"))
	draw_colored_polygon(PackedVector2Array([Vector2(1210, 235), Vector2(1445, 175), Vector2(1480, 500), Vector2(1228, 477)]), Color("261922"))
	draw_line(Vector2(0, 530), Vector2(1600, 470), Color(0.65, 0.2, 0.22, 0.35), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_ui() -> void:
	_make_label("WHAT 100 PEOPLE DO TO A GAME", Vector2(85, 105), Vector2(900, 58), 38, BONE)
	_make_label("七天 · 两种时间 · 一座只在被理解时亮起的小镇", Vector2(88, 170), Vector2(750, 32), 17, MUTED)
	_make_label("垂直切片  01", Vector2(90, 250), Vector2(300, 25), 14, AMBER)

	var a := _make_button("从 A 的一天开始", Vector2(88, 300), Vector2(320, 58), AMBER)
	var b := _make_button("从 B 的一天开始", Vector2(88, 373), Vector2(320, 58), CYAN)
	var tarot := _make_button("打开牌桌推理原型", Vector2(88, 470), Vector2(320, 50), Color("7d445c"))
	var continue_button := _make_button("继续上次进度", Vector2(88, 535), Vector2(320, 50), Color("394852"))
	var survey_results := _make_button("查看 NPC 调查问卷结果", Vector2(88, 600), Vector2(320, 50), CYAN)
	continue_button.disabled = not SaveManager.has_save()

	a.pressed.connect(_start_role.bind("A"))
	b.pressed.connect(_start_role.bind("B"))
	tarot.pressed.connect(SceneRouter.tarot_table)
	continue_button.pressed.connect(_continue_game)
	survey_results.pressed.connect(_show_survey_gate)

	_make_label("A 先行动，再从结果调整。", Vector2(445, 311), Vector2(390, 30), 15, BONE.darkened(0.08))
	_make_label("B 先确认时间、路线和费用。", Vector2(445, 384), Vector2(390, 30), 15, BONE.darkened(0.08))
	_make_label("当前目标：在同一天找到夏透明，并获得一份居民确认。", Vector2(90, 805), Vector2(720, 30), 15, MUTED)
	_build_survey_gate()


func _start_role(role: String) -> void:
	GameState.begin_vertical_slice(role)
	SceneRouter.town_day()


func _continue_game() -> void:
	if SaveManager.load_game():
		SceneRouter.town_day()


func _build_survey_gate() -> void:
	survey_gate = Control.new()
	survey_gate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	survey_gate.mouse_filter = Control.MOUSE_FILTER_STOP
	survey_gate.visible = false
	add_child(survey_gate)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	survey_gate.add_child(dimmer)

	var panel := Panel.new()
	panel.position = Vector2(525, 270)
	panel.size = Vector2(550, 310)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL
	panel_style.border_color = LINE
	panel_style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", panel_style)
	survey_gate.add_child(panel)

	_make_label_in(panel, "受限资料", Vector2(28, 24), Vector2(200, 24), 14, CYAN)
	_make_label_in(panel, "查看 NPC 调查问卷结果", Vector2(28, 57), Vector2(490, 34), 24, BONE)
	_make_label_in(panel, "请输入访问验证码后继续。", Vector2(28, 102), Vector2(490, 24), 14, MUTED)

	survey_code_input = LineEdit.new()
	survey_code_input.position = Vector2(28, 142)
	survey_code_input.size = Vector2(494, 46)
	survey_code_input.placeholder_text = "验证码"
	survey_code_input.secret = true
	survey_code_input.max_length = 12
	survey_code_input.add_theme_font_size_override("font_size", 17)
	survey_code_input.text_submitted.connect(_on_survey_code_submitted)
	panel.add_child(survey_code_input)

	survey_error_label = _make_label_in(panel, "", Vector2(28, 194), Vector2(494, 24), 13, Color("d06458"))
	var cancel := _make_button_in(panel, "取消", Vector2(278, 239), Vector2(116, 43), Color("394852"))
	var confirm := _make_button_in(panel, "验证并查看", Vector2(406, 239), Vector2(116, 43), CYAN)
	cancel.pressed.connect(_close_survey_gate)
	confirm.pressed.connect(_verify_survey_code)


func _show_survey_gate() -> void:
	survey_code_input.clear()
	survey_error_label.text = ""
	survey_gate.visible = true
	survey_code_input.grab_focus()


func _close_survey_gate() -> void:
	survey_gate.visible = false


func _on_survey_code_submitted(_value: String) -> void:
	_verify_survey_code()


func _verify_survey_code() -> void:
	if survey_code_input.text.strip_edges() == SURVEY_ACCESS_CODE:
		SceneRouter.npc_survey_results()
		return
	survey_error_label.text = "验证码不正确，请重试。"
	survey_code_input.select_all()
	survey_code_input.grab_focus()


func _make_label(text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	return _make_label_in(self, text_value, at, label_size, font_size, color)


func _make_label_in(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_button(text_value: String, at: Vector2, button_size: Vector2, accent: Color) -> Button:
	return _make_button_in(self, text_value, at, button_size, accent)


func _make_button_in(parent: Node, text_value: String, at: Vector2, button_size: Vector2, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.18)
	style.border_color = Color(accent, 0.8)
	style.set_border_width_all(1)
	var hover := style.duplicate()
	hover.bg_color = Color(accent, 0.32)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", BONE)
	parent.add_child(button)
	return button


func _capture(file_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/%s" % file_name))
	get_tree().quit()
