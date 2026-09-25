extends Control
## Object-first tabletop shared by the sound scrapbook and pocket recorder.
var compact := false
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("e3cbb0"))
	for y in range(0,int(size.y),110):
		draw_line(Vector2(0,y),Vector2(size.x,y+4),Color("b99877",.18),2)
		for x in range(0,int(size.x),280):
			draw_arc(Vector2(x+50,y+52),110,.05,.4,14,Color("b99877",.09),1)
	if compact: return
	# An open paper album, separate sound tray and framed moving postcard.
	card(Rect2(36,120,842,309),Color("f9f2e1"),14)
	card(Rect2(902,105,655,351),Color("fffbef"),8)
	card(Rect2(36,458,1521,389),Color("fbf5e7"),16)
	for y in range(520,815,25): draw_line(Vector2(74,y),Vector2(1521,y),Color("aaa18d",.12))
	draw_line(Vector2(796,484),Vector2(796,825),Color("a99072",.12),2)
	for x in range(55,1540,54):
		draw_circle(Vector2(x,477),3,Color("c0aa8a"))
	# Washi tape and registration corners keep decoration outside hit areas.
	draw_set_transform(Vector2(1148,102),-.045)
	draw_rect(Rect2(0,-8,150,27),Color("ccad6a",.65))
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(62,82),Vector2(460,82),Color("aa6953"),3)
func card(rect: Rect2,color: Color,radius: int) -> void:
	var shadow:=StyleBoxFlat.new(); shadow.bg_color=Color("72583e",.13); shadow.set_corner_radius_all(radius)
	draw_style_box(shadow,Rect2(rect.position+Vector2(4,6),rect.size))
	var paper:=StyleBoxFlat.new(); paper.bg_color=color; paper.set_corner_radius_all(radius)
	paper.set_border_width_all(2); paper.border_color=Color("b6a185",.45)
	draw_style_box(paper,rect)
