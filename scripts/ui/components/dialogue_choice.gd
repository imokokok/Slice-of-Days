extends Button
## A typographic reply, with native keyboard/controller focus and no fake hotspot.
var selected := false:
	set(value):
		selected=value
		if is_inside_tree(): _refresh()
var feedback: Tween

func _ready() -> void:
	add_to_group("scene_speech")
	focus_mode=FOCUS_ALL
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	alignment=HORIZONTAL_ALIGNMENT_LEFT
	autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_override("font",PaperLanguage.body_font)
	add_theme_font_size_override("font_size",19)
	_refresh()
	for signal_name in ["mouse_entered","mouse_exited","focus_entered","focus_exited","button_down","button_up"]:
		connect(signal_name,_feedback)

func _refresh() -> void:
	for state in ["normal","hover","pressed","focus","disabled"]:
		var face := StyleBoxFlat.new()
		face.set_corner_radius_all(3)
		face.content_margin_left=25; face.content_margin_right=12
		face.content_margin_top=10; face.content_margin_bottom=10
		face.bg_color=Color.TRANSPARENT
		if state=="hover" or (state=="normal" and selected): face.bg_color=Color("eed577",.38)
		if state=="pressed": face.bg_color=Color("eed577",.85)
		if state=="focus":
			face.border_width_left=3; face.border_color=Color("31658b")
			face.bg_color=Color("31658b",.07)
		add_theme_stylebox_override(state,face)
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		add_theme_color_override(state,Color("243b49"))
	add_theme_color_override("font_disabled_color",Color("839196"))
	queue_redraw()

func _feedback() -> void:
	if feedback: feedback.kill()
	feedback=create_tween()
	feedback.tween_property(self,"self_modulate",Color.WHITE if not disabled and (has_focus() or is_hovered() or selected) else Color(.93,.96,.98),.01 if SettingsSystem.reduced_motion() else .12)
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(25,size.y-1),Vector2(size.x-12,size.y-1),Color("31658b",.12),1)
	if not disabled and (has_focus() or is_hovered() or selected):
		draw_polyline(PackedVector2Array([Vector2(11,size.y*.5-4),Vector2(15,size.y*.5),Vector2(11,size.y*.5+4)]),Color("31658b"),1.5,true)
