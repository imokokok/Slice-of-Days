extends Control

const StageBackdrop = preload("res://scripts/ui/stage_backdrop.gd")

const INK := Color("4a342b")
const PANEL := Color("fff8eb", 0.96)
const PANEL_SOFT := Color("f1dfc7", 0.97)
const LINE := Color("b88963")
const BONE := Color("4a342b")
const MUTED := Color("806b5c")
const AMBER := Color("c85f43")
const CYAN := Color("4f7d83")
const EMBER := Color("b54f3a")
const SAGE := Color("7d8f59")

var case_data: Dictionary = {}
var selected_subject := ""
var selected_relation := ""
var selected_object := ""
var selected_labels := {"subject": "对象", "relation": "关系", "object": "对象"}
var object_buttons: Dictionary = {}
var relation_buttons: Dictionary = {}

var clock_label: Label
var money_label: Label
var confirmation_label: Label
var subject_slot: Button
var relation_slot: Button
var object_slot: Button
var result_label: RichTextLabel
var fact_label: RichTextLabel
var side_panel: Panel
var side_hidden := false


func _ready() -> void:
	case_data = _load_json("res://data/tarot/demo_case.json")
	_build_scene()
	GameState.state_changed.connect(_refresh_state)
	_refresh_state()
	_refresh_selection()
	if OS.get_cmdline_user_args().has("--capture"):
		capture_prototype.call_deferred()


func _build_scene() -> void:
	var stage := StageBackdrop.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stage)

	_build_header()
	_build_case_caption()
	_build_table_cards()
	_build_question_strip()
	_build_side_panel()
	_build_bottom_drawer()


func _build_header() -> void:
	var header := _make_panel(self, Vector2(0, 0), Vector2(1600, 78), Color("fff8eb", 0.97), LINE)

	var title := _make_label(header, "第七日之前", Vector2(28, 15), Vector2(310, 31), 22, BONE)
	title.add_theme_color_override("font_shadow_color", Color("704936", 0.18))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	_make_label(header, "牌桌推理 · 夏透明的占卜摊", Vector2(28, 43), Vector2(400, 22), 13, MUTED)

	clock_label = _make_label(header, "", Vector2(1080, 17), Vector2(125, 35), 22, BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	money_label = _make_label(header, "", Vector2(1218, 19), Vector2(130, 30), 17, BONE, HORIZONTAL_ALIGNMENT_RIGHT)
	confirmation_label = _make_label(header, "", Vector2(1362, 19), Vector2(190, 30), 17, BONE, HORIZONTAL_ALIGNMENT_RIGHT)

	var back := _make_button(header, "返回小镇", Vector2(1304, 48), Vector2(120, 23), "quiet")
	back.pressed.connect(SceneRouter.town_day)
	var reset := _make_button(header, "清空牌槽", Vector2(1432, 48), Vector2(120, 23), "quiet")
	reset.pressed.connect(_reset_selection)


func _build_case_caption() -> void:
	var caption := _make_panel(self, Vector2(35, 94), Vector2(480, 92), Color("fff8eb", 0.94), LINE)
	_make_label(caption, str(case_data.get("title", "牌桌事件")), Vector2(16, 11), Vector2(440, 28), 20, BONE)
	var opening := _make_label(caption, str(case_data.get("opening", "")), Vector2(16, 42), Vector2(445, 43), 14, MUTED)
	opening.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_table_cards() -> void:
	var object_rows: Array = case_data.get("objects", [])
	var table_positions := [Vector2(330, 522), Vector2(494, 508), Vector2(925, 510), Vector2(1082, 507)]
	for index in object_rows.size():
		var item: Dictionary = object_rows[index]
		var id := str(item.get("id", "object_%d" % index))
		var label := str(item.get("label", "对象"))
		var button := _make_button(self, label, table_positions[index], Vector2(132, 74), "object")
		button.tooltip_text = "选择为提问对象"
		button.pressed.connect(_on_object_pressed.bind(id, label))
		object_buttons[id] = button


func _build_question_strip() -> void:
	var strip := _make_panel(self, Vector2(310, 594), Vector2(850, 61), Color("fff8eb", 0.97), LINE)
	_make_label(strip, "组合问题", Vector2(13, 9), Vector2(100, 20), 13, MUTED)
	subject_slot = _make_button(strip, "对象", Vector2(115, 10), Vector2(155, 40), "slot")
	relation_slot = _make_button(strip, "关系", Vector2(278, 10), Vector2(170, 40), "slot")
	object_slot = _make_button(strip, "对象", Vector2(456, 10), Vector2(155, 40), "slot")
	var ask := _make_button(strip, "提出问题", Vector2(640, 10), Vector2(190, 40), "primary")
	ask.pressed.connect(_ask_question)
	subject_slot.pressed.connect(_clear_subject)
	relation_slot.pressed.connect(_clear_relation)
	object_slot.pressed.connect(_clear_object)


func _build_side_panel() -> void:
	side_panel = _make_panel(self, Vector2(1190, 102), Vector2(372, 542), PANEL, LINE)
	_make_label(side_panel, "事实与回应", Vector2(20, 17), Vector2(220, 29), 20, BONE)
	_make_label(side_panel, "每次提问消耗 10 分钟", Vector2(20, 47), Vector2(250, 20), 12, MUTED)

	var collapse := _make_button(side_panel, "收起", Vector2(288, 15), Vector2(64, 28), "quiet")
	collapse.pressed.connect(_toggle_side_panel.bind(collapse))

	result_label = RichTextLabel.new()
	result_label.position = Vector2(18, 80)
	result_label.size = Vector2(336, 103)
	result_label.bbcode_enabled = true
	result_label.fit_content = false
	result_label.scroll_active = false
	result_label.add_theme_font_size_override("normal_font_size", 15)
	result_label.add_theme_color_override("default_color", BONE)
	result_label.text = "[color=#806b5c]把两张对象牌和一张关系牌放入问题槽。[/color]"
	side_panel.add_child(result_label)

	_make_label(side_panel, "已知事实", Vector2(20, 201), Vector2(160, 25), 16, CYAN)
	fact_label = RichTextLabel.new()
	fact_label.position = Vector2(18, 232)
	fact_label.size = Vector2(336, 190)
	fact_label.bbcode_enabled = true
	fact_label.scroll_active = true
	fact_label.add_theme_font_size_override("normal_font_size", 14)
	fact_label.add_theme_color_override("default_color", BONE.darkened(0.08))
	side_panel.add_child(fact_label)

	_make_label(side_panel, "直接占卜会跳过推理，但需要支付。", Vector2(20, 445), Vector2(330, 20), 12, MUTED)
	var direct := _make_button(side_panel, "支付 100 元直接占卜", Vector2(20, 474), Vector2(332, 45), "danger")
	direct.pressed.connect(_direct_reading)


func _build_bottom_drawer() -> void:
	var drawer := _make_panel(self, Vector2(0, 675), Vector2(1600, 225), Color("fff8eb", 0.98), LINE)
	_make_label(drawer, "牌桌工具", Vector2(28, 17), Vector2(150, 27), 20, BONE)
	_make_label(drawer, "选择一张对象牌，再选择关系牌和第二张对象牌。", Vector2(178, 21), Vector2(450, 20), 13, MUTED)

	var relation_rows: Array = case_data.get("relations", [])
	for index in relation_rows.size():
		var item: Dictionary = relation_rows[index]
		var id := str(item.get("id", "relation_%d" % index))
		var label := str(item.get("label", "关系"))
		var button := _make_button(drawer, label, Vector2(30 + index * 174, 61), Vector2(158, 49), "relation")
		button.pressed.connect(_on_relation_pressed.bind(id, label))
		relation_buttons[id] = button

	_make_label(drawer, "塔罗能力", Vector2(758, 21), Vector2(130, 22), 14, AMBER)
	var abilities := [
		["月亮", "检查是否误认"],
		["隐士", "提示缺失人物"],
		["命运之轮", "检查事件顺序"],
		["正义", "关注规则与交换"],
	]
	for index in abilities.size():
		var ability: Array = abilities[index]
		var button := _make_button(drawer, str(ability[0]), Vector2(758 + index * 198, 61), Vector2(182, 49), "ability")
		button.tooltip_text = str(ability[1])
		button.pressed.connect(_use_tarot_ability.bind(str(ability[0]), str(ability[1])))

	var hint := _make_panel(drawer, Vector2(30, 132), Vector2(1528, 66), PANEL_SOFT, LINE.darkened(0.25))
	_make_label(hint, "操作", Vector2(14, 10), Vector2(56, 20), 13, CYAN)
	var hint_text := _make_label(hint, "点击桌上的对象牌进行选择；再次点击问题槽可以清空。塔罗能力只提供观察方向，不直接给出答案。", Vector2(76, 10), Vector2(1425, 42), 13, BONE.darkened(0.12))
	hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _on_object_pressed(id: String, label: String) -> void:
	if selected_subject.is_empty():
		selected_subject = id
		selected_labels.subject = label
	elif selected_object.is_empty():
		selected_object = id
		selected_labels.object = label
	else:
		selected_subject = selected_object
		selected_labels.subject = selected_labels.object
		selected_object = id
		selected_labels.object = label
	_refresh_selection()


func _on_relation_pressed(id: String, label: String) -> void:
	selected_relation = id
	selected_labels.relation = label
	_refresh_selection()


func _ask_question() -> void:
	if selected_subject.is_empty() or selected_relation.is_empty() or selected_object.is_empty():
		result_label.text = "[color=#c85f43]问题还不完整。需要对象、关系和另一个对象。[/color]"
		return

	GameState.spend_time(10)
	var key := "%s|%s|%s" % [selected_subject, selected_relation, selected_object]
	var answers: Dictionary = case_data.get("answers", {})
	if answers.has(key):
		var answer: Dictionary = answers[key]
		result_label.text = "[color=#4a342b]%s[/color]" % str(answer.get("response", "没有回应。"))
		var fact := str(answer.get("fact", ""))
		if not fact.is_empty():
			GameState.add_fact(fact)
	else:
		result_label.text = "[color=#806b5c]这组牌没有形成有效线索。换一个关系再试。[/color]"


func _direct_reading() -> void:
	if not GameState.spend_money(100):
		result_label.text = "[color=#b54f3a]余额不足，无法直接占卜。[/color]"
		return
	GameState.spend_time(20)
	result_label.text = "[color=#c85f43]牌面没有替你决定结果。它提醒你：空白也可能是一种被反复保存的内容。[/color]"


func _use_tarot_ability(name: String, description: String) -> void:
	GameState.spend_time(5)
	var message := "[color=#4f7d83]%s[/color]\n%s。" % [name, description]
	match name:
		"月亮":
			message += " 目前没有对象被重复确认。"
		"隐士":
			message += " 桌上可能还缺少一位知道信封来历的人。"
		"命运之轮":
			message += " 夜市开放与收信人出现存在明确先后。"
		"正义":
			message += " 注意谁拥有物件，以及谁为一次交换付出成本。"
	result_label.text = message


func _refresh_state() -> void:
	clock_label.text = "第 %d 天  %s" % [GameState.current_day, GameState.clock_text()]
	money_label.text = "余额  %d" % GameState.money
	confirmation_label.text = "认识确认  %d / 12" % GameState.residency_confirmations
	var lines: Array[String] = []
	for fact in GameState.known_facts:
		lines.append("• %s" % fact)
	fact_label.text = "\n\n".join(lines)


func _refresh_selection() -> void:
	subject_slot.text = str(selected_labels.subject)
	relation_slot.text = str(selected_labels.relation)
	object_slot.text = str(selected_labels.object)
	for id in object_buttons:
		var active: bool = id == selected_subject or id == selected_object
		_apply_button_style(object_buttons[id], "object_active" if active else "object")
	for id in relation_buttons:
		_apply_button_style(relation_buttons[id], "relation_active" if id == selected_relation else "relation")


func _clear_subject() -> void:
	selected_subject = ""
	selected_labels.subject = "对象"
	_refresh_selection()


func _clear_relation() -> void:
	selected_relation = ""
	selected_labels.relation = "关系"
	_refresh_selection()


func _clear_object() -> void:
	selected_object = ""
	selected_labels.object = "对象"
	_refresh_selection()


func _reset_selection() -> void:
	selected_subject = ""
	selected_relation = ""
	selected_object = ""
	selected_labels = {"subject": "对象", "relation": "关系", "object": "对象"}
	result_label.text = "[color=#806b5c]把两张对象牌和一张关系牌放入问题槽。[/color]"
	_refresh_selection()


func _toggle_side_panel(button: Button) -> void:
	side_hidden = not side_hidden
	side_panel.position.x = 1510 if side_hidden else 1190
	button.text = "展开" if side_hidden else "收起"


func _make_panel(parent: Node, at: Vector2, panel_size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	if panel_size.x < 1500:
		style.set_corner_radius_all(16)
		style.shadow_color = Color("704936", 0.18)
		style.shadow_size = 9
		style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _make_label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, kind: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14)
	_apply_button_style(button, kind)
	parent.add_child(button)
	return button


func _apply_button_style(button: Button, kind: String) -> void:
	var base := Color("fff9ed", 0.96)
	var edge := LINE
	var font_color := BONE
	match kind:
		"primary":
			base = AMBER
			edge = AMBER.darkened(0.12)
			font_color = Color("fff8e8")
		"danger":
			base = Color("f2cabc")
			edge = EMBER
		"object":
			base = Color("fff9ed", 0.97)
			edge = LINE
		"object_active":
			base = AMBER
			edge = AMBER
			font_color = Color("fff8e8")
		"relation":
			base = Color("dce8df")
			edge = CYAN
		"relation_active":
			base = CYAN
			edge = CYAN
			font_color = Color("fff8e8")
		"ability":
			base = Color("e2e8cf")
			edge = SAGE
		"slot":
			base = Color("fff9ed")
			edge = LINE
		"quiet":
			base = Color("f6e9d6", 0.92)
			edge = Color(LINE, 0.75)
			font_color = MUTED

	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.border_color = edge
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.shadow_color = Color("704936", 0.13)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)

	var hover := normal.duplicate()
	hover.bg_color = base.lightened(0.12)
	hover.border_color = edge.lightened(0.18)

	var pressed := normal.duplicate()
	pressed.bg_color = base.darkened(0.12)
	pressed.border_color = edge.lightened(0.28)
	pressed.shadow_size = 1

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON data: %s" % path)
		return {}
	return parsed


func capture_prototype() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var destination := ProjectSettings.globalize_path("res://captures/tarot-prototype.png")
	var error := image.save_png(destination)
	if error != OK:
		push_error("Could not save capture: %s" % error)
	get_tree().quit()
