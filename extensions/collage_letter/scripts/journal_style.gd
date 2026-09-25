extends RefCounted
## Original flat stationery UI. Reference clips inform hierarchy, not copied artwork.
static func contour(rect: Rect2, radius: float=16.0) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for corner in 4:
		var center: Vector2=[rect.position+Vector2(radius,radius),Vector2(rect.end.x-radius,rect.position.y+radius),rect.end-Vector2(radius,radius),Vector2(rect.position.x+radius,rect.end.y-radius)][corner]
		for step in 9:
			var angle:=PI+corner*PI/2+step*PI/16
			points.append(center+Vector2(cos(angle),sin(angle))*(radius+sin(step*2+corner)*0.5))
	return points

static func panel(g, rect: Rect2, color: Color, stitched: bool=true) -> void:
	g.draw_colored_polygon(contour(Rect2(rect.position+Vector2(4,6),rect.size)),Color(0.30,0.22,0.15,0.18))
	g.painted_polygon(contour(rect),color,0.13)
	var rim:=contour(rect.grow(-5));rim.append(rim[0])
	g.draw_polyline(rim,Color("fdf1d6"),2.0,true)
	if stitched:
		for x in range(int(rect.position.x+22),int(rect.end.x-18),12):
			for y in [rect.position.y+12,rect.end.y-12]:g.draw_line(Vector2(x,y),Vector2(x+5,y),Color(1,0.96,0.84,0.65),1.2,true)
		for y in range(int(rect.position.y+22),int(rect.end.y-18),12):
			for x in [rect.position.x+12,rect.end.x-12]:g.draw_line(Vector2(x,y),Vector2(x,y+5),Color(1,0.96,0.84,0.65),1.2,true)

static func clip(g, at: Vector2) -> void:
	g.draw_set_transform(at,-0.04)
	g.draw_style_box(rounded(Color("d59978"),5),Rect2(-24,-7,48,13))
	for x in [-9,9]:g.draw_arc(Vector2(x,-9),8,PI,TAU,20,Color("b08c52"),2.5,true)
	g.draw_set_transform(Vector2.ZERO)

static func rounded(color: Color, radius: int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(radius)
	return style

static func heading(g) -> void:
	# A small clipped shop card, with quiet controls on the desk instead of a dashboard banner.
	g.draw_set_transform(Vector2(235,57),-0.015)
	g.paper(Rect2(-193,-37,385,81),Color("fff1d6"))
	g.draw_set_transform(Vector2.ZERO)
	clip(g,Vector2(231,23))
	g.draw_line(Vector2(475,76),Vector2(965,76),Color("af8062"),1.0,true)

static func desk(g) -> void:
	# Single loose letter on a fabric writing pad: no gutter, binding, or second page.
	panel(g,Rect2(433,178,574,567),Color("88afa0"))
	panel(g,Rect2(53,105,337,640),Color("8fbdae"))
	g.paper(Rect2(65,145,310,550),Color("f3e1bf"))
	# Small scallops make the folio read as a physical fabric edge.
	for y in range(166,692,18):g.draw_circle(Vector2(66,y),4,Color("fff2d3"))
	panel(g,Rect2(1053,139,337,307),Color("d3a67e"))
	panel(g,Rect2(1053,449,337,306),Color("8fbdae"))
	# Picture corners stay outside the actual image hit areas.
	for point in [Vector2(1061,186),Vector2(1061,494)]:
		g.draw_colored_polygon(PackedVector2Array([point,point+Vector2(20,0),point+Vector2(0,20)]),Color("fff4de"))
	# A scalloped linen tool strip, separate from contextual paper controls.
	panel(g,Rect2(403,782,577,79),Color("edcea6"),false)
	for x in range(418,974,14):g.draw_circle(Vector2(x,786),4,Color("fff0d1"))
	g.draw_line(Vector2(47,862),Vector2(1392,862),Color(0.55,0.39,0.26,0.35),1,true)
