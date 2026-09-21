extends "res://scripts/ui/components/solmere_button.gd"
func refresh() -> void:
	super.refresh()
	var face := StyleBoxFlat.new(); face.bg_color=Color("fcf7e8",.93); face.set_corner_radius_all(6); face.content_margin_left=31; face.content_margin_right=9
	if selected: face.bg_color=Color("f1d880"); face.border_width_bottom=2; face.border_color=PaperLanguage.BLUE
	if str(get_meta("state",""))=="unavailable": face.bg_color=Color("e3e5df",.88); add_theme_color_override("font_color",Color("7b8589"))
	add_theme_stylebox_override("normal",face)
	alignment=HORIZONTAL_ALIGNMENT_LEFT; queue_redraw()
func _draw() -> void:
	var center := Vector2(15,size.y*.5)
	draw_circle(center,8,Color("fffdf2")); draw_circle(center,7,PaperLanguage.BLUE,false,1.4,true)
	if str(get_meta("state",""))=="discovered": draw_circle(center,3,PaperLanguage.BLUE)
	if str(get_meta("state",""))=="unavailable": draw_line(center-Vector2(4,0),center+Vector2(4,0),Color("7b8589"),2,true)
	if selected: draw_arc(center,11,-.15,TAU-.1,30,PaperLanguage.YELLOW,3,true)
