extends Control

const PAPER := Color("fff8eb")
const PAPER_SOFT := Color("f1dfc7")
const INK := Color("4a342b")
const MUTED := Color("806b5c")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")
const SAGE := Color("7d8f59")
const LINE := Color("b88963")
const COVER_BLUE := Color("3f78a4")
const NAVIGATION_TITLES := {
	"NewGame": "新游戏",
	"Chapters": "章节",
	"Settings": "设置",
}

var modal_overlay: ColorRect
var modal_panel: Panel
var pending_slot := 1
var entering := false
var navigation: Control
var navigation_ready := false
var intro_video: VideoStreamPlayer
var intro_wash: ColorRect
var intro_background: ColorRect


func _ready() -> void:
	WorldSound.set_active(false)
	SettingsSystem.language_changed.connect(_refresh_navigation_language)
	_build_living_cover()
	_build_navigation()
	_build_modal_shell()
	if OS.get_cmdline_user_args().has("--fresh-preview"):
		_on_new_game_pressed()
	elif OS.get_cmdline_user_args().has("--live-preview"):
		if SaveManager.load_latest(): SceneRouter.town_day()
		else: _on_new_game_pressed()


func _draw() -> void:
	var sx := size.x / 1600.0
	var sy := size.y / 900.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))
	draw_rect(Rect2(0, 0, 1600, 900), COVER_BLUE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_living_cover() -> void:
	var blue := ColorRect.new()
	blue.color = COVER_BLUE
	blue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(blue)
	var title := Label.new()
	title.text = "Solmere"
	title.position = Vector2(0, 165)
	title.size = Vector2(1600, 150)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Segoe Print", "Bradley Hand ITC", "Comic Sans MS", "Microsoft YaHei UI"])
	title_font.font_weight = 300
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

func _process(_delta: float) -> void:
	if is_instance_valid(intro_video):
		var ending := smoothstep(10.9,11.75,intro_video.stream_position)
		if ending > 0:
			intro_wash.color.a = ending
			intro_video.volume_db = linear_to_db(maxf(.0001,1.0-ending))
		return
	if entering: return
	if not navigation_ready:
		navigation_ready = true
		navigation.modulate.a = 1.0
		for child in navigation.get_children():
			if child is Button:
				child.disabled = false
				child.focus_mode = Control.FOCUS_NONE

func _build_navigation() -> void:
	navigation = Control.new()
	navigation.position = Vector2(635,545)
	navigation.size = Vector2(330,182)
	navigation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(navigation)
	for y in [0,180]:
		var rule := ColorRect.new()
		rule.position = Vector2(0,y)
		rule.size = Vector2(330,1)
		rule.color = Color(1,1,1,.88)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		navigation.add_child(rule)
	var titles := ["新游戏","章节","设置"]
	var actions := [_launch_new_game,_show_chapters,_show_settings]
	var menu_font := SystemFont.new()
	menu_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "Arial", "sans-serif"])
	menu_font.font_weight = 300
	for i in titles.size():
		var button := Button.new()
		button.name = ["NewGame","Chapters","Settings"][i]
		button.text = LocalizationSystem.text(titles[i])
		button.position = Vector2(40,24+i*44)
		button.size = Vector2(250,40)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.disabled = true
		button.focus_mode = Control.FOCUS_NONE
		button.flat = true
		button.add_theme_font_size_override("font_size",23)
		button.add_theme_font_override("font",menu_font)
		button.add_theme_constant_override("outline_size",0)
		for state in ["normal","hover","pressed","focus","disabled","hover_pressed"]:
			button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		button.add_theme_color_override("font_color",Color.WHITE)
		button.add_theme_color_override("font_hover_color",Color("fffdf6"))
		button.add_theme_color_override("font_focus_color",Color("fffdf6"))
		button.add_theme_color_override("font_pressed_color",Color("f4dfb0"))
		button.add_theme_color_override("font_shadow_color",Color("183e4e",.8))
		button.add_theme_constant_override("shadow_offset_y",1)
		navigation.add_child(button)
		button.pressed.connect(actions[i])
	navigation.modulate.a = 1


func _refresh_navigation_language(_locale := "") -> void:
	if not is_instance_valid(navigation):
		return
	for button_name in NAVIGATION_TITLES:
		var button := navigation.get_node_or_null(button_name) as Button
		if button != null:
			button.text = LocalizationSystem.text(NAVIGATION_TITLES[button_name])

func _launch_new_game() -> void:
	if entering: return
	entering = true
	intro_wash = ColorRect.new()
	intro_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_wash.color = Color(1,1,1,0)
	intro_wash.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(intro_wash)
	var fade := create_tween().set_parallel(true)
	fade.tween_property(navigation,"modulate:a",0.0,.4)
	fade.tween_property(intro_wash,"color:a",1.0,.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade.finished
	navigation.hide()
	WorldSound.set_active(false)
	await _play_opening_animation()
	_on_new_game_pressed()
	if not SceneRouter.transitioning:
		entering = false
		intro_background.queue_free()
		intro_video = null
		intro_wash.queue_free()
		navigation.show()
		navigation.modulate.a = 1.0

func _play_opening_animation() -> void:
	# The encoded stream contains only the newly authored sound design.
	intro_background = ColorRect.new()
	intro_background.color = Color.WHITE
	intro_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(intro_background)
	intro_video = VideoStreamPlayer.new()
	intro_video.name = "OpeningAnimation"
	intro_video.stream = preload("res://art/ui/new-game-intro.ogv")
	intro_video.bus = "Music"
	intro_video.expand = true
	intro_video.loop = false
	intro_video.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_background.add_child(intro_video)
	_layout_opening_animation()
	resized.connect(_layout_opening_animation)
	move_child(intro_wash,get_child_count()-1)
	intro_video.volume_db = -60.0
	intro_video.play()
	await RenderingServer.frame_post_draw
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(intro_wash,"color:a",0.0,.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal.tween_property(intro_video,"volume_db",0.0,.85)
	# Some platform decoders can leave VideoStreamPlayer playing without emitting
	# `finished`. Never strand a new journey on the opening film: wait for normal
	# completion, with a wall-clock fallback slightly beyond the encoded length.
	var deadline_msec := Time.get_ticks_msec() + int((intro_video.get_stream_length() + 2.0) * 1000.0)
	while is_instance_valid(intro_video) and intro_video.is_playing() and Time.get_ticks_msec() < deadline_msec:
		await get_tree().process_frame
	if is_instance_valid(intro_video): intro_video.stop()
	intro_wash.color.a = 1.0
	await get_tree().create_timer(.15).timeout

func _layout_opening_animation() -> void:
	if not is_instance_valid(intro_video): return
	var frame_width := minf(size.x*.8,size.y*.8*16.0/9.0)
	intro_video.size = Vector2(frame_width,frame_width*9.0/16.0)
	intro_video.position = (size-intro_video.size)*.5

func _show_chapters() -> void:
	_prepare_modal()
	modal_panel.size.y = 610
	_make_label(modal_panel,"章节",Vector2(34,24),Vector2(522,42),27,INK)
	_make_label(modal_panel,"从已保存的章节继续",Vector2(34,72),Vector2(522,30),16,MUTED)
	var saved_days: Dictionary = {}
	for slot in range(1,SaveManager.SLOT_COUNT+1):
		var summary := SaveManager.slot_summary(slot)
		if not summary.get("exists",false): continue
		var key := "%s_%d" % [str(summary.get("role","A")),int(summary.day)]
		if not saved_days.has(key) or int(summary.modified)>int(saved_days[key].modified): saved_days[key]=summary
	for day in range(1,8):
		for role in ["A","B"]:
			var key := "%s_%d" % [role,day]
			var available := saved_days.has(key)
			var button := _make_button(modal_panel,"%s · 第 %d 天%s" % [role,day,"" if available else " · —"],Vector2(44 if role=="A" else 304,115+(day-1)*53),Vector2(244,44),"regular")
			button.disabled = not available
			if available: button.pressed.connect(_resume_chapter.bind(int(saved_days[key].slot)))
	var close := _make_button(modal_panel,"返回",Vector2(200,530),Vector2(190,46),"primary")
	close.pressed.connect(_hide_modal)

func _resume_chapter(slot: int) -> void:
	if SaveManager.load_slot(slot): SceneRouter.town_day()

func _build_modal_shell() -> void:
	modal_overlay = ColorRect.new()
	modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_overlay.color = Color(INK, 0.36)
	modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal_overlay)

	modal_panel = Panel.new()
	modal_panel.position = Vector2(505, 210)
	modal_panel.size = Vector2(590, 480)
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
	# Allocate automatically; preserve older journeys without showing empty slot UI.
	if not SaveManager.prepare_new_journey(): return
	ChapterSystem.start_new_game()
	if not SaveManager.save_or_report("新旅程保存失败"):
		return
	SceneRouter.town_day(.75)


func _show_settings() -> void:
	_prepare_modal()
	modal_panel.position = Vector2(505, 75)
	modal_panel.size.y = 750
	_make_label(modal_panel, "设置", Vector2(34, 20), Vector2(522, 42), 27, INK)
	_make_label(modal_panel, "语言", Vector2(34, 72), Vector2(160, 30), 16, MUTED)
	var language_picker := OptionButton.new()
	language_picker.position = Vector2(210, 62)
	language_picker.size = Vector2(300, 44)
	language_picker.add_item(LocalizationSystem.text("简体中文"))
	language_picker.set_item_metadata(0, "zh_CN")
	language_picker.add_item("English")
	language_picker.set_item_metadata(1, "en")
	language_picker.select(0 if SettingsSystem.language() == "zh_CN" else 1)
	language_picker.add_theme_font_size_override("font_size", 17)
	modal_panel.add_child(language_picker)
	language_picker.item_selected.connect(func(index: int) -> void:
		SettingsSystem.set_language(str(language_picker.get_item_metadata(index)))
		_show_settings()
	)

	_make_label(modal_panel, "显示模式", Vector2(34, 128), Vector2(160, 30), 16, MUTED)
	var display_text := "切换为窗口模式" if SettingsSystem.fullscreen() else "切换为全屏模式"
	var display_button := _make_button(modal_panel, display_text, Vector2(210, 114), Vector2(300, 44), "teal")
	display_button.pressed.connect(_toggle_fullscreen)
	_add_settings_volume_slider("主音量", 182, SettingsSystem.master_volume(), SettingsSystem.set_master_volume)
	_add_settings_volume_slider("音乐音量", 230, SettingsSystem.music_volume(), SettingsSystem.set_music_volume)
	_add_settings_volume_slider("音效音量", 278, SettingsSystem.sound_effects_volume(), SettingsSystem.set_sound_effects_volume)
	var mute_text := "取消静音" if SettingsSystem.is_audio_muted() else "全部静音"
	var mute := _make_button(modal_panel, mute_text, Vector2(210, 316), Vector2(300, 40), "regular")
	mute.pressed.connect(func() -> void:
		SettingsSystem.set_audio_muted(not SettingsSystem.is_audio_muted())
		_show_settings())

	_make_label(modal_panel, "减少动态效果", Vector2(34, 384), Vector2(160, 30), 16, MUTED)
	var motion_text := "已开启" if SettingsSystem.reduced_motion() else "未开启"
	var motion := _make_button(modal_panel, motion_text, Vector2(210, 370), Vector2(300, 44), "regular")
	motion.pressed.connect(_toggle_reduced_motion)
	var hint := _make_label(modal_panel, "减少章节转场中的画面位移；不会跳过任何内容。", Vector2(34, 424), Vector2(522, 42), 14, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_make_label(modal_panel,"心声字号",Vector2(34,478),Vector2(160,30),16,MUTED)
	var voice_size := HSlider.new()
	voice_size.position = Vector2(210,472)
	voice_size.size = Vector2(300,38)
	voice_size.min_value = 17
	voice_size.max_value = 30
	voice_size.step = 1
	voice_size.value = SettingsSystem.values.get("voice_size",21)
	modal_panel.add_child(voice_size)
	voice_size.value_changed.connect(func(value: float) -> void:
		SettingsSystem.values.voice_size = int(value)
		SettingsSystem.save_settings())
	_make_label(modal_panel,"心声透明度",Vector2(34,532),Vector2(160,30),16,MUTED)
	var opacity := HSlider.new()
	opacity.position = Vector2(210,526)
	opacity.size = Vector2(300,38)
	opacity.min_value = 0
	opacity.max_value = 1
	opacity.step = .05
	opacity.value = SettingsSystem.values.get("voice_opacity",.86)
	modal_panel.add_child(opacity)
	opacity.value_changed.connect(func(value: float) -> void:
		SettingsSystem.values.voice_opacity = value
		SettingsSystem.save_settings())
	var close := _make_button(modal_panel, "完成", Vector2(200, 666), Vector2(190, 46), "primary")
	close.pressed.connect(_hide_modal)


func _add_settings_volume_slider(title: String, y: float, value: int, setter: Callable) -> void:
	_make_label(modal_panel, title, Vector2(34, y), Vector2(160, 30), 16, MUTED)
	var slider := HSlider.new()
	slider.position = Vector2(210, y - 9)
	slider.size = Vector2(275, 38)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value
	slider.tooltip_text = LocalizationSystem.text("%s，0 到 100" % title)
	modal_panel.add_child(slider)
	var value_label := _make_label(modal_panel, "%d%%" % value, Vector2(500, y), Vector2(54, 28), 14, MUTED)
	slider.value_changed.connect(func(changed_value: float) -> void:
		setter.call(changed_value)
		value_label.text = "%d%%" % int(round(changed_value)))


func _show_credits() -> void:
	_prepare_modal()
	_make_label(modal_panel, "制作人员", Vector2(34, 28), Vector2(522, 42), 27, INK)
	_make_label(modal_panel, "SOLMERE\n\n策划、叙事与开发：Solmere 创作团队\n美术方向：温暖海边小镇手绘风格", Vector2(34, 88), Vector2(522, 130), 16, MUTED)
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
	modal_panel.position = Vector2(505, 210)
	modal_panel.size = Vector2(590,480)
	for child in modal_panel.get_children():
		modal_panel.remove_child(child)
		child.queue_free()
	modal_overlay.visible = true


func _hide_modal() -> void:
	modal_overlay.visible = false


func _toggle_fullscreen() -> void:
	SettingsSystem.set_fullscreen(not SettingsSystem.fullscreen())
	_show_settings()


func _toggle_reduced_motion() -> void:
	SettingsSystem.set_reduced_motion(not SettingsSystem.reduced_motion())
	_show_settings()








func _unhandled_input(event: InputEvent) -> void:
	if modal_overlay.visible and event.is_action_pressed("ui_cancel"):
		_hide_modal()
		get_viewport().set_input_as_handled()


func _make_label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = LocalizationSystem.text(text_value)
	label.position = at
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, kind: String) -> Button:
	var button := Button.new()
	button.text = LocalizationSystem.text(text_value)
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

func _continue_latest() -> void:
	if SaveManager.load_latest():
		SceneRouter.town_day()

func _preview_role(role: String) -> void:
	GameState.begin_vertical_slice(role)
	SceneRouter.enter_space("home_a" if role == "A" else "home_b")
