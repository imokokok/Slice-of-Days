extends Control
var g
var preview_id: int=-1
var paper_color:=Color("f8e1b5")
var edge_color:=Color("85baa7")
var postal_trim:=false
func _draw() -> void:
	var border:=StyleBoxFlat.new();border.bg_color=edge_color;border.set_corner_radius_all(28)
	border.shadow_color=Color(0.35,0.23,0.15,0.20);border.shadow_size=5;border.shadow_offset=Vector2(3,5)
	draw_style_box(border,Rect2(Vector2.ZERO,size))
	for y in range(36,int(size.y)-24,18):
		for x in [2,size.x-2]:draw_circle(Vector2(x,y),3.5,edge_color.lightened(0.12))
	var line:=StyleBoxFlat.new();line.bg_color=paper_color;line.set_corner_radius_all(21);line.border_color=Color("fff3d6");line.set_border_width_all(3)
	draw_style_box(line,Rect2(Vector2(10,10),size-Vector2(20,20)))
	var grain: Texture2D=load("res://assets/open_pack/paper/Papier13.png")
	draw_texture_rect(grain,Rect2(Vector2(20,20),size-Vector2(40,40)),false,Color(1,1,1,0.16))
	if postal_trim:
		for i in range(0,int(size.x-100)/35):
			for y in [22,size.y-22]:
				var x:=35+i*35.0
				draw_line(Vector2(x,y-3),Vector2(x+15,y+3),Color("e8b377") if i%2==0 else Color("edcf82"),5,true)
		var corner:=Vector2(size.x-15,size.y-15)
		draw_colored_polygon(PackedVector2Array([corner-Vector2(40,0),corner-Vector2(0,42),corner]),Color("e8aa7d"))
	for y in range(36,int(size.y)-24,17):
		for x in [16,size.x-16]:draw_circle(Vector2(x,y),1.1,Color("fbefcd"))
	if preview_id>=0 and g:
		draw_texture_rect(g.get_material_texture(preview_id),Rect2(33,181,300,240),false)
		if g.cutting_source==preview_id and g.path.size()>1:
			var cut:=PackedVector2Array()
			for point in g.path:cut.append(point-global_position)
			if g.tool=="rect":draw_rect(Rect2(g.start-global_position,g.get_global_mouse_position()-g.start).abs(),Color("fff1d0"),false,1)
			else:draw_polyline(cut,Color("fff1d0"),1.5,true)
