extends Button
## The workbench is a set of touchable shop objects, with real Button semantics.
var kind:="desk"
var caption:="声音手作桌"
var detail:="剪贴今天的声音"
func _ready() -> void:
	custom_minimum_size=Vector2(260,184)
	size_flags_horizontal=SIZE_EXPAND_FILL
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	accessibility_name=caption+" · "+detail
	tooltip_text=detail
	for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)
func _draw() -> void:
	var at:=Vector2(size.x*.5,66)
	var ink:=Color("4b625b"); var light:=Color("f6edd9")
	var face:=StyleBoxFlat.new(); face.bg_color=Color("e9dcc1") if is_hovered() or has_focus() else Color("f1e7d1")
	face.set_corner_radius_all(10); face.border_color=Color("a49b7f"); face.set_border_width_all(2 if has_focus() else 1)
	draw_style_box(face,Rect2(Vector2(2,3),size-Vector2(4,6)))
	draw_ellipse_shadow(at+Vector2(0,36))
	match kind:
		"collection":
			draw_rect(Rect2(at-Vector2(85,36),Vector2(170,79)),ink)
			draw_rect(Rect2(at-Vector2(73,26),Vector2(146,39)),light)
			for x in [-39,39]:
				draw_circle(at+Vector2(x,-7),17,Color("6f877a")); draw_circle(at+Vector2(x,-7),10,light)
				for i in 6: draw_line(at+Vector2(x,-7),at+Vector2(x,-7)+Vector2(cos(i*TAU/6),sin(i*TAU/6))*11,ink,2)
			draw_rect(Rect2(at+Vector2(-49,22),Vector2(98,15)),Color("aa9271"))
		"desk":
			draw_rect(Rect2(at-Vector2(92,34),Vector2(184,80)),light)
			for row in 3:
				var start:=at+Vector2(-73+row*12,-23+row*23)
				draw_rect(Rect2(start,Vector2(125-row*19,17)),[Color("8cb5ad"),Color("d4b176"),Color("b7bb99")][row])
				for i in 17: draw_line(start+Vector2(5+i*5,8),start+Vector2(5+i*5,8+sin(i*2.4)*5),ink)
			var joint:=at+Vector2(65,24)
			for x in [-9,9]: draw_arc(joint+Vector2(x,9),8,0,TAU,20,ink,2,true)
			draw_line(joint,joint+Vector2(-18,-31),ink,3); draw_line(joint,joint+Vector2(18,-31),ink,3)
		"shelf":
			draw_rect(Rect2(at-Vector2(99,38),Vector2(198,85)),Color("9a805e"))
			draw_rect(Rect2(at-Vector2(91,30),Vector2(182,65)),Color("5d5d4c"))
			for i in 8:
				var spine:=Rect2(at+Vector2(-81+i*21,-26),Vector2(16,60))
				draw_rect(spine,Color("b8c0a2") if i%2 else Color("d1a67e"))
				draw_line(spine.position+Vector2(7,9),spine.position+Vector2(7,38),light)
	var font:=get_theme_default_font()
	for row in 2:
		var copy:=caption if row==0 else detail
		var point:=23 if row==0 else 17
		var width:=font.get_string_size(copy,HORIZONTAL_ALIGNMENT_LEFT,-1,point).x
		draw_string(font,Vector2((size.x-width)*.5,134+row*29),copy,HORIZONTAL_ALIGNMENT_LEFT,size.x-20,point,ink)
func draw_ellipse_shadow(at:Vector2) -> void:
	draw_set_transform(at,0,Vector2(1,.2)); draw_circle(Vector2.ZERO,96,Color("5c513f",.13)); draw_set_transform(Vector2.ZERO)
