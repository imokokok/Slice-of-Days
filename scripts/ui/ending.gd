extends Control

const BACKGROUND := preload("res://art/ui/title-screen-background.png")
const PAPER := Color("fff8eb")
const INK := Color("4a342b")
const MUTED := Color("806b5c")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")
const LINE := Color("b88963")


func _ready() -> void:
	_build_ui()


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color("fff5df", 0.58))


func _build_ui() -> void:
	var audit := ChapterSystem.journey_audit()
	var a: Dictionary = audit.get("A", {})
	var b: Dictionary = audit.get("B", {})
	var both_passed := bool(a.get("passed", false)) and bool(b.get("passed", false))
	var title := "两个人都被小镇记住了" if both_passed else "七天已经结束"
	_label(self, title, Vector2(120, 72), Vector2(1100, 60), 38, INK)
	_label(self, "结果只记录发生过的事，不替她们总结这七天。", Vector2(122, 135), Vector2(900, 32), 17, MUTED)
	_result_panel(Vector2(170, 225), a)
	_result_panel(Vector2(830, 225), b)
	var closing := "两张几乎一样的晚霞照片慢慢重叠。"
	var closing_label := _label(self, closing, Vector2(410, 670), Vector2(780, 38), 20, INK)
	closing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var menu := _button(self, "返回主菜单", Vector2(690, 760), Vector2(220, 52), TERRACOTTA)
	menu.pressed.connect(SceneRouter.main_menu)


func _result_panel(at: Vector2, result: Dictionary) -> void:
	var panel := Panel.new()
	panel.position = at
	panel.size = Vector2(600, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PAPER, 0.95)
	style.border_color = TEAL if bool(result.get("passed", false)) else LINE
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(INK, 0.18)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_label(panel, "%s 的七天" % str(result.get("role", "?")), Vector2(34, 30), Vector2(300, 40), 27, INK)
	_label(panel, "居民认可  %d / %d" % [int(result.get("confirmed", 0)), int(result.get("required", 12))], Vector2(34, 90), Vector2(500, 42), 23, TERRACOTTA)
	var status := "通过试居审核" if bool(result.get("passed", false)) else "没有达到12份认可"
	_label(panel, status, Vector2(34, 145), Vector2(500, 34), 18, TEAL if bool(result.get("passed", false)) else MUTED)
	_label(panel, "完成经历：%d" % int(result.get("completed_events", 0)), Vector2(34, 210), Vector2(500, 28), 16, MUTED)
	_label(panel, "私人记录：%d" % int(result.get("journal_entries", 0)), Vector2(34, 250), Vector2(500, 28), 16, MUTED)
	_label(panel, "待定 %d · 拒绝 %d" % [int(result.get("pending", 0)), int(result.get("refused", 0))], Vector2(34, 290), Vector2(500, 28), 16, MUTED)


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
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = color.darkened(0.16)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	parent.add_child(button)
	return button
