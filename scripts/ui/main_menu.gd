extends Control

const INK := Color("07090f")
const BONE := Color("d8d0bd")
const MUTED := Color("819092")
const AMBER := Color("d98a39")
const CYAN := Color("58abb2")


func _ready() -> void:
	_build_ui()
	if OS.get_cmdline_user_args().has("--capture-menu"):
		_capture.call_deferred()


func _draw() -> void:
	var sx := size.x / 1600.0
	var sy := size.y / 900.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
	draw_rect(Rect2(0, 0, 1600, 900), INK)
	# Seven days form a road across an otherwise empty stage.
	var road := PackedVector2Array([
		Vector2(0, 705), Vector2(260, 630), Vector2(470, 665), Vector2(700, 565),
		Vector2(930, 600), Vector2(1180, 510), Vector2(1600, 550), Vector2(1600, 690),
		Vector2(1190, 650), Vector2(940, 730), Vector2(710, 680), Vector2(480, 770),
		Vector2(270, 735), Vector2(0, 820)
	])
	draw_colored_polygon(road, Color("151d2b"))
	for index in 7:
		var x := 150.0 + index * 210.0
		var color := AMBER if index == 0 else Color("273849")
		draw_circle(Vector2(x, 680.0 - sin(index * 0.8) * 60.0), 8.0, color)
	# Incomplete town planes.
	draw_colored_polygon(PackedVector2Array([Vector2(980, 170), Vector2(1180, 110), Vector2(1160, 475), Vector2(930, 505)]), Color("101d28"))
	draw_colored_polygon(PackedVector2Array([Vector2(1210, 235), Vector2(1445, 175), Vector2(1480, 500), Vector2(1228, 477)]), Color("261922"))
	draw_line(Vector2(0, 530), Vector2(1600, 470), Color(0.65, 0.2, 0.22, 0.35), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_ui() -> void:
	_make_label("WHAT 100 PEOPLE DO TO A GAME", Vector2(85, 105), Vector2(900, 58), 38, BONE)
	_make_label("七天 · 两种时间 · 一座只在被理解时亮起的小镇", Vector2(88, 170), Vector2(750, 32), 17, MUTED)
	_make_label("垂直切片  01", Vector2(90, 250), Vector2(300, 25), 14, AMBER)

	var a := _make_button("从 A 的一天开始", Vector2(88, 300), Vector2(320, 58), AMBER)
	var b := _make_button("从 B 的一天开始", Vector2(88, 373), Vector2(320, 58), CYAN)
	var tarot := _make_button("打开牌桌推理原型", Vector2(88, 470), Vector2(320, 50), Color("7d445c"))
	var continue_button := _make_button("继续上次进度", Vector2(88, 535), Vector2(320, 50), Color("394852"))
	continue_button.disabled = not SaveManager.has_save()

	a.pressed.connect(_start_role.bind("A"))
	b.pressed.connect(_start_role.bind("B"))
	tarot.pressed.connect(SceneRouter.tarot_table)
	continue_button.pressed.connect(_continue_game)

	_make_label("A 先行动，再从结果调整。", Vector2(445, 311), Vector2(390, 30), 15, BONE.darkened(0.08))
	_make_label("B 先确认时间、路线和费用。", Vector2(445, 384), Vector2(390, 30), 15, BONE.darkened(0.08))
	_make_label("当前目标：在同一天找到夏透明，并获得一份居民确认。", Vector2(90, 805), Vector2(720, 30), 15, MUTED)


func _start_role(role: String) -> void:
	GameState.begin_vertical_slice(role)
	SceneRouter.town_day()


func _continue_game() -> void:
	if SaveManager.load_game():
		SceneRouter.town_day()


func _make_label(text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _make_button(text_value: String, at: Vector2, button_size: Vector2, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.18)
	style.border_color = Color(accent, 0.8)
	style.set_border_width_all(1)
	var hover := style.duplicate()
	hover.bg_color = Color(accent, 0.32)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", BONE)
	add_child(button)
	return button


func _capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/main-menu.png"))
	get_tree().quit()

