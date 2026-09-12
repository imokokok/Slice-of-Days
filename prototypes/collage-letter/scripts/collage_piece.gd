extends Node2D
class_name CollagePiece

var source_id := 0
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
	var shadow := PackedVector2Array()
	for p in polygon:
		shadow.append(p + Vector2(3,5))
	draw_colored_polygon(shadow,Color(0.15,0.14,0.1,0.15))
	if source_id == -2:
		draw_colored_polygon(polygon,Color(0.71,0.65,0.40,0.62))
		var box := bounds()
		for x in range(int(box.position.x),int(box.end.x),9):
			draw_line(Vector2(x,box.position.y+2),Vector2(x+3,box.end.y-2),Color(1,1,0.8,0.13))
	elif texture:
		draw_polygon(polygon,PackedColorArray([Color.WHITE]),uv,texture)
	else:
		draw_colored_polygon(polygon,Color("f5eddb"))
		draw_string(font,Vector2(-bounds().size.x/2+10,9),handwriting,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("40566b"))
	if selected:
		var border := polygon.duplicate()
		border.append(polygon[0])
		draw_polyline(border,Color("aa593e"),1.5,true)

func bounds() -> Rect2:
	var rect := Rect2(polygon[0],Vector2.ZERO)
	for p in polygon:
		rect = rect.expand(p)
	return rect

func hit(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(point),polygon)

func serialize() -> Dictionary:
	var poly: Array = []
	var uvs: Array = []
	for p in polygon:
		poly.append([p.x,p.y])
	for p in uv:
		uvs.append([p.x,p.y])
	return {"source":source_id,"polygon":poly,"uv":uvs,"position":[position.x,position.y],"rotation":rotation,"scale":[scale.x,scale.y],"taped":is_taped,"text":handwriting}
