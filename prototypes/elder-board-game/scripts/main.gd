extends Control
## Emitted when the user enters a local AI match.
signal game_selected(game_id: StringName)

const DESIGN_SIZE := Vector2(1579, 972)
const GAMES := [
	{"id": &"go", "title": "围棋"},
	{"id": &"gomoku", "title": "五子棋"},
	{"id": &"chess", "title": "国际象棋"},
]

var selected_game: StringName = &""
var stage: Control
var dialogue: Label
var choices: HBoxContainer
var back_button: Button
var buttons: Array[Button] = []
var match_view: Control
var setup_view: Control
var selected_go_size := 9
var greeting_index := 0
const Text = preload("res://scripts/game_text.gd")
const Memory = preload("res://scripts/elder_memory.gd")
var teaching_view: Control
var story_view: Control
var role_choice: OptionButton

func _ready() -> void:
	DisplayServer.window_set_title("老棋友 · 教棋试玩")
	var ui_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.default_font_size = 27
	theme = ui_theme
	stage = Control.new()
	stage.name = "OriginalArtworkStage"
	stage.size = DESIGN_SIZE
	add_child(stage)
	var background := TextureRect.new()
	background.texture = preload("res://assets/background.jpg")
	background.size = DESIGN_SIZE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(background)
	_build_dialogue()
	game_selected.connect(_open_match)
	resized.connect(_fit_stage)
	_fit_stage()
	buttons[0].grab_focus()
	if "--teach" in OS.get_cmdline_user_args(): call_deferred("_open_teaching")
	if "--story-preview" in OS.get_cmdline_user_args(): call_deferred("_preview_story")

func _fit_stage() -> void:
	var ratio: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	stage.scale = Vector2.ONE * ratio
	stage.position = (size - DESIGN_SIZE * ratio) / 2.0

func _panel_style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(9)
	style.set_border_width_all(2)
	style.border_color = border
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style

func _button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(220, 65)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", Color("eeeeee"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(Color("424242"), Color("a3a3a3")))
	button.add_theme_stylebox_override("hover", _panel_style(Color("5b5b5b"), Color("eeeeee")))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("282828"), Color.WHITE))
	button.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, Color.WHITE))
	return button

func _build_dialogue() -> void:
	var panel := PanelContainer.new()
	panel.name = "DialogueOverlay"
	panel.position = Vector2(455, 115)
	panel.size = Vector2(870, 260)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.18, 0.18, 0.18, 0.96)))
	stage.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	margin.add_child(column)
	var speaker := Label.new()
	speaker.text = "老棋友"
	speaker.add_theme_color_override("font_color", Color("bdbdbd"))
	var heading := HBoxContainer.new()
	speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(speaker)
	role_choice = OptionButton.new()
	role_choice.add_item("角色 A")
	role_choice.add_item("角色 B")
	role_choice.select(0 if Memory.role == "A" else 1)
	role_choice.add_theme_font_size_override("font_size", 21)
	role_choice.item_selected.connect(func(index: int):
		Memory.role = "A" if index == 0 else "B"
		dialogue.text = "%s，来坐。另一位教过的棋也记在棋谱里。\n想下一局，还是教我点新的？" % Memory.role
	)
	heading.add_child(role_choice)
	var teach_button := Button.new()
	teach_button.text = "教棋 / 共享棋谱"
	teach_button.add_theme_font_size_override("font_size", 21)
	teach_button.pressed.connect(_open_teaching)
	heading.add_child(teach_button)
	var chat_button := Button.new()
	chat_button.text = "聊两句"
	chat_button.add_theme_font_size_override("font_size", 22)
	chat_button.pressed.connect(_chat)
	heading.add_child(chat_button)
	column.add_child(heading)
	dialogue = Label.new()
	dialogue.text = Text.GREETINGS[0]
	dialogue.add_theme_font_size_override("font_size", 26)
	dialogue.add_theme_color_override("font_color", Color("f2f2f2"))
	dialogue.custom_minimum_size.y = 78
	column.add_child(dialogue)
	choices = HBoxContainer.new()
	choices.add_theme_constant_override("separation", 22)
	column.add_child(choices)
	for index in range(GAMES.size()):
		var button := _button("%d. %s" % [index + 1, GAMES[index]["title"]])
		button.pressed.connect(_select_game.bind(index))
		choices.add_child(button)
		buttons.append(button)
	back_button = _button("重新选择")
	back_button.pressed.connect(_reset_selection)
	back_button.hide()
	column.add_child(back_button)

func _select_game(index: int) -> void:
	if index < 0 or index >= GAMES.size():
		return
	selected_game = GAMES[index]["id"]
	setup_view = preload("res://scripts/rules_panel.gd").new()
	setup_view.configure(selected_game, true, selected_go_size)
	setup_view.closed.connect(_cancel_setup)
	setup_view.start_requested.connect(_start_match)
	stage.add_child(setup_view)

func _chat() -> void:
	greeting_index = (greeting_index + 1) % Text.GREETINGS.size()
	dialogue.text = Text.GREETINGS[greeting_index]

func _cancel_setup() -> void:
	if is_instance_valid(setup_view): setup_view.queue_free()
	setup_view = null
	_reset_selection()

func _start_match(go_size: int) -> void:
	selected_go_size = go_size
	if is_instance_valid(setup_view): setup_view.queue_free()
	setup_view = null
	game_selected.emit(selected_game)

func _reset_selection() -> void:
	selected_game = &""
	dialogue.text = "回来啦。想再下一局，还是换种棋试试？\n选围棋的话，也可以换一张更大的棋盘。"
	back_button.hide()
	choices.show()
	buttons[0].grab_focus()

func _open_match(id: StringName) -> void:
	stage.get_node("DialogueOverlay").hide()
	match_view = preload("res://scripts/match.gd").new()
	match_view.setup(id, selected_go_size)
	match_view.return_requested.connect(_close_match)
	match_view.match_finished.connect(_on_finished)
	stage.add_child(match_view)

func _close_match() -> void:
	if is_instance_valid(match_view):
		match_view.queue_free()
	match_view = null
	stage.get_node("DialogueOverlay").show()
	_reset_selection()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(teaching_view) or is_instance_valid(story_view): return
	if is_instance_valid(match_view): return
	if is_instance_valid(setup_view): return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_reset_selection()
		get_viewport().set_input_as_handled()
	elif selected_game == &"" and event.keycode >= KEY_1 and event.keycode <= KEY_3:
		_select_game(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()

func _open_teaching() -> void:
	if is_instance_valid(teaching_view): return
	stage.get_node("DialogueOverlay").hide()
	teaching_view = preload("res://scripts/teaching_room.gd").new()
	teaching_view.closed.connect(_close_teaching)
	teaching_view.play_requested.connect(_play_learned)
	stage.add_child(teaching_view)

func _close_teaching() -> void:
	if is_instance_valid(teaching_view): teaching_view.queue_free()
	teaching_view = null
	stage.get_node("DialogueOverlay").show()
	_reset_selection()

func _play_learned(profile: Dictionary) -> void:
	if is_instance_valid(teaching_view): teaching_view.hide()
	match_view = preload("res://scripts/learned_match.gd").new()
	match_view.setup(profile)
	match_view.return_requested.connect(func():
		match_view.queue_free()
		match_view = null
		if is_instance_valid(teaching_view): teaching_view.show()
	)
	match_view.match_finished.connect(_on_finished)
	stage.add_child(match_view)

func _on_finished(_result: String) -> void:
	call_deferred("_show_story")

func _show_story() -> void:
	if is_instance_valid(story_view): return
	story_view = preload("res://scripts/elder_story.gd").new()
	story_view.closed.connect(_close_story)
	story_view.teach_requested.connect(func():
		_close_story()
		if is_instance_valid(match_view):
			match_view.queue_free()
			match_view = null
		if is_instance_valid(teaching_view): teaching_view.show()
		else: _open_teaching()
	)
	stage.add_child(story_view)

func _preview_story() -> void:
	if is_instance_valid(story_view): return
	story_view = preload("res://scripts/elder_story.gd").new()
	story_view.preview_mode = true
	story_view.closed.connect(_close_story)
	stage.add_child(story_view)

func _close_story() -> void:
	if is_instance_valid(story_view): story_view.queue_free()
	story_view = null
