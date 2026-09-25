extends Node2D
static var font_bank: Dictionary={}
var kind: int = 0
var sheet_data: Dictionary
var font: Font
var asset_root := "res://assets/open_pack/"
var art: Texture2D
var illustration: Texture2D
var backing: Texture2D
var photo_region:=Rect2()
var paper_shape:=PackedVector2Array()
var ink := Color("344c50")
func _ready() -> void:
	art=load(asset_root+sheet_data.asset)
	if sheet_data.kind=="photo":
		photo_region=Rect2(art.get_image().get_used_rect())
		if photo_region.size.x/photo_region.size.y>3:photo_region=Rect2(Vector2(photo_region.size.x*0.25,0),Vector2(photo_region.size.y*1.5,photo_region.size.y))
	if sheet_data.kind=="letter": texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var variant:=str(sheet_data.get("font_style","print"))
	var locale:=str(sheet_data.get("display_locale","zh"))
	var font_key:=locale+":"+variant
	if font_bank.has(font_key):font=font_bank[font_key]
	else:
		if locale=="en":
			if variant=="handwritten": font=load("res://assets/fonts/caveat/Caveat[wght].ttf")
			elif variant=="typewriter": font=load("res://assets/fonts/specialelite/SpecialElite-Regular.ttf")
			elif variant=="serif": font=load("res://assets/fonts/librebaskerville/LibreBaskerville[wght].ttf")
		elif variant in ["handwritten","serif","typewriter"]:
			var face:=SystemFont.new()
			face.font_names=PackedStringArray(["KaiTi" if variant=="handwritten" else ("FangSong" if variant=="typewriter" else "SimSun"),"Microsoft YaHei"])
			font=face
		font_bank[font_key]=font
	if sheet_data.has("illustration"): illustration=load(asset_root+sheet_data.illustration)
	if sheet_data.kind in ["score","photo","art"]: backing=load(asset_root+"paper/Papier6.png")
	queue_redraw()
func text(value: String, at: Vector2, size: int = 18, width: float = 246, color: Color = Color("344c50")) -> void:
	var fitted:=size
	while fitted>8 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x>width: fitted-=1
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,fitted,color)
func lines(value: String, at: Vector2, size: int = 15, width: float = 242, max_lines: int = 5) -> void:
	var cursor:=at
	var count:=0
	for paragraph in value.split("\n"):
		var row:=""
		var units:=PackedStringArray()
		if paragraph.to_utf8_buffer().size()==paragraph.length():
			for word in paragraph.split(" "):units.append(word+" ")
		else:
			for character in paragraph:units.append(character)
		for character in units:
			if font.get_string_size(row+character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
				text(row,cursor,size,width);cursor.y+=size+6;count+=1;row=""
				if count>=max_lines: return
			row+=character
		text(row,cursor,size,width);cursor.y+=size+6;count+=1
		if count>=max_lines: return
func _draw() -> void:
	var type: String=sheet_data.kind

	if type in ["decoration","letter"]:
		var fit:=minf(170.0/art.get_width(),165.0/art.get_height())
		var dimensions:=art.get_size()*fit
		draw_texture_rect(art,Rect2(Vector2(150,119)-dimensions*0.5,dimensions),false)
		return
	var form:=int(sheet_data.get("paper_form",0))
	var dimensions: Vector2=[Vector2(276,216),Vector2(262,193),Vector2(220,216),Vector2(281,161),Vector2(245,200),Vector2(270,175),Vector2(234,213),Vector2(284,201),Vector2(258,208)][form%9]
	draw_set_transform(Vector2(150,120)-dimensions*0.5,0,dimensions/Vector2(276,216))
	draw_set_transform(Vector2(150,120)-dimensions*0.5-Vector2(12,12)*dimensions/Vector2(276,216),0,dimensions/Vector2(276,216))
	var bounds:=Rect2(12,12,276,216)
	var tint:=Color(sheet_data.get("color","#faf2df"))
	var corners: Array=[Vector2(12,12),Vector2(288,12),Vector2(288,228),Vector2(12,228)]
	var random:=RandomNumberGenerator.new();random.seed=int(sheet_data.get("edge_seed",kind*97+31))
	paper_shape.clear()
	var coordinates:=PackedVector2Array()
	for side in 4:
		for step in 28:
			var point: Vector2=corners[side].lerp(corners[(side+1)%4],step/28.0)
			var rough:=0.5 if form==0 else (4.2 if form in [1,4,6] else 1.8)
			point+=Vector2(random.randf_range(-rough,rough),random.randf_range(-rough,rough))
			if form==3 and side%2==1: point.x+=sin(step*PI/2)*3.3
			paper_shape.append(point);coordinates.append((point-Vector2(12,12))/Vector2(276,216))
	draw_colored_polygon(paper_shape,tint)
	draw_polygon(paper_shape,PackedColorArray([Color(tint,float(sheet_data.get("texture_strength",0.75)))]),coordinates,backing if backing else art)
	var edge:=paper_shape.duplicate();edge.append(edge[0]);draw_polyline(edge,Color(0.95,0.88,0.72,0.6),1.2,true)
	if type in ["art","photo"]:
		var region:=photo_region if type=="photo" else Rect2(Vector2.ZERO,art.get_size())
		var art_dimensions:=region.size*minf(250.0/region.size.x,179.0/region.size.y)
		draw_texture_rect_region(art,Rect2(Vector2(150,111)-art_dimensions*0.5,art_dimensions),region)
		text(sheet_data.title,Vector2(24,218),10,248)
		return
	match type:
		"paper": paper_pattern(str(sheet_data.pattern))
		"advert": advert()
		"score":
			var region: Array=sheet_data.get("scan_region",[0.06,0.08,0.88,0.8])
			draw_texture_rect_region(art,Rect2(23,23,254,190),Rect2(Vector2(region[0],region[1])*art.get_size(),Vector2(region[2],minf(region[3],0.98-region[1]))*art.get_size()),Color("e8d6af"))
			if backing: draw_texture_rect(backing,Rect2(23,23,254,190),false,Color(1,0.95,0.85,0.12))
		"ticket": ticket()
		_: printed()
func paper_pattern(pattern: String) -> void:
	var faint:=Color(0.24,0.43,0.45,0.28)
	if pattern in ["grid","ruled","margin"]:
		for y in range(30,217,18): draw_line(Vector2(20,y),Vector2(280,y),faint)
		if pattern=="grid":
			for x in range(30,281,18): draw_line(Vector2(x,20),Vector2(x,221),faint)
		if pattern=="margin": draw_line(Vector2(56,18),Vector2(56,222),Color(0.65,0.26,0.22,0.4),1.5)
	elif pattern=="dot":
		for x in range(30,281,18):
			for y in range(30,217,18): draw_circle(Vector2(x,y),1,faint)
	elif pattern=="postal":
		for x in range(20,270,24):
			for y in [19,219]: draw_line(Vector2(x,y),Vector2(x+12,y),Color("a76d5b") if x%48==20 else Color("618387"),4)
	elif pattern=="diagonal":
		for x in range(18,270,14): draw_line(Vector2(x,220),Vector2(mini(x+80,280),maxi(20,220-(280-x)*2)),faint)
	elif pattern=="scallop":
		for x in range(30,276,24):
			for y in [24,216]: draw_arc(Vector2(x,y),10,0,PI,16,faint,1,true)
func advert() -> void:
	var accent:=Color(sheet_data.get("accent","#a85740"))
	var layout:=int(sheet_data.get("layout",0))
	text(str(sheet_data.brand),Vector2(27,39),16,246,accent)
	if layout==0:
		draw_rect(Rect2(24,48,252,48),accent)
		text(str(sheet_data.headline),Vector2(33,79),24,234,Color("fff6df"))
		lines(str(sheet_data.body),Vector2(29,121),17,240,3)
		text(str(sheet_data.badge),Vector2(29,193),18,240,accent)
	elif layout==1:
		draw_rect(Rect2(22,47,256,147),accent,false,2)
		text(str(sheet_data.headline),Vector2(32,78),23,236,accent)
		text(str(sheet_data.badge),Vector2(32,110),25,236,accent)
		lines(str(sheet_data.body),Vector2(32,139),14,234,3)
		for x in range(27,276,12): draw_circle(Vector2(x,200),1.4,accent)
	elif layout==2:
		draw_line(Vector2(26,52),Vector2(274,52),accent,3)
		text(str(sheet_data.headline),Vector2(27,84),24,246,accent)
		lines(str(sheet_data.body),Vector2(29,115),16,239,3)
		draw_rect(Rect2(25,175,250,26),Color(accent,0.13))
		text(str(sheet_data.badge),Vector2(32,194),17,235,accent)
	else:
		draw_rect(Rect2(24,50,70,145),accent)
		lines(str(sheet_data.body),Vector2(105,104),15,164,4)
		text(str(sheet_data.headline),Vector2(104,75),22,169,accent)
		text(str(sheet_data.badge),Vector2(104,187),19,169,accent)
		if illustration: draw_texture_rect(illustration,Rect2(32,88,55,55),false,Color("f4e2bb"))
	text(str(sheet_data.footer),Vector2(27,218),10,246,accent)
func printed() -> void:
	var layout:=int(sheet_data.get("layout",0))%6
	var y:=55.0
	if layout==1:
		draw_rect(Rect2(24,24,252,49),Color(ink,0.12));y=55
	elif layout==2: draw_rect(Rect2(23,23,254,194),Color(ink,0.4),false,1)
	elif layout==3: draw_line(Vector2(26,29),Vector2(88,29),ink,4);y=66
	elif layout==4: draw_circle(Vector2(260,37),8,Color(ink,0.22))
	elif layout==5:
		for x in range(26,274,8): draw_circle(Vector2(x,207),0.8,ink)
	text(str(sheet_data.headline),Vector2(28,y),23,242)
	draw_line(Vector2(28,y+15),Vector2(271,y+15),Color(ink,0.55),1)
	lines(str(sheet_data.body),Vector2(28,y+47),16,240,5)
func ticket() -> void:
	text("SOLMERE",Vector2(28,31),9,240)
	var layout:=int(sheet_data.get("layout",0))%4
	var accent:=Color("8b5745") if layout%2 else ink
	if layout==1: draw_rect(Rect2(22,22,256,45),Color(accent,0.15))
	if layout==2: draw_rect(Rect2(23,23,254,194),accent,false,1)
	text(str(sheet_data.headline),Vector2(28,54),23,244,accent)
	lines(str(sheet_data.body),Vector2(28,88),15,240,4)
	for x in range(22,280,9): draw_line(Vector2(x,183),Vector2(x+4,183),Color(accent,0.6))
	text(str(sheet_data.get("footer","")),Vector2(27,213),10,180,accent)
	text("%04d" % (kind+1),Vector2(227,213),13,49,accent)
	if layout==3:
		for n in 38: draw_line(Vector2(28+n*4,163),Vector2(28+n*4,176),Color(accent,0.7),1 if n%3 else 2)
