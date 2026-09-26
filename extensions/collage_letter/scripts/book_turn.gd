extends Control
## A captured paper leaf bends around its binding; the next leaf is already beneath it.
var leaf: Texture2D
var progress:=0.0
var direction:=1
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	var animation:=create_tween()
	animation.tween_method(func(value:float):progress=value;queue_redraw(),0.0,1.0,0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	animation.tween_callback(queue_free)
func _draw() -> void:
	if not leaf:return
	var w:=size.x;var h:=size.y
	var remaining:=w*(1-progress)
	var bend:=sin(progress*PI)*42.0
	var edge:=remaining if direction>0 else w-remaining
	if remaining>0.5:
		var left:=0.0 if direction>0 else edge
		draw_texture_rect_region(leaf,Rect2(left,0,remaining,h),Rect2(left,0,remaining,h))
		# Curved reverse face, with its own cast shadow and warm paper grain.
		var points:=PackedVector2Array();var uv:=PackedVector2Array()
		for i in range(17):
			var y:=h*i/16.0
			var bow:=sin(PI*i/16.0)*bend*0.28
			points.append(Vector2(edge+direction*(bend+bow),y));uv.append(Vector2(1,y/h))
		for i in range(16,-1,-1):
			var y:=h*i/16.0
			points.append(Vector2(edge,y));uv.append(Vector2(0,y/h))
		var shadow:=PackedVector2Array()
		for p in points:shadow.append(p+Vector2(direction*6,5))
		draw_colored_polygon(shadow,Color(0.2,0.15,0.1,0.18*sin(progress*PI)))
		if bend>0.1:
			draw_colored_polygon(points,Color("e4d8ba"))
			draw_polygon(points,PackedColorArray([Color(1,1,1,0.28)]),uv,preload("res://extensions/collage_letter/assets/open_pack/paper/Papier13.png"))
			draw_line(Vector2(edge,0),Vector2(edge,h),Color(0.36,0.29,0.20,0.3),1.1,true)
