extends Node2D
class_name CollagePiece

const Tape=preload("res://scripts/tape_art.gd")
var alpha_hit:=false
var painted_png:=""
var is_glued:=false
var glue_coverage:=0.0
var glue_flash:=0.0
var back_visible:=false
var back_texture: ImageTexture
var glue_marks:=PackedVector2Array()
static var back_grain: Image
var silhouette_texture: ImageTexture
var lift:=0.0
var paper_thickness:=0.8
var hit_image: Image
var settling: Tween
var tape_style:=0
var strokes:=PackedVector2Array()
var pen_color:=Color("40566b")
var pen_width:=3.0
var source_id := 0
var source_language := "zh"
var texture: Texture2D
var polygon := PackedVector2Array()
var uv := PackedVector2Array()
var is_taped := false
var selected := false
var handwriting := ""
var font: Font

func _draw() -> void:
	if polygon.size() < 3:
		return
	if source_id==-3:
		if strokes.size()>1: draw_polyline(strokes,pen_color,pen_width,true)
		return
	var shadow := PackedVector2Array()
	for p in polygon:
		shadow.append(p + Vector2(1.2+paper_thickness+lift*4,1.4+paper_thickness*1.8+lift*6))
	if not alpha_hit: draw_colored_polygon(shadow,Color(0.15,0.14,0.1,0.08+paper_thickness*0.045))
	elif texture and source_id>=0:
		if not silhouette_texture:
			var mask:=texture.get_image();mask.convert(Image.FORMAT_RGBA8)
			for y in mask.get_height():
				for x in mask.get_width():mask.set_pixel(x,y,Color(1,1,1,mask.get_pixel(x,y).a))
			silhouette_texture=ImageTexture.create_from_image(mask)
		# Solid alpha silhouette: the printed picture must never appear in its shadow.
		for layer in [2,1,0]:
			var cast:=PackedVector2Array()
			for p in polygon:cast.append(p+Vector2(1.4+paper_thickness+lift*4+layer,2+paper_thickness*1.5+lift*6+layer))
			draw_polygon(cast,PackedColorArray([Color(0.22,0.17,0.12,0.06 if is_glued else 0.085)]),uv,silhouette_texture)
		var edge:=PackedVector2Array()
		for p in polygon:edge.append(p+Vector2(0.3,paper_thickness*1.5))
		draw_polygon(edge,PackedColorArray([Color("d4c5a9")]),uv,silhouette_texture)
	if source_id == -2:
		Tape.paint(self,polygon,tape_style)
	elif texture:
		if back_visible and not back_texture:rebuild_back()
		draw_polygon(polygon,PackedColorArray([Color.WHITE]),uv,back_texture if back_visible else texture)
		if not alpha_hit:
			var rim:=polygon.duplicate();rim.append(rim[0])
			draw_polyline(rim,Color(1,0.97,0.87,0.36),0.55+paper_thickness*0.35,true)
	else:
		draw_colored_polygon(polygon,Color("f5eddb"))
		draw_string(font,Vector2(-bounds().size.x/2+10,9),handwriting,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("40566b"))
	if glue_flash>0 and texture:
		draw_polygon(polygon,PackedColorArray([Color(1,1,0.82,glue_flash*0.22)]),uv,texture)
	if selected:
		var border := polygon.duplicate()
		border.append(polygon[0])
		draw_polyline(border,Color(0.96,0.9,0.75,0.5),0.8,true)

func bounds() -> Rect2:
	var rect := Rect2(polygon[0],Vector2.ZERO)
	for p in polygon:
		rect = rect.expand(p)
	return rect

func hit(point: Vector2) -> bool:
	if source_id==-3:
		for i in range(1,strokes.size()):
			if to_local(point).distance_to(Geometry2D.get_closest_point_to_segment(to_local(point),strokes[i-1],strokes[i]))<7: return true
		return false
	if not Geometry2D.is_point_in_polygon(to_local(point),polygon): return false
	if alpha_hit and texture:
		if not hit_image: hit_image=texture.get_image()
		var pixel:=Vector2(150,119)+to_local(point)
		if source_id==-4:pixel=(to_local(point)-bounds().position)/bounds().size*Vector2(hit_image.get_size())
		return hit_image.get_pixelv(Vector2i(pixel).clamp(Vector2i.ZERO,hit_image.get_size()-Vector2i.ONE)).a>0.1
	return true

func serialize() -> Dictionary:
	var poly: Array = []
	var uvs: Array = []
	for p in polygon:
		poly.append([p.x,p.y])
	for p in uv:
		uvs.append([p.x,p.y])
	var points: Array=[]
	for p in strokes: points.append([p.x,p.y])
	var marks: Array=[]
	for p in glue_marks:marks.append([p.x,p.y])
	return {"back_visible":back_visible,"glue_marks":marks,"painted_png":painted_png,"glued":is_glued,"glue_coverage":glue_coverage,"paper_thickness":paper_thickness,"alpha_hit":alpha_hit,"strokes":points,"tape_style":tape_style,"pen_color":pen_color.to_html(),"pen_width":pen_width,"source":source_id,"source_language":source_language,"polygon":poly,"uv":uvs,"position":[position.x,position.y],"rotation":rotation,"scale":[scale.x,scale.y],"taped":is_taped,"text":handwriting}

func texture_point(local: Vector2, image_size: Vector2) -> Vector2:
	return (uv[0]+(local-polygon[0])/Vector2(300,240))*image_size
func add_glue(world: Vector2) -> void:
	var point:=to_local(world)
	if glue_marks.size()>0 and glue_marks[-1].distance_to(point)<8:return
	glue_marks.append(point)
	var covered:=0;var possible:=0
	var rect:=bounds()
	for y in 12:
		for x in 12:
			var sample:=rect.position+rect.size*Vector2((x+0.5)/12.0,(y+0.5)/12.0)
			if not hit(to_global(sample)):continue
			possible+=1
			for mark in glue_marks:
				if mark.distance_to(sample)<36:covered+=1;break
	glue_coverage=float(covered)/maxi(1,possible)
	back_texture=null;queue_redraw()
func rebuild_back() -> void:
	if not texture:return
	var image:=texture.get_image();image.convert(Image.FORMAT_RGBA8)
	if not back_grain:back_grain=load("res://assets/open_pack/paper/Papier13.png").get_image()
	var grain: Image=back_grain
	for y in image.get_height():
		for x in image.get_width():
			var alpha:=image.get_pixel(x,y).a
			var tone:=grain.get_pixel(x%grain.get_width(),y%grain.get_height()).r
			image.set_pixel(x,y,Color(0.91+tone*0.075,0.865+tone*0.08,0.74+tone*0.12,alpha))
	var dimensions:=Vector2(image.get_size())
	for mark in glue_marks:
		var center:=texture_point(mark,dimensions)
		var radius:=Vector2(36,36)/Vector2(300,240)*dimensions
		for y in range(maxi(0,int(center.y-radius.y)),mini(image.get_height(),int(center.y+radius.y)+1)):
			for x in range(maxi(0,int(center.x-radius.x)),mini(image.get_width(),int(center.x+radius.x)+1)):
				var distance:=((Vector2(x,y)-center)/radius).length()
				if distance>=1:continue
				var pixel:=image.get_pixel(x,y);var wet:=Color(0.99,0.98,0.85,pixel.a)
				image.set_pixel(x,y,pixel.lerp(wet,(1-distance)*0.46))
	if back_texture:back_texture.update(image)
	else:back_texture=ImageTexture.create_from_image(image)

func release_lift() -> void:
	if settling and settling.is_running(): settling.kill()
	settling=create_tween()
	settling.tween_property(self,"lift",0.0,0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settling.tween_callback(queue_redraw)
func _process(delta: float) -> void:
	if glue_flash>0:glue_flash=maxf(0,glue_flash-delta);queue_redraw()
	if lift>0: queue_redraw()
