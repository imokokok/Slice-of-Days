extends RefCounted
const COLORS=[Color(0.78,0.67,0.43,0.76),Color(0.37,0.53,0.58,0.8),Color(0.66,0.42,0.37,0.8),Color(0.59,0.66,0.47,0.78),Color(0.91,0.82,0.65,0.82),Color(0.53,0.45,0.59,0.76),Color(0.71,0.76,0.71,0.84),Color(0.87,0.76,0.55,0.8)]
static func paint(node: Node2D, poly: PackedVector2Array, style: int) -> void:
	if poly.size()<3:return
	node.draw_colored_polygon(poly,COLORS[posmod(style,COLORS.size())])
	var bounds:=Rect2(poly[0],Vector2.ZERO)
	for p in poly: bounds=bounds.expand(p)
	for x in range(int(bounds.position.x)+7,int(bounds.end.x)-7,14):
		var center:=Vector2(x,bounds.get_center().y)
		match style%8:
			0: node.draw_line(center-Vector2(3,8),center+Vector2(3,8),Color(1,1,0.9,0.25),1)
			1:
				node.draw_line(center-Vector2(0,9),center+Vector2(0,9),Color(1,1,1,0.65),1)
				for y in [-5,5]: node.draw_line(center+Vector2(-7,y),center+Vector2(7,y),Color(1,1,1,0.65),1)
			2: node.draw_circle(center,2,Color(1,0.95,0.82,0.8))
			3:
				node.draw_line(center-Vector2(0,8),center+Vector2(0,8),Color("506144"),1)
				for offset in [-4,3]: node.draw_arc(center+Vector2(0,offset),4,0,PI,8,Color("506144"),1,true)
			4: node.draw_line(center-Vector2(5,7),center+Vector2(5,-7),Color(0.6,0.38,0.3,0.5),4,true)
			5: node.draw_arc(center,5,0,TAU,14,Color(1,0.9,0.71,0.6),1,true)
			6: node.draw_line(center-Vector2(6,4),center+Vector2(6,4),Color(0.24,0.43,0.45,0.3),2,true)
			7:
				for n in 4: node.draw_circle(center+Vector2(cos(n*PI/2),sin(n*PI/2))*4,2.8,Color(0.98,0.91,0.74,0.85))
				node.draw_circle(center,1.5,Color("ad793e"))
