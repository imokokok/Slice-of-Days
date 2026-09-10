extends Control

const StageBackdrop = preload("res://scripts/ui/stage_backdrop.gd")
const TarotEngine = preload("res://scripts/core/tarot_case_engine.gd")
const TarotSigil = preload("res://scripts/ui/tarot_sigil.gd")

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
var choosing_cards := false
var selected_card_id := ""
var selected_image_id := ""
var selected_cross_cards: Array[String] = []
var confirmed_cards: Dictionary = {}
var records: Array[Dictionary] = []
var resolved_reading_ids: Dictionary = {}
var used_cross_pairs: Dictionary = {}
var round_no := 0
var miss_streak := 0
var round_locked := false
var animating := false

var clock_label: Label
var money_label: Label
var confirmation_label: Label
var case_eyebrow: Label
var case_title: Label
var opening_label: Label
var round_label: Label
var shuffle_button: Button
var mode_label: Label
var phase_labels: Array[Label] = []
var insight_label: Label
var reading_caption: Label
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
var spread_label: RichTextLabel
var spread_flash: ColorRect
var world_overlay: ColorRect
var world_panel: Panel
var world_answer: TextEdit
var world_feedback: Label
var world_progress: Label
var world_submit_button: Button
var case_buttons: Array[Button] = []
var suggested_case_index := -1
var pending_case_switch_index := -1
var current_phase := 0


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
		_open_world(false)
		capture_prototype.call_deferred("solmere-tarot-world.png")
	elif args.has("--capture-wrong-case"):
		_reveal_cards(["temperance", "justice", "wheel"])
		_render_draw()
		_select_card("temperance")
		_select_image("cups")
		question_edit.text = "报警的人有没有走进过屋子里？"
		_ask_question()
		capture_prototype.call_deferred("solmere-tarot-wrong-case.png")
	elif args.has("--capture-response"):
		_start_case(1)
		_reveal_cards(["chariot", "lovers", "justice"])
		_render_draw()
		_select_card("chariot")
		_select_image("city")
		question_edit.text = "报警的人有没有走进过屋子里？"
		_ask_question()
		capture_prototype.call_deferred("solmere-tarot-response.png")
	elif args.has("--capture-detail"):
		_reveal_cards()
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
	var header := _make_panel(self, Vector2.ZERO, Vector2(1600, 70), Color("fff8eb", 0.98), LINE)
	var brand := _make_label(header, "SOLMERE", Vector2(28, 9), Vector2(250, 35), 27, INK)
	brand.add_theme_color_override("font_shadow_color", Color("704936", 0.16))
	brand.add_theme_constant_override("shadow_offset_x", 2)
	brand.add_theme_constant_override("shadow_offset_y", 2)
	_make_label(header, "塔罗海龟汤 · 从意象抵达真相", Vector2(29, 39), Vector2(430, 22), 13, MUTED)
	clock_label = _make_label(header, "", Vector2(1010, 10), Vector2(150, 30), 19, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	money_label = _make_label(header, "", Vector2(1170, 10), Vector2(120, 30), 15, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	confirmation_label = _make_label(header, "", Vector2(1302, 10), Vector2(248, 30), 15, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	var back := _make_button(header, "返回小镇", Vector2(1422, 41), Vector2(128, 24), "quiet")
	back.pressed.connect(_return_to_town)


func _build_case_panel() -> void:
	var panel := _make_panel(self, Vector2(24, 86), Vector2(318, 790), PAPER, LINE)
	case_eyebrow = _make_label(panel, "", Vector2(20, 16), Vector2(294, 22), 13, TEAL)
	case_title = _make_label(panel, "", Vector2(20, 42), Vector2(274, 38), 25, INK)
	opening_label = _make_label(panel, "", Vector2(20, 88), Vector2(278, 240), 15, INK)
	opening_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opening_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_make_label(panel, "桌上的谜题", Vector2(20, 338), Vector2(120, 22), 13, MUTED)
	var first_case := _make_button(panel, "四扇门", Vector2(20, 368), Vector2(132, 42), "case")
	var second_case := _make_button(panel, "门外目击者", Vector2(166, 368), Vector2(132, 42), "case")
	case_buttons = [first_case, second_case]
	first_case.pressed.connect(_request_case.bind(0))
	second_case.pressed.connect(_request_case.bind(1))
	var world_card := _make_button(panel, "XXI  THE WORLD\n翻开并提交汤底", Vector2(20, 438), Vector2(278, 104), "world")
	world_card.pressed.connect(_open_world)
	insight_label = _make_label(panel, "", Vector2(20, 558), Vector2(278, 30), 14, TEAL)
	var help := _make_label(panel, "一轮只做一次 Reading\n\n1  翻开本轮三张牌\n2  选牌，再点一个可读意象\n3  自己组织 YES / NO 问题\n4  关键 YES 会把牌留在牌阵\n5  重复牌可深读，两牌可交叉", Vector2(20, 600), Vector2(278, 164), 14, MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.vertical_alignment = VERTICAL_ALIGNMENT_TOP


func _build_reading_panel() -> void:
	var panel := _make_panel(self, Vector2(360, 86), Vector2(850, 516), PAPER, LINE)
	_make_label(panel, "本轮 Reading", Vector2(20, 12), Vector2(170, 28), 19, INK)
	shuffle_button = _make_button(panel, "翻开三张", Vector2(660, 10), Vector2(104, 34), "shuffle")
	shuffle_button.pressed.connect(_shuffle_pile)
	round_label = _make_label(panel, "", Vector2(764, 14), Vector2(66, 26), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var step_names := ["1 翻牌", "2 选牌", "3 读意象", "4 提问"]
	for index in step_names.size():
		var step := _make_label(panel, step_names[index], Vector2(20 + index * 202, 49), Vector2(190, 24), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		phase_labels.append(step)
	card_layer = Control.new()
	card_layer.position = Vector2(0, 84)
	card_layer.size = Vector2(850, 240)
	card_layer.pivot_offset = Vector2(425, 120)
	panel.add_child(card_layer)
	detail_title = _make_label(panel, "先翻开本轮三张牌", Vector2(22, 340), Vector2(500, 30), 20, INK)
	detail_theme = _make_label(panel, "牌名给出方向，牌面元素会把问题缩小到一个角度。", Vector2(22, 370), Vector2(790, 24), 14, MUTED)
	reading_caption = _make_label(panel, "", Vector2(550, 340), Vector2(278, 30), 12, TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	_make_label(panel, "可读意象", Vector2(22, 404), Vector2(110, 22), 13, TEAL)
	image_layer = Control.new()
	image_layer.position = Vector2(14, 431)
	panel.add_child(image_layer)


func _build_question_panel() -> void:
	var panel := _make_panel(self, Vector2(360, 618), Vector2(850, 258), PAPER, LINE)
	_make_label(panel, "自由提问", Vector2(20, 14), Vector2(145, 27), 19, INK)
	mode_label = _make_label(panel, "", Vector2(180, 14), Vector2(648, 27), 13, TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	question_edit = LineEdit.new()
	question_edit.position = Vector2(20, 51)
	question_edit.size = Vector2(622, 48)
	question_edit.placeholder_text = "围绕所选牌与意象，输入一个可以用 YES / NO 回答的问题"
	question_edit.add_theme_font_size_override("font_size", 15)
	question_edit.add_theme_color_override("font_color", INK)
	question_edit.add_theme_color_override("font_placeholder_color", Color(MUTED, 0.72))
	question_edit.add_theme_stylebox_override("normal", _input_style())
	question_edit.text_submitted.connect(_on_question_submitted)
	panel.add_child(question_edit)
	ask_button = _make_button(panel, "进行 Reading", Vector2(656, 51), Vector2(172, 48), "primary")
	ask_button.pressed.connect(_ask_question)
	result_label = RichTextLabel.new()
	result_label.position = Vector2(20, 116)
	result_label.size = Vector2(808, 74)
	result_label.bbcode_enabled = true
	result_label.fit_content = false
	result_label.scroll_active = false
	result_label.add_theme_font_size_override("normal_font_size", 15)
	result_label.add_theme_color_override("default_color", INK)
	panel.add_child(result_label)
	cross_button = _make_button(panel, "交叉解读尚未解锁", Vector2(20, 190), Vector2(300, 46), "cross")
	cross_button.disabled = true
	cross_button.pressed.connect(_select_next_cross_pair)
	next_button = _make_button(panel, "开始下一轮", Vector2(648, 190), Vector2(180, 46), "primary")
	next_button.disabled = true
	next_button.pressed.connect(_on_next_pressed)
	var pace_note := _make_label(panel, "每次耗时 10 分钟 · 可随时翻 The World", Vector2(330, 190), Vector2(302, 46), 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	pace_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_record_panel() -> void:
	var panel := _make_panel(self, Vector2(1228, 86), Vector2(348, 790), PAPER, LINE)
	_make_label(panel, "推理牌阵", Vector2(20, 16), Vector2(210, 30), 21, INK)
	_make_label(panel, "点亮的牌就是你已经确认的路径", Vector2(20, 47), Vector2(310, 22), 13, MUTED)
	spread_label = RichTextLabel.new()
	spread_label.position = Vector2(18, 80)
	spread_label.size = Vector2(314, 314)
	spread_label.bbcode_enabled = true
	spread_label.scroll_active = true
	spread_label.add_theme_font_size_override("normal_font_size", 14)
	spread_label.add_theme_color_override("default_color", INK)
	panel.add_child(spread_label)
	spread_flash = ColorRect.new()
	spread_flash.position = Vector2(12, 74)
	spread_flash.size = Vector2(324, 326)
	spread_flash.color = Color(GOLD, 0.0)
	spread_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(spread_flash)
	_make_label(panel, "问答与排除", Vector2(20, 410), Vector2(210, 26), 17, INK)
	record_label = RichTextLabel.new()
	record_label.position = Vector2(18, 444)
	record_label.size = Vector2(314, 324)
	record_label.bbcode_enabled = true
	record_label.scroll_active = true
	record_label.add_theme_font_size_override("normal_font_size", 14)
	record_label.add_theme_color_override("default_color", INK)
	panel.add_child(record_label)


func _build_world_overlay() -> void:
	world_overlay = ColorRect.new()
	world_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Selected cards temporarily use a positive z-index for their lift animation.
	# Keep the modal above the entire table so those cards cannot pierce it.
	world_overlay.z_index = 100
	world_overlay.color = Color(INK, 0.62)
	world_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(world_overlay)
	world_panel = _make_panel(world_overlay, Vector2(410, 160), Vector2(780, 580), Color("fff8eb"), GOLD)
	world_panel.pivot_offset = Vector2(390, 290)
	_make_label(world_panel, "XXI  THE WORLD", Vector2(34, 27), Vector2(710, 38), 27, INK)
	_make_label(world_panel, "提交完整汤底", Vector2(34, 68), Vector2(710, 27), 17, TEAL)
	var world_sigil := TarotSigil.new()
	world_sigil.position = Vector2(646, 10)
	world_sigil.size = Vector2(96, 96)
	world_sigil.configure("world", false, true)
	world_panel.add_child(world_sigil)
	world_progress = _make_label(world_panel, "", Vector2(390, 74), Vector2(230, 24), 13, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	var prompt := _make_label(world_panel, "请闭合人物、动机、行动、因果与结果。答案不要求逐字一致，但必须包含关键环节。", Vector2(34, 106), Vector2(712, 54), 15, MUTED)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_answer = TextEdit.new()
	world_answer.position = Vector2(34, 176)
	world_answer.size = Vector2(712, 210)
	world_answer.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	world_answer.add_theme_font_size_override("font_size", 16)
	world_answer.add_theme_color_override("font_color", INK)
	world_answer.add_theme_stylebox_override("normal", _input_style())
	world_panel.add_child(world_answer)
	world_feedback = _make_label(world_panel, "", Vector2(34, 399), Vector2(712, 66), 14, TERRACOTTA)
	world_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cancel := _make_button(world_panel, "继续推理", Vector2(34, 495), Vector2(180, 50), "quiet")
	cancel.pressed.connect(_close_world)
	world_submit_button = _make_button(world_panel, "翻开世界", Vector2(546, 495), Vector2(200, 50), "world")
	world_submit_button.pressed.connect(_submit_world)
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
	resolved_reading_ids.clear()
	used_cross_pairs.clear()
	world_answer.clear()
	world_feedback.text = ""
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


func _request_case(index: int) -> void:
	if index == case_index:
		return
	if records.is_empty():
		_start_case(index)
		return
	pending_case_switch_index = index
	suggested_case_index = index
	next_button.text = "确认切换并清空牌阵"
	next_button.disabled = false
	result_label.text = "[font_size=19][color=#c99545]切换谜题会清空当前牌阵[/color][/font_size]\n如要保留这局，请先继续推理或提交 The World。"
	_refresh_case_buttons()


func _draw_round() -> void:
	round_no += 1
	round_locked = false
	choosing_cards = true
	current_draw.clear()
	selected_card_id = ""
	selected_image_id = ""
	selected_cross_cards.clear()
	_prepare_draw_pile()
	question_edit.clear()
	var examples: Array = case_data.get("question_examples", [])
	question_edit.placeholder_text = "例如：%s" % str(examples[(round_no - 1) % examples.size()]) if not examples.is_empty() else "围绕所选牌与意象提出一个 YES / NO 问题"
	question_edit.editable = false
	ask_button.disabled = true
	next_button.disabled = true
	next_button.text = "开始下一轮"
	shuffle_button.disabled = false
	shuffle_button.text = "翻开三张"
	if miss_streak >= 2:
		mode_label.text = "牌阵回响 · 本轮保证出现一个未读方向"
		result_label.text = "[color=#4f7d83]连续两次没有形成线索，牌阵正在把你带回有效路径。[/color]"
	else:
		mode_label.text = "牌已洗好 · 翻开本轮的三个方向"
		result_label.text = "[color=#806b5c]每轮只读一张牌。其余两张会回到本题牌池。[/color]"
	_render_pile()
	_render_card_detail("")
	_set_phase(0)
	_refresh_cross_button()


func _prepare_draw_pile() -> void:
	draw_pile.clear()
	if round_no == 1:
		for raw_card_id in case_data.get("opening_draw", []):
			draw_pile.append(str(raw_card_id))
	else:
		draw_pile = engine.draw_three(case_data, confirmed_cards, miss_streak, rng)


func _shuffle_pile() -> void:
	if not choosing_cards or animating:
		return
	animating = true
	shuffle_button.disabled = true
	mode_label.text = "牌在桌面上重新排列……"
	var shuffle_tween := create_tween()
	shuffle_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	shuffle_tween.tween_property(card_layer, "rotation", deg_to_rad(-2.2), 0.10)
	shuffle_tween.tween_property(card_layer, "rotation", deg_to_rad(2.2), 0.10)
	shuffle_tween.tween_property(card_layer, "rotation", 0.0, 0.10)
	await shuffle_tween.finished
	_reveal_cards([], true)
	animating = false


func _reveal_cards(forced_draw: Array[String] = [], animate_cards := false) -> void:
	if not forced_draw.is_empty():
		draw_pile = forced_draw.duplicate()
	current_draw = draw_pile.duplicate()
	choosing_cards = false
	shuffle_button.disabled = true
	shuffle_button.text = "三张已翻开"
	round_label.text = "第 %d 轮" % round_no
	question_edit.editable = true
	ask_button.disabled = true
	mode_label.text = "牌阵回响已生效 · 选择一个未读方向" if miss_streak >= 2 else "三张牌给出三个角度 · 选择一张"
	result_label.text = "[color=#4f7d83]先看牌义，再选择一个牌面意象。[/color]"
	_render_draw()
	_render_card_detail("")
	_set_phase(1)
	_refresh_cross_button()
	if animate_cards:
		_animate_card_reveal()


func _render_pile() -> void:
	_clear_children(card_layer)
	for index in 3:
		var x := 263.0 + float(index) * 18.0
		var y := 20.0 + absf(float(index) - 1.0) * 7.0
		var back := _make_button(card_layer, "✦\nSOLMERE\nTAROT", Vector2(x, y), Vector2(238, 228), "card_back")
		back.rotation = deg_to_rad(float(index - 1) * 3.2)
		if index == 2:
			back.tooltip_text = "翻开本轮三张牌"
			back.pressed.connect(_shuffle_pile)
		else:
			back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reading_caption.text = "6–9 张专属牌池 · 每轮翻 3 张"
	round_label.text = "第 %d 轮" % round_no


func _render_draw() -> void:
	_clear_children(card_layer)
	for index in current_draw.size():
		var card_id := current_draw[index]
		var card: Dictionary = engine.card(card_id)
		var deep_mark := " · 可深读" if confirmed_cards.has(card_id) else ""
		var kind := "tarot_active" if card_id == selected_card_id else "tarot"
		var button := _make_button(card_layer, "", Vector2(20 + index * 276, 0), Vector2(258, 240), kind)
		button.pivot_offset = button.size * 0.5
		if card_id == selected_card_id:
			button.position.y = -8
			button.scale = Vector2(1.025, 1.025)
			button.z_index = 2
		var number_label := _make_label(button, "%s   %s" % [str(card.get("number", "")), str(card.get("name", ""))], Vector2(12, 6), Vector2(234, 26), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sigil := TarotSigil.new()
		sigil.position = Vector2(54, 30)
		sigil.size = Vector2(150, 140)
		sigil.configure(card_id, card_id == selected_card_id, confirmed_cards.has(card_id))
		button.add_child(sigil)
		var title_label := _make_label(button, "%s%s" % [str(card.get("name_zh", "")), deep_mark], Vector2(12, 174), Vector2(234, 28), 16, INK, HORIZONTAL_ALIGNMENT_CENTER)
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var theme_label := _make_label(button, str(card.get("theme", "")), Vector2(12, 204), Vector2(234, 22), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		theme_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.tooltip_text = str(card.get("theme", ""))
		button.pressed.connect(_select_card.bind(card_id))
	reading_caption.text = "其余两张会回到牌池"


func _select_card(card_id: String) -> void:
	if round_locked or choosing_cards:
		return
	selected_card_id = card_id
	selected_image_id = ""
	selected_cross_cards.clear()
	ask_button.disabled = true
	var card := engine.card(card_id)
	var mode := "深读已有牌" if confirmed_cards.has(card_id) else "读取新牌"
	mode_label.text = "%s · %s" % [mode, str(card.get("name_zh", ""))]
	reading_caption.text = "%s · 再选一个意象" % mode
	_render_draw()
	_render_card_detail(card_id)
	_set_phase(2)
	_refresh_cross_button()
	_animate_selected_card()


func _render_card_detail(card_id: String) -> void:
	_clear_children(image_layer)
	if card_id.is_empty():
		if choosing_cards:
			detail_title.text = "牌堆已洗好"
			detail_theme.text = "翻开三张牌，看看本轮出现哪三条推理路径。"
		else:
			detail_title.text = "选择一张牌作为本轮 Reading"
			detail_theme.text = "三张牌分别代表三条不同的推理路径。"
		return
	var card := engine.card(card_id)
	detail_title.text = "%s  %s  %s" % [str(card.get("number", "")), str(card.get("name", "")), str(card.get("name_zh", ""))]
	detail_theme.text = str(card.get("theme", ""))
	var images: Array = card.get("images", [])
	for index in images.size():
		var image_data: Dictionary = images[index]
		var image_id := str(image_data.get("id", ""))
		var already_lit := _confirmed_image_ids(card_id).has(image_id)
		var marker := "✦ " if already_lit else ""
		var button_text := "%s%s\n%s" % [marker, str(image_data.get("label", "")), str(image_data.get("keywords", ""))]
		var kind := "image_active" if image_id == selected_image_id else ("image_lit" if already_lit else "image")
		var button := _make_button(image_layer, button_text, Vector2(index * 202, 0), Vector2(190, 64), kind)
		button.tooltip_text = "已点亮，可继续深读" if already_lit else "以这个牌面元素限制提问角度"
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
	reading_caption.text = "已锁定意象 · 写下一个判断"
	question_edit.placeholder_text = "围绕「%s × %s」写下一个可以判断真假的问题" % [str(card.get("name_zh", "")), image_name]
	ask_button.disabled = false
	_set_phase(3)
	_animate_selected_image(image_id)
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
	selected_cross_cards.clear()
	for card_id in pairs[next_index] as Array:
		selected_cross_cards.append(str(card_id))
	selected_card_id = ""
	selected_image_id = ""
	ask_button.disabled = false
	var first := engine.card(selected_cross_cards[0])
	var second := engine.card(selected_cross_cards[1])
	mode_label.text = "交叉解读 · %s × %s" % [str(first.get("name_zh", "")), str(second.get("name_zh", ""))]
	_render_draw()
	_clear_children(image_layer)
	detail_title.text = "%s  ×  %s" % [str(first.get("name", "")), str(second.get("name", ""))]
	detail_theme.text = "围绕两张牌义共同提出一个 YES / NO 问题。"
	reading_caption.text = "两张确认牌已连线 · 写下交叉判断"
	question_edit.placeholder_text = "同时围绕「%s × %s」提出一个判断" % [str(first.get("name_zh", "")), str(second.get("name_zh", ""))]
	_set_phase(3)
	_refresh_cross_button()
	question_edit.grab_focus()


func _ask_question() -> void:
	if round_locked:
		return
	if choosing_cards:
		result_label.text = "[color=#c85f43]请先翻开本轮三张牌。[/color]"
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
	var active_cross_key := ""
	if not selected_cross_cards.is_empty():
		rule = engine.cross_reading_for(case_data, selected_cross_cards[0], selected_cross_cards[1], question)
		reading_name = "%s × %s" % [_card_short_name(selected_cross_cards[0]), _card_short_name(selected_cross_cards[1])]
		active_cross_key = _pair_key(selected_cross_cards)
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
	var rule_id := str(rule.get("id", ""))
	if not rule_id.is_empty() and resolved_reading_ids.has(rule_id):
		result_label.text = "[font_size=20][color=#c99545]已确认过这条线索[/color][/font_size]\n换一个意象或沿现有结论继续深读；重复提问不会消耗时间。"
		question_edit.select_all()
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
	var lit_card := answer == "YES" and bool(rule.get("critical", true)) and not selected_card_id.is_empty()
	records.append({"round": round_no, "reading": reading_name, "question": question, "answer": answer, "fact": fact, "note": detail, "rule_id": rule_id})
	if lit_card:
		_confirm_card(selected_card_id, selected_image_id, fact)
	if not rule_id.is_empty():
		resolved_reading_ids[rule_id] = true
	if not active_cross_key.is_empty():
		used_cross_pairs[active_cross_key] = true
	if not fact.is_empty():
		GameState.add_fact(fact)
	miss_streak = miss_streak + 1 if answer == "无关" else 0
	round_locked = true
	_set_phase(4)
	question_edit.editable = false
	ask_button.disabled = true
	next_button.disabled = false
	_refresh_records()
	_refresh_cross_button()
	_animate_answer(answer, lit_card)


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
	var spread_blocks: Array[String] = []
	if confirmed_cards.is_empty():
		spread_blocks.append("[center][color=#806b5c]\n牌阵还是空的\n\n关键 YES 会点亮牌面，\n并把它留在这里。[/color][/center]")
	else:
		spread_blocks.append("[color=#4f7d83][font_size=16]已点亮 %d 张牌[/font_size][/color]" % confirmed_cards.size())
		for card_id in confirmed_cards:
			var card := engine.card(str(card_id))
			var state: Dictionary = confirmed_cards[card_id]
			var image_names: Array[String] = []
			for image_id in state.get("images", []):
				image_names.append(_image_name(str(card_id), str(image_id)))
			var fact_lines: Array[String] = []
			for raw_fact in state.get("facts", []):
				fact_lines.append("[color=#3d2d29]%s[/color]" % _bbcode_escape(str(raw_fact)))
			spread_blocks.append("[bgcolor=#f3e5c9][b] %s  %s [/b][/bgcolor]\n[color=#7d8f59]✦ %s[/color]\n%s" % [str(card.get("number", "")), str(card.get("name_zh", "")), " · ".join(image_names), "\n".join(fact_lines)])
	spread_label.text = "\n\n".join(spread_blocks)
	var history_blocks: Array[String] = []
	if records.is_empty():
		history_blocks.append("[color=#806b5c]NO 会成为排除项；无关问题只留在历史中。[/color]")
	else:
		for record in records:
			var answer := str(record.get("answer", ""))
			var color := "#4f7d83" if answer == "YES" else ("#b54f3a" if answer == "NO" else "#806b5c")
			var marker := "确认" if answer == "YES" else ("排除" if answer == "NO" else "无关")
			var line := "[b]第 %d 轮 · %s[/b]  [color=%s]%s · %s[/color]\n%s" % [int(record.get("round", 0)), _bbcode_escape(str(record.get("reading", ""))), color, answer, marker, _bbcode_escape(str(record.get("question", "")))]
			var fact := str(record.get("fact", ""))
			var note := str(record.get("note", fact))
			if not note.is_empty():
				line += "\n[color=#806b5c]%s[/color]" % _bbcode_escape(note)
			history_blocks.append(line)
	record_label.text = "\n\n".join(history_blocks)
	if is_instance_valid(insight_label):
		var glow_count := confirmed_cards.size()
		insight_label.text = "洞察 %d · %s" % [glow_count, "可以尝试闭环" if glow_count >= 4 else "建议点亮 4–6 张牌"]


func _refresh_cross_button() -> void:
	var pairs := _available_cross_pairs()
	cross_button.disabled = choosing_cards or round_locked or pairs.is_empty()
	if pairs.is_empty():
		cross_button.text = "可用交叉已完成" if not used_cross_pairs.is_empty() else "确认两张关键牌后解锁交叉"
	elif selected_cross_cards.is_empty():
		cross_button.text = "进行交叉解读（%d 组可用）" % pairs.size()
	else:
		cross_button.text = "%s ── %s · 已连线" % [_card_short_name(selected_cross_cards[0]), _card_short_name(selected_cross_cards[1])]


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
		if pair.size() == 2 and confirmed_cards.has(str(pair[0])) and confirmed_cards.has(str(pair[1])) and not used_cross_pairs.has(_pair_key(pair)):
			pairs.append(pair.duplicate())
	return pairs


func _pair_key(pair: Array) -> String:
	var normalized: Array[String] = []
	for card_id in pair:
		normalized.append(str(card_id))
	normalized.sort()
	return "|".join(normalized)


func _open_world(animate_overlay := true) -> void:
	world_feedback.text = ""
	world_progress.text = "已推理 %d 轮 · 点亮 %d 张牌" % [records.size(), confirmed_cards.size()]
	world_submit_button.disabled = false
	world_submit_button.text = "翻开世界"
	world_overlay.visible = true
	if animate_overlay:
		world_overlay.color = Color(INK, 0.0)
		world_panel.scale = Vector2(0.88, 0.88)
		world_panel.modulate = Color(1, 1, 1, 0)
		var reveal := create_tween().set_parallel(true)
		reveal.tween_property(world_overlay, "color", Color(INK, 0.62), 0.24)
		reveal.tween_property(world_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(world_panel, "modulate", Color.WHITE, 0.18)
		_spawn_sparkles(world_panel, Vector2(686, 56), GOLD, 8)
	else:
		world_overlay.color = Color(INK, 0.62)
		world_panel.scale = Vector2.ONE
		world_panel.modulate = Color.WHITE
	world_answer.grab_focus()


func _close_world() -> void:
	if not world_overlay.visible:
		return
	var dismiss := create_tween().set_parallel(true)
	dismiss.tween_property(world_overlay, "color", Color(INK, 0.0), 0.16)
	dismiss.tween_property(world_panel, "scale", Vector2(0.96, 0.96), 0.16)
	dismiss.tween_property(world_panel, "modulate", Color(1, 1, 1, 0), 0.12)
	await dismiss.finished
	world_overlay.visible = false
	world_panel.scale = Vector2.ONE
	world_panel.modulate = Color.WHITE


func _submit_world() -> void:
	var answer := world_answer.text.strip_edges()
	if answer.is_empty():
		world_feedback.text = "请先写下你认为完整的汤底。"
		return
	var result := engine.evaluate_solution(case_data, answer)
	if not bool(result.get("success", false)):
		var missing: Array = result.get("missing", [])
		world_feedback.text = "还没有闭环（%d / %d）。继续确认：%s。" % [int(result.get("matched", 0)), int(result.get("required", 0)), "、".join(missing)]
		var start_position := world_panel.position
		var shake := create_tween()
		shake.tween_property(world_panel, "position", start_position + Vector2(-8, 0), 0.05)
		shake.tween_property(world_panel, "position", start_position + Vector2(8, 0), 0.07)
		shake.tween_property(world_panel, "position", start_position, 0.05)
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
	world_submit_button.text = "世界已翻开"
	world_submit_button.disabled = true
	result_label.text = "[color=#4f7d83][font_size=22]THE WORLD · 推理完成[/font_size][/color]\n%s" % _bbcode_escape(str(case_data.get("solution", "")))
	_spawn_sparkles(world_panel, Vector2(390, 290), GOLD, 18)


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


func _confirmed_image_ids(card_id: String) -> Array:
	if not confirmed_cards.has(card_id):
		return []
	return (confirmed_cards[card_id] as Dictionary).get("images", [])


func _image_name(card_id: String, image_id: String) -> String:
	for raw_image in engine.card(card_id).get("images", []):
		var image_data: Dictionary = raw_image
		if str(image_data.get("id", "")) == image_id:
			return str(image_data.get("label", "牌面意象"))
	return "牌面意象"


func _set_phase(phase: int) -> void:
	current_phase = phase
	for index in phase_labels.size():
		var label := phase_labels[index]
		if index < phase:
			label.text = "✓ " + label.text.trim_prefix("✓ ").trim_prefix("● ")
			label.add_theme_color_override("font_color", TEAL)
		elif index == phase and phase < 4:
			label.text = "● " + label.text.trim_prefix("✓ ").trim_prefix("● ")
			label.add_theme_color_override("font_color", TERRACOTTA)
		else:
			label.text = label.text.trim_prefix("✓ ").trim_prefix("● ")
			label.add_theme_color_override("font_color", MUTED)


func _animate_card_reveal() -> void:
	for index in card_layer.get_child_count():
		var card_view := card_layer.get_child(index) as Control
		if card_view == null:
			continue
		var target_position := card_view.position
		card_view.position += Vector2(0, 28)
		card_view.scale = Vector2(0.06, 1.0)
		card_view.modulate = Color(1, 1, 1, 0)
		var delay := 0.09 * index
		var reveal := create_tween().set_parallel(true)
		reveal.tween_property(card_view, "position", target_position, 0.34).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(card_view, "scale", Vector2.ONE, 0.34).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(card_view, "modulate", Color.WHITE, 0.20).set_delay(delay)
	_spawn_sparkles(card_layer, Vector2(425, 120), GOLD, 7)


func _animate_selected_card() -> void:
	var index := current_draw.find(selected_card_id)
	if index < 0 or index >= card_layer.get_child_count():
		return
	var card_view := card_layer.get_child(index) as Control
	if card_view == null:
		return
	var target_scale := card_view.scale
	var target_position := card_view.position
	card_view.scale = Vector2(0.92, 0.92)
	card_view.position += Vector2(0, 12)
	var lift := create_tween().set_parallel(true)
	lift.tween_property(card_view, "scale", target_scale, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(card_view, "position", target_position, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_spawn_sparkles(card_layer, target_position + card_view.size * 0.5, TERRACOTTA, 5)


func _animate_selected_image(image_id: String) -> void:
	var card := engine.card(selected_card_id)
	var image_index := -1
	var images: Array = card.get("images", [])
	for index in images.size():
		if str((images[index] as Dictionary).get("id", "")) == image_id:
			image_index = index
			break
	if image_index < 0 or image_index >= image_layer.get_child_count():
		return
	var image_button := image_layer.get_child(image_index) as Control
	if image_button == null:
		return
	image_button.pivot_offset = image_button.size * 0.5
	image_button.scale = Vector2(0.88, 0.88)
	var pulse := create_tween()
	pulse.tween_property(image_button, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(image_button, "scale", Vector2.ONE, 0.12)
	_spawn_sparkles(image_layer, image_button.position + image_button.size * 0.5, SAGE, 5)


func _animate_answer(answer: String, lit_card := false) -> void:
	var answer_color := TEAL if answer == "YES" else (TERRACOTTA if answer == "NO" else MUTED)
	var target_position := result_label.position
	result_label.position += Vector2(0, 10)
	result_label.modulate = Color(1, 1, 1, 0)
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(result_label, "position", target_position, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(result_label, "modulate", Color.WHITE, 0.18)
	_spawn_sparkles(result_label, Vector2(38, 22), answer_color, 6 if answer == "YES" else 3)
	if lit_card:
		spread_flash.color = Color(GOLD, 0.24)
		var glow := create_tween()
		glow.tween_property(spread_flash, "color", Color(GOLD, 0.0), 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _spawn_sparkles(parent: Control, center: Vector2, color: Color, count: int) -> void:
	for index in count:
		var spark := Label.new()
		spark.text = "✦"
		spark.position = center - Vector2(7, 7)
		spark.size = Vector2(14, 14)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.add_theme_font_size_override("font_size", 10 + index % 3)
		spark.add_theme_color_override("font_color", Color(color, 0.95))
		parent.add_child(spark)
		var angle := TAU * float(index) / float(maxi(count, 1)) - PI * 0.5
		var distance := 22.0 + float(index % 3) * 8.0
		var target := spark.position + Vector2.from_angle(angle) * distance
		var drift := create_tween().set_parallel(true)
		drift.tween_property(spark, "position", target, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		drift.tween_property(spark, "modulate", Color(1, 1, 1, 0), 0.48)
		drift.finished.connect(spark.queue_free)


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
		"image_lit":
			base = Color("e5ead5")
			edge = GOLD
			font_color = TEAL.darkened(0.10)
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
	await get_tree().create_timer(0.72).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var destination := ProjectSettings.globalize_path("res://captures/%s" % filename)
	var error := image.save_png(destination)
	if error != OK:
		push_error("Could not save Solmere tarot capture: %s" % error)
	get_tree().quit()
