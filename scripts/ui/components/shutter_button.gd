extends Button
func _ready() -> void:
	text=""; tooltip_text="拍摄"; focus_mode=FOCUS_ALL
	for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for event in ["mouse_entered","mouse_exited","focus_entered","focus_exited","button_down","button_up"]: connect(event,queue_redraw)
func _draw() -> void:
	var center := size*.5
	var radius := minf(size.x,size.y)*.44
	draw_circle(center,radius,Color("fffaf0",.45 if disabled else 1.0),false,3,true)
	draw_circle(center,radius-7,Color("f1d781") if is_pressed() else Color("fffaf0",.55 if disabled else .95))
	if has_focus() or is_hovered(): draw_arc(center,radius+5,0,TAU,64,Color("f1d781"),2,true)
