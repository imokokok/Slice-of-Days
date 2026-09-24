extends Button
## An opaque response chip; native keyboard/controller focus and real branches.
const Palette = preload("res://scripts/ui/components/interface_palette.gd")
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
		face.set_corner_radius_all(9)
		face.content_margin_left=25; face.content_margin_right=12
		face.content_margin_top=10; face.content_margin_bottom=10
		face.bg_color=Palette.SPEECH
		face.set_border_width_all(1); face.border_color=Palette.PAPER_EDGE
		if state=="hover": face.bg_color=Color("f6e8b2")
		if state=="normal" and selected: face.bg_color=Palette.LEMON
		if state=="normal" and has_focus() and not selected: face.bg_color=Color("f6e8b2")
		if state=="pressed": face.bg_color=Color("e7c55e")
		if state=="disabled": face.bg_color=Color("e0e6e5")
		if state=="focus":
			face.set_border_width_all(2); face.border_color=Palette.SEA
			# Focus is drawn OVER the opaque normal face by Godot.
			face.bg_color=Color.TRANSPARENT
		add_theme_stylebox_override(state,face)
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		add_theme_color_override(state,Palette.SPEECH_INK)
	add_theme_color_override("font_disabled_color",Color("56656d"))
	add_theme_constant_override("outline_size",0)
	queue_redraw()

func _feedback() -> void:
	_refresh()
	if feedback: feedback.kill()
	feedback=create_tween()
	feedback.tween_property(self,"self_modulate",Color.WHITE,.01 if SettingsSystem.reduced_motion() else .12)
	queue_redraw()

func _draw() -> void:
	if not disabled and (has_focus() or is_hovered() or selected):
		draw_polyline(PackedVector2Array([Vector2(11,size.y*.5-4),Vector2(15,size.y*.5),Vector2(11,size.y*.5+4)]),Color("31658b"),1.5,true)
