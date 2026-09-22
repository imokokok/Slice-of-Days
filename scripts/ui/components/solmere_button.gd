extends Button
## Shared native states; variants express the reference without duplicating behavior.
var variant := "quiet"
var feedback_tween: Tween
var selected := false:
	set(value):
		selected=value
		if is_inside_tree(): refresh()
func _ready() -> void:
	focus_mode=FOCUS_ALL
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	refresh()
	if toggle_mode:
		selected=button_pressed
		toggled.connect(func(value: bool) -> void: selected=value)
	for signal_name in ["mouse_entered","mouse_exited","focus_entered","focus_exited","button_down","button_up"]:
		connect(signal_name,queue_redraw)
	mouse_entered.connect(_feedback.bind(true)); mouse_exited.connect(_feedback.bind(false))
	focus_entered.connect(_feedback.bind(true)); focus_exited.connect(_feedback.bind(false))

func _feedback(active: bool) -> void:
	if disabled: return
	if feedback_tween: feedback_tween.kill()
	feedback_tween=create_tween()
	feedback_tween.tween_property(self,"self_modulate",Color.WHITE if active else Color(.94,.96,.98),.01 if SettingsSystem.reduced_motion() else .14)
func refresh() -> void:
	var dark := variant in ["choice","pause","camera","guidance"]
	for state in ["normal","hover","pressed","focus","disabled"]:
		var face := StyleBoxFlat.new()
		face.set_corner_radius_all(10 if variant=="choice" else 7)
		face.set_content_margin_all(10)
		face.bg_color=Color.TRANSPARENT
		if variant=="choice": face.bg_color=Color("2f5579")
		elif variant=="guidance": face.bg_color=Color("254b66")
		elif variant=="archive": face.bg_color=Color("e3dcc8",.46)
		elif variant=="goods": face.bg_color=Color("e1ebea",.65)
		elif variant=="tab": face.bg_color=Color("254b66")
		elif variant=="paper": face.bg_color=PaperLanguage.WHITE
		elif variant=="outlined": face.set_border_width_all(1); face.border_color=Color("9d9988",.36)
		if state in ["hover","pressed"] or (state=="normal" and selected): face.bg_color=Color("f0d982",1.0 if state=="pressed" else .86 if selected else .38)
		if variant=="choice" and (state in ["hover","pressed"] or selected): face.bg_color=Color("eed577")
		if variant=="guidance" and (state in ["hover","pressed"] or selected): face.bg_color=Color("eed577")
		if variant=="tab" and (state in ["hover","pressed"] or selected): face.bg_color=Color("eed577")
		if state=="focus":
			face.bg_color=Color.TRANSPARENT; face.set_border_width_all(2); face.border_color=PaperLanguage.YELLOW if dark else PaperLanguage.BLUE
		if state=="disabled": face.bg_color=Color("73828a",.07)
		if state=="disabled" and variant in ["choice","guidance"]: face.bg_color=Color("dce4e6")
		add_theme_stylebox_override(state,face)
	add_theme_color_override("font_color",PaperLanguage.WHITE if (dark or variant=="tab") and not selected else PaperLanguage.BLUE)
	add_theme_color_override("font_hover_color",PaperLanguage.BLUE)
	add_theme_color_override("font_pressed_color",PaperLanguage.BLUE)
	add_theme_color_override("font_focus_color",PaperLanguage.WHITE if (dark or variant=="tab") and not selected else PaperLanguage.BLUE)
	add_theme_color_override("font_disabled_color",Color("798c93",.5))
	add_theme_font_override("font",PaperLanguage.body_font)
	if not has_theme_font_size_override("font_size"): add_theme_font_size_override("font_size",20)
func _draw() -> void:
	if variant=="pause":
		draw_line(Vector2(20,size.y-1),Vector2(size.x-20,size.y-1),Color("ffffff",.15),1)
		if has_focus() or is_hovered(): draw_line(Vector2(0,8),Vector2(0,size.y-8),PaperLanguage.YELLOW,4,true)
