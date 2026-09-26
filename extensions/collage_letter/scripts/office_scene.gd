extends RefCounted
## Original 2D room: a shallow window above a generous, uninterrupted writing desk.
static func paint(g) -> void:
	g.draw_rect(Rect2(0,0,1440,150),Color("b49176"))
	g.draw_rect(Rect2(0,140,1440,14),Color("936f53"))
	g.draw_line(Vector2(0,153),Vector2(1440,153),Color("ecd1a6"),3,true)
	for x in [38,350,1080,1398]:g.draw_line(Vector2(x,0),Vector2(x,137),Color(0.28,0.20,0.16,0.16),2,true)
	# Street, sea and roofs are separate flat illustrations behind the movable blind.
	g.draw_rect(Rect2(448,0,545,134),Color("aec5cc"))
	g.draw_colored_polygon(PackedVector2Array([Vector2(448,69),Vector2(525,58),Vector2(610,71),Vector2(712,53),Vector2(811,67),Vector2(916,54),Vector2(993,63),Vector2(993,133),Vector2(448,133)]),Color("7695a1"))
	g.draw_rect(Rect2(448,79,545,55),Color("799da4"))
	for i in 11:g.draw_line(Vector2(470+i*45,86+i%3*12),Vector2(490+i*45,86+i%3*12),Color("c4d6cb"),1,true)
	g.draw_colored_polygon(PackedVector2Array([Vector2(742,91),Vector2(756,66),Vector2(756,91)]),Color("efe2c1"))
	g.draw_line(Vector2(740,94),Vector2(763,94),Color("587e87"),3,true)
	for i in 7:
		var x:=454+i*80.0;var y:float=[81,99,92,110,94,105,83][i]
		var walls:Color=[Color("e5cba5"),Color("cfaf88"),Color("eee0c0")][i%3]
		g.draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+51,y-2),Vector2(x+53,136),Vector2(x-2,136)]),walls)
		g.draw_colored_polygon(PackedVector2Array([Vector2(x-6,y),Vector2(x+21,y-17),Vector2(x+57,y-2)]),Color("b78061"))
		for w in 3:g.draw_rect(Rect2(x+7+w*14,y+8,6,10),Color("7c8981"))
	for x in [530,850,970]:
		g.draw_line(Vector2(x,136),Vector2(x-2,106),Color("797253"),3,true)
		for p in [Vector2(-7,-4),Vector2(5,-8),Vector2(12,3)]:g.draw_circle(Vector2(x-2,106)+p,12,Color("7f8e6a"))
	g.draw_rect(Rect2(442,0,9,140),Color("775c47"));g.draw_rect(Rect2(991,0,10,140),Color("775c47"))
	g.draw_rect(Rect2(716,0,7,134),Color("c3a079"));g.draw_rect(Rect2(433,133,578,10),Color("d6b48b"))
	var down:float=1.0-g.blinds_open
	for i in 11:
		var y:=i*10.7*down
		g.draw_rect(Rect2(451,y,540,10),Color("c5ad87"))
		g.draw_line(Vector2(452,y+8),Vector2(991,y+8),Color("9f8668"),1,true)
		g.draw_line(Vector2(454,y+1),Vector2(989,y+1),Color("e1c8a0"),1,true)
	for x in [504,935]:g.draw_line(Vector2(x,0),Vector2(x,10+107*down),Color("e7d2ae"),1.5,true)
	var cord_y:float=50+g.blinds_open*77
	g.draw_line(Vector2(1025,7),Vector2(1025,cord_y),Color("f2dfbc"),2,true)
	g.draw_circle(Vector2(1025,cord_y+5),6,Color("98734e"))
	g.draw_line(Vector2(1023,cord_y+2),Vector2(1023,cord_y+7),Color("d8b782"),2,true)
	# Slatted daylight falls beside the letter, never reducing text contrast.
	for i in 4:
		var x:=40+i*95.0
		g.draw_colored_polygon(PackedVector2Array([Vector2(x,157),Vector2(x+37,157),Vector2(x+107,480),Vector2(x+70,480)]),Color(1,0.91,0.66,0.055*g.blinds_open))
	# Fore-edge and joinery make this one physical desk rather than a wooden wallpaper.
	g.draw_rect(Rect2(0,879,1440,21),Color("966e50"))
	g.draw_line(Vector2(0,879),Vector2(1440,879),Color("e2bd8e"),3,true)
	g.draw_line(Vector2(20,893),Vector2(1420,893),Color("7e5a44"),1,true)
