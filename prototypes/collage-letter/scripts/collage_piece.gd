extends Node2D
class_name CollagePiece

const Tape=preload("res://scripts/tape_art.gd")
var alpha_hit:=false
var lift:=0.0
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
		shadow.append(p + Vector2(3+lift*4,5+lift*6))
	if not alpha_hit: draw_colored_polygon(shadow,Color(0.15,0.14,0.1,0.15))
	if source_id == -2:
		Tape.paint(self,polygon,tape_style)
	elif texture:
		draw_polygon(polygon,PackedColorArray([Color.WHITE]),uv,texture)
	else:
		draw_colored_polygon(polygon,Color("f5eddb"))
		draw_string(font,Vector2(-bounds().size.x/2+10,9),handwriting,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("40566b"))
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
	return {"alpha_hit":alpha_hit,"strokes":points,"tape_style":tape_style,"pen_color":pen_color.to_html(),"pen_width":pen_width,"source":source_id,"source_language":source_language,"polygon":poly,"uv":uvs,"position":[position.x,position.y],"rotation":rotation,"scale":[scale.x,scale.y],"taped":is_taped,"text":handwriting}

func release_lift() -> void:
	if settling and settling.is_running(): settling.kill()
	settling=create_tween()
	settling.tween_property(self,"lift",0.0,0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settling.tween_callback(queue_redraw)
func _process(_delta: float) -> void:
	if lift>0: queue_redraw()
