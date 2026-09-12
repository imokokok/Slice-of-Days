extends Node2D

var kind := 0
var sheet_data: Dictionary = {}
var ink := Color("374a45")
var font: Font

func word(s: String, p: Vector2, size: int = 22, color: Color = ink) -> void:
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	var colors := [Color("eee7d5"), Color("e7d4b9"), Color("f4ecdb"), Color("c8cbb2"), Color("ede5d5")]
	draw_rect(Rect2(0, 0, 300, 240), colors[kind % colors.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = kind + 173
	for i in 480:
		var p := Vector2(rng.randf_range(0,300), rng.randf_range(0,240))
		draw_line(p, p + Vector2(rng.randf_range(1,5),0.5), Color(0.35,0.29,0.20,0.06))
	if kind>=5:
		if sheet_data.get("category","")=="影像":
			draw_photo(sheet_data.get("scene","window"))
		else:
			draw_document()
		return
	match kind:
		0:
			word("海 岸 日 报", Vector2(22, 38), 29)
			draw_line(Vector2(18,49),Vector2(282,49),ink,2)
			word("LOCAL  /  第 017 期", Vector2(20,70),14)
			word("周四    下午    开放", Vector2(20,108),25)
			word("沿海地区仍有阵雨", Vector2(20,144),22)
			word("夏季    仍然    远处", Vector2(20,182),25)
			word("东侧道路恢复通行 · 市集至九点", Vector2(20,218),15)
		1:
			word("给附近的你",Vector2(24,40),27)
			word("SUMMER  /  旧街商店",Vector2(24,68),15)
			draw_rect(Rect2(22,87,255,63),Color("ba7052"))
			word("第二件    半价",Vector2(37,130),29,Color("fff4dc"))
			word("本周    请保留",Vector2(24,188),25)
			word("感谢订阅。凭此邮件到店领取。",Vector2(24,218),15)
		2:
			word("海盐杂货 / 收据",Vector2(24,36),23)
			word("NO.17                18:47",Vector2(24,70),22)
			for y in [86, 171]:
				for x in range(20,280,12):
					draw_line(Vector2(x,y),Vector2(x+5,y),ink)
			word("海盐       1       3.00",Vector2(24,118),20)
			word("RETURN",Vector2(24,156),30)
			word("THANK YOU",Vector2(24,207),25)
		3:
			word("沿海公共汽车",Vector2(24,38),23)
			word("JUL 14",Vector2(24,80),31)
			word("ONE WAY",Vector2(24,126),34)
			word("17B",Vector2(24,181),40)
			word("请保存车票  /  下一站",Vector2(24,218),18)
			for x in range(200,276,5):
				draw_line(Vector2(x,150),Vector2(x,188),ink,2)
		4:
			draw_rect(Rect2(12,12,276,200),Color("d6b398"))
			draw_circle(Vector2(228,55),24,Color("edcf91"))
			draw_colored_polygon(PackedVector2Array([Vector2(12,123),Vector2(90,105),Vector2(173,120),Vector2(288,102),Vector2(288,180),Vector2(12,180)]),Color("8aaca3"))
			draw_rect(Rect2(12,169,276,43),Color("a2a08a"))
			draw_line(Vector2(249,154),Vector2(247,51),Color("5d6450"),7)
			for p in [Vector2(224,62),Vector2(259,48),Vector2(270,76)]:
				draw_circle(p,25,Color("7c8760"))
			draw_line(Vector2(53,95),Vector2(53,189),ink,4)
			draw_rect(Rect2(22,58,102,37),Color("e8e5cb"))
			word("LAST STOP",Vector2(28,83),17)
			for y in [140,151,165]:
				draw_line(Vector2(127,y),Vector2(218,y),Color("765c47"),7)
			for x in [135,208]:
				draw_line(Vector2(x,163),Vector2(x,186),ink,4)
			word("旧公交站 · 傍晚  /  01",Vector2(18,232),15)

func draw_document() -> void:
	var accent: Color = [Color("8b6550"),Color("667f78"),Color("9b704c"),Color("73728b")][kind%4]
	var layout := int(sheet_data.get("layout",0))
	if layout==0:
		draw_rect(Rect2(13,13,274,214),accent,false,1)
		for y in range(95,222,37):
			draw_line(Vector2(20,y),Vector2(280,y),Color(accent,0.22))
	elif layout==1:
		draw_rect(Rect2(0,0,300,57),accent)
	elif layout==2:
		for y in [61,219]:
			for x in range(15,287,10):
				draw_line(Vector2(x,y),Vector2(x+4,y),accent)
	else:
		draw_rect(Rect2(12,12,7,216),accent)
		for x in range(35,282,7):
			draw_line(Vector2(x,222),Vector2(x,233),accent,2)
	word(sheet_data.title,Vector2(25,38),25,Color("f8f0db") if layout==1 else accent)
	word(sheet_data.get("kicker",""),Vector2(25,76),13,accent)
	var y:=109
	for row in sheet_data.get("rows",[]):
		var size:=24
		while font.get_string_size(row,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>254 and size>16:
			size-=1
		word(row,Vector2(25,y),size)
		y+=34

func draw_photo(scene: String) -> void:
	draw_rect(Rect2(12,12,276,200),Color("b1c2b9"))
	match scene:
		"lighthouse":
			draw_rect(Rect2(12,12,276,113),Color("d4b392"))
			draw_circle(Vector2(74,77),28,Color("f0dba5"))
			for y in [148,170,188]:
				draw_line(Vector2(22,y),Vector2(281,y-8),Color("7a9f9a"),2)
			draw_colored_polygon(PackedVector2Array([Vector2(140,180),Vector2(280,174),Vector2(273,142),Vector2(184,147)]),Color("81806c"))
			draw_colored_polygon(PackedVector2Array([Vector2(199,152),Vector2(241,152),Vector2(230,57),Vector2(210,57)]),Color("f0e5c8"))
			draw_rect(Rect2(209,63,22,20),Color("686955"))
			draw_colored_polygon(PackedVector2Array([Vector2(201,57),Vector2(240,57),Vector2(220,43)]),Color("995d48"))
			word("LIGHT 03",Vector2(26,205),17)
		"window":
			draw_rect(Rect2(12,12,276,200),Color("b6b8af"))
			draw_rect(Rect2(48,27,195,158),Color("7d9898"))
			for x in range(58,234,19):
				draw_line(Vector2(x,40+(x%5)*14),Vector2(x-7,70+(x%5)*14),Color("c1d2c7"),1.4)
			for x in [42,144,241]:
				draw_line(Vector2(x,25),Vector2(x,186),Color("e9dfc6"),7)
			draw_line(Vector2(42,101),Vector2(248,101),Color("e9dfc6"),6)
			draw_rect(Rect2(31,182,232,15),Color("89715c"))
			draw_rect(Rect2(189,163,30,21),Color("a36d50"))
			draw_line(Vector2(203,164),Vector2(200,131),Color("57745a"),3)
			draw_circle(Vector2(192,143),9,Color("739074"))
			draw_circle(Vector2(210,136),9,Color("739074"))
		"mountain":
			draw_rect(Rect2(12,12,276,200),Color("cbb2a0"))
			for points in [PackedVector2Array([Vector2(12,158),Vector2(85,55),Vector2(178,165)]),PackedVector2Array([Vector2(85,173),Vector2(212,48),Vector2(288,155)])]:
				draw_colored_polygon(points,Color("788477"))
			draw_colored_polygon(PackedVector2Array([Vector2(12,150),Vector2(132,124),Vector2(288,149),Vector2(288,212),Vector2(12,212)]),Color("999577"))
			draw_polyline(PackedVector2Array([Vector2(86,212),Vector2(134,180),Vector2(113,160),Vector2(154,149)]),Color("d6c7a7"),13,true)
			word("TRAIL 08",Vector2(167,198),18)
	word(sheet_data.title,Vector2(18,233),15)
