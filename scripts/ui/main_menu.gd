extends Control

const MENU_BACKGROUND := preload("res://art/ui/title-screen-background.png")

const PAPER := Color("fff8eb")
const PAPER_SOFT := Color("f1dfc7")
const INK := Color("4a342b")
const MUTED := Color("806b5c")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")
const SAGE := Color("7d8f59")
const LINE := Color("b88963")

var modal_overlay: ColorRect
var modal_panel: Panel


func _ready() -> void:
	_build_menu()
	_build_modal_shell()
	var args := OS.get_cmdline_user_args()
	if args.has("--capture-menu-role"):
		_show_role_selection()
		_capture.call_deferred("main-menu-role.png")
	elif args.has("--capture-menu"):
		_capture.call_deferred("main-menu.png")


func _draw() -> void:
	var sx := size.x / 1600.0
	var sy := size.y / 900.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
	draw_rect(Rect2(0, 0, 1600, 900), PAPER)
	draw_texture_rect(MENU_BACKGROUND, Rect2(0, 0, 1600, 900), false)
	draw_rect(Rect2(0, 0, 570, 900), Color("f9efd9", 0.20))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_menu() -> void:
	var title := _make_label(self, "第七日\n之前", Vector2(86, 66), Vector2(390, 170), 62, PAPER)
	title.add_theme_color_override("font_shadow_color", Color(INK, 0.42))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("line_spacing", -10)

	var subtitle := _make_label(self, "BEFORE THE SEVENTH DAY", Vector2(92, 224), Vector2(360, 26), 15, Color(PAPER, 0.92))
	subtitle.add_theme_color_override("font_shadow_color", Color(INK, 0.35))
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)

	var continue_button := _make_button(self, "继续游戏", Vector2(92, 310), Vector2(260, 52), "regular")
	var new_game := _make_button(self, "开始新游戏", Vector2(92, 376), Vector2(260, 52), "primary")
	var settings := _make_button(self, "设置", Vector2(92, 442), Vector2(260, 52), "regular")
	var credits := _make_button(self, "制作人员", Vector2(92, 508), Vector2(260, 52), "regular")
	var quit := _make_button(self, "退出", Vector2(92, 574), Vector2(260, 52), "regular")

	continue_button.disabled = not SaveManager.has_save()
	continue_button.pressed.connect(_continue_game)
	new_game.pressed.connect(_on_new_game_pressed)
	settings.pressed.connect(_show_settings)
	credits.pressed.connect(_show_credits)
	quit.pressed.connect(_show_quit_confirmation)

	var hint := "还没有保存的旅程" if continue_button.disabled else "上次的旅程正在等你"
	_make_label(self, hint, Vector2(94, 646), Vector2(300, 24), 13, Color(PAPER, 0.92))
	_make_label(self, "七天 · 两种时间 · 一座慢慢认识你的海边小镇", Vector2(92, 814), Vector2(520, 28), 14, Color(PAPER, 0.90))


func _build_modal_shell() -> void:
	modal_overlay = ColorRect.new()
	modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_overlay.color = Color(INK, 0.36)
	modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal_overlay)

	modal_panel = Panel.new()
	modal_panel.position = Vector2(505, 275)
	modal_panel.size = Vector2(590, 350)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PAPER, 0.96)
	style.border_color = Color(LINE, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(INK, 0.30)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	modal_panel.add_theme_stylebox_override("panel", style)
	modal_overlay.add_child(modal_panel)
	modal_overlay.visible = false


func _on_new_game_pressed() -> void:
	if SaveManager.has_save():
		_show_overwrite_confirmation()
	else:
		_show_role_selection()


func _show_overwrite_confirmation() -> void:
	_prepare_modal()
	_make_label(modal_panel, "开启新的旅程？", Vector2(34, 30), Vector2(522, 42), 27, INK)
	var body := _make_label(modal_panel, "开始新游戏后，之后的自动保存会覆盖现有进度。\n你确定要继续吗？", Vector2(34, 91), Vector2(522, 82), 17, MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var yes := _make_button(modal_panel, "继续", Vector2(92, 224), Vector2(190, 52), "primary")
	var no := _make_button(modal_panel, "取消", Vector2(308, 224), Vector2(190, 52), "regular")
	yes.pressed.connect(_show_role_selection)
	no.pressed.connect(_hide_modal)


func _show_role_selection() -> void:
	_prepare_modal()
	_make_label(modal_panel, "选择你的时间方式", Vector2(34, 28), Vector2(522, 42), 27, INK)
	var body := _make_label(modal_panel, "同一座小镇，两种不同的抵达方式。", Vector2(34, 78), Vector2(522, 34), 16, MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var a := _make_button(modal_panel, "A · 连续的一天", Vector2(54, 143), Vector2(226, 76), "primary")
	var b := _make_button(modal_panel, "B · 碎片的一天", Vector2(310, 143), Vector2(226, 76), "teal")
	var cancel := _make_button(modal_panel, "返回", Vector2(200, 254), Vector2(190, 46), "regular")
	a.tooltip_text = "先行动，再从结果调整"
	b.tooltip_text = "先确认时间、路线和费用"
	a.pressed.connect(_start_role.bind("A"))
	b.pressed.connect(_start_role.bind("B"))
	cancel.pressed.connect(_hide_modal)


func _show_settings() -> void:
	_prepare_modal()
	_make_label(modal_panel, "设置", Vector2(34, 28), Vector2(522, 42), 27, INK)
	_make_label(modal_panel, "显示模式", Vector2(34, 92), Vector2(160, 30), 16, MUTED)
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var display_text := "切换为窗口模式" if fullscreen else "切换为全屏模式"
	var display_button := _make_button(modal_panel, display_text, Vector2(210, 82), Vector2(300, 52), "teal")
	display_button.pressed.connect(_toggle_fullscreen)
	_make_label(modal_panel, "声音与语言选项将在后续版本加入。", Vector2(34, 164), Vector2(522, 32), 15, MUTED)
	var close := _make_button(modal_panel, "完成", Vector2(200, 254), Vector2(190, 46), "primary")
	close.pressed.connect(_hide_modal)


func _show_credits() -> void:
	_prepare_modal()
	_make_label(modal_panel, "制作人员", Vector2(34, 28), Vector2(522, 42), 27, INK)
	_make_label(modal_panel, "WHAT 100 PEOPLE DO TO A GAME\n\n策划、叙事与开发：100game 创作团队\n美术方向：温暖海边小镇手绘风格", Vector2(34, 88), Vector2(522, 130), 16, MUTED)
	var close := _make_button(modal_panel, "返回", Vector2(200, 254), Vector2(190, 46), "primary")
	close.pressed.connect(_hide_modal)


func _show_quit_confirmation() -> void:
	_prepare_modal()
	_make_label(modal_panel, "要离开小镇吗？", Vector2(34, 36), Vector2(522, 42), 27, INK)
	_make_label(modal_panel, "已保存的旅程不会丢失。", Vector2(34, 98), Vector2(522, 34), 16, MUTED)
	var yes := _make_button(modal_panel, "退出游戏", Vector2(92, 224), Vector2(190, 52), "danger")
	var no := _make_button(modal_panel, "再待一会", Vector2(308, 224), Vector2(190, 52), "regular")
	yes.pressed.connect(get_tree().quit)
	no.pressed.connect(_hide_modal)


func _prepare_modal() -> void:
	for child in modal_panel.get_children():
		modal_panel.remove_child(child)
		child.queue_free()
	modal_overlay.visible = true


func _hide_modal() -> void:
	modal_overlay.visible = false


func _toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_show_settings()


func _start_role(role: String) -> void:
	GameState.begin_vertical_slice(role)
	SceneRouter.town_day()


func _continue_game() -> void:
	if SaveManager.load_game():
		SceneRouter.town_day()


func _unhandled_input(event: InputEvent) -> void:
	if modal_overlay.visible and event.is_action_pressed("ui_cancel"):
		_hide_modal()
		get_viewport().set_input_as_handled()


func _make_label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
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
	button.add_theme_font_size_override("font_size", 17)

	var base := Color(PAPER, 0.78)
	var edge := Color(LINE, 0.74)
	var font_color := INK
	match kind:
		"primary":
			base = Color(TERRACOTTA, 0.92)
			edge = TERRACOTTA.darkened(0.12)
			font_color = PAPER
		"teal":
			base = Color(TEAL, 0.90)
			edge = TEAL.darkened(0.12)
			font_color = PAPER
		"danger":
			base = Color("e9b6a4", 0.96)
			edge = TERRACOTTA

	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.border_color = edge
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(13)
	normal.shadow_color = Color(INK, 0.20)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 4)
	var hover := normal.duplicate()
	hover.bg_color = base.lightened(0.10)
	hover.border_color = edge.lightened(0.10)
	var pressed := normal.duplicate()
	pressed.bg_color = base.darkened(0.08)
	pressed.shadow_size = 2
	var disabled := normal.duplicate()
	disabled.bg_color = Color(PAPER_SOFT, 0.58)
	disabled.border_color = Color(LINE, 0.35)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.55))
	parent.add_child(button)
	return button


func _capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/%s" % filename))
	get_tree().quit()
