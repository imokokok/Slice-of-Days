extends Control

const BACKGROUND := preload("res://art/reference/workbench-direction-warm-v2.png")
const PAPER := Color("fff8eb")
const PANEL := Color("fff8eb", 0.96)
const INK := Color("4a342b")
const MUTED := Color("806b5c")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")
const SAGE := Color("7d8f59")
const LINE := Color("b88963")

var module_id := ""
var background_texture: Texture2D = BACKGROUND
var prototype: Dictionary = {}
var interaction: Dictionary = {}
var selected_tokens: Array[String] = []
var token_buttons: Dictionary = {}
var choice_buttons: Array[Button] = []
var selection_label: Label
var result_label: Label
var clear_button: Button
var back_button: Button
var completed := false
var capture_requested := false


func _ready() -> void:
	module_id = GameplayModuleSystem.pending_module_id()
	if module_id.is_empty():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--capture-module="):
				capture_requested = true
				module_id = arg.trim_prefix("--capture-module=")
				GameState.begin_new_game("A")
				GameplayModuleSystem.unlock(module_id)
				GameplayModuleSystem.begin_session(module_id, "capture")
				break
	prototype = GameplayModuleSystem.prototype_for(module_id)
	interaction = prototype.get("interaction", {})
	var background_path := str(prototype.get("background_path", ""))
	if not background_path.is_empty() and ResourceLoader.exists(background_path):
		var loaded_background = load(background_path)
		if loaded_background is Texture2D:
			background_texture = loaded_background
	_build_ui()
	_update_interaction_state()
	if capture_requested:
		_capture.call_deferred("module-%s.png" % module_id)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("ead9bd"))
	draw_texture_rect(background_texture, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color("fff5df", 0.58))


func _build_ui() -> void:
	var metadata: Dictionary = GameplayModuleSystem.modules.get(module_id, {})
	var panel := _panel(self, Vector2(110, 54), Vector2(1380, 792), PANEL, LINE, 20)
	_label(panel, "SOLMERE 生活玩法", Vector2(42, 24), Vector2(340, 25), 14, TEAL)
	_label(panel, str(prototype.get("title", metadata.get("name", "玩法"))), Vector2(42, 53), Vector2(900, 46), 31, INK)
	var description := _label(panel, str(prototype.get("description", "当前玩法还没有说明。")), Vector2(42, 102), Vector2(1260, 50), 16, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_build_interaction_board(panel)
	_build_outcome_choices(panel)

	result_label = _label(panel, "先完成上面的准备，再决定怎样结束这次经历。", Vector2(44, 665), Vector2(950, 58), 15, MUTED)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	back_button = _button(panel, "返回小镇", Vector2(1082, 698), Vector2(250, 50), TEAL)
	back_button.pressed.connect(_return_to_town)


func _build_interaction_board(parent: Node) -> void:
	var board := _panel(parent, Vector2(40, 166), Vector2(1300, 280), Color("f5e6cf", 0.95), TEAL, 16)
	_label(board, "先在桌面上完成一次具体操作", Vector2(24, 18), Vector2(430, 28), 18, INK)
	var prompt := _label(board, str(interaction.get("prompt", "选择一项记录，再决定结果。")), Vector2(24, 50), Vector2(1180, 42), 14, MUTED)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tokens: Array = interaction.get("tokens", [])
	for index in tokens.size():
		var token: Dictionary = tokens[index]
		var column := index % 3
		var row := index / 3
		var button := _token_button(board, token, Vector2(24 + column * 410, 105 + row * 61), Vector2(390, 48))
		var token_id := str(token.get("id", "token_%d" % index))
		button.pressed.connect(_toggle_token.bind(token_id))
		token_buttons[token_id] = button
	selection_label = _label(board, "", Vector2(24, 230), Vector2(1050, 32), 14, INK)
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clear_button = _button(board, "重新整理", Vector2(1110, 224), Vector2(160, 40), TEAL)
	clear_button.pressed.connect(_clear_tokens)


func _build_outcome_choices(parent: Node) -> void:
	_label(parent, "决定怎样留下这次经历", Vector2(44, 463), Vector2(420, 28), 18, INK)
	var choices: Array = prototype.get("choices", [])
	var card_width := 1260.0 if choices.size() <= 1 else 610.0
	for index in choices.size():
		var choice: Dictionary = choices[index]
		var card_x := 44.0 + index * 638.0
		var card := _panel(parent, Vector2(card_x, 500), Vector2(card_width, 145), Color("fff9ef", 0.98), LINE, 14)
		_label(card, str(choice.get("label", "选择")), Vector2(20, 14), Vector2(card_width - 40, 28), 18, INK)
		var cost: Dictionary = choice.get("cost", {})
		var minutes := int(cost.get("minutes", 0))
		var detail_text := str(choice.get("detail", "")).trim_prefix("花费%d分钟，" % minutes).trim_prefix("花费%d分钟。" % minutes)
		if detail_text.is_empty():
			detail_text = "完成后记录这次经历。"
		var detail := _label(card, detail_text, Vector2(20, 46), Vector2(card_width - 235, 54), 14, MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label(card, "%d分钟 · %d元" % [minutes, int(cost.get("money", 0))], Vector2(20, 108), Vector2(210, 24), 13, TEAL)
		var choose := _button(card, "采用", Vector2(card_width - 188, 83), Vector2(164, 44), TERRACOTTA)
		choose.pressed.connect(_complete_choice.bind(str(choice.get("id", ""))))
		choice_buttons.append(choose)


func _toggle_token(token_id: String) -> void:
	if completed:
		return
	if selected_tokens.has(token_id):
		selected_tokens.erase(token_id)
	else:
		var maximum := int(interaction.get("max_select", 1))
		if selected_tokens.size() >= maximum:
			result_label.text = "桌面上最多保留%d项。可以先取消一项。" % maximum
			result_label.add_theme_color_override("font_color", TERRACOTTA)
			return
		selected_tokens.append(token_id)
	_update_interaction_state()


func _clear_tokens() -> void:
	if completed:
		return
	selected_tokens.clear()
	_update_interaction_state()


func _update_interaction_state() -> void:
	var minimum := int(interaction.get("min_select", 0))
	var maximum := int(interaction.get("max_select", minimum))
	var ready := selected_tokens.size() >= minimum
	for token_id in token_buttons:
		_style_token(token_buttons[token_id], selected_tokens.has(str(token_id)))
	var labels: Array[String] = []
	for token_id in selected_tokens:
		labels.append(_token_label(token_id))
	var mode := str(interaction.get("mode", "toggle"))
	var prefix := "排列" if mode == "ordered" else "已保留"
	selection_label.text = "%s：%s" % [prefix, " → ".join(labels)] if not labels.is_empty() else "尚未选择 · 需要%d项，最多%d项" % [minimum, maximum]
	if not completed:
		for button in choice_buttons:
			button.disabled = not ready
		clear_button.disabled = selected_tokens.is_empty()
		result_label.text = "准备完成，可以选择一种结果。" if ready else "还需要选择%d项。" % max(0, minimum - selected_tokens.size())
		result_label.add_theme_color_override("font_color", INK if ready else MUTED)


func _token_label(token_id: String) -> String:
	for token in interaction.get("tokens", []):
		if str(token.get("id", "")) == token_id:
			return str(token.get("label", token_id))
	return token_id


func _complete_choice(choice_id: String) -> void:
	var interaction_record := {
		"mode": str(interaction.get("mode", "toggle")),
		"selected_tokens": selected_tokens.duplicate(),
		"selected_labels": selected_tokens.map(func(token_id: String) -> String: return _token_label(token_id)),
	}
	var result := GameplayModuleSystem.complete_choice(choice_id, interaction_record)
	result_label.text = str(result.get("message", ""))
	result_label.add_theme_color_override("font_color", INK if bool(result.get("ok", false)) else TERRACOTTA)
	if bool(result.get("ok", false)):
		completed = true
		for button in choice_buttons:
			button.disabled = true
		for token_id in token_buttons:
			token_buttons[token_id].disabled = true
		clear_button.disabled = true
		SaveManager.save_game()


func _return_to_town() -> void:
	if not GameplayModuleSystem.pending_module_id().is_empty():
		GameplayModuleSystem.cancel_session()
	SceneRouter.town_day()


func _panel(parent: Node, at: Vector2, panel_size: Vector2, color: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(INK, 0.16)
	style.shadow_size = 9
	style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _token_button(parent: Node, token: Dictionary, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = str(token.get("label", "记录"))
	button.tooltip_text = str(token.get("detail", ""))
	var icon_path := str(token.get("icon_path", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var loaded_icon = load(icon_path)
		if loaded_icon is Texture2D:
			button.icon = loaded_icon
			button.icon_max_width = 30
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 14)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(button)
	_style_token(button, false)
	return button


func _style_token(button: Button, selected: bool) -> void:
	var base := Color(SAGE, 0.92) if selected else Color(PAPER, 0.92)
	var edge := SAGE if selected else Color(LINE, 0.82)
	var font_color := PAPER if selected else INK
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.border_color = edge
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 16
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = base.lightened(0.08)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", Color(font_color, 0.65))


func _button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = color.darkened(0.16)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(11)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.1)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("cfc5b5")
	disabled.border_color = LINE
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_pressed_color", PAPER)
	button.add_theme_color_override("font_disabled_color", Color(PAPER, 0.72))
	parent.add_child(button)
	return button


func _capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join(filename))
	get_tree().quit()
