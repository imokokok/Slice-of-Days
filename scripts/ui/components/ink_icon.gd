extends Control
var kind := "book"
var ink := Color("3d7096")
func _ready() -> void: mouse_filter=MOUSE_FILTER_IGNORE
func line(points: Array, width := 2.0) -> void:
	var p := PackedVector2Array()
	for point in points: p.append(Vector2(point)*size/64.0)
	draw_polyline(p,ink,width,true)
func _draw() -> void:
	match kind:
		"book":
			line([Vector2(7,12),Vector2(20,10),Vector2(32,15),Vector2(44,10),Vector2(57,12),Vector2(57,52),Vector2(44,50),Vector2(32,55),Vector2(20,50),Vector2(7,52),Vector2(7,12)])
			line([Vector2(32,15),Vector2(32,55)])
		"personal":
			draw_circle(size*Vector2(.5,.3),size.x*.12,ink,false,2,true)
			line([Vector2(18,53),Vector2(21,36),Vector2(32,32),Vector2(43,36),Vector2(46,53),Vector2(18,53)])
		"star":
			var p := PackedVector2Array()
			for i in 10: p.append(size*.5+Vector2.from_angle(i*PI/5-PI*.5)*size.x*(.42 if i%2==0 else .19))
			draw_colored_polygon(p,ink)
		"mail":
			line([Vector2(7,15),Vector2(57,15),Vector2(57,50),Vector2(7,50),Vector2(7,15),Vector2(32,37),Vector2(57,15)])
		"photo","life":
			line([Vector2(12,10),Vector2(54,14),Vector2(51,55),Vector2(8,51),Vector2(12,10)])
			line([Vector2(15,41),Vector2(26,29),Vector2(33,36),Vector2(39,30),Vector2(48,43),Vector2(15,41)])
			draw_circle(size*Vector2(.6,.35),size.x*.055,ink)
		"requirements":
			line([Vector2(15,8),Vector2(47,8),Vector2(51,13),Vector2(51,56),Vector2(15,56),Vector2(15,8)])
			for y in [23,32,41]: line([Vector2(23,y),Vector2(43,y)])
		"add":
			line([Vector2(12,12),Vector2(52,12),Vector2(52,52),Vector2(12,52),Vector2(12,12)])
			line([Vector2(22,32),Vector2(42,32)]); line([Vector2(32,22),Vector2(32,42)])
		"text":
			line([Vector2(12,15),Vector2(52,15)]); line([Vector2(32,15),Vector2(32,51)]); line([Vector2(23,51),Vector2(41,51)])
		"draw": line([Vector2(13,50),Vector2(18,38),Vector2(46,9),Vector2(55,17),Vector2(26,47),Vector2(13,50),Vector2(18,38),Vector2(26,47)])
		"play": draw_colored_polygon(PackedVector2Array([size*Vector2(.36,.2),size*Vector2(.76,.5),size*Vector2(.36,.8)]),ink)
		"pause":
			draw_rect(Rect2(size*Vector2(.28,.22),size*Vector2(.15,.56)),ink); draw_rect(Rect2(size*Vector2(.57,.22),size*Vector2(.15,.56)),ink)
		"back": line([Vector2(39,12),Vector2(18,32),Vector2(39,52)])
		"close": line([Vector2(17,17),Vector2(47,47)]); line([Vector2(47,17),Vector2(17,47)])
