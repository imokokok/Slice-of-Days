extends Control

const BACKGROUND := preload("res://art/ui/title-screen-background.png")
const PAPER := Color("fff8eb")
const INK := Color("4a342b")
const MUTED := Color("806b5c")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")
const LINE := Color("b88963")

var moving_card: Panel
var alignment_slider: HSlider
var instruction_label: Label
var continue_button: Button
var transition_id := ""


func _ready() -> void:
	_build_ui()
	_update_alignment(20.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("ead9bd"))
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color("fff5df", 0.46))


func _build_ui() -> void:
	var context := ChapterSystem.transition_context()
	transition_id = str(context.get("transition_id", "transition"))
	var current: Dictionary = context.get("from", {})
	var next: Dictionary = context.get("to", {})
	var title := "第 %d 天 · %s 的这一段结束了" % [
		int(current.get("day", GameState.current_day)),
		str(current.get("role", GameState.current_role)),
	]
	_make_label(self, title, Vector2(80, 60), Vector2(900, 44), 30, INK)
	var next_text := "七天旅程即将结束" if next.is_empty() else "接下来：第 %d 天 · %s" % [
		int(next.get("day", 1)),
		str(next.get("role", "B")),
	]
	_make_label(self, next_text, Vector2(82, 108), Vector2(760, 30), 17, MUTED)

	_make_photo_card(Vector2(300, 210), false)
	moving_card = _make_photo_card(Vector2(900, 245), true)

	instruction_label = _make_label(
		self,
		"移动右侧照片，让两张照片的边缘对齐。",
		Vector2(460, 660),
		Vector2(680, 28),
		16,
		INK
	)
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	alignment_slider = HSlider.new()
	alignment_slider.position = Vector2(520, 710)
	alignment_slider.size = Vector2(560, 34)
	alignment_slider.min_value = 0
	alignment_slider.max_value = 100
	alignment_slider.step = 1
	alignment_slider.value = 20
	alignment_slider.value_changed.connect(_update_alignment)
	add_child(alignment_slider)

	var auto_align := _make_button(self, "轻轻对齐", Vector2(575, 775), Vector2(190, 48), TEAL)
	auto_align.pressed.connect(func() -> void: alignment_slider.value = 50)
	continue_button = _make_button(self, "继续", Vector2(835, 775), Vector2(190, 48), TERRACOTTA)
	continue_button.disabled = true
	continue_button.pressed.connect(_continue_journey)


func _make_photo_card(at: Vector2, moving: bool) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = Vector2(400, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PAPER, 0.96)
	style.border_color = TEAL if moving else TERRACOTTA
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(INK, 0.24)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 7)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var image := TextureRect.new()
	image.position = Vector2(18, 18)
	image.size = Vector2(364, 280)
	image.texture = BACKGROUND
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(image)
	_make_label(panel, "同一座小镇入口", Vector2(22, 312), Vector2(350, 28), 15, MUTED)
	return panel


func _update_alignment(value: float) -> void:
	if moving_card == null:
		return
	moving_card.position.x = 900.0 - value * 4.0
	var aligned: bool = abs(value - 50.0) <= 3.0
	if continue_button != null:
		continue_button.disabled = not aligned
	if instruction_label != null:
		instruction_label.text = "两张照片已经重叠。生活仍然各自继续。" if aligned else "移动右侧照片，让两张照片的边缘对齐。"


func _continue_journey() -> void:
	ChapterSystem.mark_transition_complete(transition_id)
	var result := ChapterSystem.advance_chapter()
	SaveManager.save_game()
	if bool(result.get("complete", false)):
		SceneRouter.ending()
	else:
		SceneRouter.town_day()


func _make_label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = color.darkened(0.15)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
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
