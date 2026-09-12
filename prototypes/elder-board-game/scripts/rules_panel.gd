extends Control
signal start_requested(go_size: int)
signal closed
const Text = preload("res://scripts/game_text.gd")
var game_id: StringName
var setup_mode := false
var go_size := 9
var size_choice: OptionButton

func configure(id: StringName, is_setup: bool, preferred_size: int = 9) -> void:
	game_id = id
	setup_mode = is_setup
	go_size = preferred_size

func _ready() -> void:
	size = Vector2(1579, 972)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.size = size
	add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(265, 65)
	panel.size = Vector2(1050, 842)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("303330")
	style.set_corner_radius_all(12)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 25
	style.content_margin_bottom = 25
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var title := Label.new()
	var names := {&"go": "围棋", &"gomoku": "五子棋", &"chess": "国际象棋"}
	title.text = names[game_id] + (" · 开局准备" if setup_mode else " · 规则说明")
	title.add_theme_font_size_override("font_size", 34)
	column.add_child(title)
	var intro := Label.new()
	intro.text = "老棋友：先看看规则，准备好了咱们就开始。" if setup_mode else "老棋友：不着急，看完再接着下。"
	intro.add_theme_font_size_override("font_size", 24)
	column.add_child(intro)
	if game_id == &"go" and setup_mode:
		size_choice = OptionButton.new()
		for item in ["9 路 · 短局入门", "13 路 · 中盘练习", "19 路 · 完整棋盘"]: size_choice.add_item(item)
		size_choice.select([9, 13, 19].find(go_size))
		size_choice.custom_minimum_size.y = 52
		size_choice.item_selected.connect(func(index: int): go_size = [9, 13, 19][index])
		column.add_child(size_choice)
	var body := RichTextLabel.new()
	body.text = Text.RULES[game_id]
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size.y = 340
	body.add_theme_font_size_override("normal_font_size", 25)
	body.add_theme_constant_override("line_separation", 7)
	body.scroll_active = true
	column.add_child(body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	column.add_child(footer)
	var back := Button.new()
	back.text = "返回选择" if setup_mode else "明白了，继续下棋"
	back.custom_minimum_size = Vector2(280, 60)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func(): closed.emit())
	footer.add_child(back)
	if setup_mode:
		var start := Button.new()
		start.text = "准备好了，开始对弈"
		start.custom_minimum_size = Vector2(400, 60)
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		start.pressed.connect(func(): start_requested.emit(go_size))
		footer.add_child(start)
		start.grab_focus()
	else: back.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
