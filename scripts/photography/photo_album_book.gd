extends Control
## A blue cloth cover and two clean pages, drawn in the project's own vectors.
const S := preload("res://scripts/photography/photo_style.gd")
func _draw() -> void:
	draw_style_box(S.surface(Color("315d7d",.17),28),Rect2(Vector2(8,10),size))
	draw_style_box(S.surface(Color("80a8ce"),26),Rect2(Vector2.ZERO,size))
	draw_style_box(S.surface(Color("dfe9df"),14),Rect2(Vector2(15,12),size-Vector2(30,26)))
	var half := (size.x-64)*.5
	draw_style_box(S.surface(S.PAPER,12),Rect2(Vector2(22,18),Vector2(half,size.y-42)))
	draw_style_box(S.surface(S.PAPER,12),Rect2(Vector2(size.x*.5+10,18),Vector2(half,size.y-42)))
	draw_line(Vector2(size.x*.5,32),Vector2(size.x*.5,size.y-30),Color("5b87a9",.27),5,true)
	for y in [size.y*.22,size.y*.5,size.y*.78]:
		draw_circle(Vector2(size.x*.5-13,y),5,Color("8c9eaa"))
		draw_circle(Vector2(size.x*.5+13,y),5,Color("8c9eaa"))
		draw_arc(Vector2(size.x*.5,y),16,-.1,PI+.1,20,Color("b8c9d3"),5,true)
		draw_arc(Vector2(size.x*.5,y-1),16,-.1,PI+.1,20,Color("edf5f1"),2,true)
