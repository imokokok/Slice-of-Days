extends Button
var tint := Color("a8cce4")
var chosen := false
var chinese := ""
var english := ""
func _ready() -> void:
	for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	tooltip_text=chinese+" / "+english
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw); button_down.connect(queue_redraw); button_up.connect(queue_redraw)
	var title := Label.new()
	title.text=chinese; title.position=Vector2(10,8); title.size=Vector2(size.x-20,30)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("234e70")); title.add_theme_font_size_override("font_size",23)
	title.mouse_filter=MOUSE_FILTER_IGNORE; add_child(title)
	var subtitle := Label.new()
	subtitle.text=english; subtitle.position=Vector2(6,37); subtitle.size=Vector2(size.x-12,23)
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color",Color("315a76")); subtitle.add_theme_font_size_override("font_size",14)
	subtitle.mouse_filter=MOUSE_FILTER_IGNORE; add_child(subtitle)
func _draw() -> void:
	var w := size.x
	var h := size.y
	var outline := PackedVector2Array([Vector2(0,h),Vector2(8,h-8),Vector2(19,13),Vector2(25,4),Vector2(34,2),Vector2(w-30,3),Vector2(w-22,7),Vector2(w-17,19),Vector2(w-6,h-7),Vector2(w,h)])
	var fill := tint if chosen else tint.lerp(Color("faf7ee"),.36)
	if disabled: fill=fill.lerp(Color.GRAY,.45)
	elif is_pressed(): fill=Color("d7b941")
	elif is_hovered(): fill=fill.lerp(Color("eed577"),.26)
	draw_colored_polygon(outline,fill)
	draw_polyline(outline,Color("4f7690",.65),1.2,true)
	var fibres := RandomNumberGenerator.new(); fibres.seed=312
	for i in 150:
		var at := Vector2(fibres.randf_range(30,w-30),fibres.randf_range(6,h-3))
		draw_line(at,at+Vector2(2,.3),Color("31658b",.045),1)
	if has_focus(): draw_line(Vector2(35,h-6),Vector2(w-30,h-5),Color("31658b"),2,true)
