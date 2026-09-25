extends Button
func _ready() -> void:
	custom_minimum_size=Vector2(126,126)
	clip_text=true
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	add_theme_color_override("font_color",Color.TRANSPARENT)
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
		add_theme_color_override("font_"+state+"_color",Color.TRANSPARENT)
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
func _has_point(point:Vector2) -> bool:
	return point.distance_to(size*.5)<size.x*.46
func _draw() -> void:
	var c:=size*.5
	draw_circle(c+Vector2(0,4),size.x*.46,Color("86755e"))
	draw_circle(c,size.x*.46,Color("f5ead4"))
	draw_arc(c,size.x*.46,0,TAU,64,Color("745c48"),2,true)
	draw_circle(c,size.x*.35,Color("cf7866") if is_hovered() else Color("b86150"))
	if text.contains("停止"): draw_rect(Rect2(c-Vector2(17,17),Vector2(34,34)),Color("fff3db"))
	else: draw_circle(c,18,Color("fff3db"))
	if has_focus(): draw_arc(c,size.x*.49,0,TAU,64,Color("477b74"),3,true)
