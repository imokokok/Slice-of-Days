extends Control
## Original 2D reading desk: a shallow mail tray and one loose A4 sheet.
const PAPER=preload("res://extensions/collage_letter/assets/open_pack/paper/Papier13.png")
func _draw() -> void:
	draw_rect(Rect2(0,0,1440,900),Color(0.28,0.23,0.17,0.48))
	var wood:=StyleBoxFlat.new();wood.bg_color=Color("9d7958");wood.set_corner_radius_all(12);wood.shadow_color=Color(0.16,0.12,0.08,0.22);wood.shadow_size=8;wood.shadow_offset=Vector2(0,5)
	draw_style_box(wood,Rect2(54,161,326,665))
	var inside:=StyleBoxFlat.new();inside.bg_color=Color("b79671");inside.set_corner_radius_all(8)
	draw_style_box(inside,Rect2(63,169,308,643))
	# Several tucked envelopes suggest an inbox, without extra interactive rectangles.
	for i in range(2,-1,-1):
		var at:=Vector2(78+i*3,217-i*4)
		draw_set_transform(at,(i-1)*0.018)
		draw_rect(Rect2(0,0,273,553),Color("d9c6a2") if i else Color("ede0c1"))
		draw_set_transform(Vector2.ZERO)
	var sheet:=PackedVector2Array([Vector2(444,167),Vector2(907,166),Vector2(912,822),Vector2(445,829)])
	draw_set_transform(Vector2(5,7));draw_colored_polygon(sheet,Color(0.20,0.14,0.09,0.21));draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(sheet,Color("f5ecd9"))
	draw_texture_rect(PAPER,Rect2(449,174,453,646),false,Color(1,0.97,0.88,0.10))
	draw_polyline(PackedVector2Array([Vector2(445,169),Vector2(907,167),Vector2(911,822)]),Color("f9f2e1"),1.3,true)
	# A quiet slip keeps reply controls beside the actual letter, not over it.
	var note:=StyleBoxFlat.new();note.bg_color=Color("eadbc0");note.set_corner_radius_all(9);note.shadow_color=Color(0.20,0.14,0.09,0.12);note.shadow_size=5
	draw_style_box(note,Rect2(951,166,430,658))
