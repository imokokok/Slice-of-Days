extends Button
## Individually interactive original stationery silhouettes, not an image of a desk.
const Paper=preload("res://scripts/letter_paper.gd")
var kind: String="folio"
var caption: String=""
var font: Font
var accent:=Color("788b80")
func _ready() -> void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw);button_up.connect(queue_redraw)
func poly(points: Array, color: Color) -> void:draw_colored_polygon(PackedVector2Array(points),color)
func _draw() -> void:
	var lift:=Vector2(0,-3 if is_hovered() else 0)
	draw_set_transform(lift)
	var w:=size.x;var h:=size.y
	match kind:
		"folio":
			poly([Vector2(8,19),Vector2(w-2,11),Vector2(w-6,h-8),Vector2(13,h)],Color(0.24,0.18,0.13,0.18))
			for i in 3:Paper.paint(self,Rect2(16+i*3,15+i*3,w-31,h-32),2+i,false)
			poly([Vector2(3,34),Vector2(20,31),Vector2(20,5),Vector2(w*0.53,0),Vector2(w*0.60,28),Vector2(w-8,24),Vector2(w-3,h-17),Vector2(9,h-5)],Color("b89870"))
			draw_line(Vector2(22,41),Vector2(25,h-15),Color("977956"),2,true)
			draw_line(Vector2(10,h*0.62),Vector2(w-5,h*0.60),Color("e1c69a"),2,true)
			Paper.paint(self,Rect2(w*0.23,h*0.29,w*0.58,48),1,false)
			label_at(caption,Vector2(w*0.25,h*0.29+30),17)
		"tray":
			poly([Vector2(4,18),Vector2(w-9,7),Vector2(w,h-12),Vector2(11,h)],Color("927456"))
			for i in 3:
				var at:=Vector2(20+i*4,21-i*5);var extent:=Vector2(w-48,h-42)
				Paper.paint(self,Rect2(at,extent),i+1,false)
				draw_polyline(PackedVector2Array([at+Vector2(1,2),at+Vector2(extent.x/2,extent.y*0.55),at+Vector2(extent.x-1,0)]),Color("b9aa8e"),1,true)
			poly([Vector2(9,h-33),Vector2(w-2,h-42),Vector2(w,h-12),Vector2(11,h)],Color("ab8560"))
			label_at(caption,Vector2(29,h-13),15)
		"notebook":
			poly([Vector2(9,8),Vector2(w-3,1),Vector2(w-7,h-6),Vector2(6,h)],Color("667b75"))
			Paper.paint(self,Rect2(19,9,w-30,h-22),1,false)
			for y in range(25,int(h)-26,11):draw_line(Vector2(31,y),Vector2(w-27,y-1),Color(0.35,0.38,0.32,0.14),1,true)
			draw_line(Vector2(12,12),Vector2(10,h-7),Color("3f5852"),3,true)
			label_at(caption,Vector2(33,h*0.54),15)
		"pen":
			draw_set_transform(Vector2(w*0.50,h*0.44)+lift,0.23)
			draw_line(Vector2(0,-h*0.34),Vector2(0,h*0.30),Color("4d635c"),12,true)
			draw_line(Vector2(-3,-h*0.33),Vector2(-3,h*0.28),Color("839487"),2,true)
			draw_line(Vector2(0,-h*0.13),Vector2(0,-h*0.10),Color("d5ba82"),13,true)
			draw_line(Vector2(3,-h*0.32),Vector2(3,-h*0.18),Color("d5ba82"),2,true)
			poly([Vector2(-5,h*0.30),Vector2(0,h*0.40),Vector2(5,h*0.30)],Color("ccb789"))
			draw_line(Vector2(0,h*0.32),Vector2(0,h*0.39),Color("51554a"),1,true)
			draw_set_transform(lift);label_at(caption,Vector2(7,h-3),15)
		"tools":
			poly([Vector2(2,26),Vector2(w-13,14),Vector2(w-4,h-10),Vector2(10,h)],Color("728a80"))
			for i in 4:
				var x:=26+i*(w-38)/4
				draw_line(Vector2(x,14+i%2*11),Vector2(x+5,h-32),[Color("ad795a"),Color("d6b174"),Color("6f7770"),Color("ded8bd")][i],10,true)
				draw_line(Vector2(x-2,17+i%2*11),Vector2(x+3,h-33),Color(1,0.91,0.73,0.35),2,true)
			poly([Vector2(9,h*0.50),Vector2(w-6,h*0.48),Vector2(w-4,h-10),Vector2(10,h)],Color("9eae97"))
			for i in 4:draw_line(Vector2(15+i*(w-22)/4,h*0.54),Vector2(19+i*(w-22)/4,h-16),Color("6d8678"),1,true)
			label_at(caption,Vector2(20,h-20),15)
		"envelope":
			Paper.paint(self,Rect2(9,12,w-20,h-21),1)
			draw_polyline(PackedVector2Array([Vector2(12,14),Vector2(w*0.50,h*0.57),Vector2(w-14,13)]),Color("b5a88c"),1.3,true)
			draw_line(Vector2(12,h-12),Vector2(w*0.37,h*0.44),Color("c5b797"),1,true)
			draw_line(Vector2(w-13,h-12),Vector2(w*0.65,h*0.44),Color("c5b797"),1,true)
			draw_circle(Vector2(w*0.50,h*0.57),11,Color("ae7258"));draw_arc(Vector2(w*0.50,h*0.57),7,0,TAU,24,Color("d5a583"),1,true)
			label_at(caption,Vector2(20,h-21),14)
	draw_set_transform(Vector2.ZERO)
	if has_focus():draw_arc(size/2,minf(w,h)*0.43,0.1,TAU-0.1,32,Color("e9c687"),1.4,true)
func label_at(value: String, at: Vector2, font_size: int) -> void:
	if font:draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("484e43"))
