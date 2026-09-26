extends Control
# The live visitor uses a speech panel; the saved conversation remains a paper record.
const GRAIN=preload("res://assets/open_pack/paper/Papier13.png")
var dialogue:=false
var player_speaking:=false
func _draw() -> void:
	if dialogue:
		draw_dialogue();return
	var edge:=PackedVector2Array([Vector2(3,3)])
	for i in range(10,int(size.x)-9,10):edge.append(Vector2(i,2+sin(i*0.13)*1.1))
	edge.append(Vector2(size.x-3,3))
	for i in range(10,int(size.y)-9,10):edge.append(Vector2(size.x-2+sin(i*0.19),i))
	edge.append(Vector2(size.x-3,size.y-3))
	for i in range(int(size.x)-10,9,-10):edge.append(Vector2(i,size.y-2+sin(i*0.11)*1.1))
	edge.append(Vector2(3,size.y-3))
	for i in range(int(size.y)-10,9,-10):edge.append(Vector2(2+sin(i*0.17),i))
	draw_set_transform(Vector2(4,7));draw_colored_polygon(edge,Color(0.28,0.20,0.13,0.16));draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(edge,Color("f6e9cb"))
	draw_texture_rect(GRAIN,Rect2(12,12,size.x-24,size.y-24),false,Color(1,0.97,0.90,0.19))
	edge.append(edge[0]);draw_polyline(edge,Color("d8c5a2"),1.5,true)
	# Small postal marks belong to this sheet, rather than framing every edge.
	for i in 6:
		var x:=30.0+i*24
		draw_line(Vector2(x,19),Vector2(x+11,22),Color("c28d73") if i%2==0 else Color("94ab99"),4,true)
	draw_line(Vector2(38,87),Vector2(size.x-38,87),Color("d4c5a4"),1,true)
	var fold:=Vector2(size.x-3,size.y-3)
	draw_colored_polygon(PackedVector2Array([fold-Vector2(27,0),fold-Vector2(0,27),fold]),Color("dfcba8"))
func draw_dialogue() -> void:
	var panel:=StyleBoxFlat.new()
	panel.bg_color=Color("f4e7ce");panel.set_corner_radius_all(18)
	panel.border_color=Color("cabba0");panel.set_border_width_all(1)
	panel.shadow_color=Color(0.20,0.15,0.11,0.16);panel.shadow_size=10;panel.shadow_offset=Vector2(0,5)
	draw_style_box(panel,Rect2(Vector2.ZERO,size))
	# A speech tail and a changing speaker accent identify a conversation, without envelope marks.
	var tail_x:=size.x-72 if player_speaking else 72.0
	var tail:=PackedVector2Array([Vector2(tail_x-15,size.y-1),Vector2(tail_x+15,size.y-1),Vector2(tail_x+(12 if player_speaking else -12),size.y+17)])
	draw_colored_polygon(tail,Color("f4e7ce"))
	draw_line(tail[0],tail[2],Color("cabba0"),1,true);draw_line(tail[1],tail[2],Color("cabba0"),1,true)
	var accent:=Color("92735a") if player_speaking else Color("52796e")
	draw_circle(Vector2(29,121),4,accent)
	draw_line(Vector2(44,87),Vector2(size.x-44,87),Color("d9cbb2"),1,true)
