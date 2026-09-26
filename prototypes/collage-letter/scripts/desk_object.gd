extends Button
## Individually interactive original stationery silhouettes, not an image of a desk.
const Paper=preload("res://scripts/letter_paper.gd")
const AssetTexture=preload("res://scripts/asset_texture.gd")
const FOLIO_PATH="res://assets/illustrated_office/folio-v2.png"
const TOOLS_PATH="res://assets/illustrated_office/tool-roll-v2.png"
var folio_art: Texture2D
var tools_art: Texture2D
var kind: String="folio"
var caption: String=""
var font: Font
var accent:=Color("788b80")
func _ready() -> void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw);button_up.connect(queue_redraw)
func poly(points: Array, color: Color) -> void:draw_colored_polygon(PackedVector2Array(points),color)
func shadow(points: Array, offset: Vector2=Vector2(4,6)) -> void:
	var cast: Array=[]
	for point in points:cast.append(point+offset)
	poly(cast,Color(0.25,0.19,0.13,0.16))
func stitches(a: Vector2,b: Vector2,color: Color) -> void:
	var steps:=maxi(1,int(a.distance_to(b)/7))
	for i in steps:draw_line(a.lerp(b,float(i)/steps),a.lerp(b,(i+0.47)/steps),color,0.8,true)
func _draw() -> void:
	var lift:=Vector2(0,-3 if is_hovered() else 0)
	draw_set_transform(lift)
	var w:=size.x;var h:=size.y
	match kind:
		"folio":
			if folio_art==null and ResourceLoader.exists(FOLIO_PATH):folio_art=AssetTexture.get_texture(FOLIO_PATH)
			if folio_art!=null:
				var source:=Rect2(folio_art.get_size()*Vector2(25.0/1177,48.0/1336),folio_art.get_size()*Vector2(1140.0/1177,1220.0/1336))
				var art_rect:=draw_fitted_art(folio_art,source)
				centered_caption(art_rect.position+art_rect.size*Vector2(0.467,0.282),17)
			else:draw_folio_fallback(w,h)
		"tray":
			var tray: Array=[Vector2(4,18),Vector2(w-9,7),Vector2(w,h-12),Vector2(11,h)]
			shadow(tray);poly(tray,Color("927456"))
			poly([Vector2(13,23),Vector2(w-17,16),Vector2(w-10,h-29),Vector2(19,h-16)],Color("685747"))
			for i in 3:
				var at:=Vector2(23+i*4,27-i*6);var extent:=Vector2(w-53,h-46)
				Paper.paint(self,Rect2(at+Vector2(2,3),extent),i+1,false)
				Paper.paint(self,Rect2(at,extent),i+1,false)
				draw_polyline(PackedVector2Array([at+Vector2(1,2),at+Vector2(extent.x/2,extent.y*0.55),at+Vector2(extent.x-1,0)]),Color("b9aa8e"),1,true)
				if i==2:
					draw_line(at+Vector2(17,extent.y-18),at+Vector2(75,extent.y-18),Color("a2a38d"),1,true)
					draw_line(at+Vector2(17,extent.y-12),at+Vector2(56,extent.y-12),Color("b4ad95"),1,true)
			poly([Vector2(4,18),Vector2(13,23),Vector2(19,h-16),Vector2(11,h)],Color("b78f68"))
			poly([Vector2(w-9,7),Vector2(w-17,16),Vector2(w-10,h-29),Vector2(w,h-12)],Color("826347"))
			poly([Vector2(9,h-33),Vector2(w-2,h-42),Vector2(w,h-12),Vector2(11,h)],Color("ab8560"))
			draw_line(Vector2(11,h-32),Vector2(w-3,h-41),Color("d4b28a"),2,true)
			for i in 3:draw_line(Vector2(w*0.51,h-29+i*5),Vector2(w-15,h-33+i*5),Color(0.37,0.27,0.18,0.16),0.8,true)
			label_at(caption,Vector2(29,h-13),15)
		"notebook":
			var cover: Array=[Vector2(9,8),Vector2(w-3,1),Vector2(w-7,h-6),Vector2(6,h)]
			shadow(cover);poly(cover,Color("667b75"))
			for i in 3:
				Paper.paint(self,Rect2(20+i,10+i*2,w-34,h-24),i+1,false)
			Paper.paint(self,Rect2(19,9,w-34,h-28),1,false)
			for y in range(25,int(h)-26,11):draw_line(Vector2(35,y),Vector2(w-31,y-1),Color(0.35,0.38,0.32,0.14),1,true)
			draw_line(Vector2(13,12),Vector2(11,h-9),Color("3f5852"),4,true)
			for y in range(23,int(h)-19,24):
				draw_arc(Vector2(23,y),6,PI*0.56,PI*1.72,14,Color("958569"),1.5,true)
				draw_line(Vector2(22,y-6),Vector2(26,y-6),Color("cfbda0"),1,true)
			poly([Vector2(w-37,h-22),Vector2(w-25,h-23),Vector2(w-25,h+4),Vector2(w-31,h-1),Vector2(w-37,h+5)],Color("bb846b"))
			label_at(caption,Vector2(40,h*0.54),15)
		"pen":
			draw_set_transform(Vector2(w*0.50,h*0.44)+lift,0.23)
			draw_line(Vector2(0,-h*0.34),Vector2(0,h*0.30),Color("4d635c"),12,true)
			draw_line(Vector2(-3,-h*0.33),Vector2(-3,h*0.28),Color("839487"),2,true)
			draw_line(Vector2(0,-h*0.13),Vector2(0,-h*0.10),Color("d5ba82"),13,true)
			draw_line(Vector2(3,-h*0.32),Vector2(3,-h*0.18),Color("d5ba82"),2,true)
			poly([Vector2(-5,h*0.30),Vector2(0,h*0.40),Vector2(5,h*0.30)],Color("ccb789"))
			draw_line(Vector2(0,h*0.32),Vector2(0,h*0.39),Color("51554a"),1,true)
			draw_set_transform(lift);label_at(caption,Vector2(7,h-3),15)
		"tools":
			if tools_art==null and ResourceLoader.exists(TOOLS_PATH):tools_art=AssetTexture.get_texture(TOOLS_PATH)
			if tools_art!=null:
				var source:=Rect2(tools_art.get_size()*Vector2(70.0/1153,176.0/1364),tools_art.get_size()*Vector2(1016.0/1153,1072.0/1364))
				var art_rect:=draw_fitted_art(tools_art,source)
				centered_caption(art_rect.position+art_rect.size*Vector2(0.55,0.73),15)
			else:draw_tool_roll(w,h)
		"envelope":
			Paper.paint(self,Rect2(11,15,w-20,h-21),2)
			Paper.paint(self,Rect2(9,12,w-20,h-21),1)
			poly([Vector2(12,15),Vector2(w*0.50,h*0.60),Vector2(w-14,14)],Color(0.74,0.66,0.49,0.13))
			draw_polyline(PackedVector2Array([Vector2(12,14),Vector2(w*0.50,h*0.57),Vector2(w-14,13)]),Color("b5a88c"),1.3,true)
			draw_line(Vector2(12,h-12),Vector2(w*0.37,h*0.44),Color("c5b797"),1,true)
			draw_line(Vector2(w-13,h-12),Vector2(w*0.65,h*0.44),Color("c5b797"),1,true)
			var seal:=Vector2(w*0.50,h*0.57)
			draw_circle(seal+Vector2(1,2),12,Color(0.32,0.21,0.15,0.16))
			var wax: Array=[]
			for i in 28:wax.append(seal+Vector2(cos(i*TAU/28),sin(i*TAU/28))*(11+sin(i*2.3)*0.8))
			poly(wax,Color("ae7258"));draw_arc(seal,7,0,TAU,24,Color("d5a583"),1,true)
			draw_line(seal+Vector2(-2,4),seal+Vector2(2,-4),Color("854f40"),1,true)
			draw_line(seal+Vector2.ZERO,seal+Vector2(-3,-2),Color("854f40"),1,true)
			label_at(caption,Vector2(20,h-21),14)
	draw_set_transform(Vector2.ZERO)
	if has_focus():draw_arc(size/2,minf(w,h)*0.43,0.1,TAU-0.1,32,Color("e9c687"),1.4,true)
func draw_fitted_art(texture: Texture2D,source: Rect2) -> Rect2:
	# Runtime source regions omit transparent padding; the raster files stay intact.
	var extent:=source.size*minf(size.x/source.size.x,size.y/source.size.y)
	var destination:=Rect2((size-extent)*0.5,extent)
	draw_texture_rect_region(texture,destination,source)
	return destination
func centered_caption(center: Vector2,font_size: int) -> void:
	if font:
		var width:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		label_at(caption,center+Vector2(-width*0.5,font_size*0.34),font_size)
func draw_folio_fallback(w: float,h: float) -> void:
	poly([Vector2(8,19),Vector2(w-2,11),Vector2(w-6,h-8),Vector2(13,h)],Color(0.24,0.18,0.13,0.18))
	for i in 3:Paper.paint(self,Rect2(16+i*3,15+i*3,w-31,h-32),2+i,false)
	poly([Vector2(3,34),Vector2(20,31),Vector2(20,5),Vector2(w*0.53,0),Vector2(w*0.60,28),Vector2(w-8,24),Vector2(w-3,h-17),Vector2(9,h-5)],Color("b89870"))
	draw_line(Vector2(22,41),Vector2(25,h-15),Color("977956"),2,true)
	draw_line(Vector2(10,h*0.62),Vector2(w-5,h*0.60),Color("e1c69a"),2,true)
	Paper.paint(self,Rect2(w*0.23,h*0.29,w*0.58,48),1,false)
	label_at(caption,Vector2(w*0.25,h*0.29+30),17)
func draw_tool_roll(w: float,h: float) -> void:
	var cloth: Array=[Vector2(2,26),Vector2(w-13,14),Vector2(w-4,h-10),Vector2(10,h)]
	shadow(cloth);poly(cloth,Color("728a80"))
	for i in 11:
		var y:=32+i*(h-48)/11
		draw_line(Vector2(8,y),Vector2(w-12,y-6),Color(0.89,0.88,0.72,0.07),1,true)
	# Individual bristles, metal blade, scissors and glue cap emerge from the pockets.
	var brush_x:=31.0
	draw_line(Vector2(brush_x,52),Vector2(brush_x+4,h-32),Color("ad795a"),9,true)
	poly([Vector2(brush_x-6,27),Vector2(brush_x+6,27),Vector2(brush_x+4,50),Vector2(brush_x-4,50)],Color("bcbba7"))
	for i in 7:draw_line(Vector2(brush_x-5+i*1.6,27),Vector2(brush_x-6+i*1.8,9+absf(i-3)*1.6),Color("685c49"),1.6,true)
	var knife_x:=w*0.38
	draw_line(Vector2(knife_x,62),Vector2(knife_x+3,h-32),Color("686f68"),10,true)
	poly([Vector2(knife_x-5,61),Vector2(knife_x+5,60),Vector2(knife_x+7,25),Vector2(knife_x-3,37)],Color("c6c4b4"))
	draw_line(Vector2(knife_x+5,30),Vector2(knife_x+3,57),Color("ece5cd"),1,true)
	var scissors_x:=w*0.63
	for side in [-1,1]:
		draw_arc(Vector2(scissors_x+side*7,38),8,0,TAU,24,Color("987c5b"),4,true)
		draw_line(Vector2(scissors_x+side*4,48),Vector2(scissors_x-side*8,h*0.58),Color("b9bbb0"),4,true)
	draw_circle(Vector2(scissors_x,67),3,Color("7b7463"))
	var glue_x:=w*0.83
	draw_line(Vector2(glue_x,40),Vector2(glue_x,h-32),Color("ded8bd"),19,true)
	draw_line(Vector2(glue_x,26),Vector2(glue_x,47),Color("bd8c69"),21,true)
	draw_line(Vector2(glue_x-5,31),Vector2(glue_x-5,43),Color("dec1a0"),1.3,true)
	poly([Vector2(9,h*0.50),Vector2(w-6,h*0.48),Vector2(w-4,h-10),Vector2(10,h)],Color("9eae97"))
	draw_line(Vector2(10,h*0.51),Vector2(w-8,h*0.49),Color("c6ccb0"),2,true)
	for i in 4:
		var x:=15+i*(w-22)/4
		stitches(Vector2(x,h*0.54),Vector2(x+4,h-17),Color("688374"))
	stitches(Vector2(17,h-13),Vector2(w-10,h-22),Color("e1d8b4"))
	label_at(caption,Vector2(20,h-25),15)
func label_at(value: String, at: Vector2, font_size: int) -> void:
	if font:draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("484e43"))
