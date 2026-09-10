extends Control

const StageBackdrop = preload("res://scripts/ui/stage_backdrop.gd")
const TarotEngine = preload("res://scripts/core/tarot_case_engine.gd")

const INK := Color("3d2d29")
const PAPER := Color("fff8eb", 0.97)
const PAPER_SOFT := Color("f1dfc7", 0.97)
const LINE := Color("b88963")
const MUTED := Color("806b5c")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")
const SAGE := Color("7d8f59")
const GOLD := Color("c99545")

var engine := TarotEngine.new()
var rng := RandomNumberGenerator.new()
var case_index := 0
var case_data: Dictionary = {}
var current_draw: Array[String] = []
var draw_pile: Array[String] = []
var picked_pile_indices: Array[int] = []
var choosing_cards := false
var selected_card_id := ""
var selected_image_id := ""
var selected_cross_cards: Array[String] = []
var confirmed_cards: Dictionary = {}
var records: Array[Dictionary] = []
var round_no := 0
var miss_streak := 0
var round_locked := false

var clock_label: Label
var money_label: Label
var confirmation_label: Label
var case_eyebrow: Label
var case_title: Label
var opening_label: Label
var round_label: Label
var shuffle_button: Button
var mode_label: Label
var card_layer: Control
var detail_title: Label
var detail_theme: Label
var image_layer: Control
var question_edit: LineEdit
var ask_button: Button
var next_button: Button
var cross_button: Button
var result_label: RichTextLabel
var record_label: RichTextLabel
var world_overlay: ColorRect
var world_answer: TextEdit
var world_feedback: Label
var case_buttons: Array[Button] = []
var suggested_case_index := -1
var pending_case_switch_index := -1


func _ready() -> void:
	rng.randomize()
	if not engine.load_data("res://data/tarot/major_arcana.json", "res://data/tarot/cases.json"):
		push_error("Solmere tarot data could not be loaded")
		return
	_build_scene()
	GameState.state_changed.connect(_refresh_state)
	_refresh_state()
	_start_case(0)
	var args := OS.get_cmdline_user_args()
	if args.has("--capture-world"):
		_open_world()
		capture_prototype.call_deferred("solmere-tarot-world.png")
	elif args.has("--capture-wrong-case"):
		choosing_cards = false
		current_draw = ["temperance", "justice", "wheel"]
		_render_draw()
		_select_card("temperance")
		_select_image("cups")
		question_edit.text = "报警的人有没有走进过屋子里？"
		_ask_question()
		capture_prototype.call_deferred("solmere-tarot-wrong-case.png")
	elif args.has("--capture-response"):
		_start_case(1)
		choosing_cards = false
		current_draw = ["chariot", "lovers", "justice"]
		_render_draw()
		_select_card("chariot")
		_select_image("city")
		question_edit.text = "报警的人有没有走进过屋子里？"
		_ask_question()
		capture_prototype.call_deferred("solmere-tarot-response.png")
	elif args.has("--capture-detail") and not current_draw.is_empty():
		_select_card(current_draw[0])
		var images: Array = engine.card(current_draw[0]).get("images", [])
		if not images.is_empty():
			_select_image(str((images[0] as Dictionary).get("id", "")))
		capture_prototype.call_deferred("solmere-tarot-detail.png")
	elif args.has("--capture"):
		capture_prototype.call_deferred("solmere-tarot.png")


func _build_scene() -> void:
	var stage := StageBackdrop.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	_build_header()
	_build_case_panel()
	_build_reading_panel()
	_build_question_panel()
	_build_record_panel()
	_build_world_overlay()


func _build_header() -> void:
	var header := _make_panel(self, Vector2.ZERO, Vector2(1600, 76), Color("fff8eb", 0.98), LINE)
	var brand := _make_label(header, "SOLMERE", Vector2(28, 9), Vector2(250, 35), 27, INK)
	brand.add_theme_color_override("font_shadow_color", Color("704936", 0.16))
	brand.add_theme_constant_override("shadow_offset_x", 2)
	brand.add_theme_constant_override("shadow_offset_y", 2)
	_make_label(header, "塔罗海龟汤 · 牌面引导自由推理", Vector2(29, 40), Vector2(430, 23), 13, MUTED)
	clock_label = _make_label(header, "", Vector2(1050, 15), Vector2(145, 33), 20, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	money_label = _make_label(header, "", Vector2(1208, 16), Vector2(120, 31), 16, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	confirmation_label = _make_label(header, "", Vector2(1340, 16), Vector2(210, 31), 16, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	var back := _make_button(header, "返回小镇", Vector2(1422, 47), Vector2(128, 24), "quiet")
	back.pressed.connect(_return_to_town)


func _build_case_panel() -> void:
	var panel := _make_panel(self, Vector2(24, 94), Vector2(338, 782), PAPER, LINE)
	case_eyebrow = _make_label(panel, "", Vector2(20, 16), Vector2(294, 22), 13, TEAL)
	case_title = _make_label(panel, "", Vector2(20, 42), Vector2(294, 38), 25, INK)
	opening_label = _make_label(panel, "", Vector2(20, 88), Vector2(298, 238), 15, INK)
	opening_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opening_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_make_label(panel, "选择谜题", Vector2(20, 340), Vector2(120, 22), 14, MUTED)
	var first_case := _make_button(panel, "四扇门", Vector2(20, 372), Vector2(142, 42), "case")
	var second_case := _make_button(panel, "门外目击者", Vector2(176, 372), Vector2(142, 42), "case")
	case_buttons = [first_case, second_case]
	first_case.pressed.connect(_start_case.bind(0))
	second_case.pressed.connect(_start_case.bind(1))
	var world_card := _make_button(panel, "XXI  THE WORLD\n提交完整汤底", Vector2(20, 448), Vector2(298, 104), "world")
	world_card.pressed.connect(_open_world)
	var help := _make_label(panel, "每轮只能完成一次 Reading\n\n1  洗牌并从牌背中亲选三张\n2  翻牌后选择一张与牌面意象\n3  围绕牌义和意象自由提问\n4  关键 YES 留入牌阵\n5  已确认的牌可深读或交叉", Vector2(20, 582), Vector2(296, 178), 14, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.vertical_alignment = VERTICAL_ALIGNMENT_TOP


func _build_reading_panel() -> void:
	var panel := _make_panel(self, Vector2(382, 94), Vector2(784, 442), PAPER, LINE)
	_make_label(panel, "本轮抽牌", Vector2(20, 14), Vector2(150, 26), 19, INK)
	shuffle_button = _make_button(panel, "洗牌", Vector2(526, 10), Vector2(88, 32), "shuffle")
	shuffle_button.pressed.connect(_shuffle_pile)
	round_label = _make_label(panel, "", Vector2(620, 14), Vector2(140, 26), 14, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	card_layer = Control.new()
	card_layer.position = Vector2(0, 48)
	panel.add_child(card_layer)
	detail_title = _make_label(panel, "先选择一张牌", Vector2(22, 252), Vector2(400, 30), 20, INK)
	detail_theme = _make_label(panel, "牌名给出方向，意象缩小提问范围。", Vector2(22, 282), Vector2(720, 24), 14, MUTED)
	_make_label(panel, "可读意象", Vector2(22, 317), Vector2(110, 22), 13, TEAL)
	image_layer = Control.new()
	image_layer.position = Vector2(14, 344)
	panel.add_child(image_layer)


func _build_question_panel() -> void:
	var panel := _make_panel(self, Vector2(382, 553), Vector2(784, 323), PAPER, LINE)
	_make_label(panel, "自由提问", Vector2(20, 14), Vector2(145, 27), 19, INK)
	mode_label = _make_label(panel, "", Vector2(180, 14), Vector2(575, 27), 13, TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	question_edit = LineEdit.new()
	question_edit.position = Vector2(20, 51)
	question_edit.size = Vector2(570, 48)
	question_edit.placeholder_text = "围绕所选牌与意象，输入一个可以用 YES / NO 回答的问题"
	question_edit.add_theme_font_size_override("font_size", 15)
	question_edit.add_theme_color_override("font_color", INK)
	question_edit.add_theme_color_override("font_placeholder_color", Color(MUTED, 0.72))
	question_edit.add_theme_stylebox_override("normal", _input_style())
	question_edit.text_submitted.connect(_on_question_submitted)
	panel.add_child(question_edit)
	ask_button = _make_button(panel, "进行 Reading", Vector2(604, 51), Vector2(160, 48), "primary")
	ask_button.pressed.connect(_ask_question)
	result_label = RichTextLabel.new()
	result_label.position = Vector2(20, 116)
	result_label.size = Vector2(744, 91)
	result_label.bbcode_enabled = true
	result_label.fit_content = false
	result_label.scroll_active = false
	result_label.add_theme_font_size_override("normal_font_size", 15)
	result_label.add_theme_color_override("default_color", INK)
	panel.add_child(result_label)
	cross_button = _make_button(panel, "交叉解读尚未解锁", Vector2(20, 244), Vector2(285, 48), "cross")
	cross_button.disabled = true
	cross_button.pressed.connect(_select_next_cross_pair)
	next_button = _make_button(panel, "开始下一轮", Vector2(584, 244), Vector2(180, 48), "primary")
	next_button.disabled = true
	next_button.pressed.connect(_on_next_pressed)
	var pace_note := _make_label(panel, "一次 Reading 消耗 10 分钟\n建议 4–6 轮后尝试 The World", Vector2(320, 238), Vector2(246, 58), 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	pace_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_record_panel() -> void:
	var panel := _make_panel(self, Vector2(1186, 94), Vector2(390, 782), PAPER, LINE)
	_make_label(panel, "牌阵与记录", Vector2(20, 16), Vector2(210, 30), 21, INK)
	_make_label(panel, "关键 YES 留牌 · NO 写入排除记录", Vector2(20, 47), Vector2(350, 22), 13, MUTED)
	record_label = RichTextLabel.new()
	record_label.position = Vector2(18, 82)
	record_label.size = Vector2(356, 678)
	record_label.bbcode_enabled = true
	record_label.scroll_active = true
	record_label.add_theme_font_size_override("normal_font_size", 14)
	record_label.add_theme_color_override("default_color", INK)
	panel.add_child(record_label)


func _build_world_overlay() -> void:
	world_overlay = ColorRect.new()
	world_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_overlay.color = Color(INK, 0.62)
	world_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(world_overlay)
	var panel := _make_panel(world_overlay, Vector2(410, 160), Vector2(780, 580), Color("fff8eb"), GOLD)
	_make_label(panel, "XXI  THE WORLD", Vector2(34, 27), Vector2(710, 38), 27, INK)
	_make_label(panel, "提交完整汤底", Vector2(34, 68), Vector2(710, 27), 17, TEAL)
	var prompt := _make_label(panel, "请闭合人物、动机、行动、因果与结果。答案不要求逐字一致，但必须包含关键环节。", Vector2(34, 106), Vector2(712, 54), 15, MUTED)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_answer = TextEdit.new()
	world_answer.position = Vector2(34, 176)
	world_answer.size = Vector2(712, 210)
	world_answer.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	world_answer.add_theme_font_size_override("font_size", 16)
	world_answer.add_theme_color_override("font_color", INK)
	world_answer.add_theme_stylebox_override("normal", _input_style())
	panel.add_child(world_answer)
	world_feedback = _make_label(panel, "", Vector2(34, 399), Vector2(712, 66), 14, TERRACOTTA)
	world_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cancel := _make_button(panel, "继续推理", Vector2(34, 495), Vector2(180, 50), "quiet")
	cancel.pressed.connect(_close_world)
	var submit := _make_button(panel, "翻开世界", Vector2(546, 495), Vector2(200, 50), "world")
	submit.pressed.connect(_submit_world)
	world_overlay.visible = false


func _start_case(index: int) -> void:
	if index < 0 or index >= engine.cases.size():
		return
	case_index = index
	suggested_case_index = -1
	pending_case_switch_index = -1
	case_data = engine.case_at(index)
	confirmed_cards.clear()
	records.clear()
	round_no = 0
	miss_streak = 0
	round_locked = false
	case_eyebrow.text = str(case_data.get("eyebrow", "海龟汤"))
	case_title.text = str(case_data.get("title", "未命名谜题"))
	opening_label.text = str(case_data.get("opening", ""))
	var examples: Array = case_data.get("question_examples", [])
	question_edit.placeholder_text = "例如：%s" % str(examples[0]) if not examples.is_empty() else "围绕所选牌与意象提出一个 YES / NO 问题"
	result_label.text = "[color=#806b5c]三张牌会给出三个观察方向。选择一张开始。[/color]"
	_refresh_case_buttons()
	_refresh_records()
	_draw_round()


func _draw_round() -> void:
	round_no += 1
	round_locked = false
	choosing_cards = true
	current_draw.clear()
	picked_pile_indices.clear()
	selected_card_id = ""
	selected_image_id = ""
	selected_cross_cards.clear()
	_prepare_draw_pile()
	question_edit.clear()
	question_edit.editable = false
	ask_button.disabled = true
	next_button.disabled = true
	next_button.text = "开始下一轮"
	shuffle_button.disabled = false
	shuffle_button.text = "洗牌"
	mode_label.text = "洗牌后，凭直觉亲自选择三张牌"
	result_label.text = "[color=#806b5c]所有牌都背面朝上。可以反复洗牌，再用鼠标选满三张。[/color]"
	_render_pile()
	_render_card_detail("")
	_refresh_cross_button()


func _prepare_draw_pile() -> void:
	draw_pile.clear()
	for raw_card_id in case_data.get("deck", []):
		draw_pile.append(str(raw_card_id))
	_shuffle_card_ids(draw_pile)


func _shuffle_card_ids(cards: Array[String]) -> void:
	for index in range(cards.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = held


func _shuffle_pile() -> void:
	if not choosing_cards:
		return
	picked_pile_indices.clear()
	_shuffle_card_ids(draw_pile)
	shuffle_button.text = "已洗牌"
	mode_label.text = "牌序已打乱 · 请选择 3 张"
	result_label.text = "[color=#4f7d83]牌已经重新打乱。现在凭直觉选择三张牌。[/color]"
	_render_pile()


func _render_pile() -> void:
	_clear_children(card_layer)
	var count := draw_pile.size()
	if count == 0:
		return
	var card_width := 96.0
	var available_width := 736.0
	var step := 0.0 if count <= 1 else minf(92.0, (available_width - card_width) / float(count - 1))
	var total_width := card_width + step * float(count - 1)
	var start_x := (784.0 - total_width) * 0.5
	for index in count:
		var picked := picked_pile_indices.has(index)
		var distance_from_center := absf(float(index) - float(count - 1) * 0.5)
		var y_offset := distance_from_center * 2.0
		var text_value := "已选\n%d / 3" % (picked_pile_indices.find(index) + 1) if picked else "✦\nSOLMERE\n塔罗"
		var kind := "card_back_picked" if picked else "card_back"
		var button := _make_button(card_layer, text_value, Vector2(start_x + step * index, y_offset), Vector2(card_width, 166), kind)
		button.tooltip_text = "第 %d 张牌背" % (index + 1)
		button.pressed.connect(_pick_pile_card.bind(index))
	round_label.text = "第 %d 轮 · 已选 %d / 3" % [round_no, picked_pile_indices.size()]


func _pick_pile_card(index: int) -> void:
	if not choosing_cards or index < 0 or index >= draw_pile.size() or picked_pile_indices.has(index):
		return
	picked_pile_indices.append(index)
	if picked_pile_indices.size() < 3:
		mode_label.text = "已选 %d 张 · 还需 %d 张" % [picked_pile_indices.size(), 3 - picked_pile_indices.size()]
		shuffle_button.text = "重新洗牌"
		_render_pile()
		return
	current_draw.clear()
	for picked_index in picked_pile_indices:
		current_draw.append(draw_pile[picked_index])
	choosing_cards = false
	shuffle_button.disabled = true
	shuffle_button.text = "抽牌完成"
	round_label.text = "第 %d 轮 · 已翻开 3 张" % round_no
	question_edit.editable = true
	ask_button.disabled = false
	mode_label.text = "三张牌已翻开 · 选择其中一张"
	result_label.text = "[color=#4f7d83]这是你亲自抽出的三张牌。请选择一张，再点亮一个牌面意象。[/color]"
	_render_draw()
	_render_card_detail("")
	_refresh_cross_button()


func _render_draw() -> void:
	_clear_children(card_layer)
	for index in current_draw.size():
		var card_id := current_draw[index]
		var card: Dictionary = engine.card(card_id)
		var deep_mark := "\n◆ 可深读" if confirmed_cards.has(card_id) else ""
		var text_value := "%s\n%s\n%s%s" % [str(card.get("number", "")), str(card.get("name", "")), str(card.get("name_zh", "")), deep_mark]
		var kind := "tarot_active" if card_id == selected_card_id else "tarot"
		var button := _make_button(card_layer, text_value, Vector2(20 + index * 252, 0), Vector2(236, 176), kind)
		button.tooltip_text = str(card.get("theme", ""))
		button.pressed.connect(_select_card.bind(card_id))


func _select_card(card_id: String) -> void:
	if round_locked or choosing_cards:
		return
	selected_card_id = card_id
	selected_image_id = ""
	selected_cross_cards.clear()
	var card := engine.card(card_id)
	var mode := "深读已有牌" if confirmed_cards.has(card_id) else "读取新牌"
	mode_label.text = "%s · %s" % [mode, str(card.get("name_zh", ""))]
	_render_draw()
	_render_card_detail(card_id)
	_refresh_cross_button()


func _render_card_detail(card_id: String) -> void:
	_clear_children(image_layer)
	if card_id.is_empty():
		detail_title.text = "先选择一张牌"
		detail_theme.text = "牌名给出方向，意象缩小提问范围。"
		return
	var card := engine.card(card_id)
	detail_title.text = "%s  %s  %s" % [str(card.get("number", "")), str(card.get("name", "")), str(card.get("name_zh", ""))]
	detail_theme.text = str(card.get("theme", ""))
	var images: Array = card.get("images", [])
	for index in images.size():
		var image_data: Dictionary = images[index]
		var image_id := str(image_data.get("id", ""))
		var button_text := "%s\n%s" % [str(image_data.get("label", "")), str(image_data.get("keywords", ""))]
		var kind := "image_active" if image_id == selected_image_id else "image"
		var button := _make_button(image_layer, button_text, Vector2(index * 185, 0), Vector2(172, 72), kind)
		button.pressed.connect(_select_image.bind(image_id))


func _select_image(image_id: String) -> void:
	if round_locked or choosing_cards or selected_card_id.is_empty():
		return
	selected_image_id = image_id
	_render_card_detail(selected_card_id)
	var card := engine.card(selected_card_id)
	var image_name := ""
	for raw_image in card.get("images", []):
		var image_data: Dictionary = raw_image
		if str(image_data.get("id", "")) == image_id:
			image_name = str(image_data.get("label", ""))
			break
	mode_label.text = "%s · %s" % [str(card.get("name_zh", "")), image_name]
	question_edit.grab_focus()


func _select_next_cross_pair() -> void:
	if round_locked or choosing_cards:
		return
	var pairs := _available_cross_pairs()
	if pairs.is_empty():
		return
	var next_index := 0
	if not selected_cross_cards.is_empty():
		for index in pairs.size():
			if pairs[index] == selected_cross_cards:
				next_index = (index + 1) % pairs.size()
				break
	selected_cross_cards = (pairs[next_index] as Array).duplicate()
	selected_card_id = ""
	selected_image_id = ""
	var first := engine.card(selected_cross_cards[0])
	var second := engine.card(selected_cross_cards[1])
	mode_label.text = "交叉解读 · %s × %s" % [str(first.get("name_zh", "")), str(second.get("name_zh", ""))]
	_render_draw()
	_clear_children(image_layer)
	detail_title.text = "%s  ×  %s" % [str(first.get("name", "")), str(second.get("name", ""))]
	detail_theme.text = "围绕两张牌义共同提出一个 YES / NO 问题。"
	_refresh_cross_button()
	question_edit.grab_focus()


func _ask_question() -> void:
	if round_locked:
		return
	if choosing_cards:
		result_label.text = "[color=#c85f43]请先从牌背中亲自选满三张牌。[/color]"
		return
	var question := question_edit.text.strip_edges()
	if question.is_empty():
		result_label.text = "[color=#c85f43]请先输入一个问题。[/color]"
		return
	if selected_cross_cards.is_empty() and (selected_card_id.is_empty() or selected_image_id.is_empty()):
		result_label.text = "[color=#c85f43]请选择一张牌和一个牌面意象，或启用交叉解读。[/color]"
		return
	var rule: Dictionary
	var reading_name := ""
	if not selected_cross_cards.is_empty():
		rule = engine.cross_reading_for(case_data, selected_cross_cards[0], selected_cross_cards[1], question)
		reading_name = "%s × %s" % [_card_short_name(selected_cross_cards[0]), _card_short_name(selected_cross_cards[1])]
	else:
		rule = engine.reading_for(case_data, selected_card_id, selected_image_id, question)
		reading_name = _card_short_name(selected_card_id)
	if not bool(rule.get("consume_round", true)):
		result_label.text = "[font_size=21][color=#c85f43]%s[/color][/font_size]\n%s" % [str(rule.get("result", "需要改写")), _bbcode_escape(str(rule.get("reason", "请把问题改写成一个 YES / NO 判断。")))]
		if str(rule.get("match_kind", "")) == "other_case":
			pending_case_switch_index = _case_index_for_id(str(rule.get("suggested_case_id", "")))
			suggested_case_index = pending_case_switch_index
			if pending_case_switch_index >= 0:
				next_button.text = "切换到《%s》" % str(engine.case_at(pending_case_switch_index).get("title", "对应案件"))
				next_button.disabled = false
		else:
			pending_case_switch_index = -1
			suggested_case_index = -1
			next_button.text = "修改问题后继续"
			next_button.disabled = true
		_refresh_case_buttons()
		question_edit.grab_focus()
		return
	pending_case_switch_index = -1
	suggested_case_index = -1
	next_button.text = "开始下一轮"
	if not GameState.use_free_time(10):
		result_label.text = "[color=#c85f43]当前时间块不足以完成这次 Reading。[/color]"
		return
	var answer := str(rule.get("result", "无关"))
	var fact := str(rule.get("fact", ""))
	var color := "#4f7d83" if answer == "YES" else ("#b54f3a" if answer == "NO" else "#806b5c")
	var detail := str(rule.get("reason", fact if not fact.is_empty() else "牌义与这个问题没有形成有效连接。"))
	result_label.text = "[font_size=25][color=%s]%s[/color][/font_size]\n%s" % [color, answer, _bbcode_escape(detail)]
	records.append({"round": round_no, "reading": reading_name, "question": question, "answer": answer, "fact": fact, "note": detail})
	if answer == "YES" and bool(rule.get("critical", true)) and not selected_card_id.is_empty():
		_confirm_card(selected_card_id, selected_image_id, fact)
	if not fact.is_empty():
		GameState.add_fact(fact)
	miss_streak = miss_streak + 1 if answer == "无关" else 0
	round_locked = true
	question_edit.editable = false
	ask_button.disabled = true
	next_button.disabled = false
	_refresh_records()
	_refresh_cross_button()


func _confirm_card(card_id: String, image_id: String, fact: String) -> void:
	var state: Dictionary = confirmed_cards.get(card_id, {"images": [], "facts": []})
	var images: Array = state.get("images", [])
	var facts: Array = state.get("facts", [])
	if not image_id.is_empty() and not images.has(image_id):
		images.append(image_id)
	if not fact.is_empty() and not facts.has(fact):
		facts.append(fact)
	state["images"] = images
	state["facts"] = facts
	confirmed_cards[card_id] = state


func _refresh_records() -> void:
	var blocks: Array[String] = []
	if confirmed_cards.is_empty():
		blocks.append("[color=#806b5c]牌阵还是空的。关键 YES 会把牌留在这里。[/color]")
	else:
		blocks.append("[color=#4f7d83][font_size=16]已确认牌阵[/font_size][/color]")
		for card_id in confirmed_cards:
			var card := engine.card(str(card_id))
			var state: Dictionary = confirmed_cards[card_id]
			var fact_lines: Array[String] = []
			for raw_fact in state.get("facts", []):
				fact_lines.append("• %s" % _bbcode_escape(str(raw_fact)))
			blocks.append("[b]%s  %s[/b]\n%s" % [str(card.get("name", "")), str(card.get("name_zh", "")), "\n".join(fact_lines)])
	if not records.is_empty():
		blocks.append("[color=#806b5c][font_size=16]问答历史[/font_size][/color]")
		for record in records:
			var answer := str(record.get("answer", ""))
			var color := "#4f7d83" if answer == "YES" else ("#b54f3a" if answer == "NO" else "#806b5c")
			var line := "[b]第 %d 轮 · %s[/b]  [color=%s]%s[/color]\n%s" % [int(record.get("round", 0)), _bbcode_escape(str(record.get("reading", ""))), color, answer, _bbcode_escape(str(record.get("question", "")))]
			var fact := str(record.get("fact", ""))
			var note := str(record.get("note", fact))
			if not note.is_empty():
				line += "\n[color=#806b5c]%s[/color]" % _bbcode_escape(note)
			blocks.append(line)
	record_label.text = "\n\n".join(blocks)


func _refresh_cross_button() -> void:
	var pairs := _available_cross_pairs()
	cross_button.disabled = choosing_cards or round_locked or pairs.is_empty()
	if pairs.is_empty():
		cross_button.text = "确认两张关键牌后解锁交叉"
	elif selected_cross_cards.is_empty():
		cross_button.text = "进行交叉解读（%d 组可用）" % pairs.size()
	else:
		cross_button.text = "%s × %s · 切换组合" % [_card_short_name(selected_cross_cards[0]), _card_short_name(selected_cross_cards[1])]


func _refresh_case_buttons() -> void:
	var labels := ["四扇门", "门外目击者"]
	for index in case_buttons.size():
		var active := index == case_index
		var suggested := index == suggested_case_index and not active
		case_buttons[index].text = "● %s" % labels[index] if active else ("→ %s" % labels[index] if suggested else labels[index])
		_apply_button_style(case_buttons[index], "case_active" if active else ("case_suggested" if suggested else "case"))


func _on_next_pressed() -> void:
	if pending_case_switch_index >= 0:
		_start_case(pending_case_switch_index)
	else:
		_draw_round()


func _case_index_for_id(case_id: String) -> int:
	for index in engine.cases.size():
		if str(engine.case_at(index).get("id", "")) == case_id:
			return index
	return -1


func _available_cross_pairs() -> Array:
	var pairs: Array = []
	for raw_rule in case_data.get("cross_readings", []):
		var pair: Array = (raw_rule as Dictionary).get("cards", [])
		if pair.size() == 2 and confirmed_cards.has(str(pair[0])) and confirmed_cards.has(str(pair[1])):
			pairs.append(pair.duplicate())
	return pairs


func _open_world() -> void:
	world_answer.clear()
	world_feedback.text = ""
	world_overlay.visible = true
	world_answer.grab_focus()


func _close_world() -> void:
	world_overlay.visible = false


func _submit_world() -> void:
	var answer := world_answer.text.strip_edges()
	if answer.is_empty():
		world_feedback.text = "请先写下你认为完整的汤底。"
		return
	var result := engine.evaluate_solution(case_data, answer)
	if not bool(result.get("success", false)):
		var missing: Array = result.get("missing", [])
		world_feedback.text = "还没有闭环（%d / %d）。继续确认：%s。" % [int(result.get("matched", 0)), int(result.get("required", 0)), "、".join(missing)]
		return
	var case_id := str(case_data.get("id", "tarot_case"))
	var event_id := "solmere_tarot_solved_%s" % case_id
	var first_completion := not GameState.has_event(event_id)
	GameState.mark_event(event_id)
	if first_completion:
		GameplayModuleSystem.complete_external(
			"tarot",
			{"method": "world_solution", "case_id": case_id, "rounds": round_no},
			{
				"encounters": ["xia_touming"],
				"relationship_flags": {"xia_touming": ["在 Solmere 牌桌完成过海龟汤推理"]},
				"confirmations": {"xia_touming": "granted"},
			}
		)
		GameState.add_journal_entry({
			"id": "%s_%s_day_%d" % [event_id, GameState.current_role, GameState.current_day],
			"kind": "tarot",
			"text": "在 Solmere 牌桌用 The World 提交了《%s》的完整汤底。" % str(case_data.get("title", "海龟汤")),
		})
		SaveManager.save_game()
	world_feedback.text = "汤底闭环。The World 已翻开：%s" % str(case_data.get("solution", ""))
	result_label.text = "[color=#4f7d83][font_size=22]THE WORLD · 推理完成[/font_size][/color]\n%s" % _bbcode_escape(str(case_data.get("solution", "")))


func _on_question_submitted(_text: String) -> void:
	_ask_question()


func _refresh_state() -> void:
	clock_label.text = "第 %d 天  %s" % [GameState.current_day, GameState.clock_text()]
	money_label.text = "余额  %d" % GameState.money
	confirmation_label.text = "认识确认  %d / 12" % GameState.residency_confirmations


func _return_to_town() -> void:
	if GameplayModuleSystem.pending_module_id() == "tarot":
		GameplayModuleSystem.cancel_session()
	SceneRouter.town_day()


func _unhandled_input(event: InputEvent) -> void:
	if world_overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_world()
		get_viewport().set_input_as_handled()


func _card_short_name(card_id: String) -> String:
	var card := engine.card(card_id)
	return str(card.get("name_zh", card_id))


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _bbcode_escape(value: String) -> String:
	return value.replace("[", "［").replace("]", "］")


func _input_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fffdf6")
	style.border_color = Color(LINE, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


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
		style.shadow_color = Color("704936", 0.17)
		style.shadow_size = 8
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
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_button_style(button, kind)
	parent.add_child(button)
	return button


func _apply_button_style(button: Button, kind: String) -> void:
	var base := Color("fff9ed", 0.97)
	var edge := LINE
	var font_color := INK
	match kind:
		"primary":
			base = TERRACOTTA
			edge = TERRACOTTA.darkened(0.12)
			font_color = Color("fff8e8")
		"world":
			base = Color("3f5960")
			edge = GOLD
			font_color = Color("fff3ce")
		"tarot":
			base = Color("f3e5c9")
			edge = GOLD
		"tarot_active":
			base = Color("d9bd7b")
			edge = TERRACOTTA
		"image":
			base = Color("eef0df")
			edge = SAGE
		"image_active":
			base = SAGE
			edge = SAGE.darkened(0.16)
			font_color = Color("fffbea")
		"cross":
			base = Color("dce8e4")
			edge = TEAL
		"case":
			base = Color("f6e9d6")
			edge = LINE
		"case_active":
			base = TEAL
			edge = TEAL.darkened(0.12)
			font_color = Color("fff8e8")
		"case_suggested":
			base = Color("f2cabc")
			edge = TERRACOTTA
		"shuffle":
			base = Color("e8ddd0")
			edge = TEAL
			font_color = TEAL.darkened(0.15)
		"card_back":
			base = Color("3f5960")
			edge = GOLD
			font_color = Color("fff3ce")
		"card_back_picked":
			base = TEAL
			edge = TERRACOTTA
			font_color = Color("fff8e8")
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
	hover.bg_color = base.lightened(0.10)
	hover.border_color = edge.lightened(0.14)
	var pressed := normal.duplicate()
	pressed.bg_color = base.darkened(0.10)
	pressed.shadow_size = 1
	var disabled := normal.duplicate()
	disabled.bg_color = Color(PAPER_SOFT, 0.56)
	disabled.border_color = Color(LINE, 0.30)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.52))


func capture_prototype(filename := "solmere-tarot.png") -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var destination := ProjectSettings.globalize_path("res://captures/%s" % filename)
	var error := image.save_png(destination)
	if error != OK:
		push_error("Could not save Solmere tarot capture: %s" % error)
	get_tree().quit()
