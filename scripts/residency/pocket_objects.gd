extends Control
func _ready() -> void: mouse_filter = MOUSE_FILTER_IGNORE
func _draw() -> void:
	# Native UI illustrations: quiet physical tools beside the editorial list.
	var ink := Color("506766")
	var paper := Color("f9f1da")
	draw_rect(Rect2(70,50,280,180),Color("90a9a4"))
	draw_rect(Rect2(92,64,236,150),paper)
	for y in range(85,210,22): draw_line(Vector2(108,y),Vector2(311,y),Color("c8c8b0"),2)
	draw_line(Vector2(167,64),Vector2(167,214),Color("b7886b"),2)
	draw_rect(Rect2(250,230,185,115),ink)
	draw_circle(Vector2(340,290),40,Color("d5c9a9"))
	draw_circle(Vector2(340,290),29,Color("253f46"))
	draw_circle(Vector2(330,279),9,Color("809b9f"))
	draw_rect(Rect2(275,216,50,20),ink)
	draw_rect(Rect2(40,285,105,185),Color("b89771"))
	draw_rect(Rect2(53,300,79,64),Color("617d7b"))
	for x in range(57,133,8): draw_line(Vector2(x,388),Vector2(x,421),Color("826a53"),2)
	draw_circle(Vector2(68,443),9,Color("f1e6cc"))
	draw_circle(Vector2(112,443),9,Color("b16f50"))
	draw_rect(Rect2(200,405,228,150),paper)
	draw_rect(Rect2(216,420,196,104),Color("93b5c0"))
	draw_colored_polygon(PackedVector2Array([Vector2(216,476),Vector2(279,438),Vector2(331,480),Vector2(412,451),Vector2(412,524),Vector2(216,524)]),Color("697f70"))
