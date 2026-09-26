extends Control
## A flexible paper leaf curls around a moving fold. Front ink bends with the
## surface, while the reverse face is blank; the next leaf stays underneath.
var leaf: Texture2D
var progress:=0.0
var direction:=1
var back:Texture2D
func _ready() -> void:
	back=preload("res://extensions/collage_letter/scripts/letter_paper.gd").texture(1)
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	var animation:=create_tween()
	animation.tween_method(func(value:float):progress=value;queue_redraw(),0.0,1.0,0.70).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	animation.tween_callback(queue_free)
func point(u:float,v:float)->Vector2:
	var x:=u*size.x
	var radius:=19.0+sin(progress*PI)*16.0
	var fold:=lerpf(size.x+2.0,-PI*radius-4.0,progress)
	# The lower corner lifts first; the fold is gently diagonal, not a ruler.
	fold+=(0.5-v)*sin(progress*PI)*42.0
	var distance:=x-fold
	if distance<=0:return Vector2(x,v*size.y)
	var angle:=minf(PI,distance/radius)
	var curled_x:=fold+radius*sin(angle)
	if distance>PI*radius:curled_x-=distance-PI*radius
	var lift:=sin(angle)*13.0*(0.5-v)
	return Vector2(curled_x,v*size.y+lift)
func surface_angle(u:float,v:float)->float:
	var radius:=19.0+sin(progress*PI)*16.0
	var fold:=lerpf(size.x+2.0,-PI*radius-4.0,progress)+(0.5-v)*sin(progress*PI)*42.0
	return clampf((u*size.x-fold)/radius,0,PI)
func _draw() -> void:
	if not leaf:return
	if direction<0:draw_set_transform(Vector2(size.x,0),0,Vector2(-1,1))
	# Soft moving contact shadow, strongest beside the paper's lifted crease.
	var radius:=19.0+sin(progress*PI)*16.0
	var fold:=lerpf(size.x+2.0,-PI*radius-4.0,progress)
	for i in range(34):
		var opacity:=0.10*sin(PI*i/34.0)*sin(progress*PI)
		draw_line(Vector2(fold+i*2-10,3),Vector2(fold+i*2-10,size.y),Color(0.24,0.18,0.11,opacity),2)
	# Draw in paper order, so the turned reverse naturally occludes the front.
	for col in 56:
		for row in 8:
			var u0:=float(col)/56;var u1:=float(col+1)/56
			var v0:=float(row)/8;var v1:=float(row+1)/8
			var corners:=PackedVector2Array([point(u0,v0),point(u1,v0),point(u1,v1),point(u0,v1)])
			var uv:=PackedVector2Array([Vector2(u0,v0),Vector2(u1,v0),Vector2(u1,v1),Vector2(u0,v1)])
			if direction<0:
				for i in uv.size():uv[i].x=1.0-uv[i].x
			var angle:=surface_angle((u0+u1)*0.5,(v0+v1)*0.5)
			var reverse:=angle>PI*0.5
			var shade:=1.0-0.20*sin(angle)
			var tint:=Color(shade,shade,shade) if not reverse else Color(shade,shade*0.97,shade*0.87)
			# A quad crossing the crest can become concave or collapse edge-on.
			# Two explicit non-degenerate triangles preserve the flexible surface.
			for indices in [[0,1,2],[0,2,3]]:
				var a:Vector2=corners[indices[0]];var b:Vector2=corners[indices[1]];var c:Vector2=corners[indices[2]]
				if absf((b-a).cross(c-a))<0.03:continue
				draw_polygon(PackedVector2Array([a,b,c]),PackedColorArray([tint]),PackedVector2Array([uv[indices[0]],uv[indices[1]],uv[indices[2]]]),back if reverse else leaf)
	# Fine page edge: thickness belongs to the curled silhouette, not a frame.
	var edge:=PackedVector2Array()
	for row in 25:edge.append(point(1.0,float(row)/24))
	draw_polyline(edge,Color(0.94,0.88,0.73,0.8),1,true)
