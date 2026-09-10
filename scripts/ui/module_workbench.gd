extends Control

const BACKGROUND := preload("res://art/ui/title-screen-background.png")
const PAPER := Color("fff8eb")
const PANEL := Color("fff8eb", 0.96)
const INK := Color("4a342b")
const MUTED := Color("806b5c")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")
const SAGE := Color("7d8f59")
const LINE := Color("b88963")

var module_id := ""
var choice_buttons: Array[Button] = []
var result_label: Label
var back_button: Button


func _ready() -> void:
	module_id = GameplayModuleSystem.pending_module_id()
	if module_id.is_empty():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--capture-module="):
				module_id = arg.trim_prefix("--capture-module=")
				GameState.begin_new_game("A")
				GameplayModuleSystem.unlock(module_id)
				GameplayModuleSystem.begin_session(module_id, "capture")
				break
	_build_ui()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("ead9bd"))
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color("fff5df", 0.64))


func _build_ui() -> void:
	var prototype := GameplayModuleSystem.prototype_for(module_id)
	var metadata: Dictionary = GameplayModuleSystem.modules.get(module_id, {})
	var panel := _panel(self, Vector2(150, 90), Vector2(1300, 720))
	_label(panel, "灰盒玩法工作台", Vector2(44, 28), Vector2(300, 28), 15, TEAL)
	_label(panel, str(prototype.get("title", metadata.get("name", "玩法"))), Vector2(44, 65), Vector2(900, 52), 34, INK)
	var description := _label(panel, str(prototype.get("description", "当前玩法还没有灰盒说明。")), Vector2(44, 125), Vector2(1180, 70), 17, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_label(panel, "选择一种做法", Vector2(44, 220), Vector2(240, 30), 18, INK)

	var choices: Array = prototype.get("choices", [])
	for index in choices.size():
		var choice: Dictionary = choices[index]
		var card_x := 44 + index * 600
		var card := _panel(panel, Vector2(card_x, 270), Vector2(560, 210))
		_label(card, str(choice.get("label", "选择")), Vector2(24, 20), Vector2(510, 35), 21, INK)
		var detail := _label(card, str(choice.get("detail", "")), Vector2(24, 65), Vector2(510, 70), 15, MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		var cost: Dictionary = choice.get("cost", {})
		_label(card, "花费 %d分钟 · %d元" % [int(cost.get("minutes", 0)), int(cost.get("money", 0))], Vector2(24, 137), Vector2(260, 24), 14, TEAL)
		var choose := _button(card, "采用这种做法", Vector2(310, 137), Vector2(220, 46), TERRACOTTA)
		choose.pressed.connect(_complete_choice.bind(str(choice.get("id", ""))))
		choice_buttons.append(choose)

	result_label = _label(panel, "结果会写回当前角色的关系、日记、作品和玩法记录。", Vector2(44, 530), Vector2(1180, 80), 16, MUTED)
	result_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	back_button = _button(panel, "返回小镇", Vector2(1010, 625), Vector2(230, 50), TEAL)
	back_button.pressed.connect(_return_to_town)


func _complete_choice(choice_id: String) -> void:
	var result := GameplayModuleSystem.complete_choice(choice_id)
	result_label.text = str(result.get("message", ""))
	result_label.add_theme_color_override("font_color", INK if bool(result.get("ok", false)) else TERRACOTTA)
	if bool(result.get("ok", false)):
		for button in choice_buttons:
			button.disabled = true
		SaveManager.save_game()


func _return_to_town() -> void:
	if not GameplayModuleSystem.pending_module_id().is_empty():
		GameplayModuleSystem.cancel_session()
	SceneRouter.town_day()


func _panel(parent: Node, at: Vector2, panel_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = LINE
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(INK, 0.18)
	style.shadow_size = 10
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
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("cfc5b5")
	disabled.border_color = LINE
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_disabled_color", Color(PAPER, 0.72))
	parent.add_child(button)
	return button
