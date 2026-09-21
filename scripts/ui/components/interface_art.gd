extends Control
## Original geometry, used only as decoration behind independent native controls.
const PALETTE = preload("res://scripts/ui/components/interface_palette.gd")
var kind := "coast"
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE; resized.connect(queue_redraw)
func _draw() -> void:
	if kind=="counter":
		draw_style_box(PALETTE.face(PALETTE.DEEP,12),Rect2(Vector2.ZERO,Vector2(size.x,139)))
		for i in 3:
			var points := PackedVector2Array()
			for j in 81: points.append(Vector2(size.x*j/80.0,128+i*5+sin(j*.18+i*.6)*4))
			draw_polyline(points,PALETTE.LEMON if i==0 else Color(PALETTE.CREAM,.12),1.5,true)
	elif kind=="bag":
		draw_style_box(PALETTE.face(PALETTE.DEEP,12),Rect2(Vector2.ZERO,Vector2(size.x,147)))
		for x in range(20,int(size.x)-10,13): draw_line(Vector2(x,134),Vector2(x+5,134),Color(PALETTE.CREAM,.32),1,true)
	elif kind=="folio":
		draw_style_box(PALETTE.face(PALETTE.SEA,4),Rect2(0,0,14,size.y))
		for y in range(35,int(size.y)-20,24): draw_line(Vector2(5,y),Vector2(8,y+7),Color(PALETTE.CREAM,.4),1,true)
	else:
		# A small sun and three uneven sea strokes: Solmere's recurring signature.
		draw_circle(Vector2(size.x*.72,size.y*.26),minf(size.y*.18,22),PALETTE.LEMON)
		for i in 3:
			var p := PackedVector2Array()
			for j in 21: p.append(Vector2(size.x*j/20.0,size.y*(.53+i*.15)+sin(j*.35+i)*3))
			draw_polyline(p,Color(PALETTE.SEA,.35),1.8,true)
