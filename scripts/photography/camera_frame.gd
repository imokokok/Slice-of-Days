extends Control
func _draw() -> void:
	var ink:=Color("eee7d4",.7)
	draw_rect(Rect2(Vector2.ONE,size-Vector2(2,2)),Color("ede5d1",.32),false,1)
	for corner in [Vector2(0,0),Vector2(size.x,0),Vector2(0,size.y),size]:
		var direction:=Vector2(1 if corner.x==0 else -1,1 if corner.y==0 else -1)
		draw_line(corner,corner+Vector2(24*direction.x,0),ink,2)
		draw_line(corner,corner+Vector2(0,24*direction.y),ink,2)
	var center:=size*.5
	draw_arc(center,13,PI*.65,PI*1.35,12,Color("eee7d4",.55),1,true)
	draw_arc(center,13,-PI*.35,PI*.35,12,Color("eee7d4",.55),1,true)
