extends Control

const SUPPORTED := ["cooking", "sound_sampling", "photography", "optical_illusion", "archives"]
const PAPER := Color("fff5df")
const INK := Color("352d29")
const MUTED := Color("74675f")
const TERRACOTTA := Color("bd6248")
const SEA := Color("537982")
const SAGE := Color("788567")
const GOLD := Color("d5a952")
const BOARD := Rect2(42, 122, 920, 610)

var module_id := ""
var prototype: Dictionary = {}
var interaction: Dictionary = {}
var selected_tokens: Array[String] = []
var token_buttons: Dictionary = {}
var choice_buttons: Dictionary = {}
var background_texture: Texture2D
var instruction_label: Label
var selection_label: Label
var status_label: Label
var primary_button: Button
var return_button: Button
var value_slider: HSlider
var value_label: Label
var stage_ready := false
var completed := false
var playback_active := false
var playback_cursor := 0.0


func _ready() -> void:
	module_id = GameplayModuleSystem.pending_module_id()
	if not SUPPORTED.has(module_id):
		call_deferred("_fail")
		return
	prototype = GameplayModuleSystem.prototype_for(module_id)
	interaction = prototype.get("interaction", {})
	var background_path := str(prototype.get("background_path", ""))
	if not background_path.is_empty() and ResourceLoader.exists(background_path):
		var loaded = load(background_path)
		if loaded is Texture2D:
			background_texture = loaded
	var atlas_pages := {"cooking":16,"sound_sampling":85,"photography":91,"optical_illusion":91,"archives":97}
	if atlas_pages.has(module_id):
		var first := int(atlas_pages[module_id])
		background_texture = preload("res://scripts/ui/scene_atlas.gd").plate({"pages":[first,first+1,first+2]})
	_build_theme()
	_build_ui()
	_update_state()
	WorldSound.set_active(true)
	WorldSound.set_location(GameState.current_location)
	set_process(module_id == "sound_sampling")
	queue_redraw()


func _build_theme() -> void:
	var ui_theme := Theme.new()
	if DisplayServer.get_name() != "headless":
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", "sans-serif"])
		font.allow_system_fallback = true
		ui_theme.default_font = font
	ui_theme.default_font_size = 16
	theme = ui_theme


func _build_ui() -> void:
	var header := _panel(self, Vector2(24, 20), Vector2(1552, 82), Color(PAPER, 0.96), TERRACOTTA)
	_label(header, _eyebrow(), Vector2(22, 10), Vector2(520, 24), 13, SEA)
	_label(header, str(prototype.get("title", module_id)), Vector2(22, 32), Vector2(760, 38), 27, INK)
	_label(header, "第%d天 · %s · %s视角" % [GameState.current_day, GameState.clock_text(), GameState.current_role], Vector2(900, 27), Vector2(390, 28), 15, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var leave := _button(header, "暂时离开", Vector2(1320, 18), Vector2(205, 48), false)
	leave.pressed.connect(_return_or_cancel)

	var side := _panel(self, Vector2(985, 122), Vector2(590, 610), Color(PAPER, 0.96), Color(SEA, 0.75))
	instruction_label = _label(side, str(interaction.get("prompt", "完成这段操作。")), Vector2(22, 16), Vector2(546, 72), 15, INK)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	selection_label = _label(side, "", Vector2(22, 92), Vector2(546, 52), 14, SEA)
	selection_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var tokens: Array = interaction.get("tokens", [])
	for index in tokens.size():
		var token: Dictionary = tokens[index]
		var token_id := str(token.get("id", ""))
		var token_button := _button(side, _token_button_text(token), Vector2(22, 150 + index * (36 if module_id == "cooking" else 52)), Vector2(546, 32 if module_id == "cooking" else 44), false)
		token_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		token_button.tooltip_text = str(token.get("detail", ""))
		token_button.pressed.connect(_toggle_token.bind(token_id))
		token_buttons[token_id] = token_button

	_build_module_control(side)
	var choice_y := 522
	for choice in prototype.get("choices", []):
		var choice_id := str(choice.get("id", ""))
		var minutes := int(choice.get("cost", {}).get("minutes", 0))
		if module_id == "cooking": minutes = int(EconomySystem.cooking_cost(choice.get("cost", {})).get("minutes", minutes))
		var choice_button := _button(side, "%s · %d分钟" % [str(choice.get("label", choice_id)), minutes], Vector2(22, choice_y), Vector2(546, 42), true)
		choice_button.tooltip_text = str(choice.get("detail", ""))
		choice_button.pressed.connect(_complete_choice.bind(choice_id))
		choice_buttons[choice_id] = choice_button
		choice_y += 50

	var footer := _panel(self, Vector2(112, 754), Vector2(1376, 122), Color(PAPER, 0.97), TERRACOTTA)
	status_label = _label(footer, _initial_status(), Vector2(24, 18), Vector2(1040, 82), 16, INK)
	status_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	return_button = _button(footer, "返回原空间", Vector2(1092, 34), Vector2(250, 54), false)
	return_button.pressed.connect(_return_or_cancel)
	_label(self, "数字键选择素材 · R 执行操作 · Esc 暂时离开", Vector2(520, 879), Vector2(560, 20), 12, Color(PAPER, 0.9), HORIZONTAL_ALIGNMENT_CENTER)


func _build_module_control(parent: Control) -> void:
	value_label = _label(parent, "", Vector2(22, 414), Vector2(320, 28), 14, MUTED)
	primary_button = _button(parent, _primary_text(), Vector2(366, 416), Vector2(202, 48), true)
	primary_button.pressed.connect(_perform_primary_action)
	if module_id in ["cooking", "photography", "optical_illusion"]:
		value_slider = HSlider.new()
		value_slider.position = Vector2(22, 451)
		value_slider.size = Vector2(324, 34)
		value_slider.min_value = 0.0
		value_slider.max_value = 1.0
		value_slider.step = 0.01
		value_slider.value = 0.58 if module_id == "cooking" else (0.5 if module_id == "photography" else 0.0)
		value_slider.value_changed.connect(_on_value_changed)
		parent.add_child(value_slider)
	elif module_id == "sound_sampling":
		_label(parent, "时间线会按选择顺序播放；来源标记始终和片段一起移动。", Vector2(22, 446), Vector2(324, 52), 12, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		_label(parent, "来源编号不会从记录上剥离；建立连接和保留缺口都属于有效整理。", Vector2(22, 446), Vector2(324, 52), 12, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _toggle_token(token_id: String) -> void:
	if completed or playback_active:
		return
	if module_id == "cooking" and not EconomySystem.ingredient_available(token_id):
		status_label.text = "这份材料还没带到厨房，先去采购。"
		return
	if selected_tokens.has(token_id):
		selected_tokens.erase(token_id)
	else:
		var maximum := int(interaction.get("max_select", 1))
		if selected_tokens.size() >= maximum:
			status_label.text = "最多保留 %d 项。先取消一项，作品不会替你丢掉边界。" % maximum
			return
		selected_tokens.append(token_id)
	stage_ready = false
	_update_state()


func _on_value_changed(_value: float) -> void:
	if completed:
		return
	stage_ready = false
	_update_state()


func _perform_primary_action() -> void:
	if completed or playback_active:
		return
	var minimum := int(interaction.get("min_select", 0))
	if selected_tokens.size() < minimum:
		status_label.text = "还需要选择 %d 项，才能完成这次操作。" % (minimum - selected_tokens.size())
		return
	match module_id:
		"cooking":
			var heat := value_slider.value
			if heat < 0.42 or heat > 0.74:
				status_label.text = "火候还没有进入稳定区。让指针停在陶土色刻度之间。"
				return
			stage_ready = true
			status_label.text = "火候稳定，三样材料已经完成同一轮处理。现在决定怎样出餐。"
		"sound_sampling":
			playback_active = true
			playback_cursor = 0.0
			primary_button.disabled = true
			status_label.text = "正在试听这条短轨。来源标记与声音片段一起经过播放头……"
		"photography":
			var exposure := value_slider.value
			if exposure < 0.28 or exposure > 0.76:
				status_label.text = "高光或暗部已经失去细节。先把曝光调回可辨认范围。"
				return
			stage_ready = true
			WorldSound.play_detail(true)
			status_label.text = "快门落下。取景框内与框外的东西都还在，只是进入了不同记录。"
		"optical_illusion":
			if selected_tokens.size() != 2:
				status_label.text = "必须同时保留两份记录，才能寻找它们共同成立的角度。"
				return
			var target := _perspective_target()
			if absf(value_slider.value - target) > 0.055:
				status_label.text = "连接仍然断开。继续改变视角，让门框、楼梯和光线在同一投影中重合。"
				return
			stage_ready = true
			status_label.text = "两份矛盾记录在这个角度同时成立。空间没有被纠正，但连接已经出现。"
		"archives":
			stage_ready = true
			var has_time_link := selected_tokens.has("tide_log") and selected_tokens.has("station_ticket")
			var has_sound_link := selected_tokens.has("voice_catalog") and (selected_tokens.has("bus_manifest") or selected_tokens.has("station_ticket"))
			status_label.text = "来源和地点形成了可复查连接，可以建立交叉索引。" if has_time_link or has_sound_link else "三份记录仍缺少可靠连接。可以明确标出缺口，不必猜测补齐。"
	WorldSound.play_detail(true)
	_update_state()


func _process(delta: float) -> void:
	if not playback_active:
		return
	playback_cursor += delta / 2.4
	if playback_cursor >= 1.0:
		playback_cursor = 1.0
		playback_active = false
		stage_ready = true
		status_label.text = "试听完成。现在可以交付有授权的版本，或把边界不明的片段留作私人采样。"
	_update_state()
	queue_redraw()


func _update_state() -> void:
	var minimum := int(interaction.get("min_select", 0))
	var labels: Array[String] = []
	for token_id in selected_tokens:
		labels.append(_token_label(token_id))
	var joiner := " → " if str(interaction.get("mode", "toggle")) == "ordered" else "、"
	selection_label.text = "当前：%s" % joiner.join(labels) if not labels.is_empty() else "尚未选择 · 至少 %d 项" % minimum
	for token_id in token_buttons:
		_style_button(token_buttons[token_id], selected_tokens.has(str(token_id)))
		token_buttons[token_id].disabled = completed or playback_active
		if module_id == "cooking":
			token_buttons[token_id].disabled = completed or not EconomySystem.ingredient_available(str(token_id))
	_update_module_value()
	primary_button.disabled = completed or playback_active or selected_tokens.size() < minimum
	var record := _interaction_record()
	for choice_id in choice_buttons:
		var check := GameplayModuleSystem.choice_interaction_check(module_id, str(choice_id), record)
		choice_buttons[choice_id].disabled = completed or not stage_ready or not bool(check.get("ok", false))
		if not bool(check.get("ok", false)):
			choice_buttons[choice_id].tooltip_text = str(check.get("message", "当前素材不符合这个结果。"))
	queue_redraw()


func _update_module_value() -> void:
	if value_label == null:
		return
	match module_id:
		"cooking":
			var heat := value_slider.value
			value_label.text = "火候 %d%% · %s" % [roundi(heat * 100), "稳定" if heat >= 0.42 and heat <= 0.74 else "需要调整"]
		"sound_sampling":
			value_label.text = "试听进度 %d%%" % roundi(playback_cursor * 100)
		"photography":
			value_label.text = "曝光 %+d · %s" % [roundi((value_slider.value - 0.5) * 200), "细节可辨" if value_slider.value >= 0.28 and value_slider.value <= 0.76 else "细节丢失"]
		"optical_illusion":
			value_label.text = "观察角度 %d° · %s" % [roundi(value_slider.value * 90), "连接成立" if stage_ready else "目标投影尚未标注"]
		"archives":
			value_label.text = "已展开 %d / 3 份来源记录" % selected_tokens.size()


func _complete_choice(choice_id: String) -> void:
	if completed or not stage_ready:
		return
	var rollback_snapshot := GameState.to_save_data().duplicate(true)
	var result := GameplayModuleSystem.complete_choice(choice_id, _interaction_record())
	status_label.text = str(result.get("message", ""))
	if not bool(result.get("ok", false)):
		return
	if module_id == "cooking": status_label.text += "\n材料已实际用掉，出餐和工资记在今天的工作记录里。"
	completed = true
	if not SaveManager.save_or_report("玩法结果保存失败"):
		GameState.load_save_data(rollback_snapshot)
		completed = false
		status_label.text = "存档写入失败，本次提交尚未生效；可以重试。"
		return
	return_button.text = "带着结果返回"
	_update_state()


func _interaction_record() -> Dictionary:
	return {
		"mode": str(interaction.get("mode", "toggle")),
		"selected_tokens": selected_tokens.duplicate(),
		"selected_labels": selected_tokens.map(func(token_id: String) -> String: return _token_label(token_id)),
		"mechanic": {
			"heat": value_slider.value if module_id == "cooking" else null,
			"exposure": value_slider.value if module_id == "photography" else null,
			"view_angle": value_slider.value if module_id == "optical_illusion" else null,
			"auditioned": stage_ready if module_id == "sound_sampling" else null,
			"archive_reviewed": stage_ready if module_id == "archives" else null,
		},
	}


func _return_or_cancel() -> void:
	if not GameplayModuleSystem.pending_module_id().is_empty():
		GameplayModuleSystem.cancel_session()
	if not SaveManager.save_or_report("退出玩法后保存失败"):
		status_label.text = "状态已撤销，但存档写入失败。"
		return
	SceneRouter.return_from_gameplay()


func _fail() -> void:
	push_error("Native gameplay scene received unsupported module: %s" % module_id)
	GameplayModuleSystem.cancel_session()
	SceneRouter.return_from_gameplay()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_5:
		var index := int(event.keycode - KEY_1)
		var tokens: Array = interaction.get("tokens", [])
		if index < tokens.size():
			_toggle_token(str(tokens[index].get("id", "")))
	elif event.is_action_pressed("restart_module"):
		_perform_primary_action()
	elif event.is_action_pressed("ui_cancel"):
		_return_or_cancel()


func _draw() -> void:
	if background_texture != null:
		draw_texture_rect(background_texture, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("718087"))
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.45))
	draw_style_box(_board_style(), BOARD)
	match module_id:
		"cooking": _draw_cooking()
		"sound_sampling": _draw_sound()
		"photography": _draw_photography()
		"optical_illusion": _draw_perspective()
		"archives": _draw_archives()


func _draw_cooking() -> void:
	var center := Vector2(505, 424)
	draw_circle(center, 154, Color("3d3834"))
	draw_circle(center, 128, Color("bb6a48"))
	draw_circle(center, 111, Color("e5b55f"))
	for index in selected_tokens.size():
		var angle := -PI * 0.82 + index * PI * 0.45
		var color: Color = [Color("e1c34f"), Color("bd5e43"), Color("708b66"), Color("f1dfb8"), Color("d7aa67")][abs(hash(selected_tokens[index])) % 5]
		draw_circle(center + Vector2(cos(angle), sin(angle)) * 68, 28, color)
	var heat := value_slider.value if value_slider != null else 0.0
	draw_rect(Rect2(210, 662, 590, 18), Color("d9cbb7"))
	draw_rect(Rect2(210, 662, 590 * heat, 18), TERRACOTTA if heat >= 0.42 and heat <= 0.74 else GOLD)
	draw_line(Vector2(210 + 590 * 0.42, 654), Vector2(210 + 590 * 0.42, 688), PAPER, 3)
	draw_line(Vector2(210 + 590 * 0.74, 654), Vector2(210 + 590 * 0.74, 688), PAPER, 3)


func _draw_sound() -> void:
	for track in 3:
		var y := 292.0 + track * 112
		draw_line(Vector2(112, y), Vector2(890, y), Color(SEA, 0.55), 2)
		if track < selected_tokens.size():
			var id := selected_tokens[track]
			var unsafe := id in ["cafe_cups", "old_hinge"]
			var block := Rect2(150 + track * 115, y - 36, 360, 72)
			draw_rect(block, Color(TERRACOTTA if unsafe else SAGE, 0.88))
			for wave in 16:
				var x := block.position.x + 12 + wave * 21
				var height: float = 8.0 + absf(sin(float(wave * 3 + track))) * 22.0
				draw_line(Vector2(x, y - height), Vector2(x, y + height), Color(PAPER, 0.75), 3)
	if playback_active or playback_cursor > 0:
		var x := lerpf(112, 890, playback_cursor)
		draw_line(Vector2(x, 220), Vector2(x, 610), GOLD, 4)


func _draw_photography() -> void:
	var frame := Rect2(145, 185, 710, 475)
	draw_rect(frame, Color("688b91", 0.28))
	draw_line(frame.position + Vector2(frame.size.x / 3, 0), frame.position + Vector2(frame.size.x / 3, frame.size.y), Color(PAPER, 0.35), 2)
	draw_line(frame.position + Vector2(frame.size.x * 2 / 3, 0), frame.position + Vector2(frame.size.x * 2 / 3, frame.size.y), Color(PAPER, 0.35), 2)
	draw_line(frame.position + Vector2(0, frame.size.y / 3), frame.position + Vector2(frame.size.x, frame.size.y / 3), Color(PAPER, 0.35), 2)
	draw_line(frame.position + Vector2(0, frame.size.y * 2 / 3), frame.position + Vector2(frame.size.x, frame.size.y * 2 / 3), Color(PAPER, 0.35), 2)
	var anchors := {
		"reflection": Rect2(190, 225, 155, 230),
		"people": Rect2(420, 330, 150, 250),
		"sea_edge": Rect2(605, 205, 210, 155),
		"empty_chair": Rect2(640, 455, 145, 120),
	}
	for token_id in anchors:
		var rect: Rect2 = anchors[token_id]
		if selected_tokens.has(token_id):
			draw_rect(rect, Color(GOLD, 0.18))
			draw_rect(rect, GOLD, false, 4)
		else:
			draw_rect(rect, Color(GOLD, 0.32), false, 3)
	var exposure := value_slider.value if value_slider != null else 0.5
	draw_rect(frame, Color(1, 0.94, 0.78, absf(exposure - 0.5) * 0.72))
	draw_circle(frame.get_center(), 7, TERRACOTTA)
	draw_line(frame.get_center() - Vector2(22, 0), frame.get_center() + Vector2(22, 0), TERRACOTTA, 2)
	draw_line(frame.get_center() - Vector2(0, 22), frame.get_center() + Vector2(0, 22), TERRACOTTA, 2)


func _draw_perspective() -> void:
	var angle := value_slider.value if value_slider != null else 0.0
	var shift := lerpf(-150, 150, angle)
	var origin := Vector2(500, 420)
	var corners := [Vector2(170, 205), Vector2(830, 205), Vector2(830, 640), Vector2(170, 640)]
	for corner in corners:
		draw_line(origin, corner, Color(PAPER, 0.55), 3)
	draw_polyline(PackedVector2Array([Vector2(270 + shift, 300), Vector2(455 + shift, 300), Vector2(455 + shift, 520), Vector2(270 + shift, 520), Vector2(270 + shift, 300)]), SEA, 7)
	draw_polyline(PackedVector2Array([Vector2(545 - shift, 520), Vector2(730 - shift, 520), Vector2(730 - shift, 300), Vector2(545 - shift, 300), Vector2(545 - shift, 520)]), TERRACOTTA, 7)
	for step in 6:
		var start := Vector2(375 + shift * 0.35 + step * 45, 575 - step * 38)
		draw_line(start, start + Vector2(120, 0), Color(GOLD, 0.9), 7)
	var target := _perspective_target()
	if selected_tokens.size() == 2 and absf(angle - target) <= 0.055:
		draw_circle(origin, 34, Color(GOLD, 0.65))
		draw_circle(origin, 12, PAPER)


func _draw_archives() -> void:
	var cards := [
		Rect2(125, 205, 225, 320),
		Rect2(390, 250, 225, 320),
		Rect2(655, 185, 225, 320),
	]
	for index in cards.size():
		var card: Rect2 = cards[index]
		draw_rect(card, Color(PAPER, 0.92))
		draw_rect(card, Color(GOLD if index < selected_tokens.size() else SEA, 0.8), false, 5)
		for line in 7:
			var line_width := card.size.x - 44 - (line % 3) * 24
			draw_line(card.position + Vector2(22, 78 + line * 28), card.position + Vector2(22 + line_width, 78 + line * 28), Color(MUTED, 0.42), 3)
		draw_circle(card.position + Vector2(card.size.x - 38, 36), 13, TERRACOTTA if index < selected_tokens.size() else Color(SEA, 0.5))
	if selected_tokens.size() >= 2:
		draw_line(cards[0].get_center(), cards[1].get_center(), Color(GOLD, 0.76), 4)
	if selected_tokens.size() >= 3:
		draw_line(cards[1].get_center(), cards[2].get_center(), Color(GOLD, 0.76), 4)
		draw_line(cards[0].get_center(), cards[2].get_center(), Color(GOLD, 0.42), 2)


func _perspective_target() -> float:
	if selected_tokens.has("photo_door") and selected_tokens.has("map_door"):
		return 0.35
	if selected_tokens.has("note_stairs") and selected_tokens.has("model_stairs"):
		return 0.72
	return 0.54


func _token_label(token_id: String) -> String:
	for token in interaction.get("tokens", []):
		if str(token.get("id", "")) == token_id:
			return str(token.get("label", token_id))
	return token_id


func _token_button_text(token: Dictionary) -> String:
	var label := str(token.get("label", "素材"))
	if module_id == "cooking":
		var count := int(GameState.inventory.get(str(token.get("id", "")), 0))
		if count > 0:
			return "%s  ·  随身有%d" % [label, count]
	if module_id == "sound_sampling":
		return ("△  " if str(token.get("id", "")) in ["cafe_cups", "old_hinge"] else "✓  ") + label
	return label


func _eyebrow() -> String:
	return {
		"cooking": "RESTAURANT / PREP & HEAT",
		"sound_sampling": "RECORDS / SOURCE & TIMELINE",
		"photography": "PHOTO / FRAME & EXPOSURE",
		"optical_illusion": "STATION / PERSPECTIVE",
		"archives": "LIBRARY / CROSS INDEX",
	}.get(module_id, "SOLMERE / WORKBENCH")


func _primary_text() -> String:
	return {
		"cooking": "确认火候",
		"sound_sampling": "试听短轨",
		"photography": "按下快门",
		"optical_illusion": "锁定视角",
		"archives": "核对三份来源",
	}.get(module_id, "完成操作")


func _initial_status() -> String:
	return {
		"cooking": "先挑三样材料，再调整火候。菜名不是第一步，先让今天的剩料能够一起工作。",
		"sound_sampling": "绿色标记可用于交付；三角标记含未授权人声或来源不明，只能进入私人版本。",
		"photography": "选择画面中的两到三处关系，再调整曝光。取景框之外仍然属于这个地方。",
		"optical_illusion": "选择两份矛盾记录，拖动观察角度。正确答案不是删掉其中一份。",
		"archives": "展开三份来源不同的记录。可靠连接可以进入公共索引，证据不足也可以明确保留空格。",
	}.get(module_id, "完成这段操作。")


func _board_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK, 0.68)
	style.border_color = Color(PAPER, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	return style


func _panel(parent: Node, at: Vector2, panel_size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(INK, 0.18)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	_style_button(button, primary)
	return button


func _style_button(button: Button, selected_or_primary: bool) -> void:
	var fill := TERRACOTTA if selected_or_primary else Color(PAPER, 0.82)
	var border := TERRACOTTA if selected_or_primary else Color(SEA, 0.55)
	var font_color := PAPER if selected_or_primary else INK
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fill.lightened(0.08) if state == "hover" else (fill.darkened(0.08) if state == "pressed" else fill)
		style.border_color = border
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.content_margin_left = 14
		button.add_theme_stylebox_override(state, style)
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color("d3c9b8")
	disabled.border_color = Color("aa9c89")
	disabled.set_border_width_all(2)
	disabled.set_corner_radius_all(8)
	button.add_theme_stylebox_override("disabled", disabled)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, font_color)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.75))
