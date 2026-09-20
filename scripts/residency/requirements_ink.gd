extends Control
const BLUE := Color("31658b")
func _ready() -> void: mouse_filter=MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_polyline(PackedVector2Array([Vector2(75,257),Vector2(250,249),Vector2(450,251),Vector2(620,255)]),Color("eed577"),3,true)
	draw_line(Vector2(206,421),Vector2(1254,422),Color("31658b",.5),1,true)
	draw_line(Vector2(78,659),Vector2(1250,660),Color("31658b",.5),1,true)
	for i in 5:
		var x := 86+i*234
		if i>0: draw_line(Vector2(x-12,445),Vector2(x-12,635),Color("31658b",.27),1,true)
		draw_line(Vector2(x,478),Vector2(x+26,477),Color("eed577"),3,true)
		var center := Vector2(x+110,492)
		draw_set_transform(center)
		match i:
			0:
				draw_arc(Vector2(0,-12),8,0,TAU,24,BLUE,2,true)
				draw_polyline(PackedVector2Array([Vector2(-18,22),Vector2(-17,12),Vector2(-8,3),Vector2(8,4),Vector2(17,11),Vector2(18,22)]),BLUE,2,true)
			1:
				draw_rect(Rect2(-22,-19,44,39),BLUE,false,2)
				draw_line(Vector2(-21,-8),Vector2(22,-9),BLUE,2,true)
				draw_line(Vector2(-11,-26),Vector2(-11,-14),BLUE,2,true); draw_line(Vector2(11,-26),Vector2(11,-14),BLUE,2,true)
			2:
				draw_arc(Vector2.ZERO,21,0,TAU,28,BLUE,2,true)
				draw_polyline(PackedVector2Array([Vector2(-11,1),Vector2(-2,10),Vector2(13,-10)]),BLUE,2,true)
			3:
				draw_polyline(PackedVector2Array([Vector2(0,22),Vector2(-23,17),Vector2(-23,-19),Vector2(-12,-22),Vector2(0,-17),Vector2(12,-22),Vector2(23,-19),Vector2(23,17),Vector2(0,22),Vector2(0,-17)]),BLUE,2,true)
			4:
				draw_rect(Rect2(-18,-24,36,48),BLUE,false,2)
				for y in [-12,-2,8]: draw_line(Vector2(-10,y),Vector2(10,y+.4),BLUE,2,true)
		draw_set_transform(Vector2.ZERO)
