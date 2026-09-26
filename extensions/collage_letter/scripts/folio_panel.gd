extends Control
var g
var preview_id: int=-1
var paper_color:=Color("f8e1b5")
var edge_color:=Color("85baa7")
var postal_trim:=false
func _draw() -> void:
	# A bound material book: cloth cover, stacked leaves and a shaded stitched gutter.
	var paper=preload("res://extensions/collage_letter/scripts/letter_paper.gd")
	var cover:=StyleBoxFlat.new();cover.bg_color=Color("858e78");cover.set_corner_radius_all(8);cover.shadow_color=Color(0.23,0.18,0.12,0.18);cover.shadow_size=5;cover.shadow_offset=Vector2(4,6)
	draw_style_box(cover,Rect2(Vector2.ZERO,size))
	draw_texture_rect(paper.texture(0),Rect2(-18,10,40,size.y-18),false,Color(0.9,0.87,0.75,0.65))
	for i in range(5,0,-1):
		paper.paint(self,Rect2(17+i,10+i*1.5,size.x-29-i,size.y-27),1,false)
		var edge:=PackedVector2Array([Vector2(25,size.y-21+i*1.3),Vector2(size.x*0.6,size.y-19+i),Vector2(size.x-14+i,size.y-22+i)])
		draw_polyline(edge,Color("c5b69a"),0.7,true)
	paper.paint(self,Rect2(17,10,size.x-30,size.y-29),1,false)
	for i in 12:draw_line(Vector2(13+i,17),Vector2(13+i,size.y-24),Color(0.29,0.24,0.17,0.08*(1.0-i/12.0)),1.0)
	for y in [108,282,459]:
		draw_arc(Vector2(14,y),8,0.0,PI,16,Color("e7d6ad"),2,true)
		draw_circle(Vector2(6,y),1.5,Color("6e6858"));draw_circle(Vector2(22,y),1.5,Color("8d8267"))
	if preview_id>=0 and g:
		draw_texture_rect(g.get_material_texture(preview_id),Rect2(33,181,300,240),false)
		if g.cutting_source==preview_id and g.path.size()>1:
			var cut:=PackedVector2Array()
			for point in g.path:cut.append(point-global_position)
			if g.tool=="rect":draw_rect(Rect2(g.start-global_position,g.get_global_mouse_position()-g.start).abs(),Color("fff1d0"),false,1)
			else:draw_polyline(cut,Color("fff1d0"),1.5,true)
